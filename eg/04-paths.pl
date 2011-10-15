#!/usr/bin/perl

package SDLx::Tween::eg_04::Circle;

use Moose;

has position => (is => 'rw', required => 1);

sub paint {
    my ($self, $surface) = @_;
    $surface->draw_circle_filled($self->position, 30, 0xFFFFFFFF);
    $surface->draw_circle($self->position, 30, 0x000000FF, 1);
}

# ------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use SDL::Events;
use SDLx::App;
use SDLx::Tween;

my $w = 800;
my $h = 600;

my $app = SDLx::App->new(
    title  => 'Path Functions',
    width  => $w,
    height => $h,
);

my $circle = SDLx::Tween::eg_04::Circle->new(position => [100, 100]);

my $tween = SDLx::Tween->new(
    duration  => 3_000,
    to        => [700, 500],
    on        => $circle,
    set       => 'position',
    bounce    => 1,
    forever   => 1,
    ease      => 'sine_in_out',
    path      => 'sine',
    path_args => {
        amp  => 50,
        freq => 3,
    },
);

my $show_handler  = sub {
    $app->draw_rect(undef, 0xF3F3F3FF);
    $app->draw_line([100, 100], [700, 500], 0x999999FF);
    $circle->paint($app);
    $app->update;
};

my $move_handler  = sub {
    my $ticks = SDL::get_ticks;
    $tween->tick($ticks);
};

my $event_handler = sub { my $e = shift; $_[0]->stop if ( $e->type == SDL_QUIT ) };

$app->add_show_handler($show_handler);
$app->add_event_handler($event_handler);
$app->add_move_handler($move_handler);

$tween->start(SDL::get_ticks);

$app->run;


