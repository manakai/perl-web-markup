use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use Data::Dumper;

my $local_path = path (__FILE__)->parent->parent->child ('local');

sub json ($) { json_bytes2perl $local_path->child (shift)->slurp }

my $DOM = json 'elements.json';
my $PROMPT = json 'isindex-prompt.json';
my $HTML = json 'html-syntax.json';
my $XML = json 'xml-syntax.json';
my $MAPS = json 'maps.json';
my $SETS = json 'sets.json';

my $Data = {};

for my $ns (keys %{$DOM->{elements}}) {
  for my $ln (keys %{$DOM->{elements}->{$ns}}) {
    my $category = $DOM->{elements}->{$ns}->{$ln}->{syntax_category} // '';
    if ($category eq "void" or $category eq "obsolete void") {
      $Data->{void}->{$ns}->{$ln} = 1;
    }
  }
}

for my $locale (keys %{$PROMPT}) {
  my $text = $PROMPT->{$locale}->{chromium} ||
      $PROMPT->{$locale}->{gecko} or next;
  $text .= " " if $text =~ /:$/;
  $Data->{prompt}->{$locale} = $text;
}

for (qw(adjusted_mathml_attr_names adjusted_ns_attr_names),
     qw(adjusted_svg_attr_names adjusted_svg_element_names)) {
  $Data->{$_} = $HTML->{$_};
}

if ($HTML->{tree_patterns}->{'HTML integration point'}->[0] eq 'or') {
  my @item = @{$HTML->{tree_patterns}->{'HTML integration point'}};
  shift @item;
  for (@item) {
    if ($_->{ns} eq 'SVG' and not defined $_->{attrs}) {
      $Data->{is_svg_html_integration_point}->{$_->{name}} = 1;
    } elsif ($_->{ns} eq 'MathML' and not defined $_->{attrs}) {
      $Data->{is_mathml_html_integration_point}->{$_->{name}} = 1;
    }
  }
}
if ($HTML->{tree_patterns}->{'MathML text integration point'}->[0] eq 'or') {
  my @item = @{$HTML->{tree_patterns}->{'MathML text integration point'}};
  shift @item;
  for (@item) {
    if ($_->{ns} eq 'MathML' and not defined $_->{attrs}) {
      $Data->{is_mathml_text_integration_point}->{$_->{name}} = 1;
    }
  }
}
if ($HTML->{dispatcher_html}->[0] eq 'or') {
  my @item = @{$HTML->{dispatcher_html}};
  shift @item;
  for (@item) {
    if ($_->[0] eq 'and' and
        $_->[1]->[0] eq 'adjusted current node' and
        $_->[1]->[1] eq 'is' and
        $_->[1]->[2]->{'MathML text integration point'} and
        $_->[2]->[0] eq 'and' and
        $_->[2]->[1]->[0] eq 'token' and
        $_->[2]->[1]->[1] eq 'is a' and
        $_->[2]->[1]->[2] eq 'START' and
        $_->[2]->[2]->[0] eq 'token tag_name' and
        $_->[2]->[2]->[1] eq 'is not') {
      $Data->{is_mathml_text_integration_point_mathml}->{$_} = 1
          for @{$_->[2]->[2]->[2]};
    }
  }
}
{
  my @cond = sort { (length $b) <=> (length $a) } grep { /^START:/ } keys %{$HTML->{ims}->{'in foreign content'}->{conds}};
  if (@cond) {
    my $acts = $HTML->{ims}->{'in foreign content'}->{conds}->{$cond[0]}->{actions};
    if (@$acts and $acts->[0]->{type} eq 'parse error') {
      my $cond = $cond[0];
      $cond =~ s/^START://;
      for (split /[ ,]/, $cond) {
        $Data->{foreign_content_breakers}->{$_} = 1;
      }
    }
  }
}

for (qw(charrefs_pubids)) {
  $Data->{$_} = $XML->{$_};
}

for (keys %{$MAPS->{maps}->{'html:charref'}->{char_to_char}}) {
  my $from = hex $_;
  my $to = hex $MAPS->{maps}->{'html:charref'}->{char_to_char}->{$_};
  $Data->{charref_replacements}->{$from} = $to
      if $from < 0x100;
}
for (0x80..0x9F) {
  $Data->{charref_replacements}->{$_} ||= $_;
}

sub expand_range ($) {
  my $range = shift;
  my $list = {};
  $range =~ s/^\[//;
  $range =~ s/\]$//;
  while (length $range) {
    my $from;
    if ($range =~ s/^\\u\{([0-9A-F]+)\}//) {
      $from = hex $1;
    } elsif ($range =~ s/^\\u([0-9A-F]{4})//) {
      $from = hex $1;
    } else {
      $range =~ s/^(.)//s;
      $from = ord $1;
    }
    if ($range =~ s/^-//) {
      my $to;
      if ($range =~ s/^\\u\{([0-9A-F]+)\}//) {
        $to = hex $1;
      } elsif ($range =~ s/^\\u([0-9A-F]{4})//) {
        $to = hex $1;
      } else {
        $range =~ s/^(.)//s;
        $to = ord $1;
      }
      $list->{$_} = 1 for $from..$to;
    } else {
      $list->{$from} = 1;
    }
  }
  return $list;
} # expand_range

$Data->{nonchars} = expand_range $SETS->{sets}->{'$unicode:Noncharacter_Code_Point'}->{chars};

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Useqq = 1;
my $pm = Dumper $Data;
$pm =~ s/VAR1/Web::HTML::_SyntaxDefs/;
print "$pm\n";
print "1;\n";

my $footer = q{
=head1 LICENSE

This file contains data from the data-web-defs repository
<https://github.com/manakai/data-web-defs/>.

This file contains texts from Gecko and Chromium source codes.
See following documents for full license terms of them:

Gecko:

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

Chromium:

  See following documents:
  <http://src.chromium.org/viewvc/chrome/trunk/src/webkit/LICENSE>
  <http://src.chromium.org/viewvc/chrome/trunk/src/webkit/glue/resources/README.txt>

=cut
};
print $footer;
