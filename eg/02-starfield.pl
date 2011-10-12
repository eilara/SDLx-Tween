#!/usr/bin/perl

package SDLx::Tween::eg_02::Star;

sub new {
    my $class = shift;
    my $self = bless [[320, 200], undef, undef], $class;
    return $self;
}

package main;
use strict;
use warnings;
use FindBin qw($Bin);
use lib ("$Bin/..", "$Bin/../blib/arch", "$Bin/../blib/lib");
use Math::Trig;
use SDL::Events;
use SDLx::App;
use SDLx::Tween;

my $STAR_COUNT = 4000;

my $app = SDLx::App->new(
    title  => 'Starfield',
    width  => 640,
    height => 480,
);

my ($first_star, $prev_star, @tweens);

my $i; while($i++ < $STAR_COUNT) {
    my $theta = rand(2 * pi);
    my $to    = [cos($theta)*640 + 320, sin($theta)*480 + 240];
    my $star  = SDLx::Tween::eg_02::Star->new;
    my $tween = SDLx::Tween->new(
        duration      => (int(rand 7_000) + 1000),
        from          => [320, 200],
        to            => $to,
        on            => $star->[0],
        forever       => 1,
        ease          => 'p2_in',
        proxy         => 'array',
    );
    $star->[1] = $tween;

    if ($first_star) { $prev_star->[2] = $star }
    else             { $first_star = $star }
    
    $prev_star = $star;
    push @tweens, $tween;
}

my $show_handler  = sub {
    my $ticks = SDL::get_ticks;
    my $star = $first_star;
    $app->draw_rect(undef, 0x000000FF);
    while ($star) {
        $star->[1]->tick($ticks);
        $app->draw_rect([@{$star->[0]}, 1, 1], 0xFFFFFFFF);
        $star = $star->[2];
    }
    $app->update;
};

my $event_handler = sub { my $e = shift; $_[0]->stop if ( $e->type == SDL_QUIT ) };

$app->add_event_handler($event_handler);
$app->add_show_handler($show_handler);

$_->start for @tweens;

$app->run;

