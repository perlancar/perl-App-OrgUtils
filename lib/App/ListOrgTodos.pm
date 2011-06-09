package App::ListOrgTodos;
#ABSTRACT: List todo items in Org files

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
#$spec->{args}{due_in}[1]{default} = 0;

$SPEC{list_org_todos} = $spec;
sub list_org_todos {
    my %args = @_;
    #$args{due_in} //= 0;

    App::ListOrgHeadlines::list_org_headlines(%args, todo=>1);
}

1;
__END__

=head1 SYNOPSIS

 # show todo items that are due today
 $ list-org-todos --due-in 0 ~/organizer/*.org


=head1 DESCRIPTION

list-org-todos is just list-org-headlines with todo => 1.


=head1 FUNCTIONS

None are exported, but they are exportable.

=cut
