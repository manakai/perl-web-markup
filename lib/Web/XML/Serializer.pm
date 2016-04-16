package Web::XML::Serializer;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '11.0';
use Web::HTML::ParserData;

sub new ($) {
  return bless {}, $_[0];
} # new

sub get_qname ($$$$$$$) {
  #my ($nsurl, $prefix, $ln, $attrs, $default_ns, $nsmap, $is_element) = @_;
  my $nsurl = $_[0];
  my $prefix = $_[1];
  my $attrs = $_[3];

  # 1.
  my $qname = $_[2];

  # 2.
  my $new_attr;

  if (not defined $nsurl) {
    # 3.1.-3.2.
    if ($_[6] and (not defined $_[4] or defined ${$_[4]})) {
      # 1.
      $_[4] = \undef;

      # 2.
      my $attr = [grep {
        $_->local_name eq 'xmlns' and
        ($_->namespace_uri || '') eq Web::HTML::ParserData::XMLNS_NS;
      } @$attrs]->[0];
      if ($attr) {
        # 1.
        if ($attr->value ne '') {
          @$attrs = map { $_ eq $attr ? ['xmlns', ''] : $_ } @$attrs;
        }
      } else {
        # 3.
        $new_attr = ['xmlns', ''];
      }
    }
  } else {
    # 4.
    if ($nsurl eq Web::HTML::ParserData::XML_NS) {
      # 1.
      $prefix = 'xml';
    } elsif ($nsurl eq Web::HTML::ParserData::XMLNS_NS) {
      # 2.
      $prefix = 'xmlns';
    }

    my $nsmap_hashref = {map { @$_ } @{$_[5]}};

    if ($nsurl eq Web::HTML::ParserData::XMLNS_NS and
        $qname eq 'xmlns') {
      # 3.
      #
    } elsif ($_[6] and not defined $prefix and not defined $_[4]) {
      # 4.

      # 1.
      $_[4] = \$nsurl;
      
      # 2.
      $new_attr = ['xmlns', $nsurl];
    } elsif ($_[6] and not defined $prefix and
             defined $_[4] and defined ${$_[4]} and $_[4] eq $nsurl) {
      # 5.
      #
    } elsif (defined $prefix and
             defined $nsmap_hashref->{$prefix} and
             defined ${$nsmap_hashref->{$prefix}} and
             ${$nsmap_hashref->{$prefix}} eq $nsurl) {
      # 6.
      $qname = $prefix . ':' . $qname;
    } elsif (defined $prefix and 
             not defined $nsmap_hashref->{$prefix}) {
      # 7.

      # 1.
      push @{$_[5]}, [$prefix, \$nsurl];

      # 2.
      $new_attr = ['xmlns:'.$prefix, $nsurl];

      # 3.
      $qname = $prefix . ':' . $qname;
    } elsif (defined (my $prefix2 = [grep {
      defined $nsmap_hashref->{$_} and
      defined ${$nsmap_hashref->{$_}} and
      ${$nsmap_hashref->{$_}} eq $nsurl;
    } keys %$nsmap_hashref]->[-1])) {
      # 8.
      $qname = $prefix2 . ':' . $qname;
    } elsif ($_[6] and defined $_[4] and defined ${$_[4]} and
             ${$_[4]} eq $nsurl) {
      # 9.
      # 
    } elsif ($_[6] and not defined $prefix and not [grep {
               ($_->namespace_uri || '') eq Web::HTML::ParserData::XMLNS_NS and
               $_->local_name eq 'xmlns';
             } @$attrs]->[0]) {
      # 10.

      # 1.
      $_[4] = \$nsurl;
      
      # 2.
      $new_attr = ['xmlns', $nsurl];
    } else {
      # 11.

      # 1.
      my $n = 0;
      while (defined $nsmap_hashref->{'a'.$n}) {
        $n++;
      }
      $prefix = 'a'.$n;

      # 2.
      push @{$_[5]}, [$prefix, \$nsurl];

      # 3.
      $new_attr = ['xmlns:'.$prefix, $nsurl];

      # 4.
      $qname = $prefix . ':' . $qname;
    }
  }

  # 5.
  return ($qname, $new_attr);
} # get_qname

sub get_inner_html ($$) {
  my $node = $_[1];

  ## XML fragment serialization algorithm
  ## <http://www.whatwg.org/specs/web-apps/current-work/#serializing-xhtml-fragments>
  ## Produce an XML serialization
  ## <http://domparsing.spec.whatwg.org/#concept-serialize-xml>

  ## XXX HTML requires the serializer to throw if not serializable,
  ## while DOMPARSING requires not to throw.

  ## Step 1
  my $s = '';
  
  ## Step 2
  my @node = map { [$_,
                    undef, # undef = missing, \undef = null, \$nsurl
                    # \undef = none, \$nsurl
                    [[xml => \Web::HTML::ParserData::XML_NS],
                     [xmlns => \Web::HTML::ParserData::XMLNS_NS]]] }
      ref $node eq 'ARRAY' ? @$node :
      ($node->node_type == 1 and $node->manakai_element_type_match (Web::HTML::ParserData::HTML_NS, 'template'))
          ? $node->content->child_nodes->to_list
          : $node->child_nodes->to_list;
  C: while (@node) {
    ## Step 2.1
    my $c = shift @node;
    my $child = $c->[0];

    ## End tag
    if (not ref $child) {
      $s .= $child;
      next;
    }

    ## Step 2.2
    my $nt = $child->node_type;
    if ($nt == 1) { # Element
      ## Namespace fixup
      ## <http://suika.suikawiki.org/www/markup/xml/nsfixup>.

      # 1.-2.
      my $default_ns = $c->[1];
      my $nsmap = [@{$c->[2]}];
      
      # 3.
      my @attr = @{$child->attributes};

      # 4.
      for my $attr (@attr) {
        # 1.
        my $ns = $attr->namespace_uri || '';
        next unless $ns eq Web::HTML::ParserData::XMLNS_NS;
        
        # 2.-3.
        my $ln = $attr->local_name;
        my $value = $attr->value;

        # 4.
        next if $ln eq 'xml' or
            $value eq Web::HTML::ParserData::XML_NS or
            $value eq Web::HTML::ParserData::XMLNS_NS;
        
        if ($ln eq 'xmlns') {
          # 5.
          $default_ns = $value eq '' ? \undef : \$value;
        } else {
          # 6.

          # 1.
          @$nsmap = grep { $_->[0] ne $ln } @$nsmap;

          # 2.-3.
          push @$nsmap, [$ln, $value eq '' ? \undef : \$value];
        }
      } # $attr

      # 5.
      my ($tag_name, $new_attr) = get_qname 
          $child->namespace_uri,
          $child->prefix,
          $child->local_name,
          \@attr,
          $default_ns,
          $nsmap,
          'is_element';

      # 7.
      my @attr_spec;

      # 6.
      push @attr_spec, $new_attr if $new_attr;

      # 8.
      for my $attr (@attr) {
        # 1.
        my ($attr_name, $new_attr) = get_qname 
            $attr->namespace_uri,
            $attr->prefix,
            $attr->local_name,
            \@attr,
            $default_ns,
            $nsmap,
            0;

        # 3.
        push @attr_spec, [$attr_name, $attr->value];

        # 2.
        push @attr_spec, $new_attr if $new_attr;
      }

      $s .= '<' . $tag_name;

      for my $attr (@attr_spec) {
        $s .= ' ' . $attr->[0] . '="';
        ## escape
        $attr->[1] =~ s/&/&amp;/g;
        $attr->[1] =~ s/\xA0/&nbsp;/g;
        $attr->[1] =~ s/"/&quot;/g;
        #$attr->[1] =~ s/</&lt;/g;
        #$attr->[1] =~ s/>/&gt;/g;
# XXX U+0000-001F
        $s .= $attr->[1] . '"';
      }
      $s .= '>';
      
      unshift @node,
          (map { [$_, $default_ns, $nsmap] }
           ($child->node_type == 1 and $child->manakai_element_type_match (Web::HTML::ParserData::HTML_NS, 'template')) ? $child->content->child_nodes->to_list : $child->child_nodes->to_list),
          (['</' . $tag_name . '>']);
    } elsif ($nt == 3) { # Text
      my $value = $child->data;
      $value =~ s/&/&amp;/g;
      $value =~ s/\xA0/&nbsp;/g;
      $value =~ s/</&lt;/g;
      $value =~ s/>/&gt;/g;
      #$value =~ s/"/&quot;/g;
      $s .= $value;

      # XXX Should we support Text->serializeAsCDATA [DOMPARSING]?
    } elsif ($nt == 8) { # Comment
      $s .= '<!--' . $child->data . '-->';
    } elsif ($nt == 10) { # DocumentType
      $s .= '<!DOCTYPE ' . $child->name . '>';
    } elsif ($nt == 7) { # ProcessingInstruction
      $s .= '<?' . $child->target . ' ' . $child->data . '?>';
    } elsif ($nt == 9 or $nt == 11) { # Document / DocumentFragment
      unshift @node, map { [$_, $c->[1], $c->[2]] } $child->child_nodes->to_list;
    } else {
      die "Unsupported node type $nt";
    }
  } # C
  
  ## Step 3
  return \$s;
} # get_inner_html

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
