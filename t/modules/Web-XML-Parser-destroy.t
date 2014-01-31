use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::XML::Parser;
use Web::DOM::Document;

test {
  my $c = shift;
  my $parser_destroy_called = 0;
  my $doc_destroy_called = 0;

  no warnings 'redefine';
  no warnings 'once';
  local *Web::XML::Parser::DESTROY = sub { $parser_destroy_called++ };
  local *Web::DOM::Document::DESTROY = sub { $doc_destroy_called++ };

  my $doc = new Web::DOM::Document;
  Web::XML::Parser->new->parse_char_string (q<<p>abc</p>> => $doc);

  is $parser_destroy_called, 1;

  undef $doc;
  is $doc_destroy_called, 1;

  done $c;
} n => 2, name => 'xml_parser_gc';

run_tests;

=head1 LICENSE

Copyright 2009-2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
