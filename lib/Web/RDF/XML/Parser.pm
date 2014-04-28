package Web::RDF::XML::Parser;
use strict;
use warnings;
our $VERSION = '3.0';
use Web::URL::Canonicalize qw(url_to_canon_url);

sub RDF_URL () { q<http://www.w3.org/1999/02/22-rdf-syntax-ns#> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub XMLNS_NS () { q<http://www.w3.org/2000/xmlns/> }
sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }

sub LEVEL_RDF_FACT () { 'm' }
sub LEVEL_RDF_GRAMMER () { 'm' }

sub new ($) {
  return bless {
    next_id => 0,
  }, $_[0];
} # new

sub ontriple ($;$) {
  if (@_ > 1) {
    $_[0]->{ontriple} = $_[1];
  }
  return $_[0]->{ontriple} ||= sub {
    my %opt = @_;
    my $dump_resource = sub {
      my $resource = shift;
      if (defined $resource->{uri}) {
        return '<' . $resource->{uri} . '>';
      } elsif (defined $resource->{bnodeid}) {
        return '_:' . $resource->{bnodeid};
      } elsif ($resource->{nodes}) {
        return '"' . join ('', map {$_->inner_html} @{$resource->{nodes}}) .
            '"^^<' . $resource->{datatype} . '>';
      } elsif (defined $resource->{value}) {
        return '"' . $resource->{value} . '"' .
            (defined $resource->{datatype}
                 ? '^^<' . $resource->{datatype} . '>'
                 : (defined $resource->{language} ? '@' . $resource->{language} : ''));
      } else {
        return '??';
      }
    };
    print STDERR $dump_resource->($opt{subject}) . ' ';
    print STDERR $dump_resource->($opt{predicate}) . ' ';
    print STDERR $dump_resource->($opt{object}) . "\n";
    if ($dump_resource->{id}) {
      print STDERR $dump_resource->($dump_resource->{id}) . ' ';
      print STDERR $dump_resource->({uri => RDF_URL . 'subject'}) . ' ';
      print STDERR $dump_resource->($opt{subject}) . "\n";
      print STDERR $dump_resource->($dump_resource->{id}) . ' ';
      print STDERR $dump_resource->({uri => RDF_URL . 'predicate'}) . ' ';
      print STDERR $dump_resource->($opt{predicate}) . "\n";
      print STDERR $dump_resource->($dump_resource->{id}) . ' ';
      print STDERR $dump_resource->({uri => RDF_URL . 'object'}) . ' ';
      print STDERR $dump_resource->($opt{object}) . "\n";
      print STDERR $dump_resource->($dump_resource->{id}) . ' ';
      print STDERR $dump_resource->({uri => RDF_URL . 'type'}) . ' ';
      print STDERR $dump_resource->({uri => RDF_URL . 'Statement'}) . "\n";
    }
  };
} # ontriple

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my %opt = @_;
    warn $opt{type}, "\n";
  };
} # onerror

sub onnonrdfnode ($;$) {
  if (@_ > 1) {
    $_[0]->{onnonrdfnode} = $_[1];
  }
  return $_[0]->{onnonrdfnode} ||= sub { };
} # onnonrdfnode

sub onattr ($;$) {
  if (@_ > 1) {
    $_[0]->{onattr} = $_[1];
  }
  return $_[0]->{onattr} ||= sub { };
} # onattr

sub convert_document ($$) {
  my $self = shift;
  my $node = shift; # Document

  ## NOTE: An RDF/XML document, either |doc| or |nodeElement| is
  ## allowed as a starting production.  However, |nodeElement| is not
  ## a Root Event.

  my $has_element;

  for my $cn ($node->child_nodes->to_list) {
    my $cnt = $cn->node_type;
    if ($cnt == 1) { # ELEMENT_NODE
      unless ($has_element) {
        if ($cn->manakai_expanded_uri eq RDF_URL . q<RDF>) {
          $self->convert_rdf_element ($cn, language => undef);
        } else {
          $self->convert_node_element ($cn, language => undef);
        }
        $has_element = 1;
      } else {
        $self->onerror->(type => 'second node element',
                           level => LEVEL_RDF_GRAMMER,
                           node => $cn);
        $self->onnonrdfnode->($cn);
      }
    } elsif ($cnt == 3) { # TEXT_NODE
      $self->onerror->(type => 'character not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $cn);
      if ($cn->data =~ /[^\x09\x0A\x0C\x0D\x20]/) {
        $self->onnonrdfnode->($cn);
      }
    } elsif ($cnt == 7) { # PROCESSING_INSTRUCTION_NODE
      $self->onnonrdfnode->($cn);
    } elsif ($cnt == 10) { # DOCUMENT_TYPE_NODE
      $self->onnonrdfnode->($cn);
    }
  }

  unless ($has_element) {
    $self->onerror->(type => 'rdfxml:no root element',
                       level => LEVEL_RDF_GRAMMER,
                       node => $node);
  }
} # convert_document

my $check_rdf_namespace = sub {
  my $self = shift;
  my $node = shift;
  my $node_nsuri = $node->namespace_uri;
  return unless defined $node_nsuri;
  ## If the namespace URL is longer than
  ## <http://www.w3.org/1999/02/22-rdf-syntax-ns#>:
  if (substr ($node_nsuri, 0, length RDF_URL) eq RDF_URL and
      length RDF_URL < length $node_nsuri) {
    $self->onerror->(type => 'bad rdf namespace',
                       level => LEVEL_RDF_FACT, # Section 5.1
                       node => $node);
  }
  ## If the namespace URL is shorter than
  ## <http://www.w3.org/1999/02/22-rdf-syntax-ns#>: This is an XML
  ## parse error or DOM createElement's exception.
}; # $check_rdf_namespace

sub convert_rdf_element ($$%) {
  my ($self, $node, %opt) = @_;

  $check_rdf_namespace->($self, $node);

  # |RDF|

  for my $attr (@{$node->attributes}) {
    my $nsuri = $attr->namespace_uri || '';
    if ($nsuri eq XML_NS) {
      my $ln = $attr->local_name;
      if ($ln eq 'lang') {
        $opt{language} = $attr->value;
        delete $opt{language} if $opt{language} eq '';
        $self->onattr->($attr, 'common');
        next;
      } elsif ($ln eq 'base') {
        $self->onattr->($attr, 'common');
        next;
      }
    } elsif ($nsuri eq XMLNS_NS) {
      $self->onattr->($attr, 'common');
      next;
    }

    ## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#eventterm-element-attributes>
    my $prefix = $attr->prefix;
    if (defined $prefix) {
      if ($prefix =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    } else {
      if ($attr->manakai_local_name =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    }

    $check_rdf_namespace->($self, $attr);
    $self->onerror->(type => 'attribute not allowed',
                       level => LEVEL_RDF_GRAMMER,
                       node => $attr);
    $self->onattr->($attr, 'misc');
  }

  # |nodeElementList|
  for my $cn (@{$node->child_nodes}) {
    if ($cn->node_type == 1) { # ELEMENT_NODE
      $self->convert_node_element ($cn, language => $opt{language});
    } elsif ($cn->node_type == 3) { # TEXT_NODE
      if ($cn->data =~ /[^\x09\x0A\x0D\x20]/) {
        $self->onerror->(type => 'character not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $cn);
        $self->onnonrdfnode->($cn);
      }
    } elsif ($cn->node_type == 7) { # PROCESSING_INSTRUCTION_NODE) {
      $self->onnonrdfnode->($cn);
    }
  }
} # convert_rdf_element

my %coreSyntaxTerms = (
  RDF_URL . 'RDF' => 1,
  RDF_URL . 'ID' => 1,
  RDF_URL . 'about' => 1,
  RDF_URL . 'parseType' => 1,
  RDF_URL . 'resource' => 1,
  RDF_URL . 'nodeID' => 1,
  RDF_URL . 'datatype' => 1,
);

my %oldTerms = (
  RDF_URL . 'aboutEach' => 1,
  RDF_URL . 'aboutEachPrefix' => 1,
  RDF_URL . 'bagID' => 1,
);

my $resolve = sub {
  # XXX url_to_canon_url can't handle fragment-only relative URLs...
  # XXX don't use ->base_uri as it might drop xml:base support...
  my $resolved = url_to_canon_url $_[0], $_[1]->base_uri;
  if (not defined $resolved and $_[0] =~ /^#/) {
    return $_[1]->base_uri . $_[0];
  } elsif (not defined $resolved and $_[0] eq '') {
    return $_[1]->base_uri;
  }
  return defined $resolved ? $resolved : $_[0];
}; # $resolve

## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#eventterm-blanknodeid-string-value>
## <http://www.w3.org/TR/n-triples/#grammar-production-BLANK_NODE_LABEL>
my $generate_bnodeid = sub {
  return 'g'.$_[0]->{next_id}++;
}; # $generate_bnodeid

my $get_bnodeid = sub {
  return 'b'.$_[0];
}; # $get_bnodeid

my $uri_attr = sub {
  my ($self, $attr) = @_;
  my $abs_uri = $resolve->($attr->value, $attr);
  return $abs_uri;
}; # $uri_attr

my $id_attr = sub {
  my ($self, $attr) = @_;
  return $resolve->('#' . $attr->value, $attr);
}; # $id_attr

my $check_local_attr = sub {
  my ($self, $node, $attr, $attr_xuri) = @_;
  
  if ({
    ID => 1, about => 1, resource => 1, parseType => 1, type => 1,
  }->{$attr_xuri}) {
    $self->onerror->(type => 'unqualified rdf attr',
                       level => 's',
                       node => $attr);
    if ($node->has_attribute_ns (RDF_URL, $attr_xuri)) {
      $self->onerror->(type => 'duplicate unqualified attr',
                         level => LEVEL_RDF_FACT,
                         node => $attr);
      ## NOTE: <? rdfa:bout="" about=""> and such are not catched
      ## by this check; but who cares?  rdfa:bout="" is itself illegal.
    }
    $attr_xuri = RDF_URL . $attr_xuri;
  } else {
    $self->onerror->(type => 'unqualified attr',
                       level => LEVEL_RDF_FACT,
                       node => $attr);
  }
  
  return $attr_xuri;
}; # $check_local_attr

sub convert_node_element ($$;%) {
  my ($self, $node, %opt) = @_;

  $check_rdf_namespace->($self, $node);

  # |nodeElement|

  my $xuri = $node->manakai_expanded_uri;

  if ({
    %coreSyntaxTerms,
    RDF_URL . 'li' => 1,
    %oldTerms,
  }->{$xuri}) {
    $self->onerror->(type => 'element not allowed',
                       level => LEVEL_RDF_GRAMMER,
                       node => $node);
  }

  my $subject;
  my $type_attr;
  my @prop_attr;

  for my $attr (@{$node->attributes}) {
    my $nsuri = $attr->namespace_uri;
    if (defined $nsuri and $nsuri eq XML_NS) {
      my $ln = $attr->local_name;
      if ($ln eq 'lang') {
        $opt{language} = $attr->value;
        delete $opt{language} if $opt{language} eq '';
        $self->onattr->($attr, 'common');
        next;
      } elsif ($ln eq 'base') {
        $self->onattr->($attr, 'common');
        next;
      }
    } elsif (defined $nsuri and $nsuri eq XMLNS_NS) {
      $self->onattr->($attr, 'common');
      next;
    }

    ## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#eventterm-element-attributes>
    my $prefix = $attr->prefix;
    if (defined $prefix) {
      if ($prefix =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    } else {
      if ($attr->manakai_local_name =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    }

    $check_rdf_namespace->($self, $attr);

    my $attr_xuri = $attr->manakai_expanded_uri;

    unless (defined $nsuri) {
      $attr_xuri = $check_local_attr->($self, $node, $attr, $attr_xuri);
    }

    if ($attr_xuri eq RDF_URL . 'ID') {
      unless (defined $subject) {
        $subject = {uri => $id_attr->($self, $attr)};
      } else {
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      $self->onattr->($attr, 'rdf-id');
    } elsif ($attr_xuri eq RDF_URL . 'nodeID') {
      unless (defined $subject) {
        $subject = {bnodeid => $get_bnodeid->($attr->value)};
      } else {
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      $self->onattr->($attr, 'rdf-id');
    } elsif ($attr_xuri eq RDF_URL . 'about') {
      unless (defined $subject) {
        $subject = {uri => $uri_attr->($self, $attr)};
      } else {
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      $self->onattr->($attr, 'url');
    } elsif ($attr_xuri eq RDF_URL . 'type') {
      $type_attr = $attr;
      $self->onattr->($attr, 'url');
    } elsif ({
      %coreSyntaxTerms,
      RDF_URL . 'li' => 1,
      RDF_URL . 'Description' => 1,
      %oldTerms,
    }->{$attr_xuri}) {
      $self->onerror->(type => 'attribute not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $attr);
      $self->onattr->($attr, 'misc');
    } else {
      push @prop_attr, $attr;
      $self->onattr->($attr, 'string');
    }
  } # $attr
  
  unless (defined $subject) {
    $subject = {bnodeid => $generate_bnodeid->($self)};
  }

  if ($xuri ne RDF_URL . 'Description') {
    $self->ontriple->(subject => $subject,
                        predicate => {uri => RDF_URL . 'type'},
                        object => {uri => $xuri},
                        node => $node);
  }

  if ($type_attr) {
    $self->ontriple->(subject => $subject,
                        predicate => {uri => RDF_URL . 'type'},
                        object => {uri => $resolve->($type_attr->value,
                                                     $type_attr)},
                        node => $type_attr);
  }

  for my $attr (@prop_attr) {
    $self->ontriple->(subject => $subject,
                        predicate => {uri => $attr->manakai_expanded_uri},
                        object => {value => $attr->value,
                                   language => $opt{language}},
                        node => $attr);
  }

  # |propertyEltList|

  my $li_counter = 1;
  for my $cn (@{$node->child_nodes}) {
    my $cn_type = $cn->node_type;
    if ($cn_type == 1) { # ELEMENT_NODE
      $self->convert_property_element ($cn, li_counter => \$li_counter,
                                       subject => $subject,
                                       language => $opt{language});
    } elsif ($cn_type == 3) { # TEXT_NODE
      if ($cn->data =~ /[^\x09\x0A\x0D\x20]/) {
        $self->onerror->(type => 'character not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $cn);
        $self->onnonrdfnode->($cn);
      }
    } elsif ($cn_type == 7) { # PROCESSING_INSTRUCTION_NODE
      $self->onnonrdfnode->($cn);
    }
  }

  if ($node->manakai_element_type_match (HTML_NS, 'template')) {
    $self->onnonrdfnode->($node->content);
  }

  return $subject;
} # convert_node_element

my $get_id_resource = sub {
  my $self = shift;
  my $node = shift;

  return undef unless $node;

  return {uri => $id_attr->($self, $node)};
}; # $get_id_resource

sub convert_property_element ($$%) {
  my ($self, $node, %opt) = @_;
  
  $check_rdf_namespace->($self, $node);

  # |propertyElt|

  my $xuri = $node->manakai_expanded_uri;
  if ($xuri eq RDF_URL . 'li') {
    $xuri = RDF_URL . '_' . ${$opt{li_counter}}++;
  }

  if ({
       %coreSyntaxTerms,
       RDF_URL . 'Description' => 1,
       %oldTerms,
      }->{$xuri}) {
    $self->onerror->(type => 'element not allowed',
                       level => LEVEL_RDF_GRAMMER,
                       node => $node);
  }

  my $rdf_id_attr;
  my $dt_attr;
  my $parse_attr;
  my $nodeid_attr;
  my $resource_attr;
  my @prop_attr;
  for my $attr (@{$node->attributes}) {
    my $nsuri = $attr->namespace_uri;
    if (defined $nsuri and $nsuri eq XML_NS) {
      my $ln = $attr->local_name;
      if ($ln eq 'lang') {
        $opt{language} = $attr->value;
        delete $opt{language} if $opt{language} eq '';
        $self->onattr->($attr, 'common');
        next;
      } elsif ($ln eq 'base') {
        $self->onattr->($attr, 'common');
        next;
      }
    } elsif (defined $nsuri and $nsuri eq XMLNS_NS) {
      $self->onattr->($attr, 'common');
      next;
    }

    ## <https://dvcs.w3.org/hg/rdf/raw-file/default/rdf-xml/index.html#eventterm-element-attributes>
    my $prefix = $attr->prefix;
    if (defined $prefix) {
      if ($prefix =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    } else {
      if ($attr->manakai_local_name =~ /^[Xx][Mm][Ll]/) {
        $self->onerror->(type => 'rdf:attr ignored',
                           level => 'w',
                           node => $attr);
        $self->onattr->($attr, 'common');
        next;
      }
    }

    $check_rdf_namespace->($self, $attr);

    my $attr_xuri = $attr->manakai_expanded_uri;

    unless (defined $nsuri) {
      $attr_xuri = $check_local_attr->($self, $node, $attr, $attr_xuri);
    }

    if ($attr_xuri eq RDF_URL . 'ID') {
      $rdf_id_attr = $attr;
      $self->onattr->($attr, 'rdf-id');
    } elsif ($attr_xuri eq RDF_URL . 'datatype') {
      $dt_attr = $attr;
      $self->onattr->($attr, 'url');
    } elsif ($attr_xuri eq RDF_URL . 'parseType') {
      $parse_attr = $attr;
      $self->onattr->($attr, 'misc');
    } elsif ($attr_xuri eq RDF_URL . 'resource') {
      $resource_attr = $attr;
      $self->onattr->($attr, 'url');
    } elsif ($attr_xuri eq RDF_URL . 'nodeID') {
      $nodeid_attr = $attr;
      $self->onattr->($attr, 'rdf-id');
    } elsif ({
      %coreSyntaxTerms,
      RDF_URL . 'li' => 1,
      RDF_URL . 'Description' => 1,
      %oldTerms,
    }->{$attr_xuri}) {
      $self->onerror->(type => 'attribute not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $attr);
      $self->onattr->($attr, 'misc');
    } else {
      push @prop_attr, $attr;
      $self->onattr->($attr, 'string');
    }
  } # $attr

  my $parse = $parse_attr ? $parse_attr->value : '';
  if ($parse eq 'Resource') {
    # |parseTypeResourcePropertyElt|

    for my $attr ($resource_attr, $nodeid_attr, $dt_attr) {
      next unless $attr;
      $self->onerror->(type => 'attribute not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $attr);
    }
    
    my $object = {bnodeid => $generate_bnodeid->($self)};
    $self->ontriple->(subject => $opt{subject},
                        predicate => {uri => $xuri},
                        object => $object,
                        node => $node,
                        id => $get_id_resource->($self, $rdf_id_attr));
    
    ## As if nodeElement

    # |propertyEltList|
    
    my $li_counter = 1;
    for my $cn (@{$node->child_nodes}) {
      my $cn_type = $cn->node_type;
      if ($cn_type == 1) { # ELEMENT_NODE
        $self->convert_property_element ($cn, li_counter => \$li_counter,
                                         subject => $object,
                                         language => $opt{language});
      } elsif ($cn_type == 3) { # TEXT_NODE
        if ($cn->data =~ /[^\x09\x0A\x0D\x20]/) {
          $self->onerror->(type => 'character not allowed',
                             level => LEVEL_RDF_GRAMMER,
                             node => $cn);
          $self->onnonrdfnode->($cn);
        }
      } elsif ($cn_type == 7) { # PROCESSING_INSTRUCTION_NODE
        $self->onnonrdfnode->($cn);
      }
    }
  } elsif ($parse eq 'Collection') {
    # |parseTypeCollectionPropertyElt|

    for my $attr ($resource_attr, $nodeid_attr, $dt_attr) {
      next unless $attr;
      $self->onerror->(type => 'attribute not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $attr);
    }
    
    # |nodeElementList|
    my @resource;
    for my $cn (@{$node->child_nodes}) {
      if ($cn->node_type == 1) { # ELEMENT_NODE
        push @resource, [$self->convert_node_element ($cn),
                         {bnodeid => $generate_bnodeid->($self)},
                         $cn];
      } elsif ($cn->node_type == 3) { # TEXT_NODE
        if ($cn->data =~ /[^\x09\x0A\x0D\x20]/) {
          $self->onerror->(type => 'character not allowed',
                             level => LEVEL_RDF_GRAMMER,
                             node => $cn);
          $self->onnonrdfnode->($cn);
        }
      } elsif ($cn->node_type == 7) { # PROCESSING_INSTRUCTION_NODE
        $self->onnonrdfnode->($cn);
      }
    }

    if (@resource) {
      $self->ontriple->(subject => $opt{subject},
                          predicate => {uri => $xuri},
                          object => $resource[0]->[1],
                          node => $node);
    } else {
      $self->ontriple->(subject => $opt{subject},
                          predicate => {uri => $xuri},
                          object => {uri => RDF_URL . 'nil'},
                          node => $node,
                          id => $get_id_resource->($self, $rdf_id_attr));
    }
    
    while (@resource) {
      my $resource = shift @resource;
      $self->ontriple->(subject => $resource->[1],
                          predicate => {uri => RDF_URL . 'first'},
                          object => $resource->[0],
                          node => $resource->[2]);
      if (@resource) {
        $self->ontriple->(subject => $resource->[1],
                            predicate => {uri => RDF_URL . 'rest'},
                            object => $resource[0]->[1],
                            node => $resource->[2]);
      } else {
        $self->ontriple->(subject => $resource->[1],
                            predicate => {uri => RDF_URL . 'rest'},
                            object => {uri => RDF_URL . 'nil'},
                            node => $resource->[2]);
      }
    }
  } elsif ($parse_attr) {
    # |parseTypeLiteralPropertyElt|

    if ($parse ne 'Literal') {
      # |parseTypeOtherPropertyElt|
      $self->onerror->(type => 'parse type other',
                         level => 'w',
                         node => $parse_attr);
    }

    for my $attr ($resource_attr, $nodeid_attr, $dt_attr) {
      next unless $attr;
      $self->onerror->(type => 'attribute not allowed',
                         level => LEVEL_RDF_GRAMMER,
                         node => $attr);
    }

    $self->ontriple->(subject => $opt{subject},
                        predicate => {uri => $xuri},
                        object => {parent_node => $node,
                                   datatype => RDF_URL . 'XMLLiteral'},
                        node => $node,
                        id => $get_id_resource->($self, $rdf_id_attr));
  } else { # no rdf:parseType=""
    my $mode = 'unknown';

    if ($dt_attr) {
      $mode = 'literal'; # |literalPropertyElt|
    }
    
    my $node_element;
    my $text = '';
    for my $cn (@{$node->child_nodes}) {
      my $cn_type = $cn->node_type;
      if ($cn_type == 1) { # ELEMENT_NODE
        unless ($node_element) {
          $node_element = $cn;
          if ({
            resource => 1, unknown => 1, 'literal-or-resource' => 1,
          }->{$mode}) {
            $mode = 'resource';
          } else {
            $self->onerror->(type => 'element not allowed',
                               level => LEVEL_RDF_GRAMMER,
                               node => $cn);
            $self->onnonrdfnode->($cn);
          }
        } else {
          $self->onerror->(type => 'second node element',
                             level => LEVEL_RDF_GRAMMER,
                             node => $cn);
          $self->onnonrdfnode->($cn);
        }
      } elsif ($cn_type == 3) { # TEXT_NODE
        my $data = $cn->data;
        $text .= $data;
        if ($data =~ /[^\x09\x0A\x0D\x20]/) {
          if ({
               literal => 1, unknown => 1, 'literal-or-resource' => 1,
              }->{$mode}) {
            $mode = 'literal';
          } else {
            $self->onerror->(type => 'character not allowed',
                               level => LEVEL_RDF_GRAMMER,
                               node => $cn);
            $self->onnonrdfnode->($cn);
          }
        } else {
          if ($mode eq 'unknown') {
            $mode = 'literal-or-resource';
          } else {
            #
          }
        }
      } elsif ($cn_type == 7) { # PROCESSING_INSTRUCTION_NODE
        $self->onnonrdfnode->($cn);
      }
    } # $node->child_nodes
    
    if ($mode eq 'resource') {
      # |resourcePropertyElt|
      
      for my $attr (@prop_attr, $resource_attr, $nodeid_attr, $dt_attr) {
        next unless $attr;
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      
      my $object = $self->convert_node_element ($node_element,
                                                language => $opt{language});
      
      $self->ontriple->(subject => $opt{subject},
                          predicate => {uri => $xuri},
                          object => $object,
                          node => $node,
                          id => $get_id_resource->($self, $rdf_id_attr));
    } elsif ($mode eq 'literal' or $mode eq 'literal-or-resource') {
      # |literalPropertyElt|
      
      for my $attr (@prop_attr, $resource_attr, $nodeid_attr) {
        next unless $attr;
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      
      if ($dt_attr) {
        $self->ontriple
            ->(subject => $opt{subject},
               predicate => {uri => $xuri},
               object => {value => $text,
                          datatype => $uri_attr->($self, $dt_attr)},
               ## NOTE: No resolve() in the spec (but spec says that
               ## xml:base is applied also to rdf:datatype).
               node => $node,
               id => $get_id_resource->($self, $rdf_id_attr));
      } else {
        $self->ontriple->(subject => $opt{subject},
                            predicate => {uri => $xuri},
                            object => {value => $text,
                                       language => $opt{language}},
                            node => $node,
                            id => $get_id_resource->($self, $rdf_id_attr));
      }
    } else {
      ## |emptyPropertyElt|

      for my $attr ($dt_attr) {
        next unless $attr;
        $self->onerror->(type => 'attribute not allowed',
                           level => LEVEL_RDF_GRAMMER,
                           node => $attr);
      }
      
      if (not $resource_attr and not $nodeid_attr and not @prop_attr) {
        $self->ontriple->(subject => $opt{subject},
                            predicate => {uri => $xuri},
                            object => {value => '',
                                       language => $opt{language}},
                            node => $node,
                            id => $get_id_resource->($self, $rdf_id_attr));
      } else {
        my $object;
        if ($resource_attr) {
          $object = {uri => $uri_attr->($self, $resource_attr)};
          if (defined $nodeid_attr) {
            $self->onerror->(type => 'attribute not allowed',
                               level => LEVEL_RDF_GRAMMER,
                               node => $nodeid_attr);
          }
        } elsif ($nodeid_attr) {
          my $id = $nodeid_attr->value;
          $object = {bnodeid => $get_bnodeid->($id)};
        } else {
          $object = {bnodeid => $generate_bnodeid->($self)};
        }
        
        for my $attr (@prop_attr) {
          my $attr_xuri = $attr->manakai_expanded_uri;
          if ($attr_xuri eq RDF_URL . 'type') {
            $self->ontriple->(subject => $object,
                                predicate => {uri => $attr_xuri},
                                object => $resolve->($attr->value, $attr),
                                node => $attr);
          } else {
            $self->ontriple->(subject => $object,
                                predicate => {uri => $attr_xuri},
                                object => {value => $attr->value,
                                           language => $opt{language}},
                                node => $attr);
          }
        }

        $self->ontriple->(subject => $opt{subject},
                            predicate => {uri => $xuri},
                            object => $object,
                            node => $node,
                            id => $get_id_resource->($self, $rdf_id_attr));
      }
    }
  } # rdf:parseType=""
} # convert_property_element

# XXX onattr tests
# XXX SHOULD warn if not defined in RDF vocabulary
# XXX reification rule

# XXX datatype IRI checks
# XXX lexical form validation (?)
# XXX Attr validation:
#   - url MUST be a valid URL
#   - rdf-id MUST be an XML 1.0 Name
#   - common then validate by nsurl and local name
# XXX literal form SHOULD be NFC
# XXX URL validation
# XXX langtag validation

1;

=head1 LICENSE

Copyright 2008-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
