use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'MR::APNS',
    VERSION_FROM      => 'lib/MR/APNS.pm',
    PREREQ_PM         => {
        'Mouse'                         => 0,
        'Mouse::Role'                   => 0,
        'Mouse::Util::TypeConstraints'  => 0,
        'File::Temp'                    => 0,
        'IO::Select'                    => 0,
        'Net::SSLeay'                   => 0,
        'JSON::XS'                      => 0,
        'Encode'                        => 0,
        'List::Util'                    => 0,
    },
    AUTHOR         => 'Sivirinov Ivan <catamoose@yandex.ru>'
);
