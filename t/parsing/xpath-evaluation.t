use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::HTCT::Parser;
use Test::Differences;
use Web::XPath::Parser;
use Web::XPath::Evaluator;

for my $f (grep { -f and /\.dat$/ } file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'xpath', 'evaluation')->children) {
  for_each_test ($f->stringify, {
    data => {is_prefixed => 1},
    errors => {is_list => 1},
    result => {is_prefixed => 1},
  }, sub {
    my $test = shift;

    test {
      my $c = shift;

      my $node; # XXX

      my $parser = Web::XPath::Parser->new;
      my $parsed = $parser->parse_char_string_as_expression
          ($test->{data}->[0]);

      my $evaluator = Web::XPath::Evaluator->new;
      my @error;
      $evaluator->onerror (sub {
        my %args = @_;
        push @error, join ';', $args{level}, $args{type}, $args{value} // '';
      });
      my $result = $evaluator->evaluate ($parsed, $node);

      my $actual;
      if (not defined $result) {
        #
      } elsif ($result->{type} eq 'number') {
        $actual = $result->{value};
      } elsif ($result->{type} eq 'boolean') {
        $actual = $result->{value} ? 'true' : 'false';
      } elsif ($result->{type} eq 'string') {
        $actual = '"' . $result->{value} . '"';
      } elsif ($result->{type} eq 'node-set') {
        die;
      } else {
        die "Unknown result value type |$result->{type}|";
      }

      eq_or_diff $actual, $test->{result}->[0];
      eq_or_diff \@error, $test->{errors}->[0] || [];

      done $c;
    } n => 2, name => [$f->basename, $test->{data}->[0]];
  });
} # $f

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
