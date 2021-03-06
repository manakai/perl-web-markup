use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('lib')->stringify;
use lib path (__FILE__)->parent->parent->parent->child
    ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child
    ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::HTML::Parser;
use Web::HTML::SourceMap;
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
   [[0, 1, 1,11], [1, 3, 1,12]]],
  [qq{<style>\x00\x0Aaa</style>}, 'style', [[0, 1, 1,8], [1, 3, 1,9]]],
  [qq{<script>\x0A\x00aa</script>}, 'script',
   [[0, 1, 1,9], [1, 1, 2,1], [2, 2, 2,2]]],
  [qq{<title>\x0A\x00aa</title>}, 'title',
   [[0, 1, 1,8], [1, 1, 2,1], [2, 2, 2,2]]],
  [qq{<title>\x0A&apos;\x00aa</title>}, 'title',
   [[0, 1, 1,8], [1, 1, 2,1], [2, 1, 2,7], [3, 2, 2,8]]],
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
  [q{<svg><![CDATA[x]]></svg>}, 'svg', [[0, 1, 1,15]]],
  [qq{<svg><![CDATA[\x0Ax]]></svg>}, 'svg', [[0, 2, 1,15]]],
  [qq{<svg><![CDATA[\x0Ax\x0Ab]]></svg>}, 'svg', [[0, 2, 1,15], [2, 2, 2,2]]],
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

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerrors (sub { push @error, @{$_[1]} });
  $parser->parse_char_string (q{  hoge} => $doc);
  eq_or_diff $doc->body->first_child->manakai_get_source_location, ['', 1, 2];
  is $error[0]->{di}, 1;
  is $error[0]->{index}, 2;
  is $parser->di, 1;
  eq_or_diff $parser->di_data_set->[1], {};
  done $c;
} n => 5, name => 'parse_char_string di';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerrors (sub { push @error, @{$_[1]} });
  my $nodes = $parser->parse_char_string_with_context (q{  hoge}, undef, $doc);
  eq_or_diff $nodes->[0]->manakai_get_source_location, ['', 1, 2];
  is $error[0]->{di}, 1;
  is $error[0]->{index}, 2;
  is $parser->di, 1;
  eq_or_diff $parser->di_data_set->[1], {};
  done $c;
} n => 5, name => 'parse_char_string_with_context di';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerrors (sub { push @error, @{$_[1]} });
  $parser->parse_chars_start ($doc);
  $parser->parse_chars_feed (' ');
  $parser->parse_chars_feed (' ');
  $parser->parse_chars_feed ('h');
  $parser->parse_chars_feed ('oge');
  $parser->parse_chars_end;
  eq_or_diff $doc->body->first_child->manakai_get_source_location, ['', 1, 2];
  is $error[0]->{di}, 1;
  is $error[0]->{index}, 2;
  is $parser->di, 2;
  eq_or_diff $parser->di_data_set->[1], {map => [[0, 2, 0]]};
  eq_or_diff $parser->di_data_set->[2], {};
  done $c;
} n => 6, name => 'parse_chars_* di';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerrors (sub { push @error, @{$_[1]} });
  $parser->parse_byte_string (undef, q{  hoge} => $doc);
  eq_or_diff $doc->body->first_child->manakai_get_source_location, ['', 1, 2];
  is $error[0]->{di}, 1;
  is $error[0]->{index}, 2;
  is $parser->di, 1;
  eq_or_diff $parser->di_data_set->[1], {};
  done $c;
} n => 5, name => 'parse_byte_string di';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerrors (sub { push @error, @{$_[1]} });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (' ');
  $parser->parse_bytes_feed (' ');
  $parser->parse_bytes_feed ('h');
  $parser->parse_bytes_feed ('oge');
  $parser->parse_bytes_end;
  eq_or_diff $doc->body->first_child->manakai_get_source_location, ['', 1, 2];
  is $error[0]->{di}, 1;
  is $error[0]->{index}, 2;
  is $parser->di, 2;
  eq_or_diff $parser->di_data_set->[1], {map => [[0, 2, 0]]};
  eq_or_diff $parser->di_data_set->[2], {};
  done $c;
} n => 6, name => 'parse_bytes_* di';

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
