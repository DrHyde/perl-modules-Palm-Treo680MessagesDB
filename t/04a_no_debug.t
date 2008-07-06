#!/usr/bin/perl -w

use strict;

use Test::More tests => 2;

use Palm::PDB;
use Palm::Treo680MessagesDB;

my $pdb = Palm::PDB->new();
$pdb->Load('t/messages-database.pdb');

my @records = @{$pdb->{records}};

my $record = $records[0];
ok($record->{offset} == 9693, "got right record");
ok(!exists($record->{debug}), "and no hex dump");
