
use strict;
use warnings;
use Test::More;
use SDLx::Tween;

{ # basic complete

my ($registered, $unregistered, @last_tick);

my $iut = SDLx::Tween->new(
    register_cb   => sub { $registered   = shift },
    unregister_cb => sub { $unregistered = shift },
    tick_cb       => sub { @last_tick = @_ },
    duration      => 30,
    from          => 500,
    to            => 600,
);

is($registered, undef, 'not yet registered with clock');
ok(!$iut->is_active, 'starts inactive');

$iut->start(100);

ok($iut->is_active, 'active after start');
is($registered, $iut, 'registered with clock');
is($iut->get_cycle_start_time, 100, 'cycle start time');

$iut->tick(110);

is($last_tick[0], 10, '1st tick elapsed');
is($last_tick[1], 10, '1st dt');

$iut->tick(131);

is($last_tick[0], 30, '2st tick elapsed');
is($last_tick[1], 21, '2st dt');
ok(!$iut->is_active, 'cycle complete');

}

#{ # stop
#
#}


done_testing;
