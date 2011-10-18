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
use Math::Trig;
use SDL::Events;
use SDLx::App;
use SDLx::Text;
use SDLx::Tween;

my $w = 800;
my $h = 600;

my %paths = (
    linear   => {from => [100, 100], to => [700, 500]},
    sine     => {from => [100, 100], to => [700, 500],
                 path_args => {amp => 100, freq => 2}},
    circular => {path_args => {center => [400, 300],
                 radius => 250, begin => 0, end => 2*pi}},
);

my @paths = sort keys %paths;

my $path = $paths[0];

my $tween;

my $app = SDLx::App->new(
    title  => 'Path Functions',
    width  => $w,
    height => $h,
);

my $circle = SDLx::Tween::eg_04::Circle->new(position => [100, 100]);

my $instructions = SDLx::Text->new(
    x     => 5,
    y     => $h - 25,
    text  => 'click to change path',
    color => [0, 0, 0],
    size  => 20,
);

my $path_label = SDLx::Text->new(
    x     => $w - 150,
    y     => $h - 25,
    text  => "path=$path",
    color => [0, 0, 0],
    size  => 20,
);

my $show_handler  = sub {
    $app->draw_rect(undef, 0xF3F3F3FF);
    $instructions->write_to($app);
    $path_label->write_to($app);
    $circle->paint($app);
    $app->update;
};

my $move_handler  = sub {
    my $ticks = SDL::get_ticks;
    $tween->tick($ticks);
};

my $event_handler = sub {
    my ($e, $app) = @_;
    if($e->type == SDL_QUIT) {
        $app->stop;
    } elsif ($e->type == SDL_MOUSEBUTTONDOWN) {
        $tween->stop;
        tween_circle();
    }
    return 0;
};

$app->add_show_handler($show_handler);
$app->add_event_handler($event_handler);
$app->add_move_handler($move_handler);

tween_circle();

$app->run;

sub tween_circle {
    $path = shift @paths;
    $path_label->text($path);
    push @paths, $path;
    my $args = $paths{$path};
    $tween = SDLx::Tween->new(
        duration  => 3_000,
        on        => $circle,
        set       => 'position',
        bounce    => 1,
        forever   => 1,
        ease      => 'sine_in_out',
        path      => $path,
        %$args
    );
    $tween->start(SDL::get_ticks);
}




