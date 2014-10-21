package Net::SMS::O2;

$VERSION = '0.017';
use strict;

use Net::SMS::Web;
use URI::Escape;

#------------------------------------------------------------------------------
#
# POD
#
#------------------------------------------------------------------------------

=head1 NAME

Net::SMS::O2 - a module to send SMS messages using the O2 web2sms
gateway (L<http://www.o2.co.uk/>).

=head1 SYNOPSIS

    my $sms = Net::SMS::O2->new(
        autotruncate => 1,
        username => 'yourname',
        password => 'yourpassword',
        recipient => 07713123456,
        subject => 'a test',
        message => 'a test message',
    );

    $sms->verbose( 1 );
    $sms->message( 'a different message' );
    print "sending message to mobile number ", $sms->recipient();

    $sms->send_sms();
    my $quota = $sms->quota();
    my $status = $sms->status();

=head1 DESCRIPTION

A perl module to send SMS messages, using the O2 web2sms gateway. This
module will only work with mobile phone numbers that have been registered with
O2 (L<http://www.o2.co.uk/>) and uses form submission to a URL that may be
subject to change. The O2 service is currently only available to UK mobile
phone users.

There is a maximum length for SMS subject + message (115 for O2). If the sum
of subject and message lengths exceed this, the behaviour of the
Net::SMS::O2 objects depends on the value of the 'autotruncate' argument to
the constructor. If this is a true value, then the subject / message will be
truncated to 115 characters. If false, the object will throw an exception
(die). If you set notruncate to 1, then the module won't check the message
length, and you are on your own!

=cut

#------------------------------------------------------------------------------
#
# Package globals
#
#------------------------------------------------------------------------------

use vars qw(
    @ISA
    $LOGIN_URL
    $SEND_URL 
    %REQUIRED_KEYS 
    %LEGAL_KEYS 
    $MAX_CHARS
);

@ISA = qw( Net::SMS::Web );

$SEND_URL = 'http://sendtxt.genie.co.uk/cgi-bin/sms/send_sms.cgi';
$LOGIN_URL = 'https://gordon.genie.co.uk/login/mblogin';

%REQUIRED_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    message => 1,
);

%LEGAL_KEYS = (
    username => 1,
    password => 1,
    recipient => 1,
    subject => 1,
    message => 1,
    verbose => 1,
);

$MAX_CHARS = 115;

#------------------------------------------------------------------------------
#
# Constructor
#
#------------------------------------------------------------------------------

=head1 CONSTRUCTOR

The constructor for Net::SMS::O2 takes the following arguments as hash
values (see L<SYNOPSIS|"SYNOPSIS">):

=head2 autotruncate (OPTIONAL)

O2 has a upper limit on the length of the subject + message (115). If
autotruncate is true, subject and message are truncated to 115 if the sum of
their lengths exceeds 115. The heuristic for this is simply to treat subject
and message as a string and truncate it (i.e. if length(subject) >= 115 then
message is truncated to 0. Thanks to Mark Zealey <mark@itsolve.co.uk> for this
suggestion. The default for this is false.

=head2 notruncate (OPTIONAL)

Of course, if you don't believe the O2 web interface about maximum character
length, then you can set this option.

=head2 username (REQUIRED)

The O2 username for the user (assuming that the user is already registered
at L<http://www.o2.co.uk/>.

=head2 password (REQUIRED)

The O2 password for the user (assuming that the user is already registered
at L<http://www.o2.co.uk/>.

=head2 recipient (REQUIRED)

Mobile number for the intended SMS recipient.

=head2 subject (REQUIRED)

SMS message subject.

=head2 message (REQUIRED)

SMS message body.

=head2 verbose (OPTIONAL)

If true, various soothing messages are sent to STDERR. Defaults to false.

=cut

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    $self->_init( @_ );
    return $self;
}

#------------------------------------------------------------------------------
#
# AUTOLOAD - to set / get object attributes
#
#------------------------------------------------------------------------------

=head1 AUTOLOAD

All of the constructor arguments can be got / set using accessor methods. E.g.:

        $old_message = $self->message;
        $self->message( $new_message );

=cut

sub AUTOLOAD
{
    my $self = shift;
    my $value = shift;

    use vars qw( $AUTOLOAD );
    my $key = $AUTOLOAD;
    $key =~ s/.*:://;
    return if $key eq 'DESTROY';
    die ref($self), ": unknown method $AUTOLOAD\n" 
        unless $LEGAL_KEYS{ $key }
    ;
    if ( defined( $value ) )
    {
        $self->{$key} = $value;
    }
    return $self->{$key};
}

=head1 METHODS

=head2 send_sms

This method is invoked to actually send the SMS message that corresponds to the
constructor arguments.

=cut

sub send_sms
{
    my $self = shift;

    unless ( $self->{is_logged_in} )
    {
        $self->action( Net::SMS::Web::Action->new(
            url     => $LOGIN_URL, 
            method  => 'GET',
            params  => {
                username => $self->{username},
                password => $self->{password},
                numTries => '',
            }
        ) );
        $self->{is_logged_in} = 1;
    }
    $self->action( Net::SMS::Web::Action->new(
        url     => $SEND_URL,
        method  => 'POST',
        params  => {
            RECIPIENT => $self->{recipient},
            SUBJECT => $self->{subject} || '',
            MESSAGE => $self->{message},
            check => 0,
            left => $MAX_CHARS - $self->{message_length},
            action => 'Send',
        }
    ) );

    my $cookie_params = $self->cookie( 'params' );
    my @fields = split( '=', $cookie_params );
    my %cookie_params = map { uri_unescape( uri_unescape( $_ ) ) } @fields;
    $self->{status} = $cookie_params{status};
    warn "status: $self->{status}\n";
    unless ( $self->{status} eq 'Your message has been sent successfully.' )
    {
        die "Failed to send SMS message", 
            ( $self->{status} ? ": $self->{status}" : '' ), "\n";
    }
    my $quota = $cookie_params{quota};
    ( $self->{quota} ) = 
        $quota =~ /You have (\d+) messages left to send this month./
    ;
    warn "quota: $self->{quota}\n";
}

=head2 status

This method returns the value returned in the 'status' parameter

=cut

sub status
{
    my $self = shift;
    return $self->{status};
}

=head2 quota

This method returns the number of messages remaining in your months quota. Only
works after send_sms has be called successfully.

=cut

sub quota
{
    my $self = shift;
    return $self->{quota};
}

sub _check_length
{
    my $self = shift;
    $self->{message_length} = 0;
    if ( $self->{autotruncate} )
    {
        # Chop the message down the the correct length. Also supports subjects
        # > $MAX_CHARS, but I think it's a bit stupid to send one, anyway ...
        # - Mark Zealey
        $self->{subject} = substr $self->{subject}, 0, $MAX_CHARS;
        $self->{message} = 
            substr $self->{message}, 0, $MAX_CHARS - length $self->{subject}
        ;
        $self->{message_length} += length $self->{$_} for qw/subject message/;
    }
    elsif ( ! $self->{notruncate} )
    {
        $self->{message_length} = 
            length( $self->{subject} ) + length( $self->{message} )
        ;
        if ( $self->{message_length} > $MAX_CHARS )
        {
            die ref($self), 
                ": total message length (subject + message)  is too long ",
                "(> $MAX_CHARS)\n"
            ;
        }
    }
}

sub _init
{
    my $self = shift;
    my %keys = @_;

    for ( keys %REQUIRED_KEYS )
    {
        die ref($self), ": $_ field is required\n" unless $keys{$_};
    }
    for ( keys %keys )
    {
        $self->{$_} = $keys{$_};
    }
    $self->_check_length();
}

#------------------------------------------------------------------------------
#
# More POD ...
#
#------------------------------------------------------------------------------

=head1 SEE ALSO

L<Net::SMS::Web>.

=head1 BUGS

Bugs can be submitted to the CPAN RT bug tracker either via email
(bug-net-sms-o2@rt.cpan.org) or web
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-SMS-O2>. There is also a
sourceforge project at L<http://sourceforge.net/projects/net-sms-web/>.

=head1 AUTHOR

Ave Wrigley <Ave.Wrigley@itn.co.uk>

=head1 COPYRIGHT

Copyright (c) 2001 Ave Wrigley. All rights reserved. This program is free
software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

1;
