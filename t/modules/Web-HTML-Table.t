use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use NanoDOM;
use Web::HTML::Table;

sub serialize_node ($);
sub serialize_node ($) {
  my $obj = shift;
  if (not defined $obj or not ref $obj or ref $obj eq 'CODE') {
    return $obj;
  } elsif (ref $obj eq 'ARRAY') {
    return [map { serialize_node $_ } @$obj];
  } elsif (ref $obj eq 'HASH') {
    return {map { serialize_node $_ } %$obj};
  } elsif ($obj->isa ('NanoDOM::Node')) {
    return $obj->manakai_local_name . ' ' . $obj->text_content;
  } else {
    return $obj;
  }
} # serialize_node

sub cr ($) {
  my $s = shift;
  my $r = {};
  if ($s =~ s[^([dh]+)/?][]) {
    my $v = $1;
    $r->{has_data} = 1 if $v =~ /d/;
    $r->{has_header} = 1 if $v =~ /h/;
  }
  
  $r->{element} = $s if length $s;
  
  return $r;
} # cr

sub cell ($) {
  my $s = shift;
  my $r = {};

  if ($s =~ s[^(\d+),(\d+),(\d+),(\d+)/(.+?)(?:\s*->([^<>]+)<-)?$][]) {
    $r->{x} = $1+1-1;
    $r->{y} = $2+1-1;
    $r->{width} = $3+1-1;
    $r->{height} = $4+1-1;
    $r->{element} = $5;
    $r->{header_ids} = [split /\s+/, $6] if $6;

    if ($r->{element} =~ /^th/) {
      $r->{is_header} = 1;
      if ($r->{element} =~ s/^th\(([rc]g?)\)/th/) {
        $r->{scope} = {
          r => 'row', c => 'col', rg => 'rowgroup', cg => 'colgroup',
        }->{$1};
      } else {
        $r->{scope} = '';
      }
    }
  }
  
  return $r;
} # cell

sub rg ($) {
  my $s = shift;
  my $r = {};

  if ($s =~ s[^(\d+),(\d+),(\d+)/(.+)$][]) {
    $r->{x} = $1+1-1;
    $r->{y} = $2+1-1;
    $r->{height} = $3+1-1;
    $r->{element} = $4;
  }
  
  return $r;
} # rg

sub remove_tbody ($) {
  my $table_el = shift;
  $table_el->append_child ($table_el->first_child->first_child)
      while $table_el->first_child->first_child;
  $table_el->remove_child ($table_el->first_child); # tbody
} # remove_tbody

{
  for my $test (
    {
      input => q[<tr><td>1<td>2<tr><th>3<th>4],
      result => {
        column_group => [], column => [cr 'dh', cr 'dh'],
        row_group => [rg '0,0,2/tbody 1234', rg '0,0,2/tbody 1234'],
        row => [cr 'd/tr 12', cr 'h/tr 34'],
        cell => [
          [[cell '0,0,1,1/td 1'], [cell '0,1,1,1/th 3']],
          [[cell '1,0,1,1/td 2'], [cell '1,1,1,1/th 4']],
        ],
        width => 2, height => 2, element => 'table 1234',
      },
    },
    {
      input => q[<tr><td>1<td>2<tr><th>3<th>4],
      without_tbody => 1,
      result => {
        column_group => [], column => [cr 'dh', cr 'dh'],
        row_group => [], row => [cr 'd/tr 12', cr 'h/tr 34'],
        cell => [
          [[cell '0,0,1,1/td 1'], [cell '0,1,1,1/th 3']],
          [[cell '1,0,1,1/td 2'], [cell '1,1,1,1/th 4']],
        ],
        width => 2, height => 2, element => 'table 1234',
      },
    },
    {
      input => q[<tr><td id=a>1<td id=a>2<tr id=c><th id=b>3<th>4],
      without_tbody => 1,
      result => {
        column_group => [], column => [cr 'dh', cr 'dh'],
        row_group => [], row => [cr 'd/tr 12', cr 'h/tr 34'],
        cell => [
          [[cell '0,0,1,1/td 1'], [cell '0,1,1,1/th 3']],
          [[cell '1,0,1,1/td 2'], [cell '1,1,1,1/th 4']],
        ],
        width => 2, height => 2, element => 'table 1234',
      },
    },
    {
      input => q[<tr><td id=a>1<td id=a>2<tr id=c><th id=b>3<th>4],
      body => q[%s],
      without_tbody => 1,
      result => {
        column_group => [], column => [cr 'dh', cr 'dh'],
        row_group => [], row => [cr 'd/tr 12', cr 'h/tr 34'],
        cell => [
          [[cell '0,0,1,1/td 1'], [cell '0,1,1,1/th 3']],
          [[cell '1,0,1,1/td 2'], [cell '1,1,1,1/th 4']],
        ],
        id_cell => {
          a => cell '0,0,1,1/td 1',
          b => cell '0,1,1,1/th 3',
        },
        width => 2, height => 2, element => 'table 1234',
      },
    },
    {
      input => q[<tr><td id=a>1<td id=a>2<tr id=c><th id=b>3<th>4],
      body => q[<p id=b></p>%s<p id=a></p>],
      without_tbody => 1,
      result => {
        column_group => [], column => [cr 'dh', cr 'dh'],
        row_group => [], row => [cr 'd/tr 12', cr 'h/tr 34'],
        cell => [
          [[cell '0,0,1,1/td 1'], [cell '0,1,1,1/th 3']],
          [[cell '1,0,1,1/td 2'], [cell '1,1,1,1/th 4']],
        ],
        id_cell => {
          a => cell '0,0,1,1/td 1',
        },
        width => 2, height => 2, element => 'table 1234',
      },
    },
  ) {
    test {
      my $c = shift;
      my $doc = NanoDOM::Document->new;
      $doc->manakai_is_html (1);

      my $table_el;
      if ($test->{body}) {
        $doc->append_child
            ($doc->create_element_ns
                 ('http://www.w3.org/1999/xhtml', [undef, 'html']))
            ->inner_html (q[<head><body>]);
        my $body = $doc->last_child->last_child;
        my $body_inner = $test->{body};
        $body_inner =~ s[%s][<table></table>]g;
        $body->inner_html ($body_inner);
        my @node = ($body);
        while (@node) {
          my $node = shift @node;
          next unless $node->node_type == 1;
          if ($node->manakai_local_name eq 'table') {
            $table_el = $node;
            last;
          } else {
            push @node, @{$node->child_nodes};
          }
        }
      } else {
        $table_el = $doc->create_element_ns
            ('http://www.w3.org/1999/xhtml', [undef, 'table']);
      }
      $table_el->inner_html ($test->{input});
      remove_tbody $table_el if $test->{without_tbody};

      my $table = Web::HTML::Table->new->form_table ($table_el);
      eq_or_diff serialize_node $table, $test->{result};
      done $c;
    } n => 1, name => 'form_table';
  }
}

{
  for my $test (
    {
      input => q[<tr><th>1<th>2<tr><td>3<td>4],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '1,0,1,1/th 2']],
        [1, 2 => []],
        [2, 2 => []],
        [-1, 0 => []],
      ],
    },
    {
      input => q[<tr><th colspan=2>1<tr><td>3<td>4<tr><td>5<td>6],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,2,1/th 1']],
        [1, 1 => [cell '0,0,2,1/th 1']],
        [0, 2 => [cell '0,0,2,1/th 1']],
        [1, 2 => [cell '0,0,2,1/th 1']],
      ],
    },
    {
      input => q[<tr><th colspan=2>1<tr><td>3<td>4<td>5<td>6],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,2,1/th 1']],
        [1, 1 => [cell '0,0,2,1/th 1']],
        [2, 1 => []],
        [3, 1 => []],
      ],
    },
    {
      input => q[<tr><th>1<th>2<th>3<tr><th scope=row>4<td>5<td>6<tr><td>7<td>8<td>9],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [2, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '1,0,1,1/th 2', cell '0,1,1,1/th(r) 4']],
        [2, 1 => [cell '2,0,1,1/th 3', cell '0,1,1,1/th(r) 4']],
        [0, 2 => [cell '0,0,1,1/th 1']], # not 4
        [1, 2 => [cell '1,0,1,1/th 2']],
        [2, 2 => [cell '2,0,1,1/th 3']],
      ],
    },
    {
      input => q[<tr><th>1<th>2<th>3<tr><th>4<td>5<td>6<tr><td>7<td>8<td>9],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [2, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '1,0,1,1/th 2']],
        [2, 1 => [cell '2,0,1,1/th 3']],
        [0, 2 => [cell '0,0,1,1/th 1']], # not 4
        [1, 2 => [cell '1,0,1,1/th 2']],
        [2, 2 => [cell '2,0,1,1/th 3']],
      ],
    },
    {
      ## From Web Applications 1.0 example
      input => q[<thead><tr><th rowspan=2>1<th rowspan=2>2<th colspan=2>3<th rowspan=2>4<th rowspan=2>5<tr><th>11<th>12<tbody><tr><td>21<td>22<td>23<td>24<td>25<td>26<tr><td>31<td>32<td>33<td>34<td>35<td>36<tr><td>41<td>42<td>43<td>44<td>45<td>46],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [2, 0 => []],
        [3, 0 => []],
        [4, 0 => []],
        [5, 0 => []],
        [0, 1 => []],
        [1, 1 => []],
        [2, 1 => [cell '2,0,2,1/th 3']],
        [3, 1 => [cell '2,0,2,1/th 3']],
        [4, 1 => []],
        [5, 1 => []],
        [0, 2 => [cell '0,0,1,2/th 1']],
        [1, 2 => [cell '1,0,1,2/th 2']],
        [2, 2 => [cell '2,0,2,1/th 3', cell '2,1,1,1/th 11']],
        [3, 2 => [cell '2,0,2,1/th 3', cell '3,1,1,1/th 12']],
        [4, 2 => [cell '4,0,1,2/th 4']],
        [5, 2 => [cell '5,0,1,2/th 5']],
        [0, 3 => [cell '0,0,1,2/th 1']],
        [1, 3 => [cell '1,0,1,2/th 2']],
        [2, 3 => [cell '2,0,2,1/th 3', cell '2,1,1,1/th 11']],
        [3, 3 => [cell '2,0,2,1/th 3', cell '3,1,1,1/th 12']],
        [4, 3 => [cell '4,0,1,2/th 4']],
        [5, 3 => [cell '5,0,1,2/th 5']],
        [0, 4 => [cell '0,0,1,2/th 1']],
        [1, 4 => [cell '1,0,1,2/th 2']],
        [2, 4 => [cell '2,0,2,1/th 3', cell '2,1,1,1/th 11']],
        [3, 4 => [cell '2,0,2,1/th 3', cell '3,1,1,1/th 12']],
        [4, 4 => [cell '4,0,1,2/th 4']],
        [5, 4 => [cell '5,0,1,2/th 5']],
      ],
    },
    {
      ## From Web Applications 1.0 example
      input => q[<thead><tr><th> <th>1<th>2<th>3<tbody><tr><th>11<td>12<td>13<td>14<tr><th>21<td>22<td>23<td>24<tbody><tr><th>31<td>32<td>33<td>34<tfoot><tr><th>41<td>42<td>43<td>44],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [2, 0 => []],
        [3, 0 => []],
        [0, 1 => []],
        [1, 1 => [cell '1,0,1,1/th 1', cell '0,1,1,1/th 11']],
        [2, 1 => [cell '2,0,1,1/th 2', cell '0,1,1,1/th 11']],
        [3, 1 => [cell '3,0,1,1/th 3', cell '0,1,1,1/th 11']],
        [0, 2 => []],
        [1, 2 => [cell '1,0,1,1/th 1', cell '0,2,1,1/th 21']],
        [2, 2 => [cell '2,0,1,1/th 2', cell '0,2,1,1/th 21']],
        [3, 2 => [cell '3,0,1,1/th 3', cell '0,2,1,1/th 21']],
        [0, 3 => []],
        [1, 3 => [cell '1,0,1,1/th 1', cell '0,3,1,1/th 31']],
        [2, 3 => [cell '2,0,1,1/th 2', cell '0,3,1,1/th 31']],
        [3, 3 => [cell '3,0,1,1/th 3', cell '0,3,1,1/th 31']],
      ],
    },
    {
      ## From Web Applications 1.0 example
      input => q[<colgroup><col><colgroup><col><col><col><thead><tr><th><th>1<th>2<th>3<tbody><tr><th scope=rowgroup>11<td>12<td>13<td>14<tr><th scope=row>21<td>22<td>23<td>24<tbody><tr><th scope=rowgroup>31<td>32<td>33<td>34<tr><th scope=row>41<td>42<td>43<td>44],
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [2, 0 => []],
        [3, 0 => []],
        [0, 1 => []],
        [1, 1 => [cell '1,0,1,1/th 1', cell '0,1,1,1/th(rg) 11']],
        [2, 1 => [cell '2,0,1,1/th 2', cell '0,1,1,1/th(rg) 11']],
        [3, 1 => [cell '3,0,1,1/th 3', cell '0,1,1,1/th(rg) 11']],
        [0, 2 => [cell '0,1,1,1/th(rg) 11']],
        [1, 2 => [cell '1,0,1,1/th 1', cell '0,1,1,1/th(rg) 11', cell '0,2,1,1/th(r) 21']],
        [2, 2 => [cell '2,0,1,1/th 2', cell '0,1,1,1/th(rg) 11', cell '0,2,1,1/th(r) 21']],
        [3, 2 => [cell '3,0,1,1/th 3', cell '0,1,1,1/th(rg) 11', cell '0,2,1,1/th(r) 21']],
        [0, 3 => []],
        [1, 3 => [cell '1,0,1,1/th 1', cell '0,3,1,1/th(rg) 31']],
        [2, 3 => [cell '2,0,1,1/th 2', cell '0,3,1,1/th(rg) 31']],
        [3, 3 => [cell '3,0,1,1/th 3', cell '0,3,1,1/th(rg) 31']],
        [0, 4 => [cell '0,3,1,1/th(rg) 31']],
        [1, 4 => [cell '1,0,1,1/th 1', cell '0,3,1,1/th(rg) 31', cell '0,4,1,1/th(r) 41']],
        [2, 4 => [cell '2,0,1,1/th 2', cell '0,3,1,1/th(rg) 31', cell '0,4,1,1/th(r) 41']],
        [3, 4 => [cell '3,0,1,1/th 3', cell '0,3,1,1/th(rg) 31', cell '0,4,1,1/th(r) 41']],
      ],
    },
    {
      input => q[<tr><th id=a>1<th>2<tr><td>3<td headers=a>4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '0,0,1,1/th 1']],
      ],
    },
    {
      input => q[<tr><th id=a>1<th id=b>2<tr><td>3<td headers="a a b">4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '0,0,1,1/th 1', cell '1,0,1,1/th 2']],
      ],
    },
    {
      input => q[<tr><th id=a>1<th id=a>2<tr><td>3<td headers="a a b">4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '0,0,1,1/th 1']],
      ],
    },
    {
      input => q[<tr><th>1<th>2<tr><td id=c>3<td headers="c d" id=d>4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '0,0,1,1/th 1']],
        [1, 1 => [cell '0,1,1,1/td 3']],
      ],
    },
    {
      input => q[<tr><th>1<th>2<tr><td id=c headers=d>3<td headers=c id=d>4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => []],
        [0, 1 => [cell '1,1,1,1/td 4 ->c<-']],
        [1, 1 => [cell '0,1,1,1/td 3 ->d<-']],
      ],
    },
    {
      input => q[<colgroup span=2><tr><th scope=colgroup>1<td>2<tr><td>3<td>4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => [cell '0,0,1,1/th(cg) 1']],
        [0, 1 => [cell '0,0,1,1/th(cg) 1']],
        [1, 1 => [cell '0,0,1,1/th(cg) 1']],
      ],
    },
    {
      input => q[<colgroup span=2><tr><th scope=colgroup>1<th>2<tr><td>3<td>4],
      in_doc => 1,
      results => [
        [0, 0 => []],
        [1, 0 => [cell '0,0,1,1/th(cg) 1']],
        [0, 1 => [cell '0,0,1,1/th(cg) 1']],
        [1, 1 => [cell '0,0,1,1/th(cg) 1', cell '1,0,1,1/th 2']],
      ],
    },
    {
      input => q[<tr><th id=a headers=a>a],
      in_doc => 1,
      results => [
        [0, 0 => []],
      ],
    },
    {
      input => q[<tr><th id=a headers=b>1<th id=b headers=a>2],
      in_doc => 1,
      results => [
        [0, 0 => [cell '1,0,1,1/th 2 ->a<-']],
        [1, 0 => [cell '0,0,1,1/th 1 ->b<-']],
      ],
    },
    {
      input => q[<tr><th id=a headers=b>1<th id=b headers=c>2<th id=c>3],
      in_doc => 1,
      results => [
        [0, 0 => [cell '1,0,1,1/th 2 ->c<-']],
        [1, 0 => [cell '2,0,1,1/th 3']],
        [2, 0 => []],
      ],
    },
    {
      input => q[<tr><th id=a headers=b>1<td id=b headers=c>2<th id=c>3],
      in_doc => 1,
      results => [
        [0, 0 => [cell '1,0,1,1/td 2 ->c<-']],
        [1, 0 => [cell '2,0,1,1/th 3']],
        [2, 0 => []],
      ],
    },
  ) {
    test {
      my $c = shift;
      my $doc = NanoDOM::Document->new;
      $doc->manakai_is_html (1);
      
      my $table_el = $doc->create_element_ns
          ('http://www.w3.org/1999/xhtml', [undef, 'table']);
      $table_el->inner_html ($test->{input});
      if ($test->{in_doc}) {
        $doc->inner_html ('<!DOCTYPE html>');
        $doc->last_child->last_child->append_child ($table_el);
      }
      my $table = Web::HTML::Table->new->form_table ($table_el);
      
      for (@{$test->{results}}) {
        my $headers = Web::HTML::Table->new->get_assigned_headers
            ($table, $_->[0], $_->[1]);
        $headers = [sort {$a->{x} <=> $b->{x} || $a->{y} <=> $b->{y}} @$headers];
        $_->[2] = [sort {$a->{x} <=> $b->{x} || $a->{y} <=> $b->{y}} @{$_->[2]}];
        eq_or_diff serialize_node $headers, $_->[2];
      }
      done $c;
    } n => 0+@{$test->{results}}, name => 'get_assigned_headers';
  }
}

run_tests;

=head1 LICENSE

Copyright 2010-2013 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
