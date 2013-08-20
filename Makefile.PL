use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Perlresume',
    AUTHOR       => q{Viacheslav Tykhanovskyi <vti@cpan.org>},
    VERSION_FROM => 'lib/Perlresume.pm',
    ABSTRACT     => 'Perl resume',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'               => 0,
        'YAML'                     => 0,
        'Dancer'                   => 1.3030,
        'Dancer::Plugin::Database' => 0,
        'Dancer::Template::Caml'   => 0,
        'MetaCPAN::API'            => 0,
        'Plack'                    => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'Perlresume-*' },
);
