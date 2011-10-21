#!/usr/bin/perl

package SDLx::Tween::eg_03::Circle;

use Moose;
use SDLx::Text;

has position => (is => 'rw', required => 1);

has [qw(radius ball_color ease)] =>
    (is => 'ro', required   => 1);

has text => (is => 'ro', lazy_build => 1);

sub _build_text {
    my $self = shift;
    my $xy = $self->position;
    return SDLx::Text->new(
        x     => 2,
        y     => $xy->[1] - $self->radius,
        text  => $self->ease,
        color => [0, 0, 0],
        size  => 16,
    );
}

sub paint {
    my ($self, $surface) = @_;
    $self->text->write_to($surface);
    $surface->draw_circle_filled($self->position, $self->radius, 0xFFFFFFFF);
    $surface->draw_circle($self->position, $self->radius, $self->ball_color, 1);
}

# ------------------------------------------------------------------------------

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use SDL::Events;
use SDLx::App;
use SDLx::Sprite;
use SDLx::Tween;
use SDLx::Tween::Timeline;

my @names = qw(
    linear
    p2_in     p3_in     p4_in     p5_in     exponential_in     circular_in      sine_in      bounce_in     elastic_in     back_in     
    p2_out    p3_out    p4_out    p5_out    exponential_out    circular_out     sine_out     bounce_out    elastic_out    back_out    
    p2_in_out p3_in_out p4_in_out p5_in_out exponential_in_out circular_in_out  sine_in_out  bounce_in_out elastic_in_out back_in_out 
);
my $w          = 800;
my $h          = 615;
my $label_h    = 25;
my $content_h  = $h - $label_h;
my $radius     = ($content_h - (@names + 1)) / (2 * scalar(@names));
my $col_1      = 135;
my $col_2      = $col_1 + 18 + 1;
my $bg_color   = 0xF3F3F3FF;
my $grid_color = 0x999999FF;
my $ball_color = 0x000000FF;

my $app = SDLx::App->new(
    title  => 'Easing Functions',
    width  => $w,
    height => $h,
);

my (@circles, @tweens);

my $timeline = SDLx::Tween::Timeline->new;

my $row = 0;
for my $ease (@names) {
    my $y = 2 * $row * $radius + $radius + 1 + $row;
    my $circle = SDLx::Tween::eg_03::Circle->new(
        radius     => $radius,
        position   => [$radius + $col_1, $y],
        ball_color => $ball_color,
        ease       => $ease,
    );
    push @tweens, $timeline->tween(
        duration      => 6_000,
        to            => [$w - $radius, $y],
        on            => $circle,
        set           => 'position',
        bounce        => 1,
        forever       => 1,
        ease          => $ease,
    );
    push @circles, $circle;
    $row++;
}

my $chart = SDLx::Sprite->new(
    x     => $col_1 + 1,
    y     => 0,
    image => "$Bin/images/easing_functions_chart.png",
);

my $pause_instructions = SDLx::Text->new(
    x     => 5,
    y     => $h - 26,
    text  => 'click mouse to pause/resume, key left/right for slow/haste',
    color => [0, 0, 0],
    size  => 22,
);

my $pause_message = SDLx::Text->new(
    x     => 110,
    y     => 200,
    text  => 'PAUSED',
    color => [0, 0, 0],
    size  => 180,
);

my $duration_message = SDLx::Text->new(
    x     => $w - 220,
    y     => $h - 26,
    color => [0, 0, 0],
    size  => 22,
);

my $show_handler  = sub {
    $app->draw_rect(undef, $bg_color);
    $app->draw_line([$col_1, 0], [$col_1, $content_h - 1], $grid_color);
    $app->draw_line([$col_2, 0], [$col_2, $content_h - 1], $grid_color);
    for my $i (0..(@names - 1)) {
        my $y = 2 * $radius * $i + $i;
        $app->draw_line([0, $y], [$w, $y], $grid_color);
    }
    $app->draw_line([0, $content_h - 1], [$w, $content_h - 1], $grid_color);
    $chart->draw($app);
    $_->paint($app) for @circles;

    $duration_message->text('cycle_duration='. $tweens[0]->get_duration .'ms');

    $pause_instructions->write_to($app);
    $duration_message  ->write_to($app);
    $pause_message     ->write_to($app) if $timeline->is_paused;

    $app->update;
};

my $move_handler  = sub {
   
#   print "t=$timeline\n";
    $timeline->tick };

SDL::Events::enable_key_repeat(600, 100);
my $event_handler = sub {
    my ($e, $app) = @_;
    if($e->type == SDL_QUIT) {
        # needed for clean warning-less global destruction from Set::Object
        undef $timeline; # make sure Set::Objects destroy first in global destruction
        exit;
    } elsif ($e->type == SDL_MOUSEBUTTONDOWN) {
        $timeline->pause_resume;
    } elsif ($e->type == SDL_KEYDOWN) {
        return 0 if $timeline->is_paused;
        my $duration = $tweens[0]->get_duration;
        my $delta = 200; #ms
        if ($e->key_sym == SDLK_LEFT) {
            $duration += $delta;
        } elsif ($e->key_sym == SDLK_RIGHT) {
            $duration -= $delta;
        } else {
            return 0;
        }
        $duration = 100   if $duration < 100;
        $duration = 20000 if $duration > 20000;
        my $ticks = SDL::get_ticks; # time of duration change
        $_->set_duration($duration, $ticks) for @tweens;
    }
    return 0;
};

$app->add_show_handler($show_handler);
$app->add_event_handler($event_handler);
$app->add_move_handler($move_handler);

my $ticks = SDL::get_ticks;
$_->start($ticks) for @tweens;

$app->run;



