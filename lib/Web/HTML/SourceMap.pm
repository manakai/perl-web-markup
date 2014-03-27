package Web::HTML::SourceMap;
use strict;
use warnings;
no warnings 'utf8';
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

push @EXPORT, qw(sps_set_di);
sub sps_set_di ($$) {
  $_->[4] = $_[1] for @{$_[0]};
} # sps_set_di

push @EXPORT, qw(sps_with_offset);
sub sps_with_offset ($$) {
  my $delta = $_[1];
  return [map { my $v = [@$_]; $v->[0] += $delta; $v } @{$_[0]}];
} # sps_add_offset

push @EXPORT, qw(lc_lc_mapper);
sub lc_lc_mapper ($$$) {
  my ($from_map => $to_map, $args) = @_;
  return if defined $args->{di}; # absolute
  
  my $line;
  my $column;
  if (defined $args->{column}) {
    $line = $args->{line};
    $column = $args->{column};
  } elsif (defined $args->{token}) {
    $line = $args->{token}->{line};
    $column = $args->{token}->{column};
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
    last if $pos < $_->[0];
    $q = $_;
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

push @EXPORT, qw(pos_to_lc);
sub pos_to_lc ($$) {
  my ($map, $pos) = @_;
  my $p;
  for (@$map) {
    last if $pos < $_->[0];
    $p = $_;
  }
  my %sp;
  if (defined $p and $pos <= $p->[0] + $p->[1]) {
    $sp{line} = $p->[2];
    $sp{column} = $p->[3] + $pos - $p->[0];
    $sp{di} = $p->[4];
  }
  return \%sp;
} # pos_to_lc

push @EXPORT, qw(node_to_text_and_tc_and_sps);
sub node_to_text_and_tc_and_sps ($) {
  my $node = $_[0];
  my @text;
  my @text_sps;
  my $text_delta = 0;
  my @tc;
  my @tc_sps;
  my $tc_delta = 0;
  for my $node (@{$node->child_nodes}) {
    my $nt = $node->node_type;
    if ($nt == 1) { # ELEMENT_NODE
      my @node = @{$node->child_nodes};
      while (@node) {
        my $node = shift @node;
        my $nt = $node->node_type;
        if ($nt == 1) { # ELEMENT_NODE
          unshift @node, @{$node->child_nodes};
        } elsif ($nt == 3) { # TEXT_NODE
          push @tc_sps, map {
            my $v = [@$_]; $v->[0] += $tc_delta; $v;
          } @{$node->get_user_data ('manakai_sps') or []};
          for ($node->data) {
            push @tc, $_;
            $tc_delta += length $_;
          }
        }
      }
    } elsif ($nt == 3) { # TEXT_NODE
      push @text_sps, map {
        my $v = [@$_]; $v->[0] += $text_delta; $v;
      } @{$node->get_user_data ('manakai_sps') || []};
      push @tc_sps, map {
        my $v = [@$_]; $v->[0] += $tc_delta; $v;
      } @{$node->get_user_data ('manakai_sps') || []};
      for ($node->data) {
        push @text, $_;
        push @tc, $_;
        $tc_delta += $_, $text_delta += $_ for length $_;
      }
    }
  }
  return ((join '', @text), (join '', @tc), \@text_sps, \@tc_sps);
} # node_to_text_and_tc_and_sps

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
