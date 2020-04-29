package App::OrgUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010;
use strict;
use warnings;
use Log::ger;

use File::Slurper::Dash 'read_text';
use Org::Parser::Tiny;
use Sort::Sub;

our %SPEC;

our %common_args1 = (
    files => {
        schema => ['array*' => of => 'filename*', min_len=>1],
        req    => 1,
        pos    => 0,
        greedy => 1,
        'x.name.is_plural' => 1,
    },
    time_zone => {
        schema => ['date::tz_name'],
        summary => 'Will be passed to parser\'s options',
        description => <<'_',

If not set, TZ environment variable will be picked as default.

_
    },
);

our %arg0_file = (
    file => {
        summary => 'Path to an Org file',
        description => <<'_',

"-" means standard input.

_
        schema => 'filename*',
        default => '-',
        pos => 0,
    },
);

our $_complete_state = sub {
    use experimental 'smartmatch';
    require Complete::Util;

    my %args = @_;

    # only return answer under CLI
    return undef unless my $cmdline = $args{cmdline};
    my $r = $args{r};

    # force read config
    $r->{read_config} = 1;
    my $res = $cmdline->parse_argv($r);
    return undef unless $res->[0] == 200;
    my $args = $res->[2];

    # read org
    return unless $args->{files} && @{ $args->{files} };
    my $tz = $args->{time_zone} // $ENV{TZ} // "UTC";
    my %docs = App::OrgUtils::_load_org_files(
        [grep {-f} @{ $args->{files} }], {time_zone=>$tz});

    # get todo states
    my @states;
    for my $doc (values %docs) {
        for (@{ $doc->todo_states }, @{ $doc->done_states }) {
            push @states, $_ unless $_ ~~ @states;
        }
    }
    Complete::Util::complete_array_elem(array=>\@states, word=>$args{word});
};

our $_complete_priority = sub {
    use experimental 'smartmatch';
    require Complete::Util;

    my %args = @_;

    # only return answer under CLI
    return undef unless my $cmdline = $args{cmdline};
    my $r = $args{r};

    # force read config
    $r->{read_config} = 1;
    my $res = $cmdline->parse_argv($r);
    return undef unless $res->[0] == 200;
    my $args = $res->[2];

    # read org
    return unless $args->{files} && @{ $args->{files} };
    my $tz = $args->{time_zone} // $ENV{TZ} // "UTC";
    my %docs = App::OrgUtils::_load_org_files(
        [grep {-f} @{ $args->{files} }], {time_zone=>$tz});

    # get priorities
    my @prios;
    for my $doc (values %docs) {
        for (@{ $doc->priorities }) {
            push @prios, $_ unless $_ ~~ @prios;
        }
    }
    Complete::Util::complete_array_elem(array=>\@prios, word=>$args{word});
};

our $_complete_tags = sub {
    use experimental 'smartmatch';
    require Complete::Util;

    my %args = @_;

    # only return answer under CLI
    return undef unless my $cmdline = $args{cmdline};
    my $r = $args{r};

    # force read config
    $r->{read_config} = 1;
    my $res = $cmdline->parse_argv($r);
    return undef unless $res->[0] == 200;
    my $args = $res->[2];

    # read org
    return unless $args->{files} && @{ $args->{files} };
    my $tz = $args->{time_zone} // $ENV{TZ} // "UTC";
    my %docs = App::OrgUtils::_load_org_files(
        [grep {-f} @{ $args->{files} }], {time_zone=>$tz});

    # collect tags
    my @tags;
    for my $doc (values %docs) {
        $doc->walk(
            sub {
                my $el = shift;
                return unless $el->isa('Org::Element::Headline');
                for ($el->get_tags) {
                    push @tags, $_ unless $_ ~~ @tags;
                }
            }
        );
    }
    Complete::Util::complete_array_elem(array=>\@tags, word=>$args{word});
};

sub _load_org_files {
    require Cwd;
    require Digest::MD5;
    require Org::Parser;

    my ($files, $opts0) = @_;
    $files or die "Please specify files";

    my $orgp = Org::Parser->new;
    my %docs;
    for my $file (@$files) {
        my $opts = { %{$opts0 // {}} };
        # by default turn on cache, unless user specifically has
        # PERL_ORG_PARSER_CACHE set to 0.
        $opts->{cache} = 1 if $ENV{PERL_ORG_PARSER_CACHE} // 1;
        $docs{$file} = $orgp->parse_file($file, $opts);
    }

    %docs;
}

sub _parse_org_with_tiny {
    require Org::Parser::Tiny;

    my $file = shift;

    my $doc = Org::Parser::Tiny->new->parse(read_text($file));
    $doc;
}

sub _sort {
    my ($node, $level, $sorter, $sorter_meta) = @_;

    my @children = @{ $node->children // [] };
    return unless @children;

    # recurse depth-first to sort the children's children
    for my $child (@children) {
        next unless $child->can("children");
        my $grandchildren = $child->children;
        next unless $grandchildren && @$grandchildren;
        _sort($child, $level, $sorter, $sorter_meta);
    }

    my $has_level_sub = sub {
        $_->isa("Org::Parser::Tiny::Node::Headline") &&
            $_->level == $level
    };
    return unless grep { $has_level_sub->($_) } @children;

    my $child_has_level_sub = sub {
        $children[$_]->isa("Org::Parser::Tiny::Node::Headline") &&
            $children[$_]->level == $level
    };

    require Sort::SubList;
    my @sorted_children =
        map { $children[$_] }
        Sort::SubList::sort_sublist(
            sub {
                if ($sorter_meta->{compares_record}) {
                    my $rec0 = [$children[$_[0]]->as_string, $_[0]];
                    my $rec1 = [$children[$_[1]]->as_string, $_[1]];
                    $sorter->($rec0, $rec1);
                } else {
                    $sorter->($children[$_[0]]->as_string, $children[$_[1]]->as_string);
                }
            },
            $child_has_level_sub,
            0..$#children);
    $node->children(\@sorted_children);
}

$Sort::Sub::argsopt_sortsub{sort_sub}{cmdline_aliases} = {S=>{}};
$Sort::Sub::argsopt_sortsub{sort_args}{cmdline_aliases} = {A=>{}};

$SPEC{sort_org_headlines} = {
    v => 1.1,
    summary => '',
    args => {
        %arg0_file,
        level => {
            schema => ['posint*'],
            default => 1,
        },
        %Sort::Sub::argsopt_sortsub,
    },
    result_naked => 1,
};
sub sort_org_headlines {
    my %args = @_;

    my $sortsub_routine = $args{sort_sub} // 'asciibetically';
    my $sortsub_args    = $args{sort_args} // {};
    my ($sorter, $sorter_meta) =
        Sort::Sub::get_sorter($sortsub_routine, $sortsub_args, 'with meta');

    my $level = $args{level} // 1;

    my $doc = _parse_org_with_tiny($args{file});
    _sort($doc, $level, $sorter, $sorter_meta);
    $doc->as_string;
}

$SPEC{reverse_org_headlines} = {
    v => 1.1,
    summary => 'Reverse Org headlines',
    args => {
        %arg0_file,
        level => {
            schema => ['posint*'],
            default => 1,
        },
    },
    result_naked => 1,
};
sub reverse_org_headlines {
    my %args = @_;
    sort_org_headlines(%args, sort_sub=>'record_by_reverse_order');
}

1;
#ABSTRACT: Some utilities for Org documents

=head1 DESCRIPTION

This distribution includes a few modules (scripts) for dealing with Org
documents; some originally created as examples/demos for L<Org::Parser>. The
following are the included scripts:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<Org::Parser>

L<orgsel> in L<App::orgsel>

=cut
