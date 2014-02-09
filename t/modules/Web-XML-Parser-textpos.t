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

for my $test (
  [q<<p>abc</p>> => [[0, 3, 1,4]]],
  [q<<p>abc&amp;</p>> => [[0, 3, 1,4], [3, 1, 1,7]]],
  [q<<p>abc&amp;x</p>> => [[0, 3, 1,4], # 'a'
                           [3, 1, 1,7],
                           [4, 1, 1,12]]], # 'x'
  [qq<<p>ab\x0Ac</p>> => [[0, 2, 1,4],
                          [2, 2, 2,0]]],
  [qq<<p>ab\x0Ac&apos;y</p>> => [[0, 2, 1,4],
                                 [2, 2, 2,0],
                                 [4, 1, 2, 2],
                                 [5, 1, 2,8]]],
  [q<<p>ab</x>c</p>> => [[0, 2, 1,4],
                         [2, 1, 1,10]]],
  [q<<p>ab<![CDATA[cd]]>e</p>> => [[0, 2, 1,4],
                                   [2, 2, 1,15],
                                   [4, 1, 1,20]]],
  [q<<p>ab<![CDATA[]]>e</p>> => [[0, 2, 1,4],
                                 [2, 1, 1,18]]],
  [qq<<p>abc\x0Aabc\x0Aabc</p>> => [[0, 3, 1,4], [3, 4, 2,0], [7, 4, 3,0]]],
  [q{<!DOCTYPE a[<!ENTITY b "d">]><p>a&b;c</p>}
       => [[0, 1, 1,33],
           [1, 1, 1,25, 0],
           [2, 1, 1,37]]],
  [q{<!DOCTYPE a[<!ENTITY b "d&#x32;e">]><p>a&b;c</p>}
       => [[0, 1, 1,40], # a
           [1, 1, 1,25, 0], # d
           [2, 1, 1,26, 0], # 2
           [3, 1, 1,32, 0], # e
           [4, 1, 1,44]]], # c
  [q{<!DOCTYPE a[<!ENTITY b "&#123;d&#x32;e">]><p>a&b;c</p>}
       => [[0, 1, 1,46], # a
           [1, 1, 1,25, 0], # &#123;
           [2, 1, 1,31, 0], # d
           [3, 1, 1,32, 0], # 2
           [4, 1, 1,38, 0], # e
           [5, 1, 1,50]]], # c
  [q{<!DOCTYPE a[<!ENTITY e "f"><!ENTITY b "d&e;g">]><p>a&b;c</p>}
       => [[0, 1, 1,52], # a
           [1, 1, 1,40, 0], # d
           [2, 1, 1,25, 0], # f
           [3, 1, 1,44, 0], # g
           [4, 1, 1, 56]]], # c
  [q{<!DOCTYPE a[<!ENTITY e "f"><!ENTITY h "i&e;j"><!ENTITY b "d&h;g">]><p>a&b;c</p>}
       => [[0, 1, 1,71], # a
           [1, 1, 1,59, 0], # d
           [2, 1, 1,40, 0], # i
           [3, 1, 1,25, 0], # f
           [4, 1, 1,44, 0], # j
           [5, 1, 1,63, 0], # g
           [6, 1, 1,75]]], # c
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    Web::XML::Parser->new->parse_char_string ($test->[0] => $doc);

    my $text = $doc->document_element->first_child;
    my $pos = $text->get_user_data ('manakai_sp');

    eq_or_diff $pos, $test->[1];

    done $c;
  } n => 1, name => 'a text node';
}

for my $test (
  [q{<!DOCTYPE a><a><b>c</b></a>} => [[0, 1, 1, 19]]],
  [q{<!DOCTYPE a[<!ENTITY d "e">]><a><b>c&d;f</b></a>}
       => [[0, 1, 1, 36],
           [1, 1, 1, 25, 0],
           [2, 1, 1, 40]]],
  [q{<!DOCTYPE a[<!ENTITY d "<b>g</b>h">]><a>&d;e</a>}
       => [[0, 1, 1, 28, 0]]],
  [q{<!DOCTYPE a[<!ENTITY d "<b>g&i;k</b>h"><!ENTITY i "j">]><a>&d;e</a>}
       => [[0, 1, 1, 28, 0],
           [1, 1, 1, 52, 0],
           [2, 1, 1, 32, 0]]],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    Web::XML::Parser->new->parse_char_string ($test->[0] => $doc);

    my $text = $doc->document_element->first_child->first_child;
    my $pos = $text->get_user_data ('manakai_sp');

    eq_or_diff $pos, $test->[1];

    done $c;
  } n => 1, name => 'a text node';
}

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
