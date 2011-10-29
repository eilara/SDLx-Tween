#!/usr/bin/perl

package SDLx::Tween::eg_01::Circle;
use Moose;
has radius => (is => 'rw', default => 0);

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use SDL::Events;
use SDLx::App;
use SDLx::Tween;

my $circle = SDLx::Tween::eg_01::Circle->new;

my $app = SDLx::App->new(
    title  => 'Circle With Tweened Radius',
    width  => 640,
    height => 480,
);

my $tween = SDLx::Tween->new(
    register_cb   => sub { register(@_) },
    unregister_cb => sub { unregister(@_) },
    duration      => 4_000,
    to            => 200,
    on            => [radius => $circle],
    round         => 1,
    bounce        => 1,
    forever       => 1,
    ease          => 'p3_in_out',
);

my $move_handler  = sub { $tween->tick(SDL::get_ticks) };
my $event_handler = sub { my $e = shift; $_[0]->stop if ( $e->type == SDL_QUIT ) };

my $show_handler  = sub {
    $app->draw_rect(undef, 0x000000FF);
    $app->draw_circle_filled([320, 200], $circle->radius, 0xFFFFFFFF);
    $app->update;
};

$app->add_event_handler($event_handler );
$app->add_show_handler($show_handler );

$tween->start;
$app->run;

sub register {
    my $tween = shift;
    $app->add_move_handler($move_handler);
}

sub unregister {
    my $tween = shift;
    $app->remove_move_handler($move_handler);
}



