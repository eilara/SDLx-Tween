#!/usr/bin/perl

use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");

package SDLx::Tween::eg_07::Circle;

use Moose;

has position => (is => 'rw', required => 1);

sub paint {
    my ($self, $surface) = @_;
    $surface->draw_circle_filled($self->position, 20, 0xFFCC00FF);
    $surface->draw_circle($self->position, 20, 0x0000EEFF, 1);
}

# ------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use SDL::Events;
use SDLx::App;
use SDLx::Tween::Timeline;

my $w = 800;
my $h = 600;

my $app = SDLx::App->new(
    title  => 'Tween Complete Event',
    width  => $w,
    height => $h,
);

my $timeline = SDLx::Tween::Timeline->new(sdlx_app => $app);

my $circle = SDLx::Tween::eg_07::Circle->new(position => [20, 300]);

my ($tween_1, $tween_2);

$tween_1 = $timeline->tween(
    t         => 5_000,
    to        => [780, 300],
    on        => [position => $circle],
    path      => 'sine',
    path_args => {amp => 60, freq => 3},
    ease      => 'p4_in_out',
    done      => sub { $tween_2->start },
);

$tween_2 = $timeline->tween(
    t         => 3_000,
    from => [780,300],
    to        => [20, 300],
    on        => [position => $circle],
    ease      => 'p2_in_out',
    done      => sub { $tween_1->start },
);

my $show_handler  = sub {
    $app->draw_rect(undef, 0xF3F3F3FF);
    $circle->paint($app);
    $app->update;
};

$app->add_show_handler($show_handler);
$app->add_event_handler(sub { exit if shift->type == SDL_QUIT });

$tween_1->start;

$app->run;
