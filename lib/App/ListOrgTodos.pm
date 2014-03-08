package App::ListOrgTodos;

use 5.010;
use strict;
use warnings;
use Log::Any qw($log);

use App::ListOrgHeadlines qw(list_org_headlines);
use Data::Clone;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_todos);

# VERSION

our %SPEC;

my $spec = clone($App::ListOrgHeadlines::SPEC{list_org_headlines});
$spec->{summary} = "List all todo items in all Org files";
delete $spec->{args}{todo};
$spec->{args}{done}{schema}[1]{default} = 0;
$spec->{args}{sort}{schema}[1]{default} = 'due_date';
$spec->{"x.dist.zilla.plugin.rinci.wrap.wrap_args"} = {validate_args=>0, validate_result=>0}; # don't bother checking arguments, they will be checked in list_org_headlines()

$SPEC{list_org_todos} = $spec;
sub list_org_todos {
    my %args = @_;

    $args{done} //= 0;

    App::ListOrgHeadlines::list_org_headlines(%args, todo=>1);
}

1;
#ABSTRACT: List todo items in Org files

=head1 SYNOPSIS

 # See list-org-todos script


=head1 DESCRIPTION


=head1 FUNCTIONS

None are exported, but they are exportable.

=cut
