use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Web::XPath::Parser;

for my $test (
  {in => '', out => [['EOF']]},
  {in => 'a', out => [['NameTest', undef, undef, 'a'], ['EOF']]},
  {in => 'hoge', out => [['NameTest', undef, undef, 'hoge'], ['EOF']]},
  {in => 'hoge ', out => [['NameTest', undef, undef, 'hoge'], ['EOF']]},
  {in => "\x{5E00}", out => [['NameTest', undef, undef, "\x{5E00}"], ['EOF']]},
  {in => "12\x{5E00}", out => [['Number', undef, '12'], ['NameTest', undef, undef, "\x{5E00}"], ['EOF']]},
  {in => "\x09\x0A[]\x0D \@", out => [['['], [']'], ['@'], ['EOF']]},
  {in => '()...,::', out => [['('], [')'], ['..'], ['.'], [','], ['::'], ['EOF']]},
  {in => '""', out => [['Literal', undef, ''], ['EOF']]},
  {in => '"ab x"', out => [['Literal', undef, 'ab x'], ['EOF']]},
  {in => q{"ab' x"}, out => [['Literal', undef, q{ab' x}], ['EOF']]},
  {in => q{''}, out => [['Literal', undef, q{}], ['EOF']]},
  {in => q{'ab" x'}, out => [['Literal', undef, q{ab" x}], ['EOF']]},
  {in => q{000}, out => [['Number', undef, q{000}], ['EOF']]},
  {in => q{00.120}, out => [['Number', undef, q{00.120}], ['EOF']]},
  {in => q{125129.}, out => [['Number', undef, q{125129.}], ['EOF']]},
  {in => q{.000135533393310}, out => [['Number', undef, q{.000135533393310}], ['EOF']]},
  {in => q{.000.424}, out => [['Number', undef, q{.000}], ['Number', undef, q{.424}], ['EOF']]},
  {in => q{+12}, out => [['Operator', undef, '+'], ['Number', undef, q{12}], ['EOF']]},
  {in => q{--12}, out => [['Operator', undef, '-'], ['Operator', undef, '-'], ['Number', undef, q{12}], ['EOF']]},
  {in => q{///|+-=!=<<=>>=}, out => [['Operator', undef, '//'], ['Operator', undef, q{/}], ['Operator', undef, '|'], ['Operator', undef, '+'], ['Operator', undef, '-'], ['Operator', undef, '='], ['Operator', undef, '!='], ['Operator', undef, '<'], ['Operator', undef, '<='], ['Operator', undef, '>'], ['Operator', undef, '>='], ['EOF']]},
  {in => q{*}, out => [['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{  *}, out => [['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{@*}, out => [['@'], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{::*}, out => [['::'], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{( *}, out => [['('], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{[  *}, out => [['['], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{/*}, out => [['Operator', undef, '/'], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{]*}, out => [[']'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{mod*}, out => [['NameTest', undef, undef, 'mod'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{div*}, out => [['NameTest', undef, undef, 'div'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{and*}, out => [['NameTest', undef, undef, 'and'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{or*}, out => [['NameTest', undef, undef, 'or'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{ho*}, out => [['NameTest', undef, undef, 'ho'], ['Operator', undef, '*'], ['EOF']]},
  {in => q{@ho}, out => [['@'], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{::ho}, out => [['::'], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{(ho}, out => [['('], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{[ho}, out => [['['], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{+ho}, out => [['Operator', undef, '+'], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{>=ho}, out => [['Operator', undef, '>='], ['NameTest', undef, undef, 'ho'], ['EOF']]},
  {in => q{[and}, out => [['['], ['NameTest', undef, undef, 'and'], ['EOF']]},
  {in => q{[or }, out => [['['], ['NameTest', undef, undef, 'or'], ['EOF']]},
  {in => q{[div}, out => [['['], ['NameTest', undef, undef, 'div'], ['EOF']]},
  {in => q{[mod}, out => [['['], ['NameTest', undef, undef, 'mod'], ['EOF']]},
  {in => q{[mod:foo}, out => [['['], ['NameTest', undef, 'mod', 'foo'], ['EOF']]},
  {in => q{)mod:}, out => [['error', 4]]},
  {in => q{)mod:foo}, out => [['error', 4]]},
  {in => q{hoge:}, out => [['error', 0]]},
  {in => q{mod:*}, out => [['NameTest', undef, 'mod', undef], ['EOF']]},
  {in => q{mod:X}, out => [['NameTest', undef, 'mod', 'X'], ['EOF']]},
  {in => q{mod : X}, out => [['error', 4]]},
  {in => q{mod : *}, out => [['error', 4]]},
  {in => q{mod: *}, out => [['error', 3]]},
  {in => q{*:X}, out => [['error', 1]]},
  {in => q{**}, out => [['NameTest', undef, undef, undef], ['Operator', undef, '*'], ['EOF']]},
  {in => q{***}, out => [['NameTest', undef, undef, undef], ['Operator', undef, '*'], ['NameTest', undef, undef, undef], ['EOF']]},
  {in => q{foo:bar:baz}, out => [['error', 7]]},
  {in => q{:bar:baz}, out => [['error', 0]]},
  {in => q{foobar()}, out => [['FunctionName', undef, undef, 'foobar'], ['('], [')'], ['EOF']]},
  {in => q{foo:bar()}, out => [['FunctionName', undef, 'foo', 'bar'], ['('], [')'], ['EOF']]},
  {in => q{foo:*()}, out => [['NameTest', undef, 'foo', undef], ['('], [')'], ['EOF']]},
  {in => q{*()}, out => [['NameTest', undef, undef, undef], ['('], [')'], ['EOF']]},
  {in => q{*:bar()}, out => [['error', 1]]},
  {in => q{$*}, out => [['error', 0]]},
  {in => q{$*:bar}, out => [['error', 0]]},
  {in => q{$bar:*}, out => [['error', 0]]},
  {in => q{$foo}, out => [['VariableReference', undef, undef, 'foo'], ['EOF']]},
  {in => q{$foo }, out => [['VariableReference', undef, undef, 'foo'], ['EOF']]},
  {in => q{$foo:bar}, out => [['VariableReference', undef, 'foo', 'bar'], ['EOF']]},
  {in => q{$foo()}, out => [['error', 0]]},
  {in => q{$foo:*()}, out => [['error', 0]]},
  {in => q{$foo:bar()}, out => [['error', 0]]},
  {in => q{$ foo()}, out => [['error', 0]]},
  {in => q{foo ()}, out => [['FunctionName', undef, undef, 'foo'], ['('], [')'], ['EOF']]},
  {in => q{hoge::}, out => [['error', 0]]},
  {in => q{parent::}, out => [['AxisName', undef, 'parent'], ['::'], ['EOF']]},
  {in => q{$parent::}, out => [['error', 0]]},
  {in => q{parent:foo::}, out => [['error', 7]]},
  {in => q{parent:foo(}, out => [['FunctionName', undef, 'parent', 'foo'], ['('], ['EOF']]},
  {in => q{parent:node()}, out => [['error', 7]]},
  {in => q{*:node()}, out => [['error', 1]]},
  {in => q{parent::node()}, out => [['AxisName', undef, 'parent'], ['::'], ['NodeType', undef, 'node'], ['('], [')'], ['EOF']]},
  {in => q{comment()}, out => [['NodeType', undef, 'comment'], ['('], [')'], ['EOF']]},
  {in => q{processing-instruction()}, out => [['NodeType', undef, 'processing-instruction'], ['('], [')'], ['EOF']]},
  {in => q{text()}, out => [['NodeType', undef, 'text'], ['('], [')'], ['EOF']]},
  {in => q{namespace()}, out => [['FunctionName', undef, undef, 'namespace'], ['('], [')'], ['EOF']]},
  {in => q{a:comment()}, out => [['error', 2]]},
  {in => q{@text()}, out => [['@'], ['NodeType', undef, 'text'], ['('], [')'], ['EOF']]},
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
