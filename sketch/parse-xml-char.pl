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

my @input = map {
  s/\\x00/\x00/g;
  $_;
} @ARGV;
unless (@input) {
  local $/ = undef;
  push @input, scalar <>;
}

{
  my $di = @{$parser->di_data_set};
  $parser->di ($di);
  $parser->di_data_set->[$di] = {name => 'document entity'};
}

my $subs = [];
$parser->onextentref (sub {
  my ($self, $data, $sub) = @_;
  $sub->parse_bytes_start (undef, $self);

  $sub->di_data_set->[$sub->di] = {
    name => (defined $data->{entity}->{name} ? (($data->{entity}->{is_parameter_entity} ? '%' : '&') . $data->{entity}->{name} . ';') : 'external subset'),
    url => $data->{entity}->{system_identifier} // 'about:blank',
  };

  if (not defined $data->{entity}->{system_identifier}) {
    $sub->parse_bytes_feed ($data->{entity}->{name});
    $sub->parse_bytes_feed (' no system id');
    $sub->parse_bytes_end;
    return;
  }

  if ($data->{entity}->{system_identifier} =~ /^\#([0-9]+)$/) {
    my $id = $1;
    if (defined $input[$id]) {
      $sub->parse_bytes_feed ($input[$id]);
      $sub->parse_bytes_end;
      return;
    }
  }

  $sub->parse_bytes_feed ('<?xml encoding="utf-8"?>');
  if ($data->{entity}->{is_parameter_entity}) {
    $sub->parse_bytes_feed ('<!--');
  }
  $sub->parse_bytes_feed ('(' . ($data->{entity}->{name} // '#DOCTYPE') . ')');
  $sub->parse_bytes_feed ('&aa;') if ($data->{entity}->{name} // '') eq 'bb';
push @$subs, $sub;
});

$parser->strict_checker ('Web::XML::Parser::ForValidatorChecker');

$parser->onparsed (sub {
  print "Parsing done\n";
});
print "Parsing...\n";
if (1) {
  $parser->parse_chars_start ($doc);
  $parser->parse_chars_feed (decode 'utf-8', $input[0]);
  $parser->parse_chars_end;
} else {
  $parser->parse_char_string ((decode 'utf-8', $input[0]) => $doc);
}
print "Method done\n";
for (0..$#$subs) {
  $subs->[$_]->parse_bytes_feed ('('.$_.')-->');
  $subs->[$_]->parse_bytes_end;
}

use Data::Dumper;
warn Dumper +{xml_version => $doc->xml_version,
              xml_encoding => $doc->xml_encoding,
              xml_standalone => $doc->xml_standalone};
warn $doc->inner_html;
print dumptree $doc;
