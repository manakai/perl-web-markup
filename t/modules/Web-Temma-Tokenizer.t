use strict;
use warnings;
use warnings FATAL => 'recursion';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::DOM::Document;
use Web::Temma::Tokenizer;

for my $test (
  [q{ba<p>b</>x<xmP>a<f>a}, [
     {di => 1, index => 0,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => 'ba'},
     {di => 1, index => 2,
      type => Web::Temma::Tokenizer::START_TAG_TOKEN, tn => 0,
      tag_name => 'p'},
     {di => 1, index => 5,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => 'b'},
     {di => 1, index => 6,
      type => Web::Temma::Tokenizer::END_TAG_TOKEN, tn => 0,
      tag_name => ''},
     {di => 1, index => 9,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => 'x'},
     {di => 1, index => 10,
      type => Web::Temma::Tokenizer::START_TAG_TOKEN, tn => 0,
      tag_name => 'xmp'},
     {di => 1, index => 15,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => 'a'},
     {di => 1, index => 16,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => '<'},
     {di => 1, index => 17,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => 'f'},
     {di => 1, index => 18,
      type => Web::Temma::Tokenizer::TEXT_TOKEN, tn => 0,
      value => '>a'},
     {di => 1, index => 20,
      type => Web::Temma::Tokenizer::END_OF_FILE_TOKEN, tn => 0},
   ]],
) {
  test {
    my $c = shift;
    my $tokenizer = Web::Temma::Tokenizer->new;

    my $Tokens = [];
    $tokenizer->ontokens (sub {
      my ($tokenizer, $tokens) = @_;
      push @$Tokens, @$tokens;

      if (($tokens->[-1]->{tag_name} || '') eq 'xmp') {
        return 'RAWTEXT state';
      } else {
        return undef;
      }
    });

    my $doc = new Web::DOM::Document;
    $tokenizer->parse_char_string ($test->[0] => $doc);
    eq_or_diff $Tokens, $test->[1];
    done $c;
  };
}

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
