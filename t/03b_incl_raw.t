#!/usr/bin/perl -w
# $Id: 03b_incl_raw.t,v 1.2 2008/07/07 18:06:32 drhyde Exp $

use strict;

use Test::More tests => 1;

use Palm::PDB;
use Palm::Treo680MessagesDB incl_raw => 1;

my $pdb = Palm::PDB->new();
$pdb->Load('t/messages-database.pdb');

my @records = @{$pdb->{records}};

my $record = $records[0];
ok($record->{rawdata} =~ /mail/, "Got raw data cos we asked for it");
