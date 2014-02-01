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

  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;

  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ("<p a=b>ab<f");
  $parser->parse_bytes_feed (">a</f  >b");
  $parser->parse_bytes_feed ("");
  $parser->parse_bytes_feed ("</p> ");
  $parser->parse_bytes_end;

  is $doc->inner_html, q{<p xmlns="" a="b">ab<f>a</f>b</p>};

  done $c;
} n => 1, name => 'stream api';

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
