#!/home/acme/Public/perl-5.14.2/bin/perl
use 5.14.0;
use strict;
use warnings;
use Config::Tiny;
use DateTime::Format::Mail;
use Email::MIME::CreateHTML;
use Encode;
use Mail::IMAPClient;
use Try::Tiny;
use XML::Feed;

my $config = Config::Tiny->read( shift || 'twimap.conf' );
$config->{imap}->{Uid}       = 1;

my $mailbox = $config->{_}->{mailbox} || die "No mailbox";

my $imap = Mail::IMAPClient->new( %{ $config->{imap} } )
    or die "new failed: $@\n";

$imap->select($mailbox) or die "Select $mailbox error: ", $imap->LastError;

warn "Fetching message ids...";

my $message_ids
    = $imap->fetch_hash('BODY.PEEK[HEADER.FIELDS (Message-Id)]')
    or die "Fetch hash $mailbox error: ", $imap->LastError;
my %feed_ids;

foreach my $uid ( keys %$message_ids ) {
    my $message_id
        = $message_ids->{$uid}->{'BODY[HEADER.FIELDS (MESSAGE-ID)]'};
    my $feed_id = _header_to_id($message_id);
    next unless $feed_id;
    $feed_ids{$feed_id} = 1;
}

use Data::Dumper; warn Dumper(\%feed_ids);

my $feed = XML::Feed->parse('feeds/anandtech.feed') or die XML::Feed->errstr;
say $feed->title;
say $feed->link;

for my $entry ($feed->entries) {
  say $entry->title;
  say $entry->link;
  # fix Anandtech RSS bug, sigh
  $entry->{entry}->{pubDate} =~ s/EDT.+$/EDT/;
  my $feed_id = '<' . $entry->id . '@' . $feed->link . '>';
  say $feed_id;
  next if $feed_ids{$feed_id};
  my $content = $entry->content;
  #say $content->body;
  say "";
  my $resolver = Email::MIME::CreateHTML::Resolver::LWP->new();
  my $email = Email::MIME->create_html(
          header => [
                  Date => DateTime::Format::Mail->format_datetime( $entry->issued ),
                  From => 'acme@astray.com',
                  To => 'acme@astray.com',
                  Subject => $feed->title . ': ' . $entry->title,
                  'Message-Id' => $feed_id,
          ],
          body => $content->body,
          resolver => $resolver,
  );

  #die $email->as_string;

  my $uid = $imap->append_string( $mailbox, encode_utf8( $email->as_string ) )
  or die "Could not append_string to $mailbox: ", $imap->LastError;

  #last;
}

# nicked from Email::Simple
sub _header_to_id {
  my $head = shift;
  my @headers;
  my $crlf = qr/\x0a\x0d|\x0d\x0a|\x0a|\x0d/;
  my $mycrlf = "\n";
  while ($head =~ m/\G(.+?)$crlf/go) {
    local $_ = $1;
    if (/^\s+/ or not /^([^:]+):\s*(.*)/) {
      # This is a continuation line. We fold it onto the end of
      #  the previous header.
      next if !@headers;  # Well, that sucks.  We're continuing nothing?
      (my $trimmed = $_) =~ s/^\s+//;
      $headers[-1][0] .= $headers[-1][0] =~ /\S/ ? " $trimmed" : $trimmed;
      $headers[-1][1] .= "$mycrlf$_";
    } else {
      push @headers, $1, [ $2, $_ ];
    }
  }
  my $id = $headers[1][0];
  $id =~ s/\s+$//;
  return $id;
}