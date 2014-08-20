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
for (qw(charrefs_pubids)) {
  $Data->{$_} = $XML->{$_};
}

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
