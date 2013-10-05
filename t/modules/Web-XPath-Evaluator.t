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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
