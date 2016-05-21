package Web::XML::Parser::ForValidatorChecker;
use strict;
use warnings;
our $VERSION = '2.0';
use Web::XML::Parser::MinimumChecker;
push our @ISA, qw(Web::XML::Parser::MinimumChecker);
use Web::XML::_CharClasses;

sub check_hidden_name ($%) {
  my $class = shift;
  return $class->check_name (@_);
} # check_hidden_name

sub check_hidden_qname ($%) {
  my $class = shift;
  return $class->check_qname (@_);
} # check_hidden_qname

sub check_hidden_nmtoken ($%) {
  my $class = shift;
  return $class->check_nmtoken (@_);
} # check_hidden_nmtoken

sub check_hidden_pi_target ($%) {
  my $class = shift;
  my %args = @_;
  if ($args{name} =~ /\A[Xx][Mm][Ll]\z/) {
    $args{onerror}->(type => 'xml:pi:target:xml',
                     level => 'm',
                     value => $args{name});
  } else {
    return $class->check_name (@_);
  }
} # check_hidden_pi_target

sub check_hidden_pubid ($%) {
  my $class = shift;
  return $class->check_pubid (@_);
} # check_hidden_pubid

# XXX validate system ID
# XXX suggested name rules
# XXX Name MUST be NCName

sub check_ncnames ($%) {
  my ($class, %args) = @_;
  for (keys %{$args{names}}) {
    if (not /\A\p{InNCNameStartChar}\p{InNCNameChar}*\z/) {
      $args{onerror}->(type => 'xml:not ncname',
                       di => $args{names}->{$_}->{di},
                       index => $args{names}->{$_}->{index},
                       value => $_,
                       level => 'm');
    }
  }
} # check_ncnames

1;

=head1 LICENSE

Copyright 2003-2016 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
