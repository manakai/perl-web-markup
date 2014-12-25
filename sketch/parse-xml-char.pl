use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Web::DOM::Document;
use Web::XML::Parser;
use Web::HTML::Dumper;
use Encode;

my $doc = new Web::DOM::Document;
my $parser = Web::XML::Parser->new;
$parser->scripting (not $ENV{NOSCRIPT});
$parser->locale_tag (lc $ENV{LANG}) if $ENV{LANG};

my $input = shift;
if (defined $input) {
  $input =~ s/\\x00/\x00/g;
} else {
  local $/ = undef;
  $input = <>;
}

$parser->onextentref (sub {
  my ($self, $data, $sub) = @_;
  $sub->parse_bytes_start (undef, $self);
  $sub->parse_bytes_feed ('<?xml encoding="utf-8"?>');
  $sub->parse_bytes_feed ('(' . $data->{entity}->{name} . ')');
  $sub->parse_bytes_end;
});

$parser->onparsed (sub {
  print "Parsing done\n";
});
print "Parsing...\n";
if (1) {
  $parser->parse_chars_start ($doc);
  $parser->parse_chars_feed (decode 'utf-8', $input);
  $parser->parse_chars_end;
} else {
  $parser->parse_char_string ((decode 'utf-8', $input) => $doc);
}
print "Method done\n";

use Data::Dumper;
warn Dumper +{xml_version => $doc->xml_version,
              xml_encoding => $doc->xml_encoding,
              xml_standalone => $doc->xml_standalone};
warn $doc->inner_html;
print dumptree $doc;
