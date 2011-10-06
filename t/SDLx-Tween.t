
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
    duration      => 30,
    from          => 500,
    to            => 600,
    on            => $circle,
    set           => 'radius',
);

is($registered, undef, 'not yet registered with clock');
ok(!$iut->is_active, 'starts inactive');

$iut->start(100);

ok($iut->is_active, 'active after start');
is($registered, $iut, 'registered with clock');
is($iut->get_cycle_start_time, 100, 'cycle start time');

$iut->tick(110);

is($circle->radius, 501, '1st tick radius');

$iut->tick(131);

is($circle->radius, 601, '2nd tick radius');

ok(!$iut->is_active, 'cycle complete');

}

#{ # stop
#
#}


done_testing;

