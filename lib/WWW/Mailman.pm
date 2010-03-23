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
        my $segment = shift @segments || '';
        croak "Invalid URL $uri: no 'mailman' segment"
            if $segment ne 'mailman';
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

sub _load_uri {
    my ( $self, $uri ) = @_;
    my $mech = $self->robot;
    $mech->get($uri);

    # authentication required?
    if ( my $form = $self->_login_form ) {
        $mech->request( $form->click );
        croak "Couldn't login on $uri" if $self->_login_form;
    }

    # we're on!
}

#
# INTERNAL UTILITY FUNCTIONS
#
sub _form_data {
    return {
        map {
            $_->type eq 'submit' || $_->readonly
                ? ()    # ignore buttons and read-only inputs
                : ( $_->name => $_->value )
            } $_[0]->inputs
    };
}

#
# ACTIONS
#

# The option form has 5 submit buttons, listed here with their inputs:
#
# * change-of-address:
#   - new-address
#   - confirm-address
#   - fullname
#   - changeaddr-globally
# * unsub:
#   - unsubconfirm
# * othersubs
# * emailpw
# * changepw:
#   - newpw
#   - confpw
#   - pw-globally
# * options-submit:
#   - disablemail
#   - deliver-globally
#   - digest
#   - mime
#   - mime-globally
#   - dontreceive
#   - ackposts
#   - remind
#   - remind-globally
#   - conceal
#   - rcvtopic
#   - nodupes
#   - nodupes-globally

# most routines will be identical, so generate them:
{
    my %options = (
        address  => 'change-of-address',
        unsub    => 'unsub',
        changepw => 'changepw',
        options  => 'options-submit',
    );
    while ( my ( $method, $button ) = each %options ) {
        no strict 'refs';
        *$method = sub {
            my ( $self, $options ) = @_;

            # select the options form
            my $mech = $self->robot;
            $self->_load_uri( $self->_uri_for( 'options', $self->email ) );
            $mech->form_with_fields('fullname');

            # change of options
            if ($options) {
                $mech->set_fields(%$options);
                $mech->click($button);
                $mech->form_with_fields('fullname');
            }

            return _form_data( $mech->current_form );
        };
    }
}

# emailpw doesn't need any parameter
sub emailpw {
    my ($self) = @_;

    # no auto-authenticate
    my $mech = $self->robot;
    $mech->get( my $uri = $self->_uri_for( 'options', $self->email ) );

    if ( $mech->form_with_fields('emailpw') ) {
        $mech->click('emailpw');
    }
    elsif ( $mech->form_with_fields('login-remind') ) {
        $mech->click('login-remind');
    }
    else {
        croak "Unable to find a password email form on $uri";
    }
}

# othersubs needs some parsing to be useful
sub othersubs {
    my ($self) = @_;
    my $mech = $self->robot;
    $self->_load_uri( $self->_uri_for( 'options', $self->email ) );
    $mech->form_with_fields('fullname');
    $mech->click('othersubs');

    my $uri = $mech->uri;
    return
        map { URI->new_abs( $_, $uri ) }
        $mech->content =~ m{<li><a href="([^"]+)">[^<]+</a>}g;
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

    # authentication is automated, no need to think about it

    # user options: get / change / update
    my $options = $mm->options();
    $options->{nodupes} = 0;
    $mm->options( $options );

    # just change one item
    $mm->options( { digest => 1 } );

=head1 DESCRIPTION

C<WWW::Mailman> is a module to control B<Mailman> (as a subscriber,
moderator or administrator) without the need of a web browser.

The module handles authentication transparently and can take advantage
of stored cookies to speed it up.

It is meant as a building block for your own Mailman-managing scripts,
and will include more routines in the future.


=head1 METHODS

=head2 Constructor

=over 4

=item new( %options )

The C<new()> method returns a new C<WWW::Mailman> object. It accepts all
accessors (see below) as parameters.

=back

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


=head1 ACTION METHODS

C<WWW::Mailman> is used to interact with Mailman through its web
inteface. Most of the useful methods are therefore related to
the web interface itself.

=head2 Options

Note that since Mailman's C<options> form has six submit buttons,
each of them managing only a subset of this form's input fields,
the handling of this form has been split in six different routines.

=over 4

=item options( [ \%options ] )

Get the user options as a reference to a hash.

If an hash reference is passed as parameter, the given options will
be updated.

=item address( [ \%options ] )

Change the user email address (when reading, the field is empty)
and real name.

Parameters are: C<new-address>, C<confirm-address>, C<fullname>
and C<changeaddr-globally>.

=item changepw( [ \%options ] )

Change the user password for the mailing list.

Parameters are: C<newpw>, C<confpw> and C<pw-globally>.

=item unsub( [ \%options ] )

Unsubscribe the user from this mailing-list.

The parameter C<unsubconfirm> must be set to B<1> for the unsubscription
to be acted upon.

=item othersubs( )

Returns a list of Mailman-managed mailing-lists, that this user is
subscribed to on the same Mailman instance.

B<Note:> if you're logged in as an admin (or have an admin cookie),
this method may return an empty list (this is a bug in Mailman's interface).

=item emailpw( )

Request the password to be emailed to the user.

This method doesn't require authentication.

=back


=head1 EXAMPLES

See the distribution's F<eg/> directory for more examples.

Here's a script to update one's options across a number of mailing-lists:

    #!/usr/bin/perl
    use strict;
    use warnings;
    use WWW::Mailman;
    use YAML::Tiny qw( LoadFile );

    # some useful files
    my %opts  = ( cookie_file => 'mailman.cookie' );
    my $lists = LoadFile('mailman.yml');

    # mailman.yml looks like this:
    # ---
    # - uri: http://lists.example.com/mailman/listinfo/example
    #   email: user@example.com
    #   password: s3kr3t

    # I want to receive duplicates!
    for my $list (@$lists) {
        my $mm = WWW::Mailman->new( %opts, %$list );
        $mm->options( { nodupes => 0 } );
    }


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

I'm not the only that would like to avoid using a
web interface to interact with mailing-list software:
L<http://www.jwz.org/doc/mailman.html>

=head1 COPYRIGHT

Copyright 2010 Philippe Bruhat (BooK), all rights reserved.

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

