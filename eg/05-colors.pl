#!/usr/bin/perl

use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");

package SDLx::Tween::eg_05::Circle;

use Moose;

has color      => (is => 'rw', default => 0x000000FF);
has position   => (is => 'ro', required => 1);
has tween_args => (is => 'ro', required => 1);
has timeline   => (is => 'ro', required => 1, weak_ref => 1);
has tween      => (is => 'ro', lazy_build => 1);

sub _build_tween {
    my $self = shift;
    return $self->timeline->tween(
        on       => [color => $self],
        duration => 2_000,
        forever  => 1,
        bounce   => 1,
        ease     => 'p3_in_out',
        %{$self->tween_args},
    );
}

sub paint {
    my ($self, $surface) = @_;
    $surface->draw_circle_filled($self->position, 100, $self->color);
    $surface->draw_circle($self->position, 100, 0x000000FF, 1);
}

# force tween build
sub BUILD { shift->tween }

# ------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use SDL::Events;
use SDLx::App;
use SDLx::Text;
use SDLx::Tween::Timeline;

my $w = 800;
my $h = 600;

my @circle_defs = (
    ["path=fade from=0xFF000000 to=0xFF", 
        [200, 150], 0xFF0000FF,
        {path => 'fade', to => 0x00},
    ],
    ["path=rgba from=0x00FF0044 to=0x0000FFCC",
        [200, 320], 0x00FF0044,
        {path => 'rgba', to => 0x0000FFCC},
    ],
    ["path=rgba from=0xFF00FF77 to=0x00000077",
        [330, 150], 0xFF00FF77,
        {path => 'rgba', to => 0x00000077},
    ],
    ["path=rgba from=0xFFFF0088 to=0xFFFFFF88",
        [330, 320], 0xFFFF0088,
        {path => 'rgba', to => 0xFFFFFF88},
    ],
);

my (@circles, @text);

my $app = SDLx::App->new(
    title  => 'Color Tweening',
    width  => $w,
    height => $h,
);

my $timeline = SDLx::Tween::Timeline->new(sdlx_app => $app);

for my $def (@circle_defs) {
    my $xy = $def->[1];
    push @circles, SDLx::Tween::eg_05::Circle->new(
        position   => $xy,
        color      => $def->[2],
        tween_args => $def->[3],
        timeline   => $timeline,
    );
    my $row; for my $part (split / /, $def->[0]) {
        push @text, SDLx::Text->new(
            x       => $xy->[0] - 45,
            y       => $xy->[1] - 30 + 18 * $row++,
            text    => $part,
            color   => [0, 0, 0],
            size    => 16,
        );
    }
}

my $show_handler  = sub {
    $app->draw_rect(undef, 0xF3F3F3FF);
    $_->write_to($app) for @text;
    $_->paint($app) for @circles;
    $app->update;
};

$app->add_show_handler($show_handler);
$app->add_event_handler(sub { exit if shift->type == SDL_QUIT });

$timeline->start;

$app->run;
