package Web::HTML::SourceMap;
use strict;
use warnings;
our $VERSION = '1.0';
use Exporter::Lite;

our @EXPORT;

push @EXPORT, qw(create_pos_lc_map);
sub create_pos_lc_map ($) {
  my @map;
  my $pos = 0;
  my $l = 1;
  my $c = 1;
  for (split /(\x0D\x0A?|\x0A)/, $_[0], -1) {
    if (/[\x0D\x0A]/) {
      $l++;
      push @map, [$pos, length $_, $l, 0];
      $c = 1;
      $pos += length $_;
    } else {
      my $length = length $_;
      push @map, [$pos, $length, $l, $c];
      $c += $length;
      $pos += $length;
    }
  }
  unless (@map) {
    unshift @map, [0, 0, 1, 1];
  }
  return \@map;
} # create_pos_lc_map

push @EXPORT, qw(lc_lc_mapper);
sub lc_lc_mapper ($$$) {
  my ($from_map => $to_map, $args) = @_;
  return if defined $args->{di}; # absolute
  
  my $line;
  my $column;
  if (defined $args->{token}) {
    $line = $args->{token}->{line};
    $column = $args->{token}->{column};
  } else {
    $line = $args->{line};
    $column = $args->{column};
  }
  return unless defined $column;

  $args->{di} = -1;
  my $p;
  for (@$from_map) {
    if ($_->[2] < $line or
        $_->[2] == $line and $_->[3] <= $column) {
      $p = $_;
    } else {
      last;
    }
  }
  return unless defined $p;

  my $pos = $p->[0] + ($column - $p->[3]);
  my $q;
  for (@$to_map) {
    if ($pos < $_->[0]) {
      last;
    } else {
      $q = $_;
    }
  }
  if (defined $q and $pos <= $q->[0] + $q->[1]) {
    $args->{line} = $q->[2];
    $args->{column} = $q->[3] + $pos - $q->[0];
    $args->{di} = $q->[4];
  }
} # lc_lc_mapper

push @EXPORT, qw(lc_lc_mapper_for_sps);
sub lc_lc_mapper_for_sps ($$$) {
  my ($from_map => $to_map, $sps) = @_;
  for (@{$sps or []}) {
    next if defined $_->[4];
    my $p = {line => $_->[2], column => $_->[3]};
    lc_lc_mapper $from_map => $to_map, $p;
    $_->[2] = $p->{line};
    $_->[3] = $p->{column};
    $_->[4] = $p->{di} if defined $p->{di};
  }
} # lc_lc_mapper_for_sps

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
