package App::ListOrgHeadlinesFast;

use 5.010;
use strict;
use warnings;

use App::FilterOrgByHeadlines;
use Function::Fallback::CoreOrPP qw(clone);

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'List & count Org headlines & todos',
};

$SPEC{list_org_headlines} = do {
    my $meta = clone $App::FilterOrgByHeadlines::SPEC{filter_org_by_headlines};
    $meta->{summary} = 'List Org headlines';
    delete $meta->{args}{with_content};
    delete $meta->{args}{with_preamble};
    delete $meta->{args}{return_array};
    $meta->{result}{schema} = ['array*', of=>'str*'];
    $meta;
};
sub list_org_headlines {
    my %args = @_;

    my $headlines = App::FilterOrgByHeadlines::filter_org_by_headlines(
        %args,
        with_content => 0,
        with_preamble => 0,
        return_array => 1,
    );

    chomp for @$headlines;
    $headlines;
}

$SPEC{list_org_todos} = do {
    my $meta = clone $SPEC{list_org_headlines};
    $meta->{summary} = 'List Org todos';
    delete $meta->{args}{is_todo};
    $meta;
};
sub list_org_todos {
    my %args = @_;

    list_org_headlines(
        %args,
        is_todo => 1,
    );
}

$SPEC{count_org_headlines} = do {
    my $meta = clone $SPEC{list_org_headlines};
    $meta->{summary} = 'Count Org headlines';
    $meta->{result}{schema} = ['int*'];
    $meta;
};
sub count_org_headlines {
    my %args = @_;

    my $res = list_org_headlines(%args);
    ~~@$res;
}

$SPEC{count_org_todos} = do {
    my $meta = clone $SPEC{count_org_headlines};
    $meta->{summary} = 'Count Org todos';
    delete $meta->{args}{is_todo};
    $meta;
};
sub count_org_todos {
    my %args = @_;

    count_org_headlines(
        %args,
        is_todo => 1,
    );
}

1;
# ABSTRACT:
