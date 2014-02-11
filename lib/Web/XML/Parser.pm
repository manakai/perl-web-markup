package Web::XML::Parser; # -*- Perl -*-
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '7.0';
use Encode;
use Web::HTML::Defs;
use Web::HTML::ParserData;
use Web::HTML::InputStream;
use Web::HTML::Tokenizer;
use Web::HTML::SourceMap;
push our @ISA, qw(Web::HTML::Tokenizer);

## Insertion modes
sub BEFORE_XML_DECL_IM () { 0 }
sub AFTER_XML_DECL_IM () { 1 }
sub BEFORE_ROOT_ELEMENT_IM () { 2 }
sub IN_ELEMENT_IM () { 3 }
sub AFTER_ROOT_ELEMENT_IM () { 4 }
sub IN_SUBSET_IM () { 5 }

sub parse_char_string ($$$) {
  #my ($self, $string, $document) = @_;
  my $self = $_[0];
  my $doc = $self->{document} = $_[2];
  {
    local $self->{document}->dom_config->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'} = 0;
    $self->{document}->text_content ('');
  }
  $self->{ge} ||= {};
  $self->{pe} ||= {};

  ## Confidence: irrelevant.
  $self->{confident} = 1;

  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;

  $self->{chars} = [split //, $_[1]];
  $self->{chars_pos} = 0;
  $self->{chars_pull_next} = sub { 0 };
  delete $self->{chars_was_cr};

  my $onerror = $self->onerror;
  $self->{parse_error} = sub {
    $onerror->(line => $self->{line}, column => $self->{column}, @_);
  };

  $self->{is_xml} = 1;

  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor;
  {
    $self->{t} = $self->_get_next_token;
    $self->_construct_tree;
    if (defined $self->{t} and
        $self->{t}->{type} == ABORT_TOKEN and
        defined $self->{t}->{extent}) {
      $onerror->(type => 'external entref',
                 value => $self->{t}->{name},
                 line => $self->{t}->{line},
                 column => $self->{t}->{column},
                 level => 'i');
      unshift @{$self->{token}}, {%{$self->{t}},
                                  type => ENTITY_SUBTREE_TOKEN,
                                  parsed_nodes => []};
      delete $self->{parser_pause};
      redo;
    }
  }

  return {};
} # parse_char_string

sub parse_char_string_with_context ($$$$) {
  my $self = $_[0];
  # $s $_[1]
  my $context = $_[2]; # Element or undef
  # $empty_doc $_[3]

  ## XML fragment parsing algorithm
  ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-fragments>

  ## 1.
  my $doc = $_[3];
  $self->{document} = $doc;
  $self->{ge} ||= {};
  $self->{pe} ||= {};
  
  ## Confidence: irrelevant.
  $self->{confident} = 1;

  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;

  # 3.
  $self->{chars} = [split //, $_[1]];
  $self->{chars_pos} = 0;
  $self->{chars_pull_next} = sub { 0 };
  delete $self->{chars_was_cr};

  my $onerror = $self->onerror;
  $self->{parse_error} = sub {
    $onerror->(line => $self->{line}, column => $self->{column}, @_);
  };

  $self->{is_xml} = 1;

  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor; # strict_error_checking (0)

  my $root;
  if (defined $context) {
    # 4., 6. (Fake end tag)
    $self->{inner_html_tag_name} = $context->manakai_tag_name;

    # 2. Fake start tag
    $root = $doc->create_element_ns
        ($context->namespace_uri, [$context->prefix, $context->local_name]);
    my $nsmap = {};
    {
      my $prefixes = {};
      my $p = $context;
      while ($p and $p->node_type == 1) { # ELEMENT_NODE
        $prefixes->{$_->local_name} = 1 for grep {
          ($_->namespace_uri || '') eq Web::HTML::ParserData::XMLNS_NS;
        } @{$p->attributes or []};
        my $prefix = $p->prefix;
        $prefixes->{$prefix} = 1 if defined $prefix;
        $p = $p->parent_node;
      }
      for ('', keys %$prefixes) {
        $nsmap->{$_} = $context->lookup_namespace_uri ($_);
      }
      $nsmap->{xml} = Web::HTML::ParserData::XML_NS;
      $nsmap->{xmlns} = Web::HTML::ParserData::XMLNS_NS;
    }
    push @{$self->{open_elements}},
        [$root, $self->{inner_html_tag_name}, $nsmap];
    $doc->append_child ($root);
    $self->{insertion_mode} = IN_ELEMENT_IM;
  }

  # 5. If not well-formed, throw SyntaxError - should be handled by
  # callee using $self->onerror.

  # XXX and well-formedness errors not detected by this parser

  {
    $self->{t} = $self->_get_next_token;
    $self->_construct_tree;
    if (defined $self->{t} and
        $self->{t}->{type} == ABORT_TOKEN and
        defined $self->{t}->{extent}) {
      $onerror->(type => 'external entref',
                 value => $self->{t}->{name},
                 line => $self->{t}->{line},
                 column => $self->{t}->{column},
                 level => 'i');
      unshift @{$self->{token}}, {%{$self->{t}},
                                  type => ENTITY_SUBTREE_TOKEN,
                                  parsed_nodes => []};
      delete $self->{parser_pause};
      redo;
    }
  }

  # 7.
  return defined $context
      ? $root->manakai_element_type_match (Web::HTML::ParserData::HTML_NS, 'template')
          ? $root->content->child_nodes : $root->child_nodes
      : $doc->child_nodes;
} # parse_char_string_with_context

## ------ Stream parse API (experimental) ------

# XXX XML encoding sniffer
# XXX documentation

sub parse_bytes_start ($$$) {
  my ($self, $charset_name, $doc) = @_;
  $self->{document} = $doc;
  
  $self->{chars_pull_next} = sub { 1 };
  $self->{restart_parser} = sub {
    $self->{embedded_encoding_name} = $_[0];
    # XXX need a hook to invoke a subset of "navigate" algorithm
    $self->{byte_buffer} = $self->{byte_buffer_orig};
    return 1;
  };
  
  my $onerror = $self->onerror;
  $self->{parse_error} = sub {
    $onerror->(line => $self->{line}, column => $self->{column}, @_);
  };

  $self->{byte_buffer} = '';
  $self->{byte_buffer_orig} = '';

  $self->_parse_bytes_start_parsing
      (transport_encoding_name => $_[1],
       no_body_data_yet => 1);
} # parse_bytes_start

sub _parse_bytes_start_parsing ($;%) {
  my ($self, %args) = @_;
  {
    local $self->{document}->dom_config->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'} = 0;
    $self->{document}->text_content ('');
  }
  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;
  $self->{chars} = [];
  $self->{chars_pos} = 0;
  delete $self->{chars_was_cr};
  
  $self->_encoding_sniffing
      (embedded_encoding_name => delete $self->{embedded_encoding_name},
       transport_encoding_name => $args{transport_encoding_name},
       no_body_data_yet => $args{no_body_data_yet},
       read_head => sub {
         return \(substr $self->{byte_buffer}, 0, 1024);
     }); # $self->{confident} is set within this method.
  if (not $self->{input_encoding} and $args{no_body_data_yet}) {
    delete $self->{parse_bytes_started};
    return;
  }

  $self->{parse_bytes_started} = 1;
  
  $self->{document}->input_encoding ($self->{input_encoding});

  $self->{is_xml} = 1;
  
  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor;

  my $context = $self->{context_element};
  if (defined $context) {
    # 4., 6. (Fake end tag)
    $self->{inner_html_tag_name} = $context->manakai_tag_name;

    # 2. Fake start tag
    my $root = $self->{document}->create_element_ns
        ($context->namespace_uri, [$context->prefix, $context->local_name]);
    my $nsmap = {};
    {
      my $prefixes = {};
      my $p = $context;
      while ($p and $p->node_type == 1) { # ELEMENT_NODE
        $prefixes->{$_->local_name} = 1 for grep {
          ($_->namespace_uri || '') eq Web::HTML::ParserData::XMLNS_NS;
        } @{$p->attributes or []};
        my $prefix = $p->prefix;
        $prefixes->{$prefix} = 1 if defined $prefix;
        $p = $p->parent_node;
      }
      for ('', keys %$prefixes) {
        $nsmap->{$_} = $context->lookup_namespace_uri ($_);
      }
      $nsmap->{xml} = Web::HTML::ParserData::XML_NS;
      $nsmap->{xmlns} = Web::HTML::ParserData::XMLNS_NS;
    }
    push @{$self->{open_elements}},
        [$root, $self->{inner_html_tag_name}, $nsmap];
    $self->{document}->append_child ($root);
    $self->{insertion_mode} = IN_ELEMENT_IM;
  } # $context

  push @{$self->{chars}}, split //,
      decode $self->{input_encoding}, $self->{byte_buffer}, # XXX Encoding Standard
          Encode::FB_QUIET;
  $self->_parse_bytes_run;
} # _parse_bytes_start_parsing

## The $args{start_parsing} flag should be set true if it has taken
## more than 500ms from the start of overall parsing process.
sub parse_bytes_feed ($$;%) {
  my ($self, undef, %args) = @_;

  if ($self->{parse_bytes_started}) {
    $self->{byte_buffer} .= $_[1];
    $self->{byte_buffer_orig} .= $_[1];
    push @{$self->{chars}},
        split //, decode $self->{input_encoding}, $self->{byte_buffer},
                         Encode::FB_QUIET; # XXX encoding standard
    my $i = 0;
    if (length $self->{byte_buffer} and @{$self->{chars}} == $i) {
      substr ($self->{byte_buffer}, 0, 1) = '';
      push @{$self->{chars}}, "\x{FFFD}", split //,
          decode $self->{input_encoding}, $self->{byte_buffer},
              Encode::FB_QUIET; # XXX Encoding Standard
      $i++;
    }
    $self->_parse_bytes_run;
  } else {
    $self->{byte_buffer} .= $_[1];
    $self->{byte_buffer_orig} .= $_[1];
    if ($args{start_parsing} or 1024 <= length $self->{byte_buffer}) {
      $self->_parse_bytes_start_parsing;
    }
  }
} # parse_bytes_feed

sub parse_bytes_end ($) {
  my $self = $_[0];
  unless ($self->{parse_bytes_started}) {
    $self->_parse_bytes_start_parsing;
  }

  if (length $self->{byte_buffer}) {
    push @{$self->{chars}},
        split //, decode $self->{input_encoding}, $self->{byte_buffer}; # XXX encoding standard
    $self->{byte_buffer} = '';
  }
  $self->{chars_pull_next} = sub { 0 };
  $self->_parse_bytes_run;
} # parse_bytes_end

sub _parse_bytes_run ($) {
  my $self = $_[0];

  ## This is either the first invocation of the |_get_next_token|
  ## method or |$self->{t}| is an |ABORT_TOKEN|.
  $self->{t} = $self->_get_next_token;

  $self->_construct_tree;
  return unless defined $self->{t}; ## _stop_parsing is invoked

  ## HTML only
  if ($self->{embedded_encoding_name}) {
    ## Restarting the parser
    $self->_parse_bytes_start_parsing;
  }

  ## XML only
  if ($self->{t}->{type} == ABORT_TOKEN and defined $self->{t}->{extent}) {
    my $subparser = Web::XML::Parser::SubParser->new_from_parser ($self);
    $self->onextentref->($self, $self->{t}, $subparser);
  }
} # _parse_bytes_run

sub _parse_bytes_subparser_done ($$$) {
  my ($self, $node, $token) = @_;
  ## |$token| is an |ABORT_TOKEN| requesting the external entity.
  unshift @{$self->{token}}, {%$token,
                              type => ENTITY_SUBTREE_TOKEN,
                              parsed_nodes => $node->child_nodes};
  delete $self->{parser_pause};
  $self->_parse_bytes_run;
} # _parse_bytes_subparser_done

{
  package Web::XML::Parser::SubParser;
  push our @ISA, qw(Web::XML::Parser);

  sub new_from_parser ($$) {
    my $self = $_[0]->new;
    my $main_parser = $_[1];
    $self->{ge} = $main_parser->{ge};
    $self->{pe} = $main_parser->{pe};
    $self->{document} = $main_parser->{document}->implementation->create_document;
    $self->{context_element} = @{$main_parser->{open_elements}}
        ? $main_parser->{open_elements}->[-1]->[0]
        : $self->{document}->create_element_ns (undef, 'dummy');
    $self->onerror ($main_parser->onerror);
    $self->onextentref ($main_parser->onextentref);
    my $t = $main_parser->{t};
    $self->onparsed (sub { $main_parser->_parse_bytes_subparser_done ($_[1], $t) });
    return $self;
  } # new_from_parser

  sub parse_bytes_start ($$$) {
    return $_[0]->SUPER::parse_bytes_start ($_[1], $_[0]->{document});
  } # parse_bytes_start
}

sub _stop_parsing ($) {
  # XXX stop parsing
  $_[0]->_on_terminate;
} # _stop_parsing

sub _on_terminate ($) {
  $_[0]->onparsed->($_[0], $_[0]->{context_element} ? $_[0]->{document}->document_element : $_[0]->{document});
  $_[0]->_terminate_tree_constructor;
  $_[0]->_clear_refs;
} # _on_terminate

sub onextentref ($;$) {
  if (@_ > 1) {
    $_[0]->{onextentref} = $_[1];
  }
  return $_[0]->{onextentref} ||= sub {
    my ($self, $t, $subparser) = @_;
    $self->{parse_error}->(type => 'external entref',
                           value => $t->{name},
                           line => $t->{line},
                           column => $t->{column},
                           level => 'i');
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_end;
  };
} # onextentref

sub onparsed ($;$) {
  if (@_ > 1) {
    $_[0]->{onparsed} = $_[1];
  }
  return $_[0]->{onparsed} ||= sub { };
} # onparsed

## ------ Tree construction ------

sub _initialize_tree_constructor ($) {
  my $self = shift;
  ## NOTE: $self->{document} MUST be specified before this method is called
  $self->{document}->strict_error_checking (0);
  ## (Turn mutation events off)
  $self->{document}->dom_config
      ->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'}
      = 0;
  $self->{document}->dom_config->{manakai_allow_doctype_children} = 1
      if exists $self->{document}->dom_config
          ->{manakai_allow_doctype_children};
  $self->{document}->manakai_is_html (0);
  $self->{document}->set_user_data (manakai_source_line => 1);
  $self->{document}->set_user_data (manakai_source_column => 1);

  $self->{ge}->{'amp;'} = {value => '&', only_text => 1};
  $self->{ge}->{'apos;'} = {value => "'", only_text => 1};
  $self->{ge}->{'gt;'} = {value => '>', only_text => 1};
  $self->{ge}->{'lt;'} = {value => '<', only_text => 1};
  $self->{ge}->{'quot;'} = {value => '"', only_text => 1};

  delete $self->{tainted};
  $self->{open_elements} = [];
  $self->{insertion_mode} = BEFORE_XML_DECL_IM;
} # _initialize_tree_constructor

sub _terminate_tree_constructor ($) {
  my $self = shift;
  if (my $doc = $self->{document}) {
    $doc->strict_error_checking (1);
    $doc->dom_config
        ->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'}
        = 1;
    $doc->dom_config->{manakai_allow_doctype_children} = 0
        if exists $doc->dom_config->{manakai_allow_doctype_children};
    ## (Turn mutation events on)
  }
} # _terminate_tree_constructor

## Tree construction stage

## Differences from the XML5 spec are marked as "XML5:".

## XML5: The spec has no namespace support.

## XML5: Start, main, end phases in the spec are represented as
## insertion modes.  BEFORE_XML_DECL_IM and AFTER_XML_DECL_IM are not
## defined in the spec.

## XML5: The spec does not support entity expansion.

# XXXsps
#   - drop manakai_pos
#   - docid
#   - errors.txt

# XXX spec external entity in element content
# XXX text declarations in external GEs
# XXX param refs
# XXX external subset
# XXX entref depth limitation
# XXX PE pos
# XXX well-formedness of entity decls
# XXX double-escaped entity value

# XXX external entity support
# <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-documents>

# XXX elemsnts in GEref vs script execution, stack of open elements
# considerations...

# XXX GEref: 
#       If internal entity, expanded.
#       If unparsed entity, a well-formedness error.
#       If external entity, expanded to the empty string.
#       Otherwise, a well-formedness error.

sub _insert_point ($) {
  return $_[0]->manakai_element_type_match (Web::HTML::ParserData::HTML_NS, 'template') ? $_[0]->content : $_[0];
} # _insert_point

sub _construct_tree ($) {
  my ($self) = @_;
  my $onerror = $self->onerror;
  B: {
    return if $self->{t}->{type} == ABORT_TOKEN;

    if ($self->{insertion_mode} == IN_ELEMENT_IM) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        while ($self->{t}->{data} =~ s/\x00/\x{FFFD}/) {
          $onerror->(level => 'm', type => 'NULL', token => $self->{t});
        }
        my $parent = _insert_point $self->{open_elements}->[-1]->[0];
        $self->_append_text_by_token ($self->{t} => $parent);
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        my $nsmap = {%{$self->{open_elements}->[-1]->[2]}};

        my $attrs = $self->{t}->{attributes};
        my $attrdefs = $self->{attrdef}->{$self->{t}->{tag_name}};
        for my $attr_name (keys %{$attrdefs}) {
          if ($attrs->{$attr_name}) {
            $attrs->{$attr_name}->{type} = $attrdefs->{$attr_name}->{type} || 0;
            if ($attrdefs->{$attr_name}->{tokenize}) {
              $attrs->{$attr_name}->{value} =~ s/  +/ /g;
              $attrs->{$attr_name}->{value} =~ s/\A //;
              $attrs->{$attr_name}->{value} =~ s/ \z//;
            }
          } elsif (defined $attrdefs->{$attr_name}->{default}) {
            $attrs->{$attr_name} = {
              value => $attrdefs->{$attr_name}->{default},
              type => $attrdefs->{$attr_name}->{type} || 0,
              not_specified => 1,
              line => $attrdefs->{$attr_name}->{line},
              column => $attrdefs->{$attr_name}->{column},
              index => 1 + keys %{$attrs},
              sps => $attrdefs->{$attr_name}->{sps},
            };
          }
        }
        
        for (keys %$attrs) {
          if (/^xmlns:./s) {
            my $prefix = substr $_, 6;
            my $value = $attrs->{$_}->{value};
            if ($prefix eq 'xml' or $prefix eq 'xmlns' or
                $value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{$prefix} = $value;
            } else {
              delete $nsmap->{$prefix};
            }
          } elsif ($_ eq 'xmlns') {
            my $value = $attrs->{$_}->{value};
            if ($value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{''} = $value;
            } else {
              delete $nsmap->{''};
            }
          }
        }
        
        my $ns;
        my ($prefix, $ln) = split /:/, $self->{t}->{tag_name}, 2;
        
        if (defined $ln and $prefix ne '' and $ln ne '') { # prefixed
          if (defined $nsmap->{$prefix}) {
            $ns = $nsmap->{$prefix};
          } else {
            ## NOTE: Error should be detected at the DOM layer.
            ($prefix, $ln) = (undef, $self->{t}->{tag_name});
          }
        } else {
          $ns = $nsmap->{''} if $prefix ne '' and not defined $ln;
          ($prefix, $ln) = (undef, $self->{t}->{tag_name});
        }

        my $el = $self->{document}->create_element_ns ($ns, [$prefix, $ln]);
        $el->set_user_data (manakai_source_line => $self->{t}->{line});
        $el->set_user_data (manakai_source_column => $self->{t}->{column});

        my $has_attr;
        for my $attr_name (sort {$attrs->{$a}->{index} <=> $attrs->{$b}->{index}}
                           keys %$attrs) {
          my $ns;
          my ($p, $l) = split /:/, $attr_name, 2;

          if ($attr_name eq 'xmlns:xmlns') {
            ($p, $l) = (undef, $attr_name);
          } elsif (defined $l and $p ne '' and $l ne '') { # prefixed
            if (defined $nsmap->{$p}) {
              $ns = $nsmap->{$p};
            } else {
              ## NOTE: Error should be detected at the DOM-layer.
              ($p, $l) = (undef, $attr_name);
            }
          } else {
            if ($attr_name eq 'xmlns') {
              $ns = $nsmap->{xmlns};
            }
            ($p, $l) = (undef, $attr_name);
          }
          
          if ($has_attr->{defined $ns ? $ns : ''}->{$l}) {
            $ns = undef;
            ($p, $l) = (undef, $attr_name);
          } else {
            $has_attr->{defined $ns ? $ns : ''}->{$l} = 1;
          }

          my $attr_t = $attrs->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns ($ns, [$p, $l]);
          $attr->value ($attr_t->{value});
          if (defined $attr_t->{type}) {
            $attr->manakai_attribute_type ($attr_t->{type});
          } elsif ($self->{document}->all_declarations_processed) {
            $attr->manakai_attribute_type (0); # no value
          } else {
            $attr->manakai_attribute_type (11); # unknown
          }
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $attr->set_user_data (manakai_sps => $attr_t->{sps}) if $attr_t->{sps};
          $el->set_attribute_node_ns ($attr);
          $attr->specified (0) if $attr_t->{not_specified};
        }

        (_insert_point $self->{open_elements}->[-1]->[0])
            ->append_child ($el);

        if ($self->{self_closing}) {
          delete $self->{self_closing}; # ack
        } else {
          push @{$self->{open_elements}}, [$el, $self->{t}->{tag_name}, $nsmap];
        }
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq '') {
          ## Short end tag token.
          if (@{$self->{open_elements}} == 1 and
              defined $self->{inner_html_tag_name}) {
            ## Not in XML5: Fragment case
            $onerror->(level => 'm', type => 'unmatched end tag',
                            text => '',
                            token => $self->{t});
          } else {
            pop @{$self->{open_elements}};
          }
        } elsif ($self->{open_elements}->[-1]->[1] eq $self->{t}->{tag_name}) {
          if (@{$self->{open_elements}} == 1 and
              defined $self->{inner_html_tag_name} and
              $self->{inner_html_tag_name} eq $self->{t}->{tag_name}) {
            ## Not in XML5: Fragment case
            $onerror->(level => 'm', type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
          } else {
            pop @{$self->{open_elements}};
          }
        } else {
          $onerror->(level => 'm', type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          
          ## Has an element in scope
          INSCOPE: for my $i (reverse 0..$#{$self->{open_elements}}) {
            if ($self->{open_elements}->[$i]->[1] eq $self->{t}->{tag_name}) {
              splice @{$self->{open_elements}}, $i;
              last INSCOPE;
            }
          } # INSCOPE
        }
        
        unless (@{$self->{open_elements}}) {
          $self->{insertion_mode} = AFTER_ROOT_ELEMENT_IM;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          ## Stay in the state.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        my $comment = $self->{document}->create_comment ($self->{t}->{data});
        (_insert_point $self->{open_elements}->[-1]->[0])
            ->append_child ($comment);
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        (_insert_point $self->{open_elements}->[-1]->[0])
            ->append_child ($pi);

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        if (defined $self->{inner_html_tag_name} and
            @{$self->{open_elements}} == 1 and
            $self->{open_elements}->[0]->[1] eq $self->{inner_html_tag_name}) {
          ## Not in XML5: Fragment case
          #
        } else {
          $onerror->(level => 'm', type => 'in body:#eof',
                          token => $self->{t});
        }
        
        $self->{insertion_mode} = AFTER_ROOT_ELEMENT_IM;
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ENTITY_SUBTREE_TOKEN) {
        my $list = $self->_parse_entity_subtree_token;
        my $parent = _insert_point $self->{open_elements}->[-1]->[0];
        my $lc = $parent->last_child;
        for (@$list) {
          if ($_->node_type == 3) { # TEXT_NODE
            if (defined $lc and $lc->node_type == 3) { # TEXT_NODE
              my $sp2 = $_->get_user_data ('manakai_sps');
              my $sp = $lc->get_user_data ('manakai_sps');
              $sp = [] unless defined $sp and ref $sp eq 'ARRAY';
              my $delta = length $lc->data;
              $_->[0] += $delta for @$sp2;
              push @$sp, @$sp2;
              $lc->set_user_data (manakai_sps => $sp);
              $lc->manakai_append_text ($_->data);
            } else {
              $parent->append_child ($lc = $_);
            }
          } else {
            $parent->append_child ($_);
            $lc = $_;
          }
        }

        ## Stay in the state.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        $onerror->(level => 'm', type => 'in html:#doctype',
                        token => $self->{t});
        ## Ignore the token.
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: XML parser initial: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == IN_SUBSET_IM) {
      if ($self->{t}->{type} == COMMENT_TOKEN) {
        ## Ignore the token.

        ## Stay in the state.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ELEMENT_TOKEN) {
        unless ($self->{has_element_decl}->{$self->{t}->{name}}) {
          my $node = $self->{doctype}->get_element_type_definition_node
              ($self->{t}->{name});
          unless ($node) {
            $node = $self->{document}->create_element_type_definition
                ($self->{t}->{name});
            $self->{doctype}->set_element_type_definition_node ($node);
          }
          
          $node->set_user_data (manakai_source_line => $self->{t}->{line});
          $node->set_user_data (manakai_source_column => $self->{t}->{column});
          
          $node->content_model_text (join '', @{$self->{t}->{content}})
              if $self->{t}->{content};
        } else {
          $onerror->(level => 'm', type => 'duplicate element decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});
          
          ## TODO: $self->{t}->{content} syntax check.
        }
        $self->{has_element_decl}->{$self->{t}->{name}} = 1;

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ATTLIST_TOKEN) {
        if ($self->{stop_processing}) {
          ## TODO: syntax validation
        } else {
          my $ed = $self->{doctype}->get_element_type_definition_node
              ($self->{t}->{name});
          unless ($ed) {
            $ed = $self->{document}->create_element_type_definition
                ($self->{t}->{name});
            $ed->set_user_data (manakai_source_line => $self->{t}->{line});
            $ed->set_user_data (manakai_source_column => $self->{t}->{column});
            $self->{doctype}->set_element_type_definition_node ($ed);
          } elsif ($self->{has_attlist}->{$self->{t}->{name}}) {
            $onerror->(level => 'w', type => 'duplicate attlist decl', ## TODO: type
                            value => $self->{t}->{name},
                            token => $self->{t});
          }
          $self->{has_attlist}->{$self->{t}->{name}} = 1;
          
          unless (@{$self->{t}->{attrdefs}}) {
            $onerror->(level => 'w', type => 'empty attlist decl', ## TODO: type
                            value => $self->{t}->{name},
                            token => $self->{t});
          }
          
          for my $at (@{$self->{t}->{attrdefs}}) {
            unless ($ed->get_attribute_definition_node ($at->{name})) {
              my $node = $self->{document}->create_attribute_definition
                  ($at->{name});
              $node->set_user_data (manakai_source_line => $at->{line});
              $node->set_user_data (manakai_source_column => $at->{column});
              $node->set_user_data (manakai_pos => $at->{pos}) if $at->{pos};
              $node->set_user_data (manakai_sps => $at->{sps}) if $at->{sps};
              
              my $type = defined $at->{type} ? {
                CDATA => 1, ID => 2, IDREF => 3, IDREFS => 4, ENTITY => 5,
                ENTITIES => 6, NMTOKEN => 7, NMTOKENS => 8, NOTATION => 9,
              }->{$at->{type}} : 10;
              if (defined $type) {
                $node->declared_type ($type);
              } else {
                $onerror->(level => 'm', type => 'unknown declared type', ## TODO: type
                                value => $at->{type},
                                token => $at);
              }
              
              push @{$node->allowed_tokens}, @{$at->{tokens}};
              
              my $default = defined $at->{default} ? {
                FIXED => 1, REQUIRED => 2, IMPLIED => 3,
              }->{$at->{default}} : 4;
              if (defined $default) {
                $node->default_type ($default);
                if (defined $at->{value}) {
                  if ($default == 1 or $default == 4) {
                    #
                  } elsif (length $at->{value}) {
                    $onerror->(level => 'm', type => 'default value not allowed', ## TODO: type
                                    token => $at);
                  }
                } else {
                  if ($default == 1 or $default == 4) {
                    $onerror->(level => 'm', type => 'default value not provided', ## TODO: type
                                    token => $at);
                  }
                }
              } else {
                $onerror->(level => 'm', type => 'unknown default type', ## TODO: type
                                value => $at->{default},
                                token => $at);
              }

              $type ||= 0;
              my $tokenize = (2 <= $type and $type <= 10);

              if (defined $at->{value}) {
                if ($tokenize) {
                  $at->{value} =~ s/  +/ /g;
                  $at->{value} =~ s/\A //;
                  $at->{value} =~ s/ \z//;
                }
                $node->text_content ($at->{value});
              }
              
              $ed->set_attribute_definition_node ($node);

              ## For tree construction
              $self->{attrdef}->{$self->{t}->{name}}->{$at->{name}} = {
                type => $type,
                tokenize => $tokenize,
                default => (($default and ($default == 1 or $default == 4))
                              ? defined $at->{value} ? $at->{value} : ''
                              : undef),
                line => $at->{line},
                column => $at->{column},
                sps => $at->{sps},
              };
            } else {
              $onerror->(level => 'w', type => 'duplicate attrdef', ## TODO: type
                              value => $at->{name},
                              token => $at);
              
              ## TODO: syntax validation
            }
          } # $at
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == GENERAL_ENTITY_TOKEN) {
        if ($self->{stop_processing}) {
          ## TODO: syntax validation
        } elsif ({
          amp => 1, apos => 1, quot => 1, lt => 1, gt => 1,
        }->{$self->{t}->{name}}) {
          if (not defined $self->{t}->{value} or
              not $self->{t}->{value} =~ {
                amp => qr/\A&#(?:x0*26|0*38);\z/,
                lt => qr/\A&#(?:x0*3[Cc]|0*60);\z/,
                gt => qr/\A(?>&#(?:x0*3[Ee]|0*62);|>)\z/,
                quot => qr/\A(?>&#(?:x0*22|0*34);|")\z/,
                apos => qr/\A(?>&#(?:x0*27|0*39);|')\z/,
              }->{$self->{t}->{name}}) {
            $onerror->(level => 'm', type => 'bad predefined entity decl', ## TODO: type
                            value => $self->{t}->{name},
                            token => $self->{t});
          }

          $self->{ge}->{$self->{t}->{name}.';'} = {
            name => $self->{t}->{name},
            value => {
              amp => '&',
              lt => '<',
              gt => '>',
              quot => '"',
              apos => "'",
            }->{$self->{t}->{name}},
            only_text => 1,
          };
        } elsif (not $self->{ge}->{$self->{t}->{name}.';'}) {
          ## For parser.
          $self->{ge}->{$self->{t}->{name}.';'} = $self->{t};
          if (defined $self->{t}->{value} and
              $self->{t}->{value} !~ /[&<]/) {
            $self->{t}->{only_text} = 1;
          }
          if (defined $self->{t}->{sps}) {
            $_->[4] = 0 for @{$self->{t}->{sps}}; # XXX di
          }
          
          ## For DOM.
          if (defined $self->{t}->{notation}) {
            my $node = $self->{document}->create_general_entity ($self->{t}->{name});
            $node->set_user_data (manakai_source_line => $self->{t}->{line});
            $node->set_user_data (manakai_source_column => $self->{t}->{column});
            
            $node->public_id ($self->{t}->{pubid}); # may be undef
            $node->system_id ($self->{t}->{sysid}); # may be undef
            $node->notation_name ($self->{t}->{notation});
            
            $self->{doctype}->set_general_entity_node ($node);
          } else {
            ## TODO: syntax validation
          }
        } else {
          $onerror->(level => 'w', type => 'duplicate general entity decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});

          ## TODO: syntax validation        
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PARAMETER_ENTITY_TOKEN) {
        if ($self->{stop_processing}) {
          ## TODO: syntax validation
        } elsif (not $self->{pe}->{$self->{t}->{name}}) {
          ## For parser.
          $self->{pe}->{$self->{t}->{name}} = $self->{t};

          ## TODO: syntax validation
        } else {
          $onerror->(level => 'w', type => 'duplicate para entity decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});

          ## TODO: syntax validation        
        }
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == NOTATION_TOKEN) {
        unless ($self->{doctype}->get_notation_node ($self->{t}->{name})) {
          my $node = $self->{document}->create_notation ($self->{t}->{name});
          $node->set_user_data (manakai_source_line => $self->{t}->{line});
          $node->set_user_data (manakai_source_column => $self->{t}->{column});
          
          $node->public_id ($self->{t}->{pubid}); # may be undef
          $node->system_id ($self->{t}->{sysid}); # may be undef
          
          $self->{doctype}->set_notation_node ($node);
        } else {
          $onerror->(level => 'm', type => 'duplicate notation decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});

          ## TODO: syntax validation
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        $self->{doctype}->append_child ($pi);
        ## TODO: line/col
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_OF_DOCTYPE_TOKEN) {
        $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: XML parser subset im: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == AFTER_ROOT_ELEMENT_IM) { ## End phase
      if ($self->{t}->{type} == START_TAG_TOKEN) {
        $onerror->(level => 'm', type => 'second root element',
                   token => $self->{t});

        ## Ignore the token.
        if ($self->{self_closing}) {
          delete $self->{self_closing}; # ack
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        my $comment = $self->{document}->create_comment ($self->{t}->{data});
        $self->{document}->append_child ($comment);
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        $self->{document}->append_child ($pi);

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == CHARACTER_TOKEN) {
        ## XML5: Always a parse error.

        unless ($self->{tainted}) {
          $self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]*)//;
          if (length $self->{t}->{data}) {
            my $l = $self->{t}->{line};
            my $c = $self->{t}->{column};
            my $sp = $1;
            $l += $sp =~ /\x0A/g;
            $c = $l == $self->{t}->{line} ? $c + length $1 : length $1
                if $sp =~ /([^\x0A]+)\z/;
            $onerror->(level => 'm', type => 'text outside of root element',
                       token => $self->{t}, line => $l, column => $c);
            $self->{tainted} = 1;
          }
        }

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        return $self->_stop_parsing;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        $onerror->(level => 'm', type => 'unmatched end tag',
                   value => $self->{t}->{tag_name},
                   token => $self->{t});

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ENTITY_SUBTREE_TOKEN) {
        ## Ignore the token.
        ## Stay in the state.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        $onerror->(level => 'm', type => 'in html:#doctype',
                   token => $self->{t});

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: XML parser initial: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == BEFORE_ROOT_ELEMENT_IM) { ## Start phase
      if ($self->{t}->{type} == START_TAG_TOKEN) {
        my $nsmap = {
          xml => q<http://www.w3.org/XML/1998/namespace>,
          xmlns => q<http://www.w3.org/2000/xmlns/>,
        };

        my $attrs = $self->{t}->{attributes};
        my $attrdefs = $self->{attrdef}->{$self->{t}->{tag_name}};
        for my $attr_name (keys %{$attrdefs}) {
          if ($attrs->{$attr_name}) {
            $attrs->{$attr_name}->{type} = $attrdefs->{$attr_name}->{type} || 0;
            if ($attrdefs->{$attr_name}->{tokenize}) {
              $attrs->{$attr_name}->{value} =~ s/  +/ /g;
              $attrs->{$attr_name}->{value} =~ s/\A //;
              $attrs->{$attr_name}->{value} =~ s/ \z//;
            }
          } elsif (defined $attrdefs->{$attr_name}->{default}) {
            $attrs->{$attr_name} = {
              value => $attrdefs->{$attr_name}->{default},
              type => $attrdefs->{$attr_name}->{type} || 0,
              not_specified => 1,
              line => $attrdefs->{$attr_name}->{line},
              column => $attrdefs->{$attr_name}->{column},
              index => 1 + keys %{$attrs},
              sps => $attrdefs->{$attr_name}->{sps},
            };
          }
        }
        
        for (keys %{$attrs}) {
          if (/^xmlns:./s) {
            my $prefix = substr $_, 6;
            my $value = $attrs->{$_}->{value};
            if ($prefix eq 'xml' or $prefix eq 'xmlns' or
                $value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{$prefix} = $value;
            } else {
              delete $nsmap->{$prefix};
            }
          } elsif ($_ eq 'xmlns') {
            my $value = $attrs->{$_}->{value};
            if ($value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{''} = $value;
            } else {
              delete $nsmap->{''};
            }
          }
        }
        
        my $ns;
        my ($prefix, $ln) = split /:/, $self->{t}->{tag_name}, 2;
        
        if (defined $ln and $prefix ne '' and $ln ne '') { # prefixed
          if (defined $nsmap->{$prefix}) {
            $ns = $nsmap->{$prefix};
          } else {
            ($prefix, $ln) = (undef, $self->{t}->{tag_name});
          }
        } else {
          $ns = $nsmap->{''} if $prefix ne '' and not defined $ln;
          ($prefix, $ln) = (undef, $self->{t}->{tag_name});
        }

        my $el = $self->{document}->create_element_ns ($ns, [$prefix, $ln]);
        $el->set_user_data (manakai_source_line => $self->{t}->{line});
        $el->set_user_data (manakai_source_column => $self->{t}->{column});

        my $has_attr;
        for my $attr_name (sort {$attrs->{$a}->{index} <=> $attrs->{$b}->{index}}
                           keys %$attrs) {
          my $ns;
          my ($p, $l) = split /:/, $attr_name, 2;

          if ($attr_name eq 'xmlns:xmlns') {
            ($p, $l) = (undef, $attr_name);
          } elsif (defined $l and $p ne '' and $l ne '') { # prefixed
            if (defined $nsmap->{$p}) {
              $ns = $nsmap->{$p};
            } else {
              ## NOTE: Error should be detected at the DOM-layer.
              ($p, $l) = (undef, $attr_name);
            }
          } else {
            if ($attr_name eq 'xmlns') {
              $ns = $nsmap->{xmlns};
            }
            ($p, $l) = (undef, $attr_name);
          }
          
          if ($has_attr->{defined $ns ? $ns : ''}->{$l}) {
            $ns = undef;
            ($p, $l) = (undef, $attr_name);
          } else {
            $has_attr->{defined $ns ? $ns : ''}->{$l} = 1;
          }
          
          my $attr_t = $attrs->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns ($ns, [$p, $l]);
          $attr->value ($attr_t->{value});
          if (defined $attr_t->{type}) {
            $attr->manakai_attribute_type ($attr_t->{type});
          } elsif ($self->{document}->all_declarations_processed) {
            $attr->manakai_attribute_type (0); # no value
          } else {
            $attr->manakai_attribute_type (11); # unknown
          }
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $attr->set_user_data (manakai_sps => $attr_t->{sps}) if $attr_t->{sps};
          $el->set_attribute_node_ns ($attr);
          $attr->specified (0) if $attr_t->{not_specified};
        }

        $self->{document}->append_child ($el);

        if ($self->{self_closing}) {
          delete $self->{self_closing}; # ack
          $self->{insertion_mode} = AFTER_ROOT_ELEMENT_IM;
        } else {
          push @{$self->{open_elements}}, [$el, $self->{t}->{tag_name}, $nsmap];
          $self->{insertion_mode} = IN_ELEMENT_IM;
        }
        
        #delete $self->{tainted};

        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        my $comment = $self->{document}->create_comment ($self->{t}->{data});
        $self->{document}->append_child ($comment);
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        $self->{document}->append_child ($pi);

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == CHARACTER_TOKEN) {
        ## XML5: Always a parse error.

        unless ($self->{tainted}) {
          $self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]*)//;
          if (length $self->{t}->{data}) {
            my $l = $self->{t}->{line};
            my $c = $self->{t}->{column};
            my $sp = $1;
            $l += ($sp =~ /\x0A/g);
            $l--, $c = 1 if $c == 0;
            $c = ($l == $self->{t}->{line}) ? ($c + length $1) : (1 + length $1)
                if $sp =~ /([^\x0A]+)\z/;
            $onerror->(level => 'm', type => 'text outside of root element',
                       token => $self->{t}, line => $l, column => $c);
            $self->{tainted} = 1;
          }
        }

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        $onerror->(level => 'm', type => 'no root element',
                        token => $self->{t});
        
        $self->{insertion_mode} = AFTER_ROOT_ELEMENT_IM;
        ## Reprocess the token.
        redo B;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        $onerror->(level => 'm', type => 'stray end tag',
                   value => $self->{t}->{tag_name},
                   token => $self->{t});

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ENTITY_SUBTREE_TOKEN) {
        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        $onerror->(level => 'm', type => 'second doctype', # XXXdoc
                   token => $self->{t});

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: XML parser initial: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == AFTER_XML_DECL_IM) {
      ## XML5: DOCTYPE is not supported.

      if ($self->{t}->{type} == DOCTYPE_TOKEN) {
        my $doctype = $self->{document}->create_document_type_definition
            (defined $self->{t}->{name} ? $self->{t}->{name} : '');
        
        ## NOTE: Default value for both |public_id| and |system_id|
        ## attributes are empty strings, so that we don't set any
        ## value in missing cases.
        $doctype->public_id ($self->{t}->{pubid}) if defined $self->{t}->{pubid};
        $doctype->system_id ($self->{t}->{sysid}) if defined $self->{t}->{sysid};
        
        ## TODO: internal_subset
        
        $self->{document}->append_child ($doctype);

        %{$self->{ge}} = ();

        ## XML5: No "has internal subset" flag.
        if ($self->{t}->{has_internal_subset}) {
          $self->{doctype} = $doctype;
          $self->{insertion_mode} = IN_SUBSET_IM;
        } else {
          $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
        }
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN or
               $self->{t}->{type} == END_OF_FILE_TOKEN or
               $self->{t}->{type} == ENTITY_SUBTREE_TOKEN) {
        $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
        ## Reprocess the token.
        redo B;
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        my $comment = $self->{document}->create_comment ($self->{t}->{data});
        $self->{document}->append_child ($comment);
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        $self->{document}->append_child ($pi);

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ /[^\x09\x0A\x0C\x20]/) {
          $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
          ## Reprocess the token.
          redo B;
        } else {
          ## Stay in the mode.
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        $onerror->(level => 'm', type => 'stray end tag',
                   value => $self->{t}->{tag_name},
                   token => $self->{t});

        ## Ignore the token.
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: XML parser initial: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == BEFORE_XML_DECL_IM) {
      ## XML5: No support for the XML declaration

      if ($self->{t}->{type} == PI_TOKEN and
          $self->{t}->{target} eq 'xml' and
          $self->{t}->{data} =~ /\Aversion[\x09\x0A\x20]*=[\x09\x0A\x20]*
                         (?>"([^"]*)"|'([^']*)')
                         (?:[\x09\x0A\x20]+
                            encoding[\x09\x0A\x20]*=[\x09\x0A\x20]*
                            (?>"([^"]*)"|'([^']*)')[\x09\x0A\x20]*)?
                         (?:[\x09\x0A\x20]+
                            standalone[\x09\x0A\x20]*=[\x09\x0A\x20]*
                            (?>"(yes|no)"|'(yes|no)'))?
                         [\x09\x0A\x20]*\z/x) {
        $self->{document}->xml_version (defined $1 ? $1 : $2);
        # XXX drop XML 1.1 support?
        $self->{is_xml} = 1.1 if defined $1 and $1 eq '1.1';
        $self->{document}->xml_encoding (defined $3 ? $3 : $4); # or undef
        $self->{document}->xml_standalone (($5 || $6 || 'no') ne 'no');

        $self->{insertion_mode} = AFTER_XML_DECL_IM;
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        $self->{document}->xml_version ('1.0');
        $self->{document}->xml_encoding (undef);
        $self->{document}->xml_standalone (0);
        $self->{insertion_mode} = AFTER_XML_DECL_IM;
        ## Reconsume the token,
        redo B;
      }
    } else {
      die "$0: Unknown XML insertion mode: $self->{insertion_mode}";
    }
    die;
  } # B
} # _construct_tree

sub _parse_entity_subtree_token ($) {
  my $self = $_[0];
  my $t = $self->{t};

  ## Internal entity with "&" and/or "<" in entity value, referenced
  ## from element content.

  return $t->{parsed_nodes} if defined $t->{parsed_nodes};

  my $context = @{$self->{open_elements}}
      ? $self->{open_elements}->[-1]->[0]
      : $self->{document}->create_element_ns (undef, 'dummy');

  my $map_parsed = create_pos_lc_map $self->{ge}->{$t->{name}}->{value};
  my $map_source = $self->{ge}->{$t->{name}}->{sps} || [];

  my $doc = $self->{document}->implementation->create_document;
  my $parser = (ref $self)->new;
  $parser->onerror (sub {
    my %args = @_;
    lc_lc_mapper $map_parsed => $map_source, \%args;
    $self->onerror->(%args);
  });
  $parser->{ge} = {%{$self->{ge}}};
  delete $parser->{ge}->{$t->{name}};
  my $list = $parser->parse_char_string_with_context
      ($self->{ge}->{$t->{name}}->{value}, $context, $doc);

  my @node = @$list;
  while (@node) {
    my $node = shift @node;
    lc_lc_mapper_for_sps $map_parsed => $map_source,
        $node->get_user_data ('manakai_sps');

    if (not defined $node->get_user_data ('manakai_di')) {
      my $p = {line => $node->get_user_data ('manakai_source_line'),
               column => $node->get_user_data ('manakai_source_column')};
      if (defined $p->{column}) {
        lc_lc_mapper $map_parsed => $map_source, $p;
        $node->set_user_data (manakai_source_line => $p->{line});
        $node->set_user_data (manakai_source_column => $p->{column});
        $node->set_user_data (manakai_di => $p->{di});
      }
    }

    unshift @node, @{$node->attributes or []}, @{$node->child_nodes};
  }

  return $list;
} # _parse_entity_subtree_token

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
