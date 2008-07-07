#!/usr/bin/perl -w
# $Id: 04b_debug.t,v 1.2 2008/07/07 18:06:32 drhyde Exp $

use strict;

use Test::More tests => 2;

use Palm::PDB;
use Palm::Treo680MessagesDB debug => 1;

my $pdb = Palm::PDB->new();
$pdb->Load('t/messages-database.pdb');

my @records = @{$pdb->{records}};

my $record = $records[0];
ok($record->{offset} == 4968, "got right record");
ok($record->{debug} =~ /0x0000/, "and a hex dump");
