use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Web::Encoding;
use Web::DOM::Document;
use Web::HTML::Parser;
use Web::HTML::Validator;
use Web::HTML::SourceMap;

my $dids = [];

my $onerror = sub {
  my %args = @_;
  my $line;
  my $column;
  if (defined $args{di} and defined $args{index}) {
    my ($di, $index) = resolve_index_pair $dids, $args{di}, $args{index};
    ($line, $column) = index_pair_to_lc_pair $dids, $di, $index;
  }
  if (not defined $column and defined $args{node}) {
    my $location = $args{node}->manakai_get_source_location;
    if ($location->[1] >= 0) {
      my ($di, $index) = resolve_index_pair $dids, $location->[1], $location->[2];
      ($line, $column) = index_pair_to_lc_pair $dids, $di, $index;
    }
  }
  warn sprintf "%s: %s%s at %s\n",
      {
        m => 'Error',
        s => 'Recommendation',
        w => 'Warning',
        i => 'Information',
      }->{$args{level}} // $args{level},
      $args{type},
      (defined $args{text} ? ' ('.$args{text}.')' : ''),
      (join ', ',
           grep { length }
           ($args{node} ? 'node ' . $args{node}->node_name : ''),
           (defined $args{di} ? 'document #' . $args{di} : ''),
           (defined $args{index} ? 'index ' . $args{index} : ''),
           (defined $line ? 'line ' . $line : ''),
           (defined $column ? 'column ' . $column : ''),
           (defined $args{value} ? '"'.$args{value}.'"' : ''));
}; # $onerror

my $doc = new Web::DOM::Document;
my $parser = Web::HTML::Parser->new;
$parser->scripting (1);
$parser->di_data_set ($dids);
$parser->locale_tag (lc $ENV{LANG}) if $ENV{LANG};
$parser->onerror ($onerror);

local $/ = undef;
my $input = @ARGV ? $ARGV[0] : scalar <>;
$input = decode_web_utf8 $input;
$dids->[@$dids]->{lc_map} = create_index_lc_mapping $input;
$parser->di ($#$dids);
$parser->parse_byte_string (undef, $input => $doc);

my $checker = new Web::HTML::Validator;
$checker->onerror ($onerror);
$checker->di_data_set ($dids);
$checker->scripting ($parser->scripting);
$checker->check_node ($doc);
