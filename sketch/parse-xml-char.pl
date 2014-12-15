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

print "Parsing...\n";
$parser->parse_char_string ((decode 'utf-8', $input) => $doc);
print "Done\n";

use Data::Dumper;
warn Dumper +{xml_version => $doc->xml_version,
              xml_encoding => $doc->xml_encoding,
              xml_standalone => $doc->xml_standalone};
warn $doc->inner_html;
print dumptree $doc;
