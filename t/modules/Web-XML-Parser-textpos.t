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
    my $pos = $text->get_user_data ('manakai_sps');

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
    my $pos = $text->get_user_data ('manakai_sps');

    eq_or_diff $pos, $test->[1];

    done $c;
  } n => 1, name => 'a text node';
}

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  Web::XML::Parser->new->parse_char_string (q{<!DOCTYPE a[
<!ENTITY b "<e>cd</e>">
]><a>&b;</a>} => $doc);

  my $node = $doc->document_element->first_child;
  is $node->get_user_data ('manakai_source_line'), 2;
  is $node->get_user_data ('manakai_source_column'), 13;
  is $node->get_user_data ('manakai_di'), 0;

  done $c;
} n => 3;

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  Web::XML::Parser->new->parse_char_string (q{<!DOCTYPE a[
<!ENTITY b "<e><f>c</f>d</e>">
]><a>&b;</a>} => $doc);

  my $node = $doc->document_element->first_child->first_element_child;
  is $node->get_user_data ('manakai_source_line'), 2;
  is $node->get_user_data ('manakai_source_column'), 16;
  is $node->get_user_data ('manakai_di'), 0;

  done $c;
} n => 3;

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  Web::XML::Parser->new->parse_char_string (q{<!DOCTYPE a[
<!ENTITY b "<e>
<f>c</f>d</e>">
]><a>&b;</a>} => $doc);

  my $node = $doc->document_element->first_child->first_element_child;
  is $node->local_name, 'f';
  is $node->get_user_data ('manakai_source_line'), 3;
  is $node->get_user_data ('manakai_source_column'), 1;
  is $node->get_user_data ('manakai_di'), 0;

  done $c;
} n => 4;

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  Web::XML::Parser->new->parse_char_string (q{<!DOCTYPE a[
<!ENTITY b "<e>
<f>c</f>d</e>">
<!ENTITY g "&b;">
]><a>&g;</a>} => $doc);

  my $node = $doc->document_element->first_child->first_element_child;
  is $node->get_user_data ('manakai_source_line'), 3;
  is $node->get_user_data ('manakai_source_column'), 1;
  is $node->get_user_data ('manakai_di'), 0;

  done $c;
} n => 3;

for my $test (
  [q{<p hoge></p>} => undef, 1, 4, undef],
  [q{<p hoge=""></p>} => [], 1, 4, undef],
  [q{<p hoge=''></p>} => [], 1, 4, undef],
  [q{<p hoge=abc></p>} => [[0, 1, 1, 9], [1, 2, 1, 10]], 1, 4, undef],
  [q{<p hoge="abc"></p>} => [[0, 3, 1, 10]], 1, 4, undef],
  [q{<p hoge='abc'></p>} => [[0, 3, 1, 10]], 1, 4, undef],
  [q{<p hoge=abc&amp></p>} => [[0, 1, 1, 9], [1, 2, 1, 10], [3, 1, 1, 12]], 1, 4, undef],
  [q{<p hoge=abc&amp;b></p>} => [[0, 1, 1, 9], [1, 2, 1, 10],
                                 [3, 1, 1, 12], [4, 1, 1, 17]], 1, 4, undef],
  [q{<p hoge=abc&ampxy;></p>} => [[0, 1, 1, 9], [1, 2, 1, 10], [3, 7, 1, 12]], 1, 4, undef],
  [q{<p hoge="abc"></p>} => [[0, 3, 1, 10]], 1, 4, undef],
  [q{<p hoge='abc'></p>} => [[0, 3, 1, 10]], 1, 4, undef],
  [q{<p hoge="ab&lt;x"></p>} => [[0, 2, 1, 10], [2, 1, 1, 12], [3, 1, 1, 16]], 1, 4, undef],
  [q{<p hoge='ab&lt;x'></p>} => [[0, 2, 1, 10], [2, 1, 1, 12], [3, 1, 1, 16]], 1, 4, undef],
  [q{<p hoge="ab&ltvx"></p>} => [[0, 2, 1, 10], [2, 5, 1, 12]], 1, 4, undef],
  [q{<!DOCTYPE p[
    <!ENTITY ltv "foo">
  ]><p hoge="ab&ltv;x"></p>} => [[0, 2, 3, 14],
                                 [2, 3, 2, 19, 0],
                                 [5, 1, 3, 21]], 3, 8, undef],
  [q{<!DOCTYPE p[
    <!ENTITY ltv "fo&amp;o">
  ]><p hoge="ab&ltv;x"></p>} => [[0, 2, 3, 14], # ab
                                 [2, 2, 2, 19, 0], # fo
                                 [4, 1, 2, 21, 0], # &amp;
                                 [5, 1, 2, 26, 0], # o
                                 [6, 1, 3, 21]], 3, 8, undef], # x
  [q{<!DOCTYPE p[
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>} => [[0, 2, 3, 14], # ab
                                 [2, 2, 2, 19, 0], # fo
                                 [4, 5, 2, 21, 0], # &abc;
                                 [9, 1, 2, 26, 0], # o
                                 [10, 1, 3, 21]], 3, 8, undef], # x
  [q{<!DOCTYPE p[
    <!ENTITY abc SYSTEM "foo" aa>
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>} => [[0, 2, 4, 14], # ab
                                 [2, 2, 3, 19, 0], # fo
                                 [4, 5, 3, 21, 0], # &abc;
                                 [9, 1, 3, 26, 0], # o
                                 [10, 1, 4, 21]], 4, 8, undef], # x
  [q{<!DOCTYPE p[
    <!ENTITY abc SYSTEM "foo">
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>} => [[0, 2, 4, 14], # ab
                                 [2, 2, 3, 19, 0], # fo
                                 [4, 5, 3, 21, 0], # &abc;
                                 [9, 1, 3, 26, 0], # o
                                 [10, 1, 4, 21]], 4, 8, undef], # x
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "">
  ]><a/>} => [], 2, 17, undef],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd">
  ]><a/>} => [[0, 2, 2, 27]], 2, 17, undef],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd&amp;b">
  ]><a/>} => [[0, 2, 2, 27], [2, 1, 2, 29], [3, 1, 2, 34]], 2, 17, undef],
  [q{<!DOCTYPE a [
    <!ENTITY foo "b">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><a/>} => [[0, 2, 3, 27], [2, 1, 2, 19, 0], [3, 1, 3, 34]], 3, 17, undef],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd&foo;b">
    <!ENTITY foo "b">
  ]><a/>} => [[0, 2, 2, 27], [2, 5, 2, 29], [7, 1, 2, 34]], 2, 17, undef],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    Web::XML::Parser->new->parse_char_string ($test->[0] => $doc);

    my $attr = $doc->document_element->attributes->[0];
    my $pos = $attr->get_user_data ('manakai_sps');

    eq_or_diff $pos, $test->[1];
    is $attr->get_user_data ('manakai_source_line'), $test->[2];
    is $attr->get_user_data ('manakai_source_column'), $test->[3];
    is $attr->get_user_data ('manakai_di'), $test->[4];

    done $c;
  } n => 4, name => 'attr value';
}

for my $test (
  [q{<!DOCTYPE a [
    <!ENTITY foo "b">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><b><a/></b>} => [[0, 2, 3, 27], [2, 1, 2, 19, 0], [3, 1, 3, 34]],
   3, 17, undef],
  [q{<!DOCTYPE a [
    <!ENTITY x "d">
    <!ENTITY foo "b&x;c">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><b><a/></b>} => [[0, 2, 4, 27],
                     [2, 1, 3, 19, 0], # b
                     [3, 1, 2, 17, 0],
                     [4, 1, 3, 23, 0], # c
                     [5, 1, 4, 34]],
   4, 17, undef],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='foo'></a>">
  ]><b>&a;</b>} => [[0, 3, 2, 26, 0]], 2, 20, 0],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='foo'></a>">
    <!ENTITY b "&a;">
  ]><b>&b;</b>} => [[0, 3, 2, 26, 0]], 2, 20, 0],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='fo&c;'></a>">
    <!ENTITY b "&a;">
    <!ENTITY c "p">
  ]><b>&b;</b>} => [[0, 2, 2, 26, 0], [2, 1, 4, 17, 0]], 2, 20, 0],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    Web::XML::Parser->new->parse_char_string ($test->[0] => $doc);

    my $attr = $doc->document_element->first_child->attributes->[0];
    my $pos = $attr->get_user_data ('manakai_sps');

    eq_or_diff $pos, $test->[1];
    is $attr->get_user_data ('manakai_source_line'), $test->[2];
    is $attr->get_user_data ('manakai_source_column'), $test->[3];
    is $attr->get_user_data ('manakai_di'), $test->[4];

    done $c;
  } n => 4, name => 'attr value';
}

for my $test (
  [q{<svg>abc</svg>}, 'svg', [[0, 3, 1,6]]],
  [qq{<svg>a\x00c</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,8]]],
  [qq{<svg>\x00\x00c</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,8]]],
  [q{<svg>  c</svg>}, 'svg', [[0, 3, 1,6]]],
  [q{<svg>a&amp;x</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,12]]],
  [q{<svg>ab</x>c</svg>}, 'svg', [[0, 2, 1,6], [2, 1, 1,12]]],
  [q{<svg><g>ab</x>c</g></svg>}, 'g', [[0, 2, 1,9], [2, 1, 1,15]]],
  [qq{<frameset> </frameset>}, 'frameset', [[0, 1, 1,11]]],
  [q{<svg><![CDATA[x]]></svg>}, 'svg', [[0, 1, 1,15]]],
  [qq{<svg><![CDATA[\x0Ax]]></svg>}, 'svg', [[0, 2, 2,0]]],
  [qq{<svg><![CDATA[\x0Ax\x0Ab]]></svg>}, 'svg', [[0, 2, 2,0], [2, 2, 3,0]]],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    my $p = Web::XML::Parser->new;
    $p->onerror (sub { });
    $p->parse_char_string ($test->[0] => $doc);

    $test->[1] =~ s/\s+(\d+)$//;
    my $index = $1 || 0;
    my $el = $doc->query_selector ($test->[1]);
    my $text = ($el->local_name eq 'template' ? $el->content : $el)
        ->child_nodes->[$index];
    my $pos = $text->get_user_data ('manakai_sps');
    eq_or_diff $pos, $test->[2];

    done $c;
  } n => 1, name => 'a text node';
}

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
