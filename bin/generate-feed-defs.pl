use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use JSON::PS;
use Data::Dumper;

my $root_path = path (__FILE__)->parent->parent;
my $json_path = $root_path->child ('local/elements.json');
my $json = json_bytes2perl $json_path->slurp;

my $Data = {};

$Data->{significant} = $json->{categories}->{'feed significant content'}->{elements};

$Data::Dumper::Sortkeys = 1;
printf q{
$Web::Feed::_Defs = %s
1;
}, Dumper $Data;

## License: Public Domain.
