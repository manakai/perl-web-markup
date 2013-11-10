use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Web::DOM::Document;
use Web::HTML::Validator;

for my $attr (qw(xml:lang xml:space xml:base)) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element_ns (undef, 'br');
    $el->set_attribute_ns (undef, [undef, $attr] => '! ?');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'status:non-standard:element', # XX this info is not necessary
          node => $el,
          level => 'i'},
         {type => 'unknown element',
          node => $el,
          level => 'u'},
         {type => 'unknown attribute', # XXX attribute not defined
          node => $el->attributes->[0],
          level => 'u'},
         {type => 'status:non-standard:attr', # XXX this info is not necessary
          node => $el->attributes->[0],
          level => 'i'}];
    done $c;
  } n => 1, name => [$attr, 'in no namespace'];
} # $attr

for my $test (
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'hoge'],
          'http://www.w3.org/XML/1998/namespace');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/XML/1998/namespace',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'hoge'],
          'http://www.w3.org/2000/xmlns/');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/2000/xmlns/',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'xml'],
          'hoge');
   },
   {type => 'Reserved Prefixes and Namespace Names:Prefix',
    text => 'xml',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'xmlns'],
          'hoge');
   },
   {type => 'Reserved Prefixes and Namespace Names:Prefix',
    text => 'xmlns',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'xmlns'],
          '');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/2000/xmlns/',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'xmlns'],
          'http://fuga/');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/2000/xmlns/',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'fpoo'],
          'http://fuga/');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/2000/xmlns/',
    level => 'm'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          [undef, 'xmlns'],
          'http://www.w3.org/2000/xmlns/');
   },
   {type => 'Reserved Prefixes and Namespace Names:Name',
    text => 'http://www.w3.org/2000/xmlns/',
    level => 'm'}],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element_ns (undef, 'foo');
    $test->[0]->($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'status:non-standard:element', # XX this info is not necessary
          node => $el,
          level => 'i'},
         {type => 'unknown element',
          node => $el,
          level => 'u'},
         {%{$test->[1]}, node => $el->attributes->[0]}];
    done $c;
  } n => 1, name => [$test->[1]->{type}, $test->[1]->{text}];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->strict_error_checking (0);
  my $el = $doc->create_element_ns (undef, 'foo');
  $el->set_attribute_ns
      ('http://www.w3.org/2000/xmlns/',
       ['xmlns', 'xmlns'],
       'http://www.w3.org/2000/xmlns/');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_element ($el);
  eq_or_diff \@error,
      [{type => 'status:non-standard:element', # XX this info is not necessary
        node => $el,
        level => 'i'},
       {type => 'unknown element',
        node => $el,
        level => 'u'},
       {type => 'Reserved Prefixes and Namespace Names:Prefix',
        text => 'xmlns',
        node => $el->attributes->[0],
        level => 'm'},
       {type => 'Reserved Prefixes and Namespace Names:Name',
        text => 'http://www.w3.org/2000/xmlns/',
        node => $el->attributes->[0],
        level => 'm'}];
  done $c;
} n => 1, name => ['xmlns:xmlns'];

for my $version (qw(1.0 1.1 1.2 foo)) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->xml_version ($version);
    my $el = $doc->create_element_ns (undef, 'foo');
    $el->set_attribute_ns ('http://www.w3.org/2000/xmlns/', 'xmlns' => '');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'status:non-standard:element', # XX this info is not necessary
          node => $el,
          level => 'i'},
         {type => 'unknown element',
          node => $el,
          level => 'u'}];
    done $c;
  } n => 1, name => ['xml=""', $version];

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->xml_version ($version);
    my $el = $doc->create_element_ns (undef, 'foo');
    $el->set_attribute_ns ('http://www.w3.org/2000/xmlns/', 'xmlns:abc' => '');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'status:non-standard:element', # XX this info is not necessary
          node => $el,
          level => 'i'},
         {type => 'unknown element',
          node => $el,
          level => 'u'},
         {type => 'xmlns:* empty',
          node => $el->attributes->[0],
          level => 'm'}];
    done $c;
  } n => 1, name => ['xmlns:abc=""', $version];
} # $version

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
