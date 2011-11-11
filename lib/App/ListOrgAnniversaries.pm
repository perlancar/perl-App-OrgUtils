package App::ListOrgAnniversaries;

use 5.010;
use strict;
use warnings;
use Log::Any qw($log);

use DateTime;
use Lingua::EN::Numbers::Ordinate;
use Org::Parser;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_anniversaries);

# VERSION

our %SPEC;

my $today;
my $yest;

sub _process_hl {
    my ($file, $hl, $args, $res, $opts) = @_;

    return unless $hl->is_leaf;

    $log->tracef("Processing %s ...", $hl->title->as_string);

    if ($args->{has_tags} || $args->{lack_tags}) {
        my $tags = [$hl->get_tags];
        if ($args->{has_tags}) {
            for (@{ $args->{has_tags} }) {
                return unless $_ ~~ @$tags;
            }
        }
        if ($args->{lack_tags}) {
            for (@{ $args->{lack_tags} }) {
                return if $_ ~~ @$tags;
            }
        }
    }

    my @annivs;
    $hl->walk(
        sub {
            my ($el) = @_;

            if ($el->isa('Org::Element::Timestamp')) {
                my $field = $el->field_name;
                return unless defined($field) &&
                    $field =~ $args->{field_pattern};
                push @annivs, [$field, $el->datetime];
                return;
            }
            if ($el->isa('Org::Element::Drawer') && $el->name eq 'PROPERTIES') {
                my $props = $el->properties;
                for my $k (keys %$props) {
                    next unless $k =~ $args->{field_pattern};
                    my $v = $props->{$k};
                    unless ($v =~ /^\s*(\d{4})-(\d{2})-(\d{2})\s*$/) {
                        $log->warn("Invalid date format $v, ".
                                       "must be YYYY-MM-DD");
                        next;
                    }
                    push @annivs,
                        [$k, DateTime->new(year=>$1, month=>$2, day=>$3,
                                       time_zone=>$opts->{time_zone})];
                    return;
                }
            }
        }
    );

    if (!@annivs) {
        $log->debug("Node doesn't contain anniversary fields, skipped");
        return;
    }
    $log->tracef("annivs = ", \@annivs);
    for my $anniv (@annivs) {
        my ($field, $date) = @$anniv;
        $log->debugf("Anniversary found: field=%s, date=%s",
                     $field, $date->ymd);
        my $y = $today->year - $date->year;
        my $date_ly = $date->clone; $date_ly->add(years => $y-1);
        my $date_ty = $date->clone; $date_ty->add(years => $y  );
        my $date_ny = $date->clone; $date_ny->add(years => $y+1);
      DATE:
        for my $d ($date_ly, $date_ty, $date_ny) {
            my $days = int(($d->epoch - $today->epoch)/86400);
            next if defined($args->{due_in}) &&
                $days > $args->{due_in};
            next if defined($args->{max_overdue}) &&
                -$days > $args->{max_overdue};
            next if !defined($args->{due_in}) &&
                !defined($args->{max_overdue}) &&
                    DateTime->compare($d, $today) < 0;
            my $pl = abs($days) > 1 ? "s" : "";
            my $hide_age = $date->year == 1900;
            my $msg = sprintf(
                "%s: %s of %s (%s)",
                $days == 0 ? "today" :
                    $days < 0 ? abs($days)." day$pl ago" :
                        "in $days day$pl",
                $hide_age ? $field :
                    ordinate($d->year - $date->year)." $field",
                $hl->title->as_string,
                $hide_age ? $d->ymd : $date->ymd . " - " . $d->ymd);
            $log->debugf("Added this anniversary to result: %s", $msg);
            push @$res, $msg;
            last DATE;
        }
    } # for @annivs
}

$SPEC{list_org_anniversaries} = {
    summary => 'List all anniversaries in Org files',
    description => <<'_',
This function expects contacts in the following format:

 * First last                              :office:friend:
   :PROPERTIES:
   :BIRTHDAY:     1900-06-07
   :EMAIL:        foo@example.com
   :OTHERFIELD:   ...
   :END:

or:

 * Some name                               :office:
   - birthday   :: [1900-06-07 ]
   - email      :: foo@example.com
   - otherfield :: ...

Using PROPERTIES, dates currently must be specified in "YYYY-MM-DD" format.
Other format will be supported in the future. Using description list, dates can
be specified using normal Org timestamps (repeaters and warning periods will be
ignored).

By convention, if year is '1900' it is assumed to mean year is not specified.

By default, all contacts' anniversaries will be listed. You can filter contacts
using tags ('has_tags' and 'lack_tags' options), or by 'due_in' and
'max_overdue' options (due_in=14 and max_overdue=2 is what I commonly use in my
startup script).

_
    args    => {
        files => ['array*' => {
            of         => 'str*',
            arg_pos    => 0,
            arg_greedy => 1,
        }],
        field_pattern => [str => {
            summary => 'Field regex that specifies anniversaries',
            default => '(?:birthday|anniversary)'
        }],
        has_tags => [array => {
            summary => 'Filter headlines that have the specified tags',
        }],
        lack_tags => [array => {
            summary => 'Filter headlines that don\'t have the specified tags',
        }],
        due_in => [int => {
            summary => 'Only show anniversaries that are due '.
                'in this number of days',
        }],
        max_overdue => [int => {
            summary => 'Don\'t show dates that are overdue '.
                'more than this number of days',
        }],
        time_zone => [str => {
            summary => 'Will be passed to parser\'s options',
            description => <<'_',

If not set, TZ environment variable will be picked as default.

_
        }],
   },
};
sub list_org_anniversaries {
    my %args = @_;

    my $tz = $args{time_zone} // $ENV{TZ} // "UTC";

    # XXX schema
    my $files = $args{files};
    return [400, "Please specify files"] if !$files || !@$files;
    my $f = $args{field_pattern} // '(?:birthday|anniversary)';
    return [400, "Invalid field_pattern: $@"] unless eval { $f = qr/$f/i };
    $args{field_pattern} = $f;

    $today = DateTime->today(time_zone => $tz);
    $yest  = $today->clone->add(days => -1);

    my $orgp = Org::Parser->new;
    my @res;

    for my $file (@$files) {
        $log->debug("Parsing $file ...");
        my $opts = {time_zone => $tz};
        my $doc = $orgp->parse_file($file, $opts);
        $doc->walk(
            sub {
                my ($el) = @_;
                return unless $el->isa('Org::Element::Headline');
                _process_hl($file, $el, \%args, \@res, $opts)
            });
    } # for $file

    [200, "OK", \@res];
}

1;
#ABSTRACT: List headlines in Org files
__END__

=head1 SYNOPSIS

 # See list-org-anniversaries script


=head1 DESCRIPTION

This module uses L<Log::Any> logging framework.


=head1 FUNCTIONS

None are exported, but they are exportable.

=cut
