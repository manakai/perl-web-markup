package Web::HTML::ParserData;
use strict;
use warnings;
our $VERSION = '3.0';
use Web::HTML::_SyntaxDefs;

## ------ Namespace URLs ------

sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub MML_NS () { q<http://www.w3.org/1998/Math/MathML> }
sub SVG_NS () { q<http://www.w3.org/2000/svg> }
sub XLINK_NS () { q<http://www.w3.org/1999/xlink> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub XMLNS_NS () { q<http://www.w3.org/2000/xmlns/> }

## ------ Element categories ------

our $AllVoidElements = $Web::HTML::_SyntaxDefs->{void}->{+HTML_NS};

## ------ Foreign element integration points ------

## MathML text integration point
## <http://www.whatwg.org/specs/web-apps/current-work/#mathml-text-integration-point>.
our $MathMLTextIntegrationPoints = {
  mi => 1,
  mo => 1,
  mn => 1,
  ms => 1,
  mtext => 1,
};

## <http://www.whatwg.org/specs/web-apps/current-work/#tree-construction>.
our $MathMLTextIntegrationPointMathMLElements = {
  mglyph => 1,
  malignmark => 1,
};

## HTML integration point (SVG elements)
## <http://www.whatwg.org/specs/web-apps/current-work/#html-integration-point>.
our $SVGHTMLIntegrationPoints = {
  foreignObject => 1,
  desc => 1,
  title => 1,
};

## HTML integration point (MathML elements)
## <http://www.whatwg.org/specs/web-apps/current-work/#html-integration-point>.
our $MathMLHTMLIntegrationPoints = {
  #'annotation-xml' with encoding (ASCII case-insensitive) text/html
  #or application/xhtml+xml
};

## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inforeign>.
our $ForeignContentBreakers = {
  b => 1, big => 1, blockquote => 1, body => 1, br => 1, center => 1,
  code => 1, dd => 1, div => 1, dl => 1, dt => 1, em => 1, embed => 1,
  h1 => 1, h2 => 1, h3 => 1, h4 => 1, h5 => 1, h6 => 1, head => 1,
  hr => 1, i => 1, img => 1, li => 1, listing => 1, menu => 1, meta => 1,
  nobr => 1, ol => 1, p => 1, pre => 1, ruby => 1, s => 1, small => 1,
  span => 1, strong => 1, strike => 1, sub => 1, sup => 1, table => 1,
  tt => 1, u => 1, ul => 1, var => 1,
  # font with "color"/"face"/"size"
};

## ------ Attribute name mappings ------

our $MathMLAttrNameFixup = $Web::HTML::_SyntaxDefs->{adjusted_mathml_attr_names};
our $SVGAttrNameFixup = $Web::HTML::_SyntaxDefs->{adjusted_svg_attr_names};
our $ForeignAttrNamespaceFixup = $Web::HTML::_SyntaxDefs->{adjusted_ns_attr_names};
our $SVGElementNameFixup = $Web::HTML::_SyntaxDefs->{adjusted_svg_element_names};

our $ForeignAttrNameToArgs = {};
for (keys %$ForeignAttrNamespaceFixup) {
  $ForeignAttrNameToArgs->{(SVG_NS)}->{$_} = $ForeignAttrNamespaceFixup->{$_};
  $ForeignAttrNameToArgs->{(MML_NS)}->{$_} = $ForeignAttrNamespaceFixup->{$_};
}
for (keys %$SVGAttrNameFixup) {
  $ForeignAttrNameToArgs->{(SVG_NS)}->{$_} = [undef, [undef, $SVGAttrNameFixup->{$_}]];
}
for (keys %$MathMLAttrNameFixup) {
  $ForeignAttrNameToArgs->{(MML_NS)}->{$_} = [undef, [undef, $MathMLAttrNameFixup->{$_}]];
}

## ------ Character references ------

require Web::HTML::_NamedEntityList;
our $NamedCharRefs = $Web::HTML::EntityChar;

## <http://www.whatwg.org/specs/web-apps/current-work/#tokenizing-character-references>.
our $CharRefReplacements = {
  0x00 => 0xFFFD,
  0x0D => 0x000D,
  0x80 => 0x20AC,
  0x81 => 0x0081,
  0x82 => 0x201A,
  0x83 => 0x0192,
  0x84 => 0x201E,
  0x85 => 0x2026,
  0x86 => 0x2020,
  0x87 => 0x2021,
  0x88 => 0x02C6,
  0x89 => 0x2030,
  0x8A => 0x0160,
  0x8B => 0x2039,
  0x8C => 0x0152,
  0x8D => 0x008D,
  0x8E => 0x017D,
  0x8F => 0x008F,
  0x90 => 0x0090,
  0x91 => 0x2018,
  0x92 => 0x2019,
  0x93 => 0x201C,
  0x94 => 0x201D,
  0x95 => 0x2022,
  0x96 => 0x2013,
  0x97 => 0x2014,
  0x98 => 0x02DC,
  0x99 => 0x2122,
  0x9A => 0x0161,
  0x9B => 0x203A,
  0x9C => 0x0153,
  0x9D => 0x009D,
  0x9E => 0x017E,
  0x9F => 0x0178,
  #map { $_ => 0xFFFD } 0xD800..0xDFFF,
}; # $CharRefReplacements

our $NoncharacterCodePoints = {
  map { $_ => 1 }
    0xFDD0..0xFDEF,
    0xFFFE, 0xFFFF, 0x1FFFE, 0x1FFFF, 0x2FFFE, 0x2FFFF, 0x3FFFE, 0x3FFFF,
    0x4FFFE, 0x4FFFF, 0x5FFFE, 0x5FFFF, 0x6FFFE, 0x6FFFF, 0x7FFFE,
    0x7FFFF, 0x8FFFE, 0x8FFFF, 0x9FFFE, 0x9FFFF, 0xAFFFE, 0xAFFFF,
    0xBFFFE, 0xBFFFF, 0xCFFFE, 0xCFFFF, 0xDFFFE, 0xDFFFF, 0xEFFFE,
    0xEFFFF, 0xFFFFE, 0xFFFFF, 0x10FFFE, 0x10FFFF,
}; # $NoncharacterCodePoints

## ------ DOCTYPEs ------

## Obsolete permitted DOCTYPE strings
## <http://www.whatwg.org/specs/web-apps/current-work/#obsolete-permitted-doctype-string>,
## <http://www.whatwg.org/specs/web-apps/current-work/#the-initial-insertion-mode>.

## Case-sensitive
our $ObsoletePermittedDoctypes = {
  '-//W3C//DTD HTML 4.0//EN'
      => 'http://www.w3.org/TR/REC-html40/strict.dtd', # or missing
  '-//W3C//DTD HTML 4.01//EN'
      => 'http://www.w3.org/TR/html4/strict.dtd', # or missing
  '-//W3C//DTD XHTML 1.0 Strict//EN'
      => 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd', # required
  '-//W3C//DTD XHTML 1.1//EN'
      => 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd', # required
};

## ASCII case-insensitive
our $QuirkyPublicIDPrefixes = [
  "+//SILMARIL//DTD HTML PRO V0R11 19970101//",
  "-//ADVASOFT LTD//DTD HTML 3.0 ASWEDIT + EXTENSIONS//",
  "-//AS//DTD HTML 3.0 ASWEDIT + EXTENSIONS//",
  "-//IETF//DTD HTML 2.0 LEVEL 1//",
  "-//IETF//DTD HTML 2.0 LEVEL 2//",
  "-//IETF//DTD HTML 2.0 STRICT LEVEL 1//",
  "-//IETF//DTD HTML 2.0 STRICT LEVEL 2//",
  "-//IETF//DTD HTML 2.0 STRICT//",
  "-//IETF//DTD HTML 2.0//",
  "-//IETF//DTD HTML 2.1E//",
  "-//IETF//DTD HTML 3.0//",
  "-//IETF//DTD HTML 3.2 FINAL//",
  "-//IETF//DTD HTML 3.2//",
  "-//IETF//DTD HTML 3//",
  "-//IETF//DTD HTML LEVEL 0//",
  "-//IETF//DTD HTML LEVEL 1//",
  "-//IETF//DTD HTML LEVEL 2//",
  "-//IETF//DTD HTML LEVEL 3//",
  "-//IETF//DTD HTML STRICT LEVEL 0//",
  "-//IETF//DTD HTML STRICT LEVEL 1//",
  "-//IETF//DTD HTML STRICT LEVEL 2//",
  "-//IETF//DTD HTML STRICT LEVEL 3//",
  "-//IETF//DTD HTML STRICT//",
  "-//IETF//DTD HTML//",
  "-//METRIUS//DTD METRIUS PRESENTATIONAL//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 2.0 HTML STRICT//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 2.0 HTML//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 2.0 TABLES//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 3.0 HTML STRICT//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 3.0 HTML//",
  "-//MICROSOFT//DTD INTERNET EXPLORER 3.0 TABLES//",
  "-//NETSCAPE COMM. CORP.//DTD HTML//",
  "-//NETSCAPE COMM. CORP.//DTD STRICT HTML//",
  "-//O'REILLY AND ASSOCIATES//DTD HTML 2.0//",
  "-//O'REILLY AND ASSOCIATES//DTD HTML EXTENDED 1.0//",
  "-//O'REILLY AND ASSOCIATES//DTD HTML EXTENDED RELAXED 1.0//",
  "-//SOFTQUAD SOFTWARE//DTD HOTMETAL PRO 6.0::19990601::EXTENSIONS TO HTML 4.0//",
  "-//SOFTQUAD//DTD HOTMETAL PRO 4.0::19971010::EXTENSIONS TO HTML 4.0//",
  "-//SPYGLASS//DTD HTML 2.0 EXTENDED//",
  "-//SQ//DTD HTML 2.0 HOTMETAL + EXTENSIONS//",
  "-//SUN MICROSYSTEMS CORP.//DTD HOTJAVA HTML//",
  "-//SUN MICROSYSTEMS CORP.//DTD HOTJAVA STRICT HTML//",
  "-//W3C//DTD HTML 3 1995-03-24//",
  "-//W3C//DTD HTML 3.2 DRAFT//",
  "-//W3C//DTD HTML 3.2 FINAL//",
  "-//W3C//DTD HTML 3.2//",
  "-//W3C//DTD HTML 3.2S DRAFT//",
  "-//W3C//DTD HTML 4.0 FRAMESET//",
  "-//W3C//DTD HTML 4.0 TRANSITIONAL//",
  "-//W3C//DTD HTML EXPERIMETNAL 19960712//",
  "-//W3C//DTD HTML EXPERIMENTAL 970421//",
  "-//W3C//DTD W3 HTML//",
  "-//W3O//DTD W3 HTML 3.0//",
  "-//WEBTECHS//DTD MOZILLA HTML 2.0//",
  "-//WEBTECHS//DTD MOZILLA HTML//",
]; # $QuirkyPublicIDPrefixes

## ASCII case-insensitive
our $QuirkyPublicIDs = {
  "-//W3O//DTD W3 HTML STRICT 3.0//EN//" => 1,
  "-/W3C/DTD HTML 4.0 TRANSITIONAL/EN" => 1,
  "HTML" => 1,
}; # $QuirkyPublicIDs

## ASCII case-insensitive
## Quirks or limited quirks, depending on existence of system id
## -//W3C//DTD HTML 4.01 FRAMESET// (prefix)
## -//W3C//DTD HTML 4.01 TRANSITIONAL// (prefix)

## ASCII case-insensitive
## Limited quirks
## -//W3C//DTD XHTML 1.0 FRAMESET// (prefix)
## -//W3C//DTD XHTML 1.0 TRANSITIONAL// (prefix)

## ASCII case-insensitive
## Quirks system id
## http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd

1;

=head1 NAME

Web::HTML::ParserData - Data for HTML parser

=head1 DESCRIPTION

The C<Web::HTML::ParserData> module contains data for HTML parser,
extracted from the HTML Living Standard.

=head1 CONSTANTS

Following constants for namespace URLs are defined (but not exported):
C<HTML_NS> (HTML namespace), C<SVG_NS> (SVG namespace), C<MML_NS>
(MathML namespace), C<XML_NS> (XML namespace), C<XMLNS_NS> (XML
Namespace namespace), and C<XLINK_NS> (XLink namespace).

=head1 VARIABLES

Following data from the HTML specification are included:

=over 4

=item $AllVoidElements

A hash reference, whose keys are HTML void element names (conforming
or non-conforming) and values are true.  This list is equal to the
list of HTML elements whose "syntax_category" is "void" or "obsolete
void" in the JSON data file
<https://github.com/manakai/data-web-defs/blob/master/doc/elements.txt>.

=item $MathMLTextIntegrationPoints

=item $MathMLHTMLIntegrationPoints

=item $SVGHTMLIntegrationPoints

=item $ForeignContentBreakers

=item $MathMLAttrNameFixup

Table in adjust MathML attributes
<http://www.whatwg.org/specs/web-apps/current-work/#adjust-mathml-attributes>.

=item $SVGAttrNameFixup

Table in adjust SVG attributes
<http://www.whatwg.org/specs/web-apps/current-work/#adjust-svg-attributes>.

=item $ForeignAttrNamespaceFixup

Table in adjust foreign attributes
<http://www.whatwg.org/specs/web-apps/current-work/#adjust-foreign-attributes>.

=item $SVGElementNameFixup

Table in the rules for parsing tokens in foreign content, any other
start tag, an element in the SVG namespace
<http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inforeign>.

=item $NamedCharRefs

=item $CharRefReplacements

=item $NoncharacterCodePoints

=item $ObsoletePermittedDoctypes

=item $QuirkyPublicIDPrefixes

=item $QuirkyPublicIDs

=back

=head1 SEE ALSO

HTML Living Standard
<http://www.whatwg.org/specs/web-apps/current-work/>.

data-web-defs <https://github.com/manakai/data-web-defs/>.

=head1 LICENSE

Copyright 2004-2011 Apple Computer, Inc., Mozilla Foundation, and
Opera Software ASA.

You are granted a license to use, reproduce and create derivative
works of this document.

=cut
