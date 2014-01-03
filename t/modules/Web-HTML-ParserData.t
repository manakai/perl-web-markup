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

run_tests;

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
