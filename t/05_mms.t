#!/usr/bin/perl -w
# $Id: 05_mms.t,v 1.1 2008/07/17 16:24:07 drhyde Exp $

use strict;
use vars qw($VAR1);

use Test::More tests => 1;

use Palm::PDB;
use Palm::Treo680MessagesDB;

my $pdb = Palm::PDB->new();
# $pdb->Load('t/regression/database.pdb');

local $/ = undef;

my @raw_records = map {
    open(RAW, "t/mms/$_") || die("Can't read t/mms/$_\n");
    my $r = <RAW>;
    close(RAW);
    $r;
} qw(ms-012.40.1232940.pdr ms-013.40.1232941.pdr ms-014.40.1232942.pdr);

open(FILE, 't/mms/ms.dd') || die("Can't read t/mms/ms.dd\n");
my $struct = eval <FILE>;
close(FILE);
is_deeply(
    ...
    $struct,
    "MMS data from Michal Seliga is parsed OK (without attachments)"
);
