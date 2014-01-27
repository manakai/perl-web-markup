use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Encode;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::HTML::Dumper;

my $doc = new Web::DOM::Document;
my $parser = Web::XML::Parser->new;
$parser->locale_tag (lc $ENV{LANG}) if $ENV{LANG};

local $/ = undef;
$parser->parse_char_string ((decode 'utf-8', scalar <>) => $doc);

print dumptree $doc;
