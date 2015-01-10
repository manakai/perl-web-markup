package Web::XML::DTDValidator;
use strict;
use warnings;
our $VERSION = '8.0';
use Char::Class::XML qw(InXMLNameStartChar InXMLNameChar
                        InXMLNCNameStartChar InXMLNCNameChar);

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

my $XMLS = qr/[\x09\x0A\x0D\x20]/;
my $XMLName = qr/\p{InXMLNameStartChar}\p{InXMLNameChar}*/;
my $XMLNCName = qr/\p{InXMLNCNameStartChar}\p{InXMLNCNameChar}*/;
my $GITEM; {
  use re 'eval';
  $GITEM = qr/(?>[^()*+?|,\x09\x0A\x0D\x20]+|\($XMLS*(??{$GITEM})$XMLS*(?>[|,]$XMLS(??{$GITEM})$XMLS*)*\))(?>[*+?]|)/;
}

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

  ## PIs in document or in doctype
  for my $child (@pi) {
    my $target = $child->target;
    if (not defined $dt or not defined $dt->notations->{$target}) {
      if (not $target =~ /\A$XMLName\z/o or $target =~ /\A[Xx][Mm][Ll]\z/) {
        $self->onerror->(level => 'm',
                         type => 'xml:name syntax',
                         node => $child, value => $target);
      } else {
        if ($target =~ /:/) {
          $self->onerror->(level => 'm',
                           type => 'xml:ncname syntax',
                           node => $child, value => $target);
        } else {
          $self->onerror->(level => 'w',
                           type => 'xml:pi:target not declared',
                           node => $child, value => $target);
        }
      }
    }
  }
} # validate_document

sub _validate_doctype ($$) {
  my ($self, $dt) = @_;

  ## Element type definitions (created from <!ELEMENT> and/or <!ATTLIST>)
  for my $et ($dt->element_types->to_list) {
    my $et_name = $et->node_name;
    if (not $et_name =~ /\A$XMLName\z/o) {
      $self->onerror->(level => 'm',
                       type => 'xml:name syntax',
                       node => $et, value => $et_name);
    } else {
      $self->onerror->(level => 'm',
                       type => 'xml:qname syntax',
                       node => $et, value => $et_name)
          if $et_name =~ /:/ and not $et_name =~ /\A$XMLNCName:$XMLNCName\z/o;
    }

    my $cm = $et->content_model_text;
    my @at = $et->attribute_definitions->to_list;

    if (defined $cm) {
      if ($cm eq 'ANY' or $cm eq 'EMPTY') {
        $self->{cm}->{$et_name} = [$cm];
      } else {
        if ($cm =~ s/^\($XMLS*\#PCDATA$XMLS*(?>\|$XMLS*|(?=\)))//o) {
          $self->{cm}->{$et_name} = ['mixed', {}];
          $cm =~ s/$XMLS*\)\*?\z//o;
          for (grep { length } split /$XMLS*\|$XMLS*/o, $cm) {
            if ($self->{cm}->{$et_name}->[1]->{$_}) {
              $self->onerror->(level => 'm',
                               type => 'VC:No Duplicate Types',
                               node => $et, value => $_);
            } else {
              $self->{cm}->{$et_name}->[1]->{$_} = 1;
              if (not defined $dt->element_types->{$_}) {
                if (not $_ =~ /\A$XMLName\z/o) {
                  $self->onerror->(level => 'm',
                                   type => 'xml:name syntax',
                                   node => $et, value => $_);
                } else {
                  if ($_ =~ /:/ and not $_ =~ /\A$XMLNCName:$XMLNCName\z/o) {
                    $self->onerror->(level => 'm',
                                     type => 'xml:qname syntax',
                                     node => $et, value => $_);
                  } else {
                    $self->onerror->(level => 'w',
                                     type => 'xml:dtd:cm:element not declared',
                                     node => $et, value => $_);
                  }
                }
              }
            }
          } # $cm
        } else {
          my $group = ['group', $cm, '', '|'];
          $group->[2] = $1 if $group->[1] =~ s/([+*?]|)\z//;
          my @todo = ($group);
          while (@todo) {
            my $todo = shift @todo;
            $todo->[1] =~ s/\A\($XMLS*//o;
            $todo->[1] =~ s/$XMLS*\)\z//o;
            my @item;
            {
              if ($todo->[1] =~ s/^($GITEM)$XMLS*//o) {
                my $item = $1;
                $item =~ s/([*+?]|)\z//;
                my $repeat = $1;
                push @item, [$item =~ /^\(/ ? 'group' : 'element', $item, $repeat, '|'];
                push @todo, $item[-1] if $item[-1]->[0] eq 'group';
              }
              if ($todo->[1] =~ s/^([,|])$XMLS*//o) {
                $todo->[3] = $1;
                redo;
              }
            }
            $todo->[1] = \@item;
          } # @todo

          my @state;
          $self->{cm}->{$et_name} = ['element', \@state];
          $state[0] = {};
          my $g2s; $g2s = sub ($$) {
            my ($prev_ids, $item) = @_;
            my $next_ids = [];

            my $plus_id;
            if ($item->[2] eq '+' or $item->[2] eq '*') {
              $state[$plus_id = @state] = {};
              $prev_ids = [@$prev_ids, $plus_id];
            }

            my $deterministic_error;
            if ($item->[0] eq 'element') {
              $state[my $next_id = @state] = {};
              push @$next_ids, $next_id;
              for (@$prev_ids) {
                if (defined $state[$_]->{$item->[1]}) {
                  $self->onerror->(level => 'm',
                                   type => 'Deterministic Content Models',
                                   node => $et, value => $item->[1])
                      unless $deterministic_error++;
                } else {
                  $state[$_]->{$item->[1]} = $next_id;
                }
              }
              unless (defined $dt->element_types->{$item->[1]}) {
                if (not $item->[1] =~ /\A$XMLName\z/o) {
                  $self->onerror->(level => 'm',
                                   type => 'xml:name syntax',
                                   node => $et, value => $item->[1]);
                } else {
                  if ($item->[1] =~ /:/ and
                      not $item->[1] =~ /\A$XMLNCName:$XMLNCName\z/o) {
                    $self->onerror->(level => 'm',
                                     type => 'xml:qname syntax',
                                     node => $et, value => $item->[1]);
                  } else {
                    $self->onerror->(level => 'w',
                                     type => 'xml:dtd:element not declared',
                                     node => $et, value => $item->[1]);
                  }
                }
              }
            } elsif ($item->[0] eq 'group') {
              if ($item->[3] eq '|') {
                for (@{$item->[1]}) {
                  push @$next_ids, @{$g2s->($prev_ids => $_)};
                }
              } elsif ($item->[3] eq ',') {
                $next_ids = $prev_ids;
                for (@{$item->[1]}) {
                  $next_ids = $g2s->($next_ids => $_);
                }
              } else {
                die $item->[3];
              }
            } else {
              die $item->[0];
            }

            if (defined $plus_id) {
              for my $next_id (@$next_ids) {
                for (keys %{$state[$plus_id]}) {
                  if (defined $state[$next_id]->{$_}) {
                    $self->onerror->(level => 'm',
                                     type => 'Deterministic Content Models',
                                     node => $et, value => $_)
                        unless $deterministic_error++;
                  } else {
                    $state[$next_id]->{$_} = $state[$plus_id]->{$_};
                  }
                }
              }
            }

            if ($item->[2] eq '*' or $item->[2] eq '?') {
              push @$next_ids, @$prev_ids;
            }

            return $next_ids;
          }; # $g2s
          for (@{$g2s->([0] => $group)}) {
            $state[$_]->{''} = -1;
          }
          undef $g2s;
        }
      }
    } else { # no $cm
      $self->onerror->(level => 'w',
                       type => 'xml:dtd:element:no content model',
                       node => $et)
          unless @at;
    } # $cm

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
      if (not $at_name =~ /\A$XMLName\z/o) {
        $self->onerror->(level => 'm',
                         type => 'xml:name syntax',
                         node => $at, value => $at_name);
      } elsif ($at_name =~ /:/ and not $at_name =~ /\A$XMLNCName:$XMLNCName\z/o) {
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
                $self->onerror->(level => 'm',
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
          if (not $dv =~ /\A$XMLName\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:name syntax',
                             node => $at, value => $dv);
          } elsif ($dv =~ /:/) {
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
          if (not $dv =~ /\A$XMLName\x20$XMLName*\z/o) {
            $self->onerror->(level => 'm',
                             type => 'xml:names syntax',
                             node => $at, value => $dv);
          } elsif ($dv =~ /:/) {
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

      if ($at_name eq 'xml:space') {
        if ($declared_type == $at->ENUMERATION_ATTR and
            ((@$tokens == 2 and $tokens->[0] eq 'default' and $tokens->[1] eq 'preserve') or
             (@$tokens == 2 and $tokens->[0] eq 'preserve' and $tokens->[1] eq 'default') or
             (@$tokens == 1 and $tokens->[0] eq 'default') or
             (@$tokens == 1 and $tokens->[0] eq 'preserve'))) {
          #
        } else {
          $self->onerror->(level => 'm',
                           type => 'xml:space:bad type',
                           node => $at);
        }
      }
    } # $at
  } # $et

  ## Unparsed entities (<!ENTITY ... NDATA ...>)
  for my $ent ($dt->entities->to_list) {
    my $name = $ent->node_name;
    if (not $name =~ /\A$XMLName\z/o) {
      $self->onerror->(level => 'm',
                       type => 'xml:name syntax',
                       node => $ent, value => $name);
    } elsif ($name =~ /:/) {
      $self->onerror->(level => 'm',
                       type => 'xml:ncname syntax',
                       node => $ent, value => $name);
    }

    my $ndata = $ent->notation_name;
    if (defined $ndata) {
      unless (defined $dt->notations->{$ndata}) {
        $self->onerror->(level => 'm',
                         type => 'VC:Notation Declared',
                         node => $ent, value => $ndata);
      }
    }
  } # $ent

  ## Notations (<!NOTATION>)
  for my $notation ($dt->notations->to_list) {
    my $name = $notation->node_name;
    if (not $name =~ /\A$XMLName\z/o) {
      $self->onerror->(level => 'm',
                       type => 'xml:name syntax',
                       node => $notation, value => $name);
    } elsif ($name =~ /:/) {
      $self->onerror->(level => 'm',
                       type => 'xml:ncname syntax',
                       node => $notation, value => $name);
    }
  }
} # _validate_doctype

sub _validate_element ($$) {
  my ($self, $node) = @_;

  my $standalone = $node->owner_document->xml_standalone;
  my $dt = $node->owner_document->doctype ||
           $node->owner_document->create_document_type_definition ($node->node_name);

  my $ids = {};
  my $idrefs = {};

  my @node = ($node);
  while (@node) {
    my $node = shift @node;

    my $node_name = $node->node_name;
    my $et = $dt->element_types->{$node_name};
    my $cm = $self->{cm}->{$node_name};
    if (not defined $cm) {
      $self->onerror->(level => 'm',
                       type => 'VC:Element Valid:declared',
                       node => $node, value => $node_name);
      $cm = [''];
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
            if (not $value =~ /\A$XMLName\z/o) {
              $self->onerror->(level => 'm',
                               type => 'xml:name syntax',
                               node => $attr, value => $value);
            } elsif ($value =~ /:/) {
              $self->onerror->(level => 'm',
                               type => 'xml:ncname syntax',
                               node => $attr, value => $value);
            }
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
            my @refs = split /\x20/, $value, -1;
            for (@refs) {
              push @{$idrefs->{$_} ||= []}, $attr;
            }
            $self->onerror->(level => 'm',
                             type => 'xml:names syntax',
                             node => $attr, value => $value)
                unless @refs;
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
          } elsif ($declared_type == $at->ENTITY_ATTR) {
            my $ent = $dt->entities->{$value};
            if (defined $ent) {
              unless (defined $ent->notation_name) {
                $self->onerror->(level => 'm',
                                 type => 'VC:Entity Name:unparsed',
                                 node => $attr, value => $value);
              }
            } else {
              $self->onerror->(level => 'm',
                               type => 'VC:Entity Name:declared',
                               node => $attr, value => $value);
            }
          } elsif ($declared_type == $at->ENTITIES_ATTR) {
            my @refs = split /\x20/, $value, -1;
            for (@refs) {
              my $ent = $dt->entities->{$_};
              if (defined $ent) {
                unless (defined $ent->notation_name) {
                  $self->onerror->(level => 'm',
                                   type => 'VC:Entity Name:unparsed',
                                   node => $attr, value => $_);
                }
              } else {
                $self->onerror->(level => 'm',
                                 type => 'VC:Entity Name:declared',
                                 node => $attr, value => $_);
              }
            }
            $self->onerror->(level => 'm',
                             type => 'xml:names syntax',
                             node => $attr, value => $value)
                unless @refs;
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

    my @child = $node->child_nodes->to_list;
    my @child_el;
    for my $child (@child) {
      my $child_nt = $child->node_type;
      if ($child_nt == 1) { # ELMENT_NODE
        push @node, $child;
        push @child_el, $child;
      } elsif ($child_nt == 3) { # TEXT_NODE
        if ($cm->[0] eq 'element') {
          if ($child->data =~ /[^\x09\x0A\x0D\x20]/) {
            $self->onerror->(level => 'm',
                             type => 'VC:Element Valid:element children:text',
                             node => $child);
          }
          if ($standalone and $child->data =~ /[\x09\x0A\x0D\x20]/) {
            $self->onerror->(level => 'm',
                             type => 'VC:Standalone Document Declaration:ws',
                             node => $child);
          }
        }
      } elsif ($child_nt == $child->PROCESSING_INSTRUCTION_NODE) {
        my $target = $child->target;
        if (not defined $dt->notations->{$target}) {
          if (not $target =~ /\A$XMLName\z/o or $target =~ /\A[Xx][Mm][Ll]\z/) {
            $self->onerror->(level => 'm',
                             type => 'xml:name syntax',
                             node => $child, value => $target);
          } else {
            if ($target =~ /:/) {
              $self->onerror->(level => 'm',
                               type => 'xml:ncname syntax',
                               node => $child, value => $target);
            } else {
              $self->onerror->(level => 'w',
                               type => 'xml:pi:target not declared',
                               node => $child, value => $target);
            }
          }
        }
      }
    } # $child

    if ($cm->[0] eq 'EMPTY') {
      $self->onerror->(level => 'm',
                       type => 'VC:Element Valid:EMPTY',
                       node => $child[0])
          if @child;
    } elsif ($cm->[0] eq 'ANY') {
      #
    } elsif ($cm->[0] eq 'mixed') {
      for (@child_el) {
        $self->onerror->(level => 'm',
                         type => 'VC:Element Valid:mixed child',
                         node => $_, value => $_->node_name)
            unless $cm->[1]->{$_->node_name};
      }
    } elsif ($cm->[0] eq 'element') {
      my $states = $cm->[1];
      my $state = 0;
      for (@child_el) {
        my $next_id = $states->[$state]->{$_->node_name};
        if (not defined $next_id) {
          $self->onerror->(level => 'm',
                           type => 'VC:Element Valid:element child:element',
                           text => (join '|', sort { $a cmp $b } grep { length } keys %{$states->[$state]}),
                           node => $_);
          undef $state;
          last;
        }
        $state = $next_id;
      }
      if (defined $state) {
        unless (($states->[$state]->{''} || 0) == -1) {
          $self->onerror->(level => 'm',
                           type => 'VC:Element Valid:element child:required element',
                           text => (join '|', sort { $a cmp $b } keys %{$states->[$state]}),
                           node => $node);
        }
      }
    }
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

1;

=head1 LICENSE

Copyright 2003-2015 Wakaba <wakaba@suikawiki.org>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
