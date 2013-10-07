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
  my $el = $doc->create_element ('a');
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
  my $el = $doc->create_element ('a');
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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
