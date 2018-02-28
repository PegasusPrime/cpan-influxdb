#!/usr/bin/env perl
use warnings;
use strict;
use LWP::Simple;
use LWP::UserAgent;
use Date::Parse;

my $influx_db = "db_goes_here";
my $url = "http://metabase.cpantesters.org/tail/log.txt";
my $endpoint = "http://127.0.0.1:8086/write?db=$influx_db";
my @content = split(/\n/, get($url));
my $user = 'user';
my $pass = 'pass';
my $req = HTTP::Request->new(POST => $endpoint);
my $ua = LWP::UserAgent->new;
$ua->timeout(5);
$req->authorization_basic($user, $pass);

for my $line (@content) {
  chomp($line);
  #Remove first line since there is no data
  next if $line =~ /reports/;
  my @list = ();
  while($line =~ /(\[.*?\])/ig) {
    my $data = $1;
    $data =~ tr/[]//d;
    if (!$data) {
      $data = "unknown";
    }
    push(@list, $data);
  }
  #Decode cpu, os, compile flags
  my @arch = split(/-/, $list[4]);
  my $mapstr;
  my $tstamp = str2time($list[0]) . "000000000";;
  my $tester = $list[1];
  #Clean up tester name 
  $tester =~ s/\(.*\)//g;
  $tester =~ s/[^a-zA-Z0-9 _-]//g;
  $tester =~ s/ /\\ /g;
  #Clean up module name
  my $module = $list[3];
  $module =~ s/\//-/g;
  $module =~ s/\.tar\.gz//g;
  #If no special compile flags, say so
  if (!defined($arch[2])) {
    $mapstr = "cpan,os=$arch[1],cpu=$arch[0],compile=standard,tester=$tester,module=$module";
  } else {
    $mapstr = "cpan,os=$arch[1],cpu=$arch[0],compile=$arch[2],tester=$tester,module=$module";
  }
  #Since I need to report some integer I use 1, -1, -2, -3 to indicate status
  if ($list[2] eq "pass") {
    $mapstr .= " pass=1i $tstamp\n";
  } elsif ($list[2] eq "na") {
    $mapstr .= " pass=-1i $tstamp\n";
  } elsif ($list[2] eq "unknown") {
    $mapstr .= " pass=-2i $tstamp\n";
  } else {
    $mapstr .= " pass=-3i $tstamp\n";
  }
  $req->content($mapstr);
  my $resp = $ua->request($req);
  if (!$resp->is_success) {
    print "Error: " . $resp->code ."\n";
    print "Tried $mapstr\n";
  }
}
