use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::HTML::Parser;
use Web::DOM::Document;

test {
  my $c = shift;
  my $parser_destroy_called = 0;
  my $doc_destroy_called = 0;
  my $el_destroy_called = 0;

  no warnings 'redefine';
  no warnings 'once';
  require Web::HTML::Parser;
  local *Web::HTML::Parser::DESTROY = sub { $parser_destroy_called++ };
  local *Web::DOM::Document::DESTROY = sub { $doc_destroy_called++ };
  local *Web::DOM::Element::DESTROY = sub { $el_destroy_called++ };

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  my $el = $doc->create_element_ns (undef, [undef, 'p']);

  $el->inner_html (q[]);
  is $el_destroy_called, 1; # fragment parser's |Element|
  is $doc_destroy_called, 1; # fragment parser's |Document|

  is $parser_destroy_called, 1; # parser itself

  undef $el;
  is $el_destroy_called, 2; # $el
  undef $doc;
  is $doc_destroy_called, 2; # $doc
  is $el_destroy_called, 2;
  done $c;
} n => 6, name => 'html_fragment_parser_gc';

run_tests;

=head1 LICENSE

Copyright 2009-2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
