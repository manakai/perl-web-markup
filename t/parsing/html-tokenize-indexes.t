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

{
  package Tokenizer;
  push our @ISA, qw(Web::HTML::Parser);
  sub _construct_tree {
    my $self = shift;
    push @{$self->{_errors} ||= []},
        @{$self->{saved_lists}->{Errors}};
    push @{$self->{_tokens} ||= []},
        map { +{%$_} } @{$self->{saved_lists}->{Tokens}};
    return $self->SUPER::_construct_tree;
  }
  sub onerrors { return sub { } }
}

my $TestData = q{

|
t 0

abc
t 0 3

ab|cd
t 0 2 4

<|p>
t 0 3

<p>a</p>b
t 0 3 4 8 9

a<pb> ba
t 0 1 5 8

bb<!--a-->x
t 0 2 10 11

a</ b>ax
t 0 1 6 8
e 3

a<$b
t 0 1 2 3 4
e 2

a<!>b
t 0 1 4 5
e 3

 <!DOCTYPE a>b
t 0 1 13 14

<!DOCTYPE>a
t 0 10 11
e 9 9

<!DOCTYPE a public ">">
t 0 21 23
e 20

a&amp;b
t 0 1 6 7

a&AMP+
t 0 1 5 6
e 5

a&fuga;b
t 0 1 7 8
e 1

a&ampfoo
t 0 1 5 8
e 5

a&#x0;
t 0 1 6
e 1

a&#x110000;
t 0 1 11
e 1

a&#00;
t 0 1 6
e 1

a&#9911110000;
t 0 1 14
e 1

ab</foo bar>
t 0 2 8 12
e 2

ab</foo />
t 0 2 10
e 2

<a b c>
t 0 3 5 7

<ab  xya  aaa>
t 0 5 10 14

<ab x=""bb="">
t 0 4 8 14
e 8

ab|cd<ab |fd>
t 0 2 4 8 11

<svg><![CDATA[abc]]></svg>
t 0 14 20 26

<plaintext>ab</plaintext>n
t 0 11 26

<xmp>ab</xmpab>cd</XMp>d
t 0 5 7 9 14 15 17 23 24

<script>aa<!--<script>b</script>c-->d</script>e
t 0 8 10 12 13 14 15 16 21 22 23 24 25 31 32 33 34 35 36 37 46 47

<!---ab-->c
t 0 10 11

<!---ab----c>d
t 0 14
e 9 10 11 14

<!doc>hoge
t 0 6 10
e 5

<svg><![CDA[ab]]>bb</svg>
t 0 5 17 19 25
e 11

<svg><![CDATA[ab]]]>c</svg>
t 0 14 16 20 21 27

a<p f=x>
t 0 1 4 6 7 8

a<p f=|x>
t 0 1 4 6 8

a<p foo=bar>
t 0 1 4 8 9 12

a<p foo=|b|a|r>
t 0 1 4 8 9 10 12

a<p foo=bar baz=baz>
t 0 1 4 8 9 12 16 17 20

a<p foo="|bar"bar='|baz'>
t 0 1  4 9  13 18  23
e 13

a<p foo="bar"bar='baz'>
t 0 1  4 9  13 18  23
e 13

a<p foo="bar
t 0 12
e 12

a<p foo=b`a>
t 0 1 4 8 9 10 12
e 9

a<p foo=&amp;>
t 0 1 4 8 14

a<p foo=a&amp;b>
t 0 1 4 8 9 14 16

a<p foo=a&ampb>
t 0 1 4 8 9 15

a<p foo=a&amp>
t 0 1 4 8 9 13 14
e 13

a<p foo=a&foo>
t 0 1 4 8 9 14

a<p foo=a&foo;a>
t 0 1 4 8 9 14 16
e 9

a<p foo="a&amp=x">
t 0 1 4 9 10 14 15 18
e 14

a<p foo='a&amp=x'>
t 0 1 4 9 10 14 15 18
e 14

};

for (grep { length } split /\n\n+/, $TestData) {
  my $Input = [];
  my $TokenIndexes = [];
  my $ErrorIndexes = [];
  if (s/\ne\s+(\S.*)$//) {
    unshift @$ErrorIndexes, split /\s+/, $1;
  }
  if (s/\nt\s+(\S.*)$//) {
    unshift @$TokenIndexes, split /\s+/, $1;
  }
  $Input = [split /\|/, $_];

  test {
    my $c = shift;
    my $tokenizer = Tokenizer->new;
    my $doc = new Web::DOM::Document;
    my $di = 1;
    $tokenizer->di (45);
    $tokenizer->parse_chars_start ($doc);
    $tokenizer->parse_chars_feed ($_) for @$Input;
    $tokenizer->parse_chars_end;

    eq_or_diff [map { [$_->{di}, $_->{index}] } @{$tokenizer->{_errors}}],
        [map { [$di, $_] } @$ErrorIndexes];
    eq_or_diff [map {
      [$_->{di}, $_->{index}],
      map {
        #[$_->{di}, $_->{index}],
        map { [$_->[1], $_->[2]] } @{$_->{value}};
      } @{$_->{attr_list}};
    } @{$tokenizer->{_tokens}}],
        [map { [$di, $_] } @$TokenIndexes];

    #use Data::Dumper;
    #warn Dumper $tokenizer->{_errors};
    #warn Dumper $tokenizer->{_tokens};

    done $c;
  } n => 2, name => [@$Input];
}

run_tests;

## License: Public Domain.
