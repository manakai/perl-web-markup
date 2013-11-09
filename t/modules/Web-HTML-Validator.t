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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
