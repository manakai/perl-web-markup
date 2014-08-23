package test::Web::HTML::Tokenizer;
use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Test::HTCT::Parser;
use Web::HTML::Tokenizer;
use Web::HTML::Defs;

sub _abort : Test(10) {
  my $tokenizer = Web::HTML::Tokenizer->new;

  my $eof;

  $tokenizer->{chars} = [];
  $tokenizer->{chars_pos} = 0;
  $tokenizer->{chars_pull_next} = sub { return not $eof };
  $tokenizer->{line_prev} = $tokenizer->{line} = 1;
  $tokenizer->{column_prev} = -1;
  $tokenizer->{column} = 0;
  $tokenizer->{token} = [];
  $tokenizer->_initialize_tokenizer;

  my $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  push @{$tokenizer->{chars}}, split //, "<!DOC";
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  push @{$tokenizer->{chars}}, split //, "TYPE html>";
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => DOCTYPE_TOKEN, name => 'html',
                      line => 1, column => 1};

  push @{$tokenizer->{chars}}, split //, "<";
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  push @{$tokenizer->{chars}}, split //, 'html';
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  push @{$tokenizer->{chars}}, split //, '>';
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => START_TAG_TOKEN, tag_name => 'html',
                      line => 1, column => 16, data => undef};

  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => ABORT_TOKEN, debug => 'abort char'};

  $eof = 1;
  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => END_OF_FILE_TOKEN,
                      line => 1, column => 22};

  $token = $tokenizer->_get_next_token;
  eq_or_diff $token, {type => END_OF_FILE_TOKEN,
                      line => 1, column => 22};
} # _abort

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
