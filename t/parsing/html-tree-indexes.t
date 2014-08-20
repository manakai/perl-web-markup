use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('lib')->stringify;
use lib path (__FILE__)->parent->parent->parent->child ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::HTML::Parser;
use Web::DOM::Document;

my $TestData = q{

|
n 0 0 0 0
e 0

<!DOCTYPE html>
n 0 0 15 15 15

  <!--abc--><p>aa<br>
n 0 2 12 12 12 12 15 17
e 12

 <!DOCTYPE><xmp>ab</xmPa>d</xMp >x
n 0 1 11 11 11 11 16,18,20,24,25 33
e 10 10 1

ho|ge
n 0 0 0 0 0,2
e 0

<p foo=bar>ab
n 0 0 0 0 0 3,7,8 11
e 0

<p foo=bar&lt;baz abc>ab
n 0 0 0 0 0 3,7,8,10,14 18 22
e 0

<textarea>\u000Aabc
n 0 0 0 0 0 11
e 0 14

<textarea>abc
n 0 0 0 0 0 10
e 0 13

  ab
n 0 2 2 2 2
e 2

  \u0000ab
n 0 2 2 2 3
e 2 2 2

  a\u0000b
n 0 2 2 2 2,4
e 3 2 3

  \u0000
n 0 2 2 2
e 2 2 2

  \u0000\u0009
n 0 2 2 2 3
e 2 2 2

ab\u0000b
n 0 0 0 0 0,3
e 2 0 2

ab\u0000b\u0000
n 0 0 0 0 0,3
e 2 4 0 2 4

ab \u0000 cd e  fdgh
n 0 0 0 0 0,4
e 3 0 3

<p>a\u0000b
n 0 0 0 0 0 3,5
e 0 4 4

<frameset>abc</frameset>
n 0 0 0 0
e 0 10 11 12

<frameset> abc  def</frameset>
n 0 0 0 0 10,14
e 0 11 12 13 16 17 18

<table>abc</table>
n 0 0 0 0 7 0
e 0 7

<table>abc<!---->b</table>
n 0 0 0 0 7,17 0 10
e 0 7 17

<table>\u0000abc</table>
n 0 0 0 0 8 0
e 0 7 7 8

<template>a</template>
n 0 0 0 0 0 10 22
e 0

<p><template>a<q>bcd</template>
n 0 0 0 0 0 3 3 13 14 17
e 0 20

abc\u000D\u000Axy
n 0 0 0 0 0,3,5
e 0

abc\uFFFFxy
n 0 0 0 0 0
e 3 0

abc\uFFFF\uD800xy
n 0 0 0 0 0
e 3 4 0

<!DOCTYPE hoge>
n 0 0 15 15 15
e 0

<!DOCTYPE HTML><svg xmlns="mathml"/>
n 0 0 15 15 15 15 20,27
e 20

<br/>
n 0 0 0 0 0
e 0 0

};

for (grep { length } split /\n\n+/, $TestData) {
  my $Input = [];
  my $NodeIndexes = [];
  my $ErrorIndexes = [];
  if (s/\ne\s+(\S.*)$//) {
    unshift @$ErrorIndexes, split /\s+/, $1;
  }
  if (s/\nn\s+(\S.*)$//) {
    unshift @$NodeIndexes, map {
      [map { 0+$_ } split /,/, $_];
    } split /\s+/, $1;
  }
  $Input = [map { s/\\u([0-9A-F]{4})/chr hex $1/ge; $_ } split /\|/, $_];

  test {
    my $c = shift;
    my $parser = Web::HTML::Parser->new;
    my $errors = [];
    $parser->onerrors (sub { push @$errors, @{$_[1]} });
    my $doc = new Web::DOM::Document;
    my $di = 1;
    $parser->di (45);
    $parser->parse_chars_start ($doc);
    $parser->parse_chars_feed ($_) for @$Input;
    $parser->parse_chars_end;

    eq_or_diff [map { [$_->{di}, $_->{index}] } @$errors],
        [map { [$di, $_] } @$ErrorIndexes];

    my @result;
    my @node = ($doc);
    while (@node) {
      my $node = shift @node;
      my $sl = $node->manakai_get_source_location;
      if ($node->node_type == $node->TEXT_NODE) {
        push @result, [$sl->[1], $sl->[2], [map { [$_->[1], $_->[2]] } @{$node->manakai_get_indexed_string}]];
      } elsif ($node->node_type == $node->ATTRIBUTE_NODE) {
        push @result, [$sl->[1], $sl->[2], [map { [$_->[1], $_->[2]] } @{$node->manakai_get_indexed_string}]];
      } else {
        push @result, [$sl->[1], $sl->[2], [[$sl->[1], $sl->[2]]]];
      }
      unshift @node, $node->content if $node->node_type == $node->ELEMENT_NODE and
          $node->manakai_element_type_match ('http://www.w3.org/1999/xhtml', 'template');
      unshift @node, $node->child_nodes->to_list;
      unshift @node, @{$node->attributes or []};
    }
    eq_or_diff \@result, [map { [$di, $_->[0], [map { [$di, $_] } @$_]] } @$NodeIndexes];

    use Data::Dumper;
    #warn Dumper $errors;

    done $c;
  } n => 2, name => [@$Input];
}

run_tests;

## License: Public Domain.
