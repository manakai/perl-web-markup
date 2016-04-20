use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Web::DOM::Document;
use Web::HTML::Dumper;

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (q{<!DOCTYPE html><html><body>ff<p clasS=Abc>xx<img/>});
  
  is dumptree $doc, q{<!DOCTYPE html>
<html>
  <head>
  <body>
    "ff"
    <p>
      class="Abc"
      "xx"
      <img>
};
  done $c;
} n => 1;

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  my $el1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'p');
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'q');
  $el->append_child ($el1);
  $el->content->append_child ($el2);
  
  is dumptree $el, q{<p>
content
  <q>
};
  done $c;
} n => 1, name => 'dump <template>';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el0 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'hoge');
  my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'template');
  $el0->append_child ($el);
  my $el1 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'p');
  my $el2 = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', 'q');
  $el->append_child ($el1);
  $el->content->append_child ($el2);
  
  is dumptree $el0, q{<template>
  <p>
  content
    <q>
};
  done $c;
} n => 1, name => 'dump parent of <template>';

run_tests;

=head1 LICENSE

Copyright 2012-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
