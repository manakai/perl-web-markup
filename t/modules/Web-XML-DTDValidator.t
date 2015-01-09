use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::XML::DTDValidator;
use Web::DOM::Document;

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<x></x>});
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [{level => 'm',
                        type => 'VC:Element Valid:declared',
                        value => 'x',
                        node => $doc->document_element}];
  done $c;
} n => 1, name => 'element not declared (no DOCTYPE)';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE x><x></x>});
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [{level => 'm',
                        type => 'VC:Element Valid:declared',
                        value => 'x',
                        node => $doc->document_element}];
  done $c;
} n => 1, name => 'element not declared (with DOCTYPE)';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE x [<!ELEMENT x ANY>]><x></x>});
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [];
  done $c;
} n => 1, name => 'valid';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE x []><x></x>});
  my $et = $doc->create_element_type_definition ('x');
  $doc->doctype->set_element_type_definition_node ($et);
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [{level => 'w',
                        type => 'xml:dtd:element:no content model',
                        node => $et},
                       {level => 'm',
                        type => 'VC:Element Valid:declared',
                        node => $doc->document_element, value => 'x'}];
  done $c;
} n => 1, name => 'empty element type';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE p [<!ELEMENT p (#PCDATA)><!ATTLIST p ab ENTITY #IMPLIED>]><p ab="dd">a</p>});
  my $ent = $doc->create_general_entity ('dd');
  $doc->doctype->set_general_entity_node ($ent);
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [{
    level => 'm',
    type => 'VC:Entity Name:unparsed',
    node => $doc->document_element->attributes->[0],
    value => 'dd',
  }];
  done $c;
} n => 1, name => 'ENTITY attr / parsed entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE p [<!ELEMENT p (#PCDATA)><!ATTLIST p ab ENTITIES #IMPLIED>]><p ab="dd">a</p>});
  my $ent = $doc->create_general_entity ('dd');
  $doc->doctype->set_general_entity_node ($ent);
  my $validator = Web::XML::DTDValidator->new;
  my $errors = [];
  $validator->onerror (sub {
    push @$errors, {@_};
  });
  $validator->validate_document ($doc);
  eq_or_diff $errors, [{
    level => 'm',
    type => 'VC:Entity Name:unparsed',
    node => $doc->document_element->attributes->[0],
    value => 'dd',
  }];
  done $c;
} n => 1, name => 'ENTITIES attr / parsed entity';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
