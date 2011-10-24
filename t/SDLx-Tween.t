
package SDLx::Tween::tests::Circle;
use Moose;
has radius   => (is => 'rw');
has position => (is => 'rw');

package main;
use strict;
use warnings;
use Test::More;
use SDLx::Tween;

{ # 1D basic complete 1d linear path and ease int method proxy

my ($registered, $unregistered);

my $circle = SDLx::Tween::tests::Circle->new(radius => 500);

my $iut = SDLx::Tween->new(
    register_cb   => sub { $registered   = shift },
    unregister_cb => sub { $unregistered = shift },
    duration      => 30_000,
    from          => 500,
    to            => 600,
    on            => $circle,
    set           => 'radius',
    round         => 1,
);

is($registered, undef, 'not yet registered with clock');
ok(!$iut->is_active, 'starts inactive');

$iut->start(20_000);

ok($iut->is_active, 'active after start');
is($registered, $iut, 'registered with clock');
is($registered->get_cycle_start_time, 20_000, 'cycle start time');

$iut->tick(23_000);
is($circle->radius, 510, '1st tick radius');

# 300k ticks a second on a 2005 dual core duo notebook
# for (1..6000000) { $iut->tick(20000+ $_); }

$iut->tick(50_100);
is($circle->radius, 600, '2nd tick radius');
ok(!$iut->is_active, 'cycle complete');

}

{ # 2D basic complete 1d linear path and ease int method proxy

my $circle = SDLx::Tween::tests::Circle->new(position => [100, 200]);

my $iut = SDLx::Tween->new(
    duration      => 10_000,
    from          => [100, 200],
    to            => [200, 400],
    on            => $circle,
    set           => 'position',
);

$iut->start(10_000);

$iut->tick(15_000);
is_deeply($circle->position, [150, 300], '1st tick position');

$iut->tick(17_500);
is_deeply($circle->position, [175, 350], '2nd tick position');

$iut->stop;
ok(!$iut->is_active, 'cycle stop');
is_deeply($circle->position, [175, 350], 'final tick position after stop');

}


done_testing;

