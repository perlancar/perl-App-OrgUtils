package App::OrgUtils;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use Org::Parser;

# VERSION

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
__END__

=head1 DESCRIPTION

This distribution includes a few modules (scripts) for dealing with Org
documents; some originally created as examples/demos for L<Org::Parser>.


=head1 SEE ALSO

L<Org::Parser>

=cut
