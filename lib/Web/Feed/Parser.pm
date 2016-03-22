package Web::Feed::Parser;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Feed::_Defs;
use Web::DateTime::Parser;
use Web::URL::Canonicalize qw(url_to_canon_url);

sub new_feed () { return {entries => [], authors => []}; }
sub new_entry () { return {authors => [], categories => {}, enclosures => []}; }

sub ATOM_NS () { q<http://www.w3.org/2005/Atom> }
sub ATOM03_NS () { q<http://purl.org/atom/ns#> }
sub RDF_NS () { q<http://www.w3.org/1999/02/22-rdf-syntax-ns#> }
sub RSS_NS () { q<http://purl.org/rss/1.0/> }
sub CONTENT_NS () { q<http://purl.org/rss/1.0/modules/content/> }
sub DC_NS () { q<http://purl.org/dc/elements/1.1/> }
sub GD_NS () { q<http://schemas.google.com/g/2005> }
sub ITUNES_NS () { q<http://www.itunes.com/dtds/podcast-1.0.dtd> }
sub MEDIA_NS () { q<http://search.yahoo.com/mrss/> }
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
    return $self->_feed ($root);
  } elsif ($root->manakai_element_type_match (undef, 'rss')) {
    return $self->_rss ($root);
  } elsif ($root->manakai_element_type_match (RDF_NS, 'RDF')) {
    return $self->_rdf ($root);
  } else {
    return undef;
  }
} # parse_document

sub _feed ($$) {
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
    } elsif ($ln eq 'updated' and $ns eq ATOM_NS) {
      $feed->{updated} = $self->_date ($child) if not defined $feed->{updated};
    } elsif ($ln eq 'modified' and ($ns eq ATOM03_NS or $ns eq ATOM_NS)) {
      $feed->{updated} = $self->_dtf ($child) if not defined $feed->{updated};
    } elsif ($ln eq 'link' and ($ns eq ATOM_NS or $ns eq ATOM03_NS)) {
      $self->_feed_link ($child => $feed);
    } elsif ($ln eq 'icon' and $ns eq ATOM_NS) {
      if (not defined $feed->{icon}) {
        my $url = $self->_url ($child);
        $feed->{icon} = {url => $url} if defined $url;
      }
    } elsif ($ln eq 'logo' and $ns eq ATOM_NS) {
      if (not defined $feed->{logo}) {
        my $url = $self->_url ($child);
        $feed->{logo} = {url => $url} if defined $url;
      }
    } elsif ($ln eq 'author' and ($ns eq ATOM_NS or $ns eq ATOM03_NS)) {
      push @{$feed->{authors}}, $self->_person ($child);
    } elsif ($ln eq 'entry' and ($ns eq ATOM_NS or $ns eq ATOM03_NS)) {
      push @{$feed->{entries}}, my $entry = $self->_entry ($child);
      $self->_cleanup_entry ($entry);
    }
  }
  return $feed;
} # _feed

sub _rss ($$) {
  my ($self, $el) = @_;
  my $feed = new_feed;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri;
    my $ln = $child->local_name;
    if (not defined $ns) {
      if ($ln eq 'channel') {
        $self->_channel2 ($child => $feed);
      } elsif ($ln eq 'item') {
        push @{$feed->{entries}}, my $entry = $self->_item2 ($child);
        $self->_cleanup_entry ($entry);
      }
    }
  }
  return $feed;
} # _rss

sub ctc ($) {
  return join '', map { $_->node_type == 3 ? $_->data : '' } $_[0]->child_nodes->to_list;
} # ctc

sub _channel2 ($$$) {
  my ($self, $el, $feed) = @_;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri;
    my $ln = $child->local_name;
    if ($ln eq 'image') {
      if (not defined $ns) {
        if (not defined $feed->{logo}) {
          for ($child->children->to_list) {
            if ($_->manakai_element_type_match (undef, 'url')) {
              my $image = {url => $self->_url ($_)};
              $feed->{logo} = $image if defined $image->{url};
              last;
            }
          }
        }
      } elsif ($ns eq ITUNES_NS) {
        $feed->{icon} = $self->_image ($child, 'href') if not defined $feed->{icon};
      }
    } elsif (($ln eq 'creator' and defined $ns and $ns eq DC_NS) or
             ($ln eq 'author' and defined $ns and $ns eq ITUNES_NS)) {
      my $text = ctc $child;
      push @{$feed->{authors}}, {name => $text} if length $text;
    } elsif ($ln eq 'managingEditor' and not defined $ns) {
      my $person = $self->_mailbox ($child);
      push @{$feed->{authors}}, $person if defined $person;
    } elsif (($ln eq 'lastBuildDate' or $ln eq 'pubDate') and not defined $ns) {
      $feed->{updated} = $self->_date822 ($child) if not defined $feed->{updated};
    } elsif ($ln eq 'title' and not defined $ns) {
      $feed->{title} = $self->_string ($child) if not defined $feed->{title};
    } elsif ($ln eq 'subtitle' and defined $ns and $ns eq ITUNES_NS) {
      $feed->{subtitle} = $self->_string ($child) if not defined $feed->{subtitle};
    } elsif (($ln eq 'description' and not defined $ns) or
             ($ln eq 'summary' and defined $ns and $ns eq ITUNES_NS)) {
      $feed->{desc} = $self->_string ($child) if not defined $feed->{desc};
    } elsif ($ln eq 'link') {
      if (not defined $ns) {
        $feed->{page_url} = $self->_url ($child) if not defined $feed->{page_url};
      } elsif ($ns eq ATOM_NS) {
        $self->_feed_link ($child => $feed);
      }
    } elsif ($ln eq 'item' and not defined $ns) {
      push @{$feed->{entries}}, my $entry = $self->_item2 ($child);
      $self->_cleanup_entry ($entry);
    }
  }
} # _channel2

sub _rdf ($$) {
  my ($self, $el) = @_;
  my $feed = new_feed;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri;
    my $ln = $child->local_name;
    if (defined $ns and $ns eq RSS_NS) {
      if ($ln eq 'channel') {
        $self->_channel1 ($child => $feed);
      } elsif ($ln eq 'item') {
        #XXX

      } elsif ($ln eq 'image') {
        if (not defined $feed->{logo}) {
          for ($child->children->to_list) {
            if ($_->manakai_element_type_match (RSS_NS, 'url')) {
              my $image = {url => $self->_url ($_)};
              $feed->{logo} = $image if defined $image->{url};
              last;
            }
          }
        }
      }
    }
  }
  return $feed;
} # _rdf

sub _channel1 ($$$) {
  my ($self, $el, $feed) = @_;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri || '';
    my $ln = $child->local_name;
    if ($ln eq 'date' and $ns eq DC_NS) {
      $feed->{updated} = $self->_dtf ($child) if not defined $feed->{updated};
    } elsif ($ln eq 'creator' and defined $ns and $ns eq DC_NS) {
      my $text = ctc $child;
      push @{$feed->{authors}}, {name => $text} if length $text;
    } elsif ($ln eq 'title' and $ns eq RSS_NS) {
      $feed->{title} = $self->_string ($child) if not defined $feed->{title};
    } elsif ($ln eq 'description' and $ns eq RSS_NS) {
      $feed->{desc} = $self->_string ($child) if not defined $feed->{desc};
    } elsif ($ln eq 'link') {
      if ($ns eq RSS_NS) {
        $feed->{page_url} = $self->_url ($child) if not defined $feed->{page_url};
      } elsif ($ns eq ATOM_NS) {
        $self->_feed_link ($child => $feed);
      }
    }
  }
} # _channel1

sub _entry ($$) {
  my ($self, $el) = @_;
  my $entry = new_entry;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri || '';
    my $ln = $child->local_name;
    if ($ln eq 'author' and ($ns eq ATOM_NS or $ns eq ATOM03_NS)) {
      push @{$entry->{authors}}, $self->_person ($child);
    } elsif ($ln eq 'category' and $ns eq ATOM_NS) {
      my $term = $child->get_attribute ('term');
      $entry->{categories}->{$term} = 1 if defined $term and length $term;
    } elsif ($ln eq 'subject' and $ns eq DC_NS) {
      my $term = ctc $child;
      $entry->{categories}->{$term} = 1 if length $term;
    } elsif ($ln eq 'published' and $ns eq ATOM_NS) {
      $entry->{published} = $self->_date ($child) if not defined $entry->{published};
    } elsif ($ln eq 'created' and ($ns eq ATOM03_NS or $ns eq ATOM_NS)) {
      $entry->{published} = $self->_dtf ($child) if not defined $entry->{published};
    } elsif ($ln eq 'updated' and $ns eq ATOM_NS) {
      $entry->{updated} = $self->_date ($child) if not defined $entry->{updated};
    } elsif ($ln eq 'modified' and ($ns eq ATOM03_NS or $ns eq ATOM_NS)) {
      $entry->{updated} = $self->_dtf ($child) if not defined $entry->{updated};
    } elsif ($ln eq 'title' and $ns eq ATOM_NS) {
      $entry->{title} = $self->_text ($child) if not defined $entry->{title};
    } elsif ($ln eq 'title' and $ns eq ATOM03_NS) {
      $entry->{title} = $self->_content ($child) if not defined $entry->{title};
    } elsif ($ln eq 'summary' and $ns eq ATOM_NS) {
      $entry->{summary} = $self->_text ($child) if not defined $entry->{summary};
    } elsif ($ln eq 'summary' and $ns eq ATOM03_NS) {
      $entry->{summary} = $self->_content ($child) if not defined $entry->{summary};
    } elsif ($ln eq 'content' and $ns eq ATOM_NS) {
      $entry->{content} = $self->_text ($child) if not defined $entry->{content};
    } elsif ($ln eq 'content' and $ns eq ATOM03_NS) {
      $entry->{content} = $self->_content ($child) if not defined $entry->{content};
    } elsif ($ln eq 'link' and ($ns eq ATOM_NS or $ns eq ATOM03_NS)) {
      $self->_entry_link ($child => $entry);
    } elsif ($ln eq 'thumbnail' and $ns eq MEDIA_NS) {
      $entry->{thumbnail} = $self->_image ($child, 'url') if not defined $entry->{thumbnail};
    } elsif ($ln eq 'group' and $ns eq MEDIA_NS) {
      for my $gc ($child->children->to_list) {
        my $ns = $gc->namespace_uri || '';
        next unless $ns eq MEDIA_NS;
        my $ln = $gc->local_name;
        if ($ln eq 'title') {
          $entry->{title} = $self->_string ($gc) if not defined $entry->{title};
        } elsif ($ln eq 'description') {
          $entry->{summary} = $self->_string ($gc) if not defined $entry->{summary};
        } elsif ($ln eq 'thumbnail') {
          $entry->{thumbnail} = $self->_image ($gc, 'url') if not defined $entry->{thumbnail};
        } elsif ($ln eq 'content') {
          my $href = $gc->get_attribute ('url');
          if (defined $href and length $href) {
            my $enclosure = {};
            $enclosure->{url} = url_to_canon_url $href, $gc->base_uri; # or undef
            if (defined $enclosure->{url} and length $enclosure->{url}) {
              $enclosure->{type} = $gc->get_attribute ('type');
              push @{$entry->{enclosures}}, $enclosure;
            }
          }
        }
      }
    }

  }
  return $entry;
} # _entry

sub _item2 ($$) {
  my ($self, $el) = @_;
  my $entry = new_entry;
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri;
    my $ln = $child->local_name;
    if ($ln eq 'category' and not defined $ns) {
      my $term = ctc $child;
      $entry->{categories}->{$term} = 1 if length $term;
    } elsif ($ln eq 'author' and not defined $ns) {
      my $person = $self->_mailbox ($child);
      push @{$entry->{authors}}, $person if defined $person;
    } elsif (($ln eq 'creator' and defined $ns and $ns eq DC_NS) or
             ($ln eq 'author' and defined $ns and $ns eq ITUNES_NS)) {
      my $text = ctc $child;
      push @{$entry->{authors}}, {name => $text} if length $text;
    } elsif ($ln eq 'pubDate' and not defined $ns) {
      $entry->{updated} = $self->_date822 ($child) if not defined $entry->{updated};
    } elsif ($ln eq 'updated' and $ns eq ATOM_NS) {
      $entry->{updated} = $self->_date ($child) if not defined $entry->{updated};
    } elsif ($ln eq 'link' and not defined $ns) {
      $entry->{page_url} = $self->_url ($child) if not defined $entry->{page_url};
    } elsif ($ln eq 'thumbnail' and defined $ns and $ns eq MEDIA_NS) {
      $entry->{thumbnail} = $self->_image ($child, 'url') if not defined $entry->{thumbnail};
    } elsif ($ln eq 'image' and defined $ns and $ns eq ITUNES_NS) {
      $entry->{thumbnail} = $self->_image ($child, 'href') if not defined $entry->{thumbnail};
    } elsif ($ln eq 'enclosure' and not defined $ns) {
      my $href = $child->get_attribute ('url');
      if (defined $href and length $href) {
        my $enclosure = {};
        $enclosure->{url} = url_to_canon_url $href, $child->base_uri; # or undef
        if (defined $enclosure->{url} and length $enclosure->{url}) {
          $enclosure->{type} = $child->get_attribute ('type');
          my $length = $child->get_attribute ('length');
          if (defined $length and $length =~ /^([0-9]+)/) {
            $enclosure->{length} = 0+$1;
          }
          push @{$entry->{enclosures}}, $enclosure;
        }
      }
    } elsif ($ln eq 'title' and not defined $ns) {
      $entry->{title} = $self->_string ($child) if not defined $entry->{title};
    } elsif ($ln eq 'subtitle' and defined $ns and $ns eq ITUNES_NS) {
      $entry->{subtitle} = $self->_string ($child) if not defined $entry->{subtitle};
    } elsif ($ln eq 'description' and not defined $ns) {
      $entry->{summary} = $self->_html ($child) if not defined $entry->{summary};
    } elsif ($ln eq 'encoded' and defined $ns and $ns eq CONTENT_NS) {
      $entry->{content} = $self->_html ($child) if not defined $entry->{content};
    } elsif ($ln eq 'duration' and defined $ns and $ns eq ITUNES_NS) {
      if (not defined $entry->{duration}) {
        my $text = ctc $child;
        if ($text =~ /\A([0-9]+)\z/) {
          $entry->{duration} = 0+$1;
        } elsif ($text =~ /\A([0-9]+):([0-9]+)\z/) {
          $entry->{duration} = $1 * 60 + $2;
        } elsif ($text =~ /\A([0-9]+):([0-9]+):([0-9]+)\z/) {
          $entry->{duration} = $1 * 3600 + $2 * 60 + $3;
        }
      }
    }
  }
  return $entry;
} # _item2

sub _cleanup_entry ($$) {
  my ($self, $entry) = @_;

  #XXX
} # _cleanup_entry

my $Space = qr/[\x09\x0A\x0C\x0D\x20]/;
my $NonSpace = qr/[^\x09\x0A\x0C\x0D\x20]/;

sub _string ($$) {
  my ($self, $el) = @_;
  my $t = ctc $el;
  return $t =~ /$NonSpace/o ? $t : undef;
} # _string

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

sub _date ($$) {
  my ($self, $el) = @_;
  my $parser = Web::DateTime::Parser->new;
  $parser->onerror (sub { });
  return $parser->parse_rfc3339_xs_date_time_string (ctc $el); # or undef
} # _date

sub _dtf ($$) {
  my ($self, $el) = @_;
  my $parser = Web::DateTime::Parser->new;
  $parser->onerror (sub { });
  return $parser->parse_w3c_dtf_string (ctc $el); # or undef
} # _dtf

sub _date822 ($$) {
  my ($self, $el) = @_;
  my $parser = Web::DateTime::Parser->new;
  $parser->onerror (sub { });
  return $parser->parse_rss2_date_time_string (ctc $el); # or undef
} # _date822

sub _feed_link ($$$) {
  my ($self, $el => $feed) = @_;
  my $rel = $el->get_attribute ('rel');
  if (not defined $rel) {
    $rel = 'http://www.iana.org/assignments/relation/alternate';
  } elsif (not $rel =~ /:/) {
    $rel = "http://www.iana.org/assignments/relation/$rel";
  }
  if ($rel eq 'http://www.iana.org/assignments/relation/alternate') {
    if (not defined $feed->{page_url}) {
      my $href = $el->get_attribute ('href');
      $href = '' if not defined $href;
      $feed->{page_url} = url_to_canon_url $href, $el->base_uri; # or undef
    }
  } elsif ($rel eq 'http://www.iana.org/assignments/relation/self') {
    if (not defined $feed->{feed_url}) {
      my $href = $el->get_attribute ('href');
      $href = '' if not defined $href;
      $feed->{feed_url} = url_to_canon_url $href, $el->base_uri; # or undef
    }
  } elsif ($rel eq 'http://www.iana.org/assignments/relation/previous' or
           $rel eq 'http://www.iana.org/assignments/relation/prev') {
    if (not defined $feed->{prev_feed_url}) {
      my $href = $el->get_attribute ('href');
      $href = '' if not defined $href;
      $feed->{prev_feed_url} = url_to_canon_url $href, $el->base_uri; # or undef
    }
  } elsif ($rel eq 'http://www.iana.org/assignments/relation/next') {
    if (not defined $feed->{next_feed_url}) {
      my $href = $el->get_attribute ('href');
      $href = '' if not defined $href;
      $feed->{next_feed_url} = url_to_canon_url $href, $el->base_uri; # or undef
    }
  }
} # _feed_link

sub _entry_link ($$$) {
  my ($self, $el => $entry) = @_;
  my $rel = $el->get_attribute ('rel');
  if (not defined $rel) {
    $rel = 'http://www.iana.org/assignments/relation/alternate';
  } elsif (not $rel =~ /:/) {
    $rel = "http://www.iana.org/assignments/relation/$rel";
  }
  if ($rel eq 'http://www.iana.org/assignments/relation/alternate') {
    if (not defined $entry->{page_url}) {
      my $href = $el->get_attribute ('href');
      $href = '' if not defined $href;
      $entry->{page_url} = url_to_canon_url $href, $el->base_uri; # or undef
    }
  } elsif ($rel eq 'http://www.iana.org/assignments/relation/enclosure') {
    my $href = $el->get_attribute ('href');
    $href = '' if not defined $href;
    my $href = url_to_canon_url $href, $el->base_uri; # or undef
    if (defined $href) {
      my $enclosure = {url => $href, type => $el->get_attribute ('type')};
      my $length = $el->get_attribute ('length');
      if (defined $length and $length =~ /^([0-9]+)/) {
        $enclosure->{length} = 0+$1;
      }
      push @{$entry->{enclosures}}, $enclosure;
    }
  }
} # _entry_link

sub _url ($$) {
  my ($self, $el) = @_;
  my $text = ctc $el;
  return undef if not length $text;
  return url_to_canon_url $text, $el->base_uri; # or undef
} # _url

sub _image ($$$) {
  my ($self, $el, $an) = @_;
  my $text = $el->get_attribute ($an);
  if (defined $text and length $text) {
    my $image = {url => url_to_canon_url $text, $el->base_uri}; # or undef
    return undef unless defined $image->{url};

    my $w = $el->get_attribute ('width');
    if (defined $w and $w =~ /^([0-9]+)/) {
      $image->{width} = 0+$1;
    }
    my $h = $el->get_attribute ('height');
    if (defined $h and $h =~ /^([0-9]+)/) {
      $image->{height} = 0+$1;
    }

    return $image;
  }
  return undef;
} # _image

sub _person ($$) {
  my ($self, $el) = @_;
  my $person = {};
  for my $child ($el->children->to_list) {
    my $ns = $child->namespace_uri || '';
    my $ln = $child->local_name;
    if ($ns eq ATOM_NS or $ns eq ATOM03_NS) {
      if ($ln eq 'name') {
        $person->{name} = $self->_string ($child) if not defined $person->{name};
      } elsif ($ln eq 'email') {
        $person->{email} = $self->_string ($child) if not defined $person->{email};
      } elsif ($ln eq 'uri') {
        $person->{page_url} = $self->_url ($child) if not defined $person->{page_url};
      }
    } elsif ($ns eq GD_NS and $ln eq 'image') {
      $person->{logo} = $self->_image ($child, 'src') if not defined $person->{logo};
    }
  }
  return $person;
} # _person

sub _mailbox ($$) {
  my ($self, $el) = @_;
  my $t = ctc $el;
  if (not length $t) {
    return undef;
  } elsif ($t =~ /\A($NonSpace+)$Space+\((.+)\)\z/s) {
    return {name => $2, email => $1};
  } else {
    return {name => $t};
  }
} # _mailbox

1;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
