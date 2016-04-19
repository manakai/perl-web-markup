use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::XML::Serializer;
use Web::DOM::Document;

sub create_doc_from_html ($) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html ($_[0]);
  $doc->manakai_is_html (0);
  return $doc;
} # create_doc_from_html

sub create_el_from_html ($) {
  my $doc = create_doc_from_html q<<!DOCTYPE HTML><div></div>>;
  $doc->manakai_is_html (1);
  my $el = $doc->last_child->last_child->first_child;
  $el->inner_html ($_[0]);
  $doc->manakai_is_html (0);
  return ($doc, $el);
} # create_el_from_html

for my $test (
  [q<<html><head></head><body><p>foo</p></body></html>> =>
   q<<html xmlns="http://www.w3.org/1999/xhtml"><head></head><body><p>foo</p></body></html>>],
  [q<<!DOCTYPE html><html><head></head><body><p>foo</p></body></html>> =>
   q<<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml"><head></head><body><p>foo</p></body></html>>],
  [q<<!DOCTYPE html><html><head></head><body></body></html>> =>
   q<<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml"><head></head><body></body></html>>],
  [q<<!DOCTYPE html><html><head></head><body x="y"></body></html>> =>
   q<<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml"><head></head><body x="y"></body></html>>],
) {
  test {
    my $c = shift;
    my $doc = create_doc_from_html $test->[0];
    is ${Web::XML::Serializer->new->get_inner_html ($doc)}, $test->[1] || $test->[0];
    done $c;
  } n => 1, name => 'document_inner_html';
}

for my $test (
  [q<>],
  [q<xy z>],
  [q<<p>abc</p>> => q<<p xmlns="http://www.w3.org/1999/xhtml">abc</p>>],
  [q<<p>abc</p><div>hoge</div>> =>
   q<<p xmlns="http://www.w3.org/1999/xhtml">abc</p><div xmlns="http://www.w3.org/1999/xhtml">hoge</div>>],
  [q<<p>abc</p><!---->> => q<<p xmlns="http://www.w3.org/1999/xhtml">abc</p><!---->>],
  [q<<img alt="b" src="x">>, q<<img xmlns="http://www.w3.org/1999/xhtml" alt="b" src="x"></img>>],
  [q<<spacer>abc</spacer>> => q<<spacer xmlns="http://www.w3.org/1999/xhtml">abc</spacer>>],
) {
  test {
    my $c = shift;
    my ($doc, $el) = create_el_from_html $test->[0];
    is ${Web::XML::Serializer->new->get_inner_html ($el)}, $test->[1] || $test->[0];
    done $c;
  } n => 1, name => 'element_inner_html';
}

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns
      ('http://www.w3.org/1999/xhtml', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xyz:aBc xmlns:xyz="http://www.w3.org/1999/xhtml"></xyz:aBc>>;
  done $c;
} n => 1, name => 'element_name_html';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/svg', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xyz:aBc xmlns:xyz="http://www.w3.org/2000/svg"></xyz:aBc>>;
  done $c;
} n => 1, name => 'element_name_svg';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns
      ('http://www.w3.org/1998/Math/MathML', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xyz:aBc xmlns:xyz="http://www.w3.org/1998/Math/MathML"></xyz:aBc>>;
  done $c;
} n => 1, name => 'element_name_mathml';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns (undef, [undef, 'aBc']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<aBc xmlns=""></aBc>>;
  done $c;
} n => 1, name => 'element_name_null';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns (undef, [undef, 'aBc']);
  $abc->prefix ('xyz');
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<aBc xmlns=""></aBc>>;
  done $c;
} n => 1, name => 'element_name_null_prefixed';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://test/', ['xyz', 'aBc']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xyz:aBc xmlns:xyz="http://test/"></xyz:aBc>>;
  done $c;
} n => 1, name => 'element_name_external';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/xmlns/', ['xyz', 'xmlns']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xmlns></xmlns>>;
  done $c;
} n => 1, name => 'element_xmlns';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/xmlns/', ['xml', 'XMLNS']);
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xmlns:XMLNS></xmlns:XMLNS>>;
  done $c;
} n => 1, name => 'element_xmlns_2';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/xmlns/', ['xml', 'XMLNS']);
  $abc->set_attribute_ns ($abc->namespace_uri, ['xmlns', 'xmlns'] => 'foo');
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xmlns:XMLNS xmlns="foo"></xmlns:XMLNS>>;
  done $c;
} n => 1, name => 'element_xmlns_3';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns ('http://www.w3.org/2000/xmlns/', ['xmlns', 'xml']);
  $abc->set_attribute_ns ($abc->namespace_uri, ['xmlns', 'xml'] => 'foo');
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<xmlns:xml xmlns:xml="foo"></xmlns:xml>>;
  done $c;
} n => 1, name => 'element_xmlns_4';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  $doc->strict_error_checking (0);
  my $abc = $doc->create_element_ns ('http://hoge/', ['xmlns', 'xml']);
  $abc->set_attribute_ns
      ('http://www.w3.org/2000/xmlns/', ['xmlns', 'xml'] => 'http://hoge/');
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<a0:xml xmlns:a0="http://hoge/" xmlns:xml="http://hoge/"></a0:xml>>;
  done $c;
} n => 1, name => 'element_xmlns_5';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $abc = $doc->create_element_ns ('http://hoge/', ['abv', 'xml']);
  $abc->set_attribute_ns
      ('http://www.w3.org/2000/xmlns/', ['xmlns', 'xml'] => 'http://hoge/');
  $el->append_child ($abc);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<abv:xml xmlns:abv="http://hoge/" xmlns:xml="http://hoge/"></abv:xml>>;
  done $c;
} n => 1, name => 'element_xmlns_6';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $ab1 = $doc->create_element_ns ('http://hoge1/', [undef, 'bb']);
  my $ab2 = $doc->create_element_ns ('http://hoge2/', [undef, 'bb']);
  my $ab3 = $doc->create_element_ns (undef, [undef, 'bb']);
  my $ab4 = $doc->create_element_ns ('http://hoge4/', [undef, 'bb']);
  $el->append_child ($ab1);
  $ab1->append_child ($ab2);
  $ab2->append_child ($ab3);
  $ab3->append_child ($ab4);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<bb xmlns="http://hoge1/"><bb xmlns="http://hoge2/"><bb xmlns=""><bb xmlns="http://hoge4/"></bb></bb></bb></bb>>;
  done $c;
} n => 1, name => 'element_xmlns_7';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('');
  my $ab1 = $doc->create_element_ns ('http://hoge1/', [undef, 'bb']);
  my $ab2 = $doc->create_element_ns ('http://hoge2/', [undef, 'bb']);
  my $ab3 = $doc->create_element_ns (undef, [undef, 'bb']);
  my $ab4 = $doc->create_element_ns ('http://hoge4/', [undef, 'bb']);
  $ab4->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'xmlns'], '');
  $el->append_child ($ab1);
  $ab1->append_child ($ab2);
  $ab2->append_child ($ab3);
  $ab3->append_child ($ab4);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<bb xmlns="http://hoge1/"><bb xmlns="http://hoge2/"><bb xmlns=""><a0:bb xmlns:a0="http://hoge4/" xmlns=""></a0:bb></bb></bb></bb>>;
  done $c;
} n => 1, name => 'element_xmlns_8';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns (undef, [undef, 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" hOge="fuga"></p>>;
  done $c;
} n => 1, name => 'attr_name_null';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/XML/1998/namespace', [undef, 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" xml:hOge="fuga"></p>>;
  done $c;
} n => 1, name => 'attr_name_xml';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  $doc->strict_error_checking (0);
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" xmlns:hOge="fuga"></p>>;
  done $c;
} n => 1, name => 'attr_name_xmlns';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'xmlns'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<a0:p xmlns:a0="http://www.w3.org/1999/xhtml" xmlns="fuga"></a0:p>>;
  done $c;
} n => 1, name => 'attr_name_xmlns_xmlns';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/1999/xlink', [undef, 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" a0:hOge="fuga" xmlns:a0="http://www.w3.org/1999/xlink"></p>>;
  done $c;
} n => 1, name => 'attr_name_xlink';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  $doc->strict_error_checking (0);
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://www.w3.org/1999/xhtml', ['xmlns', 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" a0:hOge="fuga" xmlns:a0="http://www.w3.org/1999/xhtml"></p>>;
  done $c;
} n => 1, name => 'attr_name_html';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns ('http://test', [undef, 'hOge'] => 'fuga');
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q<<p xmlns="http://www.w3.org/1999/xhtml" a0:hOge="fuga" xmlns:a0="http://test"></p>>;
  done $c;
} n => 1, name => 'attr_name_unknown';

for my $tag_name (qw(style script xmp iframe noembed noframes plaintext)) {
  test {
    my $c = shift;
    my ($doc, $el) = create_el_from_html
        ($tag_name eq 'plaintext' ? '<plaintext>' : '<' . $tag_name . '></' . $tag_name . '>');
    my $pt = $el->first_child;
    is ${Web::XML::Serializer->new->get_inner_html ($pt)},
        q<>;

    $pt->inner_html (q<abc>);
    is ${Web::XML::Serializer->new->get_inner_html ($pt)},
        q<abc>;
    
    $pt->append_child ($doc->create_text_node ('<p>xyz'));
    is ${Web::XML::Serializer->new->get_inner_html ($pt)},
        q<abc&lt;p&gt;xyz>;
    
    $pt->append_child ($doc->create_element_ns (undef, [undef, 'A']))->text_content ('bcd');
    is ${Web::XML::Serializer->new->get_inner_html ($pt)},
        q<abc&lt;p&gt;xyz<A xmlns="">bcd</A>>;
    is ${Web::XML::Serializer->new->get_inner_html ($el)},
        qq<<$tag_name xmlns="http://www.w3.org/1999/xhtml">abc&lt;p&gt;xyz<A xmlns="">bcd</A></$tag_name>>;
    done $c;
  } n => 5, name => ['plaintext', $tag_name];
}

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<noscript></noscript>');
  my $noscript = $el->first_child;
  $noscript->append_child ($doc->create_text_node ('avc&<">\'' . "\xA0"));
  $noscript->append_child ($doc->create_element_ns (undef, [undef, 'abC']))
      ->set_attribute_ns (undef, [undef, 'class'] => 'xYz');
  $noscript->append_child ($doc->create_text_node ('Q&A'));

  local $Web::ScriptingEnabled = 0;
  is ${Web::XML::Serializer->new->get_inner_html ($noscript)},
      qq<avc&amp;&lt;"&gt;'&nbsp;<abC xmlns="" class="xYz"></abC>Q&amp;A>,
      'noscript_scripting_disabled noscript inner';
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      qq<<noscript xmlns="http://www.w3.org/1999/xhtml">avc&amp;&lt;"&gt;'&nbsp;<abC xmlns="" class="xYz"></abC>Q&amp;A</noscript>>,
      'noscript_scripting_disabled';

  local $Web::ScriptingEnabled = 1;
  is ${Web::XML::Serializer->new->get_inner_html ($noscript)},
      qq<avc&amp;&lt;"&gt;'&nbsp;<abC xmlns="" class="xYz"></abC>Q&amp;A>,
      'noscript_scripting_enabled noscript inner';
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      qq<<noscript xmlns="http://www.w3.org/1999/xhtml">avc&amp;&lt;"&gt;'&nbsp;<abC xmlns="" class="xYz"></abC>Q&amp;A</noscript>>,
      'noscript_scripting_enabled';
  done $c;
} n => 4, name => 'noscript';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<xmp></xmp>');
  my $xmp = $el->first_child;
  $xmp->append_child ($doc->create_text_node ('abc<>&"' . "\xA0"));
  my $pre = $xmp->append_child ($doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, 'pre']));
  $pre->append_child ($doc->create_text_node ('abc<>&"' . "\xA0"));

  is ${Web::XML::Serializer->new->get_inner_html ($xmp)},
      qq<abc&lt;&gt;&amp;"&nbsp;<pre xmlns="http://www.w3.org/1999/xhtml">abc&lt;&gt;&amp;"&nbsp;</pre>>;
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      qq<<xmp xmlns="http://www.w3.org/1999/xhtml">abc&lt;&gt;&amp;"&nbsp;<pre>abc&lt;&gt;&amp;"&nbsp;</pre></xmp>>;
  done $c;
} n => 2, name => 'xmp_descendant';

test {
  my $c = shift;
  my ($doc, $el) = create_el_from_html ('<p>');
  my $p = $el->first_child;
  $p->set_attribute_ns (undef, [undef, 'id'] => '<>&"' . qq<"']]> . '>' . "\xA0");
  
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      qq{<p xmlns="http://www.w3.org/1999/xhtml" id="<>&amp;&quot;&quot;']]>&nbsp;"></p>};
  done $c;
} n => 1, name => 'attr_value';

for my $tag_name (qw(
  area base basefont bgsound br col command embed frame hr img input
  keygen link meta param source track wbr
)) {
  test {
    my $c = shift;
    my ($doc, $el) = create_el_from_html ('<p>');
    my $p = $el->first_child;
    my $el1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
    $p->append_child ($el1);
    is ${Web::XML::Serializer->new->get_inner_html ($p)},
        qq{<$tag_name xmlns="http://www.w3.org/1999/xhtml"></$tag_name>};

    my $el2 = $doc->create_element_ns (undef, [undef, $tag_name]);
    $p->remove_child ($el1);
    $p->append_child ($el2);
    is ${Web::XML::Serializer->new->get_inner_html ($p)},
        qq{<$tag_name xmlns=""></$tag_name>};

    my $el3 = $doc->create_element_ns ('http://test/', [undef, $tag_name]);
    $p->remove_child ($el2);
    $p->append_child ($el3);
    is ${Web::XML::Serializer->new->get_inner_html ($p)},
        qq{<$tag_name xmlns="http://test/"></$tag_name>};

    my $el4 = $doc->create_element_ns ('http://www.w3.org/2000/svg', [undef, $tag_name]);
    $p->remove_child ($el3);
    $p->append_child ($el4);
    is ${Web::XML::Serializer->new->get_inner_html ($p)},
        qq{<$tag_name xmlns="http://www.w3.org/2000/svg"></$tag_name>};

    my $el5 = $doc->create_element_ns ('http://www.w3.org/1998/Math/MathML', [undef, $tag_name]);
    $p->remove_child ($el4);
    $p->append_child ($el5);
    is ${Web::XML::Serializer->new->get_inner_html ($p)},
        qq{<$tag_name xmlns="http://www.w3.org/1998/Math/MathML"></$tag_name>};
    done $c;
  } n => 5, name => ['void_elements', $tag_name];
}

for my $tag_name (qw(textarea pre listing)) {
  test {
    my $c = shift;
    my ($doc, $el) = create_el_from_html ('');
    my $child = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
    $child->text_content ("\x0Aabc\x0A");
    $el->append_child ($child);
    is ${Web::XML::Serializer->new->get_inner_html ($el)},
        qq<<$tag_name xmlns="http://www.w3.org/1999/xhtml">\x0Aabc\x0A</$tag_name>>;
    done $c;
  } n => 1, name => 'start_tag_trailing_newlines';

  for my $nsurl (undef, q<http://test/>, q<http://www.w3.org/2000/svg>) {
    test {
      my $c = shift;
      my ($doc, $el) = create_el_from_html ('');
      my $child = $doc->create_element_ns ($nsurl, [undef, $tag_name]);
      $child->text_content ("\x0Aabc\x0A");
      $el->append_child ($child);
      is ${Web::XML::Serializer->new->get_inner_html ($el)},
          qq<<$tag_name xmlns="@{[$nsurl || '']}">\x0Aabc\x0A</$tag_name>>;
      done $c;
    } n => 1, name => 'start_tag_trailing_newlines';
  }

  test {
    my $c = shift;
    my ($doc, $el) = create_el_from_html ('');
    my $child = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', [undef, $tag_name]);
    $child->text_content ("\x0Aabc\x0A");
    is ${Web::XML::Serializer->new->get_inner_html ($child)},
        qq<\x0Aabc\x0A>;
    done $c;
  } n => 1, name => 'start_tag_trailing_newlines';
}

test {
  my $c = shift;
  my $doc = create_doc_from_html ('<!DOCTYPE html><p>');
  is ${Web::XML::Serializer->new->get_inner_html ($doc)},
      q<<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml"><head></head><body><p></p></body></html>>;
  done $c;
} n => 1, name => 'doc';

test {
  my $c = shift;
  my $doc = create_doc_from_html ('<!DOCTYPE html>');
  my $df = $doc->create_document_fragment;
  $df->append_child ($doc->create_element_ns (undef, [undef, 'p']))->text_content ('a&b');
  $df->manakai_append_text ('ab<>cd');
  is ${Web::XML::Serializer->new->get_inner_html ($df)},
    q<<p xmlns="">a&amp;b</p>ab&lt;&gt;cd>;
  done $c;
} n => 1, name => 'df';

test {
  my $c = shift;
  my $doc = create_doc_from_html ('<!DOCTYPE HTML>');
  my $div = $doc->create_element_ns (undef, [undef, 'div']);
  my $svg = $doc->create_element_ns
      (q<http://www.w3.org/2000/svg>, ['svg', 'svg']);
  $div->append_child ($svg);
  
  is ${Web::XML::Serializer->new->get_inner_html ($div)},
      q<<svg:svg xmlns:svg="http://www.w3.org/2000/svg"></svg:svg>>;
  done $c;
} n => 1, name => 'svg';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->strict_error_checking (0);
  my $div = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'div']);
  my $el = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'p']);
  $div->append_child ($el);
  $el->text_content ("a b \x{1000}\x{2000}<!&\"'>\xA0");
  $el->set_attribute_ns (undef, [undef, 'title'], '<!&"\'>' . "\xA0");
  $el->append_child ($doc->create_comment ('A -- B'));
  $el->append_child ($doc->create_processing_instruction ('xml', 'version="1.0?>"'));
  $doc->append_child ($div);
  my $html = Web::XML::Serializer->new->get_inner_html ($doc);
  eq_or_diff $$html, qq{<div xmlns="http://www.w3.org/1999/xhtml"><p title="<!&amp;&quot;'>&nbsp;">a b \x{1000}\x{2000}&lt;!&amp;"'&gt;&nbsp;<!--A -- B--><?xml version="1.0?>"?></p></div>};
  done $c;
} n => 1;

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el3 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'fuga');
  $el->append_child ($el2);
  $el->content->append_child ($el3);
  $el->content->append_child ($doc->create_text_node ('abc'));
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q{<fuga xmlns="http://www.w3.org/1999/xhtml"></fuga>abc};
  done $c;
} n => 1, name => 'template';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el3 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'br');
  $el->append_child ($el2);
  $el->content->append_child ($el3);
  $el->content->append_child ($doc->create_text_node ('abc'));
  $el->content->owner_document->manakai_is_html (1);
  is ${Web::XML::Serializer->new->get_inner_html ($el)},
      q{<br xmlns="http://www.w3.org/1999/xhtml"></br>abc};
  done $c;
} n => 1, name => 'template html/xml';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el0 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'foo');
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  $el0->append_child ($el);
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el3 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'fuga');
  $el->append_child ($el2);
  $el->content->append_child ($el3);
  $el->content->append_child ($doc->create_text_node ('abc'));
  is ${Web::XML::Serializer->new->get_inner_html ($el0)},
      q{<template xmlns="http://www.w3.org/1999/xhtml"><fuga></fuga>abc</template>};
  done $c;
} n => 1, name => 'template parent';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el0 = $doc->create_document_fragment;
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  $el0->append_child ($el);
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el3 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'fuga');
  $el->append_child ($el2);
  $el->content->append_child ($el3);
  $el->content->append_child ($doc->create_text_node ('abc'));
  is ${Web::XML::Serializer->new->get_inner_html ([$el0])},
      q{<template xmlns="http://www.w3.org/1999/xhtml"><fuga></fuga>abc</template>};
  done $c;
} n => 1, name => 'template parent df';

run_tests;

=head1 LICENSE

Copyright 2009-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
