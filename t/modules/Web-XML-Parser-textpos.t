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
use Web::HTML::SourceMap;
use Web::DOM::Document;

for my $test (
  [q<<p>abc</p>>, 'p' => [[0, 3, 1,4]]],
  [q<<p>abc&amp;</p>>, 'p' => [[0, 3, 1,4], [3, 1, 1,7]]],
  [q<<p>abc&amp;x</p>>, 'p' => [[0, 3, 1,4], # 'a'
                           [3, 1, 1,7],
                           [4, 1, 1,12]]], # 'x'
  [qq<<p>ab\x0Ac</p>>, 'p' => [[0, 2, 1,4],
                          [2, 2, 1,6]]],
  [qq<<p>ab\x0Ac&apos;y</p>>, 'p' => [[0, 2, 1,4],
                                 [2, 2, 1,6],
                                 [4, 1, 2, 2],
                                 [5, 1, 2,8]]],
  [q<<p>ab</x>c</p>>, 'p' => [[0, 2, 1,4],
                         [2, 1, 1,10]]],
  [q<<p>ab<![CDATA[cd]]>e</p>>, 'p' => [[0, 2, 1,4],
                                   [2, 2, 1,15],
                                   [4, 1, 1,20]]],
  [q<<p>ab<![CDATA[]]>e</p>>, 'p' => [[0, 2, 1,4],
                                 [2, 1, 1,18]]],
  [qq<<p>abc\x0Aabc\x0Aabc</p>>, 'p' => [[0, 3, 1,4], [3, 4, 1,7], [7, 4, 2,4]]],
  [q{<!DOCTYPE a[<!ENTITY b "d">]><p>a&b;c</p>}, 'p'
       => [[0, 1, 1,33],
           [1, 1, 1,25, 0],
           [2, 1, 1,37]]],
  [q{<!DOCTYPE a[<!ENTITY b "d&#x32;e">]><p>a&b;c</p>}, 'p'
       => [[0, 1, 1,40], # a
           [1, 1, 1,25, 0], # d
           [2, 1, 1,26, 0], # 2
           [3, 1, 1,32, 0], # e
           [4, 1, 1,44]]], # c
  [q{<!DOCTYPE a[<!ENTITY b "&#123;d&#x32;e">]><p>a&b;c</p>}, 'p'
       => [[0, 1, 1,46], # a
           [1, 1, 1,25, 0], # &#123;
           [2, 1, 1,31, 0], # d
           [3, 1, 1,32, 0], # 2
           [4, 1, 1,38, 0], # e
           [5, 1, 1,50]]], # c
  [q{<!DOCTYPE a[<!ENTITY e "f"><!ENTITY b "d&e;g">]><p>a&b;c</p>}, 'p'
       => [[0, 1, 1,52], # a
           [1, 1, 1,40], # d
           [2, 1, 1,25, 0], # f
           [3, 1, 1,44], # g
           [4, 1, 1, 56]]], # c
  [q{<!DOCTYPE a[<!ENTITY e "f"><!ENTITY h "i&e;j"><!ENTITY b "d&h;g">]><p>a&b;c</p>}, 'p'
       => [[0, 1, 1,71], # a
           [1, 1, 1,59], # d
           [2, 1, 1,40], # i
           [3, 1, 1,25, 0], # f
           [4, 1, 1,44], # j
           [5, 1, 1,63], # g
           [6, 1, 1,75]]], # c
  [q{<!DOCTYPE a><a><b>c</b></a>}, 'b' => [[0, 1, 1, 19]]],
  [q{<!DOCTYPE a[<!ENTITY d "e">]><a><b>c&d;f</b></a>}, 'b'
       => [[0, 1, 1, 36],
           [1, 1, 1, 25, 0],
           [2, 1, 1, 40]]],
  [q{<!DOCTYPE a[<!ENTITY d "<b>g</b>h">]><a>&d;e</a>}, 'a'
       => [[0, 1, 1, 28]]],
  [q{<!DOCTYPE a[<!ENTITY d "<b>g&i;k</b>h"><!ENTITY i "j">]><a>&d;e</a>}, 'b'
       => [[0, 1, 1, 28],
           [1, 1, 1, 52, 0],
           [2, 1, 1, 32]]],
  [q{<svg>abc</svg>}, 'svg', [[0, 3, 1,6]]],
  [qq{<svg>a\x00c</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,8]]],
  [qq{<svg>\x00\x00c</svg>}, 'svg', [[0, 1, 1,8]]],
  [q{<svg>  c</svg>}, 'svg', [[0, 3, 1,6]]],
  [q{<svg>a&amp;x</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,12]]],
  [q{<svg>ab</x>c</svg>}, 'svg', [[0, 2, 1,6], [2, 1, 1,12]]],
  [q{<svg><g>ab</x>c</g></svg>}, 'g', [[0, 2, 1,9], [2, 1, 1,15]]],
  [qq{<frameset> </frameset>}, 'frameset', [[0, 1, 1,11]]],
  [q{<svg><![CDATA[x]]></svg>}, 'svg', [[0, 1, 1,15]]],
  [qq{<svg><![CDATA[\x0Ax]]></svg>}, 'svg', [[0, 2, 1,15]]],
  [qq{<svg><![CDATA[\x0Ax\x0Ab]]></svg>}, 'svg', [[0, 2, 1,15], [2, 2, 2,2]]],
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
    my $is = $text->manakai_get_indexed_string;

    my $dids = $p->di_data_set;
    $dids->[$p->di]->{lc_map} = create_index_lc_mapping $test->[0];
    $dids->[my $is_di = @$dids]->{map} = indexed_string_to_mapping $is;

    for (@{$test->[2]}) {
      my ($di, $index) = resolve_index_pair $dids, $is_di, $_->[0];
      my ($line, $col) = index_pair_to_lc_pair $dids, $di, $index;
      test {
        eq_or_diff [$line, $col], [$_->[2], $_->[3]];
      } $c, name => $_;
    }

    done $c;
  } n => scalar @{$test->[2]}, name => ['a text node', $test->[0]];
}

for my $test (
  [q{<!DOCTYPE a[
<!ENTITY b "<e>cd</e>">
]><a>&b;</a>}, [2, 0], [1, 25]],
  [q{<!DOCTYPE a[
<!ENTITY b "<e><f>c</f>d</e>">
]><a>&b;</a>}, [2, 0], [1, 25]],
  [q{<!DOCTYPE a[
<!ENTITY b "<e>
<f>c</f>d</e>">
]><a>&b;</a>}, [2, 0], [1, 25]],
  [q{<!DOCTYPE a[
<!ENTITY b "<e>
<f>c</f>d</e>">
<!ENTITY g "&b;">
]><a>&g;</a>}, [3, 0], [1, 25]],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    my $p = Web::XML::Parser->new;
    $p->parse_char_string ($test->[0] => $doc);

    my $nl = $doc->document_element->first_child->manakai_get_source_location;
    eq_or_diff $nl, ['', @{$test->[1]}];

    my $dids = $p->di_data_set;
    my ($di, $index) = resolve_index_pair $dids, $nl->[1], $nl->[2];
    is $di, $test->[2]->[0];
    is $index, $test->[2]->[1];

    done $c;
  } n => 3, name => 'entity expanded element';
}

for my $test (
  [q{<p hoge></p>}, 'p' => [], 1, 3],
  [q{<p hoge=""></p>}, 'p' => [], 1, 3],
  [q{<p hoge=''></p>}, 'p' => [], 1, 3],
  [q{<p hoge=abc></p>}, 'p' => [[0, 1, 1, 9], [1, 2, 1, 10]], 1, 3],
  [q{<p hoge="abc"></p>}, 'p' => [[0, 3, 1, 10]], 1, 3],
  [q{<p hoge='abc'></p>}, 'p' => [[0, 3, 1, 10]], 1, 3],
  [q{<p hoge=abc&amp></p>}, 'p' => [[0, 1, 1, 9], [1, 2, 1, 10], [3, 1, 1, 12]], 1, 3],
  [q{<p hoge=abc&amp;b></p>}, 'p' => [[0, 1, 1, 9], [1, 2, 1, 10],
                                 [3, 1, 1, 12], [4, 1, 1, 17]], 1, 3],
  [q{<p hoge=abc&ampxy;></p>}, 'p' => [[0, 1, 1, 9], [1, 2, 1, 10], [3, 7, 1, 12]], 1, 3],
  [q{<p hoge="abc"></p>}, 'p' => [[0, 3, 1, 10]], 1, 3],
  [q{<p hoge='abc'></p>}, 'p' => [[0, 3, 1, 10]], 1, 3],
  [q{<p hoge="ab&lt;x"></p>}, 'p' => [[0, 2, 1, 10], [2, 1, 1, 12], [3, 1, 1, 16]], 1, 3],
  [q{<p hoge='ab&lt;x'></p>}, 'p' => [[0, 2, 1, 10], [2, 1, 1, 12], [3, 1, 1, 16]], 1, 3],
  [q{<p hoge="ab&ltvx"></p>}, 'p' => [[0, 2, 1, 10], [2, 5, 1, 12]], 1, 3],
  [q{<!DOCTYPE p[
    <!ENTITY ltv "foo">
  ]><p hoge="ab&ltv;x"></p>}, 'p' => [[0, 2, 3, 14],
                                 [2, 3, 2, 19, 0],
                                 [5, 1, 3, 21]], 1, 44],
  [q{<!DOCTYPE p[
    <!ENTITY ltv "fo&amp;o">
  ]><p hoge="ab&ltv;x"></p>}, 'p' => [[0, 2, 3, 14], # ab
                                 [2, 2, 2, 19], # fo
                                 [4, 1, 2, 21], # &
                                 [5, 1, 2, 26], # o
                                 [6, 1, 3, 21]], 1, 49], # x
  [q{<!DOCTYPE p[
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>}, 'p' => [[0, 2, 3, 14], # ab
                                 [2, 2, 2, 19], # fo
                                 [4, 5, 2, 21], # &abc;
                                 [9, 1, 2, 26], # o
                                 [10, 1, 3, 21]], 1, 49], # x
  [q{<!DOCTYPE p[
    <!ENTITY abc SYSTEM "foo" aa>
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>}, 'p' => [[0, 2, 4, 14], # ab
                                 [2, 2, 3, 19], # fo
                                 [4, 5, 3, 21], # &abc;
                                 [9, 1, 3, 26], # o
                                 [10, 1, 4, 21]], 1, 83], # x
  [q{<!DOCTYPE p[
    <!ENTITY abc SYSTEM "foo">
    <!ENTITY ltv "fo&abc;o">
  ]><p hoge="ab&ltv;x"></p>}, 'p' => [[0, 2, 4, 14], # ab
                                 [2, 2, 3, 19], # fo
                                 [4, 5, 3, 21], # &abc;
                                 [9, 1, 3, 26], # o
                                 [10, 1, 4, 21]], 1, 80], # x
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "">
  ]><a/>}, 'a' => [], 1, 30],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd">
  ]><a/>}, 'a' => [[0, 2, 2, 27, 0]], 1, 30],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd&amp;b">
  ]><a/>}, 'a' => [[0, 2, 2, 27, 0], [2, 1, 2, 29, 0], [3, 1, 2, 34, 0]], 1, 30],
  [q{<!DOCTYPE a [
    <!ENTITY foo "b">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><a/>}, 'a' => [[0, 2, 3, 27, 0], [2, 1, 2, 19, 0], [3, 1, 3, 34, 0]], 1, 52],
  [q{<!DOCTYPE a [
    <!ATTLIST a bb CDATA "dd&foo;b">
    <!ENTITY foo "b">
  ]><a/>}, 'a' => [[0, 2, 2, 27, 0], [2, 5, 2, 29, 0], [7, 1, 2, 34, 0]], 1, 30],
  [q{<!DOCTYPE a [
    <!ENTITY foo "b">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><b><a/></b>}, 'a' => [[0, 2, 3, 27, 0], [2, 1, 2, 19, 0], [3, 1, 3, 34]], 1, 52],
  [q{<!DOCTYPE a [
    <!ENTITY x "d">
    <!ENTITY foo "b&x;c">
    <!ATTLIST a bb CDATA "dd&foo;b">
  ]><b><a/></b>}, 'a' => [[0, 2, 4, 27, 0],
                     [2, 1, 3, 19], # b
                     [3, 1, 2, 17],
                     [4, 1, 3, 23], # c
                     [5, 1, 4, 34]], 1, 76],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='foo'></a>">
  ]><b>&a;</b>}, 'a' => [[0, 3, 2, 26]], 2, 3],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='foo'></a>">
    <!ENTITY b "&a;">
  ]><b>&b;</b>}, 'a' => [[0, 3, 2, 26]], 3, 3],
  [q{<!DOCTYPE a[
    <!ENTITY a "<a hoge='fo&c;'></a>">
    <!ENTITY b "&a;">
    <!ENTITY c "p">
  ]><b>&b;</b>}, 'a' => [[0, 2, 2, 26],
                         [2, 1, 4, 17]], 3, 3],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    my $p = Web::XML::Parser->new;
    $p->parse_char_string ($test->[0] => $doc);

    $test->[1] =~ s/\s+(\d+)$//;
    my $index = $1 || 0;
    my $el = $doc->query_selector ($test->[1]);
    my $attr = $el->attributes->[0];
    my $is = $attr->manakai_get_indexed_string;

    my $dids = $p->di_data_set;
    $dids->[$p->di]->{lc_map} = create_index_lc_mapping $test->[0];
    $dids->[my $is_di = @$dids]->{map} = indexed_string_to_mapping $is;

    for (@{$test->[2]}) {
      my ($di, $index) = resolve_index_pair $dids, $is_di, $_->[0];
      my ($line, $col) = index_pair_to_lc_pair $dids, $di, $index;
      test {
        eq_or_diff [$line, $col], [$_->[2], $_->[3]];
      } $c, name => $_;
    }

    my $nl = $attr->manakai_get_source_location;
    eq_or_diff $nl, ['', $test->[3], $test->[4]];

    done $c;
  } n => 1 + scalar @{$test->[2]}, name => ['attr value', $test->[0]];
}

for my $test (
  [q{<svg><?x?></svg>}, 'svg', []],
  [q{<svg><?x ?></svg>}, 'svg', []],
  [q{<svg><?x a?></svg>}, 'svg', [[0, 1, 1,10]]],
  [q{<svg><?x   a?></svg>}, 'svg', [[0, 1, 1,12]]],
  [q{<svg><?x abc?></svg>}, 'svg', [[0, 3, 1,10]]],
  [q{<svg><?x abc  ?></svg>}, 'svg', [[0, 5, 1,10]]],
  [q{<svg><?x abc  ??></svg>}, 'svg', [[0, 5, 1,10], [6, 1, 1,15]]],
  [q{<svg><?x abc  ???></svg>}, 'svg', [[0, 5, 1,10], [6, 1, 1,15], [7, 1, 1,16]]],
  [qq{<svg><?x abc\x0Ab?></svg>}, 'svg', [[0, 3, 1,10], [3, 2, 1,13]]],
  [qq{<?x abc\x0Ab?><svg/>}, 'X 0', [[0, 3, 1,5], [3, 2, 1,8]]],
  [qq{<?xml version="1.0"?>\x0A<?x abc\x0Ab?><svg/>}, 'X 0', [[0, 3, 2,5], [3, 2, 2,8]]],
  [qq{<svg/><?x abc\x0Ab?>}, 'X 1', [[0, 3, 1,11], [3, 2, 1,14]]],
  [qq{<!DOCTYPE a[<?x abc\x0Ab?>]>}, 'doctype 0', [[0, 3, 1,17], [3, 2, 1,20]]],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    my $p = Web::XML::Parser->new;
    $p->onerror (sub { });
    $p->parse_char_string ($test->[0] => $doc);

    $test->[1] =~ s/\s+(\d+)$//;
    my $index = $1 || 0;
    my $el = $test->[1] eq 'doctype' ? $doc->doctype : $doc->query_selector ($test->[1]) || $doc;
    my $text = (($el->local_name || '') eq 'template' ? $el->content : $el)
        ->child_nodes->[$index];
    my $is = $text->manakai_get_indexed_string;

    my $dids = $p->di_data_set;
    $dids->[$p->di]->{lc_map} = create_index_lc_mapping $test->[0];
    $dids->[my $is_di = @$dids]->{map} = indexed_string_to_mapping $is;

    for (@{$test->[2]}) {
      my ($di, $index) = resolve_index_pair $dids, $is_di, $_->[0];
      my ($line, $col) = index_pair_to_lc_pair $dids, $di, $index;
      test {
        eq_or_diff [$line, $col], [$_->[2], $_->[3]];
      } $c, name => $_;
    }

    done $c;
  } n => scalar @{$test->[2]}, name => ['PI node', $test->[0]];
}

for my $test (
  [q{abc} => [[0, 3, 1, 1]]],
  [q{a b} => [[0, 2, 1, 1],
              [2, 1, 1, 3]]],
  [q{a  b} => [[0, 2, 1, 1],
               [2, 1, 1, 4]], q{a b}],
  [qq{a \x0Ab\x09} => [[0, 2, 1, 1],
                       [2, 1, 2, 1]], q{a b}],
  [q{ a  b } => [[0, 2, 1, 2],
                 [2, 1, 1, 5]], q{a b}],
  [qq{\x0A  abc\x0A} => [[0, 3, 2, 3]], q{abc}],
  [qq{&#xa;  abc\x0A} => [[0, 2, 1, 1],
                          [2, 3, 1, 8]], qq{\x0A abc}],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = new Web::XML::Parser;
    $parser->onerror (sub { });
    my $input = (sprintf q{<!DOCTYPE a[
      <!ATTLIST a b ID #IMPLIED>
    ]><a b="%s"/>}, $test->[0]);
    $parser->parse_char_string ($input => $doc);
    my $attr = $doc->document_element->attributes->[0];
    my $is = $attr->manakai_get_indexed_string;

    my $dids = $parser->di_data_set;
    $dids->[$parser->di]->{lc_map} = create_index_lc_mapping $input;
    $dids->[my $is_di = @$dids]->{map} = indexed_string_to_mapping $is;

    for (@{$test->[1]}) {
      my ($di, $index) = resolve_index_pair $dids, $is_di, $_->[0];
      my ($line, $col) = index_pair_to_lc_pair $dids, $di, $index;
      test {
        eq_or_diff [$line-2, $line == 3 ? $col-12 : $col], [$_->[2], $_->[3]];
      } $c, name => $_;
    }

    is $attr->value, $test->[2] || $test->[0];
    done $c;
  } n => 1 + @{$test->[1]}, name => 'attr tokenized';
}

for my $test (
  [q{<!DOCTYPE iframe [
  <!ENTITY hoge "&lt;/q>">
]>
<iframe srcdoc="
  &hoge;
" xmlns="http://www.w3.org/1999/xhtml"></iframe>}, [[0, 1, 4, 17],
                    [1, 1, 5, 1],
                    [2, 1, 5, 2],
                    [3, 1, 2, 18],
                    [4, 3, 2, 22],
                    [7, 1, 5, 9]]],
  [q{<!DOCTYPE iframe [
  <!ENTITY hoge "&#x3c;/q>">
]>
<iframe srcdoc="
  &hoge;
" xmlns="http://www.w3.org/1999/xhtml"></iframe>}, [[0, 1, 4, 17],
                    [1, 1, 5, 1],
                    [2, 1, 5, 2],
                    [3, 6, 5, 3], # &hoge;
                    [9, 1, 5, 9]]],
  [q{<!DOCTYPE iframe [
  <!ENTITY hoge "&#x26;#x3c;/q>">
]>
<iframe srcdoc="
  &hoge;
" xmlns="http://www.w3.org/1999/xhtml"></iframe>} => [[0, 1, 4, 17],
                    [1, 1, 5, 1],
                    [2, 1, 5, 2],
                    [3, 1, 2, 18],
                    [4, 3, 2, 29],
                    [7, 1, 5, 9]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = new Web::XML::Parser;
    $parser->onerror (sub { });
    $parser->parse_char_string ($test->[0] => $doc);
    my $attr = $doc->document_element->attributes->[0];
    my $is = $attr->manakai_get_indexed_string;

    my $dids = $parser->di_data_set;
    $dids->[$parser->di]->{lc_map} = create_index_lc_mapping $test->[0];
    $dids->[my $is_di = @$dids]->{map} = indexed_string_to_mapping $is;

    for (@{$test->[1]}) {
      my ($di, $index) = resolve_index_pair $dids, $is_di, $_->[0];
      my ($line, $col) = index_pair_to_lc_pair $dids, $di, $index;
      test {
        eq_or_diff [$line, $col], [$_->[2], $_->[3]];
      } $c, name => $_;
    }

    done $c;
  } n => scalar @{$test->[1]}, name => 'srcdoc';
}

run_tests;

=head1 LICENSE

Copyright 2014-2015 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
