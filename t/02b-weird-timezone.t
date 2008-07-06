#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

use Palm::PDB;
use Palm::Treo680MessagesDB timezone => 'America/Chicago';

my $pdb = Palm::PDB->new();
$pdb->Load('t/messages-database.pdb');

my @records = @{$pdb->{records}};

my $record = $records[0];
ok($record->{date} eq '2007-06-05', "Date calculated correctly for a weird timezone");
ok($record->{time} eq '18:04',      "Time calculated correctly for a weird timezone");
