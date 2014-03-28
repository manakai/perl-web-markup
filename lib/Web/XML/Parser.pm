package Web::XML::Parser; # -*- Perl -*-
use strict;
use warnings;
use warnings FATAL => 'recursion';
no warnings 'utf8';
our $VERSION = '9.0';
use Encode;
use Web::HTML::Defs;
use Web::HTML::ParserData;
use Web::HTML::_SyntaxDefs;
use Web::HTML::InputStream;
use Web::HTML::Tokenizer;
use Web::HTML::SourceMap;
push our @ISA, qw(Web::HTML::Tokenizer);

## Insertion modes - Tree construction stage's phases in XML5 and
## DOMDTDEF specs are represented as insertion mdes in this
## implementation.
sub BEFORE_XML_DECL_IM     () { 0 } ## Before XML declaration phase [DOMDTDEF]
sub BEFORE_DOCTYPE_IM      () { 1 } ## Before document type phase [DOMDTDEF]
sub BEFORE_ROOT_ELEMENT_IM () { 2 } ## Start phase [XML5]
sub IN_ELEMENT_IM          () { 3 } ## Main phase [XML5]
sub AFTER_ROOT_ELEMENT_IM  () { 4 } ## End phase [XML5]
sub IN_SUBSET_IM           () { 5 } ## Document type phase [DOMDTDEF]
sub BEFORE_TEXT_DECL_IM    () { 6 } ## Before text declaration phase [DOMDTDEF]

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
  local $self->{onextentref};
  $self->_parse_run;

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

  local $self->{onextentref};
  $self->_parse_run;

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
  $self->{document} = delete $self->{initial_document} || $doc;
  
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
  $self->{init_subparser}->($self) if $self->{init_subparser};

  push @{$self->{chars}}, split //,
      decode $self->{input_encoding}, $self->{byte_buffer}, # XXX Encoding Standard
          Encode::FB_QUIET;
  $self->_parse_run;
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
    $self->_parse_run;
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
  $self->_parse_run;
} # parse_bytes_end

sub _parse_run ($) {
  my $self = $_[0];

  ## This is either the first invocation of the |_get_next_token|
  ## method or |$self->{t}| is an |ABORT_TOKEN|.
  $self->{t} = $self->_get_next_token;

  $self->_construct_tree;
  return unless defined $self->{t}; ## _stop_parsing is invoked

  ## HTML only; byte mode only
  if ($self->{embedded_encoding_name}) {
    ## Restarting the parser
    $self->_parse_bytes_start_parsing;
  }

  ## XML only
  if ($self->{t}->{type} == ABORT_TOKEN and defined $self->{t}->{entdef}) {
    my $entdef = $self->{t}->{entdef};
    # XXX URL resolution
    my $subparser = Web::XML::Parser::SubParser->new_from_parser ($self, $entdef);
    my $im_key = 'insertion_mode';
    $subparser->{init_subparser} = sub {
      my $subparser = $_[0];
      if ($entdef->{external_subset} or
          $entdef->{type} == PARAMETER_ENTITY_TOKEN) {
        $subparser->{$im_key} = IN_SUBSET_IM;
        if (not defined $self->{prev_state}) {
          ## External subset or in a DeclSep
          #
        } elsif ($self->{prev_state} == DOCTYPE_ENTITY_VALUE_DOUBLE_QUOTED_STATE or
                 $self->{prev_state} == DOCTYPE_ENTITY_VALUE_SINGLE_QUOTED_STATE or
                 $self->{prev_state} == ENTITY_ENTITY_VALUE_STATE) {
          ## In an entity value
          $subparser->{state} = ENTITY_ENTITY_VALUE_STATE;
          $subparser->{ct} = $self->{ct};
          if ($im_key eq 'next_im') { ## External entity
            $subparser->{next_state} = $subparser->{state};
            $subparser->{next_ct} = $subparser->{ct};
            $subparser->{state} = EXTERNAL_PARAM_ENTITY_STATE;
            $subparser->{insertion_mode} = BEFORE_TEXT_DECL_IM;
          }
        } elsif (not $self->{prev_state} == DOCTYPE_INTERNAL_SUBSET_STATE) {
          ## In a markup declaration or a marked section's status
          $subparser->{state} = $self->{state};
          $subparser->{ct} = $self->{ct};
          $subparser->{ca} = $self->{ca};
          $subparser->{open_sects} = $self->{open_sects};
          $subparser->{in_pe_in_markup_decl} = 1;
          ## Implied space before parameter entity reference (most
          ## cases are handled by |prev_state| of action definitions
          ## in tokenizer).
          if ($subparser->{state} == MD_NAME_STATE) {
            $subparser->{state} = AFTER_DOCTYPE_NAME_STATE;
            if ($subparser->{ct}->{type} == ATTLIST_TOKEN) {
              $subparser->{state} = DOCTYPE_ATTLIST_NAME_AFTER_STATE;
            } elsif ($subparser->{ct}->{type} == ELEMENT_TOKEN) {
              $subparser->{state} = AFTER_ELEMENT_NAME_STATE;
            }
            ## Otherwise, $subparser->{ct} is a DOCTYPE, ENTITY, or NOTATION token.
          }
          if ($im_key eq 'next_im') { ## External entity
            $subparser->{next_state} = $subparser->{state};
            $subparser->{next_ct} = $subparser->{ct};
            $subparser->{state} = EXTERNAL_PARAM_ENTITY_STATE;
            $subparser->{insertion_mode} = BEFORE_TEXT_DECL_IM;
          }
        }
      } else { ## General entity
        $subparser->{inner_html_tag_name} = $self->{open_elements}->[-1]->[1];
        push @{$subparser->{open_elements}}, $self->{open_elements}->[-1];
        $subparser->{$im_key} = IN_ELEMENT_IM;
      }
    }; # init_subparser

    if (($self->{entity_depth} || 0) > $self->max_entity_depth) {
      $subparser->onparsed (sub {
        $self->_parse_subparser_done ($_[0], $entdef);
      });
      $self->{parse_error}->(type => 'entity:too deep',
                             text => $self->max_entity_depth,
                             line => $self->{t}->{line},
                             column => $self->{t}->{column},
                             level => 'm');
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_end;
    } elsif ((${$self->{entity_expansion_count} || \0}) > $self->max_entity_expansions + 1) {
      $subparser->onparsed (sub {
        $self->_parse_subparser_done ($_[0], $entdef);
      });
      $self->{parse_error}->(type => 'entity:too many refs',
                             text => $self->max_entity_expansions,
                             line => $self->{t}->{line},
                             column => $self->{t}->{column},
                             level => 'm');
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_end;
    } elsif (defined $entdef->{value}) {
      ## Internal entity with "&" and/or "<" in entity value,
      ## referenced from element content.

      my $map_parsed = create_pos_lc_map $entdef->{value};
      my $map_source = $entdef->{sps} || [];

      my $onerror = $self->onerror;
      $subparser->onerror (sub {
        my %args = @_;
        lc_lc_mapper $map_parsed => $map_source, \%args;
        $onerror->(%args);
      });
      $subparser->onparsed (sub {
        $self->_parse_subparser_done ($_[0], $entdef);
      });
      $subparser->{confident} = 1;
      $subparser->{line_prev} = $subparser->{line} = 1;
      $subparser->{column_prev} = -1;
      $subparser->{column} = 0;
      $subparser->{chars} = [split //, $entdef->{value}];
      $subparser->{chars_pos} = 0;
      $subparser->{chars_pull_next} = sub { 0 };
      delete $subparser->{chars_was_cr};
      {
        my $onerror = $subparser->onerror;
        $subparser->{parse_error} = sub {
          $onerror->(line => $subparser->{line}, column => $subparser->{column}, @_);
        };
      }

      $subparser->{is_xml} = 1;
      $subparser->_initialize_tokenizer;
      $subparser->_initialize_tree_constructor; # strict_error_checking (0)
      $subparser->{init_subparser}->($subparser);
      $subparser->{sps_transformer} = sub {
        my $token = $_[0];
        $token->{sps} = combined_sps $token->{sps}, $map_parsed => $map_source
            if defined $token->{sps};
        lc_lc_mapper $map_parsed => $map_source, $token;
      };
      $subparser->_parse_run;
    } else {
      ## An external entity
      $im_key = 'next_im';
      my $onerror = $self->onerror;
      $subparser->onerror (sub {
        my %args = @_;
        $args{di} = $subparser->di if not defined $args{di};
        $onerror->(%args);
      });
      # XXX sps_transformer to set default |di|
      $subparser->onparsed (sub {
        $self->_parse_subparser_done ($_[0], $entdef);
      });
      $self->onextentref->($self, $self->{t}, $subparser);
    }
  }
} # _parse_run

sub _parse_subparser_done ($$$) {
  my ($self, $subparser, $entdef) = @_;
  if (defined $entdef->{name}) {
    if ($entdef->{type} == PARAMETER_ENTITY_TOKEN) {
      if (not defined $self->{prev_state}) {
        ## In a DeclSep
        #
      } elsif ($self->{prev_state} == DOCTYPE_ENTITY_VALUE_DOUBLE_QUOTED_STATE or
               $self->{prev_state} == DOCTYPE_ENTITY_VALUE_SINGLE_QUOTED_STATE or
               $self->{prev_state} == ENTITY_ENTITY_VALUE_STATE) {
        ## In an entity value
        #
      } elsif (not $self->{prev_state} == DOCTYPE_INTERNAL_SUBSET_STATE) {
        ## In a markup declaration
        $self->{state} = $subparser->{state};
        $self->{ct} = $subparser->{ct};
        $self->{ca} = $subparser->{ca};
        ## Emulate state change by implied space after the parameter
        ## entity reference.
        if ($self->{state} == MD_NAME_STATE) {
          $self->{state} = AFTER_DOCTYPE_NAME_STATE;
          if ($self->{ct}->{type} == ATTLIST_TOKEN) {
            $self->{state} = DOCTYPE_ATTLIST_NAME_AFTER_STATE;
          } elsif ($self->{ct}->{type} == ELEMENT_TOKEN) {
            $self->{state} = AFTER_ELEMENT_NAME_STATE;
          }
          ## Otherwise, $self->{ct} is a DOCTYPE, ENTITY, or NOTATION token.
        } elsif ($self->{state} == DOCTYPE_ATTLIST_ATTRIBUTE_NAME_STATE) {
          $self->{state} = DOCTYPE_ATTLIST_ATTRIBUTE_NAME_AFTER_STATE;
        } elsif ($self->{state} == DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_STATE) {
          $self->{state} = DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_AFTER_STATE;
        } elsif ($self->{state} == ALLOWED_TOKEN_STATE) {
          $self->{state} = AFTER_ALLOWED_TOKEN_STATE;
        } elsif ($self->{state} == AFTER_ALLOWED_TOKENS_STATE) {
          $self->{state} = BEFORE_ATTR_DEFAULT_STATE;
        } elsif ($self->{state} == DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_BEFORE_STATE) {
          $subparser->{onerror}->(level => 'm',
                                  type => 'no default type', # XXXdoc
                                  line => $subparser->{line},
                                  column => $subparser->{column});
          $self->{state} = BOGUS_MD_STATE;
        } elsif ($self->{state} == AFTER_NDATA_STATE) {
          $self->{state} = BEFORE_NOTATION_NAME_STATE;
        } elsif ($self->{state} == AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE) {
          $self->{state} = BEFORE_DOCTYPE_PUBLIC_IDENTIFIER_STATE;
        } elsif ($self->{state} == AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE) {
          $self->{state} = BEFORE_DOCTYPE_SYSTEM_IDENTIFIER_STATE;
        } elsif ($self->{state} == CONTENT_KEYWORD_STATE) {
          $self->{state} = AFTER_MD_DEF_STATE;
        } elsif ($self->{state} == CM_ELEMENT_NAME_STATE) {
          $self->{state} = AFTER_CM_ELEMENT_NAME_STATE;
        } elsif ($self->{state} == DOCTYPE_PUBLIC_IDENTIFIER_DOUBLE_QUOTED_STATE or
                 $self->{state} == DOCTYPE_PUBLIC_IDENTIFIER_SINGLE_QUOTED_STATE or
                 $self->{state} == DOCTYPE_SYSTEM_IDENTIFIER_DOUBLE_QUOTED_STATE or
                 $self->{state} == DOCTYPE_SYSTEM_IDENTIFIER_SINGLE_QUOTED_STATE or
                 $self->{state} == DOCTYPE_ENTITY_VALUE_DOUBLE_QUOTED_STATE or
                 $self->{state} == DOCTYPE_ENTITY_VALUE_SINGLE_QUOTED_STATE) {
          $self->{state} = BOGUS_MD_STATE;
          $self->{state} = BOGUS_COMMENT_STATE;  #XXX
          $self->{ct} = {type => COMMENT_TOKEN, data => ''}; ## Will be discarded
        }
      }
      delete $self->{pe}->{$entdef->{name} . ';'}->{open};
    } else {
      delete $self->{ge}->{$entdef->{name} . ';'}->{open};
    }
  } else {
    ## External subset
    #
  }
  $self->{stop_processing} = 1 if $subparser->{stop_processing};
  delete $self->{parser_pause};
  $self->_parse_run;
} # _parse_subparser_done

{
  package Web::XML::Parser::SubParser;
  push our @ISA, qw(Web::XML::Parser);

  sub new_from_parser ($$$) {
    my $self = $_[0]->new;
    my $main_parser = $_[1];
    my $xe = $_[2];
    $self->{initial_document} =
    $self->{document} = $main_parser->{document}->implementation->create_document;
    $self->{validation} = $main_parser->{validation} ||= {};
    if ($xe->{external_subset} or
        $xe->{type} == Web::HTML::Defs::PARAMETER_ENTITY_TOKEN) {
      $self->{pe} = $main_parser->{pe} ||= {};
      $self->{pe}->{$xe->{name} . ';'}->{open} = 1 if defined $xe->{name};
      $self->{ge} = $main_parser->{ge} ||= {};
      $self->{doctype} = $main_parser->{doctype};
      $self->{has_element_decl} = $main_parser->{has_element_decl} ||= {};
      $self->{attrdef} = $main_parser->{attrdef} ||= {};
      $self->{has_attlist} = $main_parser->{has_attlist} ||= {};
      $self->{stop_processing} = $main_parser->{stop_processing};
      my $main_in_subset = $main_parser->{in_subset};
      $self->{in_subset} = {external_subset => $main_in_subset->{external_subset},
                            internal_subset => $main_in_subset->{internal_subset},
                            param_entity => (not $xe->{external_subset}),
                            in_external_entity => ($main_in_subset->{in_external_entity} or
                                                   $xe->{external_subset} or
                                                   not defined $xe->{value})}; ## External entity
      $self->{tokenizer_initial_state} = Web::HTML::Defs::DOCTYPE_INTERNAL_SUBSET_STATE;
    } else { ## General entity
      $self->{ge} = $main_parser->{ge} ||= {};
      $self->{ge}->{$xe->{name} . ';'}->{open} = 1;
    }
    $self->{entity_depth} = ($main_parser->{entity_depth} || 0) + 1;
    $self->max_entity_depth ($main_parser->max_entity_depth);
    ${$self->{entity_expansion_count} = $main_parser->{entity_expansion_count} ||= \(my $v = 0)}++;
    $self->max_entity_expansions ($main_parser->max_entity_expansions);
    $self->onextentref ($main_parser->onextentref);
    $self->{_sc} = $main_parser->_sc;
    $self->{entity_names_in_entity_values}
        = $main_parser->{entity_names_in_entity_values} ||= {};
    $self->{el_ncnames} = $main_parser->{el_ncnames} ||= {};
    $self->{entity_names} = $main_parser->{entity_names} ||= {};
    return $self;
  } # new_from_parser

  sub _check_before_terminate ($) {
    #
  } # _check_before_terminate
}

sub _stop_parsing ($) {
  # XXX stop parsing
  $_[0]->_check_before_terminate;
  $_[0]->_on_terminate;
} # _stop_parsing

sub _check_before_terminate ($) {
  my $self = $_[0];
  for (keys %{$self->{entity_names_in_entity_values} || {}}) {
    my $vt = $self->{entity_names_in_entity_values}->{$_};
    my $oe = sub { $self->{onerror}->(%$vt, column => $vt->{column} + 1, @_) };
    $self->_sc->check_hidden_name (name => $_, onerror => $oe);

    my $def = $self->{ge}->{$_ . ';'};
    if (defined $def->{notation}) {
      $self->onerror->(type => 'xml:dtd:entity value:unparsed entref',
                       value => $_ . ';',
                       level => 'w',
                       %$vt);
    }
  }
  $self->_sc->check_ncnames (names => $self->{el_ncnames} || {},
                             onerror => sub { $self->{onerror}->(@_) });
  for my $en (keys %{$self->{entity_names} || {}}) {
    $self->_sc->check_hidden_name (name => $en, onerror => sub {
      $self->{onerror}->(%{$self->{entity_names}->{$en}}, @_);
    });
  }
} # _check_before_terminate

sub _on_terminate ($) {
  $_[0]->onparsed->($_[0]);
  $_[0]->_terminate_tree_constructor;
  $_[0]->_clear_refs;
} # _on_terminate

sub di ($;$) {
  if (@_ > 1) {
    $_[0]->{di} = $_[1];
  }
  return $_[0]->{di} || 0;
} # di

sub onextentref ($;$) {
  if (@_ > 1) {
    $_[0]->{onextentref} = $_[1];
  }
  return $_[0]->{onextentref} ||= sub {
    my ($self, $t, $subparser) = @_;
    $self->{parse_error}->(type => 'external entref',
                           value => defined $t->{entdef}->{name} ? $t->{entdef}->{name} . ';' : undef,
                           line => $t->{line},
                           column => $t->{column},
                           level => 'i');
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_feed ('<?xml encoding="utf-8"?>');
    $subparser->parse_bytes_end;
  };
} # onextentref

sub onparsed ($;$) {
  if (@_ > 1) {
    $_[0]->{onparsed} = $_[1];
  }
  return $_[0]->{onparsed} ||= sub { };
} # onparsed

sub max_entity_depth ($;$) {
  if (@_ > 1) {
    $_[0]->{max_entity_depth} = $_[1];
  }
  return $_[0]->{max_entity_depth} || 10;
} # max_entity_depth

sub max_entity_expansions ($;$) {
  if (@_ > 1) {
    return $_[0]->{max_entity_expansions} = $_[1];
  }
  return $_[0]->{max_entity_expansions} || 1000;
} # max_entity_expansions

sub strict_checker ($;$) {
  if (@_ > 1) {
    $_[0]->{strict_checker} = $_[1];
  }
  return $_[0]->{strict_checker} || 'Web::XML::Parser::MinimumChecker';
} # strict_checker

sub _sc ($) {
  return $_[0]->{_sc} ||= do {
    my $sc = $_[0]->strict_checker;
    eval qq{ require $sc } or die $@;
    $sc;
  };
} # _sc

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

  delete $self->{tainted};
  $self->{open_elements} = [];
  $self->{insertion_mode} = BEFORE_XML_DECL_IM;
  $self->{next_im} = defined $self->{initial_next_im}
      ? $self->{initial_next_im} : BEFORE_DOCTYPE_IM;
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

## Differences from the XML5 spec (not documented in DOMDTDEF spec)
## are marked as "XML5:".

# XXX error type documentation
# XXX external parameter entity fetch error
# XXX warn by external ref
# XXX "expose DTD content" flag
# XXX content model data structure
#    SHOULD for PEs in content model
# XXX parser validation hooks:
#    cm in ignored ELEMENT
#    fully-normalizedness for ENTITY (should)
# XXX DTD validator:
#  wfness:
#    PITarget
#    xmlVersion SHOULD
#    tag Name
#    attr Name
#    Names and NMTokens and PubidChar in DTDEF
#    Name in content model and #PCDATA
#  validness:
#    VC:Root Element Type
#    VC:Element Valid
#    VC:Attr Value Type
#    VC:No Duplicate Types
#    VC:ID
#    VC:One ID per Element Type
#    VC:ID Attribute Default
#    VC:IDREF
#    VC:Entity Name
#    VC:Name Token
#    VC:Notation Attribute
#    VC:One Notation Per Element Type
#    VC:No Notation on Empty Element
#    VC:No Duplicate Tokens
#    VC:Enumeration
#    VC:Required Attribute
#    VC:Attribute Default Value Syntactically Correct
#    VC:Fixed Attribute Default
#    VC:Notation Name
#    VC:Standalone Document Declaration if standalone=yes and element content in ext and has white space
#  other:
#    warn if PITarget is not declared
#    xml:space type MUST be (default|preserve)
#    empty element tag SHOULD only be used for EMPTY element
#    error if content model is not deterministic
#    pubid normalization (warn)
#    sysid validation
#    warn if element in ATTLIST is not declared
#    fully-normalizedness (SHOULD)
#    suggested name rule (warn)
#    NOTATION system ID validation
#    reserved PI name
#    reserved tag name
#    reserved attr name

sub _insert_point ($) {
  return $_[0]->manakai_element_type_match (Web::HTML::ParserData::HTML_NS, 'template') ? $_[0]->content : $_[0];
} # _insert_point

sub _tokenize_attr_value ($) {
  my $token = $_[0];
  return 0 unless $token->{value} =~ / /;
  my @value;
  my @pos;
  my $old_pos = 0;
  my $new_pos = 0;
  my @v = grep { length } split /( +)/, $token->{value}, -1;
  for (@v) {
    unless (/ /) {
      push @value, $_;
      push @pos, [$old_pos, $new_pos, 1 + length $_];
      $new_pos += 1 + length $_;
    }
    $old_pos += length $_;
  }
  pop @value, pop @pos if @value and $value[-1] eq '';
  shift @value, shift @pos if @value and $value[-1] eq '';
  $pos[-1]->[2]-- if @pos;

  my $old_value = $token->{value};
  $token->{value} = join ' ', @value;
  if (defined $token->{sps}) {
    my $old_map = create_pos_lc_map $old_value;
    my $old_sps = $token->{sps};
    $token->{sps} = [map {
      my $lc = pos_to_lc $old_map, $_->[0];
      [$_->[1], $_->[2], $lc->{line}, $lc->{column}, $lc->{di}, $old_map => $old_sps];
    } @pos];
  }
  return not $old_value eq $token->{value};
} # _tokenize_attr_value

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
        $self->{sps_transformer}->($self->{t}) if defined $self->{sps_transformer};
        $self->_append_text_by_token ($self->{t} => $parent);
        $parent->set_user_data (manakai_has_struct => 1)
            if $self->{t}->{has_reference} or $self->{t}->{cdata};
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        my $nsmap = {%{$self->{open_elements}->[-1]->[2]}};

        my $attrs = $self->{t}->{attributes};
        my $attrdefs = $self->{attrdef}->{$self->{t}->{tag_name}};
        for my $attr_name (keys %{$attrdefs}) {
          my $def = $attrdefs->{$attr_name};
          if ($attrs->{$attr_name}) {
            $attrs->{$attr_name}->{type} = $def->{type} || 0;
            if ($def->{tokenize}) {
              if (_tokenize_attr_value $attrs->{$attr_name} and
                  $def->{external} and
                  not $def->{external}->{vc_error_reported} and
                  $self->{document}->xml_standalone) {
                $onerror->(level => 'm',
                           type => 'VC:Standalone Document Declaration:attr',
                           token => $def);
                $def->{external}->{vc_error_reported} = 1;
              }
            }
          } elsif (defined $def->{default}) {
            $attrs->{$attr_name} = {
              value => $def->{default},
              type => $def->{type} || 0,
              not_specified => 1,
              line => $def->{line},
              column => $def->{column},
              di => $def->{di},
              index => 1 + keys %{$attrs},
              sps => $def->{sps},
            };

            if ($def->{external} and
                not $def->{external}->{vc_error_reported} and
                $self->{document}->xml_standalone) {
              $onerror->(level => 'm',
                         type => 'VC:Standalone Document Declaration:attr',
                         token => $def);
              $def->{external}->{vc_error_reported} = 1;
            }
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
        $self->{sps_transformer}->($self->{t}) if defined $self->{sps_transformer};
        $el->set_user_data (manakai_source_line => $self->{t}->{line});
        $el->set_user_data (manakai_source_column => $self->{t}->{column});
        $el->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
        $self->{el_ncnames}->{$prefix} ||= $self->{t} if defined $prefix;
        $self->{el_ncnames}->{$ln} ||= $self->{t} if defined $ln;

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
          $self->{el_ncnames}->{$p} ||= $attr_t if defined $p;
          $self->{el_ncnames}->{$l} ||= $attr_t if defined $l;
          $attr->value ($attr_t->{value});
          if (defined $attr_t->{type}) {
            $attr->manakai_attribute_type ($attr_t->{type});
          } elsif ($self->{document}->all_declarations_processed) {
            $attr->manakai_attribute_type (0); # no value
          } else {
            $attr->manakai_attribute_type (11); # unknown
          }
          $self->{sps_transformer}->($attr_t) if defined $self->{sps_transformer};
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_di => $attr_t->{di}) if defined $attr_t->{di};
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
        $self->{sps_transformer}->($self->{t}) if defined $self->{sps_transformer};
        $pi->set_user_data (manakai_sps => $self->{t}->{sps})
            if defined $self->{t}->{sps};
        $self->_sc->check_pi_target
            (name => $self->{t}->{target},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
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
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        ## DOCTYPE in element
        $onerror->(level => 'm',
                   type => 'in html:#doctype',
                   token => $self->{t});

        if ($self->{t}->{has_internal_subset}) {
          ## Not in XML5
          ## Ignore the token.
          $self->{stop_processing} = 1; # disable internal subset processing
          $self->{doctype} = $self->{document}->create_document_type_definition ('dummy');
          $self->{insertion_mode} = IN_SUBSET_IM;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          ## Ignore the token.
          ## Stay in the mode.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
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
        ## <!ELEMENT> in DTD
        unless ($self->{has_element_decl}->{$self->{t}->{name}}) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:ext decl',
                     token => $self->{t})
              unless $self->{in_subset}->{internal_subset} and
                  not $self->{in_subset}->{param_entity};
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

          my $node = $self->{doctype}->get_element_type_definition_node
              ($self->{t}->{name});
          unless ($node) {
            $node = $self->{document}->create_element_type_definition
                ($self->{t}->{name});
            $self->{doctype}->set_element_type_definition_node ($node);
          }
          
          $node->set_user_data (manakai_source_line => $self->{t}->{line});
          $node->set_user_data (manakai_source_column => $self->{t}->{column});
          $node->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};

          $node->content_model_text (join '', @{$self->{t}->{content}})
              if $self->{t}->{content};
          $self->{has_element_decl}->{$self->{t}->{name}} = 1;
        } else {
          $onerror->(level => 'm', type => 'duplicate element decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});
        }
        ## TODO: $self->{t}->{content} syntax check.

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == ATTLIST_TOKEN) {
        ## <!ATTLIST> in DTD
        my $is_external = not ($self->{in_subset}->{internal_subset} and
                               not $self->{in_subset}->{param_entity});
        my $ed;
        $self->_sc->check_hidden_name
            (name => $self->{t}->{name},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        if ($self->{stop_processing}) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:attlist ignored',
                     token => $self->{t});
        } else {
          $onerror->(level => 'w',
                     type => 'xml:dtd:ext decl',
                     token => $self->{t})
              if $is_external;
          
          $ed = $self->{doctype}->get_element_type_definition_node
              ($self->{t}->{name});
          unless ($ed) {
            $ed = $self->{document}->create_element_type_definition
                ($self->{t}->{name});
            $ed->set_user_data (manakai_source_line => $self->{t}->{line});
            $ed->set_user_data (manakai_source_column => $self->{t}->{column});
            $ed->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
            $self->{doctype}->set_element_type_definition_node ($ed);
            $self->{has_attlist}->{$self->{t}->{name}} = 1;
          } elsif ($self->{has_attlist}->{$self->{t}->{name}}) {
            $onerror->(level => 'w', type => 'duplicate attlist decl', ## TODO: type
                       value => $self->{t}->{name},
                       token => $self->{t});
          }
          
          unless (@{$self->{t}->{attrdefs}}) {
            $onerror->(level => 'w', type => 'empty attlist decl', ## TODO: type
                            value => $self->{t}->{name},
                            token => $self->{t});
          }
        }
        
        for my $at (@{$self->{t}->{attrdefs}}) {
          my $node = $self->{document}->create_attribute_definition
              ($at->{name});
          $node->set_user_data (manakai_source_line => $at->{line});
          $node->set_user_data (manakai_source_column => $at->{column});
          $node->set_user_data (manakai_di => $at->{di}) if defined $at->{di};
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
          
          push @{$node->allowed_tokens}, @{$at->{tokens} or []};
          
          my $default = defined $at->{default} ? {
            FIXED => 1, REQUIRED => 2, IMPLIED => 3,
          }->{$at->{default}} : 4;
          if (defined $default) {
            $node->default_type ($default);
            if (defined $at->{value}) {
              if ($default == 1 or $default == 4) {
                #
              } elsif (length $at->{value}) {
                $onerror->(level => 'm',
                           type => 'default value not allowed', ## TODO: type
                           token => $at);
              }
            } else {
              if ($default == 1 or $default == 4) {
                $onerror->(level => 'm',
                           type => 'default value not provided', ## TODO: type
                           token => $at);
              }
            }
          } else {
            $onerror->(level => 'm',
                       type => 'unknown default type', ## TODO: type
                       value => $at->{default},
                       token => $at);
          }

          $type ||= 0;
          my $tokenize = (2 <= $type and $type <= 10);

          if (defined $at->{value}) {
            _tokenize_attr_value $at if $tokenize;
            $node->text_content ($at->{value});
          }

          if (defined $ed) {
            unless ($ed->get_attribute_definition_node ($at->{name})) {
              $ed->set_attribute_definition_node ($node);

              ## For tree construction
              my $def = $self->{attrdef}->{$self->{t}->{name}}->{$at->{name}} = {
                type => $type,
                tokenize => $tokenize,
                default => (($default and ($default == 1 or $default == 4))
                              ? defined $at->{value} ? $at->{value} : ''
                              : undef),
                line => $at->{line},
                column => $at->{column},
                di => $self->di,
                sps => $at->{sps},
              };
              sps_set_di $def->{sps}, $self->di;
              $def->{external} = {} if $is_external;
            } else {
              $onerror->(level => 'w', type => 'duplicate attrdef', ## TODO: type
                              value => $at->{name},
                              token => $at);
              my $onerror = sub { $onerror->(token => $at, @_) };
              if ($type == 10) { # ENUMERATION
                for (@{$at->{tokens} or []}) {
                  $self->_sc->check_hidden_nmtoken
                      (name => $_, onerror => $onerror);
                }
              } elsif ($type == 9) { # NOTATION
                for (@{$at->{tokens} or []}) {
                  $self->_sc->check_hidden_name
                      (name => $_, onerror => $onerror);
                }
              }
            }
          } # $ed
        } # $at

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == GENERAL_ENTITY_TOKEN) {
        ## <!ENTITY> (general entity) in DTD
        if ($self->{stop_processing}) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:entity ignored',
                     token => $self->{t});
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        } elsif ({
          amp => 1, apos => 1, quot => 1, lt => 1, gt => 1,
        }->{$self->{t}->{name}}) {
          if (not defined $self->{t}->{value} or # external entity
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
          my $is_external = not ($self->{in_subset}->{internal_subset} and
                                 not $self->{in_subset}->{param_entity});
          $onerror->(level => 'w',
                     type => 'xml:dtd:ext decl',
                     token => $self->{t})
              if $is_external;
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

          ## For parser.
          $self->{ge}->{$self->{t}->{name}.';'} = $self->{t};
          if (defined $self->{t}->{value} and
              $self->{t}->{value} !~ /[&<]/) {
            $self->{t}->{only_text} = 1;
          }
          $self->{sps_transformer}->($self->{t}) if defined $self->{sps_transformer};
          if (defined $self->{t}->{sps}) {
            sps_set_di $self->{t}->{sps}, $self->di;
          }
          $self->{t}->{di} = $self->di;
          $self->{t}->{external} = {} if $is_external;
          
          ## For DOM.
          if (defined $self->{t}->{notation}) {
            my $node = $self->{document}->create_general_entity ($self->{t}->{name});
            $node->set_user_data (manakai_source_line => $self->{t}->{line});
            $node->set_user_data (manakai_source_column => $self->{t}->{column});
            $node->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
            
            $node->public_id ($self->{t}->{pubid}); # may be undef
            $node->system_id ($self->{t}->{sysid}); # may be undef
            $node->notation_name ($self->{t}->{notation});
            
            $self->{doctype}->set_general_entity_node ($node);
          }
        } else {
          $onerror->(level => 'w', type => 'duplicate general entity decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});

        }
        if (defined $self->{t}->{pubid}) {
          $self->_sc->check_hidden_pubid
              (name => $self->{t}->{pubid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }
        if (defined $self->{t}->{sysid}) {
          $self->_sc->check_hidden_sysid
              (name => $self->{t}->{sysid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }
        if (defined $self->{t}->{notation}) {
          $self->_sc->check_hidden_name
              (name => $self->{t}->{notation},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PARAMETER_ENTITY_TOKEN) {
        ## <!ENTITY %> in DTD
        if ($self->{stop_processing}) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:entity ignored',
                     token => $self->{t});
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        } elsif (not $self->{pe}->{$self->{t}->{name} . ';'}) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:ext decl',
                     token => $self->{t})
              unless $self->{in_subset}->{internal_subset} and
                  not $self->{in_subset}->{param_entity};
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

          ## For parser.
          $self->{pe}->{$self->{t}->{name} . ';'} = $self->{t};
          if (defined $self->{t}->{sps}) {
            sps_set_di $self->{t}->{sps}, $self->di;
          }
        } else {
          $onerror->(level => 'w', type => 'duplicate para entity decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});
        }
        if (defined $self->{t}->{pubid}) {
          $self->_sc->check_hidden_pubid
              (name => $self->{t}->{pubid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }
        if (defined $self->{t}->{sysid}) {
          $self->_sc->check_hidden_sysid
              (name => $self->{t}->{sysid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == NOTATION_TOKEN) {
        ## <!NOTATION> in DTD
        unless ($self->{doctype}->get_notation_node ($self->{t}->{name})) {
          $onerror->(level => 'w',
                     type => 'xml:dtd:ext decl',
                     token => $self->{t})
              unless $self->{in_subset}->{internal_subset} and
                  not $self->{in_subset}->{param_entity};
          $self->_sc->check_hidden_name
              (name => $self->{t}->{name},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

          my $node = $self->{document}->create_notation ($self->{t}->{name});
          $node->set_user_data (manakai_source_line => $self->{t}->{line});
          $node->set_user_data (manakai_source_column => $self->{t}->{column});
          $node->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
          
          $node->public_id ($self->{t}->{pubid}); # may be undef
          $node->system_id ($self->{t}->{sysid}); # may be undef
          
          $self->{doctype}->set_notation_node ($node);
        } else {
          $onerror->(level => 'm', type => 'duplicate notation decl', ## TODO: type
                          value => $self->{t}->{name},
                          token => $self->{t});
        }
        if (defined $self->{t}->{pubid}) {
          $self->_sc->check_hidden_pubid
              (name => $self->{t}->{pubid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }
        if (defined $self->{t}->{sysid}) {
          $self->_sc->check_hidden_sysid
              (name => $self->{t}->{sysid},
               onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        }

        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == PI_TOKEN) {
        ## PI in DTD
        $onerror->(level => 'w',
                   type => 'xml:dtd:pi',
                   token => $self->{t});
        $self->_sc->check_hidden_pi_target
            (name => $self->{t}->{target},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

        my $pi = $self->{document}->create_processing_instruction
            ($self->{t}->{target}, $self->{t}->{data});
        $pi->set_user_data (manakai_sps => $self->{t}->{sps})
            if defined $self->{t}->{sps};
        $self->{doctype}->append_child ($pi);
        ## TODO: line/col
        
        ## Stay in the mode.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == END_OF_DOCTYPE_TOKEN) {
        if (@{$self->{open_elements}}) {
          $self->{insertion_mode} = IN_ELEMENT_IM;
        } elsif (defined $self->{document}->document_element) {
          $self->{insertion_mode} = AFTER_ROOT_ELEMENT_IM;
        } else {
          $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
        }
        my $dt = $self->{doctype};
        my $sysid = $dt->system_id;
        if (length $sysid) {
          # XXX resolve
          $self->{parser_pause} = 1;
          delete $self->{prev_state};
          $self->{t} = {type => ABORT_TOKEN,
                        entdef => {external_subset => 1, sysid => $sysid},
                        line => $dt->get_user_data ('manakai_source_line'),
                        column => $dt->get_user_data ('manakai_source_column'),
                        di => $dt->get_user_data ('manakai_di')};
          return;
        } else {
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        return $self->_stop_parsing;
      } else {
        require Data::Dumper;
        die "$0: XML parser subset im: Unknown token type - " . Data::Dumper::Dumper ($self->{t});
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
        $pi->set_user_data (manakai_sps => $self->{t}->{sps})
            if defined $self->{t}->{sps};
        $self->_sc->check_pi_target
            (name => $self->{t}->{target},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
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
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        ## <!DOCTYPE> after root element
        $onerror->(level => 'm', type => 'in html:#doctype',
                   token => $self->{t});
        if ($self->{t}->{has_internal_subset}) {
          ## Not in XML5
          ## Ignore the token.
          $self->{stop_processing} = 1; # disable DTD processing
          $self->{doctype} = $self->{document}->create_document_type_definition ('dummy');
          $self->{insertion_mode} = IN_SUBSET_IM;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          ## Ignore the token.
          ## Stay in the mode.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
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
          my $def = $attrdefs->{$attr_name};
          if ($attrs->{$attr_name}) {
            $attrs->{$attr_name}->{type} = $def->{type} || 0;
            if ($def->{tokenize}) {
              if (_tokenize_attr_value $attrs->{$attr_name} and
                  $def->{external} and
                  not $def->{external}->{vc_error_reported} and
                  $self->{document}->xml_standalone) {
                $onerror->(level => 'm',
                           type => 'VC:Standalone Document Declaration:attr',
                           token => $def);
                $def->{vc_error_reported} = 1;
              }
            }
          } elsif (defined $def->{default}) {
            $attrs->{$attr_name} = {
              value => $def->{default},
              type => $def->{type} || 0,
              not_specified => 1,
              line => $def->{line},
              column => $def->{column},
              di => $def->{di},
              index => 1 + keys %{$attrs},
              sps => $def->{sps},
            };

            if ($def->{external} and
                not $def->{external}->{vc_error_reported} and
                $self->{document}->xml_standalone) {
              $onerror->(level => 'm',
                         type => 'VC:Standalone Document Declaration:attr',
                         token => $def);
              $def->{vc_error_reported} = 1;
            }
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
        $el->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
        $self->{el_ncnames}->{$prefix} ||= $self->{t} if defined $prefix;
        $self->{el_ncnames}->{$ln} ||= $self->{t} if defined $ln;

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
          $self->{el_ncnames}->{$p} ||= $attr_t if defined $p;
          $self->{el_ncnames}->{$l} ||= $attr_t if defined $l;
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
          $attr->set_user_data (manakai_di => $attr_t->{di}) if defined $attr_t->{di};
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
        $pi->set_user_data (manakai_sps => $self->{t}->{sps})
            if defined $self->{t}->{sps};
        $self->_sc->check_pi_target
            (name => $self->{t}->{target},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
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
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        ## <!DOCTYPE> after <!DOCTYPE>
        $onerror->(level => 'm', type => 'second doctype', # XXXdoc
                   token => $self->{t});

        if ($self->{t}->{has_internal_subset}) {
          ## Not in XML5
          ## Ignore the token.
          $self->{stop_processing} = 1; # disable DTD processing
          $self->{doctype} = $self->{document}->create_document_type_definition ('dummy');
          $self->{insertion_mode} = IN_SUBSET_IM;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          ## Ignore the token.
          ## Stay in the mode.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } else {
        die "$0: XML parser initial: Unknown token type $self->{t}->{type}";
      }

    } elsif ($self->{insertion_mode} == BEFORE_DOCTYPE_IM) {
      ## XML5: DOCTYPE is not supported.
      if ($self->{t}->{type} == DOCTYPE_TOKEN) {
        my $dt = $self->{document}->create_document_type_definition
            (defined $self->{t}->{name} ? $self->{t}->{name} : '');
        
        ## NOTE: Default value for both |public_id| and |system_id|
        ## attributes are empty strings, so that we don't set any
        ## value in missing cases.
        my $pubid = $self->{t}->{pubid};
        $dt->public_id ($pubid) if defined $pubid;
        my $sysid = $self->{t}->{sysid};
        $dt->system_id ($sysid) if defined $sysid;

        $dt->set_user_data (manakai_source_line => $self->{t}->{line});
        $dt->set_user_data (manakai_source_column => $self->{t}->{column});
        $dt->set_user_data (manakai_di => $self->{t}->{di}) if defined $self->{t}->{di};
        
        $self->{document}->append_child ($dt);

        ## $pubid normalization is intentionally not done (Chrome
        ## behavior).
        if (defined $pubid and
            $Web::HTML::_SyntaxDefs->{charrefs_pubids}->{$pubid}) {
          $self->{validation}->{has_charref_decls} = 1;
          undef $sysid;
        } else {
          $self->{validation}->{need_predefined_decls} = 1;
        }

        ## XML5: No "has internal subset" flag.
        if ($self->{t}->{has_internal_subset}) {
          $self->{doctype} = $dt;
          $self->{insertion_mode} = IN_SUBSET_IM;
        } else {
          if (defined $sysid and length $sysid) {
            # XXX resolve
            $self->{doctype} = $dt;
            $self->{parser_pause} = 1;
            $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
            delete $self->{prev_state};
            $self->{t} = {type => ABORT_TOKEN,
                          entdef => {external_subset => 1, sysid => $sysid},
                          line => $self->{t}->{line},
                          column => $self->{t}->{column}};
            return;
          } else {
            $self->{insertion_mode} = BEFORE_ROOT_ELEMENT_IM;
          }
        }
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN or
               $self->{t}->{type} == END_OF_FILE_TOKEN) {
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
        $pi->set_user_data (manakai_sps => $self->{t}->{sps})
            if defined $self->{t}->{sps};
        $self->_sc->check_pi_target
            (name => $self->{t}->{target},
             onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
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

    } elsif ($self->{insertion_mode} == BEFORE_XML_DECL_IM or
             $self->{insertion_mode} == BEFORE_TEXT_DECL_IM) {
      ## Not in XML5:
      ## The before XML declaration phase [DOMDTDEF]
      ## The before text declaration phase [DOMDTDEF]
      if ($self->{t}->{type} == PI_TOKEN) {
        if ($self->{t}->{target} eq 'xml') {
          my $pos = 0;
          my $map_source = $self->{t}->{sps} || [];
          my $req_sp = 0;
          if ($self->{t}->{data} =~ s/\Aversion[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                      (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
            my $v = defined $1 ? $1 : $2;
            my $p = pos_to_lc $map_source, $pos + (defined $-[1] ? $-[1] : $-[2]);
            $pos += $+[0] - $-[0];
            $req_sp = not length $3;
            if (not $self->{insertion_mode} == BEFORE_TEXT_DECL_IM and
                $self->{next_im} == BEFORE_DOCTYPE_IM) {
              $self->{document}->xml_version ($v);
              # XXX drop XML 1.1 support?
              $self->{is_xml} = 1.1 if $v eq '1.1';
              $self->_sc->check_version (name => $v, onerror => sub {
                $onerror->(token => $self->{t}, %$p, @_);
              });
            } else {
              $self->_sc->check_hidden_version (name => $v, onerror => sub {
                $onerror->(token => $self->{t}, %$p, @_);
              });
            }
          } elsif (not $self->{insertion_mode} == BEFORE_TEXT_DECL_IM and
                   $self->{next_im} == BEFORE_DOCTYPE_IM) {
            my $p = pos_to_lc $map_source, $pos;
            $onerror->(level => 'm',
                       type => 'attribute missing:version',
                       token => $self->{t},
                       %$p);
          }
          if ($self->{t}->{data} =~ s/\Aencoding[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                      (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
            my $v = defined $1 ? $1 : $2;
            my $p = pos_to_lc $map_source, $pos + (defined $-[1] ? $-[1] : $-[2]);
            if ($req_sp) {
              my $p = pos_to_lc $map_source, $pos;
              $onerror->(level => 'm',
                         type => 'no space before attr name',
                         token => $self->{t},
                         %$p);
            }
            $pos += $+[0] - $-[0];
            $req_sp = not length $3;
            $self->_sc->check_hidden_encoding
                (name => $v, onerror => sub {
                   $onerror->(token => $self->{t}, %$p, @_);
                 });
            if (not $self->{insertion_mode} == BEFORE_TEXT_DECL_IM and
                $self->{next_im} == BEFORE_DOCTYPE_IM) {
              $self->{document}->xml_encoding ($v);
            }
          } elsif ($self->{insertion_mode} == BEFORE_TEXT_DECL_IM or
                   $self->{next_im} != BEFORE_DOCTYPE_IM) {
            ## A text declaration
            my $p = pos_to_lc $map_source, $pos;
            $onerror->(level => 'm',
                       type => 'attribute missing:encoding',
                       token => $self->{t},
                       %$p);
          }
          if ($self->{t}->{data} =~ s/\Astandalone[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                      (?>"([^"]*)"|'([^']*)')[\x09\x0A\x20]*//x) {
            my $v = defined $1 ? $1 : $2;
            if ($req_sp) {
              my $p = pos_to_lc $map_source, $pos;
              $onerror->(level => 'm',
                         type => 'no space before attr name',
                         token => $self->{t},
                         %$p);
            }
            if ($v eq 'yes' or $v eq 'no') {
              if (not $self->{insertion_mode} == BEFORE_TEXT_DECL_IM and
                  $self->{next_im} == BEFORE_DOCTYPE_IM) {
                $self->{document}->xml_standalone ($v ne 'no');
              } else {
                my $p = pos_to_lc $map_source, $pos;
                $onerror->(level => 'm',
                           type => 'attribute not allowed:standalone',
                           token => $self->{t},
                           %$p);
              }
            } else {
              my $p = pos_to_lc $map_source, $pos + (defined $-[1] ? $-[1] : $-[2]);
              $onerror->(level => 'm',
                         type => 'XML standalone:syntax error',
                         token => $self->{t},
                         value => $v,
                         %$p);
            }
            $pos += $+[0] - $-[0];
          }
          if (length $self->{t}->{data}) {
            my $p = pos_to_lc $map_source, $pos;
            $onerror->(level => 'm',
                       type => 'bogus XML declaration',
                       token => $self->{t},
                       %$p);
          }
          $self->{insertion_mode} = $self->{next_im}
              unless $self->{insertion_mode} == BEFORE_TEXT_DECL_IM;
          $self->{before_text_decl_first}++;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          #
        }
      } else {
        #
      }

      ## Anything other than XML or text declaration.
      if ($self->{insertion_mode} == BEFORE_TEXT_DECL_IM) {
        if ($self->{t}->{type} == PI_TOKEN) {
          $onerror->(level => 's',
                     type => 'no XML decl',
                     line => 1, column => 1)
              unless $self->{before_text_decl_first}++;
          ## Ignore the token.
          $self->{parse_error}->(level => 'm',
                                 type => 'pi in pe in decl');
          $self->{state} = BOGUS_MD_STATE;
          $self->{t} = $self->_get_next_token;
          redo B;
        } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
          $onerror->(level => 's',
                     type => 'no XML decl',
                     line => 1, column => 1)
              unless $self->{before_text_decl_first}++;
          ## Ignore the token.
          $self->{state} = BOGUS_MD_STATE;
          $self->{t} = $self->_get_next_token;
          redo B;
        } else {
          $onerror->(level => 's',
                     type => 'no XML decl',
                     line => 1, column => 1)
              unless $self->{before_text_decl_first}++;
          $self->{insertion_mode} = IN_SUBSET_IM;
          ## Reconsume the token.
          redo B;
        }
      } else {
        $onerror->(level => 's',
                   type => 'no XML decl',
                   line => 1, column => 1);
        $self->{insertion_mode} = $self->{next_im};
        ## Reconsume the token
        redo B;
      }

    } else {
      die "$0: Unknown XML insertion mode: $self->{insertion_mode}";
    }
    die;
  } # B
} # _construct_tree

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
