package App::OrgUtils;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use Org::Parser;

our %common_args1 = (
    files => {
        schema => ['array*' => of => 'str*', min_len=>1],
        req    => 1,
        pos    => 0,
        greedy => 1,
        'x.schema.element_entity' => 'filename',
        'x.name.is_plural' => 1,
    },
    time_zone => {
        schema => ['str'],
        summary => 'Will be passed to parser\'s options',
        description => <<'_',

If not set, TZ environment variable will be picked as default.

_
        'x.schema.entity' => 'timezone',
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
