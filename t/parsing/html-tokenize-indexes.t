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
        @{$self->{saved_lists}->{Tokens}};
    @{$self->{saved_lists}->{Errors}} = ();
    @{$self->{saved_lists}->{Tokens}} = ();
  }
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
    my $di = 45;
    $tokenizer->di ($di);
    $tokenizer->parse_chars_start ($doc);
    $tokenizer->parse_chars_feed ($_) for @$Input;
    $tokenizer->parse_chars_end;

    eq_or_diff [map { [$_->{di}, $_->{index}] } @{$tokenizer->{_errors}}],
        [map { [$di, $_] } @$ErrorIndexes];
    eq_or_diff [map {
      [$_->{di}, $_->{index}],
      map { [$_->{di}, $_->{index}] } @{$_->{attr_list}}
    } @{$tokenizer->{_tokens}}],
        [map { [$di, $_] } @$TokenIndexes];

    use Data::Dumper;
    #warn Dumper $tokenizer->{_errors};
    #warn Dumper $tokenizer->{_tokens};

    done $c;
  } n => 2, name => [@$Input];
}

run_tests;
