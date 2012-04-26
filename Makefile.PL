use 5.006; # need lexical warnings
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Palm::Treo680MessagesDB',
    META_MERGE => {
        license => 'other',
        resource => {
	    repository => 'https://github.com/DrHyde/perl-modules-Palm-Treo680MessagesDB'
        }
    },
    VERSION_FROM => 'lib/Palm/Treo680MessagesDB.pm',
    PREREQ_PM    => {
        Palm::PDB       => 1.29,
        DateTime        => 0.30,
        Data::Hexdumper => 0,
	Test::More      => 0
    },
    EXE_FILES => [qw(
        examples/treo680smsdump
    )]
);
