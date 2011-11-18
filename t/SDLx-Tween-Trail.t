
package main;
use strict;
use warnings;
use Test::More;
use SDLx::Tween::Tail;

my ($registered, $unregistered);

my $head = [1000, 0];
my $tail = [   0, 0];

my $iut = SDLx::Tween::Tail->new(
    register_cb   => sub { $registered   = shift },
    unregister_cb => sub { $unregistered = shift },
    speed         => 100/1000,
    head          => $head,
    tail          => $tail,
);

is($registered, undef, 'not yet registered with clock');
ok(!$iut->is_active, 'starts inactive');

$iut->start(20_000);
ok($iut->is_active, 'active after start');
is($registered, $iut, 'registered with clock');

$iut->tick(21_000);
is($tail->[0], 100, '1st tick');

$iut->tick(22_000);
is($tail->[0], 200, '2nd tick');

$iut->tick(30_000);
is($tail->[0], 1000, 'final tick');
ok(!$iut->is_active, 'reached target');

done_testing;


