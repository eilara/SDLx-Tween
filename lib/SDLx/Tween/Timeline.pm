package SDLx::Tween::Timeline;

use Moose;
use Scalar::Util qw(weaken);
use Set::Object::Weak qw(weak_set);
use SDL;
use SDLx::Tween;

has is_paused => (is => 'rw', default => 0);

has tweens => (is => 'ro', lazy_build => 1, handles => [qw(members clear)]);

sub _build_tweens { weak_set() }

sub tween {
    my ($self, %args) = @_;
    my $tweens = $self->tweens;
    weaken $tweens;
    my $tween = SDLx::Tween->new(
        register_cb   => sub { $tweens->insert(shift) },
        unregister_cb => sub { $tweens->remove(shift) },
        %args,
    );
    return $tween;
}

sub tick {
    my $self = shift;
    my $ticks = SDL::get_ticks;
    $_->tick($ticks) for $self->members;
}

sub pause {
    my ($self, $pause_time) = @_;
    $pause_time ||= SDL::get_ticks;
    $_->pause($pause_time) for $self->members;
}

1;
