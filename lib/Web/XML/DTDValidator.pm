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
  my $dt;
  my $root_el_name;
  my @pi;
  for my $node ($doc->child_nodes->to_list) {
    my $nt = $node->node_type;
    if ($nt == $node->DOCUMENT_TYPE_NODE) {
      $self->_validate_doctype ($node);
      $dt = $node if not defined $dt;
      for ($dt->child_nodes->to_list) {
        push @pi, $_ if $_->node_type == $node->PROCESSING_INSTRUCTION_NODE;
      }
    } elsif ($nt == $node->ELEMENT_NODE) {
      $self->_validate_element ($node);
      $root_el_name = $node->node_name unless defined $root_el_name;
    } elsif ($nt == $node->PROCESSING_INSTRUCTION_NODE) {
      push @pi, $node;
    }
  }

  if (defined $root_el_name and defined $dt) {
    $self->onerror->(level => 'm',
                     type => 'VC:Root Element Type',
                     text => $root_el_name,
                     node => $dt, value => $dt->node_name)
        unless $root_el_name eq $dt->node_name;
  }

  for my $pi (@pi) {
    my $target = $pi->target;
    $self->onerror->(level => 'w',
                     type => 'xml:pi:target not declared',
                     node => $pi, value => $target)
        if not defined $dt or not defined $dt->notations->{$target};
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
                                 type => 'VC:Notation Attributes:declared',
                                 node => $at, value => $_);
              }
            }
          }
          $has_token->{$_} = 1;
        }
      } # $tokens

      my $default_type = $at->default_type;
      my $dv = $at->node_value;
      if ($declared_type == $at->ID_ATTR) {
        $self->onerror->(level => 'w',
                         type => 'xml:dtd:non-id ID',
                         node => $at)
            unless $at->node_name eq 'id';
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
      if ($declared_type != $at->ID_ATTR and $at->node_name eq 'id') {
        $self->onerror->(level => 'w',
                         type => 'xml:dtd:id non-ID',
                         node => $at);
      }
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

sub _validate_element ($$) {
  my ($self, $node) = @_;

  my $dt = $node->owner_document->doctype ||
           $node->owner_document->create_document_type;

  my $ids = {};
  my $idrefs = {};

  my @node = ($node);
  while (@node) {
    my $node = shift @node;

    my $node_name = $node->node_name;
    my $et = $dt->element_types->{$node_name};
    my $cm = defined $et ? $et->content_model_text : undef;
    if (not defined $cm) {
      $self->onerror->(level => 'm',
                       type => 'VC:Element Valid:declared',
                       node => $node, value => $node_name);
    }

    if (defined $et) {
      my $has_attr = {};
      for my $attr ($node->attributes->to_list) {
        my $attr_name = $attr->name;
        $has_attr->{$attr_name} = 1;
        my $at = $et->attribute_definitions->{$attr_name};
        if (defined $at) {
          my $declared_type = $at->declared_type;
          my $value = $attr->value;
          if ($declared_type == $at->ID_ATTR) {
            $self->onerror->(level => 'm',
                             type => 'xml:name syntax',
                             node => $attr, value => $value)
                unless $value =~ /\A$XMLName\z/o;
            $self->onerror->(level => 'm',
                             type => 'xml:ncname syntax',
                             node => $attr, value => $value)
                if $value =~ /:/;
            if (defined $ids->{$value}) {
              $self->onerror->(level => 'm',
                               type => 'VC:ID:unique',
                               node => $attr, value => $value);
            } else {
              $ids->{$value} = $attr;
            }
          } elsif ($declared_type == $at->IDREF_ATTR) {
            push @{$idrefs->{$value} ||= []}, $attr;
          } elsif ($declared_type == $at->IDREFS_ATTR) {
            for (split /\x20/, $value, -1) {
              push @{$idrefs->{$_} ||= []}, $attr;
            }
          } elsif ($declared_type == $at->ENUMERATION_ATTR) {
            CHK: {
              for (@{$at->allowed_tokens}) {
                last CHK if $_ eq $value;
              }
              $self->onerror->(level => 'm',
                               type => 'VC:Enumeration',
                               node => $attr, value => $value);
            } # CHK
          } elsif ($declared_type == $at->NOTATION_ATTR) {
            CHK: {
              for (@{$at->allowed_tokens}) {
                last CHK if $_ eq $value;
              }
              $self->onerror->(level => 'm',
                               type => 'VC:Notation Attributes:enumeration',
                               node => $attr, value => $value);
            } # CHK
          } elsif ($declared_type == $at->NMTOKEN_ATTR) {
            $self->onerror->(level => 'm',
                             type => 'xml:nmtoken syntax',
                             node => $attr, value => $value)
                unless $value =~ /\A\p{InXMLNameChar}+\z/o;
          } elsif ($declared_type == $at->NMTOKENS_ATTR) {
            $self->onerror->(level => 'm',
                             type => 'xml:nmtokens syntax',
                             node => $attr, value => $value)
                unless $value =~ /\A\p{InXMLNameChar}+(?>\x20\p{InXMLNameChar}+)*\z/o;
          } # $declared_type
          
          my $default_type = $at->default_type;
          if ($default_type == $at->FIXED_DEFAULT) {
            unless ($attr->value eq $at->node_value) {
              $self->onerror->(level => 'm',
                               type => 'VC:Fixed Attribute Default',
                               text => $at->node_value,
                               node => $attr);
            }
          }
        } else { # no <!ATTLIST>
          $self->onerror->(level => 'm',
                           type => 'VC:Attribute Value Type:declared',
                           node => $attr, value => $attr_name)
              if defined $et;
        }
      } # $attr

      my $attrs = $node->attributes;
      for my $at ($et->attribute_definitions->to_list) {
        my $name = $at->node_name;
        if (not $has_attr->{$name} and $at->default_type == $at->REQUIRED_DEFAULT) {
          $self->onerror->(level => 'm',
                           type => 'VC:Required Attribute',
                           text => $name,
                           node => $node);
        }
      }
    } # $et

    for my $child ($node->child_nodes->to_list) {
      my $child_nt = $child->node_type;
      if ($child_nt == $child->PROCESSING_INSTRUCTION_NODE) {
        my $target = $child->target;
        $self->onerror->(level => 'w',
                         type => 'xml:pi:target not declared',
                         node => $child, value => $target)
            if not defined $dt->notations->{$target};
      }
    } # $child
  } # $node

  ## IDREF/IDREFS attribute values
  for my $id (keys %$idrefs) {
    unless (defined $ids->{$id}) {
      for (@{$idrefs->{$id}}) {
        $self->onerror->(level => 'm',
                         type => 'VC:IDREF:referenced element',
                         node => $_, value => $id);
      }
    }
  }
} # _validate_element

=pod

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
