use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use NanoDOM;

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el1 = $doc->create_element_ns (undef, [undef, 'element']);
  is $el1->tag_name, 'element';
  is $el1->manakai_tag_name, 'element';

  $doc->manakai_is_html (1);
  is $el1->tag_name, 'element';
  is $el1->manakai_tag_name, 'element';
  done $c;
} n => 4, name => '_element_tag_name_xml_lowercase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el1 = $doc->create_element_ns (undef, [undef, 'eleMent']);
  is $el1->tag_name, 'eleMent';
  is $el1->manakai_tag_name, 'eleMent';

  $doc->manakai_is_html (1);
  is $el1->tag_name, 'eleMent';
  is $el1->manakai_tag_name, 'eleMent';
  done $c;
} n => 4, name => '_element_tag_name_xml_mixcase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el1 = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'element']);
  is $el1->tag_name, 'element';
  is $el1->manakai_tag_name, 'element';

  $doc->manakai_is_html (1);
  is $el1->tag_name, 'ELEMENT';
  is $el1->manakai_tag_name, 'element';
  done $c;
} n => 4, name => '_element_tag_name_html_lowercase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el1 = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'eleMent']);
  is $el1->tag_name, 'eleMent';
  is $el1->manakai_tag_name, 'eleMent';

  $doc->manakai_is_html (1);
  is $el1->tag_name, 'ELEMENT';
  is $el1->manakai_tag_name, 'eleMent';
  done $c;
} n => 4, name => '_element_tag_name_html_mixcase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el = $doc->create_element_ns (undef, [undef, 'div']);
  $el->set_attribute_ns (undef, [undef, 'attribute']);
  is $el->get_attribute_node_ns (undef, 'attribute')->name, 'attribute';
  is $el->get_attribute_node_ns (undef, 'attribute')->manakai_name, 'attribute';

  $doc->manakai_is_html (1);
  is $el->get_attribute_node_ns (undef, 'attribute')->name, 'attribute';
  is $el->get_attribute_node_ns (undef, 'attribute')->manakai_name, 'attribute';
  done $c;
} n => 4, name => '_attr_name_xml_lowercase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el = $doc->create_element_ns (undef, [undef, 'div']);
  $el->set_attribute_ns (undef, [undef, 'attriBute']);
  is $el->get_attribute_node_ns (undef, 'attriBute')->name, 'attriBute';
  is $el->get_attribute_node_ns (undef, 'attriBute')->manakai_name, 'attriBute';

  $doc->manakai_is_html (1);
  is $el->get_attribute_node_ns (undef, 'attriBute')->name, 'attriBute';
  is $el->get_attribute_node_ns (undef, 'attriBute')->manakai_name, 'attriBute';
  done $c;
} n => 4, name => '_attr_name_xml_mixcase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'div']);
  $el->set_attribute_ns (undef, [undef, 'attribute']);
  is $el->get_attribute_node_ns (undef, 'attribute')->name, 'attribute';
  is $el->get_attribute_node_ns (undef, 'attribute')->manakai_name, 'attribute';

  $doc->manakai_is_html (1);
  is $el->get_attribute_node_ns (undef, 'attribute')->name, 'attribute';
  is $el->get_attribute_node_ns (undef, 'attribute')->manakai_name, 'attribute';
  done $c;
} n => 4, name => '_attr_name_html_lowercase';

test {
  my $c = shift;
  my $doc = NanoDOM::Document->new;
  my $el = $doc->create_element_ns (q<http://www.w3.org/1999/xhtml>, [undef, 'div']);
  $el->set_attribute_ns (undef, [undef, 'attriBute']);
  is $el->get_attribute_node_ns (undef, 'attriBute')->name, 'attriBute';
  is $el->get_attribute_node_ns (undef, 'attriBute')->manakai_name, 'attriBute';

  $doc->manakai_is_html (1);
  is $el->get_attribute_node_ns (undef, 'attriBute')->name, 'attriBute';
  is $el->get_attribute_node_ns (undef, 'attriBute')->manakai_name, 'attriBute';
  done $c;
} n => 4, name => '_attr_name_html_mixcase';

run_tests;

=head1 LICENSE

Copyright 2009-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
