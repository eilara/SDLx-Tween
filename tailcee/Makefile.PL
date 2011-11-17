use ExtUtils::MakeMaker;
use Alien::SDL;

$Verbose = 1;

WriteMakefile(
    NAME   => 'TailCee::tailcee',
    SKIP   => [qw(all static static_lib dynamic dynamic_lib)],
    INC    => Alien::SDL->config('cflags'). ' -I.',
    clean  => {'FILES' => 'libtailcee$(LIB_EXT)'},
);

sub MY::top_targets {
'
all      :: static
pure_all :: static
static   :: libtailcee$(LIB_EXT)
libtailcee$(LIB_EXT): $(O_FILES)
	$(AR) cr libtailcee$(LIB_EXT) $(O_FILES)
	$(RANLIB) libtailcee$(LIB_EXT)
';
}

