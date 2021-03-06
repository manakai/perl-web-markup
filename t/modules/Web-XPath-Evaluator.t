use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::DOM::Document;
use Web::XPath::Parser;
use Web::XPath::Evaluator;

test {
  my $c = shift;
  my $eval = Web::XPath::Evaluator->new;
  my $result = $eval->evaluate (undef);
  is $result, undef;
  done $c;
} n => 1, name => 'parse error';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p>aa</p>});
  $doc->first_child->append_child ($doc->create_text_node ('abc'));
  my $parser = Web::XPath::Parser->new;
  my $expr = $parser->parse_char_string_as_expression ('/child::*/text ()');
  my $eval = Web::XPath::Evaluator->new;
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'node-set', value => [$doc->first_child->child_nodes->[0], $doc->first_child->child_nodes->[1]]};
  done $c;
} n => 1, name => 'adjucent text nodes';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'a');
  my $parser = Web::XPath::Parser->new;
  my $expr = $parser->parse_char_string_as_expression ('/');
  my $eval = Web::XPath::Evaluator->new;
  {
    my $result = $eval->evaluate ($expr, $el);
    eq_or_diff $result, {type => 'node-set', value => [$el]};
  }
  my $el2 = $doc->create_text_node ('');
  $el->append_child ($el2);
  {
    my $result = $eval->evaluate ($expr, $el2);
    eq_or_diff $result, {type => 'node-set', value => [$el]};
  }
  $doc->append_child ($el);
  {
    my $result = $eval->evaluate ($expr, $el2);
    eq_or_diff $result, {type => 'node-set', value => [$doc]};
  }
  done $c;
} n => 3, name => '/';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $df = $doc->create_document_fragment;
  $df->inner_html (q{<p>aa</p>bxx<!--cc-->});
  my $parser = Web::XPath::Parser->new;
  my $expr = $parser->parse_char_string_as_expression ('string()');
  my $eval = Web::XPath::Evaluator->new;
  my $result = $eval->evaluate ($expr, $df);
  eq_or_diff $result, {type => 'string', value => 'aabxx'};
  done $c;
} n => 1, name => 'document fragment string()';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $node = $doc->create_element_type_definition ('x');
  my $parser = Web::XPath::Parser->new;
  my $expr = $parser->parse_char_string_as_expression ('string()');
  my $eval = Web::XPath::Evaluator->new;
  my $result = $eval->evaluate ($expr, $node);
  eq_or_diff $result, {type => 'string', value => ''};
  done $c;
} n => 1, name => 'non-standard string()';

test {
  my $c = shift;
  my $eval = Web::XPath::Evaluator->new;
  my $doc = new Web::DOM::Document;
  eq_or_diff $eval->to_string_value ($doc), {type => 'string', value => ''};
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'a');
  eq_or_diff $eval->to_string_value ($el), {type => 'string', value => ''};
  $el->text_content ('aagtw');
  eq_or_diff $eval->to_string_value ($el), {type => 'string', value => 'aagtw'};
  eq_or_diff $eval->to_string_value ($el->first_child), {type => 'string', value => 'aagtw'};
  $el->append_child ($doc->create_comment ('gwagw'));
  eq_or_diff $eval->to_string_value ($el), {type => 'string', value => 'aagtw'};
  $doc->append_child ($doc->create_processing_instruction ('xy', 'aw'));
  eq_or_diff $eval->to_string_value ($doc), {type => 'string', value => ''};
  $doc->append_child ($el);
  eq_or_diff $eval->to_string_value ($doc), {type => 'string', value => 'aagtw'};
  done $c;
} n => 7, name => 'to_string_value';

test {
  my $c = shift;
  my $eval = Web::XPath::Evaluator->new;
  eq_or_diff $eval->to_xpath_number (0), {type => 'number', value => 0};
  eq_or_diff $eval->to_xpath_number (-12.4), {type => 'number', value => -12.4};
  eq_or_diff $eval->to_xpath_number (0+'inf'), {type => 'number', value => 0+'inf'};
  eq_or_diff $eval->to_xpath_number (0+'nan'), {type => 'number', value => 0+'nan'};
  eq_or_diff $eval->to_xpath_number ('abcee'), {type => 'number', value => 0};
  eq_or_diff $eval->to_xpath_number ('52152abeae'), {type => 'number', value => 52152};
  done $c;
} n => 6, name => 'to_xpath_number';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p id="foo">aa</p>});
  my $df = $doc->create_document_fragment;
  $df->inner_html (q{<p>aa</p><q id="foo"></q><q id=""/><q id="foo"></q>});
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  {
    my $expr = $parser->parse_char_string_as_expression ('id("foo")');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'node-set', value => [$df->child_nodes->[1]]};
  }
  {
    my $expr = $parser->parse_char_string_as_expression ('id("")');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'node-set', value => []};
  }
  done $c;
} n => 2, name => 'id() on non-document tree';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p id="foo">aa</p>});
  my $df = $doc->create_document_fragment;
  $df->inner_html (q{<p>aa</p><q id="foo"></q><q id=""/><q id="foo"></q>});
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  {
    my $expr = $parser->parse_char_string_as_expression ('name()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  {
    my $expr = $parser->parse_char_string_as_expression ('namespace-uri()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  {
    my $expr = $parser->parse_char_string_as_expression ('local-name()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  done $c;
} n => 3, name => 'name() on non-document tree';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p id="foo">aa</p>});
  my $df = $doc->create_attribute_definition ('aa');
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  {
    my $expr = $parser->parse_char_string_as_expression ('name()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  {
    my $expr = $parser->parse_char_string_as_expression ('namespace-uri()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  {
    my $expr = $parser->parse_char_string_as_expression ('local-name()');
    my $result = $eval->evaluate ($expr, $df);
    $eval->sort_node_set ($result);
    eq_or_diff $result, {type => 'string', value => ''};
  }
  done $c;
} n => 3, name => 'name() on non-document tree';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  $parser->variable_bindings->set_variable (undef, 'ab-c' => $eval->to_xpath_string ('hog e'));
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'string', value => 'hog e'};
  done $c;
} n => 1, name => 'variable is string';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XPath::Parser->new;
  $parser->ns_resolver (sub { 'http://f/' });
  my $eval = Web::XPath::Evaluator->new;
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c' => $eval->to_xpath_number (-31.55));
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'number', value => -31.55};
  done $c;
} n => 1, name => 'variable is number';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XPath::Parser->new;
  $parser->ns_resolver (sub { 'http://f/' });
  my $eval = Web::XPath::Evaluator->new;
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c' => $eval->to_xpath_boolean (1));
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'boolean', value => 1};
  done $c;
} n => 1, name => 'variable is boolean';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XPath::Parser->new;
  $parser->ns_resolver (sub { 'http://f/' });
  my $eval = Web::XPath::Evaluator->new;
  my @error;
  $eval->onerror (sub {
    push @error, {@_};
  });
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c' => $eval->to_xpath_boolean (1));
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c/abc');
  my $result = $eval->evaluate ($expr, $doc);
  is $result, undef;
  eq_or_diff \@error, [{type => 'xpath:incompat with node-set',
                        value => 'boolean', level => 'm'}];
  done $c;
} n => 2, name => 'variable is boolean';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $e1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'aa');
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c' => $eval->to_xpath_node_set ([$e1, $doc, $doc]));
  $parser->ns_resolver (sub { 'http://f/' });
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'node-set', value => [$e1, $doc], unordered => 1};
  done $c;
} n => 1, name => 'variable is node-set';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $e1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'aa');
  $doc->append_child ($e1);
  my $parser = Web::XPath::Parser->new;
  $parser->ns_resolver (sub { 'http://f/' });
  my $eval = Web::XPath::Evaluator->new;
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c' => $eval->to_xpath_node_set ([$e1, $doc]));
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c[2]');
  my $result = $eval->evaluate ($expr, $doc);
  eq_or_diff $result, {type => 'node-set', value => [$e1]};
  done $c;
} n => 1, name => 'variable is node-set';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $e1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'aa');
  my $parser = Web::XPath::Parser->new;
  $parser->ns_resolver (sub { 'http://f/' });
  my $eval = Web::XPath::Evaluator->new;
  my @error;
  $eval->onerror (sub {
    push @error, {@_};
  });
  $parser->variable_bindings->set_variable (undef, 'ab-c', $eval->to_xpath_string (''));
  $eval->variable_bindings->set_variable ('', 'ab-c' => $eval->to_xpath_node_set ([$e1, $doc]));
  my $expr = $parser->parse_char_string_as_expression ('$ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  is $result, undef;
  eq_or_diff \@error, [{type => 'xpath:var not defined',
                        value => 'ab-c', level => 'm'}];
  done $c;
} n => 2, name => 'variable is not defined';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  $parser->ns_resolver (sub { 'http://f/' });
  $parser->variable_bindings->set_variable ('http://f/', 'ab-c', $eval->to_xpath_string (''));
  my @error;
  $eval->onerror (sub {
    push @error, {@_};
  });
  my $expr = $parser->parse_char_string_as_expression ('$f:ab-c');
  my $result = $eval->evaluate ($expr, $doc);
  is $result, undef;
  eq_or_diff \@error, [{type => 'xpath:var not defined',
                        value => 'f:ab-c', level => 'm'}];
  done $c;
} n => 2, name => 'variable is not defined';

test {
  my $c = shift;
  my $doc1 = new Web::DOM::Document;
  $doc1->manakai_is_html (1);
  my $el1 = $doc1->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el3 = $doc1->create_element_ns (undef, 'hoge');
  $doc1->append_child ($el1);
  $el1->append_child ($el3);
  my $doc2 = new Web::DOM::Document;
  my $el2 = $doc2->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el4 = $doc2->create_element_ns (undef, 'hoge');
  $doc2->append_child ($el2);
  $el2->append_child ($el4);
  my $parser = Web::XPath::Parser->new;
  my $eval = Web::XPath::Evaluator->new;
  my $ns1 = $eval->to_xpath_node_set ([$doc1, $doc2]);
  $parser->variable_bindings->set_variable (undef, 'a' => $ns1);
  $eval->variable_bindings ($parser->variable_bindings);
  my $expr = $parser->parse_char_string_as_expression ('$a//hoge');
  my $ns2 = $eval->to_xpath_node_set ([$el1, $el2]);
  $eval->sort_node_set ($ns2);
  my $ns3 = $eval->to_xpath_node_set ([$el3, $el4]);
  $eval->sort_node_set ($ns3);
  {
    my $result = $eval->evaluate ($expr, $doc1);
    $eval->sort_node_set ($result);
    eq_or_diff $result, $ns2;
  }
  {
    my $result = $eval->evaluate ($expr, $doc2);
    $eval->sort_node_set ($result);
    eq_or_diff $result, $ns3;
  }
  {
    my $result = $eval->evaluate ($expr, $el1);
    $eval->sort_node_set ($result);
    eq_or_diff $result, $ns2;
  }
  {
    my $result = $eval->evaluate ($expr, $el2);
    $eval->sort_node_set ($result);
    eq_or_diff $result, $ns3;
  }
  done $c;
} n => 4, name => 'HTML and XML';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
