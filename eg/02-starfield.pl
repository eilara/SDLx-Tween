#!/usr/bin/perl

package SDLx::Tween::eg_02::Star;
use Moose;
has xy => (is => 'rw', default => sub{ [320, 200] });

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use SDL::Events;
use SDLx::App;
use SDLx::Tween;

my $STAR_COUNT = 1000;

my $app = SDLx::App->new(
    title  => 'Starfield',
    width  => 640,
    height => 480,
);

my (@tweens, @stars);

my $i; while($i++ < $STAR_COUNT) {
    my $to = [int(rand 640), 480];
    my $star  = SDLx::Tween::eg_02::Star->new;
    my $tween = SDLx::Tween->new(
        register_cb   => sub {},
        unregister_cb => sub {},
        duration      => (int(rand 5000) + 1000),
        from          => [320, 200],
        to            => $to,
        on            => $star,
        set           => 'xy',
        forever       => 1,
        bounce       => 1,
        ease => 'swing',
    );
    push @tweens, $tween;
    push @stars, $star;
}

$_->start for @tweens;

my $event_handler = sub { my $e = shift; $_[0]->stop if ( $e->type == SDL_QUIT ) };

my $move_handler  = sub {
    my $ticks = SDL::get_ticks;
    $_->tick($ticks) for @tweens;
};

my $show_handler  = sub {
    $app->draw_rect(undef, 0x000000FF);
    for my $star (@stars) {
        $app->draw_rect([@{$star->xy}, 1, 1], 0xFFFFFFFF);
    }
    $app->update;
};

$app->add_event_handler($event_handler);
$app->add_show_handler($show_handler);
$app->add_move_handler($move_handler);

$app->run;

