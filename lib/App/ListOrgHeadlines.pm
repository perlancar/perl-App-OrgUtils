package App:::ListOrgHeadlines;
#ABSTRACT: An application to list headlines in Org files

use 5.010;
use strict;
use warnings;
use Log::Any qw($log);

use DateTime;
use Org::Parser;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_headlines);

our %SPEC;

sub _add_result {
    my ($hl, $ts, $args) = @_;

    my $res;
    if ($args->{detail}) {
        $res = {};
        $res->{title}      = $hl->title->as_string;
        $res->{start_date} = $ts->ymd("-");
        $res->{due_date}   =
    } else {
        if ($args{todo} && !$args{done}) {
        my $days = int(($el->datetime->epoch-$today->epoch)/86400);
        $res = sprintf("%s: %s (%s)",
                $days == 0 ? "today" :
                    $days < 0 ? abs($days)." days ago" :
                        "in $days days",
                $cur_hl->title->as_string,
                $el->datetime->ymd);
    }
    $res;
}

$SPEC{list_org_headlines} = {
    summary => 'List all headlines in all Org files',
    args    => {
        files => ['array*' => {
            of         => 'str*',
            arg_pos    => 0,
            arg_greedy => 1,
        }],
        todo => [bool => {
            summary => 'Filter headlines that are todos',
            default => 0,
        }],
        done => [bool => {
            summary => 'Filter todo items that are done',
        }],
        due_in => [int => {
            summary => 'Filter todo items which is due in this number of days',
        }],
        from_level => [int => {
            summary => 'Filter headlines having this level as the minimum',
            default => 1,
        }],
        to_level => [int => {
            summary => 'Filter headlines having this level as the maximum',
        }],
        state => [str => {
            summary => 'Filter todo items that have this state',
        }],
        detail => [bool => {
            summary => 'Show details instead of just titles',
            default => 0,
        }],
        has_tags => [array => {
            summary => 'Filter headlines that have the specified tags',
        }],
        lack_tags => [array => {
            summary => 'Filter headlines that don\'t have the specified tags',
        }],
        priority => [str => {
            summary => 'Filter todo items that have this priority',
        }],
    },
};
sub list_org_headlines {
    my %args = @_;

    my $files = $args{files};
    return [400, "Please specify files"] if !$files || !@$files;

    my $orgp  = Org::Parser->new;
    my $today = DateTime->today;
    my $yest  = $today->clone->add(days => -1);
    my @res;

    for my $file (@$files) {
        $log->debug("Parsing $file ...");
        my $cur_hl; # current headline
        my $cur_ats; # current active timestamp
        my $include;
        my $doc = $orgp->parse_file($file);
        $doc->walk(
            sub {
                my ($el) = @_;
                if ($el->isa('Org::Element::Headline')) {
                    my $prev_el = $cur_hl;
                    if ($prev_el && $include) {
                        if ($args{detail}) {
                        } else {
                            }
                        }
                    }
                    $cur_hl = $el;
                    $cur_
                    $include = 1;
                } elsif ($el->isa('Org::Element::Timestamp')) {
                }

                return unless $el->isa('Org::Element::Timestamp')
                    && $el->is_active;
                my $is_hl = $el->isa('Org::Element::Headline');
                return unless $is_hl && $el->is_todo && !$el->is_done
                    || $el->isa('Org::Element::Timestamp') && $el->is_active;
                if ($is_hl && $el->is_todo) {
                    $curtodo = $el;
                }

                return unless !$is_hl && $curtodo;
                my $days = int(($el->datetime->epoch-$today->epoch)/86400);
                if ($days <= $args{days_before}) {
                    push @res,
                }
                $curtodo = undef;
            });
    }
    [200, "OK", \@res];
}

1;
