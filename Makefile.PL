use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Palm::Treo680MessagesDB',
    VERSION_FROM => 'lib/Palm/Treo680MessagesDB.pm',
    PREREQ_PM    => {
        Palm::PDB       => 1.29,
        DateTime        => 0.30,
	Data::Hexdumper => 0,
    }
);
