#!/usr/bin/perl

use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");

package SDLx::Tween::eg_05::Circle;

use Moose;
use SDLx::Tween;

has color      => (is => 'rw', default => 0x000000FF);
has position   => (is => 'ro', required => 1);
has tween_args => (is => 'ro', required => 1);
has tween      => (is => 'ro', lazy_build => 1, handles => [qw(start tick)]);

sub _build_tween {
    my $self = shift;
    SDLx::Tween->new(
        on       => $self,
        set      => 'color',
        duration => 2_000,
        forever  => 1,
        bounce   => 1,
        ease     => 'p3_in_out',
        %{$self->tween_args},
    );
}

sub paint {
    my ($self, $surface) = @_;
#printf("color=%x\n",$self->color);
    $surface->draw_circle_filled($self->position, 100, $self->color);
    $surface->draw_circle($self->position, 100, 0x000000FF, 1);
}

# ------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use SDL::Events;
use SDLx::App;
use SDLx::Text;

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
);

my (@circles, @text);

my $app = SDLx::App->new(
    title  => 'Color Tweening',
    width  => $w,
    height => $h,
);

for my $def (@circle_defs) {
    my $xy = $def->[1];
    push @circles, SDLx::Tween::eg_05::Circle->new(
        position   => $xy,
        color      => $def->[2],
        tween_args => $def->[3],
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

my $move_handler  = sub {
    my $ticks = SDL::get_ticks;
    $_->tick($ticks) for @circles;
};

my $event_handler = sub {
    my ($e, $app) = @_;
    if($e->type == SDL_QUIT) {
        exit;
    }
    return 0;
};

$app->add_show_handler($show_handler);
$app->add_event_handler($event_handler);
$app->add_move_handler($move_handler);

$_->start for @circles;

$app->run;
