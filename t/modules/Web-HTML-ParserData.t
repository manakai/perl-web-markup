use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Web::HTML::ParserData;

test {
  my $c = shift;
  ok Web::HTML::ParserData::HTML_NS;
  ok Web::HTML::ParserData::SVG_NS;
  ok Web::HTML::ParserData::MML_NS;
  ok Web::HTML::ParserData::XML_NS;
  ok Web::HTML::ParserData::XMLNS_NS;
  ok Web::HTML::ParserData::XLINK_NS;
  done $c;
} n => 6, name => 'nsurls';

test {
  my $c = shift;
  ok $Web::HTML::ParserData::AllVoidElements->{br};
  ok !$Web::HTML::ParserData::AllVoidElements->{canvas};
  ok $Web::HTML::ParserData::AllVoidElements->{embed};
  ok $Web::HTML::ParserData::AllVoidElements->{source};
  ok $Web::HTML::ParserData::AllVoidElements->{track};
  ok $Web::HTML::ParserData::AllVoidElements->{bgsound};
  ok $Web::HTML::ParserData::AllVoidElements->{frame};
  ok !$Web::HTML::ParserData::AllVoidElements->{command};
  ok !$Web::HTML::ParserData::AllVoidElements->{template};
  ok !$Web::HTML::ParserData::AllVoidElements->{image};
  ok !$Web::HTML::ParserData::AllVoidElements->{isindex};
  done $c;
} n => 11, name => 'void';

test {
  my $c = shift;
  ok $Web::HTML::ParserData::MathMLTextIntegrationPoints->{mi};
  ok $Web::HTML::ParserData::MathMLTextIntegrationPoints->{mo};
  ok $Web::HTML::ParserData::MathMLTextIntegrationPoints->{mn};
  ok $Web::HTML::ParserData::MathMLTextIntegrationPoints->{ms};
  ok $Web::HTML::ParserData::MathMLTextIntegrationPoints->{mtext};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPoints->{mglyph};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPoints->{math};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPoints->{title};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPoints->{'annotation-xml'};
  done $c;
} n => 9, name => 'mathml text int';

test {
  my $c = shift;
  ok $Web::HTML::ParserData::MathMLTextIntegrationPointMathMLElements->{mglyph};
  ok $Web::HTML::ParserData::MathMLTextIntegrationPointMathMLElements->{malignmark};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPointMathMLElements->{mi};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPointMathMLElements->{math};
  ok not $Web::HTML::ParserData::MathMLTextIntegrationPointMathMLElements->{desc};
  done $c;
} n => 5, name => 'mathml text int tag names';

test {
  my $c = shift;
  ok $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{title};
  ok $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{desc};
  ok $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{foreignObject};
  ok not $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{foreignobject};
  ok not $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{svg};
  ok not $Web::HTML::ParserData::SVGHTMLIntegrationPoints->{g};
  done $c;
} n => 6, name => 'svg int';

test {
  my $c = shift;
  ok not $Web::HTML::ParserData::MathMLHTMLIntegrationPoints->{mi};
  ok not $Web::HTML::ParserData::MathMLHTMLIntegrationPoints->{title};
  ok not $Web::HTML::ParserData::MathMLHTMLIntegrationPoints->{'annotation-xml'};
  done $c;
} n => 3, name => 'mathml int';

test {
  my $c = shift;
  ok not $Web::HTML::ParserData::ForeignContentBreakers->{svg};
  ok $Web::HTML::ParserData::ForeignContentBreakers->{p};
  ok $Web::HTML::ParserData::ForeignContentBreakers->{div};
  ok $Web::HTML::ParserData::ForeignContentBreakers->{h1};
  ok not $Web::HTML::ParserData::ForeignContentBreakers->{hgroup};
  ok not $Web::HTML::ParserData::ForeignContentBreakers->{g};
  ok not $Web::HTML::ParserData::ForeignContentBreakers->{script};
  ok not $Web::HTML::ParserData::ForeignContentBreakers->{font};
  done $c;
} n => 8, name => 'foreign breaker';

test {
  my $c = shift;
  is $Web::HTML::ParserData::MathMLAttrNameFixup->{definitionurl},
      'definitionURL';
  done $c;
} n => 1, name => 'mathml_attr';

test {
  my $c = shift;
  is $Web::HTML::ParserData::SVGAttrNameFixup->{glyphref},
      'glyphRef';
  done $c;
} n => 1, name => 'svg_attr';

test {
  my $c = shift;
  is_deeply $Web::HTML::ParserData::ForeignAttrNamespaceFixup->{'xml:lang'},
      ['http://www.w3.org/XML/1998/namespace', ['xml', 'lang']];
  done $c;
} n => 1, name => 'foreign_attr';

test {
  my $c = shift;
  is $Web::HTML::ParserData::SVGElementNameFixup->{foreignobject},
      'foreignObject';
  done $c;
} n => 1, name => 'svg_el';

test {
  my $c = shift;
  is $Web::HTML::ParserData::NamedCharRefs->{'amp;'}, '&';
  is $Web::HTML::ParserData::NamedCharRefs->{'AMP'}, '&';
  is $Web::HTML::ParserData::NamedCharRefs->{'acE;'}, "\x{223E}\x{333}";
  done $c;
} n => 3, name => 'charrefs';

test {
  my $c = shift;
  is $Web::HTML::ParserData::CharRefReplacements->{0x0000}, 0xFFFD;
  is $Web::HTML::ParserData::CharRefReplacements->{0x0001}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0x000A}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0x000D}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0x0080}, 0x20AC;
  is $Web::HTML::ParserData::CharRefReplacements->{0x0081}, 0x0081;
  is $Web::HTML::ParserData::CharRefReplacements->{0x009F}, 0x0178;
  is $Web::HTML::ParserData::CharRefReplacements->{0xD800}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0xFDD0}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0xFFFD}, undef;
  is $Web::HTML::ParserData::CharRefReplacements->{0xFFFF}, undef;
  done $c;
} n => 11, name => 'charref replacements';

test {
  my $c = shift;
  ok not $Web::HTML::ParserData::NoncharacterCodePoints->{0x0000};
  ok not $Web::HTML::ParserData::NoncharacterCodePoints->{0xD900};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0xFDD0};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0xFDE0};
  ok not $Web::HTML::ParserData::NoncharacterCodePoints->{0xFEFF};
  ok not $Web::HTML::ParserData::NoncharacterCodePoints->{0xFFFD};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0xFFFE};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0xFFFF};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0x1FFFF};
  ok $Web::HTML::ParserData::NoncharacterCodePoints->{0x10FFFF};
  ok not $Web::HTML::ParserData::NoncharacterCodePoints->{0x110000};
  done $c;
} n => 11, name => 'nonchar';

run_tests;

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
