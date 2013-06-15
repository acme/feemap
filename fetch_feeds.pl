#!/home/acme/Public/perl-5.14.2/bin/perl
use 5.14.0;
use strict;
use warnings;
use Cache::File;
use File::Slurp;
use URI::Fetch;

my $feeds = {
  anandtech => 'http://www.anandtech.com/rss/',
};

my $cache = Cache::File->new( cache_root => 'cache/' );

foreach my $name (keys %$feeds) {
  my $uri = $feeds->{$name};
  say "$name at $uri";
  my $res = URI::Fetch->fetch($uri, Cache => $cache) or die URI::Fetch->errstr;
  my $filename = "feeds/$name.feed";
  write_file($filename, $res->content);
}
