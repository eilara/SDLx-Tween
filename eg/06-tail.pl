#!/usr/bin/perl

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use SDL::Events;
use SDLx::App;
use SDLx::Tween::Timeline;

my $app = SDLx::App->new(
    title  => 'Tail Behavior Example',
    width  => 640,
    height => 480,
);

my $timeline = SDLx::Tween::Timeline->new(sdlx_app => $app);

my $cursor = [100, 100];

my (@followers, @tweens);

for my $i (1..100) {
    my $follower = [0, 0];
    push @followers, $follower;
    push @tweens, $timeline->tail(
        speed => (50+$i*5)/1000,
        head  => $cursor,
        tail  => $follower,
    );
}

my $event_handler = sub {
    my ($e, $app) = @_;
    if($e->type == SDL_QUIT) {
        $app->stop;
    } elsif ($e->type == SDL_MOUSEMOTION) {
        for (@tweens) { $_->start unless $_->is_active }
        $cursor->[0] = $e->motion_x;
        $cursor->[1] = $e->motion_y;
    }
};

my $show_handler  = sub {
    $app->draw_rect(undef, 0x000000FF);
    for my $follower (@followers) {
        my ($x, $y) = @$follower;
        $app->draw_circle([$x, $y], 20, [255,255,255]);
    }
    $app->update;
};

$app->add_event_handler($event_handler );
$app->add_show_handler($show_handler );

$timeline->start;
$app->run;

