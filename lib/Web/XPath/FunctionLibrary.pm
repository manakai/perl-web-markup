package Web::XPath::FunctionLibrary;
use strict;
use warnings;
our $VERSION = '1.0';

## Core function library <http://www.w3.org/TR/xpath/#corelib>.

my $Functions = {
  string => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      if (@$args) {
        return $self->to_string ($args->[0]); # or undef;
      } else {
        return $self->to_string ({type => 'node-set', value => [$ctx->{node}]});
      }
    },
  }, # string
}; # $Functions

sub get_argument_number ($$$) {
  my (undef, $nsurl, $ln) = @_;
  return undef if defined $nsurl;
  return undef unless $Functions->{$ln};
  return $Functions->{$ln}->{args};
} # get_argument_number

sub get_code ($$$) {
  my (undef, $nsurl, $ln) = @_;
  return undef if defined $nsurl;
  return undef unless $Functions->{$ln};
  return $Functions->{$ln}->{code};
} # get_code

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
