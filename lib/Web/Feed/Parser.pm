package Web::Feed::Parser;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Feed::_Defs;

sub new_feed () { return {entries => [], authors => []}; }
sub new_entry () { return {authors => [], categories => [], enclosures => []}; }

sub ATOM_NS () { q<http://www.w3.org/2005/Atom> }
sub ATOM03_NS () { q<http://purl.org/atom/ns#> }
sub RDF_NS () { q<XXX> }
sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub SVG_NS () { q<http://www.w3.org/2000/svg> }

sub new ($) {
  return bless {}, $_[0];
} # new

sub parse_document ($$) {
  my ($self, $doc) = @_;
  my $root = $doc->document_element;
  if (not defined $root) {
    return undef;
  } elsif ($root->manakai_element_type_match (ATOM_NS, 'feed') or
           $root->manakai_element_type_match (ATOM03_NS, 'feed')) {
    return $self->_process_feed ($root);
  } elsif ($root->manakai_element_type_match (undef, 'rss')) {
    return $self->_process_rss ($root);
  } elsif ($root->manakai_element_type_match (RDF_NS, 'RDF')) {
    return $self->_process_rdf ($root);
  } else {
    return undef;
  }
} # parse_document

sub _process_feed ($$) {
  my ($self, $el) = @_;
  my $feed = new_feed;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri || '';
    my $ln = $child->local_name;
    if ($ln eq 'title' and $ns eq ATOM_NS) {
      $feed->{title} = $self->_text ($child) if not defined $feed->{title};
    } elsif ($ln eq 'title' and $ns eq ATOM03_NS) {
      $feed->{title} = $self->_content ($child) if not defined $feed->{title};
    } elsif ($ln eq 'subtitle' and $ns eq ATOM_NS) {
      $feed->{subtitle} = $self->_text ($child) if not defined $feed->{subtitle};
    } elsif ($ln eq 'tagline' and $ns eq ATOM03_NS) {
      $feed->{subtitle} = $self->_content ($child) if not defined $feed->{subtitle};
    }
  }
  return $feed;
} # _proess_feed

my $Space = qr/[\x09\x0A\x0C\x0D\x20]/;
my $NonSpace = qr/[^\x09\x0A\x0C\x0D\x20]/;

sub ctc ($) {
  return join '', map { $_->node_type == 3 ? $_->data : '' } $_[0]->child_nodes->to_list;
} # ctc

sub _text ($$) {
  my ($self, $el) = @_;
  my $type = $el->get_attribute ('type') || '';
  if ($type eq 'html') {
    return $self->_html ($el);
  } elsif ($type eq 'xhtml') {
    for my $div ($el->children->to_list) {
      if ($div->manakai_element_type_match (HTML_NS, 'div')) {
        return $self->_xml ($div);
      }
    }
  }

  my $t = ctc $el;
  return $t =~ /$NonSpace/o ? $t : undef;
} # _text

sub _content ($$) {
  my ($self, $el) = @_;
  my $mode = $el->get_attribute ('mode') || '';
  my $type = $el->get_attribute ('type') || '';

  if ($mode eq 'escaped' and
      $type =~ m{\A[Tt][Ee][Xx][Tt]/[Hh][Tt][Mm][Ll]\z}) {
    return $self->_html ($el);
  }

  my $t = ctc $el;
  return $t =~ /$NonSpace/o ? $t : undef;
} # _content

sub _sanitize_and_has_significant ($$) {
  my ($self, $node) = @_;
  my $has_significant = 0;
  my @node = ($node);
  my @hidden;
  while (@node) {
    my $node = shift @node;
    if ($node->node_type == 1) {
      my $ns = $node->namespace_uri || '';
      my $ln = $node->local_name;
      if ($ns eq HTML_NS and $ln eq 'img' and
          ($node->get_attribute ('width') || '') eq '1' and
          ($node->get_attribute ('height') || '') eq '1') {
        my $parent = $node->parent_node;
        $parent->remove_child ($node) if defined $parent;
      } elsif ($node->has_attribute ('hidden') or
               (($ln eq 'style' or $ln eq 'script') and ($ns eq HTML_NS or $ns eq SVG_NS))) {
        unshift @hidden, $node->child_nodes->to_list;
      } else {
        if ($Web::Feed::_Defs->{significant}->{$ns}->{$ln}) {
          $has_significant ||= 1;
        } elsif ($ns eq HTML_NS and $ln eq 'audio') {
          $has_significant ||= $node->has_attribute ('controls');
        } elsif ($ns eq HTML_NS and $ln eq 'input') {
          $has_significant ||= not (($node->get_attribute ('type') || '') =~ /\A[Hh][Ii][Dd][Ee][Nn]\z/);
        }
        unshift @node, $node->child_nodes->to_list;
      }
    } elsif ($node->node_type == 3) {
      $has_significant ||= $node->data =~ /$NonSpace/o;
    } else {
      unshift @node, $node->child_nodes->to_list;
    }
  }
  while (@hidden) {
    my $node = shift @hidden;
    if ($node->node_type == 1) {
      my $ns = $node->namespace_uri || '';
      my $ln = $node->local_name;
      if ($ns eq HTML_NS and $ln eq 'img' and
          ($node->get_attribute ('width') || '') eq '1' and
          ($node->get_attribute ('height') || '') eq '1') {
        my $parent = $node->parent_node;
        $parent->remove_child ($node) if defined $parent;
      }
    }
  }
  return $has_significant;
} # _sanitize_and_has_significant

sub _html ($$) {
  my ($self, $el) = @_;
  my $d = $el->owner_document->implementation->create_document;
  $d->manakai_is_html (1);
  my $div = $d->create_element ('div');
  $div->inner_html (ctc $el);
  my $df = $el->owner_document->create_document_fragment;
  $df->append_child ($_) for $div->child_nodes->to_list;
  if ($self->_sanitize_and_has_significant ($df)) {
    return $df;
  } else {
    return undef;
  }
} # _html

sub _xml ($$) {
  my ($self, $el) = @_;
  my $df = $el->owner_document->create_document_fragment;
  $df->append_child ($_->clone_node (1)) for $el->child_nodes->to_list;
  if ($self->_sanitize_and_has_significant ($df)) {
    return $df;
  } else {
    return undef;
  }
} # _xml

1;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
