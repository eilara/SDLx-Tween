package SDLx::Tween;

use 5.010001;
use strict;
use warnings;
use Carp;
use SDL;
use XS::Object::Magic;

our $VERSION = '0.01';
require XSLoader;
XSLoader::load('SDLx::Tween', $VERSION);

my %Ease_Lookup;
do {
    my $i = 0;
    %Ease_Lookup = map { $_ => $i++ } qw(
        linear
        swing
        out_bounce
        in_bounce
        in_out_bounce
    );
};

my %Path_Lookup;
do {
    my $i = 0;
    %Path_Lookup = map { $_ => $i++ } qw(
        linear
    );
};

# TODO
#   duration non zero
#   required params
#   auto from setting
sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    my $ease = $Ease_Lookup{ delete $args{ease} || 'linear' };
    my $path = $Path_Lookup{ delete $args{path} || 'linear' };

    # you must provide path_args or from+to in args for linear paths,
    # for other paths, no path_args or special keys in args needed
    my $path_args = delete $args{path_args};
    unless ($path_args) {
        $path_args = $args{path} eq 'linear'? {
            from => (delete($args{from}) || die 'No "from" value given'),
            to   => (delete($args{to})   || die 'No "to" value given'),
        }: {};
    }

    $self->build_struct(
        delete($args{register_cb}),
        delete($args{unregister_cb}),
        delete($args{tick_cb}),
        delete($args{duration}),
        delete($args{forever}) || 0,
        delete($args{repeat} ) || 1,
        delete($args{bounce} ) || 0,
        $ease, $path, $path_args,
    );
    return $self;
}

sub DESTROY { shift->free_struct }

1;

=head1 NAME

SDLx::Tween - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SDLx::Tween;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SDLx::Tween, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.

=head2 Exportable constants

  TESTVAL



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Ran Eilam, E<lt>eilara@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Ran Eilam

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
