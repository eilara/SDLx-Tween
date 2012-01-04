package SDLx::Tween::Group;

use Moose;
use SDL;
use SDLx::Tween;

has is_paused     => (is => 'rw', default    => 0);
has children      => (is => 'ro', lazy_build => 1);
has child_defs    => (is => 'ro', required   => 1);
has repeat        => (is => 'rw', default    => 1);
has forever       => (is => 'rw', default    => 0);
has register_cb   => (is => 'rw');
has unregister_cb => (is => 'rw');
    
around BUILDARGS => sub {
    my ($orig, $class, @args) = @_;
    my %control = ref($args[0]) && ref($args[0]) eq 'ARRAY'?
        (@{ shift @args }): (repeat => 1);
    return $class->$orig(%control, child_defs => [@args]);
};

sub BUILD {
    my $self = shift;
    my @defs = @{ $self->child_defs };
    my @children;
    while (@defs) {
        my $thing = shift @defs;
        if (ref $thing) { # a tween child
            push @children, SDLx::Tween->new(%$thing);
        } else { # a group child
            my $def = shift @defs;
            my $class = $thing eq 'sequence'? 'SDLx::Tween::Sequence':
                        $thing eq 'parallel'? 'SDLx::Tween::Parallel':
                        die "Unknown tween group type: '$thing'";
            push @children, $class->new(@$thing);
        }
    }
    $self->children(\@children);
}

sub pause_resume {
    my ($self, $time) = @_;
    my $method = $self->is_paused? 'resume': 'pause';
    $self->$method($time);
}

1;
