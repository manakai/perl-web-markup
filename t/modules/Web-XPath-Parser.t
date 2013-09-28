use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Web::XPath::Parser;

for my $test (
  {in => '', out => [['EOF']]},
  {in => 'a', out => [['NameTest', undef, 'a'], ['EOF']]},
  {in => 'hoge', out => [['NameTest', undef, 'hoge'], ['EOF']]},
  {in => 'hoge ', out => [['NameTest', undef, 'hoge'], ['EOF']]},
  {in => "\x{5E00}", out => [['NameTest', undef, "\x{5E00}"], ['EOF']]},
  {in => "12\x{5E00}", out => [['Number', '12'], ['NameTest', undef, "\x{5E00}"], ['EOF']]},
  {in => "\x09\x0A[]\x0D \@", out => [['['], [']'], ['@'], ['EOF']]},
  {in => '()...,::', out => [['('], [')'], ['..'], ['.'], [','], ['::'], ['EOF']]},
  {in => '""', out => [['Literal', ''], ['EOF']]},
  {in => '"ab x"', out => [['Literal', 'ab x'], ['EOF']]},
  {in => q{"ab' x"}, out => [['Literal', q{ab' x}], ['EOF']]},
  {in => q{''}, out => [['Literal', q{}], ['EOF']]},
  {in => q{'ab" x'}, out => [['Literal', q{ab" x}], ['EOF']]},
  {in => q{000}, out => [['Number', q{000}], ['EOF']]},
  {in => q{00.120}, out => [['Number', q{00.120}], ['EOF']]},
  {in => q{125129.}, out => [['Number', q{125129.}], ['EOF']]},
  {in => q{.000135533393310}, out => [['Number', q{.000135533393310}], ['EOF']]},
  {in => q{.000.424}, out => [['Number', q{.000}], ['Number', q{.424}], ['EOF']]},
  {in => q{+12}, out => [['Operator', '+'], ['Number', q{12}], ['EOF']]},
  {in => q{--12}, out => [['Operator', '-'], ['Operator', '-'], ['Number', q{12}], ['EOF']]},
  {in => q{///|+-=!=<<=>>=}, out => [['Operator', '//'], ['Operator', q{/}], ['Operator', '|'], ['Operator', '+'], ['Operator', '-'], ['Operator', '='], ['Operator', '!='], ['Operator', '<'], ['Operator', '<='], ['Operator', '>'], ['Operator', '>='], ['EOF']]},
  {in => q{*}, out => [['NameTest', undef, undef], ['EOF']]},
  {in => q{  *}, out => [['NameTest', undef, undef], ['EOF']]},
  {in => q{@*}, out => [['@'], ['NameTest', undef, undef], ['EOF']]},
  {in => q{::*}, out => [['::'], ['NameTest', undef, undef], ['EOF']]},
  {in => q{( *}, out => [['('], ['NameTest', undef, undef], ['EOF']]},
  {in => q{[  *}, out => [['['], ['NameTest', undef, undef], ['EOF']]},
  {in => q{/*}, out => [['Operator', '/'], ['NameTest', undef, undef], ['EOF']]},
  {in => q{]*}, out => [[']'], ['Operator', '*'], ['EOF']]},
  {in => q{mod*}, out => [['NameTest', undef, 'mod'], ['Operator', '*'], ['EOF']]},
  {in => q{div*}, out => [['NameTest', undef, 'div'], ['Operator', '*'], ['EOF']]},
  {in => q{and*}, out => [['NameTest', undef, 'and'], ['Operator', '*'], ['EOF']]},
  {in => q{or*}, out => [['NameTest', undef, 'or'], ['Operator', '*'], ['EOF']]},
  {in => q{ho*}, out => [['NameTest', undef, 'ho'], ['Operator', '*'], ['EOF']]},
  {in => q{@ho}, out => [['@'], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{::ho}, out => [['::'], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{(ho}, out => [['('], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{[ho}, out => [['['], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{+ho}, out => [['Operator', '+'], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{>=ho}, out => [['Operator', '>='], ['NameTest', undef, 'ho'], ['EOF']]},
  {in => q{[and}, out => [['['], ['NameTest', undef, 'and'], ['EOF']]},
  {in => q{[or }, out => [['['], ['NameTest', undef, 'or'], ['EOF']]},
  {in => q{[div}, out => [['['], ['NameTest', undef, 'div'], ['EOF']]},
  {in => q{[mod}, out => [['['], ['NameTest', undef, 'mod'], ['EOF']]},
  {in => q{[mod:foo}, out => [['['], ['NameTest', 'mod', 'foo'], ['EOF']]},
  {in => q{)mod:}, out => [['error', 4]]},
  {in => q{)mod:foo}, out => [['error', 4]]},
  {in => q{hoge:}, out => [['error', 0]]},
  {in => q{mod:*}, out => [['NameTest', 'mod', undef], ['EOF']]},
  {in => q{mod:X}, out => [['NameTest', 'mod', 'X'], ['EOF']]},
  {in => q{mod : X}, out => [['error', 4]]},
  {in => q{mod : *}, out => [['error', 4]]},
  {in => q{mod: *}, out => [['error', 3]]},
  {in => q{*:X}, out => [['error', 1]]},
  {in => q{**}, out => [['NameTest', undef, undef], ['Operator', '*'], ['EOF']]},
  {in => q{***}, out => [['NameTest', undef, undef], ['Operator', '*'], ['NameTest', undef, undef], ['EOF']]},
  {in => q{foo:bar:baz}, out => [['error', 7]]},
  {in => q{:bar:baz}, out => [['error', 0]]},
  {in => q{foobar()}, out => [['FunctionName', undef, 'foobar'], ['('], [')'], ['EOF']]},
  {in => q{foo:bar()}, out => [['FunctionName', 'foo', 'bar'], ['('], [')'], ['EOF']]},
  {in => q{foo:*()}, out => [['NameTest', 'foo', undef], ['('], [')'], ['EOF']]},
  {in => q{*()}, out => [['NameTest', undef, undef], ['('], [')'], ['EOF']]},
  {in => q{*:bar()}, out => [['error', 1]]},
  {in => q{$*}, out => [['error', 0]]},
  {in => q{$*:bar}, out => [['error', 0]]},
  {in => q{$bar:*}, out => [['error', 0]]},
  {in => q{$foo}, out => [['VariableReference', undef, 'foo'], ['EOF']]},
  {in => q{$foo }, out => [['VariableReference', undef, 'foo'], ['EOF']]},
  {in => q{$foo:bar}, out => [['VariableReference', 'foo', 'bar'], ['EOF']]},
  {in => q{$foo()}, out => [['error', 0]]},
  {in => q{$foo:*()}, out => [['error', 0]]},
  {in => q{$foo:bar()}, out => [['error', 0]]},
  {in => q{$ foo()}, out => [['error', 0]]},
  {in => q{foo ()}, out => [['FunctionName', undef, 'foo'], ['('], [')'], ['EOF']]},
  {in => q{hoge::}, out => [['error', 0]]},
  {in => q{parent::}, out => [['AxisName', 'parent'], ['::'], ['EOF']]},
  {in => q{$parent::}, out => [['error', 0]]},
  {in => q{parent:foo::}, out => [['error', 7]]},
  {in => q{parent:foo(}, out => [['FunctionName', 'parent', 'foo'], ['('], ['EOF']]},
  {in => q{parent:node()}, out => [['error', 7]]},
  {in => q{*:node()}, out => [['error', 1]]},
  {in => q{parent::node()}, out => [['AxisName', 'parent'], ['::'], ['NodeType', 'node'], ['('], [')'], ['EOF']]},
  {in => q{comment()}, out => [['NodeType', 'comment'], ['('], [')'], ['EOF']]},
  {in => q{processing-instruction()}, out => [['NodeType', 'processing-instruction'], ['('], [')'], ['EOF']]},
  {in => q{text()}, out => [['NodeType', 'text'], ['('], [')'], ['EOF']]},
  {in => q{namespace()}, out => [['FunctionName', undef, 'namespace'], ['('], [')'], ['EOF']]},
  {in => q{a:comment()}, out => [['error', 2]]},
  {in => q{@text()}, out => [['@'], ['NodeType', 'text'], ['('], [')'], ['EOF']]},
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
