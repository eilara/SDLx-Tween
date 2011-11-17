use 5.010001;
use ExtUtils::MakeMaker;
use Alien::SDL;

$Verbose = 1;

WriteMakefile(
    NAME              => 'SDLx::Tween',
    VERSION_FROM      => 'lib/SDLx/Tween.pm', # finds $VERSION
    PREREQ_PM         => {
        'SDL'         => 2.533,
        'Moose'       => 2.0204,
        'Set::Object' => 1.28,
    },
    ABSTRACT_FROM     => 'lib/SDLx/Tween.pm',
    AUTHOR            => 'Ran Eilam <eilara@cpan.org>',
    LIBS              => Alien::SDL->config('libs', '-lm'),
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => Alien::SDL->config('cflags'). ' -I.',
    'MYEXTLIB'        => 'tweencee/libtweencee$(LIB_EXT) tailcee/libtailcee$(LIB_EXT)',
    OBJECT            => q/$(O_FILES)/,
);

sub MY::postamble {
'
$(MYEXTLIB): tweencee/Makefile tailcee/Makefile
	cd tweencee && $(MAKE) $(PASSTHRU)
	cd tailcee && $(MAKE) $(PASSTHRU)
';
}
