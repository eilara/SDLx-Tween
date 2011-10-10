#!/usr/bin/perl

package SDLx::Tween::eg_02::Star;
use Moose;
has xy => (is => 'rw', default => sub{ [320, 200] });

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use Math::Trig;
use SDL::Events;
use SDLx::App;
use SDLx::Tween;

my $STAR_COUNT = 2500;

my $app = SDLx::App->new(
    title  => 'Starfield',
    width  => 640,
    height => 480,
);

my (@tweens, @stars);

my $i; while($i++ < $STAR_COUNT) {
    my $theta = rand(2 * pi);
    my $to    = [cos($theta)*640 + 320, sin($theta)*480 + 240];
    my $star  = SDLx::Tween::eg_02::Star->new;
    my $tween = SDLx::Tween->new(
        register_cb   => sub {}, # the stars start and never stop
        unregister_cb => sub {}, # so we will register for ticks ourselves
        duration      => (int(rand 10_000) + 1000),
        to            => $to,
        on            => $star,
        set           => 'xy',
        forever       => 1,
    );
    push @tweens, $tween;
    push @stars, $star;
}

my $move_handler  = sub {
    my $ticks = SDL::get_ticks;
    $_->tick($ticks) for @tweens;
};

my $show_handler  = sub {
    $app->draw_rect(undef, 0x000000FF);
    for my $star (@stars) {
        $app->draw_rect([@{$star->{xy}}, 1, 1], 0xFFFFFFFF);
    }
    $app->update;
};

my $event_handler = sub { my $e = shift; $_[0]->stop if ( $e->type == SDL_QUIT ) };

$app->add_event_handler($event_handler);
$app->add_show_handler($show_handler);
$app->add_move_handler($move_handler);

$_->start for @tweens;

$app->run;

