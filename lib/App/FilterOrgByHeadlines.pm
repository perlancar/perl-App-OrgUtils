package App::FilterOrgByHeadlines;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;

our %SPEC;

sub _match {
    my ($hl, $op) = @_;
    if (ref($op) eq 'Regexp') {
        return $hl =~ $op;
    } elsif ($op =~ m!\A/(.*)/(i?)\z!) {
        my $re;
        # XXX possible arbitrary code execution
        eval "\$re = qr/$1/$2";
        die if $@;
        return $hl =~ $re;
    } else {
        return index($hl, $op) >= 0;
    }
}

$SPEC{filter_org_by_headlines} = {
    v => 1.1,
    summary => 'Filter Org by headlines',
    description => <<'_',

This routine uses simple regex instead of Org::Parser, for faster performance.

_
    args => {
        input => {
            #schema => ['any*', of => ['str*', ['array*', of => 'str*']]],
            schema => ['str*'],
            description => <<'_',

Value is either a string or an array of strings.

_
            req => 1,
            pos => 0,
            cmdline_src => 'stdin_or_files',
        },
        min_level => {
            schema => 'int*',
            tags => ['category:filtering'],
        },
        max_level => {
            schema => 'int*',
            tags => ['category:filtering'],
        },
        level => {
            schema => 'int*',
            tags => ['category:filtering'],
        },
        match => {
            schema => ['any*', of=>['str*', 're*']],
            summary => 'Only include headline which matches this',
            description => <<'_',

Value is either a string or a regex. If string is in the form of `/.../` or
`/.../i` it is assumed to be a regex.

_
            tags => ['category:filtering'],
        },
        parent_match => {
            schema => ['any*', of=>['str*', 're*']],
            summary => 'Only include headline whose parent matches this',
            description => <<'_',

Value is either a string or a regex. If string is in the form of `/.../` or
`/.../i` it is assumed to be a regex.

_
            tags => ['category:filtering'],
        },
        ascendant_match => {
            schema => ['any*', of=>['str*', 're*']],
            summary => 'Only include headline whose ascendant matches this',
            description => <<'_',

Value is either a string or a regex. If string is in the form of `/.../` or
`/.../i` it is assumed to be a regex.

_
            tags => ['category:filtering'],
        },
        is_todo => {
            schema => 'bool',
            summary => 'Only include headline which is a todo item',
            'summary.alt.bool.not' =>
                'Only include headline which is not a todo item',
            tags => ['category:filtering'],
        },
        is_done => {
            schema => 'bool',
            summary => 'Only include headline which is a done todo item',
            'summary.alt.bool.not' =>
                'Only include headline which is a todo item but not done',
            tags => ['category:filtering'],
        },
        has_tags => {
            'x.name.is_plural' => 1,
            schema => ['array*', of=>'str*'],
            summary => 'Only include headline which have all these tags',
            tags => ['category:filtering'],
        },
        lacks_tags => {
            'x.name.is_plural' => 1,
            schema => ['array*', of=>'str*'],
            summary => 'Only include headline which lack all these tags',
            tags => ['category:filtering'],
        },

        # XXX todo_state => str*
        with_content => {
            schema => 'bool',
            summary => 'Include headline content',
            'summary.alt.bool.not' =>
                "Don't include headline content, just print the headlines",
            default => 1,
            tags => ['category:result'],
        },
        with_preamble => {
            schema => 'bool',
            summary => 'Include text before any headline',
            'summary.alt.bool.not' =>
                "Don't include text before any headline",
            default => 1,
            tags => ['category:result'],
        },
        return_array => {
            schema => ['bool*', is=>1],
            summary => 'Return array of strings instead of strings',
            tags => ['category:result'],
        },
    },
    result_naked => 1,
    result => {
        schema => ['any*', of=>['str*', ['array*', of=>'str*']]],
    },
};
sub filter_org_by_headlines {
    my %args = @_;

    my $input    = $args{input};
    my $with_ct  = $args{with_content} // 1;
    my $with_pre = $args{with_preamble} // 1;

    my $curhl;
    my $curlevel;
    my $curtodokw;
    my $curhl_filtered;
    my $curtags;
    my @parenthls; # ([hl, level], ...)

    my %todo_keywords = map {$_=>1} qw(TODO);
    my %done_keywords = map {$_=>1} qw(DONE);
    my $seen_todo_def;

    my $out;
  LINE:
    for my $line (ref($input) ? @$input : split(/^/, $input)) {
        my $is_hl; # whether current line is a headline
        if ($line =~ /^#\+TODO:\s*(.+)/) {
            my $arg = $1;
            if (!$seen_todo_def++) {
                %todo_keywords = ();
                %done_keywords = ();
            }
            my $done_s = $arg =~ s/\s*\|\s*(.*)// ? $1 : '';
            my $todo_s = $arg;
            $todo_keywords{$_}++ for grep {length} split /\s+/, $todo_s;
            $done_keywords{$_}++ for grep {length} split /\s+/, $done_s;
        } elsif ($line =~ /^(\*+)\s+(.*)/) {
            $is_hl++;

            my $level = length($1);
            my $arg = $2;

            if ($line =~ /\s+:(\w+(?::\w+)*):(?:\s+|$)/) {
                $curtags = [split /:/, $1];
            } else {
                undef $curtags;
            }

            if ($curlevel && $curlevel < $level) {
                push @parenthls, [$curhl, $curlevel];
            } elsif (@parenthls) {
                @parenthls = grep { $_->[1] < $level } @parenthls;
            }
            $curhl = $line;
            $curlevel = $level;

            $curtodokw = undef;
            if ($arg =~ /(\w+)\s/) {
                if ($todo_keywords{$1} || $done_keywords{$1}) {
                    $curtodokw = $1;
                }
            }

            undef $curhl_filtered;
        }

        # filtering
        my $include;
      FILTER: {
            if (!$curhl) {
                $include++ if $with_pre;
                last FILTER;
            }
            last if !$with_ct && !$is_hl;
            if (defined $curhl_filtered) {
                $include++ if !$curhl_filtered;
                last FILTER;
            }

            $curhl_filtered = 1 if $is_hl;
            if (defined $args{min_level}) {
                last if $curlevel < $args{min_level};
            }
            if (defined $args{max_level}) {
                last if $curlevel > $args{max_level};
            }
            if (defined $args{level}) {
                last if $curlevel != $args{level};
            }
            if (defined $args{is_todo}) {
                my $kw = $curtodokw // '';
                last if ( ($todo_keywords{$kw} || $done_keywords{$kw}) xor
                             $args{is_todo} );
            }
            if (defined $args{is_done}) {
                my $kw = $curtodokw // '';
                last unless $kw;
                last if ( $done_keywords{$kw} xor $args{is_done} );
            }
            if (defined $args{match}) {
                last unless _match($curhl, $args{match});
            }
            if ($args{has_tags}) {
                last unless $curtags;
                for my $t (@{ $args{has_tags} }) {
                    last FILTER unless grep {$t eq $_} @$curtags;
                }
            }
            if ($args{lacks_tags}) {
                for my $t (@{ $args{lacks_tags} }) {
                    last FILTER if grep {$t eq $_} @{$curtags//[]};
                }
            }
            if (defined $args{parent_match}) {
                last unless @parenthls;
                last unless _match($parenthls[-1][0], $args{parent_match});
            }
            if (defined $args{ascendant_match}) {
                for (@parenthls) {
                    do { $include++; last FILTER }
                        if _match($_->[0], $args{ascendant_match});
                }
                last;
            }
            $curhl_filtered = 0 if $is_hl;

            $include = 1;
        }
        if ($include) {
            if ($args{return_array}) {
                $out //= [];
                if ($is_hl) {
                    push @$out, $line;
                } else {
                    $out->[-1] .= $line;
                }
            } else {
                $out .= $line;
            }
        }
    }

    $out;
}

1;
# ABSTRACT:
