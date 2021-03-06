=head1 NAME

NanoDOM - A Non-Conforming Implementation of DOM Subset

=head1 DESCRIPTION

The C<NanoDOM> module contains a non-conforming implementation
of a subset of DOM.  It is the intention that this module is
used only for the purpose of testing the C<HTML> module.

See source code if you would like to know what it does.

=cut

package NanoDOM;
use strict;
use warnings;
our $VERSION = '1.31';

require Scalar::Util;

package NanoDOM::DOMImplementation;

sub new ($) {
  my $class = shift;
  my $self = bless {}, $class;
  return $self;
} # new

sub create_document ($) {
  return NanoDOM::Document->new;
} # create_document

package NanoDOM::Node;

sub new ($) {
  my $class = shift;
  my $self = bless {}, $class;
  return $self;
} # new

sub parent_node ($) {
  return shift->{parent_node};
} # parent_node

sub manakai_parent_element ($) {
  my $self = shift;
  my $parent = $self->{parent_node};
  while (defined $parent) {
    if ($parent->node_type == 1) {
      return $parent;
    } else {
      $parent = $parent->{parent_node};
    }
  }
  return undef;
} # manakai_parent_element

sub child_nodes ($) {
  $_[0]->{child_nodes} ||= [];
  if (ref $_[0]->{child_nodes} eq 'ARRAY') {
    bless $_[0]->{child_nodes}, 'NanoDOM::NodeList';
  }
  return $_[0]->{child_nodes};
} # child_nodes

sub node_name ($) { return $_[0]->{node_name} }

sub namespace_uri ($) { return undef }

## NOTE: Only applied to Elements and Documents
sub append_child ($$) {
  my ($self, $new_child) = @_;
  ($self->owner_document || $self)->adopt_node ($new_child);
  if (defined $new_child->{parent_node}) {
    my $parent_list = $new_child->{parent_node}->{child_nodes};
    for (reverse 0..$#$parent_list) {
      if ($parent_list->[$_] eq $new_child) {
        splice @$parent_list, $_, 1;
      }
    }
  }
  push @{$self->{child_nodes}}, $new_child;
  $new_child->{parent_node} = $self;
  Scalar::Util::weaken ($new_child->{parent_node});
  return $new_child;
} # append_child

## NOTE: Only applied to Elements and Documents
sub insert_before ($$;$) {
  my ($self, $new_child, $ref_child) = @_;
  ($self->owner_document || $self)->adopt_node ($new_child);
  if (defined $new_child->{parent_node}) {
    my $parent_list = $new_child->{parent_node}->{child_nodes};
    for (0..$#$parent_list) {
      if ($parent_list->[$_] eq $new_child) {
        splice @$parent_list, $_, 1;
      }
    }
  }
  my $i = @{$self->{child_nodes}};
  if (defined $ref_child) {
    for (0..$#{$self->{child_nodes}}) {
      if ($self->{child_nodes}->[$_] eq $ref_child) {
        $i = $_;
        last;
      }
    }
  }
  splice @{$self->{child_nodes}}, $i, 0, $new_child;
  $new_child->{parent_node} = $self;
  Scalar::Util::weaken ($new_child->{parent_node});
  return $new_child;
} # insert_before

## NOTE: Only applied to Elements and Documents
sub remove_child ($$) {
  my ($self, $old_child) = @_;
  my $parent_list = $self->{child_nodes};
  for (0..$#$parent_list) {
    if ($parent_list->[$_] eq $old_child) {
      splice @$parent_list, $_, 1;
    }
  }
  delete $old_child->{parent_node};
  return $old_child;
} # remove_child

## NOTE: Only applied to Elements and Documents
sub has_child_nodes ($) {
  return @{shift->{child_nodes}} > 0;
} # has_child_nodes

## NOTE: Only applied to Elements and Documents
sub first_child ($) {
  my $self = shift;
  return $self->{child_nodes}->[0];
} # first_child

## NOTE: Only applied to Elements and Documents
sub last_child ($) {
  my $self = shift;
  return @{$self->{child_nodes}} ? $self->{child_nodes}->[-1] : undef;
} # last_child

## NOTE: Only applied to Elements and Documents
sub previous_sibling ($) {
  my $self = shift;
  my $parent = $self->{parent_node};
  return undef unless defined $parent;
  my $r;
  for (@{$parent->{child_nodes}}) {
    if ($_ eq $self) {
      return $r;
    } else {
      $r = $_;
    }
  }
  return undef;
} # previous_sibling

sub prefix ($;$) {
  my $self = shift;
  if (@_) {
    $self->{prefix} = shift;
  }
  return $self->{prefix};
} # prefix

sub text_content ($;$) {
  my $self = shift;
  if (@_) {
    @{$self->{child_nodes}} = (); ## NOTE: parent_node not unset.
    $self->append_child (NanoDOM::Text->new ($_[0])) if length $_[0];
    return unless wantarray;
  }
  my $r = '';
  for my $child (@{$self->child_nodes}) {
    if ($child->node_type == 7 or $child->node_type == 8) {
      #
    } elsif ($child->can ('data')) {
      $r .= $child->data;
    } else {
      $r .= $child->text_content;
    }
  }
  return $r;
} # text_content

sub owner_document ($) {
  return shift->{owner_document};
} # owner_document

sub get_user_data ($$) {
  return $_[0]->{$_[1]};
} # get_user_data

sub set_user_data ($$;$$) {
  $_[0]->{$_[1]} = $_[2];
} # set_user_data

sub ELEMENT_NODE () { 1 }
sub ATTRIBUTE_NODE () { 2 }
sub TEXT_NODE () { 3 }
sub CDATA_SECTION_NODE () { 4 }
sub ENTITY_REFERENCE_NODE () { 5 }
sub ENTITY_NODE () { 6 }
sub PROCESSING_INSTRUCTION_NODE () { 7 }
sub COMMENT_NODE () { 8 }
sub DOCUMENT_NODE () { 9 }
sub DOCUMENT_TYPE_NODE () { 10 }
sub DOCUMENT_FRAGMENT_NODE () { 11 }
sub NOTATION_NODE () { 12 }
sub ELEMENT_TYPE_DEFINITION_NODE () { 81001 }
sub ATTRIBUTE_DEFINITION_NODE () { 81002 }

package NanoDOM::Document;
push our @ISA, 'NanoDOM::Node';

sub new ($) {
  my $self = shift->SUPER::new;
  $self->{child_nodes} = [];
  return $self;
} # new

## A manakai extension
sub manakai_append_text ($$) {
  my $self = shift;
  if (@{$self->{child_nodes}} and
      $self->{child_nodes}->[-1]->node_type == 3) {
    $self->{child_nodes}->[-1]->manakai_append_text (shift);
  } else {
    my $text = $self->create_text_node (shift);
    $self->append_child ($text);
  }
} # manakai_append_text

sub node_type () { 9 }

sub strict_error_checking {
  return 0;
} # strict_error_checking

sub create_text_node ($$) {
  shift;
  return NanoDOM::Text->new (shift);
} # create_text_node

sub create_comment ($$) {
  shift;
  return NanoDOM::Comment->new (shift);
} # create_comment

## The second parameter only supports manakai extended way
## to specify qualified name - "[$prefix, $local_name]"
sub create_attribute_ns ($$$) {
  my ($self, $nsuri, $qn) = @_;
  return NanoDOM::Attr->new (undef, $nsuri, $qn->[0], $qn->[1], '');

  ## NOTE: Created attribute node should be set to an element node
  ## as far as possible.  |onwer_document| of the attribute node, for
  ## example, depends on the definedness of the |owner_element| attribute.
} # create_attribute_ns

## The second parameter only supports manakai extended way
## to specify qualified name - "[$prefix, $local_name]"
sub create_element_ns ($$$) {
  my ($self, $nsuri, $qn) = @_;
  return NanoDOM::Element->new ($self, $nsuri, $qn->[0], $qn->[1]);
} # create_element_ns

## A manakai extension
sub create_document_type_definition ($$) {
  shift;
  return NanoDOM::DocumentType->new (shift);
} # create_document_type_definition

## A manakai extension.
sub create_element_type_definition ($$) {
  shift;
  return NanoDOM::ElementTypeDefinition->new (shift);
} # create_element_type_definition

## A manakai extension.
sub create_general_entity ($$) {
  shift;
  return NanoDOM::Entity->new (shift);
} # create_general_entity

## A manakai extension.
sub create_notation ($$) {
  shift;
  return NanoDOM::Notation->new (shift);
} # create_notation

## A manakai extension.
sub create_attribute_definition ($$) {
  return NanoDOM::AttributeDefinition->new ($_[0], $_[1]);
} # create_attribute_definition

sub create_processing_instruction ($$$) {
  return NanoDOM::ProcessingInstruction->new (@_);
} # create_processing_instruction

sub create_document_fragment ($) {
  return NanoDOM::DocumentFragment->new ($_[0]);
} # create_document_fragment

sub implementation ($) {
  return 'NanoDOM::DOMImplementation';
} # implementation

sub document_element ($) {
  my $self = shift;
  for (@{$self->child_nodes}) {
    if ($_->node_type == 1) {
      return $_;
    }
  }
  return undef;
} # document_element

sub dom_config ($) {
  return {};
} # dom_config

sub adopt_node ($$) {
  my @node = ($_[1]);
  while (@node) {
    my $node = shift @node;
    $node->{owner_document} = $_[0];
    Scalar::Util::weaken ($node->{owner_document});
    push @node, @{$node->child_nodes};
    push @node, @{$node->attributes or []} if $node->can ('attributes');
  }
  return $_[1];
} # adopt_node

sub manakai_is_html ($;$) {
  if (@_ > 1) {
    if ($_[1]) {
      $_[0]->{manakai_is_html} = 1;
    } else {
      delete $_[0]->{manakai_is_html};
      delete $_[0]->{manakai_compat_mode};
    }
  }
  return $_[0]->{manakai_is_html};
} # manakai_is_html

sub compat_mode ($) {
  if ($_[0]->{manakai_is_html}) {
    if ($_[0]->{manakai_compat_mode} eq 'quirks') {
      return 'BackCompat';
    }
  }
  return 'CSS1Compat';
} # compat_mode

sub manakai_compat_mode ($;$) {
  if ($_[0]->{manakai_is_html}) {
    if (@_ > 1 and defined $_[1] and
        {'no quirks' => 1, 'limited quirks' => 1, 'quirks' => 1}->{$_[1]}) {
      $_[0]->{manakai_compat_mode} = $_[1];
    }
    return $_[0]->{manakai_compat_mode} || 'no quirks';
  } else {
    return 'no quirks';
  }
} # manakai_compat_mode

sub manakai_is_srcdoc ($;$) {
  if (@_ > 1) {
    $_[0]->{manakai_is_srcdoc} = !!$_[1];
  }

  return $_[0]->{manakai_is_srcdoc};
} # manakai_is_srcdoc

sub manakai_head ($) {
  my $html = $_[0]->manakai_html;
  return undef unless defined $html;
  for my $el (@{$html->child_nodes}) {
    next unless $el->node_type == 1; # ELEMENT_NODE
    my $nsuri = $el->namespace_uri;
    next unless defined $nsuri;
    next unless $nsuri eq q<http://www.w3.org/1999/xhtml>;
    next unless $el->manakai_local_name eq 'head';
    return $el;
  }
  return undef;
} # manakai_head

sub manakai_html ($) {
  my $de = $_[0]->document_element;
  my $nsuri = $de->namespace_uri;
  if (defined $nsuri and $nsuri eq q<http://www.w3.org/1999/xhtml> and
      $de->manakai_local_name eq 'html') {
    return $de;
  } else {
    return undef;
  }
} # manakai_html

## NOTE: Manakai extension.
sub all_declarations_processed ($;$) {
  $_[0]->{all_declarations_processed} = $_[1] if @_ > 1;
  return $_[0]->{all_declarations_processed};
} # all_declarations_processed

sub input_encoding ($;$) {
  $_[0]->{input_encoding} = $_[1] if @_ > 1;
  return $_[0]->{input_encoding} || 'utf-8';
}

sub manakai_charset ($;$) {
  $_[0]->{manakai_charset} = $_[1] if @_ > 1;
  return $_[0]->{manakai_charset};
}

sub manakai_has_bom ($;$) {
  $_[0]->{manakai_has_bom} = $_[1] if @_ > 1;
  return $_[0]->{manakai_has_bom};
}

sub xml_version ($;$) {
  $_[0]->{xml_version} = $_[1] if @_ > 1;
  return $_[0]->{xml_version} || '1.0';
}

sub xml_encoding ($;$) {
  $_[0]->{xml_encoding} = $_[1] if @_ > 1;
  return $_[0]->{xml_encoding};
}

sub xml_standalone ($;$) {
  $_[0]->{xml_standalone} = $_[1] if @_ > 1;
  return $_[0]->{xml_standalone};
}

sub document_uri ($;$) {
  $_[0]->{document_uri} = $_[1] if @_ > 1;
  return $_[0]->{document_uri};
}

sub get_element_by_id ($$) {
  my @nodes = @{$_[0]->child_nodes};
  N: while (@nodes) {
    my $node = shift @nodes;
    next N unless $node->node_type == 1; # ELEMENT_NODE
    for my $attr (@{$node->attributes}) {
      if ($attr->manakai_local_name eq 'id' and $attr->value eq $_[1]) {
        return $node;
      }
    }
    unshift @nodes, @{$node->child_nodes};
  } # N
  return undef;
} # get_element_by_id

sub inner_html ($;$) {
  my $self = $_[0];
  if ($self->{manakai_is_html}) {
    if (@_ > 1) {
      for ($self->child_nodes->to_list) {
        $self->remove_child ($_);
      }

      require Web::HTML::Parser;
      Web::HTML::Parser->new->parse_char_string ($_[1] => $self);
      return unless defined wantarray;
    }

    require Web::HTML::Serializer;
    return ${ Web::HTML::Serializer->get_inner_html ($self) };
  } else { # XML
    if (@_ > 1) {
      my $doc = $self->implementation->create_document;
      require Web::XML::Parser;
      Web::XML::Parser->new->parse_char_string ($_[1] => $doc);
      for ($self->child_nodes->to_list) {
        $self->remove_child ($_);
      }
      for my $node (map { $_ } $doc->child_nodes->to_list) {
        $self->append_child ($self->adopt_node ($node));
      }
      return unless defined wantarray;
    }

    require Web::XML::Serializer;
    return ${ Web::XML::Serializer->get_inner_html ($self) };
  }
} # inner_html

package NanoDOM::Element;
push our @ISA, 'NanoDOM::Node';

sub new ($$$$$) {
  my $self = shift->SUPER::new;
  $self->{owner_document} = shift;
  Scalar::Util::weaken ($self->{owner_document});
  $self->{namespace_uri} = shift;
  $self->{prefix} = shift;
  $self->{local_name} = shift;
  $self->{attributes} = {};
  $self->{child_nodes} = [];
  return $self;
} # new

sub clone_node ($$) {
  my ($self, $deep) = @_; ## NOTE: Deep cloning is not supported
  my $clone = bless {
    namespace_uri => $self->{namespace_uri},
    prefix => $self->{prefix},
    local_name => $self->{local_name},      
    child_nodes => [],
  }, ref $self;
  for my $ns (keys %{$self->{attributes}}) {
    for my $ln (keys %{$self->{attributes}->{$ns}}) {
      my $attr = $self->{attributes}->{$ns}->{$ln};
      $clone->{attributes}->{$ns}->{$ln} = bless {
        namespace_uri => $attr->{namespace_uri},
        prefix => $attr->{prefix},
        local_name => $attr->{local_name},
        value => $attr->{value},
      }, ref $self->{attributes}->{$ns}->{$ln};
    }
  }
  return $clone;
} # clone

## A manakai extension
sub manakai_append_text ($$) {
  my $self = shift;
  if (@{$self->{child_nodes}} and
      $self->{child_nodes}->[-1]->node_type == 3) {
    $self->{child_nodes}->[-1]->manakai_append_text (shift);
  } else {
    my $text = NanoDOM::Text->new (shift);
    $self->append_child ($text);
  }
} # manakai_append_text

sub attributes ($) {
  my $self = shift;
  my $r = [];
  ## Order MUST be stable
  for my $ns (sort {$a cmp $b} keys %{$self->{attributes}}) {
    for my $ln (sort {$a cmp $b} keys %{$self->{attributes}->{$ns}}) {
      push @$r, $self->{attributes}->{$ns}->{$ln}
        if defined $self->{attributes}->{$ns}->{$ln};
    }
  }
  return $r;
} # attributes

sub local_name ($) {
  return shift->{local_name};
} # local_name
*manakai_local_name = \&local_name;

sub namespace_uri ($) {
  return shift->{namespace_uri};
} # namespace_uri

sub manakai_element_type_match ($$$) {
  my ($self, $nsuri, $ln) = @_;
  if (defined $nsuri) {
    if (defined $self->{namespace_uri} and $nsuri eq $self->{namespace_uri}) {
      return ($ln eq $self->{local_name});
    } else {
      return 0;
    }
  } else {
    if (not defined $self->{namespace_uri}) {
      return ($ln eq $self->{local_name});
    } else {
      return 0;
    }
  }
} # manakai_element_type_match

sub node_type { 1 }

sub tag_name ($) {
  my $self = shift;
  my $n;
  if (defined $self->{prefix}) {
    $n = $self->{prefix} . ':' . $self->{local_name};
  } else {
    $n = $self->{local_name};
  }
  if ($self->{owner_document}->{manakai_is_html}) {
    my $nsurl = $self->{namespace_uri} || '';
    if ($nsurl eq q<http://www.w3.org/1999/xhtml>) {
      $n =~ tr/a-z/A-Z/;
    }
  }
  return $n;
} # tag_name

sub manakai_tag_name ($) {
  my $self = shift;
  if (defined $self->{prefix}) {
    return $self->{prefix} . ':' . $self->{local_name};
  } else {
    return $self->{local_name};
  }
} # manakai_tag_name

sub get_attribute_ns ($$$) {
  my ($self, $nsuri, $ln) = @_;
  $nsuri = '' unless defined $nsuri;
  return defined $self->{attributes}->{$nsuri}->{$ln}
    ? $self->{attributes}->{$nsuri}->{$ln}->value : undef;
} # get_attribute_ns

sub get_attribute_node_ns ($$$) {
  my ($self, $nsuri, $ln) = @_;
  $nsuri = '' unless defined $nsuri;
  return $self->{attributes}->{$nsuri}->{$ln};
} # get_attribute_node_ns

sub has_attribute_ns ($$$) {
  my ($self, $nsuri, $ln) = @_;
  $nsuri = '' unless defined $nsuri;
  return defined $self->{attributes}->{$nsuri}->{$ln};
} # has_attribute_ns

## The second parameter only supports manakai extended way
## to specify qualified name - "[$prefix, $local_name]"
sub set_attribute_ns ($$$$) {
  my ($self, $nsuri, $qn, $value) = @_;
  $self->{attributes}->{defined $nsuri ? $nsuri : ''}->{$qn->[1]}
    = NanoDOM::Attr->new ($self, $nsuri, $qn->[0], $qn->[1], $value);
} # set_attribute_ns

sub set_attribute_node_ns ($$) {
  my $self = shift;
  my $attr = shift;
  my $ns = $attr->namespace_uri;
  $self->{attributes}->{defined $ns ? $ns : ''}->{$attr->manakai_local_name}
      = $attr;
  $attr->{owner_element} = $self;
  Scalar::Util::weaken ($attr->{owner_element});
} # set_attribute_node_ns

sub manakai_ids ($) {
  my $self = shift;
  my $id = $self->get_attribute_ns (undef, 'id');
  if (defined $id) {
    return [$id];
  } else {
    return [];
  }
} # manakai_ids

sub lookup_prefix ($$) {
  my $self = $_[0];

  # 1.
  my $prefix = defined $_[1] ? ''.$_[1] : undef;
  if (not defined $prefix or not length $prefix) {
    return undef;
  }

  # 2.
  my $nt = $self->node_type;
  if ($nt == 1) {
    return $self->_locate_prefix ($prefix);
  #} elsif ($nt == DOCUMENT_NODE) {
  #  my $de = $self->document_element;
  #  if ($de) {
  #    return $de->_locate_prefix ($prefix);
  #  } else {
  #    return undef;
  #  }
  #} elsif ($nt == DOCUMENT_TYPE_NODE or $nt == DOCUMENT_FRAGMENT_NODE) {
  #  return undef;
  #} elsif ($nt == ATTRIBUTE_NODE) {
  #  my $oe = $self->owner_element;
  #  if ($oe) {
  #    return $oe->_locate_prefix ($prefix);
  #  } else {
  #    return undef;
  #  }
  #} else {
  #  my $pe = $self->parent_element;
  #  if ($pe) {
  #    return $pe->_locate_prefix ($prefix);
  #  } else {
      return undef;
  #  }
  }
} # lookup_prefix

sub _locate_prefix ($$) {
  my $self = $_[0];
  my $nsurl = $_[1];

  # Locate a namespace prefix

  # 1.
  my $node_nsurl = $self->namespace_uri;
  $node_nsurl = '' if not defined $node_nsurl;
  if ($node_nsurl eq $nsurl) {
    my $prefix = $self->prefix;
    if (defined $prefix) {
      return $prefix;
    }
  }

  # 2.
  for my $attr ($self->attributes->to_list) {
    if (($attr->prefix || '') eq 'xmlns' and
        $attr->value eq $nsurl) {
      my $ln = $attr->local_name;
      my $lookup_url = $self->lookup_namespace_uri ($ln);
      $lookup_url = '' unless defined $lookup_url;
      if ($lookup_url eq $nsurl) { # DOM3 vs DOM4
        return $ln;
      }
    }
  }
  
  # 3.
  my $pe = $self->parent_node;
  if ($pe and $pe->node_type == 1) {
    return $pe->_locate_prefix ($nsurl);
  } else {
    return undef;
  }
} # _locate_prefix

sub lookup_namespace_uri ($$) {
  my $self = $_[0];
  my $prefix = defined $_[1] ? ''.$_[1] : '';

  # Locate a namespace
  my $nt = $self->node_type;
  if ($nt == 1) {
    # 1.
    my $nsurl = $self->namespace_uri;
    my $node_prefix = $self->prefix;
    $node_prefix = '' unless defined $node_prefix;
    if (defined $nsurl and $prefix eq $node_prefix) {
      return $nsurl;
    }

    # 2.
    if ($prefix eq '') {
      my $attr = $self->get_attribute_node_ns
          ('http://www.w3.org/2000/xmlns/', 'xmlns');
      if ($attr and not defined $attr->prefix) {
        # 1.-2.
        my $value = $attr->value;
        return length $value ? $value : undef;
      }
    } else {
      my $attr = $self->get_attribute_node_ns
          ('http://www.w3.org/2000/xmlns/', $prefix);
      if ($attr and ($attr->prefix || '') eq 'xmlns') {
        # 1.-2.
        my $value = $attr->value;
        return length $value ? $value : undef;
      }
    }

    # 3.-4.
    my $pe = $self->parent_node;
    if ($pe and $pe->node_type == 1) {
      return $pe->lookup_namespace_uri ($prefix);
    } else {
      return undef;
    }
  #} elsif ($nt == DOCUMENT_NODE) {
  #  # 1.-2.
  #  my $de = $self->document_element;
  #  if (defined $de) {
  #    return $de->lookup_namespace_uri ($prefix);
  #  } else {
  #    return undef;
  #  }
  #} elsif ($nt == DOCUMENT_TYPE_NODE or $nt == DOCUMENT_FRAGMENT_NODE) {
  #  return undef;
  #} elsif ($nt == ATTRIBUTE_NODE) {
  #  # 1.-2.
  #  my $oe = $self->owner_element;
  #  if (defined $oe) {
  #    return $oe->lookup_namespace_uri ($prefix);
  #  } else {
  #    return undef;
  #  }
  #} else {
  #  # 1.-2.
  #  my $pe = $self->parent_node;
  #  if (defined $pe and $pe->node_type == 1) {
  #    return $pe->lookup_namespace_uri ($prefix);
  #  } else {
      return undef;
  #  }
  }
} # lookup_namespace_uri

sub is_default_namespace ($$) {
  # 2.
  my $default = $_[0]->lookup_namespace_uri (undef);

  # 1., 3.
  my $nsurl = defined $_[1] ? ''.$_[1] : '';
  if (defined $default and length $nsurl and $default eq $nsurl) {
    return 1;
  } elsif (not defined $default and $nsurl eq '') {
    return 1;
  } else {
    return 0;
  }
} # is_default_namespace

sub inner_html ($;$) {
  my $self = $_[0];

  if (@_ > 1) {
    if ($self->{owner_document}->{manakai_is_html}) {
      require Web::HTML::Parser;
      my $children = Web::HTML::Parser->new->parse_char_string_with_context
          ($_[1], $self, NanoDOM::Document->new);
      $self->text_content ('');
      for ($children->to_list) {
        $self->append_child ($_);
      }
    } else {
      require Web::XML::Parser;
      my $children = Web::XML::Parser->new->parse_char_string_with_context
          ($_[1], $self, NanoDOM::Document->new);
      $self->text_content ('');
      for ($children->to_list) {
        $self->append_child ($_);
      }
    }
    return unless defined wantarray;
  }
  
  if ($self->{owner_document}->{manakai_is_html}) {
    require Web::HTML::Serializer;
    return ${ Web::HTML::Serializer->get_inner_html ($self) };
  } else {
    require Web::XML::Serializer;
    return ${ Web::XML::Serializer->get_inner_html ($self) };
  }
} # inner_html

# HTMLMenuElement.type
sub type ($) {
  my $type = $_[0]->get_attribute_ns (undef, 'type') || '';
  $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $type = '' unless $type eq 'popup' or $type eq 'toolbar';
  if ($type eq '') {
    my $parent = $_[0]->parent_node;
    if ($parent and
        $parent->node_type == 1 and # ELEMENT_NODE
        ($parent->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml' and
        $parent->local_name eq 'menu') {
      return $parent->type;
    } else {
      return 'toolbar';
    }
  } else {
    return $type;
  }
} # type

package NanoDOM::Attr;
push our @ISA, 'NanoDOM::Node';

sub new ($$$$$$) {
  my $self = shift->SUPER::new;
  $self->{owner_element} = shift;
  Scalar::Util::weaken ($self->{owner_element});
  $self->{namespace_uri} = shift;
  $self->{prefix} = shift;
  $self->{local_name} = shift;
  $self->{value} = shift;
  $self->{specified} = 1;
  return $self;
} # new

sub namespace_uri ($) {
  return shift->{namespace_uri};
} # namespace_uri

sub manakai_local_name ($) {
  return shift->{local_name};
} # manakai_local_name
*local_name = \&manakai_local_name;

sub node_type { 2 }

sub owner_document ($) {
  return shift->owner_element->owner_document;
} # owner_document

sub name ($) {
  my $self = shift;
  if (defined $self->{prefix}) {
    return $self->{prefix} . ':' . $self->{local_name};
  } else {
    return $self->{local_name};
  }
} # name
*manakai_name = \&name;

sub value ($;$) {
  if (@_ > 1) {
    $_[0]->{value} = $_[1];
  }
  return shift->{value};
} # value

sub owner_element ($) {
  return shift->{owner_element};
} # owner_element

sub specified ($;$) {
  $_[0]->{specified} = $_[1] if @_ > 1;
  return $_[0]->{specified} || 0;
}

sub manakai_attribute_type ($;$) {
  $_[0]->{manakai_attribute_type} = $_[1] if @_ > 1;
  return $_[0]->{manakai_attribute_type} || 0;
}

package NanoDOM::CharacterData;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{data} = shift;
  return $self;
} # new

## A manakai extension
sub manakai_append_text ($$) {
  my ($self, $s) = @_;
  $self->{data} .= $s;
} # manakai_append_text

sub data ($) {
  return shift->{data};
} # data

package NanoDOM::Text;
push our @ISA, 'NanoDOM::CharacterData';

sub node_type () { 3 }

package NanoDOM::Comment;
push our @ISA, 'NanoDOM::CharacterData';

sub node_type () { 8 }

package NanoDOM::DocumentType;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{name} = shift;
  $self->{element_types} = {};
  $self->{entities} = {};
  $self->{notations} = {};
  $self->{child_nodes} = [];
  return $self;
} # new

sub node_type () { 10 }

sub name ($) {
  return shift->{name};
} # name

sub public_id ($;$) {
  $_[0]->{public_id} = $_[1] if @_ > 1;
  return $_[0]->{public_id};
} # public_id

sub system_id ($;$) {
  $_[0]->{system_id} = $_[1] if @_ > 1;
  return $_[0]->{system_id};
} # system_id

sub element_types ($) {
  return $_[0]->{element_types};
} # element_types

sub entities ($) {
  return $_[0]->{entities};
} # entities

sub notations ($) {
  return $_[0]->{notations};
} # notations

sub get_element_type_definition_node ($$) {
  return $_[0]->{element_types}->{$_[1]};
} # get_element_type_definition_node

sub set_element_type_definition_node ($$) {
  $_[0]->{element_types}->{$_[1]->node_name} = $_[1];
} # set_element_type_definition_node

sub get_general_entity_node ($$) {
  return $_[0]->{entities}->{$_[1]};
} # get_general_entity_node

sub set_general_entity_node ($$) {
  $_[0]->{entities}->{$_[1]->node_name} = $_[1];
} # set_general_entity_node

sub get_notation_node ($$) {
  return $_[0]->{notations}->{$_[1]};
} # get_notation_node

sub set_notation_node ($$) {
  $_[0]->{notations}->{$_[1]->node_name} = $_[1];
} # set_notation_node

package NanoDOM::ProcessingInstruction;
push our @ISA, 'NanoDOM::Node';

sub new ($$$$) {
  my $self = shift->SUPER::new;
  shift;
#  $self->{owner_document} = shift;
#  Scalar::Util::weaken ($self->{owner_document});
  $self->{target} = shift;
  $self->{data} = shift;
  return $self;
} # new

sub node_type () { 7 }

sub target ($) {
  return $_[0]->{target};
} # target

sub data ($;$) {
  $_[0]->{data} = $_[1] if @_ > 1;
  return $_[0]->{data};
} # data

package NanoDOM::Entity;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{node_name} = shift;
  $self->{child_nodes} = [];
  return $self;
} # new

sub node_type () { 6 }

sub public_id ($;$) {
  $_[0]->{public_id} = $_[1] if @_ > 1;
  return $_[0]->{public_id};
} # public_id

sub system_id ($;$) {
  $_[0]->{system_id} = $_[1] if @_ > 1;
  return $_[0]->{system_id};
} # system_id

sub notation_name ($;$) {
  $_[0]->{notation_name} = $_[1] if @_ > 1;
  return $_[0]->{notation_name};
} # notation_name

package NanoDOM::Notation;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{node_name} = shift;
  return $self;
} # new

sub node_type () { 12 }

sub public_id ($;$) {
  $_[0]->{public_id} = $_[1] if @_ > 1;
  return $_[0]->{public_id};
} # public_id

sub system_id ($;$) {
  $_[0]->{system_id} = $_[1] if @_ > 1;
  return $_[0]->{system_id};
} # system_id

package NanoDOM::ElementTypeDefinition;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{node_name} = shift;
  $self->{content_model} = '';
  $self->{attribute_definitions} = {};
  return $self;
} # new

sub node_type () { 81001 }

sub content_model_text ($;$) {
  $_[0]->{content_model} = $_[1] if @_ > 1;
  return $_[0]->{content_model};
} # content_model_text

sub attribute_definitions ($) { return $_[0]->{attribute_definitions} }

sub get_attribute_definition_node ($$) {
  return $_[0]->{attribute_definitions}->{$_[1]};
} # get_attribute_definition_node

sub set_attribute_definition_node ($$) {
  $_[0]->{attribute_definitions}->{$_[1]->node_name} = $_[1];
} # set_attribute_definition_node

package NanoDOM::AttributeDefinition;
push our @ISA, 'NanoDOM::Node';

sub new ($$) {
  my $self = shift->SUPER::new;
  $self->{owner_document} = shift;
  Scalar::Util::weaken ($self->{owner_document});
  $self->{node_name} = shift;
  $self->{allowed_tokens} = [];
  return $self;
} # new

sub node_type () { 81002 }

sub allowed_tokens ($) { return $_[0]->{allowed_tokens} }

sub default_type ($;$) {
  $_[0]->{default_type} = $_[1] if @_ > 1;
  return $_[0]->{default_type} || 0;
} # default_type

sub declared_type ($;$) {
  $_[0]->{declared_type} = $_[1] if @_ > 1;
  return $_[0]->{declared_type} || 0;
} # declared_type

package NanoDOM::DocumentFragment;
push our @ISA, 'NanoDOM::Node';

sub new ($) {
  my $self = shift->SUPER::new;
  $self->{owner_document} = shift;
  Scalar::Util::weaken ($self->{owner_document});
  $self->{child_nodes} = [];
  return $self;
} # new

sub node_type () { 11 }

## A manakai extension
sub manakai_append_text ($$) {
  my $self = shift;
  if (@{$self->{child_nodes}} and
      $self->{child_nodes}->[-1]->node_type == 3) {
    $self->{child_nodes}->[-1]->manakai_append_text (shift);
  } else {
    my $text = NanoDOM::Text->new (shift);
    $self->append_child ($text);
  }
} # manakai_append_text

package NanoDOM::NodeList;

sub to_list ($) {
  return @{$_[0]};
} # to_list

=head1 SEE ALSO

L<Web::HTML::Parser>, L<Web::XML::Parser>, L<Web::Validator>.

=head1 AUTHOR

Wakaba <w@suika.fam.cx>.

=head1 LICENSE

Copyright 2007-2011 Wakaba <w@suika.fam.cx>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
