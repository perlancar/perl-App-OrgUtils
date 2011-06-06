package App:::ListOrgTodos;
#ABSTRACT: An application to list todo items in Org files

use 5.010;
use strict;
use warnings;
use Log::Any qw($log);

use App::ListOrgHeadlines qw(list_org_headlines);
use Data::Clone;
use DateTime;
use Org::Parser;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(list_org_todos);

our %SPEC;

my $spec = clone($App::ListOrgHeadlines::SPEC{list_org_headlines});
$spec->{summary} = "List all todo items in all Org files";
delete $spec->{args}{todo};

$SPEC{list_org_todos} = $spec;
sub list_org_todos {
    my %args = @_;

    App::ListOrgHeadlines::list_org_headlines(%args, todo=>1);
}

