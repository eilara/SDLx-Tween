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
)};

my %Paths_Requiring_Edge_Value_Args = map { $Path_Lookup{$_} => 1 } qw(
    linear
    sine
    fade
    rgba
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

    # range is sugar for "from" and "to" together
    if ($args{range}) {
        $path_args->{from} = $args{range}->[0];
        $path_args->{to}   = $args{range}->[1];
    }

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
    my $complete_cb   = $args{done}          || sub {};
    my $duration      = $args{duration} || $args{t} || die "No positive duration given";

    my @args = (

        $register_cb, $unregister_cb, $complete_cb, $duration,

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

  # tween accessors
  $ticks = $tween->get_cycle_start_time;
  $bool  = $tween->is_active;
  $ticks = $tween->get_duration;

  # tween methods
  $tween->set_duration($new_duration_in_ticks); # hasten/slow a tween
  $tween->start($optional_ideal_cycle_start_time_in_ticks);  
  $tween->stop;
  $tween->pause($optional_ideal_pause_time_in_ticks);
  $tween->resume($optional_ideal_resume_time_in_ticks);
  $tween->tick($now_in_ticks); # called internally by timeline or SDLx app

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

  # tweening 2D position using a non-linear path, repeat 4 times
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

See L</WHY> and L</FEATURES> for an introduction to tweening, or continue for
the technical details.


=head1 DECLARING TWEENING BEHAVIORS


=head2 THE TIMLINE

The timeline is the tween factory. It is created with an C<SDLx::App>:

  $timeline = SDLx::Tween::Timeline->new(sdlx_app => $app);

Now you can create tweens through the timeline, and control the cycle
of all the timeline controlled tweens through the timeline:
C< start/stop/pause/resume>. You can create as many timelines as you like to
control different tween groups.


=head2 THE TWEEN

A tween is a behavior of some game property vs. time. It sets the target game
property using a proxy, according to some path, at a time computed by an easing
function, which obeys certain cycle rules, for a given duration.

A tween is created from a timeline, which passes C<tick()> to the tween from
the C<SDLx::App> C<move_handler>.  Once you create the tween you can control
its cycle: set ideal cycle times, start/stop, pause/resume, and change cycle
duration.

The simplest tween uses the method proxy and calls a game method with the
tweened value. It uses the default linear path to tween a value between a
range given by the C<range> arg. Speed of change will be constant, because
the tween uses the default linear easing function.

The simplest tween, animating a turret turning 180 degrees in 1 second:

  $tween = $timeline->tween(
      on    => [angle => $turret],
      t     => 1_000,
      range => [0, pi],
  );


=head2 CYCLE CONTROL

A tween has a duration and a cycle start time. These define its cycle. Several
tween constructor arguments help to control the tween cycle:

=over 4

=item t

C<integer> Ticks (milliseconds) duration of the tween from start to stop.

=item forever

C<boolean> Repeat the cycle forever, restarting on each cycle completion.

=item repeat

C<integer> Repeat the cycle C<n> times, then stop.

=item bounce

C<bool> If the cycle is repeating, on each cycle completion reverse the
tween direction, I<bouncing> the tween between its edge points.

=back

Cycle control methods:

=over 4

=item start/stop/pause/resume

These all take an optional ideal event time in SDL ticks, see L</ACCURACY> for
more info. The difference between C<start/stop> and C<pause/resume> is that
C<start/stop> resets the tween, while C<pause/resume> works so that the tween
starts from where it left off.

These can also be called on the C<SDLx::Tween::Timeline>. It will broadcast
the call to all tweens it has created.

=item get_cycle_start_time

Returns the tween cycle start time, in SDL ticks.

=item get/set_duration

Get/set the tween duration, in ticks.

=back


=head2 PROXIES

The tween translates ticks from the C<SDLx::Controller> into changes in game
elements. To change these elements it uses a proxy. The proxy calls methods on
your game objects, or changes array refs directly.

=over 4

=item method proxy

If the tween constructor arg C<on> is an array ref of 2 elements, a string and
a blessed ref, eg:

  # as part of the tween constructor arg hash
  on => [method_name => $game_object],

Then the tween will use the method proxy. The tween value will be set by calling
the given method on the given object.

If the path requires a C<from> arg (e.g. linear path), and none is supplied,
the method defined for the proxy is used to I<get> the initial tween value. In
this case the proxy method shoud be able to do get/set.

When using the method proxy you can use the optional C<round> flag when
creating the tween. If true, values will be rounded and made distinct by
dropping repeated values.


=item array proxy

If the tween constructor arg C<on> is an array ref of numbers, eg:

  $pos = [320, 200];
  ...
  # as part of the tween constructor arg hash
  on => $pos,

Then the tween will use the array proxy. The elements of the array ref C<$pos>
will be changed directly by the tween. This is very fast, but you lose any
semblance of encapsulation.

=back


=head2 EASING


The deault tween changes in constant speed because it uses the linear easing
function. The time used by the path to compute position of the tween value,
advances in a linear rate.

By setting the C<ease> arg in the tween constructor you can make time advance
according to a non-linear curve. For example to make the tween go slow at
first, then go fast:

  # as part of the tween constructor arg hash
  ease => 'p2_in',

This will cause time to advance in a quadratic curve. At normalized time
C<$t> where C< $t=$elapsed/$duration > and $t is between 0 and 1, the C<p2_in>
tween will be where a linear tween would be at time C<$t**2>.

All easing functions except linear ease have 3 variants: C<_in>, C<_out>, and
C<_in_out>. To get C<exponential> easing on the forward dir of the tween, you
use C<exponential_in> easing. To get it on both dirs, you use
C<exponential_in_out>.

These are the available easing functions. See C<eg/03-easing.pl> in the
distribution for a visual explanation. See
L<https://github.com/warrenm/AHEasing/blob/master/AHEasing/easing.c> for a math
explanation. The tweening functions originate from
L<http://robertpenner.com/easing/penner_chapter7_tweening.pdf>.

=over 4

=item *

linear

=item *

p2

=item *

p3

=item *

p4

=item *

p5

=item *

sine

=item *

circular

=item *

exponential

=item *

elastic

=item *

back

=item *

bounce

=back

=head2 PATHS


The simplest tween follows a linear path, the only option when tweening a 1
dimensional value. You can also use the linear path for tweening values up
to 4D, by providing the tween with an array ref of size 4 as the range:

  # constructing a tween in 4D
  range => [[0, 0, 0, 0], [320, 200, 10, 640]],

When tweening 2D values, you can customize the path the tween takes through the
plane. The path is given in the C<path> arg of the tween constructor hash. Some
paths also require a C<path_args> key to configure the path. Here are paths
available:

=over 4

=item linear

Requires one of 2 constructor args: C<range> or C<from + to>. If no C<range>
and no C<from> are given then the value is taken from the tween target using
the proxy. Thus you can tween a GOB from its current position to another
without specifying the current position twice. Here are the 3 options for
using the default linear path:

  # option 1: construct a tween only with "to", from is taken from the target
  to       => [320, 200]

  # option 2: provide "from" + "to"
  from     => [  0,   0]
  to       => [320, 200]

  # option 3: provide "range"
  range    => [[0, 0], [320, 200]]

=item sine

Tweens a value along a sine curve. Uses the same C<from + to> setup as the
linear path, but requires C<path_args> with amplitude and frequency.

  range     => [[0, 0], [320, 200]]
  path      => 'sine',
  path_args => {amp => 100, freq => 2},

=item circular

Tweens a value along a circle with a given radius and center, between 2 angles.

  path      => 'circle',
  path_args => {
      center       => [320, 200],
      radius       => 100,
      begin_angle  => 0,
      end_angle    => 2*pi,
  },

=item spiral

Tweens a value along a spiral.

  path      => 'spiral',
  path_args => {
      center       => [320, 200],
      begin_radius => 50,
      end_radius   => 150,
      begin_angle  => 0,
      rotations    => 3,
  },


=item polyline

Tweens a value along an array of segments, specified by the xy coordinates of
the waypoints. The tween will start at the 1st waypoint and continue until the
last following a linear path.

  path      => 'polyline',
  path_args => { points => [
        [200, 200],
        [600, 200],
        [200, 400],
        [600, 400],
        [200, 200],
  ]},

=back


=head2 COLOR TWEENING

Two special paths exists from tweening SDL colors in a linear path through the
4D space of RGBA.

=over 4

=item fade

Tween the opacity of a color between 2 values. To tween the opacity of some red
color from opaque to transparent:

  path => 'fade',
  from => 0xFF0000FF,
  to   => 0x00,

=item rgba

Tween a linear path between 2 points in the 4D color space. To transform red into
semi-transparent green:

  path => 'rgba',
  from => 0xFF0000FF,
  to   => 0x00FF00AA,

=back


=head2 SPAWNING IS TWEENING

If you need to spawn creeps, missiles, or whatever, you can tween the spawn 
method on your spawner with an integer wave number:

    $spawn_tween = $timeline->tween(
        duration => 10_000,
        on       => [spawn_creep => $gob],
        range    => [0, 9],
        round    => 1,
    );


Will call C<spawn_creep> once a second for 10 seconds with the numbers 0
through 9 as the only arg. You can use the value as the wave number. You
can also set an easing function to change the rate of spawning.


=head2 THE TAIL

The tail is a simple behavior for making one position follow another at a given
velocity. It is constructed from the timeline, like tweens, and takes 3
constructor args: speed, head, and tail. The speed is given in changes per
tick.  Head and tail should be given as array refs. The tail behavior will move
the position in the tail array ref towards the head array ref, even if the
head position changes.

For example, if you want a game object to follow the cursor, create an array
ref C<$cursor_pos> and set its elements on mouse move. This will be the head.
Create another array ref C<$gob_pos> for the game object position. This will be
the tail, whose elements will be changed by the behavior. It is the position 
array ref that you read in your paint handler. Then create the behavior:

  $rail = $timeline->tail(
      speed => 100/1000,
      head  => $cursor_pos,
      tail  => $gob_pos,
  );      


You can then control the tail as you would a tween.

The tail will stop when the distance to the head is smaller than 1, or when the
head passes through the tail.


=head2 MEMORY MANAGEMENT

There are two issues with tween memory management: how do you keep a ref to the
tween in game objects, and how does the tween keep ref to the game elements it 
changes.

The timeline only keeps weak refs to the tweens it creates, active or inactive.
This means you must keep a strong ref to the tween somewhere, usually in the
game object. When the game object goes out of the scope, the tween will stop,
be destroyed, and cleaned out of the timeline automatically.

The tween only keeps weak refs to the game elements (objects or array refs) it
changes. Usually other game object will have strong refs to them, as part of
the game scene graph. When the game object that is the target of the tween
goes out of scope, you must stop the tween, and never use it again. B<TODO> add
event for this and allow changing of targets.

=head2 ACCURACY

C<SDLx::Tween> takes into account rounding errors, the inaccuracy of the
C<SDLx::Controller> C<move_handler>, and the inaccuracy of time/distance limits
on behaviors. Used correctly, 2 tweens on the same path, one with duration 1
sec and the other 2 sec, will always meet every 2 cycles, even 100 years later.

To get this absolute accuracy with no errors growing over time, you need to set
ideal C< start/pause/resume> times when controling tween cycles.

Here is an example of starting 2 tweens which is I<NOT> accurate:

  # dont do this!
  $t1 = $timeline->tween(...);
  $t1->start;
  $t2 = $timeline->tween(...);
  $t2->start;


C<$t1> and C<$t2> will not have the same C<cycle_start_time>, and this applies
to all cycle control methods.  One way to get accuracy, is to start the tweens
through the timeline:

  # do this
  $t1 = $timeline->tween(...);
  $t2 = $timeline->tween(...);
  $timeline->start;
  

The timeline will make sure both tweens share the same C<cycle_start_time>.
Another way to get accuracy is to use the optional ideal time argument
of the cycle control methods:

  # or this
  $start_time = SDL::get_ticks;
  $t1 = $timeline->tween(...);
  $t1->start($start_time);
  $t2 = $timeline->tween(...);
  $t2->start($start_time);


When chaining tweens, the 2nd tween ideal start time should be set as the 1st  
tween start time + the tween duration.

When spawning tweens, compute the ideal spawn time, and make that the cycle
start time.

B<TODO> sugarize this and allow implicit passing of ideal times for
sequence/parallel/spawn tweens, then delete this section.


=head1 WHY

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

Perl SDL move handlers are rarely a simple linear progression. An ideal
tweening library should feature:

=over 4

=item *

tween any method, e.g. a Moose get/set accessor, or directly on an array

=item *

tween a property with several dimensions, e.g. xy position, some 4D color space

=item *

tween xy position not on a line, but on some curve

=item *

round the tween values, and pass only values when they change

=item *

smooth the motion with acceleration/deceleration using easing functions

=item *

make the tween bounce, repeat for N cycles or forever

=item *

pause/resume tweens

=item *

hasten/slow a tween, for example when creeps are suddenly given a speed bonus

=item *

follow a moving target, e.g. a homing missile with constant acceleration

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

C<SDLx::Tween> doesn't do everything yet.  See the C<TODO> file in the
distribution for planned features, and the docs above for supported features.


=head1 EXAMPLES

Tweening examples in the distribution dir C< eg/>:

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


=head1 BUGS

Very little safety in XS code. Lose your ref to the tween target (object or
array ref being set) and horrible things will happen on next tick.


=head1 AUTHOR

eilara <ran.eilam@gmail.com>

Big thanks to:

  Sam Hocevar, from 14 rue de Plaisance, 75014 Paris, France
  https://raw.github.com/warrenm

For his most excellent AHEasing lib which C<SDLx-Tween> uses for easing
functions. The license is in the C<tweencee/> dir. The library is at
L<https://github.com/warrenm/AHEasing>.

Check that page for some great info about easing functions.

Huge thanks to Zohar Kelrich <lumimies@gmail.com> for patient listening and
advice.


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Ran Eilam

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
