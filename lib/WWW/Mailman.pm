package WWW::Mailman;

use warnings;
use strict;

our $VERSION = '0.01';

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

