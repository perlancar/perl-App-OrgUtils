package App::ListOrgTodos;

# DATE
# VERSION

use 5.010;
use strict;
use warnings;
use Log::Any::IfLOG qw($log);

use App::ListOrgHeadlines qw(list_org_headlines);
use Perinci::Sub::Util qw(gen_modified_sub);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_todos);

our %SPEC;

gen_modified_sub(
    output_name => 'list_org_todos',
    summary     => 'List all todo items in all Org files',

    base_name   => 'App::ListOrgHeadlines::list_org_headlines',
    remove_args => ['todo'],
    modify_args => {
        done => sub { my $as = shift; $as->{schema}[1]{default} = 0 },
        sort => sub { my $as = shift; $as->{schema}[1]{default} = 'due_date' },
    },
    modify_meta => sub {
        my $meta = shift;
        $meta->{"x.dist.zilla.plugin.rinci.wrap.wrap_args"} = {validate_args=>0, validate_result=>0}; # don't bother checking arguments, they will be checked in list_org_headlines()
    },
    output_code => sub {
        my %args = @_;

        $args{done} //= 0;

        App::ListOrgHeadlines::list_org_headlines(%args, todo=>1);
    },
);

1;
#ABSTRACT:

=head1 SYNOPSIS

 # See list-org-todos script


=head1 DESCRIPTION


=cut
