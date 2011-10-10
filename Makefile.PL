use 5.010001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'SDLx::Tween',
    VERSION_FROM      => 'lib/SDLx/Tween.pm', # finds $VERSION
    PREREQ_PM         => {
        'XS::Object::Magic' => 0.04,
        'SDL'               => 2.533,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/SDLx/Tween.pm', # retrieve abstract from module
       AUTHOR         => 'Ran Eilam <eilara@cpan.org>') : ()),
    LIBS              => ['-lm -lSDL'], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => '-I.', # e.g., '-I. -I/usr/include/other'
    'MYEXTLIB'        => 'tweencee/libtweencee$(LIB_EXT)',
#    OBJECT            => q/$(O_FILES)/,
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);

sub MY::postamble {
'
$(MYEXTLIB): tweencee/Makefile
	cd tweencee && $(MAKE) $(PASSTHRU)
';
}
