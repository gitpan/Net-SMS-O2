#!/usr/bin/perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;

use Getopt::Long;
use App::Config;
use lib 'blib/lib';
use Net::SMS::O2;

my @options = qw(
    username=s
    password=s
    recipient=s
    message=s
    subject=s
    verbose
);

my $cfg_file = "$ENV{HOME}/.o2cfg";
my %args;
if ( -e $cfg_file )
{
    my $ac = App::Config->new;
    for ( qw( password username recipient ) )
    {
        $ac->define( $_ );
    }
    $ac->cfg_file( $cfg_file );
    %args = map { $_ => $ac->get( $_ ) } qw( password username recipient );
}
die <<USAGE unless GetOptions( \%args, @options );
$0 
    -username <username> 
    -password <password>
    -recipient <mobile no.>
    -message <message>
    [ -subject <subject> ]
    [ -verbose ]

USAGE

my $sms = Net::SMS::O2->new( %args );
$sms->send_sms();
