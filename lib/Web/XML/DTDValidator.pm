package Web::XML::DTDValidator;
use strict;
use warnings;
our $VERSION = '8.0';
use Char::Class::XML qw!InXMLNameStartChar InXMLNameChar!;

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my $error = {@_};
    my $text = defined $error->{text} ? qq{ - $error->{text}} : '';
    my $value = defined $error->{value} ? qq{ "$error->{value}"} : '';
    my $level = {
      m => 'Error',
      s => 'SHOULD-level error',
      w => 'Warning',
      i => 'Information',
    }->{$error->{level} || ''} || $error->{level};
    warn "$level ($error->{type}$text) at node @{[$error->{node}->node_name]}\n";
  };
} # onerror

=pod

XXX

    VC_ATTR_DECLARED	=> {	## VC: Attribute Value Type
    	description	=> 'Attribute "%s" should (or must to be valid) be declared',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_DECLARED	=> {
    	description	=> 'Element type "%s" should (or must to be valid) be declared',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_MIXED	=> {
    	description	=> 'Element type "%s" cannot come here by definition',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_CDATA	=> {
    	description	=> 'In element content, character data (other than S) cannot be written',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_MATCH	=> {
    	description	=> 'Child element (type = "%s") cannot appear here, since it does not match to the content model',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_MATCH_EMPTY	=> {
    	description	=> 'Required child element does not found',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_MATCH_NEED_MORE_ELEMENT	=> {
    	description	=> 'Required child element does not found',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_MATCH_TOO_MANY_ELEMENT	=> {
    	description	=> 'Child element (type = "%s") does not match to the content model',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_REF	=> {
    	description	=> 'In element content, entity or character reference cannot be used',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_ELEMENT_SECTION	=> {
    	description	=> 'In element content, marked section cannot be used',
    	level	=> 'vc',
    },
    VC_ELEMENT_VALID_EMPTY	=> {
    	description	=> 'Content must be empty, i.e. no element, comment, PCDATA nor markup declaration can be contained',
    	level	=> 'vc',
    },
    VC_ENUMERATION	=> {
    	description	=> 'Attribute value "%s" must match one of name token defined in ATTLIST declaration',
    	level	=> 'vc',
    },
    VC_FIXED_ATTR_DEFAULT	=> {
    	description	=> 'Attribute value "%s" must match the default value ("%s")',
    	level	=> 'vc',
    },
    VC_ID_SYNTAX	=> {
    	description	=> 'Value of ID attribute ("%s") must be a valid Name',
    	level	=> 'vc',
    },
    VC_ID_UNIQUE	=> {
    	description	=> 'Value of ID attribute ("%s") must be unique in the document',
    	level	=> 'vc',
    },
    VC_IDREF_MATCH	=> {
    	description	=> 'Value of IDREF/IDREFS attribute ("%s") must be match one of ID specified in the document',
    	level	=> 'vc',
    },
    VC_NOTATION_ATTR_DECLARED	=> {
    	description	=> 'Notation "%s" should (or must to be valid) be declared',
    	level	=> 'vc',
    },
    VC_NOTATION_ATTR_ENUMED	=> {
    	description	=> 'Notation "%s" must be included in group of the declaration',
    	level	=> 'vc',
    },
    VC_NOTATION_SYNTAX	=> {
    	description	=> 'Value of NOTATION attribute ("%s") must be a valid Name',
    	level	=> 'vc',
    },
    VC_REQUIRED_ATTR	=> {
    	description	=> 'Required attribute %s/@%s must be specified',
    	level	=> 'vc',
    },
    WARN_XML_EMPTY_NET	=> {
    	description	=> 'For interoperability, NET (EmptyElemTag) syntax should be used for mandatorlly empty element',
    	level	=> 'warn',
    },
    WARN_XML_NON_EMPTY_NET	=> {
    	description	=> 'For interoperability, NET (EmptyElemTag) syntax should not be used other than for mandatorlly empty element',
    	level	=> 'warn',
    },

=cut

sub validate_document ($$) {
  my ($self, $doc) = @_;
  for my $node ($doc->child_nodes->to_list) {
    my $nt = $node->node_type;
    if ($nt == $node->DOCUMENT_TYPE_NODE) {
      $self->_validate_doctype ($node);
    } elsif ($nt == $node->ELEMENT_NODE) {
      $self->_validate_element ($node);
    }
  }
} # validate_document

my $XMLName = qr/\p{InXMLNameStartChar}\p{InXMLNameChar}*/;
my $XMLNCName = qr/\p{InXMLNCNameStartChar}\p{InXMLNCNameChar}*/;

sub _validate_doctype ($$) {
  my ($self, $dt) = @_;

  ## Element type definitions (created from <!ELEMENT> and/or <!ATTLIST>)
  for my $et ($dt->element_types->to_list) {
    my $et_name = $et->node_name;
    unless ($et_name =~ /\A$XMLName\z/o) {
      $self->onerror->(level => 'm',
                       type => 'xml:name syntax',
                       node => $et, value => $et_name);
    }
    if ($et_name =~ /:/ and not $et_name =~ /\A$XMLNCName:$XMLNCName\z/o) {
      $self->onerror->(level => 'm',
                       type => 'xml:qname syntax',
                       node => $et, value => $et_name);
    }

    my $cm = $et->content_model_text;
    my @at = $et->attribute_definitions->to_list;
    if (@at and not defined $cm) {
      $self->onerror->(level => 'w',
                       type => 'xml:dtd:attlist element declared',
                       node => $at[0], value => $et_name);
    }

    ## Attribute definitions (created from <!ATTLIST>)
    my $has_id;
    my $has_notation;
    my $et_has_token = {};
    for my $at (@at) {
      my $at_name = $at->node_name;
      unless ($at_name =~ /\A$XMLName\z/o) {
        $self->onerror->(level => 'm',
                         type => 'xml:name syntax',
                         node => $at, value => $at_name);
      }
      if ($at_name =~ /:/ and not $at_name =~ /\A$XMLNCName:$XMLNCName\z/o) {
        $self->onerror->(level => 'm',
                         type => 'xml:qname syntax',
                         node => $at, value => $at_name);
      }

      my $declared_type = $at->declared_type;
      my $tokens = $at->allowed_tokens;
      my $has_token = {};
      for (@$tokens) {
        if ($has_token->{$_}) {
          $self->onerror->(level => 'm',
                           type => 'VC:No Duplicate Tokens',
                           node => $at, value => $_);
        } else {
          if ($declared_type == $at->ENUMERATION_ATTR) {
            unless ($_ =~ /\A\p{InXMLNameChar}+\z/) {
              $self->onerror->(level => 'm',
                               type => 'xml:nmtoken syntax',
                               node => $at, value => $_);
            }
            if ($et_has_token->{$_}) {
              $self->onerror->(level => 's',
                               type => 'xml:dtd:duplicate nmtoken in element',
                               node => $at, value => $_);
            }
            $et_has_token->{$_} = 1;
          } elsif ($declared_type == $at->NOTATION_ATTR) {
            if (not defined $dt->notations->{$_}) {
              if (not $_ =~ /\A$XMLName\z/o) {
                $self->onerror->(level => 'm',
                                 type => 'xml:name syntax',
                                 node => $at, value => $_);
              } elsif ($_ =~ /:/) {
                $self->onerror->(level => 'm',
                                 type => 'xml:ncname syntax',
                                 node => $at, value => $_);
              } else {
                $self->onerror->(level => 'w',
                                 type => 'xml:dtd:notation not declared',
                                 node => $at, value => $_);
              }
            }
          }
          $has_token->{$_} = 1;
        }
      }

      my $default_type = $at->default_type;
      my $dv = $at->node_value;
      if ($declared_type == $at->ID_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          $self->onerror->(level => 'm',
                           type => 'VC:ID Attribute Default',
                           node => $at);
        }
        $self->onerror->(level => 'm',
                         type => 'VC:One ID per Element Type',
                         node => $at) if $has_id;
        $has_id = 1;
      } elsif ($declared_type == $at->IDREF_ATTR or
               $declared_type == $at->ENTITY_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          ## VC:Attribute Default Value Syntactically Correct
          unless ($dv =~ /\A$XMLName\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:name syntax',
                             node => $at, value => $dv);
          }
          if ($dv =~ /:/) {
            $self->onerror->(level => 'm',
                             type => 'xml:ncname syntax',
                             node => $at, value => $dv);
          }
        }
      } elsif ($declared_type == $at->IDREFS_ATTR or
               $declared_type == $at->ENTITIES_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          ## VC:Attribute Default Value Syntactically Correct
          unless ($dv =~ /\A$XMLName\x20$XMLName)*\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:names syntax',
                             node => $at, value => $dv);
          }
          if ($dv =~ /:/) {
            $self->onerror->(level => 'm',
                             type => 'xml:ncname syntax',
                             node => $at, value => $dv);
          }
        }
      } elsif ($declared_type == $at->NMTOKEN_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          ## VC:Attribute Default Value Syntactically Correct
          unless ($dv =~ /\A\p{InXMLNameChar}+\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:nmtoken syntax',
                             node => $at, value => $dv);
          }
        }
      } elsif ($declared_type == $at->NMTOKENS_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          ## VC:Attribute Default Value Syntactically Correct
          unless ($dv =~ /\A\p{InXMLNameChar}+(?>\x20\p{InXMLNameChar}+)*\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:nmtokens syntax',
                             node => $at, value => $dv);
          }
        }
      } elsif ($declared_type == $at->ENUMERATION_ATTR or
               $declared_type == $at->NOTATION_ATTR) {
        if ($default_type == $at->EXPLICIT_DEFAULT or
            $default_type == $at->FIXED_DEFAULT) {
          ## VC:Attribute Default Value Syntactically Correct
          $self->onerror->(level => 'm',
                           type => 'VC:Attribute Default Value Syntactically Correct:enumeration',
                           node => $at, value => $dv)
              unless $has_token->{$dv};
        }
        if ($declared_type == $at->NOTATION_ATTR) {
          $self->onerror->(level => 'm',
                           type => 'VC:One Notation per Element Type',
                           node => $at) if $has_notation;
          $has_notation = 1;
          $self->onerror->(level => 'm',
                           type => 'VC:No Notation on Empty Element',
                           node => $at) if $cm eq 'EMPTY';
        }
      } # $declared_type
    } # $at
  } # $et

  for my $ent ($dt->entities->to_list) {
    my $ndata = $ent->notation_name;
    if (defined $ndata) {
      unless (defined $dt->notations->{$ndata}) {
        $self->onerror->(level => 'm',
                         type => 'VC:Notation Declared',
                         node => $ent, value => $ndata);
      }
    }
  } # $ent
} # _validate_doctype

=pod

sub _validate_document_instance ($$;%) {
  my ($self, $node, %opt) = @_;
  my $valid = 1;
  $opt{_element} = {};
  $opt{entMan}->get_entities ($opt{_elements}, namespace_uri => $NS{SGML}.'element');
  $opt{_idref_attr} = [];
  $opt{_idref_value} = {};
  for (@{$node->{node}}) {
    if ($_->{type} eq '#element') {
      $valid &= $self->_validate_element ($_, \%opt);
    }
  }
  
  ## IDREF/IDREFS attribute values
  for (@{$opt{_idref_attr}}) {
    unless ($opt{_id_value}->{$_->[0]}) {
      $self->{error}->raise_error ($_->[1], type => 'VC_IDREF_MATCH', t => $_->[0]);
      $valid = 0;
    }
  }
  $valid;
}
sub _validate_element ($$$) {
  my ($self, $node, $opt) = @_;
  my $valid = 1;
  ### DEBUG: 
  #Carp::croak join qq!\t!, caller(0) unless eval q{$node->qname};
  my $qname = $node->qname;
  unless ($opt->{_element}->{$qname}) {
    $opt->{_element}->{$qname} = $opt->{entMan}->get_entity ($qname,
                                                 namespace_uri => $NS{SGML}.'element');
    unless ($opt->{_element}->{$qname}) {
      $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_DECLARED', t => $qname);
      $opt->{_element}->{$qname} = 'undeclared';
      $valid = 0;
    }
  }
  unless ($opt->{_attrs}->{$qname}) {
    $opt->{_attrs}->{$qname} = $opt->{entMan}->get_attr_definitions (qname => $qname);
  }
  #$opt->{_id_value};
  #$opt->{_idref_attr} = [[$id, $node],...]
  my %specified;
  my $has_child = 0;
  for (@{$node->{node}},
       ## NS attributes
       grep {ref $_} values %{$node->{ns_specified}}) {
    if ($_->{type} eq '#attribute') {
      my $attr_qname = $_->qname;
      $specified{$attr_qname} = 1;	## defined explicilly or by default declaration
      my $attrdef = $opt->{_attrs}->{$qname}->{attr}->{$attr_qname};
      if (ref $attrdef) {
        my $attr_type = $attrdef->get_attribute ('type', make_new_node => 1)->inner_text;
        my $attr_value = $_->inner_text;
        my $attr_deftype = $attrdef->get_attribute ('default_type', make_new_node => 1)->inner_text;
        if ($attr_type eq 'CDATA') {
          ## Check FIXED value
          if ($attr_deftype eq 'FIXED') {
            my $dv = $attrdef->get_attribute ('default_value')->inner_text;
            unless ($attr_value eq $dv) {
              $self->{error}->raise_error ($_, type => 'VC_FIXED_ATTR_DEFAULT',
                                           t => [$attr_value, $dv]);
              $valid = 0;
            }
          }
        } elsif ({qw/ID 1 IDREF 1 IDREFS 1 NMTOKEN 1 NMTOKENS 1 NOTATION 1/}->{$attr_type}) {
          ## Normalization
          $attr_value =~ s/\x20\x20+/\x20/g;
          $attr_value =~ s/^\x20+//;  $attr_value =~ s/\x20+$//;
          ## Check FIXED value
          if ($attr_deftype eq 'FIXED') {
            my $dv = $attrdef->get_attribute ('default_value')->inner_text;
            $dv =~ s/\x20\x20+/\x20/g;
            $dv =~ s/^\x20+//;  $dv =~ s/\x20+$//;
            unless ($attr_value eq $dv) {
              $self->{error}->raise_error ($_, type => 'VC_FIXED_ATTR_DEFAULT',
                                           t => [$attr_value, $dv]);
              $valid = 0;
            }
          }
          ## Check value syntax and semantics
          if ({qw/ID 1 IDREF 1 NOTATION 1/}->{$attr_type}) {
            if ($attr_value !~ /^$xml_re{Name}$/) {
              $self->{error}->raise_error ($_, type => 'VC_'.$attr_type.'_SYNTAX',
                                           t => $attr_value);
              $valid = 0;
            } elsif (index ($attr_value, ':') > -1) {
              $self->{error}->raise_error ($_, type => 'VALID_NS_NAME_IS_NCNAME',
                                           t => $attr_value);
              $valid = 0;
            }
            if ($attr_type eq 'ID') {
              if ($opt->{_id_value}->{$attr_value}) {
                $self->{error}->raise_error ($_, type => 'VC_ID_UNIQUE',
                                             t => $attr_value);
                $valid = 0;
              } else {
                $opt->{_id_value}->{$attr_value} = 1;
              }
            } elsif ($attr_type eq 'IDREF') {
              unless ($opt->{_id_value}->{$attr_value}) {
                ## Referred ID is not defined yet, so check later
                push @{$opt->{_idref_attr}}, [$attr_value, $_];
              }
            } elsif ($attr_type eq 'NOTATION') {
              unless ($opt->{_attrs}->{$qname}->{enum}->{$attr_qname}->{$attr_value}) {
                $self->{error}->raise_error ($_, type => 'VC_NOTATION_ATTR_ENUMED',
                                             t => $attr_value);
                $valid = 0;
              }
              unless ($opt->{entMan}->get_entity ($attr_value,
                                                  namespace_uri => $NS{SGML}.'notation')) {
                $self->{error}->raise_error ($_, type => 'VC_NOTATION_ATTR_DECLARED',
                                             t => $attr_value);
                $valid = 0;
              }
            }
          } elsif ($attr_type eq 'NMTOKEN') {
            if ($attr_value =~ /\P{InXMLNameChar}/) {
              $self->{error}->raise_error ($_, type => 'VC_NAME_TOKEN_NNTOKEN',
                                           t => $attr_value);
              $valid = 0;
            }
          } elsif ($attr_type eq 'NMTOKENS') {
            if ($attr_value =~ /[^\p{InXMLNameChar}\x20]/) {
              $self->{error}->raise_error ($_, type => 'VC_NAME_TOKEN_NMTOKENS',
                                           t => $attr_value);
              $valid = 0;
            }
          } else {	## IDREFS
            for my $anid (split /\x20/, $attr_value) {
              if ($anid !~ /^$xml_re{Name}$/) {
                $self->{error}->raise_error ($_, type => 'VC_IDREF_IDREFS_NAME',
                                             t => $anid);
                $valid = 0;
              } else {
                if (index ($anid, ':') > -1) {
                  $self->{error}->raise_error ($_, type => 'VALID_NS_NAME_IS_NCNAME',
                                               t => $anid);
                  $valid = 0;
                }
              }
              unless ($opt->{_id_value}->{$attr_value}) {
                ## Referred ID is not defined yet, so check later
                push @{$opt->{_idref_attr}}, [$attr_value, $_];
              }
            }	# IDREFS values
          }
        } elsif ($attr_type eq 'enum') {
          ## Normalization
          $attr_value =~ s/\x20\x20+/\x20/g;
          $attr_value =~ s/^\x20+//;  $attr_value =~ s/\x20+$//;
          unless ($opt->{_attrs}->{$qname}->{enum}->{$attr_qname}->{$attr_value}) {
            $self->{error}->raise_error ($_, type => 'VC_ENUMERATION', t => $attr_value);
            $valid = 0;
          }
        }	# enum
      } else {
        $self->{error}->raise_error ($_, type => 'VC_ATTR_DECLARED', t => $attr_qname);
        $valid = 0;
      }
    } else {
      $has_child = 1;
    }
  }
  
  for my $attr_qname (keys %{$opt->{_attrs}->{$qname}->{attr}}) {
    my $attrdef = $opt->{_attrs}->{$qname}->{attr}->{$attr_qname};
    if ($attrdef->get_attribute_value ('default_type') eq 'REQUIRED') {
      unless ($specified{$attr_qname}
       || ($attr_qname eq 'xmlns' and $node->{ns_specified}->{''})
       || (substr ($attr_qname, 0, 6) eq 'xmlns:'
           and defined $node->{ns_specified}->{substr $attr_qname, 6})) {
        $self->{error}->raise_error ($node, type => 'VC_REQUIRED_ATTR',
                                     t => [$qname, $attr_qname]);
        $valid = 0;
      }
    }
  }
  
  ## Content check
  my $cmodel = ref $opt->{_element}->{$qname}
               ? $opt->{_element}->{$qname}->get_attribute_value ('content',
                                                                  default => '')
               : 'ANY';
  if ($cmodel eq 'EMPTY') {
    if ($has_child) {
      $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_EMPTY');
      $valid = 0;
    } elsif (!$node->{option}->{use_EmptyElemTag}) {
      $self->{error}->raise_error ($node, type => 'WARN_XML_EMPTY_NET');
    }
  } else {	# not EMPTY
    if (!$has_child && $node->{option}->{use_EmptyElemTag}) {
      $self->{error}->raise_error ($node, type => 'WARN_XML_NON_EMPTY_NET');
    }
    if ($cmodel eq 'ANY') {
      for (@{$node->{node}}) {
        if ($_->{type} eq '#element') {
          $valid &= $self->_validate_element ($_, $opt);
        }
      }
    } elsif ($cmodel eq 'mixed') {
      my %accepted_element_type;
      for (@{$opt->{_element}->{$qname}->{node}}) {
        if ($_->{type} eq '#element' && $_->{namespace_uri} eq $NS{SGML}.'element'
         && $_->{local_name} eq 'group') {
          for my $el (@{$_->{node}}) {
            if ($el->{type} eq '#element' && $el->{namespace_uri} eq $NS{SGML}.'element'
             && $el->{local_name} eq 'element') {
              $accepted_element_type{$el->get_attribute ('qname', make_new_node => 1)->inner_text}
                = 1;
            }
          }
          last;
        }	# content model group
      }
      
      for my $child (@{$node->{node}}) {
        if ($child->{type} eq '#element') {
          my $child_qname = $child->qname;
          unless ($accepted_element_type{$child_qname}) {
            $self->{error}->raise_error ($child, type => 'VC_ELEMENT_VALID_MIXED',
                                         t => $child_qname);
            $valid = 0;
          }
          $valid &= $self->_validate_element ($child, $opt);
        }
      }
    } else {	# element content
      my $make_cmodel_arraytree;
      $make_cmodel_arraytree = sub {
        my $node = shift;
        my @r;
        for (@{$node->{node}}) {
          if ($_->{type} eq '#element' && $_->{namespace_uri} eq $NS{SGML}.'element') {
            if ($_->{local_name} eq 'group') {
              push @r, &$make_cmodel_arraytree ($_);
            } elsif ($_->{local_name} eq 'element') {
              push @r, {qname => ($_->get_attribute_value ('qname')),
                        occurence => ($_->get_attribute_value
                                            ('occurence', default => '1')),
                        type => 'element'};
            }
          }
        }
        my $tree =
        {connector => ($node->get_attribute ('connector', make_new_node => 1)->inner_text || '|'),
         occurence => ($node->get_attribute ('occurence', make_new_node => 1)->inner_text || '1'),
         element => \@r, type => 'group'};
        if ($tree->{connector} eq '|') {
          if ($tree->{occurence} eq '1' || $tree->{occurence} eq '+') {
            for (@{$tree->{element}}) {
              if ($_->{occurence} eq '?' || $_->{occurence} eq '*') {
                $tree->{occurence} = {'1'=>'?','+'=>'*'}->{$tree->{occurence}};
                last;
              }
            }
          }
        }
        $tree;
      };	# $make_cmodel_arraytree
      my $tree = &$make_cmodel_arraytree ($opt->{_element}->{$qname});
      
      my $find_myname;
      $find_myname = sub {
        my ($nodes=>$idx, $tree, $opt) = @_;
        if ($tree->{type} eq 'group') {
          my $return = {match => 1, some_match => 0, actually_no_match => 1};
          my $original_idx = $$idx;
          for (my $i = 0; $i <= $#{$tree->{element}}; $i++) {
            my $result = (&$find_myname ($nodes=>$idx, $tree->{element}->[$i],
                                         {depth => 1+$opt->{depth},
                                          nodes_max => $opt->{nodes_max}}));
            print STDERR qq(** Lower level match [$opt->{depth}] ("$nodes->[$$idx]->[1]") : Exact = $result->{match}, Some = $result->{some_match}\n) if $main::DEBUG;
            if ($result->{match} == 1 && !$result->{actually_no_match}) {
              $return->{actually_no_match} = 0;
              if ($tree->{connector} eq '|') {
                $return->{match} = 1;
                $return->{some_match} = 1;
                if (($tree->{element}->[$i]->{occurence} eq '*'
                  || $tree->{element}->[$i]->{occurence} eq '+')
                  && $$idx <= $opt->{nodes_max}) {
                  print STDERR qq(** More matching chance ($tree->{element}->[$i]->{occurence}) [$opt->{depth}] : "$tree->{element}->[$i]->{qname}" (model) vs "$nodes->[$$idx]->[1]" (instance)\n) if $main::DEBUG;
                  $return->{more} = 1;
                  $i--;
                  #$$idx++;
                  next;
                } else {
                  return $return;
                }
              } else {	# ','
                $return->{match} &= 1;
                $return->{some_match} = 1;
                if ($$idx > $opt->{nodes_max}) {	# already last of instance's nodes
                  if ($i == $#{$tree->{element}}) {
                    return $return;
                  } else {	## (foo1,foo2,foo3,foo4) and <foo1/><foo2/>.
                          	## If foo3 and foo4 is optional, valid, otherwise invalid
                    my $isopt = 1;
                    for ($i+1..$#{$tree->{element}}) {
                      if ($tree->{element}->[$_]->{occurence} ne '*'
                       && $tree->{element}->[$_]->{occurence} ne '?') {
                        $isopt = 0;
                        last;
                      }
                    }
                    $return->{match} = 0 unless $isopt;
                    return $return;
                  }
                } else {	# not yet last of instance's nodes
                  if ($tree->{element}->[$i]->{occurence} eq '*'
                   || $tree->{element}->[$i]->{occurence} eq '+') {
                    $return->{more} = 1;
                    $i--;
                    #$$idx++;
                    next;
                  } elsif ($i == $#{$tree->{element}}) {	# already last of model group
                    return $return;
                  } else {
                    #$$idx++;
                    next;
                  }
                }
              }
            } else {	# doesn't match
              # <$return->{match} == 1>
              if ($return->{more}	## (something*) but not matched
              || ($tree->{element}->[$i]->{occurence} eq '?'
               && $tree->{connector} eq ',')) {
                $return->{more} = 0;
                $return->{match} = 0 if $result->{some_match};
                if ($tree->{connector} eq '|') {
                  return $return;
                } else {	# ','
                  next;
                }
              } elsif ($result->{some_match} && $tree->{connector} eq '|') {
                $$idx = $original_idx;
              }
              if ($tree->{element}->[$i]->{occurence} eq '*') {
                $return->{match} = 1;
                #$return->{actually_no_match} &= 1;	# default
              } else {
                $return->{match} = 0;
                if ($tree->{connector} eq ',') {
                  return $return;
                }
              }
            }	# match or nomatch
          }	# content group elements
          ## - ',' and all matched
          ## - '|' and match to no elements
          return $return;
        } else {	# terminal element
          print STDERR qq(** Element match [$opt->{depth}] : "$tree->{qname}" (model) vs "$nodes->[$$idx]->[1]" (instance)\n) if $main::DEBUG;
          if ($tree->{qname} eq $nodes->[$$idx]->[1]) {
            $$idx++;
            return {match => 1, some_match => 1};
          #} elsif ($tree->{occurence} eq '*' || $tree->{occurence} eq '?') {
          #  return {match => 1, some_match => 1, actually_no_match => 1};
          } else {
            return {match => 0, some_match => 0};
          }
        }
      };
      my @nodes;
      for my $child (@{$node->{node}}) {
        if ($child->{type} eq '#element') {
          push @nodes, [$child, $child->qname];
        } elsif ($child->{type} eq '#section') {
          $self->{error}->raise_error ($child, type => 'VC_ELEMENT_VALID_ELEMENT_SECTION');
          $valid = 0;
        } elsif ($child->{type} eq '#reference') {
          $self->{error}->raise_error ($child, type => 'VC_ELEMENT_VALID_ELEMENT_REF');
          $valid = 0;
        } elsif ($child->{type} eq '#text') {
          if ($child->inner_text =~ /[^$xml_re{_s__chars}]/s) {
            $self->{error}->raise_error ($child, type => 'VC_ELEMENT_VALID_ELEMENT_CDATA',
                                         t => $child->inner_text);
            $valid = 0;
          }
        }
      }	# children
      
      my $nodes_max = $#nodes;
      if (@nodes == 0) {	## Empty
        my $check_empty_ok;
        $check_empty_ok = sub {
          my ($tree) = @_;
          if ($tree->{occurence} eq '*'
           || $tree->{occurence} eq '?') {
            return 1;
          } elsif ($tree->{type} eq 'group') {
            if ($tree->{connector} eq ',') {
              my $ok = 1;
              for (@{$tree->{element}}) {
                $ok &= &$check_empty_ok ($_);
                last unless $ok;
              }
              return $ok;
            } else {	# '|'
              my $ok = 0;
              for (@{$tree->{element}}) {
                $ok ||= &$check_empty_ok ($_);
                last if $ok;
              }
              return $ok;
            }
          } else {
            return 0;
          }
        };
        if (&$check_empty_ok ($tree)) {
          
        } else {
          $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_ELEMENT_MATCH_EMPTY');
          $valid = 0;
        }
      } else {	## Non-empty
        my $i = 0;
        my $result = &$find_myname (\@nodes, \$i, $tree, {depth => 0, nodes_max => $nodes_max});
        if ($result->{match}) {
          if ($i > $nodes_max) {
            ## All child elements match to the model
          } else {
            ## Some more child element does not match to the model
            $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_ELEMENT_MATCH_TOO_MANY_ELEMENT', t => $nodes[$i]->[1]);
            $valid = 0;
          }
        } else {
          if ($i <= $nodes_max) {
            ## Some more child element is required by the model
            $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_ELEMENT_MATCH_NEED_MORE_ELEMENT');
            $valid = 0;
          } else {
            $self->{error}->raise_error ($node, type => 'VC_ELEMENT_VALID_ELEMENT_MATCH', t => $nodes[$i]->[1]);
            $valid = 0;
          }
        }
      }
      for (0..$nodes_max) {
        $valid &= $self->_validate_element ($nodes[$_]->[0], $opt);
      }
      
    }	# element content
  }	# not EMPTY
  $valid;
}

=cut

1;

=head1 LICENSE

Copyright 2003-2015 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
