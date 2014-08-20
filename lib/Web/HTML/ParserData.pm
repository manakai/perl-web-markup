package Web::HTML::ParserData;
use strict;
use warnings;
our $VERSION = '5.0';
use Web::HTML::_SyntaxDefs;
use Web::HTML::_NamedEntityList;

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

our $MathMLTextIntegrationPoints = $Web::HTML::_SyntaxDefs->{is_mathml_text_integration_point};
our $MathMLTextIntegrationPointMathMLElements = $Web::HTML::_SyntaxDefs->{is_mathml_text_integration_point_mathml};
our $SVGHTMLIntegrationPoints = $Web::HTML::_SyntaxDefs->{is_svg_html_integration_point};
our $MathMLHTMLIntegrationPoints = $Web::HTML::_SyntaxDefs->{is_mathml_html_integration_point};
our $ForeignContentBreakers = $Web::HTML::_SyntaxDefs->{foreign_content_breakers};

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

our $NamedCharRefs = $Web::HTML::EntityChar;
our $InvalidCharRefs = $Web::HTML::_SyntaxDefs->{charref_invalid};
our $CharRefReplacements = $Web::HTML::_SyntaxDefs->{charref_replacements};
our $NoncharacterCodePoints = $Web::HTML::_SyntaxDefs->{nonchars};

## ------ DEPRECATED ------

# XXX Variables in this section will be removed.

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
our $QuirkyPublicIDs = {
  "-//W3O//DTD W3 HTML STRICT 3.0//EN//" => 1,
  "-/W3C/DTD HTML 4.0 TRANSITIONAL/EN" => 1,
  "HTML" => 1,
}; # $QuirkyPublicIDs

## ------ End of deprecated ------

1;

=head1 NAME

Web::HTML::ParserData - Data for HTML parser

=head1 DESCRIPTION

The C<Web::HTML::ParserData> module contains data for HTML and XML
parsers, extracted from the HTML Standard.

=head1 CONSTANTS

Following constants returning namespace URLs are defined (but not
exported): C<HTML_NS> (HTML namespace), C<SVG_NS> (SVG namespace),
C<MML_NS> (MathML namespace), C<XML_NS> (XML namespace), C<XMLNS_NS>
(XML Namespaces namespace), and C<XLINK_NS> (XLink namespace).

=head1 VARIABLES

There are following data from the HTML Standard:

=over 4

=item $AllVoidElements

A hash reference, whose keys are HTML void element names (conforming
or non-conforming) and values are true.  This list is equal to the
list of HTML elements whose "syntax_category" is "void" or "obsolete
void" in the JSON data file
<https://github.com/manakai/data-web-defs/blob/master/doc/elements.txt>.

=item $MathMLTextIntegrationPoints

The local names of the MathML text integration point elements
<http://www.whatwg.org/specs/web-apps/current-work/#mathml-text-integration-point>.
Keys are local names and values are true values.

=item $MathMLTextIntegrationPointMathMLElements

The tag names of the start tags that are interpreted as MathML
elements in MathML text integration point
<http://www.whatwg.org/specs/web-apps/current-work/#tree-construction>.
Keys are tag names (in lowercase) and values are true values.

=item $SVGHTMLIntegrationPoints

The local names of the HTML integration point SVG elements
<http://www.whatwg.org/specs/web-apps/current-work/#html-integration-point>.
Keys are local names and values are true values.

=item $MathMLHTMLIntegrationPoints

The local names of the HTML integration point MathML elements
<http://www.whatwg.org/specs/web-apps/current-work/#html-integration-point>.
Keys are local names and values are true values.

Note that the C<annotation-xml> element is B<NOT> in this list (but
sometimes it is an HTML integration point).

=item $ForeignContentBreakers

The tag names of the start tags that will close foreign elements if
they appear in foreign content parsing mode
<http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inforeign>.
Keys are tag names (in lowercase) and values are true values.

Note that the C<font> tag name is B<NOT> in this list (but it
sometimes closes foreign elements).

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

HTML named character references.

=item $CharRefReplacements

The code point replacement table for HTML character references, as
specified in HTML Standard
<http://www.whatwg.org/specs/web-apps/current-work/#tokenizing-character-references>.
Keys are original code points (as specified in character references),
represented as strings in shortest decimal form, and values are
corresponding replaced code points, represented as integers.

Note that surrogate code points are not included in this list (but
replaced by U+FFFD).  Note also that some code points are replaced by
the same code point.

=item $NoncharacterCodePoints

The Unicode noncharacter code points.  Keys are code points,
represented as strings in shortest decimal form, and values are some
true values.

=back

Note that variables not mentioned in this section should not be used.
They might be removed in later revision of this module.

=head1 SPECIFICATION

=over 4

=item HTML

HTML Standard <http://www.whatwg.org/specs/web-apps/current-work/>.

=back

=head1 SOURCES

data-web-defs <https://github.com/manakai/data-web-defs/>.

data-chars <https://github.com/manakai/data-chars/>.

=head1 LICENSE

You are granted a license to use, reproduce and create derivative
works of this file.

The JSON file contains data extracted from HTML Standard.  "Written by
Ian Hickson (Google, ian@hixie.ch) - Parts © Copyright 2004-2014 Apple
Inc., Mozilla Foundation, and Opera Software ASA; You are granted a
license to use, reproduce and create derivative works of this
document."

=cut
