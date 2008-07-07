#!/usr/bin/perl -w
# $Id: 02a-default-timezone.t,v 1.2 2008/07/07 18:06:32 drhyde Exp $

use strict;

use Test::More tests => 2;

use Palm::PDB;
use Palm::Treo680MessagesDB;

my $pdb = Palm::PDB->new();
$pdb->Load('t/messages-database.pdb');

my @records = @{$pdb->{records}};

my $record = $records[0];
ok($record->{date} eq '2007-06-06', "Date calculated correctly for default timezone");
ok($record->{time} eq '00:04',      "Time calculated correctly for default timezone");
