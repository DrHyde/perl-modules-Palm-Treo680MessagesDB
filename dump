#!perl -Ilib

use strict;
use warnings;

use Palm::PDB;
use Palm::Treo680MessagesDB debug => 1;
use Data::Dumper;

my $pdb = Palm::PDB->new();
$pdb->Load("palm-messages-database.pdb");

foreach my $record (
    @{$pdb->{records}}
) {
    print Dumper($record);
}
