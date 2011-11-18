package SDLx::Tween::Tail;

use 5.010001;
use strict;
use warnings;
use Carp;
use SDLx::Tween;

sub new {
    my ($class, %args) = @_;

    my $head  = $args{head}  || die 'No "head" give';
    my $tail  = $args{tail}  || die 'No "tail" give';
    my $speed = $args{speed} || die 'No "speed" given';

    my $register_cb   = $args{register_cb}   || sub {}; 
    my $unregister_cb = $args{unregister_cb} || sub {};

    my @args = (

        $register_cb, $unregister_cb,
        $speed,
        $head, $tail,
    );
    my $struct = new_struct(@args);
    my $self = bless([$struct], $class);
    return $self;
}

1;
