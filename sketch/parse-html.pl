use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Web::DOM::Document;
use Web::HTML::Parser;
use Web::HTML::Dumper;

my $doc = new Web::DOM::Document;
my $parser = Web::HTML::Parser->new;
$parser->locale_tag (lc $ENV{LANG}) if $ENV{LANG};

local $/ = undef;
$parser->parse_byte_string (undef, scalar <> => $doc);

print dumptree $doc;
