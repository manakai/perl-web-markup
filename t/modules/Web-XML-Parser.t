use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::XML::Parser;
use Web::DOM::Document;

test {
  my $c = shift;
  my $s = qq{<foo>\x{4500}<bar xy="zb"/>\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html,
      qq{<foo xmlns="">\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is $doc->input_encoding, 'utf-8';
  is $doc->xml_version, '1.0';
  is $doc->xml_encoding, undef;
  ok not $doc->xml_standalone;
  ok not $doc->manakai_is_html;
  is scalar @{$doc->child_nodes}, 2;
  done $c;
} n => 7, name => 'parse_char_string';

test {
  my $c = shift;
  my $s = qq{<foo>\x{4500}<bar xy="zb"/>\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<foo>abc</foo>});
  is scalar @{$doc->child_nodes}, 1;
  
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html,
      qq{<foo xmlns="">\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is scalar @{$doc->child_nodes}, 2;
  done $c;
} n => 3, name => 'parse_char_string_old_content';

test {
  my $c = shift;
  my $s = qq{<foo>\x{4500}<bar xy=zb />\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html,
      qq{<foo xmlns="">\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is scalar @{$doc->child_nodes}, 2;
  delete $error[0]->{token};
  eq_or_diff \@error, [{type => 'unquoted attr value',
                        level => 'm',
                        line => 1, column => 15}];
  done $c;
} n => 3, name => 'parse_char_string_old_content';

test {
  my $c = shift;
  my $s = q{<!DOCTYPE a[<!ENTITY x SYSTEM "">]><a>B&x;C</a>};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html, q{<!DOCTYPE a><a xmlns="">BC</a>};
  eq_or_diff \@error, [{type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 40}];
  done $c;
} n => 2, name => 'parse_char_string - external entity';

test {
  my $c = shift;
  my $s = q{<!DOCTYPE a[<!ENTITY x SYSTEM "">]><a>B&x;C&x;D</a>};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html, q{<!DOCTYPE a><a xmlns="">BCD</a>};
  eq_or_diff \@error, [{type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 40},
                       {type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 44}];
  done $c;
} n => 2, name => 'parse_char_string - external entity';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns (undef, [undef, 'nnn']);
  my $children = $parser->parse_char_string_with_context
      ('<hoge>aaa<!-- bb -->bb<foo/>cc</hoge>aa<bb/>',
       $el, Web::DOM::Document->new);
  
  is scalar @$children, 3;
  is $children->[0]->namespace_uri, undef;
  is $children->[0]->manakai_tag_name, 'hoge';
  is $children->[0]->inner_html, 'aaa<!-- bb -->bb<foo xmlns=""></foo>cc';
  is $children->[1]->data, 'aa';
  is $children->[2]->namespace_uri, undef;
  is $children->[2]->manakai_tag_name, 'bb';
  is $children->[2]->text_content, '';
  done $c;
} n => 8, name => 'parse_char_string_with_context';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://foo/', [undef, 'nnn']);
  my $children = $parser->parse_char_string_with_context
      ('<hoge/>', $el, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, 'http://foo/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns1';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  my $children = $parser->parse_char_string_with_context
      ('<ho:hoge/>', $el, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, 'http://foo/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns2';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  my $el2 = $doc->create_element_ns ('http://bar/', ['ho', 'nnn']);
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<ho:hoge/>', $el2, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, 'http://bar/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns3';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  $el1->set_attribute_ns ('http://www.w3.org/2000/xmlns/', ['xmlns', 'a5'],
                          'http://ns1/');
  my $el2 = $doc->create_element_ns ('http://bar/', ['ho', 'nnn']);
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<a5:hoge/>', $el2, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, 'http://ns1/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns4';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  $el1->set_attribute_ns ('http://www.w3.org/2000/xmlns/', [undef, 'xmlns'],
                          'http://ns1/');
  my $el2 = $doc->create_element_ns ('http://bar/', ['ho', 'nnn']);
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<hoge/>', $el2, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, 'http://ns1/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns5';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  my $el2 = $doc->create_element_ns ('http://bar/', [undef, 'nnn']);
  $el2->set_attribute_ns ('http://www.w3.org/2000/xmlns/', ['xmlns', 'ho'],
                          '');
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<ho:hoge/>', $el2, Web::DOM::Document->new);
  is $children->[0]->namespace_uri, undef;
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns6';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  my $el2 = $doc->create_element_ns ('http://bar/', [undef, 'nnn']);
  $el2->set_attribute_ns ('http://www.w3.org/2000/xmlns/', ['xmlns', 'xml'],
                          'http://foo/');
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<hoge xml:lang="en"/>', $el2, Web::DOM::Document->new);
  is $children->[0]->attributes->[0]->namespace_uri,
      'http://www.w3.org/XML/1998/namespace';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns7';

test {
  my $c = shift;
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  my $el1 = $doc->create_element_ns ('http://foo/', ['ho', 'nnn']);
  my $el2 = $doc->create_element_ns ('http://bar/', [undef, 'nnn']);
  $el2->set_attribute_ns ('http://www.w3.org/2000/xmlns/', ['xmlns', 'abc'],
                          'http://foo/');
  $el1->append_child ($el2);
  my $children = $parser->parse_char_string_with_context
      ('<hoge abc:lang="en"/>', $el2, Web::DOM::Document->new);
  is $children->[0]->attributes->[0]->namespace_uri,
      'http://foo/';
  done $c;
} n => 1, name => 'parse_char_string_with_context_ns8';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = new Web::XML::Parser;
  $parser->parse_char_string (q{<template xmlns="http://www.w3.org/1999/xhtml"></template>} => $doc);
  is $doc->child_nodes->length, 1;
  my $el = $doc->document_element;
  is $el->child_nodes->length, 0;
  is $el->content->child_nodes->length, 0;
  done $c;
} n => 3, name => 'template root, empty';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = new Web::XML::Parser;
  $parser->parse_char_string (q{<template xmlns="http://www.w3.org/1999/xhtml"><p>hoge</p><!--abc--><?ab?>aa<![CDATA[dd]]></template>} => $doc);
  is $doc->child_nodes->length, 1;
  my $el = $doc->document_element;
  is $el->child_nodes->length, 0;
  is $el->content->child_nodes->length, 4;
  is $el->inner_html, q{<p xmlns="http://www.w3.org/1999/xhtml">hoge</p><!--abc--><?ab ?>aadd};
  done $c;
} n => 4, name => 'template root, non-empty';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = new Web::XML::Parser;
  $parser->parse_char_string (q{<a:b xmlns:a="http://www.w3.org/1999/xhtml"><a:template><p>hoge</p><!--abc--><?ab?>aa<![CDATA[dd]]><a:x/></a:template></a:b>} => $doc);
  is $doc->child_nodes->length, 1;
  my $el = $doc->document_element->first_child;
  is $el->child_nodes->length, 0;
  is $el->content->child_nodes->length, 5;
  is $el->inner_html, q{<p xmlns="">hoge</p><!--abc--><?ab ?>aadd<a:x xmlns:a="http://www.w3.org/1999/xhtml"></a:x>};
  done $c;
} n => 4, name => 'template non-root, non-empty';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = new Web::XML::Parser;
  $parser->parse_char_string (q{<a:b xmlns:a="http://www.w3.org/1999/xhtml"><a:template><p>hoge</p><!--abc--><?ab?>aa<![CDATA[dd]]><template xmlns="http://www.w3.org/1999/xhtml"><a:x/></template></a:template></a:b>} => $doc);
  is $doc->child_nodes->length, 1;
  my $el = $doc->document_element->first_child;
  is $el->child_nodes->length, 0;
  is $el->content->child_nodes->length, 5;
  is $el->inner_html, q{<p xmlns="">hoge</p><!--abc--><?ab ?>aadd<template xmlns="http://www.w3.org/1999/xhtml"><a:x xmlns:a="http://www.w3.org/1999/xhtml"></a:x></template>};
  done $c;
} n => 4, name => 'template non-root, non-empty';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('template');
  my $parser = new Web::XML::Parser;
  my $result = $parser->parse_char_string_with_context
      (q{<p>a</p><!--aa-->bb}, $el => $doc);

  isa_ok $result, 'Web::DOM::NodeList';
  is $result->length, 3;
  is $result->[0]->outer_html, q{<p xmlns="http://www.w3.org/1999/xhtml">a</p>};
  is $result->[1]->data, 'aa';
  is $result->[2]->data, 'bb';
  done $c;
} n => 5, name => 'parse_char_string_with_context context is template';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('hoge');
  my $parser = new Web::XML::Parser;
  my $result = $parser->parse_char_string_with_context
      (q{<template><p>a</p><!--aa-->bb</template>}, $el => $doc);

  isa_ok $result, 'Web::DOM::NodeList';
  is $result->length, 1;
  is $result->[0]->child_nodes->length, 0;
  is $result->[0]->content->child_nodes->length, 3;
  is $result->[0]->outer_html, q{<template xmlns="http://www.w3.org/1999/xhtml"><p>a</p><!--aa-->bb</template>};
  done $c;
} n => 5, name => 'parse_char_string_with_context has template';

test {
  my $c = shift;
  my $s = q{<!DOCTYPE a[<!ENTITY x SYSTEM "">]><a>B&x;C</a>};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string_with_context ($s, undef, $doc);
  eq_or_diff $doc->inner_html, q{<!DOCTYPE a><a xmlns="">BC</a>};
  eq_or_diff \@error, [{type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 40}];
  done $c;
} n => 2, name => 'parse_char_string_with_context - external entity';

test {
  my $c = shift;
  my $s = q{<!DOCTYPE a[<!ENTITY x SYSTEM "">]><a>B&x;C&x;D</a>};
  my $parser = Web::XML::Parser->new;
  my $doc = new Web::DOM::Document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string_with_context ($s, undef, $doc);
  eq_or_diff $doc->inner_html, q{<!DOCTYPE a><a xmlns="">BCD</a>};
  eq_or_diff \@error, [{type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 40},
                       {type => 'external entref',
                        level => 'i', value => 'x;',
                        line => 1, column => 44}];
  done $c;
} n => 2, name => 'parse_char_string_with_context - external entity';

run_tests;

=head1 LICENSE

Copyright 2009-2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
