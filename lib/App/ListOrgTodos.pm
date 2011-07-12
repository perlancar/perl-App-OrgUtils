package App::ListOrgTodos;

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

# VERSION

our %SPEC;

my $spec = clone($App::ListOrgHeadlines::SPEC{list_org_headlines});
$spec->{summary} = "List all todo items in all Org files";
delete $spec->{args}{todo};
#$spec->{args}{due_in}[1]{default} = 0;

$SPEC{list_org_todos} = $spec;
sub list_org_todos {
    my %args = @_;
    #$args{due_in} //= 0;

    App::ListOrgHeadlines::list_org_headlines(%args, todo=>1);
}

1;
#ABSTRACT: List todo items in Org files
__END__

=head1 SYNOPSIS

 # See list-org-todos script


=head1 DESCRIPTION


=head1 FUNCTIONS

None are exported, but they are exportable.

=cut
