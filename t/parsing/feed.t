use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Data::Dumper;
use Test::More;
use Test::X1;
use Test::HTCT::Parser;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::Feed::Parser;
use JSON::PS;

sub cleanup ($);
sub cleanup ($) {
  my $parsed = $_[0];
  my @key = keys %$parsed;
  for (@key) {
    if (not defined $parsed->{$_}) {
      delete $parsed->{$_};
    } elsif (ref $parsed->{$_} eq 'ARRAY') {
      if (not @{$parsed->{$_}}) {
        delete $parsed->{$_};
      } else {
        for my $obj (@{$parsed->{$_}}) {
          cleanup $obj;
        }
      }
    } elsif (ref $parsed->{$_} eq 'HASH') {
      if (not keys %{$parsed->{$_}}) {
        delete $parsed->{$_};
      }
    } elsif (UNIVERSAL::isa ($parsed->{$_}, 'Web::DOM::Node')) {
      $parsed->{$_} = $parsed->{$_}->inner_html;
    } elsif (UNIVERSAL::isa ($parsed->{$_}, 'Web::DateTime')) {
      $parsed->{$_} = $parsed->{$_}->to_global_date_and_time_string;
    }
  }
} # cleanup

my $data_path = path (__FILE__)->parent->parent->parent
    ->child ('t_deps/tests/feed/parsing');
for my $path (($data_path->children (qr/\.dat$/))) {
  for_each_test ($path, {
    data => {is_prefixed => 1},
    parsed => {is_prefixed => 1},
  }, sub {
    my $test = shift;
    test {
      my $c = shift;
      my $doc = new Web::DOM::Document;
      $doc->manakai_set_url (q<https://base/>);
      my $p = new Web::XML::Parser;
      $p->onerror (sub { });
      $p->parse_char_string ($test->{data}->[0] => $doc);
      my $parser = new Web::Feed::Parser;
      my $parsed = $parser->parse_document ($doc);

      if (defined $parsed) {
        cleanup $parsed;
      }
      my $expected = json_chars2perl $test->{parsed}->[0];
      is +(perl2json_chars_for_record $parsed), (perl2json_chars_for_record $expected);
      done $c;
    } n => 1, name => [$path->relative ($data_path), $test->{data}->[0]];
  });
}

run_tests;

## License: Public Domain.
