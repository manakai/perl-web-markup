package Web::XPath::VariableBindings;
use strict;
use warnings;
our $VERSION = '1.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub has_variable ($$$) {
  my ($self, $nsurl, $ln) = @_;
  if (defined $nsurl) {
    return !!$self->{var}->{$nsurl}->{$ln};
  } else {
    return !!$self->{default_var}->{$ln};
  }
} # has_variable

sub get_variable ($$$) {
  my ($self, $nsurl, $ln) = @_;
  if (defined $nsurl) {
    return $self->{var}->{$nsurl}->{$ln}; # or undef
  } else {
    return $self->{default_var}->{$ln}; # or undef
  }
} # get_variable

sub set_variable ($$$$) {
  my ($self, $nsurl, $ln, $value) = @_;
  if (defined $nsurl) {
    $self->{var}->{$nsurl}->{$ln} = $value;
  } else {
    $self->{default_var}->{$ln} = $value;
  }
} # set_variable

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
