#!/usr/bin/perl

#------------------------------------------------------------------------------
#
# Standard pragmas
#
#------------------------------------------------------------------------------

use strict;

use Getopt::Long;
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

my %args;
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
