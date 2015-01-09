use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::DOM::Document;
use Web::HTML::Validator;

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p>a</p>});
  my $val = Web::HTML::Validator->new;
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->check_node ($doc);
  eq_or_diff $errors, [{
    level => 'i',
    type => 'xml:no DTD validation',
    node => $doc,
  }, {
    level => 'w',
    type => 'unknown namespace element',
    node => $doc->document_element,
    value => '',
  }];
  done $c;
} n => 1, name => 'no DOCTYPE';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<p>a</p>});
  my $val = Web::HTML::Validator->new;
  $val->force_dtd_validation (1);
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->check_node ($doc);
  eq_or_diff $errors, [{
    level => 'm',
    type => 'VC:Element Valid:declared',
    node => $doc->document_element,
    value => 'p',
  }, {
    level => 'w',
    type => 'unknown namespace element',
    node => $doc->document_element,
    value => '',
  }];
  done $c;
} n => 1, name => 'no DOCTYPE, force';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE p><p>a</p>});
  my $val = Web::HTML::Validator->new;
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->check_node ($doc);
  eq_or_diff $errors, [{
    level => 'm',
    type => 'VC:Element Valid:declared',
    node => $doc->document_element,
    value => 'p',
  }, {
    level => 'w',
    type => 'unknown namespace element',
    node => $doc->document_element,
    value => '',
  }];
  done $c;
} n => 1, name => 'with empty DOCTYPE';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{<!DOCTYPE p [<!ELEMENT p (#PCDATA)>]><p>a</p>});
  my $val = Web::HTML::Validator->new;
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->check_node ($doc);
  eq_or_diff $errors, [{
    level => 'w',
    type => 'unknown namespace element',
    node => $doc->document_element,
    value => '',
  }];
  done $c;
} n => 1, name => 'with DOCTYPE, valid';

run_tests;

=head1 LICENSE

Copyright 2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
