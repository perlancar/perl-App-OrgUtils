package App::OrgUtils;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use Org::Parser;

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
    my %docs = App::OrgUtils::_load_org_files_with_cache(
        [grep {-f} @{ $args->{files} }], $args->{cache_dir}, {time_zone=>$tz});

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
    my %docs = App::OrgUtils::_load_org_files_with_cache(
        [grep {-f} @{ $args->{files} }], $args->{cache_dir}, {time_zone=>$tz});

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
    my %docs = App::OrgUtils::_load_org_files_with_cache(
        [grep {-f} @{ $args->{files} }], $args->{cache_dir}, {time_zone=>$tz});

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

sub _load_org_files_with_cache {
    require Cwd;
    require Digest::MD5;

    my ($files, $cache_dir, $opts0) = @_;
    $files or die "Please specify files";

    my $orgp = Org::Parser->new;
    my %docs;
    for my $file (@$files) {
        my $cf;
        if ($cache_dir) {
            my $afile = Cwd::abs_path($file) or die "Can't find $file";
            my $afilel = $afile; $afilel =~ s!.+/!!;
            $cf = "$cache_dir/$afilel.".Digest::MD5::md5_hex($afile).
                ".storable";
            $log->debug("Parsing file $file (cache file $cf) ...");
        } else {
            $log->debug("Parsing file $file ...");
        }

        my $opts = { %{$opts0 // {}} };
        $opts->{cache_file} = $cf if $cf;
        $docs{$file} = $orgp->parse_file($file, $opts);
    }

    %docs;
}

1;
#ABSTRACT: Some utilities for Org documents

=head1 DESCRIPTION

This distribution includes a few modules (scripts) for dealing with Org
documents; some originally created as examples/demos for L<Org::Parser>.


=head1 SEE ALSO

L<Org::Parser>

=cut
