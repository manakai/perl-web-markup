use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Test::XPathParser;
use Web::XPath::Parser;

sub funclib ($) {
  my $checker = shift;
  my $rand = int rand 1000000;
  no strict 'refs';
  *{"test::temp::package_${rand}::get_argument_number"} = sub {
    shift;
    return $checker->(@_);
  };
  $INC{"test/temp/package_${rand}.pm"} = 1;
  return "test::temp::package_${rand}";
} # funclib

sub vars ($) {
  my $checker = shift;
  my $rand = int rand 1000000;
  no strict 'refs';
  *{"test::temp::package_${rand}::has_variable"} = sub {
    shift;
    return $checker->(@_);
  };
  $INC{"test/temp/package_${rand}.pm"} = 1;
  return "test::temp::package_${rand}";
} # vars

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
  #{in => q{foo:*()}, out => [['NameTest', 0, 'foo', undef], ['(', 5], [')', 6], ['EOF', 7]]},
  {in => q{foo:*()}, out => [['error', 5]]},
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

for my $test (
  [' / ' => X LP [ROOT]],
  ['hoge' => X LP [S 'child', undef, undef, 'hoge', []]],
  ['/ hoge' => X LP [ROOT, S 'child', undef, undef, 'hoge', []]],
  ['hoge/fuga' => X LP [(S 'child', undef, undef, 'hoge', []),
                        (S 'child', undef, undef, 'fuga', [])]],
  ['child::hoge' => X LP [S 'child', undef, undef, 'hoge', []]],
  ['parent::hoge' => X LP [S 'parent', undef, undef, 'hoge', []]],
  ['self::*' => X LP [S 'self', undef, undef, undef, []]],
  ['ancestor-or-self::f-a'
       => X LP [S 'ancestor-or-self', undef, undef, 'f-a', []]],
  ['descendant-or-self::f-a'
       => X LP [S 'descendant-or-self', undef, undef, 'f-a', []]],
  ['@*' => X LP [S 'attribute', undef, undef, undef, []]],
  ['@abc' => X LP [S 'attribute', undef, undef, 'abc', []]],
  ['parent ::  hoge' => X LP [S 'parent', undef, undef, 'hoge', []]],
  ['following  ::  * ' => X LP [S 'following', undef, undef, undef, []]],
  ['   * ' => X LP [S 'child', undef, undef, undef, []]],
  ['   *//* ' => X LP [(S 'child', undef, undef, undef, []),
                       (Sf 'descendant-or-self', 'node', undef, []),
                       (S 'child', undef, undef, undef, [])]],
  [' // ' => X LP [ROOT, (Sf 'descendant-or-self', 'node', undef, [])]],
  [' //da- ' => X LP [ROOT,
                      (Sf 'descendant-or-self', 'node', undef, []),
                      (S 'child', undef, undef, 'da-', [])]],
  [' //da//y/z ' => X LP [ROOT,
                          (Sf 'descendant-or-self', 'node', undef, []),
                          (S 'child', undef, undef, 'da', []),
                          (Sf 'descendant-or-self', 'node', undef, []),
                          (S 'child', undef, undef, 'y', []),
                          (S 'child', undef, undef, 'z', [])]],
  [' v//da//y/z ' => X LP [(S 'child', undef, undef, 'v', []),
                          (Sf 'descendant-or-self', 'node', undef, []),
                          (S 'child', undef, undef, 'da', []),
                          (Sf 'descendant-or-self', 'node', undef, []),
                          (S 'child', undef, undef, 'y', []),
                          (S 'child', undef, undef, 'z', [])]],
  ['following-sibling::  hoge'
       => X LP [S 'following-sibling', undef, undef, 'hoge', []]],
  ['preceding::  hoge' => X LP [S 'preceding', undef, undef, 'hoge', []]],
  ['preceding-sibling::  hoge'
       => X LP [S 'preceding-sibling', undef, undef, 'hoge', []]],
  ['node()' => X LP [Sf 'child', 'node', undef, []]],
  ['parent::node()' => X LP [Sf 'parent', 'node', undef, []]],
  ['node  ( ) ' => X LP [Sf 'child', 'node', undef, []]],
  ['processing-instruction()'
       => X LP [Sf 'child', 'processing-instruction', undef, []]],
  ['comment()' => X LP [Sf 'child', 'comment', undef, []]],
  ['text()' => X LP [Sf 'child', 'text', undef, []]],
  [qq{processing-instruction( "'abc\x{5012}\x{DE00}'" )}
       => X LP [Sf 'child', 'processing-instruction', qq{'abc\x{5012}\x{DE00}'}, []]],
  ['node()[1]' => X LP [Sf 'child', 'node', undef, [X LP [NUM 1, []]]]],
  ['node[/]' => X LP [S 'child', undef, undef, 'node', [X LP [ROOT]]]],
  ['node[/][ab]' => X LP [S 'child', undef, undef, 'node',
                          [(X LP [ROOT]),
                           (X LP [S 'child', undef, undef, 'ab', []])]]],
  ['*[/]' => X LP [S 'child', undef, undef, undef, [X LP [ROOT]]]],
  ['@aa[/]' => X LP [S 'attribute', undef, undef, 'aa', [X LP [ROOT]]]],
  ['$ab' => X LP [VAR undef, undef, 'ab', []]],
  ['$ab/a' => X LP [(VAR undef, undef, 'ab', []),
                    (S 'child', undef, undef, 'a', [])]],
  ['$ab[dw]' => X LP [VAR undef, undef, 'ab',
                      [X LP [S 'child', undef, undef, 'dw', []]]]],
  ['(ab/c)' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                            (S 'child', undef, undef, 'c', [])])]],
  ['(ab/c)/d' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                              (S 'child', undef, undef, 'c', [])]),
                       (S 'child', undef, undef, 'd', [])]],
  ['(ab/c)[x-]' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                                (S 'child', undef, undef, 'c', [])],
                          [X LP [S 'child', undef, undef, 'x-', []]])]],
  ['(ab/c)[x-]/a' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                                  (S 'child', undef, undef, 'c', [])],
                            [X LP [S 'child', undef, undef, 'x-', []]]),
                           (S 'child', undef, undef, 'a', [])]],
  ['(ab/c)//a' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                               (S 'child', undef, undef, 'c', [])],
                         []),
                        (Sf 'descendant-or-self', 'node', undef, []),
                        (S 'child', undef, undef, 'a', [])]],
  ['(ab/c)[x-]//a' => X LP [(X LP [(S 'child', undef, undef, 'ab', []),
                                   (S 'child', undef, undef, 'c', [])],
                             [X LP [S 'child', undef, undef, 'x-', []]]),
                            (Sf 'descendant-or-self', 'node', undef, []),
                            (S 'child', undef, undef, 'a', [])]],
  [q{'$ab'} => X LP [STR q{$ab}, []]],
  [q{'$ab'[xy]} => X LP [STR q{$ab},
                         [X LP [S 'child', undef, undef, 'xy', []]]]],
  [q{12.41} => X LP [NUM 12.41, []]],
  [q{521.120[xy]} => X LP [NUM 521.12,
                         [X LP [S 'child', undef, undef, 'xy', []]]]],
  [q{.120[xy]} => X LP [NUM .12,
                        [X LP [S 'child', undef, undef, 'xy', []]]]],
  [q{ha()} => X LP [F undef, undef, 'ha', [], []]],
  [q{element()} => X LP [F undef, undef, 'element', [], []]],
  [q{attribute()} => X LP [F undef, undef, 'attribute', [], []]],
  [q{ha()[ga]} => X LP [F undef, undef, 'ha', [],
                        [X LP [S 'child', undef, undef, 'ga', []]]]],
  [q{ha()[ga][z]} => X LP [F undef, undef, 'ha', [],
                           [(X LP [S 'child', undef, undef, 'ga', []]),
                            (X LP [S 'child', undef, undef, 'z', []])]]],
  [q{ha(12.4)} => X LP [F undef, undef, 'ha',
                        [(X LP [NUM 12.4, []])], []]],
  [q{ha(12.4,ax)} => X LP [F undef, undef, 'ha',
                           [(X LP [NUM 12.4, []]),
                            (X LP [S 'child', undef, undef, 'ax', []])], []]],
  [q{ha(12.4,ax , ("x"))} => X LP [F undef, undef, 'ha',
                                   [(X LP [NUM 12.4, []]),
                                    (X LP [S 'child', undef, undef, 'ax', []]),
                                    (X LP [X LP [STR 'x', []]])], []]],
  [q{ha(12.4,ax , (("x")))}
       => X LP [F undef, undef, 'ha',
                [(X LP [NUM 12.4, []]),
                 (X LP [S 'child', undef, undef, 'ax', []]),
                 (X LP [X LP [X LP [STR 'x', []]]])], []]],
  [q{ha(12.4)[q]} => X LP [F undef, undef, 'ha',
                           [(X LP [NUM 12.4, []])],
                           [(X LP [S 'child', undef, undef, 'q', []])]]],
  ['ab | cd ' => X OP '|', (LP [S 'child', undef, undef, 'ab', []]),
                           (LP [S 'child', undef, undef, 'cd', []])],
  ['ab | (-cd)' => X OP '|', (LP [S 'child', undef, undef, 'ab', []]),
                             (LP [X NEG LP [S 'child', undef, undef, 'cd', []]])],
  ['-ab | (-cd)' => X NEG OP '|',
       (LP [S 'child', undef, undef, 'ab', []]),
       (LP [X NEG LP [S 'child', undef, undef, 'cd', []]])],
  ['-(ab | cd)' => X NEG LP [X OP '|',
       (LP [S 'child', undef, undef, 'ab', []]),
       (LP [S 'child', undef, undef, 'cd', []])]],
  ['a or b or c' => X OP 'or',
       (OP 'or', (LP [S 'child', undef, undef, 'a', []]),
                 (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a and b or c' => X OP 'or',
       (OP 'and', (LP [S 'child', undef, undef, 'a', []]),
                  (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a or b and c' => X OP 'or',
       (LP [S 'child', undef, undef, 'a', []]),
       (OP 'and', (LP [S 'child', undef, undef, 'b', []]),
                  (LP [S 'child', undef, undef, 'c', []]))],
  ['a and b and c' => X OP 'and',
       (OP 'and', (LP [S 'child', undef, undef, 'a', []]),
                  (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a =b!=c' => X OP '!=',
       (OP '=', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a !=b!=c' => X OP '!=',
       (OP '!=', (LP [S 'child', undef, undef, 'a', []]),
                 (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a<b != c' => X OP '!=',
       (OP '<', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a<b <= c' => X OP '<=',
       (OP '<', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a>b >= c' => X OP '>=',
       (OP '>', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a + b + c' => X OP '+',
       (OP '+', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a - b + c' => X OP '+',
       (OP '-', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a * b div c' => X OP 'div',
       (OP '*', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a div b mod c' => X OP 'mod',
       (OP 'div', (LP [S 'child', undef, undef, 'a', []]),
                  (LP [S 'child', undef, undef, 'b', []])),
       (LP [S 'child', undef, undef, 'c', []])],
  ['a + b + c * y' => X OP '+',
       (OP '+', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (OP '*', (LP [S 'child', undef, undef, 'c', []]),
                (LP [S 'child', undef, undef, 'y', []]))],
  ['a = b + c * y' => X OP '=',
       (LP [S 'child', undef, undef, 'a', []]),
       (OP '+', (LP [S 'child', undef, undef, 'b', []]),
                (OP '*', (LP [S 'child', undef, undef, 'c', []]),
                         (LP [S 'child', undef, undef, 'y', []])))],
  ['a = b +- c * y' => X OP '=',
       (LP [S 'child', undef, undef, 'a', []]),
       (OP '+', (LP [S 'child', undef, undef, 'b', []]),
                (OP '*', (NEG LP [S 'child', undef, undef, 'c', []]),
                         (LP [S 'child', undef, undef, 'y', []])))],
  ['-a = b +- c * y' => X OP '=',
       (NEG LP [S 'child', undef, undef, 'a', []]),
       (OP '+', (LP [S 'child', undef, undef, 'b', []]),
                (OP '*', (NEG LP [S 'child', undef, undef, 'c', []]),
                         (LP [S 'child', undef, undef, 'y', []])))],
  ['---a = b +- c * y' => X OP '=',
       (NEG NEG NEG LP [S 'child', undef, undef, 'a', []]),
       (OP '+', (LP [S 'child', undef, undef, 'b', []]),
                (OP '*', (NEG LP [S 'child', undef, undef, 'c', []]),
                         (LP [S 'child', undef, undef, 'y', []])))],
  ['---a = b +- c * / y' => X OP '=',
       (NEG NEG NEG LP [S 'child', undef, undef, 'a', []]),
       (OP '+', (LP [S 'child', undef, undef, 'b', []]),
                (OP '*', (NEG LP [S 'child', undef, undef, 'c', []]),
                         (LP [ROOT, S 'child', undef, undef, 'y', []])))],
  ['*****' => X OP '*',
       (OP '*', (LP [S 'child', undef, undef, undef, []]),
                (LP [S 'child', undef, undef, undef, []])),
       (LP [S 'child', undef, undef, undef, []])],
  ['div div mod' => X OP 'div',
       (LP [S 'child', undef, undef, 'div', []]),
       (LP [S 'child', undef, undef, 'mod', []])],
  ['a | b + c * y' => X OP '+',
       (OP '|', (LP [S 'child', undef, undef, 'a', []]),
                (LP [S 'child', undef, undef, 'b', []])),
       (OP '*', (LP [S 'child', undef, undef, 'c', []]),
                (LP [S 'child', undef, undef, 'y', []]))],
  ['(/) and 0' => X OP 'and',
       (LP [X LP [ROOT]]),
       (LP [NUM 0, []])],
) {
  test {
    my $c = shift;
    my $parser = Web::XPath::Parser->new;
    my @error;
    $parser->onerror (sub {
      push @error, {@_};
    });
    $parser->function_library (funclib sub { [0, 0+'inf'] });
    $parser->variable_bindings (vars sub { 1 });
    my $result = $parser->parse_char_string_as_expression ($test->[0]);
    eq_or_diff $result, $test->[1];
    eq_or_diff \@error, [];
    done $c;
  } n => 2, name => ['parse_char_string_as_expression', $test->[0]];
}

for my $test (
  ['hoge:fuga', {hoge => 'ab c'} => X LP [S 'child', 'hoge', 'ab c', 'fuga', []]],
  ['hoge:fuga/ab:*', {hoge => 'ab c', ab => 'AB'}
       => X LP [(S 'child', 'hoge', 'ab c', 'fuga', []),
                (S 'child', 'ab', 'AB', undef, [])]],
  ['hoge:fuga/hoge:*', {hoge => 'ab c', ab => 'AB'}
       => X LP [(S 'child', 'hoge', 'ab c', 'fuga', []),
                (S 'child', 'hoge', 'ab c', undef, [])]],
  ['hoge:fuga/hoge:*', {hoge => ''}
       => X LP [(S 'child', 'hoge', '', 'fuga', []),
                (S 'child', 'hoge', '', undef, [])]],
  ['$hoge:fuga', {hoge => 'ab c'} => X LP [VAR 'hoge', 'ab c', 'fuga', []]],
  ['hoge:fuga()', {hoge => 'ab c'} => X LP [F 'hoge', 'ab c', 'fuga', [], []]],
  ['hoge:fuga(a)', {hoge => 'ab c'}
       => X LP [F 'hoge', 'ab c', 'fuga',
                [X LP [S 'child', undef, undef, 'a', []]], []]],
) {
  test {
    my $c = shift;
    my $parser = Web::XPath::Parser->new;
    my @error;
    $parser->onerror (sub {
      push @error, {@_};
    });
    $parser->ns_resolver (sub { return $test->[1]->{$_[0]} });
    $parser->function_library (funclib sub { [0, 0+'inf'] });
    $parser->variable_bindings (vars sub { 1 });
    my $result = $parser->parse_char_string_as_expression ($test->[0]);
    eq_or_diff $result, $test->[2];
    eq_or_diff \@error, [];
    done $c;
  } n => 2, name => ['parse_char_string_as_expression', $test->[0]];
}

for my $test (
  ['', 0],
  ["\x09\x0A ", 3],
  ['!-', 0],
  ['hoge =?', 6],
  ['ab <> "cde', 6],
  ['hogexfuga/', 10],
  ['hogeyfuga//', 11],
  ['hoge/fuga/', 10],
  ['hoge/fuga//', 11],
  ['hoge fuga', 5],
  ['hoge 12', 5],
  ['hoge / /', 7],
  ['hoge / //', 7],
  ['///', 3],
  ['////', 4],
  ['/[12]', 1],
  ['//[12]', 2],
  ['abc::def', 0],
  ['child::abc::def', 7],
  ['SELF::def', 0],
  ['@::def', 1],
  ['::def', 0],
  [' parent:: ', 10],
  [' descendant::def : xy', 17],
  [' parent: :foo ', 7],
  [' parent::-foo ', 9],
  [' parent::foo:ab:cd', 15],
  ['par:ent::foo:ab:cd', 4],
  ['text("ab")', 5],
  ['comment("ab")', 8],
  ['node("ab")', 5],
  ['node("ab",)', 5],
  ['node(,)', 5],
  ['processing-instruction("ab",)', 27],
  ['processing-instruction("ab","de")', 27],
  ['*:*', 1],
  ['child::*:*', 8],
  ['a[', 2],
  ['a[]', 2],
  ['a[ab', 4],
  ['a[[ab]]', 2],
  ['..[b]', 2],
  ['parent::..', 8],
  ['.[b]', 1],
  ['parent::..', 8],
  ['@..', 1],
  ['@.', 1],
  ['$', 0],
  ['$*', 0],
  ['$ab:*', 0],
  ['$*:*', 0],
  ['ab/(cd | ef)', 3],
  ['1||2', 2],
  ['12.124.1314.5', 6],
  ['ab:*()', 4],
  ['*()', 1],
  ['*:*()', 1],
  ['child::*()', 8],
  ['child::hoge()', 7],
  ['ab(', 3],
  ['ab(,)', 3],
  ['ab("ab",)', 8],
  ['ab("ab",,"c")', 8],
  ['ab("ab",12,"c"))', 15],
  ['ab|', 3],
  ['ab|-x', 3],
  ['ab * div fa', 9],
  ['* yz', 2],
  ['!= yz', 0],
  ['ab <> yz', 4],
  ['ab <> yz:ab', 4],
  ['ab <> $yz:ab', 4],
  ['ab <> yz:ab()', 4],
  ['/ and 0', 6],
  ['/ho/ge/[@aa]', 7],
) {
  test {
    my $c = shift;
    my $parser = Web::XPath::Parser->new;
    my @error;
    $parser->onerror (sub {
      push @error, {@_};
    });
    $parser->function_library (funclib sub { [0, 0+'inf'] });
    $parser->variable_bindings (vars sub { 1 });
    my $result = $parser->parse_char_string_as_expression ($test->[0]);
    is $result, undef;
    eq_or_diff \@error, [{index => $test->[1], type => 'xpath:syntax error',
                          level => 'm'}];
    done $c;
  } n => 2, name => ['parse_char_string_as_expression', $test->[0]];
}

for my $test (
  ['ab:*', {} => 0, 'ab'],
  ['ab:yz', {} => 0, 'ab'],
  ['c:d/ab:yz', {c => 'xy'} => 4, 'ab'],
  ['$ab:yz', {} => 1, 'ab'],
  ['ab:yz()', {} => 0, 'ab'],
  ['ab:yz(12)', {} => 0, 'ab'],
  ['ab:yz(12)/foo:bar', {} => 0, 'ab'],
  ['ab:yz(12', {} => 0, 'ab'],
) {
  test {
    my $c = shift;
    my $parser = Web::XPath::Parser->new;
    my @error;
    $parser->onerror (sub {
      push @error, {@_};
    });
    $parser->ns_resolver (sub { return $test->[1]->{$_[0]} });
    $parser->function_library (funclib sub { [0, 0+'inf'] });
    $parser->variable_bindings (vars sub { 1 });
    my $result = $parser->parse_char_string_as_expression ($test->[0]);
    is $result, undef;
    eq_or_diff \@error,
        [{index => $test->[2], type => 'namespace prefix:not declared',
          level => 'm', value => $test->[3]}];
    done $c;
  } n => 2, name => ['parse_char_string_as_expression', $test->[0]];
}

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  my $result = $parser->parse_char_string_as_expression ('$hoge');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 0, type => 'xpath:variable:unknown',
        level => 'm', value => 'hoge'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'variable unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->ns_resolver (sub { 'abc' });
  my $result = $parser->parse_char_string_as_expression ('$hoge:fuga');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 0, type => 'xpath:variable:unknown',
        level => 'm', value => 'hoge:fuga'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'variable unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->function_library (funclib sub { undef });
  my $result = $parser->parse_char_string_as_expression ('hoge ()');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 0, type => 'xpath:function:unknown',
        level => 'm', value => 'hoge'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'function unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->ns_resolver (sub { 'abc' });
  $parser->function_library (funclib sub { undef });
  my $result = $parser->parse_char_string_as_expression ('hoge:fuga()');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 0, type => 'xpath:function:unknown',
        level => 'm', value => 'hoge:fuga'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'function unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->function_library (funclib sub { [1, 1] });
  my $result = $parser->parse_char_string_as_expression ('hoge ()');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 6, type => 'xpath:function:min', level => 'm'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'function unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->function_library (funclib sub { [2, 3] });
  my $result = $parser->parse_char_string_as_expression ('hoge (12)');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 9, type => 'xpath:function:min', level => 'm'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'function unknown'];

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->function_library (funclib sub { [2, 2] });
  my $result = $parser->parse_char_string_as_expression ('hoge (12, 31, 4)');
  is $result, undef;
  eq_or_diff \@error,
      [{index => 16, type => 'xpath:function:max', level => 'm'}];
  done $c;
} n => 2, name => ['parse_char_string_as_expression', 'function unknown'];

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
