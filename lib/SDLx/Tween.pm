package SDLx::Tween;

use 5.010001;
use strict;
use warnings;
use Carp;
use SDL;
use XS::Object::Magic;

our $VERSION = '0.01';

require DynaLoader;
use base 'DynaLoader';
bootstrap SDLx::Tween;

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
)};

my %Proxy_Lookup;
do { my $i = 0; %Proxy_Lookup = map { $_ => $i++ } qw(
    method
    array
)};

# TODO
#   auto from setting
sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;

    my $ease  = $Ease_Lookup{  $args{ease}  || 'linear' };
    my $path  = $Path_Lookup{  $args{path}  || 'linear' };
    my $proxy = $Proxy_Lookup{ $args{proxy} || 'method' };

    my $path_args  = $args{path_args};
    my $proxy_args = $args{proxy_args};

    if (!$proxy_args) {
        if ($proxy == 0) {
            die 'No "set"/"on" given' unless exists($args{set}) && exists ($args{on});
            $proxy_args  = {
                target => $args{on},
                method => $args{set},
            };
        } elsif ($proxy == 1) {
            die 'No "on" given' unless exists $args{on};
            # make sure they are all floats not ints
            # is there no better way?! SvNOK_on seems to fail need to replace scalar?
            for (@{$args{on}}) { $_ += 0.000000000001 }
            $proxy_args = {on => $args{on}};
        }
    }

    if ($path < 2) {                    # paths that need "from" get sugar
        if ($proxy == 0) {              # for proxies that can get "from"
            if (!exists($args{from})) { # if "from" not given then
                if (                    # you don't need to provide it!
                    !$path_args ||
                    ($path_args && !exists($path_args->{from}))
                ) {
                    # get "from" from proxy and put in args
                    my $method = $proxy_args->{method};
                    my $from = $proxy_args->{target}->$method;
                    ($path_args || \%args)->{from} = $from;
                }
            }
        }
    }

    # you must provide path_args or from+to in args for some paths
    if (!$path_args && $path < 2) {
        die 'No from/to given' unless exists($args{from}) && exists ($args{to});
        $path_args  = {
            from => $args{from},
            to   => $args{to},
        };
    }
    if ($path < 2 && !exists($path_args->{to})) {
        die 'No "to" given' unless exists $args{to};
        $path_args->{to} = $args{to};
    }

    $proxy_args->{round} = $args{round} || 0;

    my $register_cb   = $args{register_cb}   || sub {}; 
    my $unregister_cb = $args{unregister_cb} || sub {};
    my $duration      = $args{duration}      || die 'No positive duration given';

    # non linear paths only in 2D
    if ($path != 0) {
        # find dim
        my $dim = $path_args && exists($path_args->{from})? @{$path_args->{from}}:
                  $proxy == 1                             ? @{$proxy_args->{on}}:
                  die "Unknown dimension for tween";
        die "Non-linear paths can only do 2D" unless $dim == 2;
    }

    my @args = (

        $register_cb, $unregister_cb, $duration,

        $args{forever} || 0,
        $args{repeat}  || 0,
        $args{bounce}  || 0,

        $ease,
        $path, $path_args,
        $proxy, $proxy_args,
    );
    $self->build_struct(@args);
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
