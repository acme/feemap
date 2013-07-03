#!/home/acme/Public/perl-5.14.2/bin/perl
use 5.14.0;
use strict;
use warnings;
use Config::Tiny;
use DateTime::Format::Mail;
use Email::MIME::CreateHTML;
use Encode;
use IPC::Run3;
use LWP::Simple;
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

#use Data::Dumper; warn Dumper(\%feed_ids);


foreach my $name (keys %{$config->{feeds}}) {
  parse_feed($name);
}

sub parse_feed {
   my $name = shift;
   my $filename = "feeds/$name.feed";

  my $feed = XML::Feed->parse($filename) or die XML::Feed->errstr;
  say $feed->title;
  say $feed->link;

  for my $entry ($feed->entries) {
    say encode_utf8($entry->title);
    say $entry->link;
    # fix Anandtech RSS bug, sigh
    $entry->{entry}->{pubDate} =~ s/EDT.+$/EDT/;
    my $feed_id = '<' . $entry->id . '@' . $feed->link . '>';
    say $feed_id;
    next if $feed_ids{$feed_id};
    my $content = $entry->content;
    my $body = $content->body;
    my $html = get($entry->link);
    my $html_utf8 = encode_utf8($html);
    run3 ['node', 'readability.js'], \$html_utf8, \my $out, \my $err;
    warn $err if $err;
    $body = decode_utf8($out) if defined $out;
    say "";
    my $resolver = Email::MIME::CreateHTML::Resolver::LWP->new({
      base => $feed->link,
    });
    my $email = Email::MIME->create_html(
            header => [
                    Date => DateTime::Format::Mail->format_datetime( $entry->issued ),
                    From => Email::Address->new($feed->title)->format,
                    To => 'acme@astray.com',
                    Subject => encode('MIME-q', $feed->title . ': ' . $entry->title),
                    'Message-Id' => $feed_id,
            ],
            body => $body,
            body_attributes => { xxx => 'text/html; charset="UTF-8"' },
            resolver => $resolver,
    );
    $email->walk_parts(sub {
      my ($part) = @_;
      return if $part->subparts; # multipart
      if ( $part->content_type =~ m[text/html]i ) {
        $part->charset_set( 'UTF-8' );
      }
    });

    #die $email->as_string;

    foreach (1..10) {
      my $uid = $imap->append_string( $mailbox, encode_utf8( $email->as_string ) );
      last if $uid;
      warn "Could not append_string to $mailbox: ", $imap->LastError;
      $imap = Mail::IMAPClient->new( %{ $config->{imap} } )
          or die "new failed: $@\n";
      $imap->select($mailbox) or die "Select $mailbox error: ", $imap->LastError;
    }

    #last;
  }
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
