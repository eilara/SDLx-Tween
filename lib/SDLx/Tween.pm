package SDLx::Tween;

use 5.010001;
use strict;
use warnings;
use Carp;
use SDL;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('SDLx::Tween', $VERSION);

my (@Ease_Names, %Ease_Lookup);
{
    @Ease_Names = qw(
        linear
        p2_in p2_out p2_in_out
        p3_in p3_out p3_in_out
        p4_in p4_out p4_in_out
        p5_in p5_out p5_in_out
        sine_in sine_out sine_in_out
        circular_in circular_out circular_in_out
        exponential_in exponential_out exponential_in_out
        elastic_in elastic_out elastic_in_out
        back_in back_out back_in_out
        bounce_in bounce_out bounce_in_out
    );
    my $i = 0; %Ease_Lookup = map { $_ => $i++ } @Ease_Names;
}

sub Ease_Names { @Ease_Names }

my %Path_Lookup;
do { my $i = 0; %Path_Lookup = map { $_ => $i++ } qw(
    linear
    sine
    circular
    spiral
    polyline
    fade
    rgba
    tail
)};

my %Paths_Requiring_Edge_Value_Args = map { $Path_Lookup{$_} => 1 } qw(
    linear
    sine
    fade
    rgba
    tail
);

my %Paths_On_Color = map { $Path_Lookup{$_} => 1 } qw(
    fade
    rgba
);

my %Path_Get_Dim = (
    $Path_Lookup{linear}   => \&compute_dim_path_with_edge_values,
    $Path_Lookup{sine}     => \&compute_dim_path_with_edge_values,
    $Path_Lookup{circular} => \&compute_dim_path_centered,
    $Path_Lookup{spiral}   => \&compute_dim_path_centered,
    $Path_Lookup{polyline} => \&compute_dim_path_polyline,
    $Path_Lookup{tail}     => \&compute_dim_path_with_edge_values,
);

my %Proxy_Lookup;
do { my $i = 0; %Proxy_Lookup = map { $_ => $i++ } qw(
    method
    array
)};

my %Proxy_Builders = (
    $Proxy_Lookup{method} => \&build_proxy_method,
    $Proxy_Lookup{array}  => \&build_proxy_array,
);

my %Proxies_That_Get_Edge_Values = (
    $Proxy_Lookup{method} => \&init_value_proxy_method,
    $Proxy_Lookup{array}  => \&init_value_proxy_array,
);

sub new {
    my ($class, %args) = @_;

    my $on_arg = $args{on} || die 'No "on" give';
    # if "on" is ARRAY and 2nd member is not a ref, then 
    # we want an array proxy
    if (ref($on_arg) eq 'ARRAY') {
        die '"on" is empty array ref' unless @$on_arg;
        $args{proxy} ||= 'array' if
           (@$on_arg == 1) || !ref($on_arg->[1]);
    }

    my $ease  = $Ease_Lookup{  $args{ease}  || 'linear' };
    my $path  = $Path_Lookup{  $args{path}  || 'linear' };
    my $proxy = $Proxy_Lookup{ $args{proxy} || 'method' };

    # proxy args built from top level args
    my $proxy_args = $Proxy_Builders{$proxy}->(\%args);
    my $path_args  = $args{path_args} || {};

    # these paths require "from" and "to" in top level args
    if ($Paths_Requiring_Edge_Value_Args{$path}) {
        if (!exists($args{from})) { # auto get "from"
            die 'Must provide explicit "from" value for this path and proxy'
                unless $Proxies_That_Get_Edge_Values{$proxy};
            $args{from} = $Proxies_That_Get_Edge_Values{$proxy}->($proxy_args);
        }
        die 'No from/to given' unless exists($args{from}) && exists ($args{to});
        $path_args->{from} = $args{from};
        $path_args->{to}   = $args{to};
    } 

    # non linear paths need dimension check, color paths dont
    if ($path != 0 && !$Paths_On_Color{$path}) {
        my $dim_provider = $Path_Get_Dim{$path} || die 'Cannot compute dimension of tween';
        my $dim = $dim_provider->($path_args);
        die "Non linear paths only work for 2D, dim=$dim" unless $dim == 2;
    }
  
    $proxy_args->{is_uint32} = $Paths_On_Color{$path}? 1: 0;

    my $register_cb   = $args{register_cb}   || sub {}; 
    my $unregister_cb = $args{unregister_cb} || sub {};

    my $duration = $args{duration} || $args{t} || die "No positive duration given";

    my @args = (

        $register_cb, $unregister_cb, $duration,

        $args{forever} || 0,
        $args{repeat}  || 0,
        $args{bounce}  || 0,

        $ease,
        $path, $path_args,
        $proxy, $proxy_args,
    );
    my $struct = new_struct(@args);
    my $self = bless([$struct], $class);
    return $self;
}



sub build_proxy_method {
    my $args = shift;
    my $on = $args->{on};
    die 'No "on" given' unless $on;
    if (ref($on) eq 'ARRAY') {
        $args->{set} = $on->[0];
        $on          = $on->[1];
    }
    die 'No "set" given' unless exists $args->{set};
    return {
        target => $on,
        method => $args->{set},
        round  => $args->{round} || 0,
    };
}

sub build_proxy_array {
    my $args = shift;
    my $on = $args->{on} || die 'No "on" array given to array proxy';
    # make sure they are all floats not ints
    # is there no better way?! SvNOK_on seems to fail need to replace scalar?
    for (@$on) { $_ += 0.000000000001 }
    return {on => $on};
}



sub init_value_proxy_method {
    my $proxy_args = shift;
    my $method = $proxy_args->{method};
    return $proxy_args->{target}->$method;
}

sub init_value_proxy_array {
    my $proxy_args = shift;
    # copy the array
    my @v = @{ $proxy_args->{on} };
    return \@v;
}


sub compute_dim_path_with_edge_values {
    my $path_args = shift;
    return scalar @{$path_args->{from}};
}

sub compute_dim_path_centered {
    my $path_args = shift;
    return scalar @{$path_args->{center}};
}

# convert the list of waypoints into a list of segments, each
# with its relative length, and its tween progress
sub compute_dim_path_polyline {
    my $path_args = shift;
    my @points = @{$path_args->{points} || die 'No "points given'};
    my $dim = scalar @{$points[0]};
    # convert points to segments with distance ratio
    my @segments;
    my $last_point = shift @points;
    my $total_length = 0;
    while (my $point = shift @points) {
        my ($dx, $dy) = ($point->[0] - $last_point->[0],
                         $point->[1] - $last_point->[1]);
        my $length = sqrt($dx*$dx + $dy*$dy);
        $total_length += $length;
        push @segments, [@$last_point, @$point, $length, undef];
        $last_point = $point;
    }
    my $progress = 0;
    foreach my $segment (@segments) {
        my $length_ratio = $segment->[4] / $total_length;
        $progress += $length_ratio;
        $segment->[4] = $length_ratio;
        $segment->[5] = $progress;
    };
    $path_args->{segments} = [@segments];
    $path_args->{distance} = $total_length;
    return $dim;
}

1;

=head1 NAME

SDLx::Tween - SDL Perl XS Tweening Library

=head1 SYNOPSIS

  # simple linear tween
  use SDLx::Tween::Timeline;
  
  $sdlx_app = SDLx::App->new(...);

  # timeline gets its ticks from the SDLx app controller move handler
  $timeline = SDLx::Tween::Timeline->new(app => $sdlx_app);

  $xy = [0, 0]; # tween the position stored in this array ref

  # create tweens from the timeline, setting the target ($xy), the
  # duration (1 second), and the final requested value ([640, 480])
  $tween = $timeline->tween(on => $xy, t => 1_000, to => [640, 480]);

  # tween will not do anything until started
  $tween->start;

  # xy will now be tweened between [0, 0] and [640, 480] for 1 second 
  # and then the tween will stop
  $sdlx_app->run;

  # tween methods
  $ticks = $tween->get_cycle_start_time;
  $ticks = $tween->get_duration;
  $tween->set_duration($new_duration_in_ticks); # hasten/slow a tween
  $bool = $tween->is_active;
  $tween->start($optional_ideal_cycle_start_time_in_ticks);  
  $tween->stop;
  $tween->pause($optional_ideal_pause_time_in_ticks);
  $tween->resume($optional_ideal_resume_time_in_ticks);
  $tween->tick($ticks); # called internally by timeline or SDLx app

  # tweening an integer get/set accessor
  $tween = $timeline->tween(
      on            => [radius => $circle], # set $circle->radius
      t             => 4_000,               # tween duration
      from          => 100,                 # initial value
      to            => 300,                 # final value
      round         => 1,                   # round values before setting
      bounce        => 1,                   # reverse when repeating
      forever       => 1,                   # continue forever
      ease          => 'p3_in_out',         # use easing function
  );

  # tweening 2D position using a non-linear path, repeats 4 times
  $tween = $timeline->tween(
      on            => [xy => $circle],     # set values in a xy array ref field
      t             => 4_000,               # tween duration
      to            => [640,480],           # final value, initial taken from $xy
      repeat        => 4,                   # repeat tween 4 times
      path          => 'sine',              # use a sine path
      path_args     => {                    # sine path needs path_args
         {amp => 100, freq => 2},
      }
  );

  # tail behavior makes one position follow another at given speed
  # the behavior makes the tail follow the head
  # unlike other tweens, tails only allow the following 3 contructor args
  $tail = $timeline->tail(
      speed => 50/1000,                     # advance a distance of 50 pixels a sec 
      head  => $head,                       # position to follow array ref
      tail  => $tail,                       # position to set array ref
  );


=head1 DESCRIPTION

C<SDLx::Tween> is a library for tweening Perl SDL elements. It lets you to move
game objects (GOBs) around in various ways, rotate and scale things, animate
sprites and colors, make GOBs spawn at a given rate, and generally bring about
changes in the game over time. It lets you do these things declaratively,
without writing complex C<SDLx::Controller> C<move_handlers()>.

=head1 WHY?

Writing Perl SDL game move handlers is hard. Consider a missile with 3 states:

=over 4

=item *

firing - some sprite animation

=item *

flying towards enemy - need to update its position until it hits enemy

=item *

exploding - another sprite animation

=back    

The move handler for this game object (GOB) is hard to write, because it needs to:

=over 4

=item *

update GOB properties

=item *

you must take into account acceleration and paths in the computation of these
values

=item *

you need to set limits of the values, wait for the limits

=item *

GOBs need to act differently according to their state, so you need to manage
that as well

=item *

it all must be very accurate, or animations will miss each other

=item *

it has to be fast- this code is run per each GOB per each update

=back

As a game becomes more wonderful, the GOB move handlers become more hellish.
Brave souls have done it, but even they could not do it in a way us mortals
can reuse or even understand.

C<SDLx::Tween> solves the missile requirements. Instead of writing a move
handler, declare tweens on your GOBs. C<SDLx::Tween> will take care of the move
handler for you.

Instead of writing a move handler which updates the position of $my_gob 
from its current position to x=100 in 1 second, you can go:

    $tween = $timline->tween(on => [x => $my_gob], to =>100, t => 1_000);

C<SDLx::Tween> will setup the correct move handler.

According to L<http://en.wikipedia.org/wiki/Tweening>:

    "In the inbetweening workflow of traditional hand-drawn animation, the
    senior or key artist would draw the keyframes ... and then would hand over
    the scene to his or her assistant the inbetweener who does the rest."

Let SDLx-Tween be your inbetweener.


=head1 FEATURES

Perl SDL move handlers are rarely a simple linear progression. C<SDLx::Tween>
features:

=over 4

=item *

tween any method, e.g. a Moose get/set accessor, or directly on an array

=item *

tween a property with several dimensions, e.g. xy position, 4D color space

=item *

tween xy position not on a line, but on some curve

=item *

smooth the motion with acceleration/deceleration using easing functions

=item *

make the tween bounce, repeat for N cycles or forever

=item *

pause/resume tweens

=item *

hasten/slow a tween, for example when creeps are suddenly given a speed bonus

=item *

follow a moving target, e.g. for a homing missile with constant acceleration

=item *

chain tweens, paralellize tween, e.g start explode tween after reaching target

=item *

tween sprite frames, color/opacity/brightness/saturation/hue, volume/pitch,
spawning, rotation, size, camera position

=item *

delay before/after tweens

=item *

rewind/ffw/reverse/seek tweens, and generaly play with elastic time for making
the game faster or slower

=back

All but the last 4 features are ready for use. The 4 C<TODO> features need some
sugaring and examples.

See the C<TODO> file in the distribution for more planned features.


=head1 Examples

The distribution includes a few tweening examples:

=over 4

=item C<01-circle.pl>

the hello world of tweening, a growing circle

=item C<02-starfield.pl>

demo of 6000 concurrent tweens

=item C<03-easing.pl>

demo of all easing functions

=item C<04-paths.pl>

demo of all paths

=item C<05-colors.pl>

demo of color transitions

=item C<06-colors.pl>

demo of 100 tail behaviors

=back


=head1 SEE ALSO

Development is at L<https://github.com/PerlGameDev/SDLx-Tween>.

Interesting implementations of the tweening idea:

=over 4

=item *

http://www.greensock.com/tweenlite/

=item *

http://drawlogic.com/2010/04/11/itween-tweening-and-easing-animation-library-for-unity-3d/

=item *

http://www.leebyron.com/else/shapetween/

=back


=head1 AUTHOR

eilara <ran.eilam@gmail.com>


=head1 COPYRIGHT AND LICENSE

Big thanks to:

  Sam Hocevar, from 14 rue de Plaisance, 75014 Paris, France
  https://raw.github.com/warrenm

For his most excellent AHEasing lib which C<SDLx-Tween> uses for easing
functions. The license is in the C<tweencee/> dir. The library is at
L<https://github.com/warrenm/AHEasing>.

Check that page for some great info about easing functions.


Copyright (C) 2011 by Ran Eilam

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
