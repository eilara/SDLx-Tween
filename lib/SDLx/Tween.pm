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
)};

my %Paths_Requiring_Edge_Value_Args = map { $Path_Lookup{$_} => 1 } qw(
    linear
    sine
    fade
);

my %Paths_On_Color = map { $Path_Lookup{$_} => 1 } qw(
    fade
);

my %Path_Get_Dim = (
    $Path_Lookup{linear}   => \&compute_dim_path_with_edge_values,
    $Path_Lookup{sine}     => \&compute_dim_path_with_edge_values,
    $Path_Lookup{circular} => \&compute_dim_path_centered,
    $Path_Lookup{spiral}   => \&compute_dim_path_centered,
    $Path_Lookup{polyline} => \&compute_dim_path_polyline,
    $Path_Lookup{fade}     => \&compute_dim_path_color,
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
    my $duration      = $args{duration}      || die 'No positive duration given';

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
    my $self = bless($struct, $class);
    return $self;
}



sub build_proxy_array {
    my $args = shift;
    my $on = $args->{on} || die 'No "on" array given to array proxy';
    # make sure they are all floats not ints
    # is there no better way?! SvNOK_on seems to fail need to replace scalar?
    for (@$on) { $_ += 0.000000000001 }
    return {on => $on};
}

sub build_proxy_method {
    my $args = shift;
    die 'No "set"/"on" given' unless exists($args->{set}) && exists ($args->{on});
    return {
        target => $args->{on},
        method => $args->{set},
        round  => $args->{round} || 0,
    };
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
    return $dim;
}

sub compute_dim_path_color {
    my $path_args = shift;
# TODO arg checks on color args?
    return 1;
}


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
