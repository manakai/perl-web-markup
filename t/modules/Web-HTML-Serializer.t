package test::Web::HTML::Serializer;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Web::HTML::Serializer;
use NanoDOM;

my $dom = NanoDOM::DOMImplementation->new;

sub create_doc_from_html ($) {
  my $doc = $dom->create_document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($_[0]);
  return $doc;
} # create_doc_from_html

sub create_el_from_html ($) {
  my $doc = create_doc_from_html q<<!DOCTYPE HTML><div></div>>;
  my $el = $doc->last_child->last_child->first_child;
  $el->inner_html ($_[0]);
  return ($doc, $el);
} # create_el_from_html

sub _document_inner_html : Test(4) {
  for (
    [q<<html><head></head><body><p>foo</p></body></html>>],
    [q<<!DOCTYPE html><html><head></head><body><p>foo</p></body></html>>],
    [q<<!DOCTYPE html><html><head></head><body></body></html>>],
    [q<<!DOCTYPE html><html><head></head><body x="y"></body></html>>],
  ) {
    my $doc = create_doc_from_html $_->[0];
    is ${Web::HTML::Serializer->get_inner_html ($doc)}, $_->[1] // $_->[0];
  }
} # _document_inner_html

sub _element_inner_html : Test(6) {
  for (
    [q<>],
    [q<xy z>],
    [q<<p>abc</p>>],
    [q<<p>abc</p><!---->>],
    [q<<img alt="b" src="x">>],
    [q<<spacer>abc</spacer>>],
  ) {
    my ($doc, $el) = create_el_from_html $_->[0];
    is ${Web::HTML::Serializer->get_inner_html ($el)}, $_->[1] // $_->[0];
  }
} # _element_inner_html

sub _element_name_html : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<aBc></aBc>>;
} # _element_name_html

sub _element_name_svg : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/svg', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<aBc></aBc>>;
} # _element_name_svg

sub _element_name_mathml : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://www.w3.org/1998/Math/MathML', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<aBc></aBc>>;
} # _element_name_mathml

sub _element_name_null : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns (undef, [undef, 'aBc']);
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<aBc></aBc>>;
} # _element_name_null

sub _element_name_null_prefixed : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns (undef, [undef, 'aBc']);
  $abc->prefix ('xyz');
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<xyz:aBc></xyz:aBc>>;
} # _element_name_null_prefixed

sub _element_name_external : Test(1) {
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://test/', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<xyz:aBc></xyz:aBc>>;
} # _element_name_external

sub _attr_name_null : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns (undef, [undef, 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p hOge="fuga"></p>>;
} # _attr_name_null

sub _attr_name_xml : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/XML/1998/namespace', [undef, 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p xml:hOge="fuga"></p>>;
} # _attr_name_xml

sub _attr_name_xmlns : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  $doc->strict_error_checking (0);
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p xmlns:hOge="fuga"></p>>;
} # _attr_name_xmlns

sub _attr_name_xmlns_xmlns : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'xmlns'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p xmlns="fuga"></p>>;
} # _attr_name_xmlns_xmlns

sub _attr_name_xlink : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/1999/xlink', [undef, 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p xlink:hOge="fuga"></p>>;
} # _attr_name_xlink

sub _attr_name_html : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  $doc->strict_error_checking (0);
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/1999/html', ['xmlns', 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p xmlns:hOge="fuga"></p>>;
} # _attr_name_html

sub _attr_name_unknown : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://test', [undef, 'hOge'] => 'fuga');
  is ${Web::HTML::Serializer->get_inner_html ($el)}, q<<p hOge="fuga"></p>>;
} # _attr_name_unknown

sub _plaintext : Test(35) {
  for my $tag_name (qw(style script xmp iframe noembed noframes plaintext)) {
    my ($doc, $el) = create_el_from_html
        ($tag_name eq 'plaintext' ? '<plaintext>' : '<' . $tag_name . '></' . $tag_name . '>');
    my $pt = $el->first_child;
    is ${Web::HTML::Serializer->get_inner_html ($pt)}, q<>;

    $pt->inner_html (q<abc>);
    is ${Web::HTML::Serializer->get_inner_html ($pt)}, q<abc>;
    
    $pt->append_child ($doc->create_text_node ('<p>xyz'));
    is ${Web::HTML::Serializer->get_inner_html ($pt)}, q<abc<p>xyz>;
    
    $pt->append_child ($doc->create_element_ns (undef, [undef, 'A']))->text_content ('bcd');
    is ${Web::HTML::Serializer->get_inner_html ($pt)}, q<abc<p>xyz<A>bcd</A>>;
    is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<$tag_name>abc<p>xyz<A>bcd</A></$tag_name>>;
  }
} # _plaintext

sub _noscript : Test(4) {
  my ($doc, $el) = create_el_from_html ('<noscript></noscript>');
  my $noscript = $el->first_child;
  $noscript->append_child ($doc->create_text_node ('avc&<">\'' . "\xA0"));
  $noscript->append_child ($doc->create_element_ns (undef, [undef, 'abC']))
      ->set_attribute_ns (undef, [undef, 'class'] => 'xYz');
  $noscript->append_child ($doc->create_text_node ('Q&A'));

  local $Web::ScriptingEnabled = 0;
  is ${Web::HTML::Serializer->get_inner_html ($noscript)}, qq<avc&amp;&lt;"&gt;'&nbsp;<abC class="xYz"></abC>Q&amp;A>,
      'noscript_scripting_disabled noscript inner';
  is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<noscript>avc&amp;&lt;"&gt;'&nbsp;<abC class="xYz"></abC>Q&amp;A</noscript>>,
      'noscript_scripting_disabled';

  local $Web::ScriptingEnabled = 1;
  is ${Web::HTML::Serializer->get_inner_html ($noscript)}, qq<avc&<">'\xA0<abC class="xYz"></abC>Q&A>,
      'noscript_scripting_enabled noscript inner';
  is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<noscript>avc&<">'\xA0<abC class="xYz"></abC>Q&A</noscript>>,
      'noscript_scripting_enabled';
} # _noscript

sub _xmp_descendant : Test(2) {
  my ($doc, $el) = create_el_from_html ('<xmp></xmp>');
  my $xmp = $el->first_child;
  $xmp->append_child ($doc->create_text_node ('abc<>&"' . "\xA0"));
  my $pre = $xmp->append_child ($doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, 'pre']));
  $pre->append_child ($doc->create_text_node ('abc<>&"' . "\xA0"));

  is ${Web::HTML::Serializer->get_inner_html ($xmp)}, qq<abc<>&"\xA0<pre>\x0Aabc&lt;&gt;&amp;"&nbsp;</pre>>;
  is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<xmp>abc<>&"\xA0<pre>\x0Aabc&lt;&gt;&amp;"&nbsp;</pre></xmp>>;
} # _xmp_descendant

sub _attr_value : Test(1) {
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns (undef, [undef, 'id'] => '<>&"' . qq<"']]> . '>' . "\xA0");
  
  is ${Web::HTML::Serializer->get_inner_html ($el)}, qq{<p id="<>&amp;&quot;&quot;']]>&nbsp;"></p>};
} # _attr_value

sub _void_elements : Test(95) {
  for my $tag_name (qw(
    area base basefont bgsound br col command embed frame hr img input
    keygen link meta param source track wbr
  )) {
    my ($doc, $el) = create_el_from_html ('<p>');
    my $p = $el->first_child;
    my $el1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
    $p->append_child ($el1);
    is ${Web::HTML::Serializer->get_inner_html ($p)}, qq{<$tag_name>};

    my $el2 = $doc->create_element_ns (undef, [undef, $tag_name]);
    $p->remove_child ($el1);
    $p->append_child ($el2);
    is ${Web::HTML::Serializer->get_inner_html ($p)}, qq{<$tag_name></$tag_name>};

    my $el3 = $doc->create_element_ns ('http://test/', [undef, $tag_name]);
    $p->remove_child ($el2);
    $p->append_child ($el3);
    is ${Web::HTML::Serializer->get_inner_html ($p)}, qq{<$tag_name></$tag_name>};

    my $el4 = $doc->create_element_ns ('http://www.w3.org/2000/svg', [undef, $tag_name]);
    $p->remove_child ($el3);
    $p->append_child ($el4);
    is ${Web::HTML::Serializer->get_inner_html ($p)}, qq{<$tag_name></$tag_name>};

    my $el5 = $doc->create_element_ns ('http://www.w3.org/1998/Math/MathML', [undef, $tag_name]);
    $p->remove_child ($el4);
    $p->append_child ($el5);
    is ${Web::HTML::Serializer->get_inner_html ($p)}, qq{<$tag_name></$tag_name>};
  }
} # _void_elements

sub _start_tag_trailing_newlines : Test(15) {
  for my $tag_name (qw(textarea pre listing)) {
    {
      my ($doc, $el) = create_el_from_html ('');
      my $child = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
      $child->text_content ("\x0Aabc\x0A");
      $el->append_child ($child);
      is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<$tag_name>\x0A\x0Aabc\x0A</$tag_name>>;
    }

    for my $nsurl (undef, q<http://test/>, q<http://www.w3.org/2000/svg>) {
      my ($doc, $el) = create_el_from_html ('');
      my $child = $doc->create_element_ns ($nsurl, [undef, $tag_name]);
      $child->text_content ("\x0Aabc\x0A");
      $el->append_child ($child);
      is ${Web::HTML::Serializer->get_inner_html ($el)}, qq<<$tag_name>\x0Aabc\x0A</$tag_name>>;
    }

    {
      my ($doc, $el) = create_el_from_html ('');
      my $child = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
      $child->text_content ("\x0Aabc\x0A");
      is ${Web::HTML::Serializer->get_inner_html ($child)}, qq<\x0Aabc\x0A>;
    }
  }
} # _start_tag_trailing_newlines

sub _doc : Test(1) {
  my $doc = create_doc_from_html ('<!DOCTYPE html><p>');
  is ${Web::HTML::Serializer->get_inner_html ($doc)}, q<<!DOCTYPE html><html><head></head><body><p></p></body></html>>;
} # _doc

sub _df : Test(1) {
  my $doc = create_doc_from_html ('<!DOCTYPE html>');
  my $df = $doc->create_document_fragment;
  $df->append_child ($doc->create_element_ns (undef, [undef, 'p']))->text_content ('a&b');
  $df->manakai_append_text ('ab<>cd');
  is ${Web::HTML::Serializer->get_inner_html ($df)},
    q<<p>a&amp;b</p>ab&lt;&gt;cd>;
} # _df

sub _svg : Test(1) {
  my $doc = create_doc_from_html ('<!DOCTYPE HTML>');
  my $div = $doc->create_element_ns (undef, [undef, 'div']);
  my $svg = $doc->create_element_ns (q<http://www.w3.org/2000/svg>, ['svg', 'svg']);
  $div->append_child ($svg);
  
  is ${Web::HTML::Serializer->get_inner_html ($div)}, q<<svg></svg>>;
} # _svg

sub _nanodom : Test(1) {
  my $doc = NanoDOM::Document->new;
  my $div = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'div']);
  my $el = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'p']);
  $div->append_child ($el);
  $el->text_content ("a b \x{1000}\x{2000}<!&\"'>\xA0");
  $el->set_attribute_ns (undef, [undef, 'title'], '<!&"\'>' . "\xA0");
  $el->append_child ($doc->create_comment ('A -- B'));
  $el->append_child ($doc->create_processing_instruction ('xml', 'version="1.0?>"'));
  $doc->append_child ($div);
  my $html = Web::HTML::Serializer->get_inner_html ($doc);
  eq_or_diff $$html, qq{<div><p title="<!&amp;&quot;'>&nbsp;">a b \x{1000}\x{2000}&lt;!&amp;"'&gt;&nbsp;<!--A -- B--><?xml version="1.0?>"></p></div>};
}

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2009-2013 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
