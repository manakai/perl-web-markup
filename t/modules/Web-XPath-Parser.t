use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Web::XPath::Parser;

for my $test (
  {in => '', out => [['EOF', 0]]},
  {in => 'a', out => [['NameTest', 0, undef, 'a'], ['EOF', 1]]},
  {in => 'hoge', out => [['NameTest', 0, undef, 'hoge'], ['EOF', 4]]},
  {in => 'hoge ', out => [['NameTest', 0, undef, 'hoge'], ['EOF', 5]]},
  {in => "\x{5E00}", out => [['NameTest', 0, undef, "\x{5E00}"], ['EOF', 1]]},
  {in => "12\x{5E00}", out => [['Number', 0, '12'], ['NameTest', 2, undef, "\x{5E00}"], ['EOF', 3]]},
  {in => "\x09\x0A[]\x0D \@", out => [['[', 2], [']', 3], ['@', 6], ['EOF', 7]]},
  {in => '()...,::', out => [['(', 0], [')', 1], ['..', 2], ['.', 4], [',', 5], ['::', 6], ['EOF', 8]]},
  {in => '""', out => [['Literal', 0, ''], ['EOF', 2]]},
  {in => '"ab x"', out => [['Literal', 0, 'ab x'], ['EOF', 6]]},
  {in => q{"ab' x"}, out => [['Literal', 0, q{ab' x}], ['EOF', 7]]},
  {in => q{''}, out => [['Literal', 0, q{}], ['EOF', 2]]},
  {in => q{'ab" x'}, out => [['Literal', 0, q{ab" x}], ['EOF', 7]]},
  {in => q{000}, out => [['Number', 0, q{000}], ['EOF', 3]]},
  {in => q{00.120}, out => [['Number', 0, q{00.120}], ['EOF', 6]]},
  {in => q{125129.}, out => [['Number', 0, q{125129.}], ['EOF', 7]]},
  {in => q{.000135533393310}, out => [['Number', 0, q{.000135533393310}], ['EOF', 16]]},
  {in => q{.000.424}, out => [['Number', 0, q{.000}], ['Number', 4, q{.424}], ['EOF', 8]]},
  {in => q{+12}, out => [['Operator', 0, '+'], ['Number', 1, q{12}], ['EOF', 3]]},
  {in => q{--12}, out => [['Operator', 0, '-'], ['Operator', 1, '-'], ['Number', 2, q{12}], ['EOF', 4]]},
  {in => q{///|+-=!=<<=>>=}, out => [['Operator', 0, '//'], ['Operator', 2, q{/}], ['Operator', 3, '|'], ['Operator', 4, '+'], ['Operator', 5, '-'], ['Operator', 6, '='], ['Operator', 7, '!='], ['Operator', 9, '<'], ['Operator', 10, '<='], ['Operator', 12, '>'], ['Operator', 13, '>='], ['EOF', 15]]},
  {in => q{*}, out => [['NameTest', 0, undef, undef], ['EOF', 1]]},
  {in => q{  *}, out => [['NameTest', 2, undef, undef], ['EOF', 3]]},
  {in => q{@*}, out => [['@', 0], ['NameTest', 1, undef, undef], ['EOF', 2]]},
  {in => q{::*}, out => [['::', 0], ['NameTest', 2, undef, undef], ['EOF', 3]]},
  {in => q{( *}, out => [['(', 0], ['NameTest', 2, undef, undef], ['EOF', 3]]},
  {in => q{[  *}, out => [['[', 0], ['NameTest', 3, undef, undef], ['EOF', 4]]},
  {in => q{/*}, out => [['Operator', 0, '/'], ['NameTest', 1, undef, undef], ['EOF', 2]]},
  {in => q{]*}, out => [[']', 0], ['Operator', 1, '*'], ['EOF', 2]]},
  {in => q{mod*}, out => [['NameTest', 0, undef, 'mod'], ['Operator', 3, '*'], ['EOF', 4]]},
  {in => q{div*}, out => [['NameTest', 0, undef, 'div'], ['Operator', 3, '*'], ['EOF', 4]]},
  {in => q{and*}, out => [['NameTest', 0, undef, 'and'], ['Operator', 3, '*'], ['EOF', 4]]},
  {in => q{or*}, out => [['NameTest', 0, undef, 'or'], ['Operator', 2, '*'], ['EOF', 3]]},
  {in => q{ho*}, out => [['NameTest', 0, undef, 'ho'], ['Operator', 2, '*'], ['EOF', 3]]},
  {in => q{@ho}, out => [['@', 0], ['NameTest', 1, undef, 'ho'], ['EOF', 3]]},
  {in => q{::ho}, out => [['::', 0], ['NameTest', 2, undef, 'ho'], ['EOF', 4]]},
  {in => q{(ho}, out => [['(', 0], ['NameTest', 1, undef, 'ho'], ['EOF', 3]]},
  {in => q{[ho}, out => [['[', 0], ['NameTest', 1, undef, 'ho'], ['EOF', 3]]},
  {in => q{+ho}, out => [['Operator', 0, '+'], ['NameTest', 1, undef, 'ho'], ['EOF', 3]]},
  {in => q{>=ho}, out => [['Operator', 0, '>='], ['NameTest', 2, undef, 'ho'], ['EOF', 4]]},
  {in => q{[and}, out => [['[', 0], ['NameTest', 1, undef, 'and'], ['EOF', 4]]},
  {in => q{[or }, out => [['[', 0], ['NameTest', 1, undef, 'or'], ['EOF', 4]]},
  {in => q{[div}, out => [['[', 0], ['NameTest', 1, undef, 'div'], ['EOF', 4]]},
  {in => q{[mod}, out => [['[', 0], ['NameTest', 1, undef, 'mod'], ['EOF', 4]]},
  {in => q{[mod:foo}, out => [['[', 0], ['NameTest', 1, 'mod', 'foo'], ['EOF', 8]]},
  {in => q{)mod:}, out => [['error', 4]]},
  {in => q{)mod:foo}, out => [['error', 4]]},
  {in => q{hoge:}, out => [['error', 0]]},
  {in => q{mod:*}, out => [['NameTest', 0, 'mod', undef], ['EOF', 5]]},
  {in => q{mod:X}, out => [['NameTest', 0, 'mod', 'X'], ['EOF', 5]]},
  {in => q{mod : X}, out => [['error', 4]]},
  {in => q{mod : *}, out => [['error', 4]]},
  {in => q{mod: *}, out => [['error', 3]]},
  {in => q{*:X}, out => [['error', 1]]},
  {in => q{**}, out => [['NameTest', 0, undef, undef], ['Operator', 1, '*'], ['EOF', 2]]},
  {in => q{***}, out => [['NameTest', 0, undef, undef], ['Operator', 1, '*'], ['NameTest', 2, undef, undef], ['EOF', 3]]},
  {in => q{foo:bar:baz}, out => [['error', 7]]},
  {in => q{:bar:baz}, out => [['error', 0]]},
  {in => q{foobar()}, out => [['FunctionName', 0, undef, 'foobar'], ['(', 6], [')', 7], ['EOF', 8]]},
  {in => q{foo:bar()}, out => [['FunctionName', 0, 'foo', 'bar'], ['(', 7], [')', 8], ['EOF', 9]]},
  {in => q{foo:*()}, out => [['NameTest', 0, 'foo', undef], ['(', 5], [')', 6], ['EOF', 7]]},
  {in => q{*()}, out => [['NameTest', 0, undef, undef], ['(', 1], [')', 2], ['EOF', 3]]},
  {in => q{*:bar()}, out => [['error', 1]]},
  {in => q{$*}, out => [['error', 0]]},
  {in => q{$*:bar}, out => [['error', 0]]},
  {in => q{$bar:*}, out => [['error', 0]]},
  {in => q{$foo}, out => [['VariableReference', 0, undef, 'foo'], ['EOF', 4]]},
  {in => q{$foo }, out => [['VariableReference', 0, undef, 'foo'], ['EOF', 5]]},
  {in => q{$foo:bar}, out => [['VariableReference', 0, 'foo', 'bar'], ['EOF', 8]]},
  {in => q{$foo()}, out => [['error', 0]]},
  {in => q{$foo:*()}, out => [['error', 0]]},
  {in => q{$foo:bar()}, out => [['error', 0]]},
  {in => q{$ foo()}, out => [['error', 0]]},
  {in => q{foo ()}, out => [['FunctionName', 0, undef, 'foo'], ['(', 4], [')', 5], ['EOF', 6]]},
  {in => q{hoge::}, out => [['error', 0]]},
  {in => q{parent::}, out => [['AxisName', 0, 'parent'], ['::', 6], ['EOF', 8]]},
  {in => q{$parent::}, out => [['error', 0]]},
  {in => q{parent:foo::}, out => [['error', 7]]},
  {in => q{parent:foo(}, out => [['FunctionName', 0, 'parent', 'foo'], ['(', 10], ['EOF', 11]]},
  {in => q{parent:node()}, out => [['error', 7]]},
  {in => q{*:node()}, out => [['error', 1]]},
  {in => q{parent::node()}, out => [['AxisName', 0, 'parent'], ['::', 6], ['NodeType', 8, 'node'], ['(', 12], [')', 13], ['EOF', 14]]},
  {in => q{comment()}, out => [['NodeType', 0, 'comment'], ['(', 7], [')', 8], ['EOF', 9]]},
  {in => q{processing-instruction()}, out => [['NodeType', 0, 'processing-instruction'], ['(', 22], [')', 23], ['EOF', 24]]},
  {in => q{text()}, out => [['NodeType', 0, 'text'], ['(', 4], [')', 5], ['EOF', 6]]},
  {in => q{namespace()}, out => [['FunctionName', 0, undef, 'namespace'], ['(', 9], [')', 10], ['EOF', 11]]},
  {in => q{a:comment()}, out => [['error', 2]]},
  {in => q{@text()}, out => [['@', 0], ['NodeType', 1, 'text'], ['(', 5], [')', 6], ['EOF', 7]]},
) {
  test {
    my $c = shift;
    my $parser = Web::XPath::Parser->new;
    eq_or_diff $parser->tokenize ($test->{in}), $test->{out};
    done $c;
  } n => 1, name => ['tokenize', $test->{in}];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
