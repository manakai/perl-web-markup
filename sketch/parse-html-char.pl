use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Web::DOM::Document;
use Web::HTML::Parser;
use Web::HTML::Dumper;
use Encode;

my $doc = new Web::DOM::Document;
my $parser = Web::HTML::Parser->new;
$parser->locale_tag (lc $ENV{LANG}) if $ENV{LANG};

my $input = shift;
$input =~ s/\\x00/\x00/g;

$parser->parse_char_string ((decode 'utf-8', $input) => $doc);

print dumptree $doc;
