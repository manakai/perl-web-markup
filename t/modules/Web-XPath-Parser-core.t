use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'test-x1', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Test::XPathParser;
use Web::XPath::Parser;
use Web::XPath::FunctionLibrary;

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my $parsed = $parser->parse_char_string_as_expression ('string()');
  eq_or_diff $parsed, X LP [F undef, undef, 'string', [], []];
  done $c;
} n => 1, name => 'string ()';

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my $parsed = $parser->parse_char_string_as_expression ('string(12)');
  eq_or_diff $parsed, X LP [F undef, undef, 'string', [X LP [NUM 12, []]], []];
  done $c;
} n => 1, name => 'string (a)';

test {
  my $c = shift;
  my $parser = Web::XPath::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  my $parsed = $parser->parse_char_string_as_expression ('string(12, 4)');
  eq_or_diff $parsed, undef;
  eq_or_diff \@error, [{type => 'xpath:function:max',
                        level => 'm',
                        index => 13}];
  done $c;
} n => 2, name => 'string (a, b)';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
