package test::Web::HTML::ParserData;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Web::HTML::ParserData;

sub _nsurls : Test(6) {
  ok Web::HTML::ParserData::HTML_NS;
  ok Web::HTML::ParserData::SVG_NS;
  ok Web::HTML::ParserData::MML_NS;
  ok Web::HTML::ParserData::XML_NS;
  ok Web::HTML::ParserData::XMLNS_NS;
  ok Web::HTML::ParserData::XLINK_NS;
} # _nsurls

sub _void : Test(5) {
  ok $Web::HTML::ParserData::AllVoidElements->{br};
  ok !$Web::HTML::ParserData::AllVoidElements->{canvas};
  ok $Web::HTML::ParserData::AllVoidElements->{embed};
  ok $Web::HTML::ParserData::AllVoidElements->{bgsound};
  ok !$Web::HTML::ParserData::AllVoidElements->{image};
} # _void

sub _mathml_attr : Test(1) {
  is $Web::HTML::ParserData::MathMLAttrNameFixup->{definitionurl},
      'definitionURL';
} # _mathml_attr

sub _svg_attr : Test(1) {
  is $Web::HTML::ParserData::SVGAttrNameFixup->{glyphref},
      'glyphRef';
} # _svg_attr

sub _foreign_attr : Test(1) {
  is_deeply $Web::HTML::ParserData::ForeignAttrNamespaceFixup->{'xml:lang'},
      ['http://www.w3.org/XML/1998/namespace', ['xml', 'lang']];
} # _foreign_attr

sub _svg_el : Test(1) {
  is $Web::HTML::ParserData::SVGElementNameFixup->{foreignobject},
      'foreignObject';
} # _svg_el

sub _charrefes : Test(3) {
  is $Web::HTML::ParserData::NamedCharRefs->{'amp;'}, '&';
  is $Web::HTML::ParserData::NamedCharRefs->{'AMP'}, '&';
  is $Web::HTML::ParserData::NamedCharRefs->{'acE;'}, "\x{223E}\x{333}";
} # _charrefs

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
