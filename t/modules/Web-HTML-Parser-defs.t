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
    my $def = $defs->{elements}->{$nsurl}->{$ln};
    test {
      my $c = shift;
      my $cat = Web::HTML::Parser::get_el_category ($nsurl, $ln);
      my $expected = $def->{parser_category} || 'ordinary';
      if ($expected eq 'special') {
        ok $cat & SPECIAL;
      } elsif ($expected eq 'formatting') {
        ok $cat & Web::HTML::Parser::FORMATTING_EL ();
      } else {
        ok not $cat & (SPECIAL | Web::HTML::Parser::FORMATTING_EL ());
      }
      done $c;
    } n => 1, name => [$nsurl, $ln, 'parser_category'];
    test {
      my $c = shift;
      my $cat = Web::HTML::Parser::get_el_category ($nsurl, $ln);
      is !!($cat & Web::HTML::Parser::SCOPING_EL ()),
         !!$def->{parser_scoping}, 'in scope';
      is !!($cat & Web::HTML::Parser::SCOPING_EL () or ($nsurl eq 'http://www.w3.org/1999/xhtml' and ($ln eq 'ul' or $ln eq 'ol'))),
         !!$def->{parser_li_scoping}, 'in list scope';
      is !!($cat & Web::HTML::Parser::BUTTON_SCOPING_EL ()),
         !!$def->{parser_button_scoping}, 'in button scope';
      is !!($cat & Web::HTML::Parser::TABLE_SCOPING_EL ()),
         !!$def->{parser_table_scoping}, 'in table scope';
      is !!($cat & Web::HTML::Parser::TABLE_ROWS_SCOPING_EL ()),
         !!$def->{parser_table_body_scoping}, 'in table body scope';
      is !!($cat & Web::HTML::Parser::TABLE_ROW_SCOPING_EL ()),
         !!$def->{parser_table_row_scoping}, 'in table row scope';
      is !!($cat == Web::HTML::Parser::OPTGROUP_EL () or
            $cat == Web::HTML::Parser::OPTION_EL ()),
         !!$def->{parser_select_non_scoping}, 'in select scope';
      done $c;
    } n => 7, name => [$nsurl, $ln, 'scoping'];
  }
}

test {
  my $c = shift;
  my $defined = {};
  for (
    Web::HTML::Parser::A_EL (),
    Web::HTML::Parser::ADDRESS_DIV_EL (),
    Web::HTML::Parser::MISC_SCOPING_EL (),
    Web::HTML::Parser::MISC_SPECIAL_EL (),
    Web::HTML::Parser::FORMATTING_EL (),
    Web::HTML::Parser::BODY_EL (),
    Web::HTML::Parser::BUTTON_EL (),
    Web::HTML::Parser::CAPTION_EL (),
    Web::HTML::Parser::COLGROUP_EL (),
    Web::HTML::Parser::DTDD_EL (),
    Web::HTML::Parser::FORM_EL (),
    Web::HTML::Parser::FRAMESET_EL (),
    Web::HTML::Parser::HEADING_EL (),
    Web::HTML::Parser::HEAD_EL (),
    Web::HTML::Parser::HTML_EL (),
    Web::HTML::Parser::LI_EL (),
    Web::HTML::Parser::NOBR_EL (),
    Web::HTML::Parser::OPTGROUP_EL (),
    Web::HTML::Parser::OPTION_EL (),
    Web::HTML::Parser::P_EL (),
    Web::HTML::Parser::RUBY_COMPONENT_EL (),
    Web::HTML::Parser::RUBY_EL (),
    Web::HTML::Parser::SELECT_EL (),
    Web::HTML::Parser::TABLE_EL (),
    Web::HTML::Parser::TEMPLATE_EL (),
    Web::HTML::Parser::TABLE_ROW_GROUP_EL (),
    Web::HTML::Parser::TABLE_CELL_EL (),
    Web::HTML::Parser::TABLE_ROW_GROUP_EL (),
    Web::HTML::Parser::TABLE_ROW_EL (),
    Web::HTML::Parser::MML_AXML_EL (),
    Web::HTML::Parser::MML_TEXT_INTEGRATION_EL (),
    Web::HTML::Parser::SVG_INTEGRATION_EL (),
    Web::HTML::Parser::SVG_SCRIPT_EL (),
  ) {
    ok 1 if not $defined->{$_};
    $defined->{$_} = 1;
  }
  done $c;
} name => 'terminals';

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
