package App::ListOrgHeadlines;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use experimental 'smartmatch';
use Log::ger;

use App::OrgUtils;
use Cwd qw(abs_path);
use DateTime;
use Digest::MD5 qw(md5_hex);
use List::MoreUtils qw(uniq);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_headlines);

our %SPEC;

my $today;
my $yest;

sub _process_hl {
    my ($file, $hl, $args, $res) = @_;

    return if $args->{from_level} && $hl->level < $args->{from_level};
    return if $args->{to_level}   && $hl->level > $args->{to_level};
    if (defined $args->{todo}) {
        return if $args->{todo} xor $hl->is_todo;
    }
    if (defined $args->{done}) {
        return if $args->{done} xor $hl->is_done;
    }
    if (defined $args->{state}) {
        return unless $hl->is_todo &&
            $hl->todo_state eq $args->{state};
    }
    if ($args->{has_tags} || $args->{lacks_tags}) {
        my $tags = [$hl->get_tags];
        if ($args->{has_tags}) {
            for (@{ $args->{has_tags} }) {
                return unless $_ ~~ @$tags;
            }
        }
        if ($args->{lacks_tags}) {
            for (@{ $args->{lacks_tags} }) {
                return if $_ ~~ @$tags;
            }
        }
    }
    if (defined $args->{priority}) {
        my $p = $hl->todo_priority;
        return unless defined($p) && $args->{priority} eq $p;
    }
    if (defined $args->{minimum_priority}) {
        my $p = $hl->todo_priority;

        if (defined $p) {
            my $cmp = $hl->document->cmp_priorities(
                $p, $args->{minimum_priority});
            return if defined($cmp) && $cmp > 0;
            return if !defined($cmp) && !$args->{with_unknown_priority};
        } else {
            return unless $args->{with_unknown_priority};
        }
    }
    if (defined $args->{maximum_priority}) {
        my $p = $hl->todo_priority;

        if (defined $p) {
            my $cmp = $hl->document->cmp_priorities(
                $p, $args->{maximum_priority});
            return if defined($cmp) && $cmp < 0;
            return if !defined($cmp) && !$args->{with_unknown_priority};
        } else {
            return unless $args->{with_unknown_priority};
        }
    }

    my $ats = $hl->get_active_timestamp;
    my $days;
    $days = ($ats->datetime < $today ? -1:1) * $ats->datetime->delta_days($today)->in_units('days')
        if $ats;
    if (exists $args->{due_in}) {
        return unless $ats;
        my $met;
        if (defined $args->{due_in}) {
            $met = $days <= $args->{due_in};
        }
        if (!$met && $ats->_warning_period) {
            # try the warning period
            my $dt = $ats->datetime->clone;
            my $wp = $ats->_warning_period;
            $wp =~ s/(\w)$//;
            my $unit = $1;
            $wp = abs($wp);
            if ($unit eq 'd') {
                $dt->subtract(days => $wp);
            } elsif ($unit eq 'w') {
                $dt->subtract(weeks => $wp);
            } elsif ($unit eq 'm') {
                $dt->subtract(months => $wp);
            } elsif ($unit eq 'y') {
                $dt->subtract(years => $wp);
            } else {
                die "Can't understand unit '$unit' in timestamp's ".
                    "warning period: " . $ats->as_string;
                return;
            }
            $met++ if DateTime->compare($dt, $today) <= 0;
        }
        if (!$met && !$ats->_warning_period && !defined($args->{due_in})) {
            # try the default 14 days
            $met = $days <= 14;
        }
        return unless $met;
    }

    my $r;
    my $date;
    if ($args->{detail}) {
        $r               = {};
        $r->{file}       = $file;
        $r->{title}      = $hl->title->as_string;
        $r->{due_date}   = $ats ? $ats->datetime : undef;
        $r->{priority}   = $hl->todo_priority;
        $r->{tags}       = [$hl->get_tags];
        $r->{is_todo}    = $hl->is_todo;
        $r->{is_done}    = $hl->is_done;
        $r->{todo_state} = $hl->todo_state;
        $r->{progress}   = $hl->progress;
        $r->{level}      = $hl->level;
        $date = $r->{due_date};
    } else {
        if ($ats) {
            my $pl = abs($days) > 1 ? "s" : "";
            $r = sprintf("%s (%s): %s (%s)",
                         $days == 0 ? "today" :
                             $days < 0 ? abs($days)." day$pl ago" :
                                 "in $days day$pl",
                         $ats->datetime->strftime("%a"),
                         $hl->title->as_string,
                         $ats->datetime->ymd);
            $date = $ats->datetime;
        } else {
            $r = $hl->title->as_string;
        }
    }
    push @$res, [$r, $date, $hl];
}

$SPEC{list_org_headlines} = {
    v       => 1.1,
    summary => 'List all headlines in all Org files',
    args    => {
        %App::OrgUtils::common_args1,
        todo => {
            schema => ['bool'],
            summary => 'Only show headlines that are todos',
            tags => ['filter'],
        },
        done => {
            schema  => ['bool'],
            summary => 'Only show todo items that are done',
            tags => ['filter'],
        },
        due_in => {
            schema => ['int'],
            summary => 'Only show todo items that are (nearing|passed) due',
            description => <<'_',

If value is not set, then will use todo item's warning period (or, if todo item
does not have due date or warning period in its due date, will use the default
14 days).

If value is set to something smaller than the warning period, the todo item will
still be considered nearing due when the warning period is passed. For example,
if today is 2011-06-30 and due_in is set to 7, then todo item with due date
<2011-07-10 > won't pass the filter (it's still 10 days in the future, larger
than 7) but <2011-07-10 Sun +1y -14d> will (warning period 14 days is already
passed by that time).

_
            tags => ['filter'],
        },
        from_level => {
            schema => [int => {default=>1, min=>1}],
            summary => 'Only show headlines having this level as the minimum',
            tags => ['filter'],
        },
        to_level => {
            schema => ['int' => {min=>1}],
            summary => 'Only show headlines having this level as the maximum',
            tags => ['filter'],
        },
        state => {
            schema => ['str'],
            summary => 'Only show todo items that have this state',
            tags => ['filter'],
            completion => $App::OrgUtils::_complete_state,
        },
        detail => {
            schema => [bool => default => 0],
            summary => 'Show details instead of just titles',
            tags => ['format'],
        },
        has_tags => {
            schema => ['array', of=>'str*'],
            summary => 'Only show headlines that have the specified tags',
            tags => ['filter'],
            element_completion => $App::OrgUtils::_complete_tags,
        },
        lacks_tags => {
            schema => ['array', of=>'str*'],
            summary=> 'Only show headlines that don\'t have the specified tags',
            tags => ['filter'],
            element_completion => $App::OrgUtils::_complete_tags,
        },
        group_by_tags => {
            schema => [bool => default => 0],
            summary => 'Whether to group result by tags',
            description => <<'_',

If set to true, instead of returning a list, this function will return a hash of
lists, keyed by tag: {tag1: [hl1, hl2, ...], tag2: [...]}. Note that a headline
that has several tags will only be listed under its first tag, unless when
`allow_duplicates` is set to true, in which case the headline will be listed
under each of its tag.

_
            tags => ['format'],
        },
        allow_duplicates => {
            schema => ['bool'],
            summary => 'Whether to allow headline to be listed more than once',
            description => <<'_',

This is only relevant when `group_by_tags` is on. Normally when a headline has
several tags, it will only be listed under its first tag. But when this option
is turned on, the headline will be listed under each of its tag (which mean a
single headline will be listed several times).

_
            tags => ['format'],
        },
        priority => {
            schema => ['str'],
            summary => 'Only show todo items that have this priority',
            tags => ['filter'],
            completion => $App::OrgUtils::_complete_priority,
        },
        minimum_priority => {
            schema => ['str'],
            summary => 'Only show todo items that have at least this priority',
            tags => ['filter'],
            description => <<'_',

Note that the default priority list is [A, B, C] (A being the highest) and it
can be customized using the `#+PRIORITIES` setting.

_
            links => ['maximum_priority'],
            completion => $App::OrgUtils::_complete_priority,
        },
        maximum_priority => {
            schema => ['str'],
            summary => 'Only show todo items that have at most this priority',
            tags => ['filter'],
            description => <<'_',

Note that the default priority list is [A, B, C] (A being the highest) and it
can be customized using the `#+PRIORITIES` setting.

_
            links => ['minimum_priority'],
            completion => $App::OrgUtils::_complete_priority,
        },
        with_unknown_priority => {
            schema => ['bool'],
            summary => 'Also show items with no/unknown priority',
            tags => ['filter'],
            description => <<'_',

Relevant only when used with `minimum_priority` and/or `maximum_priority`.

If this option is turned on, todo items that does not have any priority or have
unknown priorities will *still* be included. Otherwise they will not be
included.

_
            links => ['minimum_priority', 'maximum_priority'],
        },
        today => {
            schema => [obj => isa=>'DateTime'],
            summary => 'Assume today\'s date',
            description => <<'_',

You can provide Unix timestamp or DateTime object. If you provide a DateTime
object, remember to set the correct time zone.

_
        },
        sort => {
            schema => [any => {
                of => [
                    ['str*' => {in=>['due_date', '-due_date']}],
                    'code*',
                ],
                default => 'due_date',
            }],
            summary => 'Specify sorting',
            description => <<'_',

If string, must be one of 'due_date', '-due_date' (descending).

If code, sorting code will get [REC, DUE_DATE, HL] as the items to compare,
where REC is the final record that will be returned as final result (can be a
string or a hash, if 'detail' is enabled), DUE_DATE is the DateTime object (if
any), and HL is the Org::Headline object.

_
            tags => ['format'],
        },
    },
};
sub list_org_headlines {
    my %args = @_;

    my $sort  = $args{sort};
    my $tz    = $args{time_zone} // $ENV{TZ} // "UTC";
    my $files = $args{files};

    $today = $args{today} // DateTime->today(time_zone => $tz);

    $yest  = $today->clone->add(days => -1);

    my @res;

    my %docs = App::OrgUtils::_load_org_files(
        $files, {time_zone=>$tz});
    for my $file (keys %docs) {
        my $doc = $docs{$file};
        $doc->walk(
            sub {
                my ($el) = @_;
                return unless $el->isa('Org::Element::Headline');
                _process_hl($file, $el, \%args, \@res)
            });
    }

    if ($sort) {
        if (ref($sort) eq 'CODE') {
            @res = sort $sort @res;
        } elsif ($sort =~ /^-?due_date$/) {
            @res = sort {
                my $dt1 = $a->[1];
                my $dt2 = $b->[1];
                my $comp;
                if ($dt1 && !$dt2) {
                    $comp = -1;
                } elsif (!$dt1 && $dt2) {
                    $comp = 1;
                } elsif (!$dt1 && !$dt2) {
                    $comp = 0;
                } else {
                    $comp = DateTime->compare($dt1, $dt2);
                }
                ($sort =~ /^-/ ? -1 : 1) * $comp;
            } @res;
        }
    }

    my $res;
    if ($args{group_by_tags}) {
        my %seen;

        # cache tags in each @res element's [3] element
        for (@res) { $_->[3] = [$_->[2]->get_tags] }
        my @tags = sort(uniq(map {@{$_->[3]}} @res));
        $res = {};
        for my $tag ('', @tags) {
            $res->{$tag} = [];
            for (@res) {
                if ($tag eq '') {
                    next if @{$_->[3]};
                } else {
                    next unless $tag ~~ @{$_->[3]};
                }
                next if !$args{allow_duplicates} && $seen{$_->[0]}++;
                push @{ $res->{$tag} }, $_->[0];
            }
        }
    } else {
        $res = [map {$_->[0]} @res];
    }

    [200, "OK", $res];
}

1;
#ABSTRACT:

=head1 SYNOPSIS

 # See list-org-headlines script


=head1 DESCRIPTION


=cut
