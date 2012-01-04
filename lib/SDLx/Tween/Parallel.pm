package SDLx::Tween::Parallel;

use Moose;

extends 'SDLx::Tween::Group';

sub start {
    my ($self, $ticks) = @_;
    $ticks ||= SDL::get_ticks;
    my $register = $self->register_cb;
    $register->($self) if $register;
    $_->start($ticks) for @{$self->children};
}

sub stop {
    my $self = shift;
    my $unregister = $self->unregister_cb;
    $unregister->($self) if $unregister;
    $_->stop for @{$self->children};
}

sub tick {
    my ($self, $ticks) = @_;
    return if $self->is_paused;
    $ticks ||= SDL::get_ticks;
    $_->tick($ticks) for @{$self->children};
}

sub pause {
    my ($self, $pause_time) = @_;
    return if $self->is_paused;
    $pause_time ||= SDL::get_ticks;
    $_->pause($pause_time) for @{$self->children};
    $self->is_paused(1);
}

sub resume {
    my ($self, $resume_time) = @_;
    return unless $self->is_paused;
    $resume_time ||= SDL::get_ticks;
    $_->resume($resume_time) for @{$self->children};
    $self->is_paused(0);
}


1;
