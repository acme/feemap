#!/home/acme/Public/perl-5.14.2/bin/perl
use 5.14.0;
use strict;
use warnings;
use Cache::File;
use Config::Tiny;
use File::Slurp;
use URI::Fetch;

my $config = Config::Tiny->read( shift || 'twimap.conf' );

foreach my $name (keys %{$config->{feeds}}) {
  my $uri = $config->{feeds}->{$name};
  say "$name at $uri";
  my $res = URI::Fetch->fetch($uri) or die URI::Fetch->errstr;
  my $filename = "feeds/$name.feed";
  write_file($filename, $res->content);
}
