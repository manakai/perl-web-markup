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

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;b</a>});
  $parser->parse_bytes_feed ('', start_parsing => 1);
  while (defined (my $req = $parser->parse_bytes_get_entity_req)) {
    if ($req) {
      $parser->parse_bytes_entity_start (undef);
      $parser->parse_bytes_entity_feed ('XYZ');
      $parser->parse_bytes_entity_end;
      $parser->parse_bytes_feed ('', start_parsing => 1);
    }
  }
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cXYZb</a>};
  done $c;
} n => 1, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_feed ('', start_parsing => 1);
  my $count = 0;
  while (defined (my $req = $parser->parse_bytes_get_entity_req)) {
    if ($req) {
      $parser->parse_bytes_entity_start (undef);
      $parser->parse_bytes_entity_feed ('XYZ');
      $parser->parse_bytes_entity_end;
      $parser->parse_bytes_feed ('', start_parsing => 1);
      $count++;
    }
  }
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cXYZvXYZb</a>};
  is $count, 2;
  done $c;
} n => 2, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_feed ('', start_parsing => 1);
  my $count = 0;
  while (defined (my $req = $parser->parse_bytes_get_entity_req)) {
    if ($req) {
      $parser->parse_bytes_entity_start (undef);
      $parser->parse_bytes_entity_feed ('X<p>Y</p>Z');
      $parser->parse_bytes_entity_end;
      $parser->parse_bytes_feed ('', start_parsing => 1);
      $count++;
    }
  }
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cX<p>Y</p>ZvX<p>Y</p>Zb</a>};
  is $count, 2;
  done $c;
} n => 2, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_feed ('', start_parsing => 1);
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cvb</a>};
  done $c;
} n => 1, name => 'an external entity - not expanded';

# XXX parse_bytes_ feed -> _entity_* -> _feed -> _end
# XXX nested entity

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
