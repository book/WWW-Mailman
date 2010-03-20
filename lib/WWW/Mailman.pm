package WWW::Mailman;

use warnings;
use strict;

use Carp;
use URI;
use WWW::Mechanize;
use HTTP::Cookies;

our $VERSION = '0.01';

my @attributes = qw(
    secure server prefix list
    email password moderator_password admin_password
    robot cookie_file
);

#
# ACCESSORS / MUTATORS
#

# generic accessors
for my $attr (@attributes) {
    no strict 'refs';
    *{$attr} = sub {
        my $self = shift;
        return $self->{$attr} if !@_;
        return $self->{$attr} = shift;
    };
}

# specialized accessors
sub uri {
    my ( $self, $uri ) = @_;
    if ($uri) {
        $uri = URI->new($uri);

        # @segments = @prefix, 'mailman', $action, $list, @suffix
        my ( undef, @segments ) = $uri->path_segments;
        my @prefix;
        push @prefix, shift @segments
            while @segments && $segments[0] ne 'mailman';
        croak "Invalid URL $uri: no 'mailman' segment"
            if shift @segments ne 'mailman';
        croak "Invalid URL $uri: no action"
            if !shift @segments;

        # just keep the bits we need
        $self->server( $uri->host );
        $self->secure( $uri->scheme eq 'https' );
        $self->prefix( join '/', @prefix );
        $self->list( shift @segments );
    }

    # create a generic listinfo URL
    else {
        $uri = URI->new();
        $uri->scheme( $self->secure ? 'https' : 'http' );
        $uri->host( $self->server );
        $uri->path( join '/', $self->prefix, 'mailman', 'listinfo',
            $self->list );
    }
    return $uri;
}

#
# CONSTRUCTOR
#

sub new {
    my ( $class, %args ) = @_;

    # create the object
    my $self = bless {}, $class;

    # get attributes
    $self->$_( delete $args{$_} )
        for grep { exists $args{$_} } @attributes, 'uri';

    # bring in the robot
    my %mech_options = (
        agent => "WWW::Mailman/$VERSION",
        stack_depth => 2,    # make it a Bear of Very Little Brain
    );
    $mech_options{cookie_jar} = HTTP::Cookies->new(
        file           => $self->cookie_file,
        autosave       => 1,
        ignore_discard => 1, # Promise me you'll never forget me
    ) if $self->cookie_file;
    $self->robot( WWW::Mechanize->new(%mech_options) );

    return $self;
}

#
# PRIVATE METHODS
#
sub _uri_for {
    my ( $self, $action, @options ) = @_;
    my $uri = URI->new();
    $uri->scheme( $self->secure ? 'https' : 'http' );
    $uri->host( $self->server );
    $uri->path( join '/', $self->prefix || (),
        'mailman', $action, $self->list, @options );
    return $uri;
}

1;

__END__

=head1 NAME

WWW::Mailman - Interact with Mailman's web interface from a Perl program

=head1 SYNOPSIS

    use WWW::Mailman;

    my $mm = WWW::Mailman->new(

        # the smallest bit of information we need
        url      => 'http://lists.example.com/mailman/listinfo/example',

        # TIMTOWTDI
        server   => 'lists.example.com',
        list     => 'example',

        # user / authentication / authorization
        email    => 'user@example.com',
        password => 'roses',              # needed for user actions
        moderator_password => 'Fl0wers',  # needed for moderator actions
        admin_password     => 's3kr3t',   # needed for action actions

        # use cookies for quicker authentication
        cookie_file => "$ENV{HOME}/.mailmanrc",

    );

    # authentication is automated, so just point to the page you want

=head1 DESCRIPTION


=head1 METHODS

=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-mailman at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Mailman>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Mailman


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Mailman>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Mailman>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Mailman>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Mailman>

=back


=head1 ACKNOWLEDGEMENTS

My first attempt to control Mailman with C<WWW::Mechanize> is described
in French at L<http://articles.mongueurs.net/magazines/linuxmag58.html#h3>.

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

