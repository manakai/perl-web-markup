use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use JSON qw(jsonToObj);

my $parser_f = file (__FILE__)->dir->parent->parent
    ->file ('lib', 'Web', 'HTML', 'Parser.pm');

my $defs_f = file (__FILE__)->dir->parent->parent
    ->file ('local', 'elements.json');
my $defs = jsonToObj (scalar $defs_f->slurp);

my $script = $parser_f->slurp . q{

sub get_el_category ($$) {
  my ($nsurl, $ln) = @_;
  if ($nsurl eq 'http://www.w3.org/1999/xhtml') {
    return $el_category->{$ln} || 0;
  } else {
    return $el_category_f->{$nsurl || ''}->{$ln} || Web::HTML::Parser::FOREIGN_EL;
  }
}

1;

};
eval $script or die $@;

sub SPECIAL () { (Web::HTML::Parser::SPECIAL_EL () |
                  Web::HTML::Parser::SCOPING_EL () |
                  Web::HTML::Parser::BUTTON_SCOPING_EL ()) }

test {
  my $c = shift;
  ok $defs->{elements}->{'http://www.w3.org/1999/xhtml'}->{html}->{parser_category};
  ok $defs->{elements}->{'http://www.w3.org/2000/svg'}->{foreignObject}->{parser_category};
  done $c;
} n => 2, name => 'check data';

for my $nsurl (keys %{$defs->{elements}}) {
  for my $ln (keys %{$defs->{elements}->{$nsurl}}) {
    test {
      my $c = shift;
      my $cat = Web::HTML::Parser::get_el_category ($nsurl, $ln);
      my $expected = $defs->{elements}->{$nsurl}->{$ln}->{parser_category} || 'ordinary';
      if ($expected eq 'special') {
        ok $cat & SPECIAL;
      } elsif ($expected eq 'formatting') {
        ok $cat & Web::HTML::Parser::FORMATTING_EL ();
      } else {
        ok not $cat & (SPECIAL | Web::HTML::Parser::FORMATTING_EL ());
      }
      done $c;
    } n => 1, name => [$nsurl, $ln];
  }
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
