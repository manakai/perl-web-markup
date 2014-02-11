use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::HTML::Parser;
use Web::DOM::Document;

for my $test (
  [q{<svg>abc</svg>}, 'svg', [[0, 3, 1,6]]],
  [qq{<svg>a\x00c</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,8]]],
  [qq{<svg>\x00\x00c</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,8]]],
  [q{<svg>  c</svg>}, 'svg', [[0, 3, 1,6]]],
  [q{<svg>a&amp;x</svg>}, 'svg', [[0, 1, 1,6], [1, 1, 1,7], [2, 1, 1,12]]],
  [q{<svg>ab</x>c</svg>}, 'svg', [[0, 2, 1,6], [2, 1, 1,12]]],
  [q{<svg><g>ab</x>c</g></svg>}, 'g', [[0, 2, 1,9], [2, 1, 1,15]]],
  [q{<table>ab</table>}, 'body', [[0, 2, 1,8]]],
  [qq{<table>ab\x00c</table>}, 'body', [[0, 2, 1,8], [2, 1, 1,11]]],
  [q{<table> ab</table>}, 'body', [[0, 3, 1,8]]],
  [q{<table> a&amp;b</table>}, 'body', [[0, 2, 1,8], [2, 1, 1,10], [3, 1, 1, 15]]],
  [q{<table> <!---->ab</table>}, 'body', [[0, 2, 1,16]]],
  [q{<table> <!---->ab<!---->c</table>}, 'body', [[0, 2, 1,16], [2, 1, 1,25]]],
  [q{<template><tr>yx</template>}, 'template 1', [[0, 2, 1,15]]],
  [q{<template><tr>yx</x>cd</template>}, 'template 1', [[0, 2, 1,15], [2, 2, 1,21]]],
  [q{<textarea>aa</textarea>}, 'textarea', [[0, 2, 1,11]]],
  [qq{<textarea>\x0Aaa</textarea>}, 'textarea', [[0, 2, 2,1]]],
  [qq{<textarea>\x0A\x00aa</textarea>}, 'textarea',
   [[0, 1, 2,1], [1, 2, 2,2]]],
  [qq{<textarea>\x00\x0Aaa</textarea>}, 'textarea',
   [[0, 1, 1,11], [1, 3, 2,0]]],
  [qq{<style>\x00\x0Aaa</style>}, 'style', [[0, 1, 1,8], [1, 3, 2,0]]],
  [qq{<script>\x0A\x00aa</script>}, 'script',
   [[0, 1, 2,0], [1, 1, 2,1], [2, 2, 2,2]]],
  [qq{<title>\x0A\x00aa</title>}, 'title',
   [[0, 1, 2,0], [1, 1, 2,1], [2, 2, 2,2]]],
  [qq{<title>\x0A&apos;\x00aa</title>}, 'title',
   [[0, 1, 2,0], [1, 1, 2,1], [2, 1, 2,7], [3, 2, 2,8]]],
  [qq{<head> </head>}, 'head', [[0, 1, 1,7]]],
  [qq{</head> }, 'html 1', [[0, 1, 1,8]]],
  [qq{<head> x}, 'head', [[0, 1, 1,7]]],
  [qq{<head> x}, 'body', [[0, 1, 1,8]]],
  [qq{</head> x}, 'html 1', [[0, 1, 1,8]]],
  [qq{</head> x}, 'body', [[0, 1, 1,9]]],
  [qq{<template>aa</template>}, 'template', [[0, 2, 1,11]]],
  [qq{\x00ab}, 'body', [[0, 2, 1,2]]],
  [qq{x\x00ab}, 'body', [[0, 1, 1,1], [1, 2, 1,3]]],
  [qq{x&lt;ab}, 'body', [[0, 1, 1,1], [1, 1, 1,2], [2, 2, 1,6]]],
  [q{<table><span>a</span></table>}, 'span', [[0, 1, 1,14]]],
  [q{<table><span>a</x>c</span></table>}, 'span',
   [[0, 1, 1,14], [1, 1, 1,19]]],
  [q{<table><span> a</span></table>}, 'span', [[0, 2, 1,14]]],
  [q{<table><colgroup>  </table>}, 'colgroup', [[0, 2, 1,18]]],
  [q{<table><colgroup>  ab</table>}, 'colgroup', [[0, 2, 1,18]]],
  [q{<table><colgroup>  ab</table>}, 'body', [[0, 2, 1,20]]],
  [q{<select> </select>}, 'select', [[0, 1, 1,9]]],
  [q{<select> a</select>}, 'select', [[0, 2, 1,9]]],
  [qq{<select>\x00a</select>}, 'select', [[0, 1, 1,10]]],
  [qq{<select>b\x00a</select>}, 'select', [[0, 1, 1,9], [1, 1, 1,11]]],
  [qq{</body>  }, 'body', [[0, 2, 1,8]]],
  [qq{</body>  x}, 'body', [[0, 2, 1,8], [2, 1, 1,10]]],
  [qq{</body>x}, 'body', [[0, 1, 1,8]]],
  [qq{<frameset> </frameset>}, 'frameset', [[0, 1, 1,11]]],
  [qq{<frameset> ab</frameset>}, 'frameset', [[0, 1, 1,11]]],
  [qq{<frameset>ab </frameset>}, 'frameset', [[0, 1, 1,13]]],
  [qq{<frameset>ab c </frameset>}, 'frameset', [[0, 1, 1,13], [1, 1, 1,15]]],
  [qq{<frameset> c </frameset>}, 'frameset', [[0, 1, 1,11], [1, 1, 1,13]]],
) {
  test {
    my $c = shift;

    my $doc = new Web::DOM::Document;
    my $p = Web::HTML::Parser->new;
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
