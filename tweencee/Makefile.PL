use ExtUtils::MakeMaker;
use Alien::SDL;

$Verbose = 1;

WriteMakefile(
    NAME   => 'TweenCee::tweencee',
    SKIP   => [qw(all static static_lib dynamic dynamic_lib)],
    INC    => Alien::SDL->config('cflags'). ' -I.',
    clean  => {'FILES' => 'libtweencee$(LIB_EXT)'},
);

sub MY::top_targets {
'
all      :: static
pure_all :: static
static   :: libtweencee$(LIB_EXT)
libtweencee$(LIB_EXT): $(O_FILES)
	$(AR) cr libtweencee$(LIB_EXT) $(O_FILES)
	$(RANLIB) libtweencee$(LIB_EXT)
';
}

