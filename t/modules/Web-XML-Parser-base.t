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

  my $input = {
    '' => q{<!DOCTYPE a SYSTEM "http://dtd/" [
      <!ENTITY hoge SYSTEM "a" NDATA x>
      <!NOTATION x SYSTEM "b">
      <!ENTITY % e2 '
        <!ENTITY ent2 SYSTEM "" NDATA x>
        <!NOTATION ent2 SYSTEM "">
        <!ENTITY foo "&#x25;empty;">
      '>
    ]><a attr="">&ge1;</a>},
    'http://dtd/' => q{
      <!ENTITY % empty SYSTEM "http://empty/">
      <!ENTITY dtd1 SYSTEM "b" NDATA x>
      <!NOTATION dtd1 SYSTEM "b" %empty;>
      <!ENTITY % p SYSTEM "http://ent1/"> %p;
      <!ENTITY ge2 "">
    },
    'http://ent1/' => q{
      <!ENTITY ent1 SYSTEM "b" NDATA x>
      <!NOTATION ent1 SYSTEM "b">
      %e2;
      <!ENTITY ge1 SYSTEM "http://ge1/">
    },
    'http://empty/' => q{},
    'http://ge1/' => q{<p>&ge2;</p>},
    'http://ge2/' => q{<p></p>},
  };
  my $expected = {
    entities => {
      hoge => q<about:blank#document>,
      dtd1 => q<http://dtd/>,
      ent1 => q<http://ent1/>,
      ent2 => q<http://ent1/>,
    },
    notations => {
      x => q<about:blank#document>,
      dtd1 => q<http://dtd/>,
      ent1 => q<http://ent1/>,
      ent2 => q<http://ent1/>,
    },
    resolution => {
      '' => q<about:blank#document>,
      p => q<http://dtd/>,
      empty => q<http://dtd/>,
      ge1 => q<http://ent1/>,
      ge2 => q<http://dtd/>,
    },
  };

  my $parser = Web::XML::Parser->new;
  $parser->onerror (sub { });
  $parser->onextentref (sub {
    my ($self, $data, $sub) = @_;
    $sub->parse_bytes_start (undef, $self);
    is $sub->di_data_set->[$data->{entity}->{base_url_di}]->{url},
       $expected->{resolution}->{$data->{entity}->{name} || ''},
       "base URL of entity @{[$data->{entity}->{name} || '']}";
    $sub->di_data_set->[$sub->di] = {
      url => $data->{entity}->{system_identifier},
    };
    $sub->parse_bytes_feed ($input->{$data->{entity}->{system_identifier}});
    $sub->parse_bytes_end;
  });
  $parser->parse_chars_start ($doc);
  $parser->di_data_set->[$parser->di]->{url} = 'about:blank#document';
  $parser->parse_chars_feed ($input->{''});
  $parser->parse_chars_end;

  for my $name (keys %{$expected->{entities} or {}}) {
    my $ent = $doc->doctype->entities->{$name};
    is $ent->declaration_base_uri, $expected->{entities}->{$name};
  }
  for my $name (keys %{$expected->{notations} or {}}) {
    my $ent = $doc->doctype->notations->{$name};
    is $ent->declaration_base_uri, $expected->{notations}->{$name};
  }
  done $c;
} n => 13, name => 'declaration_base_uri';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
