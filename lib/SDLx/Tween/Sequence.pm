package SDLx::Tween::Sequence;

use Moose;

extends 'SDLx::Tween::Group';

has active_tween => (is => 'rw');

sub start {
    my ($self, $ticks) = @_;
    $ticks ||= SDL::get_ticks;
    my $register = $self->register_cb;
    $register->($self) if $register;
    my $active = $self->children->[0];
    $self->active_tween($active);
    $active->start($ticks);
}

sub stop {
    my $self = shift;
    my $unregister = $self->unregister_cb;
    $unregister->($self) if $unregister;
    $self->active_tween->stop;
}

sub tick {
    my ($self, $ticks) = @_;
    return if $self->is_paused;
    $ticks ||= SDL::get_ticks;
    $self->active_tween->tick($ticks);
}

sub pause {
    my ($self, $pause_time) = @_;
    return if $self->is_paused;
    $pause_time ||= SDL::get_ticks;
    $self->active_tween->pause($pause_time);
    $self->is_paused(1);
}

sub resume {
    my ($self, $resume_time) = @_;
    return unless $self->is_paused;
    $resume_time ||= SDL::get_ticks;
    $self->active_tween->resume($resume_time);
    $self->is_paused(0);
}


1;
