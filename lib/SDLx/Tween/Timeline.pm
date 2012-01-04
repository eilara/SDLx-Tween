package SDLx::Tween::Timeline;

use Moose;
use Scalar::Util qw(weaken);
use Set::Object::Weak qw(weak_set);
use SDL;
use SDLx::Tween;
use SDLx::Tween::Tail;
use SDLx::Tween::Parallel;
use SDLx::Tween::Sequence;

has is_paused     => (is => 'rw', default => 0);

has all_tweens    => (is => 'ro', lazy_build => 1);
has active_tweens => (is => 'ro', lazy_build => 1);

has sdlx_app      => (is => 'ro', handles => [qw(add_move_handler remove_move_handler)]);
has move_handler  => (is => 'ro', lazy_build => 1);

sub _build_all_tweens    { weak_set() }
sub _build_active_tweens { weak_set() }

sub _build_move_handler {
    my $self = shift;
    weaken $self;
    return sub { $self->tick };
}

sub BUILD {
    my $self = shift;
    my $app = $self->sdlx_app;
    return unless $app;
    $app->add_move_handler($self->move_handler);
}

sub DESTROY {
    my $self = shift;
    $self->remove_move_handler($self->move_handler) if $self->sdlx_app;
}

sub tween    { shift->add_child('SDLx::Tween'           , @_) }
sub tail     { shift->add_child('SDLx::Tail'            , @_) }
sub parallel { shift->add_child('SDLx::Tween::Parallel' , @_) }
sub sequence { shift->add_child('SDLx::Tween::Sequence' , @_) }

sub add_child {
    my ($self, $class, %args) = @_;
    my $active_tweens = $self->active_tweens;
    weaken $active_tweens;
    my $tween = $class->new(
      register_cb   => sub { $active_tweens->insert(shift) },
      unregister_cb => sub { $active_tweens->remove(shift) },
      %args,
    );
    $self->all_tweens->insert($tween);
    return $tween;
}

sub tick {
    my ($self, $ticks) = @_;
    return if $self->is_paused;
    $ticks ||= SDL::get_ticks;
    $_->tick($ticks) for $self->active_tweens->members;
}


sub start {
    my ($self, $ticks) = @_;
    $ticks ||= SDL::get_ticks;
    $_->start($ticks) for $self->all_tweens->members;
}

sub stop {
    my $self = shift;
    $_->stop for $self->active_tweens->members;
}


sub pause {
    my ($self, $pause_time) = @_;
    return if $self->is_paused;
    $pause_time ||= SDL::get_ticks;
    $_->pause($pause_time) for $self->active_tweens->members;
    $self->is_paused(1);
}

sub resume {
    my ($self, $resume_time) = @_;
    return unless $self->is_paused;
    $resume_time ||= SDL::get_ticks;
    $_->resume($resume_time) for $self->active_tweens->members;
    $self->is_paused(0);
}

sub pause_resume {
    my ($self, $time) = @_;
    my $method = $self->is_paused? 'resume': 'pause';
    $self->$method($time);
}

1;
