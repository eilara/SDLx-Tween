
package SDLx::Tween::tests::Circle;
use Moose;
has radius => (is => 'rw');

package main;
use strict;
use warnings;
use Test::More;
use SDLx::Tween;

{ # basic complete 1d linear path and ease int method proxy

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
is($iut->get_cycle_start_time, 20_000, 'cycle start time');

$iut->tick(23_000);
is($circle->radius, 510, '1st tick radius');

# 300K ticks a second on a 2005 dual core duo notebook
# for (1..6000000) { $iut->tick(20000+ $_); }

$iut->tick(50_100);
is($circle->radius, 600, '2nd tick radius');
ok(!$iut->is_active, 'cycle complete');

}

#{ # stop
#
#}


done_testing;

