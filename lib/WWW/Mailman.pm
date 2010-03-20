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
    robot
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

    # bring in the robot if needed
    if ( !$self->robot ) {
        my %mech_options = (
            agent => "WWW::Mailman/$VERSION",
            stack_depth => 2,    # make it a Bear of Very Little Brain
            quiet       => 1,
        );
        $mech_options{cookie_jar} = HTTP::Cookies->new(
            file => delete $args{cookie_file},
            ignore_discard => 1,    # Promise me you'll never forget me
            autosave       => 1,
        ) if exists $args{cookie_file};
        $self->robot( WWW::Mechanize->new(%mech_options) );
    }

    # some unknown parameters remain
    croak "Unknown constructor parameters: @{ [ keys %args ] }"
        if keys %args;

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

sub _login_form {
    my ($self) = @_;
    my $mech = $self->robot;

    # shortcut
    return if !$mech->forms;

    my $form;

    # login is required if the form asks for:
    # - a login/password
    if ( $form = $mech->form_with_fields('password') ) {
        $form->value( email    => $self->email );
        $form->value( password => $self->password );
    }

    # - an admin (or moderator) password
    elsif ( $form = $mech->form_with_fields('adminpw') ) {
        $form->value(
            adminpw => $self->admin_password || $self->moderator_password
        );
    }

    # no authentication required
    else {
        $form = undef;
    }

    return $form;
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

=head2 Constructor

The C<new()> method returns a new C<WWW::Mailman> object. It accepts all
accessors (see below) as parameters.

Extra parameters:

=over 4

=item cookie_file

If the I<robot> paramater is not given, the constructor will automatically
provide one (this is usually the best choice). If I<cookie_file> is provided,
the provided robot will read cookies from this file, and save them afterwards.

Using a cookie file will make your scripts faster, as the robot will not
have to fill in and post the authentication form.

=back

=head2 Accessors / Mutators

C<WWW::Mailman> supports the following accessors to its attributes:

=over 4

=item secure

Get or set the I<secure> parameter which, if true, indicates the Mailman
URL is accessible via the I<https> scheme.

=item server

Get or set the I<server> part of the web interface.

=item prefix

Get or set the I<prefix> part of the web interface.
(For the rare case when Mailman is not run from the top-level C</mailman/>
URL.)

=item list

Get or set the I<list> name.

=item uri

When used as an accessor, get the default I<listinfo> URI for the list.

When used as a mutator, set the I<secure>, I<server>, I<prefix> and I<list>
attributes based on the given URI.

=item email

Get or set the user's I<email>.

=item password

Get or set the user's I<password>.

=item moderator_password

Get or set the I<moderator password>.

=item admin_password

Get or set the I<administrator password>.

=item robot

Get or set the C<WWW::Mechanize> object used to access the Mailman
web interface.


=back

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

