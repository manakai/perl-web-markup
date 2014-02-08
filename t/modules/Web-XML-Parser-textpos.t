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
  [q<<p>abc&amp;</p>> => [[0, 4, 1,4]]],
  [q<<p>abc&amp;x</p>> => [[0, 4, 1,4], # 'a'
                           [4, 1, 1,12]]], # 'x'
  [qq<<p>ab\x0Ac</p>> => [[0, 2, 1,4],
                          [2, 2, 2,0]]],
  [qq<<p>ab\x0Ac&apos;y</p>> => [[0, 2, 1,4],
                                 [2, 3, 2,0],
                                 [5, 1, 2,8]]],
  [q<<p>ab</x>c</p>> => [[0, 2, 1,4],
                         [2, 1, 1,10]]],
  [q<<p>ab<![CDATA[cd]]>e</p>> => [[0, 2, 1,4],
                                   [2, 2, 1,15],
                                   [4, 1, 1,20]]],
  [q<<p>ab<![CDATA[]]>e</p>> => [[0, 2, 1,4],
                                 [2, 1, 1,18]]],
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

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
