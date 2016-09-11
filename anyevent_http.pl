#!/usr/bin/perl -w

####################################################
#                                                  #
#  Get an OAuth2 Access Token with AnyEvent::HTTP  #
#  And testing Is there memory leak if looped      #
#                                                  #
####################################################

use warnings;
use strict;
use AnyEvent::HTTP;
use URL::Encode qw(url_encode_utf8);
use feature qw(say);
use Data::Dumper qw(Dumper);
use Memory::Usage;

select(STDERR);
local $| = 1;
select(STDOUT);
local $| = 1;

my $client_id = '';
my $client_secret = '';

my $url = 'https://login.windows.net/improwerk.onmicrosoft.com/oauth2/token?api-version=beta';
#my $url = 'http://localhost';
#my $url = 'http://google.com';
#my $url = 'https://google.com';

my $headers = {
				'User-Agent'     => 'nxlog',
				'Content-Type'   => 'application/x-www-form-urlencoded',
				'Referer'        => 'http://localhost/',
				'Content-Length' => 0
			  };
my $body = "grant_type=client_credentials&client_id=" . $client_id . "&client_secret=" . url_encode_utf8 ( $client_secret );

my $response = request ( $url, $headers, $body );
say ( Dumper ( $response ) );

my $i = 1;

my $mu = Memory::Usage -> new;
$mu -> record ( 'started' );
for ( ; ; )
{
	request ( $url, $headers, $body );
	print $i . ",";
	$i++;
	if ( $i > 100000 )
	{
		last;
	}
}
$mu -> record ( 'finished' );
$mu -> dump ();

sub request
{
	my $url     = $_[ 0 ];
	my $headers = $_[ 1 ];
	my $body    = $_[ 2 ];
    my $response_body;
    my $response_headers;
	my $exit_wait = AnyEvent -> condvar;
	http_post
	$url, 
	$body,
	headers => $headers,
	sub
	{
		my ( $body, $headers ) = @_;
        $response_body = $body;
        $response_headers = $headers;
	    $exit_wait -> send;
	};
	$exit_wait -> recv;
	return { 'response_body' => $response_body, 'response_headers' => $response_headers };
}

=pod

https://login.windows.net ... 10000x ( auth ok )

  time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
     0  46488 ( 46488)  13508 ( 13508)   5920 (  5920)      8 (     8)   7692 (  7692) started
  1582  46528 (    40)  13768 (   260)   6108 (   188)      8 (     0)   7732 (    40) finished

https://login.windows.net ... 10000x ( auth failed )

  time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
     0  46456 ( 46456)  13552 ( 13552)   5968 (  5968)      8 (     8)   7660 (  7660) started
  1339  46528 (    72)  13748 (   196)   6096 (   128)      8 (     0)   7732 (    72) finished

https://login.windows.net .. 100000x, ( auth ok )

  time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
     0  46456 ( 46456)  13584 ( 13584)   6000 (  6000)      8 (     8)   7660 (  7660) started
 15739  46528 (    72)  13848 (   264)   6192 (   192)      8 (     0)   7732 (    72) finished

http://google.com 10000x

  time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
     0  34220 ( 34220)   9996 (  9996)   3760 (  3760)      8 (     8)   6584 (  6584) started
  2304  34220 (     0)   9996 (     0)   3760 (     0)      8 (     0)   6584 (     0) finished


https://google.com 100x

time    vsz (  diff)    rss (  diff) shared (  diff)   code (  diff)   data (  diff)
     0  46452 ( 46452)  13524 ( 13524)   5944 (  5944)      8 (     8)   7656 (  7656) started
    42  46584 (   132)  13524 (     0)   5944 (     0)      8 (     0)   7788 (   132) finished

=cut