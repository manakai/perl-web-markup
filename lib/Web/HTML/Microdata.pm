package Web::HTML::Microdata;
use strict;
use warnings;
our $VERSION = '1.0';

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my %args = @_;
    warn sprintf "%s: %s (%s)\n",
        $args{node}->node_name,
        $args{type},
        $args{level};
  };
} # onerror

sub get_top_level_items ($$) {
  my ($self, $node) = @_;
  ## Top-level microdata item
  ## <http://www.whatwg.org/specs/web-apps/current-work/#top-level-microdata-items>.
  my $items = [];
  my @cand = (ref $node eq 'ARRAY' ? @$node : $node);
  while (@cand) {
    my $node = shift @cand;
    if ($node->node_type == 1 and # ELEMENT_NODE
        ($node->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml' and
        $node->has_attribute_ns (undef, 'itemscope') and
        not $node->has_attribute_ns (undef, 'itemprop')) {
      push @$items, $node;
    }
    unshift @cand, @{$node->child_nodes};
  }
  local $self->{created_items} = [];
  return [map { $self->_get_item_of_element ($_) } @$items];
} # get_top_level_items

sub get_item_of_element ($$) {
  my ($self, $element) = @_;
  local $self->{created_items} = [];
  return $self->_get_item_of_element ($element);
} # get_item_of_element

sub _get_item_of_element ($$) {
  my ($self, $root) = @_;

  for (@{$self->{current_item_els} ||= []}) {
    return {type => 'error',
            node => $root} if $_ eq $root;
  }
  push @{$self->{current_item_els} ||= []}, $root;
  for (@{$self->{created_items} || []}) {
    return $_ if $_->{node} eq $root;
  }

  ## The properties of an item
  ## <http://www.whatwg.org/specs/web-apps/current-work/#the-properties-of-an-item>.

  ## 1., 2., 3.
  my $results = {};
  my $memory = [$root];
  my $pending = [@{$root->children}];

  ## 4.
  my $root_can_have_attrs = ($root->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml';
  if ($root_can_have_attrs) {
    my $itemref = $root->get_attribute_ns (undef, 'itemref');
    my @id = grep { length } split /[\x09\x0A\x0C\x0D\x20]+/, defined $itemref ? $itemref : '';
    my $home_root = $root;
    while (1) {
      my $parent = $home_root->parent_node or last;
      $home_root = $parent;
    }
    push @$pending, grep { defined $_ } map { $home_root->get_element_by_id ($_) } @id;
  }

  ## 5. Loop
  LOOP: while (@$pending) {
    ## 6.
    my $current = shift @$pending;

    ## 7.
    for (@$memory) {
      if ($_ eq $current) {
        $self->onerror->(type => 'microdata:referenced by itemref',
                         node => $_,
                         level => 'm');
        next LOOP;
      }
    }

    ## 8.
    push @$memory, $current;

    ## 9.
    my $current_can_have_attrs = ($current->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml';
    unless ($current_can_have_attrs and
            $current->has_attribute_ns (undef, 'itemscope')) {
      push @$pending, @{$current->children};
    }

    ## 10.
    if ($current_can_have_attrs) {
      my $itemprop = $current->get_attribute_ns (undef, 'itemprop');
      my %found;
      my $prop_names = [grep { length $_ and not $found{$_}++ } split /[\x09\x0A\x0C\x0D\x20]+/, defined $itemprop ? $itemprop : ''];
      if (@$prop_names) {
        my $value = $self->get_item_value_of_element ($current);
        push @{$results->{$_} ||= []}, $value for @$prop_names;
      }
    }

    ## 11.
    #next LOOP;
  } # LOOP

  my $item = {type => 'item', node => $root, props => {}, types => {}};

  ## 12. End of loop
  $item->{props}->{$_} = $self->_sort_nodes ($results->{$_})
      for keys %$results;

  if ($root_can_have_attrs) {
    my $itemtype = $root->get_attribute_ns (undef, 'itemtype');
    for (split /[\x09\x0A\x0C\x0D\x20]+/, defined $itemtype ? $itemtype : '') {
      $item->{types}->{$_} = 1 if length $_;
    }

    my $itemid = $root->itemid; ## resolve
    $item->{id} = $itemid if defined $itemid and length $itemid;
  }

  pop @{$self->{current_item_els}};
  push @{$self->{created_items} || []}, $item; # not ||=

  ## 13.
  return $item;
} # _get_item_of_element

sub get_item_value_of_element ($$) {
  my ($self, $el) = @_;

  ## Property value
  ## <http://www.whatwg.org/specs/web-apps/current-work/#concept-property-value>.

  ## |itemValue|
  ## <http://www.whatwg.org/specs/web-apps/current-work/#dom-itemvalue>.

  if (($el->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml') {
    if ($el->has_attribute_ns (undef, 'itemscope')) {
      return $self->_get_item_of_element ($el);
    }
    my $ln = $el->local_name;
    if ($ln eq 'meta') {
      return {type => 'string', text => $el->content, node => $el};
    } elsif ($ln eq 'audio' ||
             $ln eq 'embed' ||
             $ln eq 'iframe' ||
             $ln eq 'img' ||
             $ln eq 'source' ||
             $ln eq 'track' ||
             $ln eq 'video') {
      return {type => 'url', text => $el->src, node => $el}; # XXX base
    } elsif ($ln eq 'a' or $ln eq 'area' or $ln eq 'link') {
      return {type => 'url', text => $el->href, node => $el}; # XXX base
    } elsif ($ln eq 'object') {
      return {type => 'url', text => $el->data, node => $el}; # XXX base
    } elsif ($ln eq 'data' or $ln eq 'meter') {
      my $value = $el->get_attribute_ns (undef, 'value');
      return {type => 'string', text => defined $value ? $value : '', node => $el};
    } elsif ($ln eq 'time') {
      my $value = $el->get_attribute_ns (undef, 'datetime');
      return {type => 'string', text => defined $value ? $value : $el->text_content, node => $el};
    }
  }
  return {type => 'string', text => $el->text_content, node => $el};
} # get_item_value_of_element

sub _sort_nodes ($$) {
  return $_[1] if @{$_[1]} < 2;

  my @node = map {
    my $r = [-1];
    my $n = $_->{node};
    P: while (my $p = $n->parent_node) {
      my $i = 0;
      for (@{$p->child_nodes}) {
        if ($_ eq $n) {
          unshift @$r, $i;
          last;
        }
        $i++;
      }
      $n = $p;
    } # P
    [$_, $r];
  } @{$_[1]};

  return [map { $_->[0] } sort {
    my $cmp = 0;
    for (0..$#{$a->[1]}) {
      last if $cmp = $a->[1]->[$_] <=> $b->[1]->[$_];
    }
    $cmp;
  } @node];
} # _sort_nodes

1;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
