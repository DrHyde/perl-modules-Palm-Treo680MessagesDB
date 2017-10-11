package Palm::Treo680MessagesDB;

use strict;
use warnings;

use Palm::Raw();
use DateTime;
use Data::Hexdumper ();

use vars qw($VERSION @ISA $timezone $incl_raw $debug $multipart);

$VERSION = '1.02';
@ISA = qw(Palm::Raw);
$timezone = 'Europe/London';
$debug = 0;
$incl_raw = 0;

$multipart = {};

sub import {
    my $class = shift;
    my %opts = @_;
    $timezone = $opts{timezone} if(exists($opts{timezone}));
    $incl_raw = $opts{incl_raw} if(exists($opts{incl_raw}));
    $debug    = $opts{debug}    if(exists($opts{debug}));
    Palm::PDB::RegisterPDBHandlers(__PACKAGE__, [MsSt => 'MsDb']);

    if(!$debug) {
        no warnings;
        my $orig_Load = \&Palm::PDB::Load;
        *Palm::PDB::Load = sub {
            $orig_Load->(@_);
            $_[0]->{records} = [
                grep {
                    $_->{type} ne 'unknown' &&
                    !(exists($_->{epoch}) && $_->{epoch} < 946684800) # 2000-01-01 00:00
                } @{$_[0]->{records}}
            ] if(
                $_[0]->{creator} eq 'MsSt' &&
                $_[0]->{type}    eq 'MsDb'
            );
        }
    }
}

=head1 NAME

Palm::Treo680MessagesDB - Handler for Treo 680 SMS message databases

=head1 SYNOPSIS

    use Palm::PDB;
    use Palm::Treo680MessagesDB timezone => 'Europe/London';
    use Data::Dumper;

    my $pdb = Palm::PDB->new();
    $pdb->Load("MessagesDB.pdb");
    print Dumper(@{$pdb->{records}});

=head1 DESCRIPTION

This is a helper class for the Palm::PDB package, which parses the
database generated by a Treo 680 as a record of all your SMSes.

=head1 OPTIONS

You can set some global options when you 'use' the module:

=over

=item timezone

Defaults to 'Europe/London'.

=item incl_raw

Whether to include the raw binary blob of data in the parsed records.
Defaults to false.

=item debug

Defaults to false.

If false, unknown record-types and those which look like they weren't
parsed properly (eg they have an impossible timestamp) are suppressed.
This is done by over-riding Palm::PDB's C<Load()> method.

If true, include a hexadecimal dump of each record in the 'debug'
field, and don't suppress unknown or badly parsed records.

=back

=head1 METHODS

This class inherits from Palm::Raw, so has all of its methods.  The
folliwing are over-ridden, and differ from that in the parent class
thus:

=head2 ParseRecord

Returns data structures with the following keys:

=over

=item rawdata

The raw data blob passed to the method.  This is only present if the
incl_raw option is true.

=item date

The date of the message, if available, in YYYY-MM-DD format

=item time

The time of the message, if available, in HH:MM format

=item epoch or timestamp (it's available under both names)

The epoch time of the message, if available.  Note that because
the database doesn't
store the timezone, we assume 'Europe/London' when converting this
to the seperate date and time fields.  If you want to change
that, then suppy a timezone option when you 'use' the module.

Note that this is always the Unix epoch time, even though PalmOS
uses an epoch based on 1904.

=item name

The name of the other party, which the Treo extracts from the SIM
phone-book or from the Palm address book at the time the SMS is saved.

=item number or phone

The number of the other party.  This is not normalised so you might see
the same number in different formats, eg 07979866975 and +447979866975.
I may add number normalisation in the future.

=item direction

Either 'incoming', or 'outgoing'.

=back

Other fields may be added in the future.

=cut

sub ParseRecord {
    my $self = shift;
    my %record = @_;

    $record{rawdata} = delete($record{data});
    my $parsed = _parseblob($record{rawdata});
    delete $record{rawdata} unless($incl_raw);

    return {%record, %{$parsed}};
}

sub _parseblob {
    my $buf = shift;
    my %record = ();

    my $type = 256 * ord(substr($buf, 10, 1)) + ord(substr($buf, 11, 1));
    my($dir, $num, $name, $msg) = ('', '', '', '');
    if($type == 0x400C || $type == 0x4009) { # 4009 not used by 680?
        $dir = ($type == 0x400C) ? 'inbound' : 'outbound';

        # ASCIIZ number starting at 0x22
        ($num  = substr($buf, 0x22)) =~ s/\00.*//s;

        # immediately followed by ASCIIZ name, with some trailing 0s
        $name = substr($buf, length($num) + 1 + 0x22);
        $name =~ /^([^\00]*?)\00+(.*)$/s;
        ($name, my $after_name) = ($1, $2);

        # four unknown bytes, then ASCIIZ message
        ($msg = substr($after_name, 4)) =~ s/\00.*//s;

        # two unknown bytes, then 32-bit time_t, but with 1904 epoch
        my $epoch = substr($after_name, 4 + length($msg) + 1 + 2, 4);

        $record{epoch} =
                 0x1000000 * ord(substr($epoch, 0, 1)) +
                 0x10000   * ord(substr($epoch, 1, 1)) +
                 0x100     * ord(substr($epoch, 2, 1)) +
                             ord(substr($epoch, 3, 1)) -
                 2082844800; # offset from Palm epoch (1904) to Unix

        # if is because DateTime::from_epoch seems to DTwrongT on Win32
        # when you get a negative epoch
        if($record{epoch} > 0) {
            my $dt = DateTime->from_epoch(
                epoch => $record{epoch},
                time_zone => $timezone
            );
            $record{date} = sprintf('%04d-%02d-%02d', $dt->year(), $dt->month(), $dt->day());
            $record{time} = sprintf('%02d:%02d', $dt->hour(), $dt->minute());
        }
    } elsif($type == 0x0002) {
        $dir = 'outbound';

        # ASCIIZ number starting at 0x46
        ($num  = substr($buf, 0x46)) =~ s/\00.*//s;

        # immediately followed by ASCIIZ name, with some trailing 0s
        # some Trsm gibberish, then an ASCIIZ message
        # $name = substr($buf, length($num) + 1 + 0x46);
        # $name =~ /^([^\00]+)\00+.Trsm....([^\00]+)\00.*$/s;
        # ($name, $msg) = ($1, $2);
        ($name = substr($buf, length($num) + 1 + 0x46)) =~ s/\00.*//s;
        $name = undef unless(length($name));
        $name .= " (may be truncated)" if($name && length($name) == 31);
        ($msg = $buf) =~ s/^.*?Trsm....(([^\00]+)\00.*)$/$2/s;

        # 32-bit time_t, but with 1904 epoch
        my $epoch = substr($buf, 0x24, 4);
        $record{epoch} =
                 0x1000000 * ord(substr($epoch, 0, 1)) +
                 0x10000   * ord(substr($epoch, 1, 1)) +
                 0x100     * ord(substr($epoch, 2, 1)) +
                             ord(substr($epoch, 3, 1)) -
                 2082844800;
        my $dt = DateTime->from_epoch(
            epoch => $record{epoch},
            time_zone => $timezone
        );
        $record{date} = sprintf('%04d-%02d-%02d', $dt->year(), $dt->month(), $dt->day());
        $record{time} = sprintf('%02d:%02d', $dt->hour(), $dt->minute());

        if($msg eq "\01N@" && length($1) == 14) { # no real body. bleh
            delete @record{qw(epoch date time)};
            $type = 'unknown';
        }
    } elsif($type == 0x0001) {
        $dir = 'outbound';

        # number field at 0x4C, possibly including some leading crap
        # then an ASCIIZ number
        ($num  = substr($buf, 0x4C)) =~ s/(^\00*[^\00]+)\00.*/$1/s;

        # immediately followed by ASCIIZ name, with some trailing 0s
        ($name = substr($buf, length($num) + 0x4C + 1)) =~ s/\00.*//s;

        # ASCIIZ message, prefixed by 0x20 0x02 16-bit length word
        $msg = substr($buf, length($num) + 0x4C + 1 + length($name) + 1);
        $msg =~ s/^.*\x20\x02..|\00.*$//g;
        
        $num =~ s/^[^0-9+]+//; # clean leading rubbish from number

        my $epoch = substr($buf, 0x24, 4);
        $record{epoch} =
                 0x1000000 * ord(substr($epoch, 0, 1)) +
                 0x10000   * ord(substr($epoch, 1, 1)) +
                 0x100     * ord(substr($epoch, 2, 1)) +
                             ord(substr($epoch, 3, 1)) -
                 2082844800;
        my $dt = DateTime->from_epoch(
            epoch => $record{epoch},
            time_zone => $timezone
        );
        $record{date} = sprintf('%04d-%02d-%02d', $dt->year(), $dt->month(), $dt->day());
        $record{time} = sprintf('%02d:%02d', $dt->hour(), $dt->minute());

        if($num eq '') {
            delete @record{qw(epoch date time)};
            $type = 'unknown';
        }
    } elsif($type == 0x0000 && substr($buf, 0x0040, 1) ne "\00") {
        $dir = 'outbound';

        # message first, preceded by 0x2002 and 16 bit length
        ($msg = $buf) =~ s/^.*\040\02..//s;
        $msg =~ s/\00.*//s;

        # then some cruft, ASCIIZ number and name
        # find number by finding *last* sequence of 6 or more digits, then
        # going back 1 to find a + if it's there
        ($num, $name) = split(/\00/, ($buf =~ /(\+?\d{6,}\00[^\00]+\00)/g)[-1]);

        my $epoch = substr($buf, index($buf, "\x80\00") + 2, 4);
        $record{epoch} =
                 0x1000000 * ord(substr($epoch, 0, 1)) +
                 0x10000   * ord(substr($epoch, 1, 1)) +
                 0x100     * ord(substr($epoch, 2, 1)) +
                             ord(substr($epoch, 3, 1)) -
                 2082844800;
        my $dt = DateTime->from_epoch(
            epoch => $record{epoch},
            time_zone => $timezone
        );
        $record{date} = sprintf('%04d-%02d-%02d', $dt->year(), $dt->month(), $dt->day());
        $record{time} = sprintf('%02d:%02d', $dt->hour(), $dt->minute());

        if($num eq '') {
            delete @record{qw(epoch date time)};
            $type = 'unknown';
        }
    } elsif($type == 0x0000) {
        $dir = 'outbound';

        # number field at 0x4C, possibly including some leading crap
        # then an ASCIIZ number
        ($num  = substr($buf, 0x4C)) =~ s/(^\00*[^\00]+)\00.*/$1/s;

        # immediately followed by ASCIIZ name, with some trailing 0s
        ($name = substr($buf, length($num) + 0x4C + 1)) =~ s/\00.*//s;

        # ASCIIZ message, prefixed by 0x20 0x02 16-bit length word
        $msg = substr($buf, length($num) + 0x4C + 1 + length($name) + 1);
        $msg =~ s/^.*\x20\x02..|\00.*$//g;
        
        $num =~ s/^[^0-9+]+//; # clean leading rubbish from number

        my $epoch = substr($buf, 0x24, 4);
        $record{epoch} =
                 0x1000000 * ord(substr($epoch, 0, 1)) +
                 0x10000   * ord(substr($epoch, 1, 1)) +
                 0x100     * ord(substr($epoch, 2, 1)) +
                             ord(substr($epoch, 3, 1)) -
                 2082844800;
        my $dt = DateTime->from_epoch(
            epoch => $record{epoch},
            time_zone => $timezone
        );
        $record{date} = sprintf('%04d-%02d-%02d', $dt->year(), $dt->month(), $dt->day());
        $record{time} = sprintf('%02d:%02d', $dt->hour(), $dt->minute());

        if($num eq '') {
            delete @record{qw(epoch date time)};
            $type = 'unknown';
        }
    } else {
        $type = 'unknown';
    }
    $record{debug} = "\n".Data::Hexdumper::hexdump(suppress_warnings => 1, data => $buf) if($debug);
    $record{device}    = 'Treo 680';
    $record{direction} = $dir;  # inbound or outbound
    $record{phone}     = $record{number} = $num;
    $record{timestamp} = $record{epoch};
    $record{name}      = $name;
    $record{text}      = $msg;
    $record{type}      = $type eq 'unknown' ? $type : sprintf('0x%04X', $type);
    return \%record;
}

=head1 BUGS, LIMITATIONS and FEEDBACK

The database structure is undocumented.  Consequently it has had to be
reverse-engineered.  There appear to be several message formats in
the database.  Some have a superficial resemblance to those used by
the 650 (and which is partially documented by Palm) but there is no
publicly available documentation that I could find for the others -
if you know where I can get docs, please let me know!

I can only reverse-engineer record formats that appear on my phone, so
there may be some missing.  In addition, I may decode some formats
incorrectly because they're not quite what I thought they were.  If
this affects you, please please please send me the offending data.

There is currently no support for creating a new database, or for
editing the contents of an existing database.  If you need that
functionality, please submit a patch with tests.  I will *not* write
this myself unless I need it.  Behaviour if you try to create or
edit a database is currently undefined, but editing a database will
almost certainly break it.

Bug reports should be made on Github or by email.
Ideally, I would like to receive
sample data and a test file, which fails with the latest version of
the module but will pass when I fix the bug.

Sample data can be either in the form of a complete database, or a
dump of just a single record structure, which *must* include the
raw binary data -
use the 'incl_raw' option when you load the module, and save the
data structure to a file using Data::Dumper.
Feel free to obscure
real names, phone numbers, and messages in the data, but you
should ensure that phone numbers are correctly formed, and that
you don't change the length of any parts of the message.  Also,
please don't change any non-human-readable parts of the record.

=head1 SEE ALSO

L<Palm::SMS>, which handles SMS messages databases on some other models
of Treo.

L<Palm::PDB>

L<DateTime>

=head1 THANKS TO

Michal Seliga, for sample MMS data

=head1 AUTHOR, COPYRIGHT and LICENCE

Copyright 2008 David Cantrell E<lt>david@cantrell.org.ukE<gt>

This software is free-as-in-speech software, and may be used,
distributed, and modified under the terms of either the GNU
General Public Licence version 2 or the Artistic Licence. It's
up to you which one you use. The full text of the licences can
be found in the files GPL2.txt and ARTISTIC.txt, respectively.

=head1 CONSPIRACY

This module is also free-as-in-mason software.

=cut

1;
