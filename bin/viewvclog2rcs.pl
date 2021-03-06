#!/usr/bin/perl
use strict;
use Path::Class;
use lib file (__FILE__)->dir->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->subdir ('modules/manakai/lib')->stringify;
our $VERSION = '1.0';

my $log_uri;
my $original_base_url;

use Getopt::Long;
use Pod::Usage;
GetOptions (
  'log-uri=s' => \$log_uri,
  'original-base-url=s' => \$original_base_url,
);
pod2usage ({
  -input => file (__FILE__)->dir->file ('viewvclog2rcs.pod')->stringify,
  -verbose => 1,
}) unless defined $log_uri;

my $diff_command = 'diff';
my $diff_options = ['--rcs', '-a'];

require Message::DOM::DOMImplementation;
my $dom = 'Message::DOM::DOMImplementation';

if ($log_uri !~ m[^[^/:]+:]) {
  use Cwd;
  my $base_url = 'file://' . dir (getcwd)->absolute . '/';
  $log_uri = $dom->create_uri_reference ($log_uri)
      ->get_absolute_reference ($base_url)->uri_reference;
}
my $ent = get_remote_entity ($log_uri);
unless (defined $ent->{s}) {
  die "<$log_uri>: $ent->{error_status_text}";
}

require RCSFormat;

sub htunescape ($) {
  my $s = shift;
  $s =~ s!<[^<>]+>!!g;
  $s =~ s/&lt;/</g;
  $s =~ s/&gt;/>/g;
  $s =~ s/&amp;/&/g;
  $s =~ s/&quot;/\x22/g;
  $s =~ s/&#([0-9]+);/chr $1/ge;
  $s =~ s/&#x([0-9A-Fa-f]+);/chr hex $1/ge;
  return $s;
} # htunescape

my $rcs = new RCSFormat;
$rcs->{admin}->{strict} = 1;
$rcs->{admin}->{comment} = '# ';
$rcs->{admin}->{expand} = 'b';

my $text = {};
my $text_from = {};

#if ($ent->{s} =~ m!<title>CVS log for ([^<>]+)</title>!gc) {
#  $info->{file_path} = htunescape ($1);
#}

my $default_branch = 'MAIN';
#if ($ent->{s} =~ m[<[Pp]>\s*Default branch: ([^<]+)<(?>br|BR)>]gc) {
#  $default_branch = [split /,/, $1, 2]->[0];
#
#  #if ($ent->{s} =~ m[\G\s*Current tag: ([\w_-]+)<(?>br|BR)>]gc) {
#  #  
#  #}
#}

my $branches = {};
my $branch_rev = {};
if ($ent->{s} =~ m[View only Branch]gc) {
  while ($ent->{s} =~ m[<option value="([^"]+)"|</select]gc) {
    last unless defined $1;
    $branches->{$1} = 1;
  }
}

pos ($ent->{s}) = 0;

REV: while ($ent->{s} =~ m!<(?>hr|HR) (?>(?>size|SIZE)="?1"? (?>noshade|NOSHADE)>|/>\s*<a name="rev)!gc) {
  my $rev = '';

  #warn substr $ent->{s}, pos $ent->{s}, 100;
  
  if ($ent->{s} =~ m[\G(?:(?!<[Hh][Rr])[\s\S])*?Revision]gc and
      ($ent->{s} =~ m[\G(?:(?!<[Hh][Rr])[\s\S])*?<[aA] (?>href|HREF)="([^"]+)"[^<>]*>(?:<[bB]>)?([0-9.]+|view)(?:</[bB]>)?</[aA]>]gc or
       $ent->{s} =~ m[\G(?:(?!<[Hh][Rr])[\s\S])*?()<b>([0-9.]+)</b>(?: <i>\(vendor branch\)</i>|)(?:: <a href="([^"]+)" class="download-link">download</a>|)]gc)) {
    $rev = $2;
    if (not defined $3 and $1 eq '') {
      $rcs->{delta}->{$rev}->{state} = 'dead';
    } else {
      my $uri = htunescape (defined $3 ? $3 : $1);
      if ($rev eq 'view' and $uri =~ /\?revision=([0-9.]+)\b/) {
        $rev = $1;
      }
      $uri =~ s[&content-type=text/(?>x-cvsweb|vnd\.viewcvs)-markup$][&content-type=text/plain];
      $uri =~ s[&view=markup$][&content-type=text/plain&view=co];

      if (defined $original_base_url) {
        $uri = $dom->create_uri_reference ($uri)
                   ->get_relative_reference ($original_base_url)
                   ->uri_reference;
      }

      $uri = $dom->create_uri_reference ($uri)
                 ->get_absolute_reference ($log_uri)
                 ->uri_reference;

      my $revent = get_remote_entity ($uri);
      if (defined $revent->{s}) {
        $text->{$rev} = $revent->{s};
      } else {
        warn "<$uri>: $revent->{error_status_text}";
      }

      #$rcs->{admin}->{head} ||= $rev;
      $rcs->{delta}->{$rev}->{state} = 'Exp';
    }
  }

  if ($ent->{s} =~ m!<(?>i|I|em)>\w+ (\w+)\s*(\d+)\s*(\d+):(\d+):(\d+) (\d+) UTC</(?>i|I|em)>\s*\([^()]+\)\s*by <(?>i|I|em)>([^<>]+)</(?>i|I|em)>!gc) {
    $rcs->{delta}->{$rev}->{date} = sprintf '%02d.%02d.%02d.%02d.%02d.%02d',
        $6, {
          Jan => '01', Feb => '02', Mar => '03', Apr => '04',
          May => '05', Jun => '06', Jul => '07', Aug => '08',
          Sep => '09', Oct => '10', Nov => '11', Dec => '12',
        }->{$1}, $2, $3, $4, $5;
    $rcs->{delta}->{$rev}->{author} = $7;
  }

  $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>\s*Branch(?:es|):((?>(?!<(?>[bhBH][rR]|pre|PRE)).)+)]gcs) {
    my $b = $1;
    while ($b =~ m!(?:><(?:b|B|strong)>|(?:<[bB]>|)<[Aa] (?>href|HREF)="[^"]+">)([^<>]+)</(?>[bBaA]|strong)>!gc) {
      my $branch = $1;
      if ($branch ne $default_branch) {
        my $rev = $rev;
        $rev =~ s/\.(\d+)\.\d+\z//;
        push @{$rcs->{admin}->{symbols} ||= []}, [$branch => "$rev.0.$1"];
      } else {
        $rcs->{admin}->{head} ||= $rev if $rev =~ /^\d+\.\d+$/;
      }
    }
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;
  }

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>\s*Branch point]gc) {
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;
  }

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>\s*CVS [Tt]ags:((?>(?!<(?>[bhBH][rR]|pre|PRE)).)+)]gcs) {
    my $b = $1;
    while ($b =~ m!(?:><(?>b|B|strong)>|<[aA] (?:href|HREF)="[^"]+">)([^<>]+)</(?>[bBaA]|strong)>!gc) {
      my $rev = $branches->{$1} ? "$rev.0.".((++$branch_rev->{$rev})*2) : $rev;
      if ($1 eq 'HEAD') {
        $rcs->{admin}->{head} = $rev if $rev =~ /^\d+\.\d+$/;
        $rcs->{deltatext}->{$rev}->{text} = $text->{$rev};
      } else {
        push @{$rcs->{admin}->{symbols} ||= []}, [$1 => $rev];
      }
    }
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc; 
  }

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>Branch point]gcs) {
    ## We ignore "branch point" since it is not possible to restore
    ## branch tag's revision number.
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;
  }

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>\s*Diff to:]gcs) {
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;
  }

  if ($ent->{s} =~ m[\G<(?>br|BR)(?> /)?>\s*<b><i>FILE REMOVED</i></b>]gcs) {
    $ent->{s} =~ m[(?=<(?>br|BR|pre|PRE)\b)]gc;
  }

  if ($ent->{s} =~ m!\G<(?>br|BR)(?> /)?>\s*Changes since (?:<(?>b|B|strong)>|revision\s+)([0-9.]+):!gc) {
    my $from_rev = $1;
    if ($rev =~ /\A[0-9]+\.[0-9]+\z/) {
      $rcs->{delta}->{$rev}->{next} = $from_rev;
      $text_from->{$from_rev} = $rev;
    } elsif ($from_rev =~ /\A[0-9]+\.[0-9]+\z/) {
      push @{$rcs->{delta}->{$from_rev}->{branches} ||= []}, $rev;
      $text_from->{$rev} = $from_rev;
    } else {
      $rcs->{delta}->{$from_rev}->{next} = $rev;
      $text_from->{$rev} = $from_rev;
    }
  }

  if ($ent->{s} =~ m!<(?>pre|PRE)(?> class="(?:vc_|)log")?>(.*?)</(?>pre|PRE)>!gcs) {
    my $x = $1;
    $x =~ s/^\x0D?\x0A//;
    $rcs->{deltatext}->{$rev}->{log} = htunescape ($x);
  } else {
    $rcs->{deltatext}->{$rev}->{log} = '';
  }
} # REV

$rcs->{admin}->{head} ||= '1.1';
delete $text_from->{$rcs->{admin}->{head}};

my %symbol;
for (@{$rcs->{admin}->{symbols} || []}) {
  $symbol{$_->[0]} = $_->[1];
}
$rcs->{admin}->{symbols} = [map {[$_ => $symbol{$_}]} keys %symbol];

{
  my $head_rev = $rcs->{admin}->{head};
  my $prev_rev = $rcs->{delta}->{$head_rev}->{next};
  if ($rcs->{delta}->{$head_rev}->{state} eq 'dead' and
      $rcs->{delta}->{$prev_rev}->{state} eq 'Exp' and
      not defined $text->{$head_rev} and
      defined $text->{$prev_rev}) {
    $rcs->{deltatext}->{$head_rev}->{text} = $text->{$prev_rev};
  }
}

require File::Temp;
require IPC::Open2;
my $DEBUG = $ENV{DEBUG};
for my $rev (keys %$text_from) {
  next unless defined $text->{$text_from->{$rev}};
  
    my $from_file = new File::Temp (UNLINK => !$DEBUG);
    binmode $from_file;
    $from_file->print ($text->{$text_from->{$rev}});
    my $to_file = new File::Temp (UNLINK => !$DEBUG);
    binmode $to_file;
    $to_file->print ($text->{$rev});
    IPC::Open2::open2 (my $diffin, my $diffout,
                       $diff_command, @{$diff_options},
                       $from_file->filename => $to_file->filename)
        or die "$0: $diff_command: $!";
    binmode $diffin;
    local $/ = undef;
    $rcs->{deltatext}->{$rev}->{text} = <$diffin>;
    if ($DEBUG) {
      warn "old ($text_from->{$rev}): $from_file\n";
      warn "new ($rev): $to_file\n";
    }
}

if (defined $rcs->{admin}->{head} and
    $rcs->{deltatext}->{$rcs->{admin}->{head}} and
    not defined $rcs->{deltatext}->{$rcs->{admin}->{head}}->{text}) {
  $rcs->{deltatext}->{$rcs->{admin}->{head}}->{text} = $text->{$rcs->{admin}->{head}};
}

print $rcs->stringify;

sub get_remote_entity ($) {
  my $request_uri = $_[0];
  my $r = {};

  if ($request_uri =~ /^file:/) {
    $request_uri =~ s{\?rev=([0-9.]+)(?>&content-type=[^&]+)?$}{.$1};
    $request_uri =~ s{\?revision=([0-9.]+)&content-type=[^&]+&view=co$}{.$1};
  }

    my $uri = $dom->create_uri_reference ($request_uri);
    unless ({
             http => 1,
             https => 1,
             file => 1,
            }->{lc $uri->uri_scheme}) {
      return {uri => $request_uri, request_uri => $request_uri,
              error_status_text => 'URI scheme not allowed'};
    }

    require Message::Util::HostPermit;
    my $host_permit = new Message::Util::HostPermit;
    $host_permit->add_rule (<<EOH);
Deny host=localhost
Deny host=*.localdomain
Deny ipv4=0.0.0.0/8
Deny ipv4=10.0.0.0/8
Deny ipv4=127.0.0.0/8
Deny ipv4=169.254.0.0/16
Deny ipv4=172.0.0.0/11
Deny ipv4=192.0.2.0/24
Deny ipv4=192.88.99.0/24
Deny ipv4=192.168.0.0/16
Deny ipv4=198.18.0.0/15
Deny ipv4=224.0.0.0/4
Deny ipv4=255.255.255.255/32
Deny ipv6=0::0/0
Allow host=*
EOH
    if (lc $uri->uri_scheme eq 'http' or
        lc $uri->uri_scheme eq 'https') {
      unless ($host_permit->check ($uri->uri_host, $uri->uri_port || 80)) {
        return {uri => $request_uri, request_uri => $request_uri,
                error_status_text => 'Connection to the host is forbidden'};
      }
    }

    require LWP::UserAgent;
    my $ua = WDCC::LWPUA->new;
    $ua->{wdcc_dom} = $dom;
    $ua->{wdcc_host_permit} = $host_permit;
    $ua->agent ('Mozilla'); ## TODO: for now.
    $ua->parse_head (0);
    $ua->protocols_allowed ([qw/http https file/]);
    $ua->max_size (1000_000);
    my $req = HTTP::Request->new (GET => $request_uri);
  warn "<$request_uri>...\n";
    my $res = $ua->request ($req);
    ## TODO: 401 sets |is_success| true.
    if ($res->is_success) {
      $r->{base_uri} = $res->base; ## NOTE: It does check |Content-Base|, |Content-Location|, and <base>. ## TODO: Use our own code!
      $r->{uri} = $res->request->uri;
      $r->{request_uri} = $request_uri;

      ## TODO: More strict parsing...
      my $ct = $res->header ('Content-Type');
      if (defined $ct and $ct =~ m#^([0-9A-Za-z._+-]+/[0-9A-Za-z._+-]+)#) {
        $r->{media_type} = lc $1;
      }
      if (defined $ct and $ct =~ /;\s*charset\s*=\s*"?(\S+)"?/i) {
        $r->{charset} = lc $1;
        $r->{charset} =~ tr/\\//d;
      }

      $r->{s} = ''.$res->content;
    } else {
      $r->{uri} = $res->request->uri;
      $r->{request_uri} = $request_uri;
      $r->{error_status_text} = $res->status_line;
    }

    $r->{header_field} = [];
    $res->scan (sub {
      push @{$r->{header_field}}, [$_[0], $_[1]];
    });
    $r->{header_status_code} = $res->code;
    $r->{header_status_text} = $res->message;

  return $r;
} # get_remote_entity

package WDCC::LWPUA;
BEGIN { push our @ISA, 'LWP::UserAgent'; }

sub redirect_ok {
  my $ua = shift;
  unless ($ua->SUPER::redirect_ok (@_)) {
    return 0;
  }

  my $uris = $_[1]->header ('Location');
  return 0 unless $uris;
  my $uri = $ua->{wdcc_dom}->create_uri_reference ($uris);
  unless ({
           http => 1,
          }->{lc $uri->uri_scheme}) {
    return 0;
  }
  unless ($ua->{wdcc_host_permit}->check ($uri->uri_host, $uri->uri_port || 80)) {
    return 0;
  }
  return 1;
} # redirect_ok

=head1 LICENSE

Copyright 2007-2017 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
