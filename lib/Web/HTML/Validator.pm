package Web::HTML::Validator;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '128.0';
use Scalar::Util qw(refaddr);
use Web::HTML::Validator::_Defs;

## ------ Constructor ------

sub new ($) {
  return bless {}, $_[0];
} # new

## ------ Validator error handler ------

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my %args = @_;
    return if $args{level} eq 'mh';
    warn sprintf "%s%s%s%s (%s)%s\n",
        defined $args{node} ? $args{node}->node_name . ': ' : '',
        $args{type},
        defined $args{text} ? ' ' . $args{text} : '',
        defined $args{value} ? ' "' . $args{value} . '"' : '',
        $args{level},
        (defined $args{column} ? sprintf ' at line %d column %d', $args{line}, $args{column} : '');
  };
} # onerror

my $GetNestedOnError = sub {
  my ($onerror, $node) = @_;
  my $pos = $node->get_user_data ('manakai_pos');
  return sub {
    my %args = @_;
    delete $args{uri}; # XXX

    my $line = delete $args{line};
    my $column = delete $args{column};
    if (not defined $line and $args{node}) {
      $line = $args{node}->get_user_data ('manakai_source_line');
      $column = $args{node}->get_user_data ('manakai_source_column');
    }

    if (defined $line and defined $column) {
      $column ||= 1;
      if ($pos and ref $pos eq 'ARRAY') {
        my $v = [1,1 => 1,1];
        for (@$pos) {
          if ($_->[0] < $line or
              ($_->[0] == $line and $_->[1] <= $column)) {
            $v = $_;
          } else {
            last;
          }
        }
        if ($v) {
          if ($v->[0] == $line) {
            $onerror->(@_, node => $node,
                       line => $v->[2],
                       column => $v->[3] + $column - $v->[1]);
            return;
          } else {
            $onerror->(@_, node => $node,
                       line => $v->[2] + $line - $v->[0],
                       column => $column);
            return;
          }
        }
      }
    }

    # XXX has no line/column; can we do something better?

    $onerror->(%args, node => $node);
  };
}; # $GetNestedOnError

## ------ Validator definitions and states ------

## Variable |$_Defs| (|$Web::HTML::Validator::_Defs|), defined in
## |Web::HTML::Validator::_Defs| module, is generated from
## |element.json| in <https://github.com/manakai/data-web-defs/>.  It
## contains various properties of elements and attributes, described
## in
## <https://github.com/manakai/data-web-defs/blob/master/doc/elements.txt>.

## $self->{flag}->
##
##   {has_autofocus}     Used to detect duplicate autofocus="" attributes.
##   {has_http_equiv}->{$keyword}  Set to true if there is a
##                       <meta http-equiv=$keyword> element.
##   {has_label}         Set to a true value if and only if there is a
##                       |label| element ancestor of the current node.
##   {has_labelable}     Set to |1| if and only if a nearest ancestor |label|
##                       element has the |for| attribute and there is
##                       no labelable form-associated element that is
##                       a descendant of the |label| element and
##                       precedes the current node in tree order.
##                       This flag is set to |2| if and only if there
##                       is a labelable form-associated element that
##                       is a descendant of the nearest ancestor
##                       |label| element of the current node and
##                       precedes the current node in tree order.
##                       Otherwise, it is set to a false value.
##                       However, when there is no ancestor |label|
##                       element of the current node, i.e. when
##                       |$self->{flag}->{has_label}| is false, the
##                       value of the |$self->{flag}->{has_labelable}|
##                       flag is undefined.
##   {has_meta_charset}  Set to true if there is a <meta charset=""> or
##                       <meta http-equiv=content-type> element.
##   {in_a_href}         Set to true if there is an ancestor |a| element
##                       with a |href| attribute.
##   {in_canvas}         Set to true if there is an ancestor |canvas| element.
##   {in_head}           Set to true if there is an ancestor |head| element.
##   {in_media}          Set to true if there is an ancestor media element.
##   {in_phrasing}       Set to true if in phrasing content expecting element.
##   {is_template}       The checker is in the template content mode.
##   {no_interactive}    Set to true if no interactive content is allowed.

## $element_state
##
##   figcaptions     Used by |figure| element checker.
##   figure_embedded_count If the element is a |figure| element, the number
##                   of embedded content child elements.
##   figure_has_non_table If the element is a |figure| element, whether
##                   there is a non-|table| content or not.
##   figure_table_count If the element is a |figure| element, the number
##                   of |table| child elements.
##   has_autofocus_original Used for autofocus="" scoping by |dialog|
##   has_figcaption_content The element is a |figure| element and
##                   there is a |figcaption| child element whose content
##                   has elements and/or texts other than inter-element
##                   whitespaces.
##   has_label_original Used to preserve the value of
##                   |$self->{flag}->{has_label}| at the time of
##                   invocation of the method |check_start| for the
##                   element being checked.
##   has_labelable_original Used to preserve the value of 
##                   |$self->{flag}->{has_labelable}| at the time of
##                   invocation of the method |check_start| for the 
##                   element being checked.
##   has_non_style   Used by flow content checker to detect misplaced
##                   |style| elements.
##   has_palpable    Set to true if a palpable content child is found.
##                   (Handled specially for <ruby>.)
##   has_summary     Used by |details| element checker.
##   in_a_href_original Used to preserve |$self->{flag}->{in_a_href}|.
##   in_flow_content Set to true while the content model checker is
##                   in the "flow content" checking mode.
##   phase           Content model checker state name.  Possible values
##                   depend on the element.
##   require_title   Set to 'm' (MUST) or 's' (SHOULD) if the element
##                   is expected to have the |title| attribute.
##   style_type      The styling language's MIME type object.
##   text            Text data in the element.

sub _init ($) {
  my $self = $_[0];
  $self->{minus_elements} = {};
  $self->{id} = {};
  $self->{id_type} = {};
  $self->{name} = {};
  $self->{form} = {}; # form/@name
  $self->{idref} = [];
  $self->{term} = {};
  $self->{usemap} = [];
  $self->{map_exact} = {}; # |map| elements with their original |name|s
  $self->{map_compat} = {}; # |map| elements with their lowercased |name|s
  $self->{has_link_type} = {};
  $self->{flag} = {};
  $self->{top_level_item_elements} = [];
      ## An arrayref of elements that create top-level microdata items
  $self->{itemprop_els} = [];
      ## An atrrayref of elements with |itemprop| attribute
  #$self->{has_uri_attr};
  #$self->{has_hyperlink_element};
  #$self->{has_charset};
  #$self->{has_base};
  $self->{return} = {
    class => {},
    id => $self->{id},
    name => $self->{name},
    table => [], # table objects returned by Web::HTML::Table
    term => $self->{term},
    rdf => [],
  };
} # _init

sub _terminate ($) {
  my $self = $_[0];
  delete $self->{minus_elements};
  delete $self->{id};
  delete $self->{id_type};
  delete $self->{name};
  delete $self->{form};
  delete $self->{idref};
  delete $self->{usemap};
  delete $self->{map_exact};
  delete $self->{map_compat};
  delete $self->{top_level_item_elements};
  delete $self->{itemprop_els};
} # _terminate

## For XML documents c.f. <http://www.whatwg.org/specs/web-apps/current-work/#serializing-xhtml-fragments>
## XXX warning public ID chars
## XXX warning system ID chars
## XXX warning "xmlns" attribute in no namespace
## XXX warning attribute name duplication
## XXX warning Comment.data =~ /--/ or =~ /-\z/
## XXX warning PI.target == xml
## XXX warning PI.data =~ /\?>/ or =~ /^<S>/
## XXX warning attribute definition's properties
## XXX must?? system ID has to be URL
##   MUST VersionNum http://www.w3.org/TR/xml/#xmldoc
##   MUST EncName
##   SHOULD fully-normalized
##   warning suggestion for names
## XXX local part begining with "xml" is inadvisable [XMLNS]
## XXX Prefix and local part MUST be NCName [XMLNS].
## XXX Document type name, entity name, notation name, entity's
## notation name, element type name, attribute name in attribute
## definition, element names in element content model, and PI target
## MUST be NCName [XMLNS].

## XXX In HTML documents
##   warning doctype name, pubid, sysid
##   warning PI, element type definition, attribute definition
##   warning comment data
##   warning pubid/sysid chars
##   warning non-ASCII element names
##   warning uppercase element/attribute names
##   warning element/attribute names
##   warning non-builtin prefix/namespaces
##   warning xmlns=""
##   warning prefix
##   warning http://www.whatwg.org/specs/web-apps/current-work/#comments
##   warning http://www.whatwg.org/specs/web-apps/current-work/#element-restrictions
##   warning http://www.whatwg.org/specs/web-apps/current-work/#cdata-rcdata-restrictions
##   warning unserializable foreign elements

## XXX xml-stylesheet PI

sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub MML_NS () { q<http://www.w3.org/1998/Math/MathML> }
sub SVG_NS () { q<http://www.w3.org/2000/svg> }
sub XML_NS () { q<http://www.w3.org/XML/1998/namespace> }
sub XMLNS_NS () { q<http://www.w3.org/2000/xmlns/> }
sub XSLT_NS () { q<http://www.w3.org/1999/XSL/Transform> }
sub RDF_NS () { q<http://www.w3.org/1999/02/22-rdf-syntax-ns#> }
sub RSS1_NS () { q<http://purl.org/rss/1.0/> }

our $_Defs;

## ------ Text checker ------

## <http://www.whatwg.org/specs/web-apps/current-work/#text-content>
## <http://chars.suikawiki.org/set?expr=%24html%3AUnicode-characters+-+%5B%5Cu0000%5D+-+%24unicode%3ANoncharacter_Code_Point+-+%24html%3Acontrol-characters%20|%20$html:space-characters>
## + U+000C, U+000D
my $InvalidChar = qr{[^\x09\x0A\x{0020}-~\x{00A0}-\x{D7FF}\x{E000}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{1FFFD}\x{20000}-\x{2FFFD}\x{30000}-\x{3FFFD}\x{40000}-\x{4FFFD}\x{50000}-\x{5FFFD}\x{60000}-\x{6FFFD}\x{70000}-\x{7FFFD}\x{80000}-\x{8FFFD}\x{90000}-\x{9FFFD}\x{A0000}-\x{AFFFD}\x{B0000}-\x{BFFFD}\x{C0000}-\x{CFFFD}\x{D0000}-\x{DFFFD}\x{E0000}-\x{EFFFD}\x{F0000}-\x{FFFFD}\x{100000}-\x{10FFFD}]};

sub _check_data ($$) {
  my ($self, $node, $method) = @_;
  my $value = $node->$method;

  # XXX line/column by manakai_pos
  while ($value =~ /($InvalidChar)/og) {
    my $char = ord $1;
    if ($char == 0x000D) {
      # XXX in XML, roundtripable?
      $self->{onerror}->(node => $node,
                         type => 'U+000D not serializable',
                         index => - - $-[0],
                         level => 'w');
    } elsif ($char == 0x000C) {
      $self->{onerror}->(node => $node,
                         type => 'U+000C not serializable',
                         index => - - $-[0],
                         level => 'w')
          unless $node->owner_document->manakai_is_html;
    } else {
      $self->{onerror}->(node => $node,
                         type => 'text:bad char',
                         value => ($char <= 0x10FFFF ? sprintf 'U+%04X', $char
                                                     : sprintf 'U-%08X', $char),
                         index => - - $-[0],
                         level => 'm');
    }
  }
} # _check_data

sub _check_attr_bidi ($$) {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  my @expected;
  my $onerror = $GetNestedOnError->($self->onerror, $attr);

  my $line = 1;
  my $col_offset = -1;
  while ($value =~ /([\x{202A}-\x{202E}\x{2066}-\x{2069}\x0A]|\x0D\x0A?)/g) {
    my $c = $1;
    if ($c eq "\x{202A}" or $c eq "\x{202B}" or # LRE / RLE
        $c eq "\x{202D}" or $c eq "\x{202E}") { # LRO / RLO
      unshift @expected, "\x{202C}";
    } elsif ($c eq "\x{2066}" or $c eq "\x{2067}" or
             $c eq "\x{2068}") { # LRI / RLI / FSI
      unshift @expected, "\x{2069}";
    } elsif ($c eq "\x{202C}" or $c eq "\x{2069}") { # PDF / PDI
      if (@expected and $expected[0] eq $c) {
        shift @expected;
      } else {
        $onerror->(type => 'bidi:stray pop',
                   value => $c eq "\x{202C}" ? "PDF" : "PDI",
                   line => $line,
                   column => $-[0] - $col_offset,
                   level => 'm');
      }
    } elsif ($c eq "\x0A" or $c eq "\x0D\x0A" or $c eq "\x0D") {
      $line++;
      $col_offset = $+[0] - 1;
    }
  }
  if (@expected) {
    $onerror->(type => 'bidi:no pop',
               text => (join '', map { $_ eq "\x{202C}" ? "&#x202C;" : "&#x2069;" } @expected),
               line => $line,
               column => (length $value) - $col_offset,
               level => 'm');
  }
} # _check_attr_bidi

# XXX bidi check for element contents

## ------ Attribute conformance checkers ------

my $CheckerByType = {};
my $NamespacedAttrChecker = {};
my $ElementAttrChecker = {};
my $ItemValueChecker = {};

sub _check_element_attrs ($$$;%) {
  my ($self, $item, $element_state, %args) = @_;
  my $el_ns = $item->{node}->namespace_uri;
  $el_ns = '' unless defined $el_ns;
  my $el_ln = $item->{node}->local_name;
  my $allow_dataset = $el_ns eq HTML_NS;
  my $is_embed = $el_ns eq HTML_NS && $el_ln eq 'embed';
  my $input_type;
  if ($el_ns eq HTML_NS && $el_ln eq 'input') {
    $input_type = $item->{node}->get_attribute_ns (undef, 'type');
    $input_type = 'text' unless defined $input_type;
    $input_type =~ tr/A-Z/a-z/;
    $input_type = 'text' unless $_Defs->{elements}
        ->{'http://www.w3.org/1999/xhtml'}->{input}->{attrs}
        ->{''}->{type}->{enumerated}->{$input_type}->{conforming};
  }
  for my $attr (@{$item->{node}->attributes}) {
    my $attr_ns = $attr->namespace_uri;
    $attr_ns = '' if not defined $attr_ns;
    my $attr_ln = $attr->local_name;

    my $prefix = $attr->prefix;
    if (not defined $prefix) {
      if ($attr_ns ne '' and
          not ($attr_ns eq XMLNS_NS and $attr_ln eq 'xmlns')) {
        $self->{onerror}->(node => $attr,
                           type => 'nsattr has no prefix',
                           level => 'w');
      }

      # XXX warn xmlns="" in no namespace
    } elsif ($prefix eq 'xml') {
      if ($attr_ns ne XML_NS) {
        $self->{onerror}->(node => $attr,
                           type => 'Reserved Prefixes and Namespace Names:Prefix',
                           text => $prefix,
                           level => 'w');
      }
    } elsif ($prefix eq 'xmlns') {
      if ($attr_ns ne XMLNS_NS) {
        $self->{onerror}->(node => $attr,
                           type => 'Reserved Prefixes and Namespace Names:Prefix',
                           text => $prefix,
                           level => 'w');
      }
    }

    ## $el_ns and $el_ln can be |*| but no problem.
    my $checker =
        $ElementAttrChecker->{$el_ns}->{$el_ln}->{$attr_ns}->{$attr_ln} ||
        $ElementAttrChecker->{$el_ns}->{'*'}->{$attr_ns}->{$attr_ln} ||
        $NamespacedAttrChecker->{$attr_ns}->{$attr_ln} ||
        $NamespacedAttrChecker->{$attr_ns}->{''};
    my $attr_def = $_Defs->{elements}->{$el_ns}->{$el_ln}->{attrs}->{$attr_ns}->{$attr_ln} ||
        $_Defs->{elements}->{$el_ns}->{'*'}->{attrs}->{$attr_ns}->{$attr_ln} ||
        $_Defs->{elements}->{'*'}->{'*'}->{attrs}->{$attr_ns}->{$attr_ln};
    my $conforming = $attr_def->{conforming};
    my $status = $attr_def->{status} || '';
    if ($allow_dataset and
        $attr_ns eq '' and
        $attr_ln =~ /^data-\p{InXMLNCNameChar10}+\z/ and
        $attr_ln !~ /[A-Z]/) {
      ## |data-*=""| - XML-compatible + no uppercase letter
      $checker = $CheckerByType->{any};
      $conforming = 1;
      $status = 'REC';
    } elsif (defined $input_type and
             $attr_ns eq '' and
             keys %{$_Defs->{input}->{attrs}->{$attr_ln} or {}} and
             not $_Defs->{input}->{attrs}->{$attr_ln}->{$input_type}) {
      $checker = sub {
        $self->{onerror}->(node => $_[1],
                           type => 'input attr not applicable',
                           text => $input_type,
                           level => 'm');
      };
    } elsif ($attr_ns eq '') {
      # XXX
      $checker = $args{element_specific_checker}->{$attr_ln} || $checker;
    } elsif ($attr_ns eq XMLNS_NS) { # xmlns="", xmlns:*=""
      $conforming = 1;
      $status = 'REC';
    }
    my $value_type = $attr_def->{value_type} || '';
    $checker ||= $CheckerByType->{$value_type};
    if ($is_embed and
        $attr_ns eq '' and
        $attr_ln !~ /^xml/ and
        $attr_ln !~ /[A-Z]/ and
        $attr_ln =~ /\A\p{InXML_NCNameStartChar10}\p{InXMLNCNameChar10}*\z/) {
      ## XML-compatible + no uppercase letter
      $checker ||= $CheckerByType->{any};
      $conforming = 1;
      $status = 'REC';
    }
    $checker->($self, $attr, $item, $element_state, $attr_def) if $checker;

    if ($conforming or $attr_def->{obsolete_but_conforming}) {
      unless ($checker) {
        ## According to the attribute list, this attribute is
        ## conforming.  However, current version of the validator does
        ## not support the attribute.  The conformance is unknown.
        $self->{onerror}->(node => $attr,
                           type => 'unknown attribute', level => 'u');
      }
      if ($status eq 'REC' or $status eq 'CR' or $status eq 'LC') {
        #
      } else {
        ## The attribute is conforming, but is in earlier stage such
        ## that it should not be used without caution.
        $self->{onerror}->(node => $attr,
                           type => 'status:wd:attr', level => 'i')
      }
    } else {
      if ($_Defs->{namespaces}->{$el_ns}->{supported} or
          $_Defs->{namespaces}->{$attr_ns}->{supported}) {
        ## "Authors must not use elements, attributes, or attribute
        ## values that are not permitted by this specification or
        ## other applicable specifications" [HTML]
        if ($attr_ns eq '' and
            $attr_ln eq 'generator-unable-to-provide-required-alt' and
            $el_ns eq HTML_NS and
            $el_ln eq 'img') {
          #
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'attribute not defined',
                             level => 'm');
        }
      }
    }

    $self->_check_data ($attr, 'value');
  } # $attr
} # _check_element_attrs

$CheckerByType->{any} = sub {};
$CheckerByType->{text} = sub {};
$ItemValueChecker->{text} = sub {};

## Non-empty text
$CheckerByType->{'non-empty'} =
$CheckerByType->{'non-empty text'} = sub {
  my ($self, $attr) = @_;
  if ($attr->value eq '') {
    $self->{onerror}->(node => $attr,
                       type => 'empty attribute value',
                       level => 'm');
  }
}; # non-empty / non-empty text

## Boolean attribute [HTML]
$CheckerByType->{boolean} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{onerror}->(node => $attr,
                     type => 'boolean:invalid',
                     level => 'm')
      unless $value eq '' or $value eq $attr->local_name;
}; # boolean

$ElementAttrChecker->{(HTML_NS)}->{img}->{''}->{ismap} = sub {
  my ($self, $attr) = @_;
  $self->{onerror}->(node => $attr,
                     type => 'attribute not allowed:ismap',
                     level => 'm')
      unless $self->{flag}->{in_a_href};

  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{onerror}->(node => $attr,
                     type => 'boolean:invalid',
                     level => 'm')
      unless $value eq '' or $value eq 'ismap';
}; # <a ismap="">

## Enumerated attribute [HTML]
$CheckerByType->{enumerated} = sub {
  my ($self, $attr, undef, undef, $def) = @_;
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  if ($def->{enumerated}->{$value} and not $value =~ /^#/) {
    if ($def->{enumerated}->{$value}->{conforming}) {
      return;
    } elsif ($def->{enumerated}->{$value}->{non_conforming}) {
      $self->{onerror}->(node => $attr, type => 'enumerated:non-conforming',
                         level => 'm');
      return;
    }
  }
  $self->{onerror}->(node => $attr, type => 'enumerated:invalid',
                     level => 'm');
}; # enumerated

## Integer [HTML]
$CheckerByType->{integer} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value =~ /\A-?[0-9]+\z/) {
    #
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'integer:syntax error',
                       level => 'm');
  }
}; # integer
$ItemValueChecker->{integer} = sub {
  my ($self, $value, $node) = @_;
  if ($value =~ /\A-?[0-9]+\z/) {
    #
  } else {
    $self->{onerror}->(node => $node,
                       type => 'integer:syntax error',
                       value => $value,
                       level => 'm');
  }
}; # integer

## Non-negative integer [HTML]
$CheckerByType->{'non-negative integer'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value =~ /\A[0-9]+\z/) {
    #
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'nninteger:syntax error',
                       level => 'm');
  }
}; # non-negative integer
$ItemValueChecker->{'non-negative integer'} = sub {
  my ($self, $value, $node) = @_;
  if ($value =~ /\A[0-9]+\z/) {
    #
  } else {
    $self->{onerror}->(node => $node,
                       type => 'nninteger:syntax error',
                       value => $value,
                       level => 'm');
  }
}; # non-negative integer

## Non-negative integer greater than zero [HTML]
$CheckerByType->{'non-negative integer greater than zero'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value =~ /\A[0-9]+\z/) {
    if ($value > 0) {
      #
    } else {
      $self->{onerror}->(node => $attr, type => 'nninteger:zero',
                         level => 'm');
    }
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'nninteger:syntax error',
                       level => 'm');
  }
}; # non-negative integer greater than zero

## Dimension value [OBSVOCAB]
$CheckerByType->{'dimension value'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  unless ($value =~ /\A[0-9]+%?\z/) {
    $self->{onerror}->(node => $attr, type => 'length:syntax error',
                       level => 'm');
  }
}; # dimension value

## List of dimensions [OBSVOCAB]
$CheckerByType->{'list of dimensions'} = sub {
  my ($self, $attr) = @_;
  for my $ml (split /,/, $attr->value, -1) {
    $ml =~ s/\A[\x09\x0A\x0C\x0D\x20]+//;
    $ml =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;
    unless ($ml =~ /\A(?>[0-9]+[%*]?|\*)\z/) {
      $self->{onerror}->(node => $attr,
                         value => $ml,
                         type => 'multilength:syntax error',
                         level => 'm');
    }
  }
}; # list of dimensions

## Floating-point number [HTML]
$CheckerByType->{'floating-point number'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value =~ /\A
    (-? (?> [0-9]+ (?>(?:\.[0-9]+))? | \.[0-9]+))
    (?>[Ee] ([+-]?[0-9]+) )?
  \z/x) {
    my $num = 0+$1;
    $num *= 10 ** ($2 + 0) if $2;
    $element_state->{number_value}->{$attr->name} = $num;
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'float:syntax error',
                       level => 'm');
  }
}; # floating-point number
$ItemValueChecker->{'floating-point number'} = sub {
  my ($self, $value, $node) = @_;
  if ($value =~ /\A
    (-? (?> [0-9]+ (?>(?:\.[0-9]+))? | \.[0-9]+))
    (?>[Ee] ([+-]?[0-9]+) )?
  \z/x) {
    my $num = 0+$1;
    $num *= 10 ** ($2 + 0) if $2;
  } else {
    $self->{onerror}->(node => $node,
                       type => 'float:syntax error',
                       value => $value,
                       level => 'm');
  }
}; # floating-point number

$ElementAttrChecker->{(HTML_NS)}->{input}->{''}->{step} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value =~ /\A
    (-? (?> [0-9]+ (?>(\.[0-9]+))? | \.[0-9]+))
    (?>[Ee] ([+-]?[0-9]+) )?
  \z/x) {
    my $num = 0+$1;
    $num *= 10 ** ($2 + 0) if $2;
    unless ($num > 0) {
      $self->{onerror}->(node => $attr,
                         type => 'float:out of range',
                         level => 'm');
    }
  } elsif ($value =~ /\A[Aa][Nn][Yy]\z/) { ## |any| ASCII case-insensitive
    #
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'float:syntax error',
                       level => 'm');
  }
}; # <input step="">

## Browsing context name [HTML]
$CheckerByType->{'browsing context name'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value =~ /^_/) {
    $self->{onerror}->(node => $attr,
                       type => 'window name:reserved',
                       level => 'm');
  } elsif (length $value) {
    #
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'window name:empty',
                       level => 'm');
  }
}; # browsing context name

## Browsing context name or keyword [HTML]
$CheckerByType->{'browsing context name or keyword'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value =~ /^_/) {
    $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    unless ({
      _blank => 1,_self => 1, _parent => 1, _top => 1,
    }->{$value}) {
      $self->{onerror}->(node => $attr,
                         type => 'window name:reserved',
                         value => $value,
                         level => 'm');
    }
  } elsif (length $value) {
    #
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'window name:empty',
                       level => 'm');
  }
}; # browsing context name or keyword

## Legacy color value [OBSVOCAB]
$CheckerByType->{'legacy color value'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;

  if ($attr->value =~ /\A\x23[0-9A-Fa-f]{6}\z/) {
    #
  } else {
    require Web::CSS::Colors;

    $value =~ tr/A-Z/a-z/;
    if ($Web::CSS::Colors::X11Colors->{$value}) {
      #
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'color:syntax error',
                         level => 'm');
    }
  }
}; # legacy color value

## MIME type [HTML]
$CheckerByType->{'MIME type'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;

  require Web::MIME::Type;
  my $onerror = sub {
    $self->{onerror}->(@_, node => $attr);
  };

  ## Syntax-level validation
  my $type = Web::MIME::Type->parse_web_mime_type ($value, $onerror);

  ## Vocabulary-level validation
  if ($type) {
    $type->validate ($onerror);
  }

  return $type; # or undef
}; # MIME type

$ElementAttrChecker->{(HTML_NS)}->{style}->{''}->{type} = sub {
  my ($self, $attr, $item, $element_state) = @_;

  require Web::MIME::Type;
  my $onerror = sub { $self->{onerror}->(@_, node => $attr) };
  my $type = Web::MIME::Type->parse_web_mime_type
      ($attr->value, $onerror);

  if ($type) {
    $type->validate ($onerror);

    $self->{onerror}->(node => $attr,
                       type => 'IMT:not styling lang',
                       level => 'm')
        unless $type->is_styling_lang;

    $self->{onerror}->(node => $attr,
                       value => 'charset',
                       type => 'IMT:parameter not allowed',
                       level => 'm')
        if defined $type->param ('charset');
  }
  $element_state->{content_type} = $type;
}; # <style type="">

$ElementAttrChecker->{(HTML_NS)}->{script}->{''}->{type} = sub {
  my ($self, $attr, $item, $element_state) = @_;

  require Web::MIME::Type;
  my $onerror = sub { $self->{onerror}->(@_, node => $attr) };
  my $type = Web::MIME::Type->parse_web_mime_type
      ($attr->value, $onerror);

  if ($type) {
    $type->validate ($onerror);

    $self->{onerror}->(node => $attr,
                       value => 'charset',
                       type => 'IMT:parameter not allowed',
                       level => 'm')
        if defined $type->param ('charset');
  }
  $element_state->{content_type} = $type;
}; # <script type="">

## Language tag [HTML] [BCP47]
$CheckerByType->{'language tag'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  require Web::LangTag;
  my $lang = Web::LangTag->new;
  $lang->onerror (sub {
    $self->{onerror}->(@_, node => $attr);
  });
  my $parsed = $lang->parse_tag ($value);
  $lang->check_parsed_tag ($parsed);
}; # language tag
$ItemValueChecker->{'language tag'} = sub {
  my ($self, $value, $node) = @_;
  require Web::LangTag;
  my $lang = Web::LangTag->new;
  $lang->onerror (sub {
    $self->{onerror}->(value => $value, @_, node => $node);
  });
  my $parsed = $lang->parse_tag ($value);
  $lang->check_parsed_tag ($parsed);
}; # language tag

## BCP 47 language tag or the empty string [HTML] [BCP47]
$CheckerByType->{'language tag or empty'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value ne '') {
    require Web::LangTag;
    my $lang = Web::LangTag->new;
    $lang->onerror (sub {
      $self->{onerror}->(@_, node => $attr);
    });
    my $parsed = $lang->parse_tag ($value);
    $lang->check_parsed_tag ($parsed);
  }
}; # language tag or empty

$CheckerByType->{'character encoding label'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value =~ /\A[Uu][Tt][Ff]-8\z/) { # "utf-8" ASCII case-insensitive.
    #
  } else {
    require Web::Encoding;
    if (Web::Encoding::is_encoding_label ($value)) {
      $self->{onerror}->(node => $attr,
                         type => 'non-utf-8 character encoding',
                         level => 'm'); # [ENCODING]
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'not encoding label',
                         level => 'm');
    }
  }
}; # character encoding label

$ElementAttrChecker->{(HTML_NS)}->{form}->{''}->{'accept-charset'} = sub {
  my ($self, $attr) = @_;

  ## An ordered set of unique space-separated tokens.
  my @value = grep { length $_ } split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value, -1;
  my %word;
  for my $charset (@value) {
    $charset =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($word{$charset}) {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $charset,
                         level => 'm');
    } else {
      $word{$charset} = 1;
      require Web::Encoding;
      my $name = Web::Encoding::encoding_label_to_name ($charset);
      if (defined $name) {
        unless (Web::Encoding::is_ascii_compat_encoding_name ($name)) {
          $self->{onerror}->(node => $attr,
                             type => 'charset:not ascii compat',
                             value => $charset,
                             level => 'm');
        }
        if ($name ne 'utf-8') {
          $self->{onerror}->(node => $attr,
                             type => 'non-utf-8 character encoding',
                             value => $charset,
                             level => 'm'); # [ENCODING]
        }
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'not encoding label',
                           value => $charset,
                           level => 'm');
      }
    }
  }
}; # <form accept-charset="">

## URL potentially surrounded by spaces [HTML]
$CheckerByType->{'URL potentially surrounded by spaces'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($value);
  $chk->onerror (sub {
    $self->{onerror}->(@_, node => $attr);
  });
  $chk->check_iri_reference; # XXX URL
  $self->{has_uri_attr} = 1;
}; # URL potentially surrounded by spaces

## Non-empty URL potentially surrounded by spaces [HTML]
$CheckerByType->{'non-empty URL potentially surrounded by spaces'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value eq '') {
    $self->{onerror}->(type => 'url:empty',
                       node => $attr,
                       level => 'm');
  } else {
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($value);
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $attr);
    });
    $chk->check_iri_reference; # XXX URL
  }
  $self->{has_uri_attr} = 1;
}; # non-empty URL potentially surrounded by spaces [HTML]

$ElementAttrChecker->{(HTML_NS)}->{html}->{''}->{manifest} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value eq '') {
    $self->{onerror}->(type => 'url:empty',
                       node => $attr,
                       level => 'm');
  } else {
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($value);
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $attr);
    });
    $chk->check_iri_reference; # XXX URL
  }
  ## Same as "non-empty URL potentially surrounded by spaces" checker
  ## except for:
  #$self->{has_uri_attr} = 1;
}; # <html manifest="">

$ElementAttrChecker->{(HTML_NS)}->{a}->{''}->{ping} =
$ElementAttrChecker->{(HTML_NS)}->{area}->{''}->{ping} =
$ElementAttrChecker->{(HTML_NS)}->{head}->{''}->{profile} =
$ElementAttrChecker->{(HTML_NS)}->{object}->{''}->{archive} = sub {
  my ($self, $attr) = @_;

  ## Set of space-separated tokens [HTML]
  my %word;
  for my $word (grep { length $_ }
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }

  for my $value (keys %word) {
    ## Non-empty URL [HTML]
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($value);
    $chk->onerror (sub {
      $self->{onerror}->(value => $value, @_, node => $attr);
    });
    # XXX For <object archive="">, base URL is <object codebase="">
    $chk->check_iri_reference; # XXX URL
  }

  $self->{has_uri_attr} = 1 if $attr->local_name ne 'profile';
}; # <a ping=""> <area ping=""> <head profile=""> <object archive="">

$ElementAttrChecker->{(HTML_NS)}->{applet}->{''}->{archive} = sub {
  my ($self, $attr) = @_;

  ## A set of comma-separated tokens [HTML]
  my $value = $attr->value;
  my @value = length $value ? split /,/, $value, -1 : ();

  require Web::URL::Checker;
  for my $v (@value) {
    $v =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
    $v =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;

    if ($v eq '') {
      $self->{onerror}->(type => 'url:empty',
                         node => $attr,
                         level => 'm');
    } else {
      ## Non-empty URL
      my $chk = Web::URL::Checker->new_from_string ($v);
      $chk->onerror (sub {
        $self->{onerror}->(value => $v, @_, node => $attr);
      });
      # XXX base URL is <applet codebase="">
      $chk->check_iri_reference; # XXX URL
    }
  }

  $self->{has_uri_attr} = 1;
}; # <applet archive="">

my $ValidEmailAddress;
{
  my $atext_dot = qr[[A-Za-z0-9!#\$%&'*+/=?^_`{|}~.-]];
  my $label = qr{[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?};
  $ValidEmailAddress = qr/$atext_dot+\@$label(?>\.$label)+/o;
}

## E-mail address [HTML]
$CheckerByType->{'e-mail address'} = sub {
  my ($self, $attr) = @_;
  $self->{onerror}->(node => $attr,
                     type => 'email:syntax error',
                     level => 'm')
      unless $attr->value =~ qr/\A$ValidEmailAddress\z/o;
}; # e-mail address

## E-mail address list [HTML]
$CheckerByType->{'e-mail address list'} = sub {
  my ($self, $attr) = @_;
  ## A set of comma-separated tokens.
  my @addr = split /,/, $attr->value, -1;
  for (@addr) {
    s/\A[\x09\x0A\x0C\x0D\x20]+//; # space characters
    s/[\x09\x0A\x0C\x0D\x20]\z//; # space characters
    $self->{onerror}->(node => $attr,
                       type => 'email:syntax error',
                       value => $_,
                       level => 'm')
        unless /\A$ValidEmailAddress\z/o;
  }
}; # e-mail address list

## Event handler content attribute [HTML]
$CheckerByType->{'event handler'} = sub {
  my ($self, $attr) = @_;
  # XXX MUST be JavaScript FunctionBody
  $self->{onerror}->(node => $attr,
                     type => 'event handler',
                     level => 'u');
}; # event handler

## Web Applications 1.0 "Valid MIME type"
our $MIMETypeChecker = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;

  require Web::MIME::Type;
  my $onerror = sub {
    $self->{onerror}->(@_, node => $attr);
  };

  ## Syntax-level validation
  my $type = Web::MIME::Type->parse_web_mime_type ($value, $onerror);

  ## Vocabulary-level validation
  if ($type) {
    $type->validate ($onerror);
  }

  return $type; # or undef
}; # $MIMETypeChecker

## ------ ID references ------

## ID reference
$CheckerByType->{idref} = sub {
  my ($self, $attr, undef, undef, $def) = @_;
  push @{$self->{idref}}, [$def->{id_type} || 'any', $attr->value => $attr];
}; # ID reference

$ElementAttrChecker->{(HTML_NS)}->{menuitem}->{''}->{command} = sub {
  my ($self, $attr) = @_;
#  push @{$self->{idref}}, ['command', $attr->value, $attr]; # XXX not implemented yet
}; # <menuitem command="">

## XXX Warn violation to control-dependent restrictions.  For example,
## |<input type=url maxlength=10 list=a> <datalist id=a><option
## value=nonurlandtoolong></datalist>| should be warned.

## IDREFS to any element
$ElementAttrChecker->{(HTML_NS)}->{output}->{''}->{for} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{itemref} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-controls'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-controls'} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-describedby'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-describedby'} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-flowto'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-flowto'} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-labelledby'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-labelledby'} =
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-owns'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-owns'} = sub {
  my ($self, $attr) = @_;
  ## Unordered set of unique space-separated tokens.
  my %word;
  for my $word (grep {length $_}
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
      push @{$self->{idref}}, ['any', $word, $attr];
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }
}; # IDREFS

## Hash-name reference to a |map| element [HTML]
$CheckerByType->{'hash-name reference'} = sub {
  my ($self, $attr) = @_;
  ## MUST be a valid hash-name reference to a |map| element.
  my $value = $attr->value;
  if ($value =~ s/^#//) {
    ## NOTE: |usemap="#"| is conforming, though it identifies no |map| element
    ## according to the "rules for parsing a hash-name reference" algorithm.
    ## The document is non-conforming anyway, since |<map name="">| (empty
    ## name) is non-conforming.
    push @{$self->{usemap}}, [$value => $attr];
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'hashref:syntax error',
                       level => 'm');
  }
  ## NOTE: Space characters in hash-name references are conforming.
  ## ISSUE: UA algorithm for matching is case-insensitive; IDs only different in cases should be reported
}; # hash-name reference

## Hash-ID reference to an |object| element [OBSVOCAB]
$CheckerByType->{'hash-ID reference'} = sub {
  my ($self, $attr) = @_;
  
  my $value = $attr->value;
  if ($value =~ s/^\x23(?=.)//s) {
    push @{$self->{idref}}, ['object', $value, $attr];
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'hashref:syntax error',
                       level => 'm');
  }
}; # hash-ID reference

## ID reference or hash-ID reference to an |object| element [OBSVOCAB]
$CheckerByType->{'idref or hash-ID reference'} = sub {
  my ($self, $attr) = @_;
  
  my $value = $attr->value;
  if ($value =~ s/^\x23?(?=.)//s) {
    push @{$self->{idref}}, ['object', $value, $attr];
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'hashref:syntax error',
                       level => 'm');
  }
}; # ID reference or hash-ID reference

## ------ XML and XML Namespaces ------

## XML Namespaces
##
## These requirements from XML Namespaces specification are only
## syntactical or only relevant to DTDs so they are checked by parser
## and/or DTD validator, not by this validator:
##
##   - Prefix MUST be declared.
##   - Attributes MUST be unique.
##   - Names in DTD and names in some typed attribute values MUST be NCName.
##
## Use of reserved namespace name/prefix by $node->prefix and/or
## $node->namespace_uri are only warnings, not errors, as there are no
## conformance requirement for DOM representation in any
## specification.  (In fact most combinations of them are not even
## exist in standard DOM world.)

$NamespacedAttrChecker->{(XML_NS)}->{''} = sub {
  my ($self, $attr) = @_;
  ## "Attribute not defined" error is thrown by other place.
  
  my $prefix = $attr->prefix;
  if (defined $prefix and not $prefix eq 'xml') {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Name',
                       text => 'http://www.w3.org/XML/1998/namespace',
                       level => 'w');
    ## "$prefix is undef" error is thrown by other place
  }
}; # xml:*=""

$NamespacedAttrChecker->{(XML_NS)}->{space} = sub {
  my ($self, $attr) = @_;
  
  my $prefix = $attr->prefix;
  if (defined $prefix and not $prefix eq 'xml') {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Name',
                       text => 'http://www.w3.org/XML/1998/namespace',
                       level => 'w');
    ## "$prefix is undef" error is thrown by other place
  }

  my $oe = $attr->owner_element;
  if ($oe and
      ($oe->namespace_uri || '') eq HTML_NS and
      $oe->owner_document->manakai_is_html) {
    $self->{onerror}->(node => $attr,
                       type => 'in HTML:xml:space',
                       level => 'w');
  }

  my $value = $attr->value;
  if ($value eq 'default' or $value eq 'preserve') {
    #
  } else {
    ## Note that S before or after value is not allowed, as
    ## $attr->value is normalized value.  DTD validation should be
    ## performed before the conformance checking.
    $self->{onerror}->(node => $attr,
                       type => 'invalid attribute value',
                       level => 'm');
  }
}; # xml:space

$NamespacedAttrChecker->{(XML_NS)}->{lang} = sub {
  my ($self, $attr) = @_;
  
  my $prefix = $attr->prefix;
  if (defined $prefix and not $prefix eq 'xml') {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Name',
                       text => 'http://www.w3.org/XML/1998/namespace',
                       level => 'w');
    ## "$prefix is undef" error is thrown by other place
  }

  ## BCP 47 language tag or the empty string [XML] [BCP47]
  my $value = $attr->value;
  if ($value ne '') {
    require Web::LangTag;
    my $lang = Web::LangTag->new;
    $lang->onerror (sub {
      $self->{onerror}->(@_, node => $attr);
    });
    my $parsed = $lang->parse_tag ($value);
    $lang->check_parsed_tag ($parsed);
  }

  my $nsuri = $attr->owner_element->namespace_uri;
  if (defined $nsuri and $nsuri eq HTML_NS) {
    my $lang_attr = $attr->owner_element->get_attribute_node_ns
        (undef, 'lang');
    if ($lang_attr) {
      my $lang_attr_value = $lang_attr->value;
      $lang_attr_value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
      my $value = $value;
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
      if ($lang_attr_value ne $value) {
        ## NOTE: HTML5 Section "The |lang| and |xml:lang| attributes"
        $self->{onerror}->(node => $attr,
                           type => 'xml:lang ne lang',
                           level => 'm');
      }
    }

    if ($attr->owner_document->manakai_is_html) { # MUST NOT
      $self->{onerror}->(node => $attr,
                         type => 'in HTML:xml:lang',
                         level => 'm');
    }
  }
}; # xml:lang=""

$NamespacedAttrChecker->{(XML_NS)}->{base} = sub {
  my ($self, $attr) = @_;

  ## XXX xml:base support will be likely removed from the Web.
  ## XXX but maybe we can't drop it entirely to not break feed support.

  my $value = $attr->value;
  if ($value =~ /[^\x{0000}-\x{10FFFF}]/) { ## ISSUE: Should we disallow noncharacters?
    $self->{onerror}->(node => $attr,
                       type => 'invalid attribute value',
                       level => 'm', # fact
                      );
  }
  ## NOTE: Conformance to URI standard is not checked since there is
  ## no author requirement on conformance in the XML Base
  ## specification.

  ## XXX If this attribute will not be removed: The attribute value
  ## must be URL.  It does not defined as URLs for the purpose of
  ## <base href=""> validation.  (Note that even if the attribute is
  ## dropped for browsers, we have to continue to support it for
  ## feeds.)
}; # xml:base=""

$NamespacedAttrChecker->{(XMLNS_NS)}->{''} = sub {
  my ($self, $attr) = @_;
  my $ln = $attr->local_name;

  my $prefix = $attr->prefix;
  if ($ln eq 'xmlns') { # xmlns=""
    if (not defined $prefix) {
      #
    } elsif ($prefix eq 'xmlns') {
      ## The prefix |xmlns| MUST NOT be declared.
      $self->{onerror}->(node => $attr,
                         type => 'Reserved Prefixes and Namespace Names:Prefix',
                         text => 'xmlns',
                         level => 'm');
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'Reserved Prefixes and Namespace Names:Name',
                         text => 'http://www.w3.org/2000/xmlns/',
                         level => 'w');
    }
  } else { # xmlns:*=""
    if (defined $prefix and not $prefix eq 'xmlns') {
      $self->{onerror}->(node => $attr,
                         type => 'Reserved Prefixes and Namespace Names:Name',
                         text => 'http://www.w3.org/2000/xmlns/',
                         level => 'w');
      ## "$prefix is undef" error is thrown by other place
    }
  }

  my $value = $attr->value;
  if ($value eq '') {
    unless ($ln eq 'xmlns') { # xmlns:*="" (empty value)
      ## <http://www.w3.org/TR/xml-names/#nsc-NoPrefixUndecl>.
      $self->{onerror}->(node => $attr,
                         type => 'xmlns:* empty',
                         level => 'm');
    }
  } else {
    ## Non-empty URL [HTML]
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($value);
    $chk->onerror (sub {
      $self->{onerror}->(value => $value, @_, node => $attr);
    });
    $chk->check_iri_reference; # XXX URL

    ## XXX
    ## Use of relative URLs are deprecated.

    ## Namespace URL SHOULD be unique and persistent.  But this can't
    ## be tested.
  }

  if ($value eq XML_NS and $ln ne 'xml') {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Name',
                       text => $value,
                       level => 'm');
  } elsif ($value eq XMLNS_NS) {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Name',
                       text => $value,
                       level => 'm');
  }
  if ($ln eq 'xml' and $value ne XML_NS) {
    $self->{onerror}->(node => $attr,
                       type => 'Reserved Prefixes and Namespace Names:Prefix',
                       text => $ln,
                       level => 'm');
  }
}; # xmlns="", xmlns:*=""

## ------ ARIA ------

my $NodeIsHyperlink = {};

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{role} = sub { };
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{role} = sub { };

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-label'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-label'} = sub {
  my ($self, $attr) = @_;
  $self->{onerror}->(node => $attr,
                     type => 'aria:label',
                     level => 'w');
}; # aria-label=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-dropeffect'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-dropeffect'} = sub {
  my ($self, $attr) = @_;
  ## Unordered set of unique space-separated tokens.
  my %word;
  for my $word (grep {length $_}
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
      $self->{onerror}->(node => $attr,
                         type => 'word not allowed', value => $word,
                         level => 'm')
          unless $_Defs->{elements}->{(HTML_NS)}->{'*'}->{attrs}->{''}->{'aria-dropeffect'}->{keywords}->{$word}->{conforming};
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }
}; # aria-dropeffect=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'aria-relevant'} =
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{'aria-relevant'} = sub {
  my ($self, $attr) = @_;
  ## Unordered set of unique space-separated tokens.
  my %word;
  for my $word (grep {length $_}
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
      $self->{onerror}->(node => $attr,
                         type => 'word not allowed', value => $word,
                         level => 'm')
          unless $_Defs->{elements}->{(HTML_NS)}->{'*'}->{attrs}->{''}->{'aria-relevant'}->{keywords}->{$word}->{conforming};
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }
}; # aria-relevant=""

sub _validate_aria ($$) {
  my ($self, $target_nodes) = @_;

  my @relevant;

  my $descendants = {};
  my $aria_owned_nodes = {};
  my $node_context = {};

  my %is_root = (map { refaddr $_ => 1 } @$target_nodes);
  my %owned_id;
  my @node = (map { [$_, [], {}] } @$target_nodes);
  while (@node) {
    my ($node, $parents, $ancestor_state) = @{shift @node};
    if ($node->node_type == 1) { # ELEMENT_NODE
      my $node_ref = refaddr $node;
      $descendants->{refaddr $_}->{$node_ref} = $node for @$parents;

      my $ns = $node->namespace_uri || '';
      my $ln = $node->local_name;
      if ($ns eq HTML_NS or $ns eq SVG_NS) {
        if ($_Defs->{elements}->{$ns}->{$ln}->{aria} or
            $ln eq 'input' or
            $node->has_attribute_ns (undef, 'role')) {
          push @relevant, $node;
        } else {
          for (@{$node->attributes}) {
            if ($_->local_name =~ /^aria-/) {
              push @relevant, $node;
              last;
            }
          }
        }

        my $owns = $node->get_attribute_node_ns (undef, 'aria-owns');
        if (defined $owns) {
          $self->{onerror}->(node => $owns,
                             type => 'aria:owns',
                             level => 'w');

          my @node;
          for (grep { length } split /[\x09\x0A\x0C\x0D\x20]+/, $owns->value) {
            my $attr = ($self->{id}->{$_} or [])->[0] or next;
            push @node, $attr->owner_element;
            if ($owned_id{$_}) {
              $self->{onerror}->(node => $owns,
                                 type => 'aria:owns:duplicate idref',
                                 value => $_,
                                 level => 'm');
            } else {
              $owned_id{$_} = [$node => $node[-1]];
            }
          }
          $aria_owned_nodes->{$node_ref} = {map { (refaddr $_) => $_ } @node};
        }
      } # $ns
      $node_context->{$node_ref} = $ancestor_state;

      my $state = {in_hgroup => $ancestor_state->{in_hgroup},
                   in_datalist => $ancestor_state->{in_datalist}};
      if ($ns eq HTML_NS) {
        if ($ln eq 'select') {
          $state->{in_select} = 1;
        } elsif ($ln eq 'optgroup') {
          $state->{in_select_optgroup} = 1
              if $ancestor_state->{in_select};
          $state->{in_disabled_optgroup} = 1
              if $node->has_attribute_ns (undef, 'disabled');
        } elsif ($ln eq 'hgroup') {
          $state->{in_hgroup} = 1;
        } elsif ($ln eq 'datalist') {
          $state->{in_datalist} = 1;
        } elsif ($ln eq 'ul' or $ln eq 'ol') {
          $state->{in_ulol} = 1;
        }
        $state->{is_inert} = 1
            if $ancestor_state->{is_inert} || $node->has_attribute_ns (undef, 'inert'); # XXX or inert by <dialog>
      }

      $parents = [@$parents, $node];
      unshift @node, map { [$_, $parents, $state] } @{$node->children};
    } else {
      unshift @node, map { [$_, $parents, $ancestor_state] } grep { $_->node_type == 1 } @{$node->child_nodes};
    }
  } # @node

  for my $id (keys %owned_id) {
    if ($descendants->{refaddr $owned_id{$id}->[0]}->{refaddr $owned_id{$id}->[1]}) {
      $self->{onerror}->(node => $owned_id{$id}->[0]->get_attribute_node_ns (undef, 'aria-owns'),
                         type => 'aria:owns:descendant is refed',
                         value => $id,
                         level => 'm');
    }
  }

  my $get_owned_nodes = sub {
    my $node = $_[0];
    my $nodes = {%{$descendants->{refaddr $node} or {}}};
    {
      my %parent = %{$aria_owned_nodes->{refaddr $node} or {}};
      $nodes = {%$nodes, %parent, map { %{$descendants->{$_} or {}} } keys %parent};
    }
    my $prev_keys = 0;
    my $new_keys = keys %$nodes;
    while ($prev_keys != $new_keys) {
      $prev_keys = $new_keys;
      my %parent = map { %{$aria_owned_nodes->{$_} or {}} } keys %$nodes;
      $nodes = {%$nodes, %parent, map { %{$descendants->{$_} or {}} } keys %parent};
      $new_keys = keys %$nodes;
    }
    return $nodes;
  }; # $get_owned_nodes

  my $node_to_roles = {};
  my $parent_is_presentation = {};
  for my $node (@relevant) {
    my $ns = $node->namespace_uri || '';
    my $ln = $node->local_name;

    my %role;
    my $role_attr = $node->get_attribute_node_ns (undef, 'role');
    if (defined $role_attr) {
      ## An ordered set of unique space-separated tokens.
      my @value = grep { length $_ }
          split /[\x09\x0A\x0C\x0D\x20]+/, $role_attr->value, -1;
      my %word;
      for my $token (@value) {
        if ($word{$token}) {
          $self->{onerror}->(node => $role_attr,
                             type => 'duplicate token', value => $token,
                             level => 'm');
        } else {
          $word{$token} = 1;
          my $def = $_Defs->{elements}->{(HTML_NS)}->{'*'}->{attrs}->{''}->{role};
          if ($def->{keywords}->{$token} and
              $def->{keywords}->{$token}->{conforming}) {
            $role{$token} = 'attr';
          } else {
            $self->{onerror}->(node => $role_attr,
                               type => 'aria:bad role', value => $token,
                               level => 'm');
          }
        }
      }
    } # role=""

    my $aria_defs = $_Defs->{elements}->{$ns}->{$ln}->{aria};
    if ($ns eq HTML_NS and $ln eq 'input') {
      $aria_defs = $_Defs->{input}->{aria}->{$node->type};
    }

    my $adef;
    if ($ns eq HTML_NS) {
      if ($ln eq 'img') {
        my $alt = $node->get_attribute_ns (undef, 'alt');
        if (defined $alt and not length $alt) {
          $adef = $aria_defs->{'empty-alt'};
        } else {
          $adef = $aria_defs->{'not-empty-alt'};
        }
      } elsif ($ln eq 'a' or $ln eq 'area') {
        $adef = $aria_defs->{'hyperlink'}
            if $node->has_attribute_ns (undef, 'href');
      } elsif ($ln eq 'link') {
        if ($NodeIsHyperlink->{refaddr $node}) {
          $adef = $aria_defs->{'hyperlink'};
        }
      } elsif ($ln eq 'option') {
        my $context = $node_context->{refaddr $node};
        $adef = $aria_defs->{'in-list'}
            if $context->{in_select} or
               $context->{in_select_optgroup} or
               ($context->{in_datalist} and
                not $node->has_attribute_ns (undef, 'disabled') and
                not $context->{in_disabled_optgroup} and
                not $node->value eq '');
      } elsif ($ln eq 'li') {
        $adef = $aria_defs->{'in-ulol'}
            if $node_context->{refaddr $node}->{in_ulol};
      } elsif ($ln eq 'menu') {
        $adef = $aria_defs->{$node->type}; # type=popup or toolbar
      } elsif ($ln =~ /\Ah[1-6]\z/) {
        $adef = $aria_defs->{'no-hgroup'}
            unless $node_context->{refaddr $node}->{in_hgroup};
      } elsif ($ln eq 'body' or $ln eq 'frameset') {
        $adef = $aria_defs->{'the-body'}
            if ($node->owner_document->body || '') eq $node;
      }
    }
    $adef ||= $aria_defs->{''};

    ## If role=presentation, its required children is also implicitly
    ## set to presentation.  Whether this is a right implementation of
    ## that requirement is unclear...
    if ($parent_is_presentation->{refaddr $node}) {
      $adef = {};
    }
    if ($role{presentation}) {
      $parent_is_presentation->{refaddr $_} = 1
          for ($node->children->to_list);
    }

    my $default_role = $adef->{default_role};
    if (defined $default_role and $default_role eq '#textbox-or-combobox') {
      LIST: {
        my $list = $node->get_attribute_ns (undef, 'list');
        if (defined $list and length $list) {
          my $attr = $self->{id}->{$list}->[0];
          if (defined $attr) {
            my $oe = $attr->owner_element;
            if (($oe->namespace_uri || '') eq HTML_NS and
                $oe->local_name eq 'datalist') {
              $default_role = 'combobox';
              last LIST;
            }
          }
        }
        $default_role = 'textbox';
      } # LIST
    }

    for my $role (keys %role) {
      my $conflict_error;
      if ($adef->{allowed_roles}) {
        unless ($adef->{allowed_roles}->{$role}) {
          if (defined $default_role and $default_role eq $role) {
            $self->{onerror}->(node => $role_attr,
                               type => 'aria:role:default role',
                               value => $role,
                               level => 'm');
            next;
          } else {
            $self->{onerror}->(node => $role_attr,
                               type => 'aria:role:conflict with semantics',
                               value => $role,
                               level => 'm');
            $conflict_error = 1;
          }
        }
      }

      my $preferred = $_Defs->{roles}->{$role}->{preferred};
      if ($preferred) {
        if ($preferred->{type} eq 'html-element' and
            $ns eq HTML_NS and
            $ln eq $preferred->{name}) {
          $self->{onerror}->(node => $role_attr,
                             type => 'aria:redundant role',
                             value => $role,
                             level => 'w')
              unless $conflict_error;
        } elsif ($preferred->{type} eq 'input' and
                 $ns eq HTML_NS and
                 $ln eq 'input' and
                 $node->type eq $preferred->{name}) {
          $self->{onerror}->(node => $role_attr,
                             type => 'aria:redundant role',
                             value => $role,
                             level => 'w')
              unless $conflict_error;
        } else {
          $self->{onerror}->(node => $role_attr,
                             type => 'aria:not preferred markup:' . $preferred->{type},
                             text => $preferred->{name} || $preferred->{scope}, # or undef
                             value => $role,
                             level => 'w')
              unless $role eq 'textbox' and $ns eq HTML_NS and $ln eq 'input';
        }
      }
    } # $role

    if (not keys %role and defined $default_role) {
      $role{$default_role} = 'implicit';
    }
    
    my %attr;
    for my $attr (@{$node->attributes}) {
      next if defined $attr->namespace_uri;
      my $attr_ln = $attr->local_name;
      next unless $attr_ln =~ /^aria-/;
      my $attr_def = $_Defs->{elements}->{$ns}->{'*'}->{attrs}->{''}->{$attr_ln};
      next unless $attr_def;
      $attr{$attr_ln} = $attr;
      
      my $allowed;
      if ($_Defs->{roles}->{roletype}->{attrs}->{$attr_ln}) {
        ## A global ARIA attribute
        $allowed = 1;
      } else {
        ## A non-global ARIA attribute
        for my $role (keys %role) {
          if ($_Defs->{roles}->{$role}->{attrs}->{$attr_ln}) {
            $allowed = 1;
            last;
          }
        }
      }

      if (not $allowed) {
        $self->{onerror}->(node => $attr,
                           type => 'aria:attr not allowed for role',
                           text => (join ' ', sort { $a cmp $b } keys %role),
                           level => 'm');
      } elsif ($adef->{attrs}->{$attr_ln} or
               ($attr_ln eq 'aria-hidden' and
                ($node->namespace_uri || '') eq HTML_NS and
                $node->has_attribute_ns (undef, 'hidden')) or
               ($attr_ln eq 'aria-disabled' and
                $node_context->{refaddr $node}->{is_inert})) {
        $self->{onerror}->(node => $attr,
                           type => 'aria:attr not allowed for element',
                           level => 'm');
      } elsif ($attr_ln eq 'aria-level' and
               ($node->namespace_uri || '') eq HTML_NS and
               {h1 => 1, h2 => 1, h3 => 1, h4 => 1, h5 => 1, h6 => 1,
                hgroup => 1}->{$node->local_name}) {
        $self->{onerror}->(node => $attr,
                           type => 'attribute not allowed',
                           level => 'w');
      } elsif ($attr_def->{preferred}) {
        if ($attr_def->{preferred}->{type} eq 'html-attr' and
            ($node->namespace_uri || '') eq HTML_NS) {
          if ($node->has_attribute_ns (undef, $attr_def->{preferred}->{name})) {
            $self->{onerror}->(node => $attr,
                               type => 'aria:redundant:html-attr',
                               text => $attr_def->{preferred}->{name},
                               level => 'w');
          } else {
            $self->{onerror}->(node => $attr,
                               type => 'aria:not preferred markup:html-attr',
                               text => $attr_def->{preferred}->{name},
                               level => 'w');
          }
        }
      }
    } # $attr

    for my $role (keys %role) {
      next if $role{$role} eq 'implicit';
      my $role_def = $_Defs->{roles}->{$role};
      for my $attr_ln (keys %{$role_def->{attrs} or {}}) {
        if ($role_def->{attrs}->{$attr_ln}->{must}) {
          $self->{onerror}->(node => $role_attr,
                             value => $role,
                             type => 'attribute missing',
                             text => $attr_ln,
                             level => 'm')
              unless defined $attr{$attr_ln};
        } elsif ($role_def->{attrs}->{$attr_ln}->{should}) {
          $self->{onerror}->(node => $role_attr,
                             value => $role,
                             type => 'attribute missing',
                             text => $attr_ln,
                             level => 's')
              unless defined $attr{$attr_ln};
        }
      }
    }

    if (defined $attr{'aria-checked'}) {
      if ($role{radio} or $role{menuitemradio}) {
        my $value = $attr{'aria-checked'}->value;
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        $self->{onerror}->(node => $attr{'aria-checked'},
                           type => 'aria:checked:mixed but radio',
                           level => 'w')
            if $value eq 'mixed';
      }
    }

    if (defined $attr{'aria-live'}) {
      my $value = $attr{'aria-live'}->value;
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($value eq 'assertive') {
        $self->{onerror}->(node => $attr{'aria-live'},
                           type => 'aria:live:assertive',
                           level => 's');
      }
    }

    if (defined $attr{'aria-posinset'}) {
      if (defined $attr{'aria-setsize'}) {
        $attr{'aria-posinset'}->value =~ /^([0-9]+)/;
        my $pos = $1;
        $attr{'aria-setsize'}->value =~ /^([0-9]+)/;
        my $size = $1;
        if (defined $pos and defined $size and not $pos <= $size) {
          $self->{onerror}->(node => $attr{'aria-posinset'},
                             type => 'aria:posinset:> setsize',
                             level => 'm');
        }
      } else {
        $self->{onerror}->(node => $attr{'aria-posinset'},
                           type => 'aria:posinset:no setsize',
                           level => 's');
      }
    }

    if (defined $attr{'aria-valuemax'} or
        defined $attr{'aria-valuemin'} or
        defined $attr{'aria-valuenow'}) {
      my %v;
      for (qw(max min now)) {
        next unless defined $attr{'aria-value'.$_};
        $attr{'aria-value'.$_}->value =~ /^[\x09\x0A\x0C\x0D\x20]*([+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[Ee][+-]?[0-9]+)?)/;
        $v{$_} = $1;
      }
      if (defined $v{max} and defined $v{min} and not $v{min} <= $v{max}) {
        $self->{onerror}->(node => $attr{'aria-valuemax'},
                           type => 'aria:valuemax lt valuemin',
                           level => 'm');
      } elsif (defined $v{min} and defined $v{now} and not $v{min} <= $v{now}) {
        $self->{onerror}->(node => $attr{'aria-valuenow'},
                           type => 'aria:valuenow lt valuemin',
                           level => 'w');
      } elsif (defined $v{max} and defined $v{now} and not $v{now} <= $v{max}) {
        $self->{onerror}->(node => $attr{'aria-valuemax'},
                           type => 'aria:valuemax lt valuenow',
                           level => 'w');
      }

      if ($role{progressbar} and defined $attr{'aria-valuenow'}) {
        $self->{onerror}->(node => $node,
                           type => 'attribute missing',
                           text => 'aria-valuemin',
                           level => 's')
            if not defined $attr{'aria-valuemin'};
        $self->{onerror}->(node => $node,
                           type => 'attribute missing',
                           text => 'aria-valuemax',
                           level => 's')
            if not defined $attr{'aria-valuemax'};
      }
    }

    if (defined $attr{'aria-valuetext'}) {
      if (defined $attr{'aria-valuenow'}) {
        $self->{onerror}->(node => $attr{'aria-valuetext'},
                           type => 'aria:valuetext',
                           level => 's');
      } else {
        $self->{onerror}->(node => $node,
                           type => 'attribute missing',
                           text => 'aria-valuenow',
                           level => 's');
      }
    }

    if ($role{definition} and defined $attr{'aria-labelledby'}) {
      for (split /[\x09\x0A\x0C\x0D\x20]+/, $attr{'aria-labelledby'}->value) {
        my $attr = $self->{id}->{$_}->[0];
        if (defined $attr) {
          my $el = $attr->owner_element;
          if (($el->namespace_uri || '') eq HTML_NS and
              $el->local_name eq 'dfn') {
            #
          } else {
            $self->{onerror}->(node => $attr{'aria-labelledby'},
                               value => $_,
                               type => 'aria:labelledby:definition label not dfn',
                               level => 's');
          }
        }
      }
    }

    if ($role{math} and not $role{math} eq 'implicit') {
      $self->{onerror}->(node => $node,
                         type => 'attribute missing',
                         text => 'aria-describedby',
                         level => 's')
          if not defined $attr{'aria-describedby'} and
             ($node->namespace_uri || '') eq HTML_NS and
             $node->local_name eq 'img';
    }

    if ($role{dialog} and not $role{dialog} eq 'implicit') {
      $self->{onerror}->(node => $node,
                         type => 'attribute missing:aria-label*',
                         level => 's')
          if not defined $attr{'aria-label'} and
             not defined $attr{'aria-labelledby'};
    }

    if ($role{presentation} and
        ($node->namespace_uri || '') eq HTML_NS and
        $node->local_name eq 'img') {
      my $attr = $node->get_attribute_node_ns (undef, 'alt');
      if (defined $attr and not $attr->value eq '') {
        $self->{onerror}->(node => $attr,
                           type => 'aria:img presentation:non empty alt',
                           level => 's');
      }
    }

    delete $role{presentation};
    $node_to_roles->{refaddr $node} = \%role;
  } # @relevant

  my $node_has_scope = {};
  my $need_tab = {};
  for my $node (@relevant) {
    my $roles = $node_to_roles->{refaddr $node};
    my $owned_nodes;
    ROLE: for my $role (keys %$roles) {
      my $role_def = $_Defs->{roles}->{$role};
      my @scope = keys %{$role_def->{scope_of} or {}};
      push @scope, 'radio' if $role eq 'radiogroup';
      if (@scope) {
        $owned_nodes ||= $get_owned_nodes->($node);
        for my $n_a (keys %$owned_nodes) {
          for my $r (@scope) {
            if ($node_to_roles->{$n_a}->{$r}) {
              $node_has_scope->{$n_a}->{$role} = 1;
            }
          }
        }
      }
      my @must = keys %{$role_def->{must_contain} or {}};
      if (not $roles->{$role} eq 'implicit' and @must) {
        my $busy = $node->get_attribute_ns (undef, 'aria-busy');
        if (defined $busy and $busy =~ /\A[Tt][Rr][Uu][Ee]\z/) {
          last ROLE; ## aria-busy=true, ASCII case-insensitive.
        }
        $owned_nodes ||= $get_owned_nodes->($node);
        for my $n_a (keys %$owned_nodes) {
          for my $r (@must) {
            next ROLE if $node_to_roles->{$n_a}->{$r};
          }
        }
        $self->{onerror}->(node => $node,
                           type => 'aria:role:no required owned element',
                           text => (join ' ', keys %{$role_def->{must_contain}}),
                           value => $role,
                           level => 'm');
      }
    } # $roles

    if ($roles->{document} or $roles->{application}) {
      $owned_nodes ||= $get_owned_nodes->($node);
      my $els = {banner => [], contentinfo => [], main => [], toolbar => []};
      for my $n_a (keys %$owned_nodes) {
        for my $r (qw(banner contentinfo main toolbar)) {
          push @{$els->{$r}}, $owned_nodes->{$n_a}
              if $node_to_roles->{$n_a}->{$r};
        }
      }
      for my $r (qw(banner contentinfo main)) {
        $self->{onerror}->(node => $node,
                           type => 'aria:multiple role elements',
                           text => $r,
                           level => 's')
            if @{$els->{$r}} > 1;
      }

      if ($roles->{application} and @{$els->{toolbar}} > 1) {
        for (@{$els->{toolbar}}) {
          $self->{onerror}->(node => $_,
                             type => 'attribute missing',
                             text => 'aria-label',
                             level => 'm')
              unless $_->has_attribute_ns (undef, 'aria-label');
        }
      }

      unless ((($node->namespace_uri || '') eq HTML_NS and $node->local_name eq 'body') or
              (($node->namespace_uri || '') eq SVG_NS and $node->local_name eq 'svg')) {
        $self->{onerror}->(node => $node,
                           type => 'attribute missing',
                           text => 'aria-labelledby',
                           level => 's')
            unless $node->has_attribute_ns (undef, 'aria-labelledby');
      }
    } # role=document role=application

    my $ad = $node->get_attribute_node_ns (undef, 'aria-activedescendant');
    if (defined $ad) {
      my $id = $ad->value;
      if (length $id) {
        my $refed = $self->{id}->{$id}->[0];
        if (defined $refed) {
          $owned_nodes ||= $get_owned_nodes->($node);
          $self->{onerror}->(node => $ad,
                             type => 'aria:activedescendant:not owned',
                             level => 's')
              unless $owned_nodes->{refaddr $refed->owner_element};
        }
      }
    }

    if ($roles->{tabpanel}) {
      TABPANEL: {
        my $lbls = $node->get_attribute_ns (undef, 'aria-labelledby');
        if (defined $lbls) {
          for (grep { length } split /[\x09\x0A\x0C\x0D\x20]+/, $lbls) {
            my $attr = $self->{id}->{$_}->[0] or next;
            if ($node_to_roles->{refaddr $attr->owner_element}->{tab}) {
              last TABPANEL;
            }
          }
        }
        $need_tab->{refaddr $node} = $node;
      } # TABPANEL
    }

    if ($roles->{region}) {
      LABEL: {
        my $lbls = $node->get_attribute_ns (undef, 'aria-labelledby');
        if (defined $lbls) {
          for (grep { length } split /[\x09\x0A\x0C\x0D\x20]+/, $lbls) {
            my $attr = $self->{id}->{$_}->[0] or next;
            my $el = $attr->owner_element;
            if ($node_to_roles->{refaddr $el}->{heading} or
                ((($el->namespace_uri || '') eq HTML_NS) and
                 {h1 => 1, h2 => 1, h3 => 1,
                  h4 => 1, h5 => 1, h6 => 1}->{$el->local_name})) {
              last LABEL;
            }
          }
        }
        last LABEL if $roles->{region} eq 'implicit';
        $self->{onerror}->(node => $node,
                           type => 'aria:region:no heading label',
                           level => 's');
      } # LABEL
    }

    if ($roles->{grid} or $roles->{treegrid}) {
      $owned_nodes ||= $get_owned_nodes->($node);
      my $has_sort = 0;
      for (keys %$owned_nodes) {
        if ($node_to_roles->{$_}->{columnheader} or
            $node_to_roles->{$_}->{rowheader}) {
          my $sort = $owned_nodes->{$_}->get_attribute_ns (undef, 'aria-sort');
          if (defined $sort) {
            $sort =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            unless ($sort eq 'none') {
              $has_sort++;
            }
          }
        }
      }
      if ($has_sort > 1) {
        $self->{onerror}->(node => $node,
                           type => 'aria:grid:multiple sorts',
                           level => 's');
      }
    }
  } # @relevant

  for my $node (@relevant) {
    my $node_addr = refaddr $node;
    next if $is_root{$node_addr};
    my $roles = $node_to_roles->{$node_addr};
    ROLE: for my $role (keys %$roles) {
      my $role_def = $_Defs->{roles}->{$role};
      my @scope = keys %{$role_def->{scope} or {}};
      if (@scope) {
        for (@scope) {
          next ROLE if $node_has_scope->{$node_addr}->{$_};
        }
        $self->{onerror}->(node => $node,
                           type => 'aria:role:not required context',
                           text => (join ' ', sort { $a cmp $b } @scope),
                           value => $role,
                           level => 'm');
      }
    }
    if ($roles->{radio} and
        not $roles->{radio} eq 'implicit' and
        not $node_has_scope->{$node_addr}->{radiogroup}) {
      $self->{onerror}->(node => $node,
                         type => 'aria:role:not required context',
                         text => 'radiogroup',
                         value => 'radio',
                         level => 's');
    }

    if ($roles->{tab}) {
      my $controls = $node->get_attribute_ns (undef, 'aria-controls');
      if (defined $controls) {
        for (grep { length } split /[\x09\x0A\x0C\x0D\x20]+/, $controls) {
          my $attr = $self->{id}->{$_}->[0] or next;
          delete $need_tab->{refaddr $attr->owner_element};
        }
      }
    }
  } # @relevant

  for (keys %$need_tab) {
    $self->{onerror}->(node => $need_tab->{$_},
                       type => 'aria:tabpanel:no tab',
                       level => 's');
  }
} # _validate_aria

## ------ Element content model ------

my $ElementDisallowedDescendants = {};
my $IsPalpableContent = {};

for my $ns (keys %{$_Defs->{elements}}) {
  for my $ln (keys %{$_Defs->{elements}->{$ns}}) {
    my $list = $_Defs->{elements}->{$ns}->{$ln}->{disallowed_descendants}
        or next;
    my $new_list = $ElementDisallowedDescendants->{$ns}->{$ln} ||= {};
    for my $el_ns (keys %{$list->{elements} or {}}) {
      for my $el_ln (keys %{$list->{elements}->{$el_ns}}) {
        $new_list->{$el_ns}->{$el_ln} = 1
            if $list->{elements}->{$el_ns}->{$el_ln};
      }
    }
    for my $cat (keys %{$list->{categories} or {}}) {
      for my $el_ns (keys %{$_Defs->{categories}->{$cat}->{elements} or {}}) {
        for my $el_ln (keys %{$_Defs->{categories}->{$cat}->{elements}->{$el_ns}}) {
          $new_list->{$el_ns}->{$el_ln} = 1
              if $_Defs->{categories}->{$cat}->{elements}->{$el_ns}->{$el_ln};
        }
      }
      for my $el_ns (keys %{$_Defs->{categories}->{$cat}->{elements_with_exceptions} or {}}) {
        for my $el_ln (keys %{$_Defs->{categories}->{$cat}->{elements_with_exceptions}->{$el_ns}}) {
          $new_list->{$el_ns}->{$el_ln} = 1
              if $_Defs->{categories}->{$cat}->{elements_with_exceptions}->{$el_ns}->{$el_ln};
        }
      }
    }
  }
}
## Note that there might be exceptions, which is checked by the
## |_is_minus_element| method.

$IsPalpableContent->{(HTML_NS)}->{audio} = sub {
  return $_[0]->has_attribute_ns (undef, 'controls');
};
$IsPalpableContent->{(HTML_NS)}->{input} = sub {
  ## Not <input type=hidden>
  return not (($_[0]->get_attribute_ns (undef, 'type') || '') =~ /\A[Hh][Ii][Dd][Dd][Ee][Nn]\z/); # hidden ASCII case-insensitive
};
$IsPalpableContent->{(HTML_NS)}->{menu} = sub {
  return $_[0]->type eq 'toolbar';
};

$IsPalpableContent->{(HTML_NS)}->{ul} =
$IsPalpableContent->{(HTML_NS)}->{ol} = sub {
  for (@{$_[0]->child_nodes}) {
    return 1 if
        $_->node_type == 1 and # ELEMENT_NODE
        $_->local_name eq 'li' and
        ($_->namespace_uri || '') eq HTML_NS;
  }
  return 0;
};

$IsPalpableContent->{(HTML_NS)}->{dl} = sub {
  for (@{$_[0]->child_nodes}) {
    return 1 if
        $_->node_type == 1 and # ELEMENT_NODE
        $_->local_name =~ /\Ad[td]\z/ and # dt | dd
        ($_->namespace_uri || '') eq HTML_NS;
  }
  return 0;
};

sub _add_minus_elements ($$@) {
  my $self = shift;
  my $element_state = shift;
  for my $elements (@_) {
    for my $nsuri (keys %$elements) {
      for my $ln (keys %{$elements->{$nsuri}}) {
        unless ($self->{minus_elements}->{$nsuri}->{$ln}) {
          $element_state->{minus_elements_original}->{$nsuri}->{$ln} = 0;
          $self->{minus_elements}->{$nsuri}->{$ln} = 1;
        }
      }
    }
  }
} # _add_minus_elements

sub _remove_minus_elements ($$) {
  my $self = shift;
  my $element_state = shift;
  for my $nsuri (keys %{$element_state->{minus_elements_original}}) {
    for my $ln (keys %{$element_state->{minus_elements_original}->{$nsuri}}) {
      delete $self->{minus_elements}->{$nsuri}->{$ln};
    }
  }
} # _remove_minus_elements

## ------ XXXXXX XXXXXX

our %AnyChecker = (
  ## NOTE: |check_start| is invoked before anything on the element's
  ## attributes and contents is checked.
  check_start => sub { },
  ## NOTE: |check_attrs| and |check_attrs2| are invoked after
  ## |check_start| and before anything on the element's contents is
  ## checked.  |check_attrs| is invoked immediately before
  ## |check_attrs2|.
  check_attrs => sub {
    my ($self, $item, $element_state) = @_;
    $self->_check_element_attrs ($item, $element_state);
  },
  check_attrs2 => sub { },
  ## NOTE: |check_child_element| is invoked for each occurence of
  ## child elements.  It is invoked after |check_attrs| and before
  ## |check_end|.  |check_child_element| and |check_child_text| are
  ## invoked for each child elements and text nodes in tree order.
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln}) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      #
    }
  },
  ## NOTE: |check_child_text| is invoked for each occurence of child
  ## text nodes.  It is invoked after |check_attrs| and before
  ## |check_end|.  |check_child_element| and |check_child_text| are
  ## invoked for each child elements and text nodes in tree order.
  check_child_text => sub { },
  ## NOTE: |check_end| is invoked after everything on the element's
  ## attributes and contents are checked.
  check_end => sub { },
);

our $ElementDefault = {
  %AnyChecker,
  check_start => sub {},
};

## This method returns whether the specified element is disallowed in
## the current context or not, given that the specified element is
## included in the list of possibly disallowed elements.
##
## Flags |no_interactive| and |in_canvas| are used to allow some kinds
## of interactive content that are descendant of |canvas| elements but
## not descendant of |a| or |button| elements.
sub _is_minus_element ($$$$) {
  my ($self, $el, $nsuri, $ln) = @_;

  if ($nsuri ne HTML_NS) {
    return 1;
  } else {
    if ($ln eq 'input') {
      my $value = $el->get_attribute_ns (undef, 'type') || '';
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($self->{flag}->{no_interactive} or not $self->{flag}->{in_canvas}) {
        return ($value ne 'hidden');
      } else {
        return not {
          hidden => 1,
          checkbox => 1,
          radio => 1,
          submit => 1, image => 1, reset => 1, button => 1,
        }->{$value};
      }
    } elsif ($ln eq 'img' or $ln eq 'object') {
      return $el->has_attribute_ns (undef, 'usemap');
    } elsif ($ln eq 'video' or $ln eq 'audio') {
      ## No media element is allowed as a descendant of a media
      ## element.
      return 1 if $self->{flag}->{in_media};

      return $el->has_attribute_ns (undef, 'controls');
    } elsif ($ln eq 'menu') {
      my $value = $el->get_attribute_ns (undef, 'type') || '';
      $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      return ($value eq 'toolbar');
    } elsif ($ln eq 'a' or $ln eq 'button') {
      return $self->{flag}->{no_interactive} || !$self->{flag}->{in_canvas};
    } else {
      return 1;
    }
  } # ns
} # _is_minus_element

our $Element = {};

$Element->{(RDF_NS)}->{RDF} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    my $triple = [];
    push @{$self->{return}->{rdf}}, [$item->{node}, $triple];
    require Web::RDF::XML::Parser;
    my $rdf = Web::RDF::XML::Parser->new;
    ## TODO: Should we make bnodeid unique in a document?
    $rdf->onerror ($self->{onerror});
    $rdf->ontriple (sub {
      my %opt = @_;
      push @$triple,
          [$opt{node}, $opt{subject}, $opt{predicate}, $opt{object}];
      if (defined $opt{id}) {
        push @$triple,
            [$opt{node},
             $opt{id},
             {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#subject>},
             $opt{subject}];
        push @$triple,
            [$opt{node},
             $opt{id},
             {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate>},
             $opt{predicate}];
        push @$triple,
            [$opt{node},
             $opt{id},
             {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#object>},
             $opt{object}];
        push @$triple,
            [$opt{node},
             $opt{id},
             {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>},
             {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#Statement>}];
      }
    });
    $rdf->convert_rdf_element ($item->{node});
  },
}; # rdf:RDF

use Char::Class::XML qw/InXML_NCNameStartChar10 InXMLNCNameChar10/;

## Check whether the labelable form-associated element is allowed to
## place there or not and mark the element ID, if any, might be used
## in the |for| attribute of a |label| element.
my $FAECheckStart = sub {
  my ($self, $item, $element_state) = @_;

  A: {
    my $el = $item->{node};
    if ($el->local_name eq 'input') {
      my $nsurl = $el->namespace_uri;
      if (defined $nsurl and $nsurl eq HTML_NS) {
        my $type = $el->get_attribute_ns (undef, 'type') || '';
        if ($type =~ /\A[Hh][Ii][Dd][Dd][Ee][Nn]\z/) { ## ASCII case-insensitive.
          # <input type=hidden>
          last A;
        }
      }
    }
    $element_state->{id_type} = 'labelable';
  } # A
}; # $FAECheckStart
my $FAECheckAttrs2 = sub {
  my ($self, $item, $element_state) = @_;

  ## This must be done in "check_attrs2" phase since it requires the
  ## |id| attribute of the element, if any, reflected to the
  ## |$self->{id}| hash.

  CHK: {
    # <input type=hidden>
    last CHK unless ($element_state->{id_type} || '') eq 'labelable';

    if ($self->{flag}->{has_label} and $self->{flag}->{has_labelable}) {
      my $for = $self->{flag}->{label_for};
      if (defined $for) {
        my $id_attrs = $self->{id}->{$for};
        if ($id_attrs and $id_attrs->[0]) {
          my $el = $id_attrs->[0]->owner_element;
          if ($el and $el eq $item->{node}) {
            ## Even if there is an ancestor |label| element with its
            ## |for| attribute specified, the attribute value
            ## identifies THIS element, then there is no problem.
            last CHK;
          }
        }
      }
      
      $self->{onerror}->(node => $item->{node},
                         type => 'multiple labelable fae',
                         level => 'm');
    } else {
      $self->{flag}->{has_labelable} = 2;
    }
  } # CHK
}; # $FAECheckAttrs2

## -- Common attribute syntacx checkers

my $GetHTMLEnumeratedAttrChecker = sub {
  my $states = shift; # {value => conforming ? 1 : -1}
  return sub {
    my ($self, $attr) = @_;
    my $value = $attr->value;
    $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($states->{$value}) {
      if ($states->{$value} eq 'last resort:good') {
        $self->{onerror}->(node => $attr,
                           type => 'last resort',
                           level => 'w'); # urged
      } elsif ($states->{$value} > 0) {
        #
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'enumerated:non-conforming',
                           level => 'm');
      }
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'enumerated:invalid',
                         level => 'm');
    }
  };
}; # $GetHTMLEnumeratedAttrChecker

## |rel| attribute (set of space separated tokens,
## whose allowed values are defined by the section on link types)
my $HTMLLinkTypesAttrChecker = sub {
  my ($a_or_area, $todo, $self, $attr, $item, $element_state) = @_;

  my $value = $attr->value;
  $value =~ s/(?:\G|[\x09\x0A\x0C\x0D\x20])[Ss][Hh][Oo][Rr][Tt][Cc][Uu][Tt]\x20[Ii][Cc][Oo][Nn](?:$|[\x09\x0A\x0C\x0D\x20])/ icon /gs;

  my %word;
  for my $word (grep {length $_}
                split /[\x09\x0A\x0C\x0D\x20]+/, $value) {
    $word =~ tr/A-Z/a-z/ unless $word =~ /:/; ## ASCII case-insensitive.

    unless ($word{$word}) {
      $word{$word} = 1;
    } elsif ($word eq 'up') {
      #
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }

  ## NOTE: Though there is no explicit "MUST NOT" for undefined values,
  ## "MAY"s and "only ... MAY" restrict non-standard non-registered
  ## values to be used conformingly.

  # XXX This need to be updated.

  my $is_hyperlink;
  my $is_resource;
  our $LinkType;
  for my $word (keys %word) {
    my $def = $LinkType->{$word};
    if (defined $def) {
      if ($def->{status} eq 'accepted') {
        if (defined $def->{effect}->[$a_or_area]) {
          #
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'link type:bad context',
                             value => $word,
                             level => 'm');
        }
      } elsif ($def->{status} eq 'proposal') {
        $self->{onerror}->(node => $attr,
                           type => 'link type:proposed',
                           value => $word,
                           level => 's');
        if (defined $def->{effect}->[$a_or_area]) {
          #
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'link type:bad context',
                             value => $word,
                             level => 'm');
        }
      } else { # rejected or synonym
        $self->{onerror}->(node => $attr,
                           type => 'link type:non-conforming',
                           value => $word,
                           level => 'm');
      }
      if (defined $def->{effect}->[$a_or_area]) {
        if ($word eq 'alternate') {
          #
        } elsif ($def->{effect}->[$a_or_area] eq 'hyperlink') {
          $is_hyperlink = 1;
        }
      }
      if ($def->{unique}) {
        unless ($self->{has_link_type}->{$word}) {
          $self->{has_link_type}->{$word} = 1;
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'link type:duplicate',
                             value => $word,
                             level => 'm');
        }
      }

      if (defined $def->{effect}->[$a_or_area] and $word ne 'alternate') {
        $is_hyperlink = 1
            if $def->{effect}->[$a_or_area] eq 'hyperlink' or
               $def->{effect}->[$a_or_area] eq 'annotation';
        $is_resource = 1 if $def->{effect}->[$a_or_area] eq 'external resource';
      }
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'unknown link type',
                         value => $word,
                         level => 'u');
    }

    ## XXX For registered link types, this check should be skipped
    if ($word =~ /:/) {
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($word);
      $chk->onerror (sub {
        $self->{onerror}->(value => $word, @_, node => $attr);
      });
      $chk->check_iri_reference; # XXX absolute URL
    }
  }
  $is_hyperlink = 1 if $word{alternate} and not $word{stylesheet};
  ## TODO: The Pingback 1.0 specification, which is referenced by HTML5,
  ## says that using both X-Pingback: header field and HTML
  ## <link rel=pingback> is deprecated and if both appears they
  ## SHOULD contain exactly the same value.
  ## ISSUE: Pingback 1.0 specification defines the exact representation
  ## of its link element, which cannot be tested by the current arch.
  ## ISSUE: Pingback 1.0 specification says that the document MUST NOT
  ## include any string that matches to the pattern for the rel=pingback link,
  ## which again inpossible to test.
  ## ISSUE: rel=pingback href MUST NOT include entities other than predefined 4.

  ## NOTE: <link rel="up index"><link rel="up up index"> is not an error.
  ## NOTE: We can't check "If the page is part of multiple hierarchies,
  ## then they SHOULD be described in different paragraphs.".

  $todo->{has_hyperlink_link_type} = 1 if $is_hyperlink;
  $element_state->{link_rel} = \%word;

  $NodeIsHyperlink->{refaddr $item->{node}} = 1 if $is_hyperlink;
}; # $HTMLLinkTypesAttrChecker

## Valid global date and time.
my $GetDateTimeAttrChecker = sub ($) {
  my $type = shift;
  return sub {
    my ($self, $attr, $item, $element_state) = @_;
    
    my $range_error;
    
    require Web::DateTime;
    my $dp = Web::DateTime->new;
    $dp->onerror (sub {
      my %opt = @_;
      unless ($opt{type} eq 'date value not supported') {
        $self->{onerror}->(%opt, node => $attr);
        $range_error = '';
      }
    });
    
    my $method = 'parse_' . $type;
    my $d = $dp->$method ($attr->value);
    $element_state->{date_value}->{$attr->name} = $d || $range_error;
  };
}; # $GetDateTimeAttrChecker

my $GetHTMLNonNegativeIntegerAttrChecker = sub {
  my $range_check = shift;
  return sub {
    my ($self, $attr) = @_;
    my $value = $attr->value;
    if ($value =~ /\A[0-9]+\z/) {
      if ($range_check->($value + 0)) {
        return 1;
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'nninteger:out of range',
                           level => 'm');
        return 0;
      }
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'nninteger:syntax error',
                         level => 'm');
      return 0;
    }
  };
}; # $GetHTMLNonNegativeIntegerAttrChecker

my $FormControlNameAttrChecker = sub {
  my ($self, $attr) = @_;
  
  unless (length $attr->value) {
    $self->{onerror}->(node => $attr,
                       type => 'empty control name',
                       level => 'm');
  }
  
  ## NOTE: No uniqueness constraint.
}; # $FormControlNameAttrChecker

my $CharChecker = sub {
  my ($self, $attr) = @_;
  
  ## A character, or string of length = 1.
  
  my $value = $attr->value;
  if (length $value != 1) {
    $self->{onerror}->(node => $attr,
                       type => 'char:syntax error',
                       level => 'm');
  }
}; # $CharChecker

my $TextFormatAttrChecker = sub {
  my ($self, $attr) = @_;
  unless ($attr->value =~ /\A(?>(?>\*|[0-9]*)[AaNnXxMm]|\\.)+\z/s) {
    $self->{onerror}->(node => $attr,
                       type => 'format:syntax error',
                       level => 'm');
  }
}; # $TextFormatAttrChecker

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{accesskey} = sub {
  my ($self, $attr) = @_;
  
  ## "Ordered set of unique space-separated tokens"
  
  my %keys;
  my @keys = grep {length} split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value;
  
  for my $key (@keys) {
    unless ($keys{$key}) {
      $keys{$key} = 1;
      if (length $key != 1) {
        $self->{onerror}->(node => $attr,
                           type => 'char:syntax error', value => $key,
                           level => 'm');
      }
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $key,
                         level => 'm');
    }
  }
}; # accesskey=""
$ElementAttrChecker->{(HTML_NS)}->{a}->{''}->{directkey}
    = $ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{accesskey};
$ElementAttrChecker->{(HTML_NS)}->{input}->{''}->{directkey}
    = $ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{accesskey};

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{id} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if (length $value > 0) {
    if ($self->{id}->{$value}) {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate ID',
                         level => 'm');
      push @{$self->{id}->{$value}}, $attr;
    } elsif ($self->{name}->{$value} and
             $self->{name}->{$value}->[-1]->owner_element ne $item->{node}) {
      $self->{onerror}->(node => $attr,
                         type => 'id name confliction',
                         value => $value,
                         level => 'm');
      $self->{id}->{$value} = [$attr];
      $self->{id_type}->{$value} = $element_state->{id_type} || '';
    } else {
      $self->{id}->{$value} = [$attr];
      $self->{id_type}->{$value} = $element_state->{id_type} || '';
    }
    push @{$element_state->{element_ids} ||= []}, $value;
    
    if ($value =~ /[\x09\x0A\x0C\x0D\x20]/) {
      $self->{onerror}->(node => $attr,
                         type => 'space in ID',
                         level => 'm');
    }
  } else {
    ## NOTE: MUST contain at least one character
    $self->{onerror}->(node => $attr,
                       type => 'empty attribute value',
                       level => 'm');
  }
}; # id=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{dir} = $GetHTMLEnumeratedAttrChecker->({
  ltr => 1,
  rtl => 1,
  auto => 'last resort:good',
}); # dir=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{class} = sub {
  my ($self, $attr) = @_;
    
    ## NOTE: "set of unique space-separated tokens".

    my %word;
    for my $word (grep {length $_}
                  split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
      unless ($word{$word}) {
        $word{$word} = 1;
        push @{$self->{return}->{class}->{$word}||=[]}, $attr;
      }
    }
}; # class=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{dropzone} = sub {
  ## Unordered set of space-separated tokens, ASCII case-insensitive.
    my ($self, $attr) = @_;
    my $has_feedback;
    my %word;
    for my $word (grep {length $_}
                  split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
      $word =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      if ($word eq 'copy' or $word eq 'move' or $word eq 'link') {
        if ($has_feedback) {
          $self->{onerror}->(node => $attr,
                             type => 'dropzone:duplicate feedback',
                             value => $word,
                             level => 'm');
        }
        $has_feedback = 1;
      } elsif ($word =~ /^(?:string|file):./s) {
        if ($word{$word}) {
          $self->{onerror}->(node => $attr,
                             type => 'duplicate token',
                             value => $word,
                             level => 'm');
        }
        $word{$word} = 1;
      } else {
          $self->{onerror}->(node => $attr,
                             type => 'word not allowed',
                             value => $word,
                             level => 'm');
      }
    }
}; # dropzone=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{language} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  unless ($value eq 'javascript') {
    $self->{onerror}->(type => 'script language:not js',
                       node => $attr,
                       level => 'm');
  }
}; # language=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{'xml:lang'} = sub {
  ## The |xml:lang| attribute in the null namespace, which is
  ## different from the |lang| attribute in the XML's namespace.
  my ($self, $attr) = @_;
  
  if ($attr->owner_document->manakai_is_html) {
    ## Allowed by HTML Standard but is ignored.
    $self->{onerror}->(type => 'in HTML:xml:lang',
                       level => 'i',
                       node => $attr);
  } else {
    ## Not allowed by any spec.
    $self->{onerror}->(type => 'in XML:xml:lang',
                       level => 'm',
                       node => $attr);
  }
  
  my $lang_attr = $attr->owner_element->get_attribute_node_ns (undef, 'lang');
  if ($lang_attr) {
    my $lang_attr_value = $lang_attr->value;
    $lang_attr_value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
    my $value = $attr->value;
    $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
    if ($lang_attr_value ne $value) {
      $self->{onerror}->(type => 'xml:lang ne lang',
                         level => 'm',
                         node => $attr);
    }
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'attribute missing',
                       text => 'lang',
                       level => 'm');
  }
}; # xml:lang=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{xmlns} = sub {
  ## The |xmlns| attribute in the null namespace, which is different
  ## from the |xmlns| attribute in the XMLNS namespace.
    my ($self, $attr) = @_;
    my $value = $attr->value;
    unless ($value eq HTML_NS) {
      $self->{onerror}->(node => $attr,
                         type => 'invalid attribute value',
                         level => 'm');
    }
    unless ($attr->owner_document->manakai_is_html) {
      $self->{onerror}->(node => $attr,
                         type => 'in XML:xmlns',
                         level => 'm');
      ## TODO: Test
    }
}; # xmlns=""

## ------ ------

my $NameAttrChecker = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value eq '') {
    $self->{onerror}->(node => $attr,
                       type => 'anchor name:empty',
                       level => 'm');
  } else {
    if ($self->{name}->{$value}) {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate anchor name',
                         value => $value,
                         level => 'm');
    } elsif ($self->{id}->{$value} and
             $self->{id}->{$value}->[-1]->owner_element ne $item->{node}) {
      $self->{onerror}->(node => $attr,
                         type => 'id name confliction',
                         value => $value,
                         level => 'm');
    } elsif ($attr->owner_element->local_name eq 'a') {
      $self->{onerror}->(node => $attr,
                         type => 'anchor name',
                         level => 's'); # obsolete but conforming
    }

    push @{$self->{name}->{$value} ||= []}, $attr;
    $element_state->{element_name} = $value;
  }
}; # $NameAttrChecker

my $NameAttrCheckEnd = sub {
  my ($self, $item, $element_state) = @_;
  if (defined $element_state->{element_name}) {
    my $has_id;
    
    for my $id (@{$element_state->{element_ids} or []}) {
      if ($id eq $element_state->{element_name}) {
        undef $has_id;
        last;
      }
      $has_id = 1;
    }

    if ($has_id) {
      $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'name'),
                         type => 'id name mismatch',
                         level => 'm');
    }
  }
}; # $NameAttrCheckEnd

my $ShapeCoordsChecker = sub ($$$$) {
  my ($self, $item, $attrs, $shape) = @_;
  
  my $coords;
  if ($attrs->{coords}) {
    my $coords_value = $attrs->{coords}->value;
    if ($coords_value =~ /\A-?[0-9]+(?>,-?[0-9]+)*\z/) {
      $coords = [split /,/, $coords_value];
    } else {
      $self->{onerror}->(node => $attrs->{coords},
                         type => 'coords:syntax error',
                         level => 'm');
    }
  }

  if (defined $attrs->{shape}) {
    my $sv = $attrs->{shape}->value;
    $sv =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    $shape = {
        circ => 'circle', circle => 'circle',
        default => 'default',
        poly => 'polygon', polygon => 'polygon',
        rect => 'rectangle', rectangle => 'rectangle',
    }->{$sv} || 'rectangle';
  }
  
  if ($shape eq 'circle') {
    if (defined $attrs->{coords}) {
      if (defined $coords) {
        if (@$coords == 3) {
          if ($coords->[2] < 0) {
            $self->{onerror}->(node => $attrs->{coords},
                               type => 'coords:out of range',
                               index => 2,
                               value => $coords->[2],
                               level => 'm');
          }
        } else {
          $self->{onerror}->(node => $attrs->{coords},
                             type => 'coords:number not 3',
                             text => 0+@$coords,
                             level => 'm');
        }
      } else {
        ## NOTE: A syntax error has been reported.
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'coords',
                         level => 'm');
    }
  } elsif ($shape eq 'default') {
    if (defined $attrs->{coords}) {
      $self->{onerror}->(node => $attrs->{coords},
                         type => 'attribute not allowed',
                         level => 'm');
    }
  } elsif ($shape eq 'polygon') {
    if (defined $attrs->{coords}) {
      if (defined $coords) {
        if (@$coords >= 6) {
          unless (@$coords % 2 == 0) {
            $self->{onerror}->(node => $attrs->{coords},
                               type => 'coords:number not even',
                               text => 0+@$coords,
                               level => 'm');
          }
        } else {
          $self->{onerror}->(node => $attrs->{coords},
                             type => 'coords:number lt 6',
                             text => 0+@$coords,
                             level => 'm');
        }
      } else {
        ## NOTE: A syntax error has been reported.
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'coords',
                         level => 'm');
    }
  } elsif ($shape eq 'rectangle') {
    if (defined $attrs->{coords}) {
      if (defined $coords) {
        if (@$coords == 4) {
          unless ($coords->[0] < $coords->[2]) {
            $self->{onerror}->(node => $attrs->{coords},
                               type => 'coords:out of range',
                               index => 0,
                               value => $coords->[0],
                               level => 'm');
          }
          unless ($coords->[1] < $coords->[3]) {
            $self->{onerror}->(node => $attrs->{coords},
                               type => 'coords:out of range',
                               index => 1,
                               value => $coords->[1],
                               level => 'm');
          }
        } else {
          $self->{onerror}->(node => $attrs->{coords},
                             type => 'coords:number not 4',
                             text => 0+@$coords,
                             level => 'm');
        }
      } else {
        ## NOTE: A syntax error has been reported.
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'coords',
                         level => 'm');
    }
  }
}; # $ShapeCoordsChecker

my $LegacyLoopChecker = sub {
  my ($self, $attr) = @_;
  
  ## A valid integer.
  
  if ($attr->value =~ /\A(-?[0-9]+)\z/) {
    my $n = 0+$1;
    if ($n != 0 and $n >= -1) {
      #
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'integer:out of range',
                         level => 'm');
    }
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'integer:syntax error',
                       level => 'm');
  }
}; # $LegacyLoopChecker

# XXX
my $GetHTMLAttrsChecker = sub {
  my $element_specific_checker = shift;
  return sub {
    my ($self, $item, $element_state) = @_;
    $self->_check_element_attrs ($item, $element_state,
                                 element_specific_checker => $element_specific_checker);
  };
}; # $GetHTMLAttrsChecker

my %HTMLEmptyChecker = (
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:empty',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed:empty',
                         level => 'm');
    }
  },
);

my %HTMLTextChecker = (
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:text',
                         level => 'm');
    }
  },
);

my %HTMLFlowContentChecker = (
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
      if ($element_state->{has_non_style}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow style',
                           level => 'm');
      }
    } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
             $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
      $element_state->{has_non_style} = 1;
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:flow',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $element_state->{has_non_style} = 1;
    }
  },
); # %HTMLFlowContentChecker

my %HTMLPhrasingContentChecker = (
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    ## Will be restored by |check_end| of
    ## |%HTMLPhrasingContentChecker| or |menu| element.
    $element_state->{in_phrasing_original} = $self->{flag}->{in_phrasing};
    $self->{flag}->{in_phrasing} = 1;
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
             $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:phrasing',
                         level => 'm');
    }
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{in_phrasing}
        unless $element_state->{in_phrasing_original};
  }, # check_end
); # %HTMLPhrasingContentChecker

## All "transparent" elements are only allowed as phrasing content or
## as flow content.  Therefore, if there is a phrasing content model
## ancestor, the content of the element is also phrasing content.
## Otherwise, it is flow content.  We don't take non-conforming
## placement of transparent elements into account (use flow content
## model instead).  Note that palpable content check is also performed
## for transparent elements.
my %TransparentChecker = (
  %HTMLFlowContentChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($self->{flag}->{in_phrasing}) { # phrasing content
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:phrasing',
                           level => 'm');
      }
    } else { # flow content
      if ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
        ## <style scoped> is only allowed as the first child elements
        ## when the element is used as real flow content (i.e. is a
        ## root element).
        if ($element_state->{has_non_style} or
            do {
              my $parent = $item->{node}->parent_node;
              ($parent and $parent->node_type == 1);
            }) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:flow style',
                             level => 'm');
        }
      } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
               $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{has_non_style} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
  }, # check_child_element
); # %TransparentChecker

# ---- Default HTML elements ----

$Element->{+HTML_NS}->{''} = {
  %AnyChecker,
};

for my $ns (keys %{$_Defs->{elements}}) {
  for my $ln (keys %{$_Defs->{elements}->{$ns}}) {
    my $cm = $_Defs->{elements}->{$ns}->{$ln}->{content_model} or next;
    if ($cm eq 'phrasing content') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $HTMLPhrasingContentChecker{$_}
          for keys %HTMLPhrasingContentChecker;
    } elsif ($cm eq 'flow content') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $HTMLFlowContentChecker{$_} for keys %HTMLFlowContentChecker;
    } elsif ($cm eq 'empty') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $HTMLEmptyChecker{$_} for keys %HTMLEmptyChecker;
    } elsif ($cm eq 'text') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $HTMLTextChecker{$_} for keys %HTMLTextChecker;
    }
  }
}

# ---- The root element ----

$Element->{+HTML_NS}->{html} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = 'before head';
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $parent = $item->{node}->parent_node;
    unless ($item->{node}->owner_document->manakai_is_srcdoc) {
      if (not $parent or $parent->node_type != 1) { # != ELEMENT_NODE
        unless ($item->{node}->has_attribute_ns (undef, 'lang')) {
          $self->{onerror}->(node => $item->{node},
                             type => 'attribute missing',
                             text => 'lang',
                             level => 'w');
        }
      }
    }
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'before head') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'head') {
        $element_state->{phase} = 'after head';            
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'body') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing',
                           text => 'head',
                           level => 'm');
        $element_state->{phase} = 'after body';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');      
      }
    } elsif ($element_state->{phase} eq 'after head') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'body') {
        $element_state->{phase} = 'after body';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');      
      }
    } elsif ($element_state->{phase} eq 'after body') {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');      
    } else {
      die "check_child_element: Bad |html| phase: $element_state->{phase}";
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{phase} eq 'after body') {
      #
    } elsif ($element_state->{phase} eq 'before head') {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'head',
                         level => 'm');
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'body',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'after head') {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'body',
                         level => 'm');
    } else {
      die "check_end: Bad |html| phase: $element_state->{phase}";
    }

    $AnyChecker{check_end}->(@_);
  },
}; # html

# ---- Document metadata ----

$Element->{+HTML_NS}->{head} = {
  %AnyChecker,
  ## $item->{is_template} - It is actually a template content, not |head|
  ## $item->{is_noscript} - It is actually a |noscript|, not |head|
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{in_head_original} = $self->{flag}->{in_head};
    $self->{flag}->{in_head} = 1;
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'title') {
      if ($item->{is_noscript}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:head noscript',
                           level => 'm');
      } elsif (not $element_state->{has_title} or $item->{is_template}) {
        $element_state->{has_title} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:head title',
                           level => 'm');
      }
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
      #
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'link') {
      #
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'meta') {
      #
    } elsif ($_Defs->{categories}->{'metadata content'}->{elements}->{$child_nsuri}->{$child_ln}) {
      if ($item->{is_noscript}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:head noscript',
                           level => 'm');
      }
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:metadata',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if (not $element_state->{has_title} and
        not $item->{is_template} and
        not $item->{is_noscript}) {
      my $el = $item->{node};
      my $od = $el->owner_document;
      my $tmd = $od->get_user_data('manakai_title_metadata');
      if ((defined $tmd and length $tmd) or $od->manakai_is_srcdoc) {
        #
      } else {
        $self->{onerror}->(node => $el,
                           type => 'child element missing',
                           text => 'title',
                           level => 'm');
      }
    }
    $self->{flag}->{in_head} = $element_state->{in_head_original};

    $AnyChecker{check_end}->(@_);
  },
}; # head

$Element->{+HTML_NS}->{title} = {
  %HTMLTextChecker,
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{onerror}->(node => $item->{node},
                       level => 'm',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
  }, # check_end
}; # title

$Element->{+HTML_NS}->{base} = {
  %HTMLEmptyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    if ($self->{has_uri_attr} and
        $item->{node}->has_attribute_ns (undef, 'href')) {
      ## XXX warn: <style>@import 'relative';</style><base href>
      ## This can't be detected: |<script>location.href =
      ## 'relative';</script><base href>|
      $self->{onerror}->(node => $item->{node},
                         type => 'basehref after URL attribute',
                         level => 'm');
    }

    $HTMLEmptyChecker{check_start}->(@_);
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    if ($self->{has_base}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'element not allowed:base',
                         level => 'm');
    } else {
      $self->{has_base} = 1;
    }

    my $has_target = $item->{node}->has_attribute_ns (undef, 'target');
    if ($self->{has_hyperlink_element} and $has_target) {
      $self->{onerror}->(node => $item->{node},
                         type => 'basetarget after hyperlink',
                         level => 'm');
    }

    if (not $has_target and
        not $item->{node}->has_attribute_ns (undef, 'href')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing:href|target',
                         level => 'm');
    }
  }, # check_attrs
}; # base

$Element->{+HTML_NS}->{link} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    rel => sub {}, ## checked in check_attrs2
    sizes => sub {
      my ($self, $attr) = @_;
      my %word;
      for my $word (grep {length $_}
                    split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
        $word =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        unless ($word{$word}) {
          $word{$word} = 1;
          if ($word eq 'any' or $word =~ /\A[1-9][0-9]*x[1-9][0-9]*\z/) {
            #
          } else {
            $self->{onerror}->(node => $attr, 
                               type => 'sizes:syntax error',
                               value => $word,
                               level => 'm');
          }
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'duplicate token',
                             value => $word,
                             level => 'm');
        }
      }
    },
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $rel_attr = $item->{node}->get_attribute_node_ns (undef, 'rel');
    $HTMLLinkTypesAttrChecker->(0, $item, $self, $rel_attr, $item, $element_state)
        if $rel_attr;

    if ($item->{node}->has_attribute_ns (undef, 'href')) {
      $self->{has_hyperlink_element} = 1 if $item->{has_hyperlink_link_type};
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'href',
                         level => 'm');
    }

    my $itemprop_attr = $item->{node}->get_attribute_node_ns (undef, 'itemprop');
    if ($rel_attr and $itemprop_attr) {
      $self->{onerror}->(node => $self->{flag}->{in_head} ? $itemprop_attr : $rel_attr,
                         type => 'attribute not allowed',
                         level => 'm');
    } elsif (not $rel_attr and not $itemprop_attr) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => ($self->{flag}->{in_head} or $item->{is_root}) ? 'rel' : 'itemprop',
                         level => 'm');
    } elsif (not $itemprop_attr and
             not $self->{flag}->{in_head} and
             not $item->{is_root}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'itemprop',
                         level => 'm');
    }
    
    if ($item->{node}->has_attribute_ns (undef, 'sizes') and
        not $element_state->{link_rel}->{icon}) {
      $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'sizes'),
                         type => 'attribute not allowed',
                         level => 'm');
    }

    if ($element_state->{link_rel}->{alternate} and
        $element_state->{link_rel}->{stylesheet}) {
      my $title_attr = $item->{node}->get_attribute_node_ns (undef, 'title');
      unless ($title_attr) {
        $element_state->{require_title} = 'm';
      } elsif ($title_attr->value eq '') {
        $self->{onerror}->(node => $title_attr,
                           type => 'empty style sheet title',
                           level => 'm');
      }
    }

    # XXX warn if crossorigin="" is set but external resource link
  }, # check_attrs2
}; # link

$ElementAttrChecker->{(HTML_NS)}->{meta}->{''}->{$_} = sub {}
    for qw(charset content http-equiv name); ## Checked by |check_attrs2|

$Element->{+HTML_NS}->{meta} = {
  %HTMLEmptyChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    my @key_attr = grep { $_ } (
      my $name_attr = $el->get_attribute_node_ns (undef, 'name'),
      my $http_equiv_attr = $el->get_attribute_node_ns (undef, 'http-equiv'),
      my $charset_attr = $el->get_attribute_node_ns (undef, 'charset'),
      my $itemprop_attr = $el->get_attribute_node_ns (undef, 'itemprop'),
    );
    if (not @key_attr) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing:meta',
                         level => 'm');
    } elsif (@key_attr > 1) {
      for (@key_attr[1..$#key_attr]) {
        $self->{onerror}->(node => $_,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    } # name="" http-equiv="" charset="" itemprop=""

    my $content_attr = $el->get_attribute_node_ns (undef, 'content');
    if ($name_attr or $http_equiv_attr or $itemprop_attr) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing',
                         text => 'content',
                         level => 'm')
          unless $content_attr;
    } else {
      $self->{onerror}->(node => $content_attr,
                         type => 'attribute not allowed',
                         level => 'm')
          if $content_attr;
    } # content=""

    if (not $itemprop_attr and
        not $self->{flag}->{in_head} and
        not $item->{is_root}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'itemprop',
                         level => 'm');
    }

    my $charset;
    if ($charset_attr) {
      $charset = $charset_attr->value;
      unless ($el->owner_document->manakai_is_html) { # XML document
        unless ($charset =~ /\A[Uu][Tt][Ff]-8\z/) { # "utf-8" ASCII case-insensitive.
          $self->{onerror}->(node => $charset_attr,
                             type => 'in XML:charset',
                             level => 'm');
        }
      }
    } # charset=""

    if ($name_attr) {
      my $name = $name_attr->value;
      $name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      my $value = $content_attr ? $content_attr->value : '';

      # XXX need to be updated
      Web::HTML::Validator::HTML::Metadata->check
          (name => $name,
           name_attr => $name_attr,
           content => $value,
           content_attr => $content_attr || $el,
           checker => $self);
    } # name=""

    if ($http_equiv_attr) {
      my $keyword = $http_equiv_attr->value;
      $keyword =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

      if ($keyword ne 'content-type' and ## checked separately
          $self->{flag}->{has_http_equiv}->{$keyword}) {
        $self->{onerror}->(type => 'duplicate http-equiv', value => $keyword,
                           node => $http_equiv_attr,
                           level => 'm');
      } else {
        $self->{flag}->{has_http_equiv}->{$keyword} = 1;
      }

      # XXX
      if ($keyword eq 'content-type' or
          $keyword eq 'default-style' or
          $keyword eq 'refresh' or
          $keyword eq 'pics-label') {
        #
      } elsif ($keyword eq 'content-language' or
               $keyword eq 'set-cookie') {
        $self->{onerror}->(node => $http_equiv_attr,
                           type => 'enumerated:non-conforming',
                           level => 'm');
      } else {
        $self->{onerror}->(node => $http_equiv_attr,
                           type => 'enumerated:invalid',
                           level => 'm');
      }

      # XXX
      if ($keyword eq 'content-language') {
        if ($content_attr) {
          ## BCP 47 language tag [OBSVOCAB]
          require Web::LangTag;
          my $lang = Web::LangTag->new;
          $lang->onerror (sub {
            $self->{onerror}->(@_, node => $content_attr);
          });
          my $parsed = $lang->parse_tag ($content_attr->value);
          $lang->check_parsed_tag ($parsed);
        }
      } elsif ($keyword eq 'content-type') {
        if ($content_attr) {
          if ($content_attr->value =~ m{\A[Tt][Ee][Xx][Tt]/[Hh][Tt][Mm][Ll];[\x09\x0A\x0C\x0D\x20]*[Cc][Hh][Aa][Rr][Ss][Ee][Tt]=(.+)\z}s) {
            $charset = $1;
          } else {
            $self->{onerror}->(node => $content_attr,
                               type => 'meta content-type syntax error',
                               level => 'm');
          }
        }
        unless ($el->owner_document->manakai_is_html) { # XML document
          $self->{onerror}->(node => $content_attr || $el,
                             type => 'in XML:charset',
                             level => 'm');
        }
      } elsif ($keyword eq 'default-style') {
        if ($content_attr) {
          $self->{onerror}->(node => $content_attr,
                             type => 'empty style sheet title',
                             level => 'w')
              if $content_attr->value eq '';
        }
      } elsif ($keyword eq 'refresh') {
        if ($content_attr) {
          my $content = $content_attr->value;
          if ($content =~ /\A[0-9]+\z/) { # Non-negative integer.
            #
          } elsif ($content =~ s/\A[0-9]+;[\x09\x0A\x0C\x0D\x20]+[Uu][Rr][Ll]=//) { # Non-negative integer, ";", space characters, "URL" ASCII case-insensitive, "="
            if ($content =~ m{^[\x22\x27]}) {
              $self->{onerror}->(node => $content_attr,
                                 value => $content,
                                 type => 'refresh:bad url',
                                 level => 'm');
            }

            ## URL [URL]
            require Web::URL::Checker;
            my $chk = Web::URL::Checker->new_from_string ($content);
            $chk->onerror (sub {
              $self->{onerror}->(value => $content, @_, node => $content_attr);
            });
            $chk->check_iri_reference; # XXX
            $self->{has_uri_attr} = 1; ## NOTE: One of "attributes with URLs".
          } else {
            $self->{onerror}->(node => $content_attr,
                               type => 'refresh:syntax error',
                               level => 'm');
          }
        }
      } elsif ($keyword eq 'set-cookie') {
        ## XXX set-cookie-string [OBSVOCAB]
      } # $keyword
    } # $http_equiv_attr

    if (defined $charset) {
      if ($self->{flag}->{has_meta_charset}) {
        $self->{onerror}->(node => $el,
                           type => 'duplicate meta charset',
                           level => 'm');
      } else {
        $self->{flag}->{has_meta_charset} = 1;
      }

      $self->{onerror}->(node => $el,
                         type => 'srcdoc:charset', # XXXdocumentation
                         level => 'm')
          if $el->owner_document->manakai_is_srcdoc;

      require Web::Encoding;
      if (Web::Encoding::is_encoding_label ($charset)) {
        my $name = Web::Encoding::encoding_label_to_name ($charset);
        my $doc_name = Web::Encoding::encoding_label_to_name ($el->owner_document->input_encoding);
        unless ($name eq $doc_name) {
          $self->{onerror}->(node => $charset_attr || $content_attr,
                             type => 'mismatched charset name',
                             value => $name,
                             text => $doc_name,
                             level => 'm');
        }
      } else {
        $self->{onerror}->(node => $charset_attr || $content_attr,
                           type => 'not encoding label',
                           value => $charset,
                           level => 'm');
      }

      for my $attr ($charset_attr, $http_equiv_attr, $content_attr) {
        if ($attr and $attr->get_user_data ('manakai_has_reference')) {
          $self->{onerror}->(node => $attr,
                             type => 'charref in charset',
                             level => 'm');
        }
      }

      # XXX charset1024 check
    } # Character encoding declaration
  }, # check_attrs2
}; # meta

$Element->{+HTML_NS}->{style} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{text} = '';
    $element_state->{content_type} = do {
      require Web::MIME::Type;
      Web::MIME::Type->parse_web_mime_type ('text/css');
    }; # overridden by type="" checker, if specified
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    if ($self->{flag}->{in_head}) {
      my $scoped_attr = $item->{node}->get_attribute_node_ns (undef, 'scoped');
      $self->{onerror}->(node => $scoped_attr,
                         type => 'attribute not allowed',
                         level => 'w')
          if $scoped_attr;
    } else {
      my $parent = $item->{node}->parent_node;
      if ($parent and $parent->node_type == 1) { # ELEMENT_NODE
        unless ($item->{node}->has_attribute_ns (undef, 'scoped')) {
          $self->{onerror}->(node => $item->{node},
                             type => 'attribute missing',
                             text => 'scoped',
                             level => 'm');
        }
      }
    }

    $element_state->{element_allowed} = 1
        if $element_state->{content_type} and
           $element_state->{content_type}->is_xml_mime_type;
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{element_allowed}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{text} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my $tc = $item->{node}->text_content;
    $tc =~ s/.*<!--.*?-->//gs;
    if ($tc =~ /<!--/) {
      $self->{onerror}->(node => $item->{node},
                         type => 'style:unclosed cdo',
                         level => 'm');
    }

    if (defined $element_state->{content_type} and
        ($element_state->{content_type}->as_valid_mime_type || '') eq 'text/css') {
      my $parser = $self->_css_parser ($item->{node}); # XXX
      # XXX $parser->context->scoped (has_attribute ('scoped'));
      my $ss = $parser->parse_char_string_as_ss ($element_state->{text});
      # XXX Web::CSS::Checker->new->check_ss ($ss);
    } elsif (defined $element_state->{content_type}) {
      $self->{onerror}->(node => $item->{node},
                         value => $element_state->{content_type}->as_valid_mime_type,
                         type => 'unknown style lang',
                         level => 'u');
    }

    $AnyChecker{check_end}->(@_);
  },
}; # style

# ---- Scripting ----

sub scripting ($;$) {
  if (@_ > 1) {
    $_[0]->{scripting} = $_[1];
  }
  return $_[0]->{scripting};
} # scripting

$Element->{+HTML_NS}->{script} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{text} = '';
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};
    unless ($el->has_attribute_ns (undef, 'src')) {
      for my $attr_name (qw(charset defer async crossorigin)) {
        my $attr = $el->get_attribute_node_ns (undef, $attr_name);
        $self->{onerror}->(type => 'attribute not allowed',
                           node => $attr,
                           level => $attr_name eq 'crossorigin' ? 'w' : 'm')
            if $attr;
      }
    }

    my $type = $item->{node}->get_attribute_ns (undef, 'type');
    my $language = $item->{node}->get_attribute_ns (undef, 'language');
    if ((defined $type and $type eq '') or
        (not defined $type and defined $language and $language eq '') or
        (not defined $type and not defined $language)) {
      $element_state->{content_type} = do {
        require Web::MIME::Type;
        Web::MIME::Type->parse_web_mime_type ('text/javascript');
      };
    } elsif (defined $language) {
      $element_state->{content_type} ||= do {
        require Web::MIME::Type;
        Web::MIME::Type->parse_web_mime_type ('text/' . $language, sub { });
      };
    }

    $element_state->{element_allowed} = 1
        if $element_state->{content_type} and
           $element_state->{content_type}->is_xml_mime_type and
           not $el->has_attribute_ns (undef, 'src');
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{element_allowed}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{text} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my $tc = $item->{node}->text_content;
    $tc =~ s{.*<!--(.*?)-->}{
      if ($1 =~ /<[Ss][Cc][Rr][Ii][Pp][Tt][\x09\x0A\x0C\x0D\x20\x2F>]/) {
        $self->{onerror}->(node => $item->{node},
                           type => 'script:nested <script>',
                           level => 'm');
      }
      '';
    }gse;
    if ($tc =~ /<!--/) {
      $self->{onerror}->(node => $item->{node},
                         type => 'style:unclosed cdo',
                         level => 'm');
    }

    if ($item->{node}->has_attribute_ns (undef, 'src')) {
      if (defined $element_state->{content_type} and
          $element_state->{content_type}->is_scripting_lang) {
        #
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'script:external data block',
                           level => 'm');
      }
      unless ($element_state->{text} =~ m{\A(?>(?>[\x20\x09]|/\*(?>[^*]|\*[^/])*\*+/)*(?>//[^\x0A]*)?\x0A)*\z}) {
        ## Non-Unicode character error is detected by other place.
        $self->{onerror}->(node => $item->{node},
                           type => 'script:inline doc:invalid',
                           level => 'm');
      }
    } elsif (defined $element_state->{content_type} and
             $element_state->{content_type}->is_javascript) {
      # XXX validate $element_state->{text} as JavaScript
      $self->{onerror}->(node => $item->{node},
                         value => $element_state->{content_type}->as_valid_mime_type,
                         type => 'unknown script lang',
                         level => 'u');
    } elsif (defined $element_state->{content_type}) {
      $self->{onerror}->(node => $item->{node},
                         value => $element_state->{content_type}->as_valid_mime_type,
                         type => 'unknown script lang',
                         level => 'u');
    }

    $AnyChecker{check_end}->(@_);
  }, # check_end

  ## XXXresource: <script type=""> must match the MIME type of the
  ## referenced resource.  <script type=""> must be specified if the
  ## referenced resource is not JavaScript.  <script charset=""> must
  ## match the charset="" of the referenced resource.
}; # script

$ElementAttrChecker->{(HTML_NS)}->{script}->{''}->{language} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $lang = $attr->value;
  $lang =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  if ($lang eq 'javascript') {
    my $type = $item->{node}->get_attribute_ns (undef, 'type');
    $type =~ tr/A-Z/a-z/ if defined $type; ## ASCII case-insensitive.
    if (not defined $type or $type eq 'text/javascript') {
      $self->{onerror}->(node => $attr,
                         type => 'script language',
                         level => 's'); # obsolete but conforming
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'script language:ne type',
                         level => 'm');
    }
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'script language:not js',
                       level => 'm');
  }
}; # <script language="">

$Element->{+HTML_NS}->{noscript} = {
  %TransparentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $item->{is_noscript} = 1;

    unless ($item->{node}->owner_document->manakai_is_html) {
      $self->{onerror}->(node => $item->{node},
                         type => 'in XML:noscript',
                         level => 'm');
    }

    if ($self->scripting) { ## Scripting is enabled
      $HTMLTextChecker{check_start}->(@_);
    } else { ## Scripting is disabled
      if ($self->{flag}->{in_head}) {
        $Element->{(HTML_NS)}->{head}->{check_start}->(@_);
      } else {
        $self->_add_minus_elements ($element_state,
                                    {(HTML_NS) => {noscript => 1}});
        $TransparentChecker{check_start}->(@_);
      }
    }
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->scripting) { ## Scripting is enabled
      $HTMLTextChecker{check_child_element}->(@_);
    } else { ## Scripting is disabled
      if ($self->{flag}->{in_head}) {
        $Element->{(HTML_NS)}->{head}->{check_child_element}->(@_);
      } else {
        $TransparentChecker{check_child_element}->(@_);
      }
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($self->scripting) { ## Scripting is enabled
      $HTMLTextChecker{check_child_text}->(@_);
    } else { ## Scripting is disabled
      if ($self->{flag}->{in_head}) {
        $Element->{(HTML_NS)}->{head}->{check_child_text}->(@_);
      } else {
        $TransparentChecker{check_child_text}->(@_);
      }
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($self->scripting) { ## Scripting is enabled
      if ($item->{node}->owner_document->manakai_is_html) {
        my $container_ln = $self->{flag}->{in_head} ? 'head' :
                           $self->{flag}->{in_phrasing} ? 'span' : 'div';
        $self->_add_minus_elements ($element_state,
                                    {(HTML_NS) => {script => 1,
                                                   noscript => 1}});
        $self->_check_fallback_html
            ($item->{node}, $self->{minus_elements}, $container_ln);
        $self->_remove_minus_elements ($element_state);
      }
      $HTMLTextChecker{check_end}->(@_);
    } else { ## Scripting is disabled
      if ($self->{flag}->{in_head}) {
        $Element->{(HTML_NS)}->{head}->{check_end}->(@_);
      } else {
        $self->_remove_minus_elements ($element_state);
        $self->{onerror}->(node => $item->{node},
                           level => 's',
                           type => 'no significant content')
            unless $element_state->{has_palpable};
        $TransparentChecker{check_end}->(@_);
      }
    }
  }, # check_end
}; # noscript

# ---- Sections ----

$Element->{+HTML_NS}->{$_}->{check_start} = sub {
  my ($self, $item, $element_state) = @_;
  $self->{flag}->{has_hn} = 1;
  $HTMLPhrasingContentChecker{check_start}->(@_);
} for qw(h1 h2 h3 h4 h5 h6); # check_start

## TODO: Explicit sectioning is "encouraged".

$Element->{+HTML_NS}->{hgroup} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state, $element_state2) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
      if ($child_nsuri eq HTML_NS and $child_ln =~ /\Ah[1-6]\z/) {
        $element_state2->{has_hn} = 1;
      }
    } elsif ($child_nsuri eq HTML_NS and $child_ln =~ /\Ah[1-6]\z/) {
      ## NOTE: Use $element_state2 instead of $element_state here so
      ## that the |h2| element in |<hgroup><ins><h2>| is not counted
      ## as an |h2| of the |hgroup| element.
      $element_state2->{has_hn} = 1;
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    unless ($element_state->{has_hn}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing:hn',
                         level => 'm');
    }

    $AnyChecker{check_end}->(@_);
  }, # check_end
}; # hgroup

$Element->{+HTML_NS}->{header} = {
  %HTMLFlowContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{has_hn_original} = $self->{flag}->{has_hn};
    $self->{flag}->{has_hn} = 0;
    $HTMLFlowContentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    unless ($self->{flag}->{has_hn}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing:hn',
                         level => 'w');
    }
    $self->{flag}->{has_hn} ||= $element_state->{has_hn_original};

    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # header

# ---- Grouping content ----

$Element->{+HTML_NS}->{ul} =
$Element->{+HTML_NS}->{ol} =
$Element->{+HTML_NS}->{dir} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'li') {
      #
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
}; # ul ol dir

$ElementAttrChecker->{(HTML_NS)}->{ol}->{''}->{type} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  unless ({
    1 => 1, a => 1, A => 1, i => 1, I => 1,
  }->{$value}) {
    $self->{onerror}->(node => $attr,
                       type => 'oltype:invalid',
                       level => 'm');
  }
}; # <ol type="">

$ElementAttrChecker->{(HTML_NS)}->{ul}->{''}->{type} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  unless ($value eq 'disc' or $value eq 'square' or $value eq 'circle') {
    $self->{onerror}->(node => $attr,
                       type => 'enumerated:invalid',
                       level => 'm');
  }
}; # <ul type="">

$ElementAttrChecker->{(HTML_NS)}->{$_}->{''}->{type} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  unless ($value =~ /\A(?:[Cc][Ii][Rr][Cc][Ll][Ee]|[Dd][Ii][Ss][Cc]|[Ss][Qq][Uu][Aa][Rr][Ee]|[1aAiI])\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'litype:invalid',
                       level => 'm');
  }
} for qw(li dir); # <li type=""> <dir type="">

$ElementAttrChecker->{(HTML_NS)}->{li}->{''}->{value} = sub {
  my ($self, $attr) = @_;

  my $parent_is_ol;
  my $parent = $attr->owner_element->manakai_parent_element;
  if (defined $parent) {
    my $parent_ns = $parent->namespace_uri;
    $parent_ns = '' unless defined $parent_ns;
    my $parent_ln = $parent->local_name;
    $parent_is_ol = ($parent_ns eq HTML_NS and $parent_ln eq 'ol');
  }

  unless ($parent_is_ol) {
    $self->{onerror}->(node => $attr,
                       type => 'non-ol li value',
                       level => 'm');
  }
  
  my $value = $attr->value;
  unless ($value =~ /\A-?[0-9]+\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'integer:syntax error',
                       level => 'm');
  }
}; # <li value="">

$Element->{+HTML_NS}->{dl} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = 'before dt';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } elsif ($element_state->{phase} eq 'in dds') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        #$element_state->{phase} = 'in dds';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $element_state->{phase} = 'in dts';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'in dts') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        #$element_state->{phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $element_state->{phase} = 'in dds';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'before dt') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $element_state->{phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}
             ->(node => $child_el,
                type => 'ps element missing',
                text => 'dt',
                level => 'm');
        $element_state->{phase} = 'in dds';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } else {
      die "check_child_element: Bad |dl| phase: $element_state->{phase}";
    }

    if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
      my $name = $child_el->text_content;
      if (defined $element_state->{dl_names}->{$name}) {
        $self->{onerror}->(node => $child_el,
                           type => 'duplicate dl name',
                           level => 's');
      } else {
        $element_state->{dl_names}->{$name} = 1;
      }
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{phase} eq 'in dts') {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'dd',
                         level => 'm');
    }

    $AnyChecker{check_end}->(@_);
  },
}; # dl

$ElementAttrChecker->{(HTML_NS)}->{marquee}->{''}->{loop} = $LegacyLoopChecker;

$ElementAttrChecker->{(HTML_NS)}->{font}->{''}->{size} = sub {
  my ($self, $attr) = @_;
  unless ($attr->value =~ /\A[+-]?[1-7]\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'fontsize:syntax error',
                       level => 'm');
  }
}; # <font size="">

# ---- Text-level semantics ----

$Element->{+HTML_NS}->{a} = {
  %TransparentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    coords => sub { }, ## Checked in $ShapeCoordsChecker.
          cti => sub {
            my ($self, $attr) = @_;
            my $value = $attr->value;
            if ($value =~ m[\A[0-9*\x23,/]{1,128}\z]) {
              if ($value =~ m[//]) {
                $self->{onerror}->(node => $attr,
                                   type => 'cti:syntax error',
                                   level => 'm');
              }
            } else {
              $self->{onerror}->(node => $attr,
                                 type => 'cti:syntax error',
                                 level => 'm');
            }
          }, # cti
          loop => sub {
            my ($self, $attr) = @_;
            if ($attr->value =~ /\A(?:[0-9]+|infinite)\z/) {
              #
            } else {
              $self->{onerror}->(node => $attr,
                                 type => 'nninteger:syntax error',
                                 level => 'm');
            }
          }, # loop
          memoryname => sub {
            my ($self, $attr) = @_;
            if ($attr->value =~ /.-./s) {
              #
            } else {
              $self->{onerror}->(node => $attr,
                                 type => 'memoryname:syntax error',
                                 level => 'm');
            }
          }, # memoryname
          name => $NameAttrChecker,
    rel => sub {}, ## checked in check_attrs2
          viblength => $GetHTMLNonNegativeIntegerAttrChecker->(sub {
            1 <= $_[0] and $_[0] <= 9;
          }),
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $rel_attr = $item->{node}->get_attribute_node_ns (undef, 'rel');
    $HTMLLinkTypesAttrChecker->(1, $item, $self, $rel_attr, $item, $element_state)
        if $rel_attr;

    my %attr;
    for my $attr (@{$item->{node}->attributes}) {
      my $attr_ns = $attr->namespace_uri;
      $attr_ns = '' unless defined $attr_ns;
      my $attr_ln = $attr->local_name;
      $attr{$attr_ln} = $attr if $attr_ns eq '';
    }

    $element_state->{in_a_href_original} = $self->{flag}->{in_a_href};
    if (defined $attr{href}) {
      $self->{has_hyperlink_element} = 1;
      $self->{flag}->{in_a_href} = 1;
    } else {
      for (qw(
        target ping rel hreflang type
        ilet iswf irst ib ifb ijam ista
        email telbook kana memoryname
        lcs
        loop soundstart volume
      )) {
        if (defined $attr{$_}) {
          $self->{onerror}->(node => $attr{$_},
                             type => 'attribute not allowed',
                             level => 'm');
        }
      }

      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'href',
                         level => 'm')
          if defined $attr{itemprop};
    }

    if ($attr{target}) {
      for (qw(ilet iswf irst ib ifb ijam lcs utn)) {
        if ($attr{$_}) {
          $self->{onerror}->(node => $attr{target},
                             type => 'attribute not allowed',
                             level => 'm');
          last;
        }
      }
    }

    if ($attr{viblength} and not $attr{vibration}) {
      $self->{onerror}->(node => $attr{viblength},
                         type => 'attribute not allowed',
                         level => 'm');
    }

    $ShapeCoordsChecker->($self, $item, \%attr, 'missing');
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{no_interactive_original}
        = $self->{flag}->{no_interactive};
    $self->{flag}->{no_interactive} = 1;
    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{in_a_href}
        unless $element_state->{in_a_href_original};
    delete $self->{flag}->{no_interactive}
        unless $element_state->{no_interactive};

    $NameAttrCheckEnd->(@_);
    $TransparentChecker{check_end}->(@_);
  }, # check_end
}; # a

$Element->{+HTML_NS}->{dfn} = {
  %HTMLPhrasingContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    my $node = $item->{node};
    my $term = $node->get_attribute_ns (undef, 'title');
    unless (defined $term) {
      for my $child (@{$node->child_nodes}) {
        if ($child->node_type == 1) { # ELEMENT_NODE
          if (defined $term) {
            undef $term;
            last;
          } elsif ($child->local_name eq 'abbr') {
            my $nsuri = $child->namespace_uri;
            if (defined $nsuri and $nsuri eq HTML_NS) {
              my $attr = $child->get_attribute_node_ns (undef, 'title');
              if ($attr) {
                $term = $attr->value;
              }
            }
          }
        } elsif ($child->node_type == 3 or $child->node_type == 4) {
          ## TEXT_NODE or CDATA_SECTION_NODE
          if ($child->data =~ /\A[\x09\x0A\x0C\x0D\x20]+\z/) { # Inter-element whitespace
            next;
          }
          undef $term;
          last;
        }
      }
      unless (defined $term) {
        $term = $node->text_content;
      }
    }
    if ($self->{term}->{$term}) {
      push @{$self->{term}->{$term}}, $node;
    } else {
      $self->{term}->{$term} = [$node];
    }
    ## ISSUE: The HTML5 definition for the defined term does not work with
    ## |ruby| unless |dfn| has |title|.

    $HTMLPhrasingContentChecker{check_start}->(@_);
  }, # check_start
}; # dfn

## NOTE: |abbr|: "If an abbreviation is pluralised, the expansion's
## grammatical number (plural vs singular) must match the grammatical
## number of the contents of the element."  Though this can be checked
## by machine, it requires language-specific knowledge and dictionary,
## such that we don't support the check of the requirement.

# XXX content model need to be updated
$Element->{+HTML_NS}->{time} = {
  %HTMLPhrasingContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    datetime => sub { 1 }, # checked in |checker|
  }), # check_attrs
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $self->_add_minus_elements ($element_state, {(HTML_NS) => {time => 1}}); # XXX

    $HTMLPhrasingContentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->_remove_minus_elements ($element_state);

    ## XXX Maybe we should move this code out somewhere (maybe
    ## Message::Date) such that we can reuse this code in other places
    ## (e.g. HTMLTimeElement implementation).

    ## "Vaguer moments in time" or "valid date or time string".
    my $attr = $item->{node}->get_attribute_node_ns (undef, 'datetime');
    my $input;
    my $reg_sp;
    my $input_node;
    if ($attr) {
      $input = $attr->value;
      $reg_sp = qr/[\x09\x0A\x0C\x0D\x20]/;
      $input_node = $attr;
    } else {
      $input = $item->{node}->text_content;
      $reg_sp = qr/\p{WhiteSpace}/;
      $input_node = $item->{node};
    }

    # XXX Update error descriptions
    my $hour;
    my $minute;
    my $second;
    if ($input =~ /
      \A
      $reg_sp*
      ([0-9]+) # 1
      (?>
        -([0-9]+) # 2
        -((?>[0-9]+)) # 3 # Use (?>) such that yyyy-mm-ddhh:mm does not match
        $reg_sp*
        (?>
          (?>
            T
            $reg_sp*
          )?
          ([0-9]+) # 4
          :([0-9]+) # 5
          (?>
            :([0-9]+(?>\.[0-9]+)?) # 6
          )?
          $reg_sp*
          (?>
            Z
            $reg_sp*
          |
            ([+-])([0-9]+):([0-9]+) # 7, 8, 9
            $reg_sp*
          )?
        )?
        \z
      |
        :([0-9]+) # 10
        (?:
          :([0-9]+(?>\.[0-9]+)?) # 11
        )?
        $reg_sp*
        \z
      )
    /x) {
      my $has_syntax_error;
      if (defined $2) { ## YYYY-MM-DD T? hh:mm
        if (length $1 != 4 or length $2 != 2 or length $3 != 2 or
            (defined $4 and length $4 != 2) or
            (defined $5 and length $5 != 2)) {
          $self->{onerror}->(node => $input_node,
                             type => 'dateortime:syntax error',
                             level => 'm');
          $has_syntax_error = 1;
        }

        if (1 <= $2 and $2 <= 12) {
          $self->{onerror}->(node => $input_node, type => 'datetime:bad day',
                             level => 'm')
              if $3 < 1 or
                  $3 > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$2];
          $self->{onerror}->(node => $input_node, type => 'datetime:bad day',
                             level => 'm')
              if $2 == 2 and $3 == 29 and
                  not ($1 % 400 == 0 or ($1 % 4 == 0 and $1 % 100 != 0));
        } else {
          $self->{onerror}->(node => $input_node,
                             type => 'datetime:bad month',
                             level => 'm');
        }
        $self->{onerror}->(node => $input_node,
                           type => 'datetime:bad year',
                           level => 'm')
          if $1 == 0;

        ($hour, $minute, $second) = ($4, $5, $6);
          
        if (defined $8) { ## [+-]hh:mm
          if (length $8 != 2 or length $9 != 2) {
            $self->{onerror}->(node => $input_node,
                               type => 'dateortime:syntax error',
                               level => 'm');
            $has_syntax_error = 1;
          }

          $self->{onerror}->(node => $input_node,
                             type => 'datetime:bad timezone hour',
                             level => 'm')
              if $8 > 23;
          $self->{onerror}->(node => $input_node,
                             type => 'datetime:bad timezone minute',
                             level => 'm')
              if $9 > 59;
          if ($7 eq '-' and $8 == 0 and $9 == 0) {
            $self->{onerror}->(node => $input_node,
                               type => 'datetime:-00:00', # XXXtype
                               level => 'm'); # don't return
          }
        }
      } else { ## hh:mm
        if (length $1 != 2 or length $10 != 2) {
          $self->{onerror}->(node => $input_node,
                             type => qq'dateortime:syntax error',
                             level => 'm');
          $has_syntax_error = 1;
        }

        ($hour, $minute, $second) = ($1, $10, $11);
      }

      $self->{onerror}->(node => $input_node, type => 'datetime:bad hour',
                         level => 'm')
          if defined $hour and $hour > 23;
      $self->{onerror}->(node => $input_node, type => 'datetime:bad minute',
                         level => 'm')
          if defined $minute and $minute > 59;

      if (defined $second) { ## s
        ## NOTE: Integer part of second don't have to have length of two.
          
        if (substr ($second, 0, 1) eq '.') {
          $self->{onerror}->(node => $input_node,
                             type => 'dateortime:syntax error',
                             level => 'm');
          $has_syntax_error = 1;
        }
          
        $self->{onerror}->(node => $input_node, type => 'datetime:bad second',
                           level => 'm') if $second >= 60;
      }

      unless ($has_syntax_error) {
        $input =~ s/\A$reg_sp+//;
        $input =~ s/$reg_sp+\z//;
        if ($input =~ /$reg_sp+/) {
          $self->{onerror}->(node => $input_node,
                             type => 'dateortime:syntax error',
                             level => 'm');
        }
      }
    } else {
      $self->{onerror}->(node => $input_node,
                         type => 'dateortime:syntax error',
                         level => 'm');
    }

    $HTMLPhrasingContentChecker{check_end}->(@_);
  }, # check_end
}; # time

$Element->{+HTML_NS}->{$_}->{check_end} = sub {
  my ($self, $item, $element_state) = @_;
  my $el = $item->{node}; # <i> or <b>

  if ($el->local_name eq 'b') {
    $self->{onerror}->(type => 'last resort',
                       node => $el,
                       level => 's');
  }

  if ($el->has_attribute_ns (undef, 'class')) {
    if ($el->local_name eq 'b') {
      #
    } else {
      $self->{onerror}->(type => 'last resort',
                         node => $el,
                         level => 'w'); # encouraged
    }
  } else {
    $self->{onerror}->(type => 'attribute missing',
                       text => 'class',
                       node => $el,
                       level => 'w'); # encouraged
  }

  $HTMLPhrasingContentChecker{check_end}->(@_);
} for qw(b i); # check_end

# XXX broken
# XXX update error descriptions
$Element->{+HTML_NS}->{ruby} = {
  %HTMLPhrasingContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    $element_state->{phase} = 'before-rb';
    #$HTMLPhrasingContentChecker{check_start}->(@_);
  },
  ## NOTE: (phrasing, (rt | (rp, rt, rp)))+
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'before-rb') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{phase} = 'in-rb';
      } elsif ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rt';
      } elsif ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rp1';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:ruby base',
                           level => 'm');
        $element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'in-rb') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        #$element_state->{phase} = 'in-rb';
      } elsif ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        unless (delete $element_state->{has_palpable}) {
          $self->{onerror}->(node => $child_el,
                             level => 's',
                             type => 'no significant content before');
        }
        $element_state->{phase} = 'after-rt';
      } elsif ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        unless (delete $element_state->{has_palpable}) {
          $self->{onerror}->(node => $child_el,
                             level => 's',
                             type => 'no significant content before');
        }
        $element_state->{phase} = 'after-rp1';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:ruby base',
                           level => 'm');
        #$element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'after-rt') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{phase} = 'in-rb';
      } elsif ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rp1';
      } elsif ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        #$element_state->{phase} = 'after-rt';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:ruby base',
                           level => 'm');
        $element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'after-rp1') {
      if ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        $element_state->{phase} = 'after-rp-rt';
      } elsif ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el, 
                           type => 'ps element missing',
                           text => 'rt',
                           level => 'm');
        $element_state->{phase} = 'after-rp2';
      } else {
        $self->{onerror}->(node => $child_el, 
                           type => 'ps element missing',
                           text => 'rt',
                           level => 'm');
        $self->{onerror}->(node => $child_el, 
                           type => 'ps element missing',
                           text => 'rp',
                           level => 'm');
        unless ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
                $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:ruby base',
                             level => 'm');
        }
        $element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'after-rp-rt') {
      if ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        $element_state->{phase} = 'after-rp2';
      } elsif ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el, 
                           type => 'ps element missing',
                           text => 'rp',
                           level => 'm');
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rt';
      } else {
        $self->{onerror}->(node => $child_el, 
                           type => 'ps element missing',
                           text => 'rp',
                           level => 'm');
        unless ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
                $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:ruby base',
                             level => 'm');
        }
        $element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'after-rp2') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{phase} = 'in-rb';
      } elsif ($child_ln eq 'rt' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rt';
      } elsif ($child_ln eq 'rp' and $child_nsuri eq HTML_NS) {
        $self->{onerror}->(node => $child_el,
                           level => 's',
                           type => 'no significant content before');
        $element_state->{phase} = 'after-rp1';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:ruby base',
                           level => 'm');
        $element_state->{phase} = 'in-rb';
      }
    } else {
      die "check_child_element: Bad |ruby| phase: $element_state->{phase}";
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $element_state->{has_palpable} = 1;
      if ($element_state->{phase} eq 'before-rb') {
        $element_state->{phase} = 'in-rb';
      } elsif ($element_state->{phase} eq 'in-rb') {
        #
      } elsif ($element_state->{phase} eq 'after-rt' or
               $element_state->{phase} eq 'after-rp2') {
        $element_state->{phase} = 'in-rb';
      } elsif ($element_state->{phase} eq 'after-rp1') {
        $self->{onerror}->(node => $child_node, 
                           type => 'ps element missing',
                           text => 'rt',
                           level => 'm');
        $self->{onerror}->(node => $child_node, 
                           type => 'ps element missing',
                           text => 'rp',
                           level => 'm');
        $element_state->{phase} = 'in-rb';
      } elsif ($element_state->{phase} eq 'after-rp-rt') {
        $self->{onerror}->(node => $child_node, 
                           type => 'ps element missing',
                           text => 'rp',
                           level => 'm');
        $element_state->{phase} = 'in-rb';
      } else {
        die "check_child_text: Bad |ruby| phase: $element_state->{phase}";
      }
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->_remove_minus_elements ($element_state);

    if ($element_state->{phase} eq 'before-rb') {
      $self->{onerror}->(node => $item->{node},
                         level => 's',
                         type => 'no significant content');
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing',
                         text => 'rt',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'in-rb') {
      unless (delete $element_state->{has_palpable}) {
        $self->{onerror}->(node => $item->{node},
                           level => 's',
                           type => 'no significant content at the end');
      }
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing',
                         text => 'rt',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'after-rt' or
             $element_state->{phase} eq 'after-rp2') {
      #
    } elsif ($element_state->{phase} eq 'after-rp1') {
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing',
                         text => 'rt',
                         level => 'm');
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing',
                         text => 'rp',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'after-rp-rt') {
      $self->{onerror}->(node => $item->{node},
                         type => 'element missing',
                         text => 'rp',
                         level => 'm');
    } else {
      die "check_child_text: Bad |ruby| phase: $element_state->{phase}";
    }
    #$HTMLPhrasingContentChecker{check_end}->(@_);
  }, # check_end
}; # ruby

$Element->{+HTML_NS}->{bdo}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  unless ($item->{node}->has_attribute_ns (undef, 'dir')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'dir',
                       level => 'm');
  }
}; # check_attrs2

# ---- Edits ----

# XXX "paragraph" vs ins/del

$Element->{+HTML_NS}->{ins} = {
  %TransparentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    datetime => $GetDateTimeAttrChecker->('date_string_with_optional_time'),
  }), # check_attrs
}; # ins

$Element->{+HTML_NS}->{del} = {
  %TransparentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    datetime => $GetDateTimeAttrChecker->('date_string_with_optional_time'),
  }), # check_attrs
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    # "in_phrasing" don't have to be restored here, because of the
    # "transparent"ness.

    #$TransparentChecker{check_end}->(@_);
  }, # check_end
}; # del

# ---- Embedded content ----

$Element->{+HTML_NS}->{figure} = {
  %HTMLFlowContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    for my $child (@{$item->{node}->child_nodes}) {
      my $child_nt = $child->node_type;
      if ($child_nt == 1) { # ELEMENT_NODE
        my $child_ns = $child->namespace_uri || '';
        if ($child_ns eq HTML_NS) {
          my $child_ln = $child->local_name;
          if ($child_ln eq 'figcaption') {
            for (@{$child->child_nodes}) {
              my $nt = $_->node_type;
              if ($nt == 1) { # ELEMENT_NODE
                $element_state->{has_figcaption_content} = 1;
                last;
              } elsif ($nt == 3) { # TEXT_NODE
                if ($_->data =~ /[^\x09\x0A\x0C\x0D\x20]/) {
                  $element_state->{has_figcaption_content} = 1;
                  last;
                }
              }
            }
          } elsif ($child_ln eq 'table') {
            $element_state->{figure_table_count}++;
          } elsif ($_Defs->{categories}->{'embedded content'}->{elements}->{$child_ns}->{$child_ln}) {
            $element_state->{figure_embedded_count}++;
            $element_state->{figure_has_non_table} = 1;
          } else {
            $element_state->{figure_has_non_table} = 1;
          }
        } else { # ns
          $element_state->{figure_has_non_table} = 1;
        }
      } elsif ($child_nt == 3) { # TEXT_NODE
        if ($child->data =~ /[^\x09\x0A\x0C\x0D\x20]/) {
          $element_state->{figure_embedded_count}++;
          $element_state->{figure_has_non_table} = 1;
        } else {
          #$element_state->{figure_has_non_table} = 1; ## Spec does not explicitly allow inter-element whitespaces
        }
      }
    } # $child
  }, # check_start
  ## Flow content, optionally either preceded or followed by a |figcaption|
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'figcaption') {
      push @{$element_state->{figcaptions} ||= []}, $child_el;
    } else { # flow content
      if ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
        if ($element_state->{has_non_style}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:flow style',
                             level => 'm');
        }
        $element_state->{in_flow_content} = 1;
        push @{$element_state->{figcaptions} ||= []}, 'flow';
      } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
               $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{in_flow_content} = 1;
        $element_state->{has_non_style} = 1;
        push @{$element_state->{figcaptions} ||= []}, 'flow';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      push @{$element_state->{figcaptions} ||= []}, 'flow';
      $element_state->{has_non_style} = 1;
      $element_state->{in_flow_content} = 1;
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if (@{$element_state->{figcaptions} or []}) {
      if (ref $element_state->{figcaptions}->[0]) {
        shift @{$element_state->{figcaptions}};
      } elsif (ref $element_state->{figcaptions}->[-1]) {
        pop @{$element_state->{figcaptions}};
      }
      for (grep { ref $_ } @{$element_state->{figcaptions}}) {
        $self->{onerror}->(node => $_,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
    $self->{onerror}->(node => $item->{node},
                       level => 's',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # figure

$Element->{+HTML_NS}->{iframe} = {
  %HTMLTextChecker,
  check_start => sub {
    my ($self, $item) = @_;
    if ($item->{node}->owner_document->manakai_is_html) {
      $HTMLTextChecker{check_start}->(@_);
    } else {
      $HTMLEmptyChecker{check_start}->(@_);
    }
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'itemprop') and
        not $item->{node}->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item) = @_;
    if ($item->{node}->owner_document->manakai_is_html) {
      $HTMLTextChecker{check_child_element}->(@_);
    } else {
      $HTMLEmptyChecker{check_child_element}->(@_);
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item) = @_;
    if ($item->{node}->owner_document->manakai_is_html) {
      $HTMLTextChecker{check_child_text}->(@_);
    } else {
      $HTMLEmptyChecker{check_child_text}->(@_);
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->owner_document->manakai_is_html) {
      $self->_add_minus_elements ($element_state,
                                  {(HTML_NS) => {script => 1}});
      $self->_check_fallback_html
          ($item->{node}, $self->{minus_elements}, 'span');
      $self->_remove_minus_elements ($element_state);
      $HTMLTextChecker{check_end}->(@_);
    } else {
      $HTMLEmptyChecker{check_end}->(@_);
    }
  }, # check_end
}; # iframe

{
  my $keywords = $_Defs->{elements}->{(HTML_NS)}->{iframe}->{attrs}->{''}->{sandbox}->{keywords};
  $ElementAttrChecker->{(HTML_NS)}->{iframe}->{''}->{sandbox} = sub {
    ## Unordered set of space-separated tokens, ASCII case-insensitive.
    my ($self, $attr) = @_;
    my %word;
    for my $word (grep {length $_}
                  split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
      $word =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      unless ($word{$word}) {
        $word{$word} = 1;
        $self->{onerror}->(node => $attr,
                           type => 'word not allowed', value => $word,
                           level => 'm')
            unless $keywords->{$word}->{conforming};
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'duplicate token', value => $word,
                           level => 'm');
      }
    }
    if ($word{'allow-scripts'} and $word{'allow-same-origin'}) {
      $self->{onerror}->(node => $attr,
                         type => 'sandbox allow-same-origin allow-scripts',
                         level => 'w');
    }
  }; # <iframe sandbox="">
}

sub image_viewable ($;$) {
  if (@_ > 1) {
    $_[0]->{image_viewable} = $_[1];
  }
  return $_[0]->{image_viewable};
} # image_viewable

$Element->{+HTML_NS}->{img} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
      border => sub {
        my ($self, $attr) = @_;

        my $value = $attr->value;
        if ($value eq '0') {
          $self->{onerror}->(node => $attr,
                             type => 'img border:0',
                             level => 's'); # obsolete but conforming
        } else {
          if ($GetHTMLNonNegativeIntegerAttrChecker->(sub { 1 })->(@_)) {
            ## A non-negative integer.
            $self->{onerror}->(node => $attr,
                               type => 'img border:nninteger',
                               level => 'm');
          } else {
            ## Not a non-negative integer.
          }
        }
      }, # border
      localsrc => sub {
        my ($self, $attr) = @_;
        my $value = $attr->value;
        if ($value =~ /\A[1-9][0-9]*\z/) {
          #
        } elsif ($value =~ /\A[0-9A-Za-z]+\z/) {
          $self->{onerror}->(node => $attr,
                             type => 'localsrc:deprecated',
                             level => 's');
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'localsrc:invalid',
                             level => 'm');
        }
      },
      name => $NameAttrChecker,
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    my $long_attr = $el->get_attribute_node_ns
        (undef, 'generator-unable-to-provide-required-alt');

    if (defined $long_attr and not $long_attr->value eq '') {
      $self->{onerror}->(node => $long_attr,
                         type => 'invalid attribute value',
                         level => 'm');
    }

    unless ($el->has_attribute_ns (undef, 'alt')) {
      if (defined $long_attr or
          (($item->{parent_state}->{figure_embedded_count} || 0) == 1 and
           $item->{parent_state}->{has_figcaption_content}) or
          $self->image_viewable) {
        #
      } else {
        my $title = $el->get_attribute_ns (undef, 'title');
        $self->{onerror}->(node => $el,
                           type => 'attribute missing:alt',
                           level => 'm')
            unless defined $title and length $title;
      }
      $self->{onerror}->(node => $long_attr,
                         type => 'attribute not defined',
                         level => 'mh')
          if defined $long_attr;
    } else {
      $self->{onerror}->(node => $long_attr,
                         type => 'attribute not defined',
                         level => 'm')
          if defined $long_attr;
    }

    unless ($el->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }

    if (my $attr = $el->get_attribute_node_ns (undef, 'start')) {
      unless ($el->has_attribute_ns (undef, 'dynsrc')) {
        $self->{onerror}->(node => $attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }

    ## XXXresource: external resource check
  }, # check_attrs2
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    
    $NameAttrCheckEnd->(@_);
    $HTMLEmptyChecker{check_end}->(@_);
  }, # check_end
}; # img

# XXX <img srcset>

$Element->{+HTML_NS}->{embed} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $NameAttrChecker,
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    unless ($item->{node}->has_attribute_ns (undef, 'src')) {
      if ($item->{node}->has_attribute_ns (undef, 'itemprop')) {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'src',
                           level => 'm');
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'src',
                           level => 'i');
      }
    }

    for (qw(align border hspace vspace name)) {
      my $attr = $item->{node}->get_attribute_node_ns (undef, $_);
      $self->{onerror}->(node => $attr,
                         type => 'attribute not defined',
                         level => $_ eq 'border' ? 'w' : 'm')
          if $attr;
    }

    ## XXXresource: external resource check
  }, # check_attrs2
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    
    $NameAttrCheckEnd->(@_); # for <embed name>
    $HTMLEmptyChecker{check_end}->(@_);
  }, # check_end
}; # embed

$Element->{+HTML_NS}->{noembed} = {
  %HTMLTextChecker, # XXX content model restriction (same as iframe)
}; # noembed

$Element->{+HTML_NS}->{object} = {
  %TransparentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    # XXX classid="" MUST be absolute
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    my $has_data = $el->has_attribute_ns (undef, 'data');
    my $has_type = $el->has_attribute_ns (undef, 'type');
    if (not $has_data and not $has_type) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing:data|type',
                         level => 'm');
    } elsif (not $has_data and $el->has_attribute_ns (undef, 'itemprop')) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing',
                         text => 'data',
                         level => 'm');
    }

    if ($has_data and $has_type) {
      unless ($el->has_attribute_ns (undef, 'typemustmatch')) {
        ## Strictly speaking, if |data|'s origin is same as the
        ## document's origin, this warning is not useful enough.
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => 'typemustmatch',
                           level => 'w');
      }
    } else {
      my $tmm = $el->get_attribute_node_ns (undef, 'typemustmatch');
      if ($tmm) {
        $self->{onerror}->(node => $tmm,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }

    if ($el->has_attribute_ns (undef, 'classid')) {
      unless ($el->has_attribute_ns (undef, 'codetype')) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => 'codetype',
                           level => 's');
      }
    }
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{id_type} = 'object';
    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
      $element_state->{has_non_legend} = 1;
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'param') {
      if ($element_state->{has_non_param}) {
        my $type = $self->{flag}->{in_phrasing}
            ? 'element not allowed:phrasing'
            : 'element not allowed:flow';
        $self->{onerror}->(node => $child_el, 
                           type => $type,
                           level => 'm');
      }
    } else {
      $element_state->{has_non_param} = 1;
      $TransparentChecker{check_child_element}->(@_);
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $element_state->{has_non_param} = 1;
    }
    $TransparentChecker{check_child_text}->(@_);
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{onerror}->(node => $item->{node},
                       level => 's',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
    $TransparentChecker{check_end}->(@_);
  }, # check_end
}; # object

$Element->{+HTML_NS}->{applet} = {
  %{$Element->{+HTML_NS}->{object}},
  check_attrs => $GetHTMLAttrsChecker->({
    name => $NameAttrChecker,
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    unless ($el->has_attribute_ns (undef, 'code')) {
      unless ($el->has_attribute_ns (undef, 'object')) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing:code|object',
                           level => 'm');
      }
    }
    
    for my $attr_name (qw(width height)) {
      ## |width| and |height| are REQUIRED according to HTML4.
      unless ($el->has_attribute_ns (undef, $attr_name)) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => $attr_name,
                           level => 'm');
      }
    }
  }, # check_attrs2
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $Element->{+HTML_NS}->{object}->{check_end}->(@_);
    $NameAttrCheckEnd->(@_); # for <img name>
  }, # check_end
}; # applet

$Element->{+HTML_NS}->{param}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  unless ($item->{node}->has_attribute_ns (undef, 'name')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'name',
                       level => 'm');
  }
  unless ($item->{node}->has_attribute_ns (undef, 'value')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'value',
                       level => 'm');
  }
}; # check_attrs2

$Element->{+HTML_NS}->{video} =
$Element->{+HTML_NS}->{audio} = {
  %TransparentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{allow_source}
        = not $item->{node}->has_attribute_ns (undef, 'src');
    $element_state->{allow_track} = 1;
    $element_state->{has_source} ||= $element_state->{allow_source} * -1;
      ## NOTE: It might be set true by |check_element|.

    $element_state->{in_media_orig} = $self->{flag}->{in_media};
    $self->{flag}->{in_media} = 1;

    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'itemprop') and
        not $item->{node}->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }

    my $ap_attr = $item->{node}->get_attribute_node_ns (undef, 'autoplay');
    if (defined $ap_attr) {
      $self->{onerror}->(node => $ap_attr,
                         type => 'autoplay',
                         level => 'w');
      my $pre_attr = $item->{node}->get_attribute_node_ns (undef, 'preload');
      $self->{onerror}->(node => $pre_attr,
                         type => 'autoplay:preload',
                         level => 'w')
          if defined $pre_attr;
    }
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
      delete $element_state->{allow_source};
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'source') {
      unless ($element_state->{allow_source}) {
        my $type = $self->{flag}->{in_phrasing}
            ? 'element not allowed:phrasing'
            : 'element not allowed:flow';
        $self->{onerror}->(node => $child_el,
                           type => $type,
                           level => 'm');
      }
      $element_state->{has_source} = 1;
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'track') {
      unless ($element_state->{allow_track}) {
        my $type = $self->{flag}->{in_phrasing}
            ? 'element not allowed:phrasing'
            : 'element not allowed:flow';
        $self->{onerror}->(node => $child_el,
                           type => $type,
                           level => 'm');
      }
      delete $element_state->{allow_source};
    } else {
      delete $element_state->{allow_source};
      delete $element_state->{allow_track};
      $TransparentChecker{check_child_element}->(@_);
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      delete $element_state->{allow_source};
      delete $element_state->{allow_track};
    }
    $TransparentChecker{check_child_text}->(@_);
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{in_media} unless $element_state->{in_media_orig};
    
    if ($element_state->{has_source} == -1) { 
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'source',
                         level => 'w');
    }
    
    $self->{onerror}->(node => $item->{node},
                       type => 'no significant content',
                       level => 's')
        unless $element_state->{has_palpable};

    $TransparentChecker{check_end}->(@_);
  }, # check_end
}; # video, audio

$Element->{+HTML_NS}->{source}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  unless ($item->{node}->has_attribute_ns (undef, 'src')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'src',
                       level => 'm');
  }
}; # source - check_attrs2

$Element->{+HTML_NS}->{track} = {
  %HTMLEmptyChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    unless ($el->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $el,
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }

    my $kind = $el->get_attribute_ns (undef, 'kind') || '';
    $kind =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    unless ({
      captions => 1, descriptions => 1, chapters => 1, metadata => 1,
    }->{$kind}) { # subtitles
      unless ($el->has_attribute_ns (undef, 'srclang')) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => 'srclang',
                           level => 'm');
      }
      $kind = 'subtitles';
    }

    my $srclang = $el->get_attribute_ns (undef, 'srclang');
    $srclang = defined $srclang ? ':' . $srclang : '';
    $srclang =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

    my $label = $el->get_attribute_ns (undef, 'label');
    $label = defined $label ? ':' . $label : '';
    
    if ($item->{parent_state}->{has_track_kind}->{$kind}->{$srclang}->{$label}) {
      $self->{onerror}->(node => $el,
                         type => 'duplicate track',
                         level => 'm');
    } else {
      $item->{parent_state}->{has_track_kind}->{$kind}->{$srclang}->{$label} = 1;
    }

    unless ($kind eq 'metadata') {
      if ($el->has_attribute_ns (undef, 'default')) {
        if ($item->{parent_state}->{has_default_track}->{$kind eq 'captions' ? 'subtitles' : $kind}) {
          $self->{onerror}->(node => $el,
                             type => 'duplicate default track',
                             level => 'm');
        } else {
          $item->{parent_state}->{has_default_track}->{$kind eq 'captions' ? 'subtitles' : $kind} = 1;
        }
      }
    }
  }, # check_attrs2
}; # track

$Element->{+HTML_NS}->{bgsound} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    balance => sub {
      my ($self, $attr) = @_;

      ## A valid integer.

      if ($attr->value =~ /\A(-?[0-9]+)\z/) {
        my $n = 0+$1;
        if (-10000 <= $n and $n <= 10000) {
          #
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'integer:out of range',
                             level => 'm');
        }
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'integer:syntax error',
                           level => 'm');
      }
    }, # balance
    loop => $LegacyLoopChecker,
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    unless ($item->{node}->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }
  }, # check_attrs2
}; # bgsound

$Element->{+HTML_NS}->{canvas} = {
  %TransparentChecker,

  # Authors MUST provide alternative content (HTML5 revision 2868) -
  # This requirement cannot be checked, since the alternative content
  # might be placed outside of the element.

  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $self->_add_minus_elements
        ($element_state,
         $_Defs->{categories}->{'interactive content'}->{elements},
         $_Defs->{categories}->{'interactive content'}->{elements_with_exceptions});
    $element_state->{in_canvas_orig} = $self->{flag}->{in_canvas};
    $self->{flag}->{in_canvas} = 1;
    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->_remove_minus_elements ($element_state);
    delete $self->{flag}->{in_canvas} unless $element_state->{in_canvas_orig};
    $TransparentChecker{check_end}->(@_);
  }, # check_end
}; # canvas

$Element->{+HTML_NS}->{map} = {
  %TransparentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => sub {
      my ($self, $attr) = @_;
      my $value = $attr->value;
      my $value_compat = lc $value; ## XXX compatibility caseless match
      if (length $value) {
        if ($value =~ /[\x09\x0A\x0C\x0D\x20]/) {
          $self->{onerror}->(node => $attr,
                             type => 'space in map name',
                             level => 'm');
        }
        
        if ($self->{map_compat}->{$value_compat}) {
          $self->{onerror}->(node => $attr,
                             type => 'duplicate map name',
                             value => $value,
                             level => 'm');
        }
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'empty attribute value',
                           level => 'm');
      }
      $self->{map_exact}->{$value} ||= $attr;
      $self->{map_compat}->{$value_compat} ||= $attr;
    },
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $name = $item->{node}->get_attribute_ns (undef, 'name');
    if (defined $name) {
      my $id = $item->{node}->get_attribute_ns (undef, 'id');
      if (defined $id and not $name eq $id) {
        $self->{onerror}
            ->(node => $item->{node}->get_attribute_node_ns (undef, 'id'),
               type => 'id ne name',
               level => 'm');
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'name',
                         level => 'm');
    }
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{in_map_original} = $self->{flag}->{in_map};
    $self->{flag}->{in_map} = [@{$self->{flag}->{in_map} or []}, {}];
        ## NOTE: |{in_map}| is a reference to the array which contains
        ## hash references.  Hashes are corresponding to the opening
        ## |map| elements and each of them contains the key-value
        ## pairs corresponding to the absolute URLs for the processed
        ## |area| elements in the |map| element corresponding to the
        ## hash.  The key represents the resource (## TODO: use
        ## absolute URL), while the value represents whether there is
        ## an |area| element whose |alt| attribute is specified to a
        ## non-empty value.  If there IS such an |area| element for
        ## the resource specified by the key, then the value is set to
        ## zero (|0|).  Otherwise, if there is no such an |area|
        ## element but there is any |area| element with the empty
        ## |alt=""| attribute, then the value contains an array
        ## reference that contains all of such |area| elements.
    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    
    for (keys %{$self->{flag}->{in_map}->[-1]}) {
      my $nodes = $self->{flag}->{in_map}->[-1]->{$_};
      next unless $nodes;
      for (@$nodes) {
        $self->{onerror}->(type => 'empty area alt',
                           node => $_,
                           level => 'm'); # MAY be left blank if...
      }
    }
    
    $self->{flag}->{in_map} = $element_state->{in_map_original};
    
    $TransparentChecker{check_end}->(@_);
  }, # check_end
}; # map

$Element->{+HTML_NS}->{area} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    alt => sub { }, ## Checked later.
    coords => sub { }, ## Checked in $ShapeCoordsChecker
    rel => sub {}, ## Checked in check_attrs2
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $rel_attr = $item->{node}->get_attribute_node_ns (undef, 'rel');
    $HTMLLinkTypesAttrChecker->(1, $item, $self, $rel_attr, $item, $element_state)
        if $rel_attr;

    my %attr;
    for my $attr (@{$item->{node}->attributes}) {
      my $attr_ns = $attr->namespace_uri;
      $attr_ns = '' unless defined $attr_ns;
      my $attr_ln = $attr->local_name;
      $attr{$attr_ln} = $attr if $attr_ns eq '';
    }

    if (defined $attr{href}) {
      $self->{has_hyperlink_element} = 1;
      if (defined $attr{alt}) {
        my $url = $attr{href}->value; ## TODO: resolve
        if (length $attr{alt}->value) {
          for (@{$self->{flag}->{in_map} or []}) {
            $_->{$url} = 0;
          }
        } else {
          ## NOTE: Empty |alt=""|.  If there is another |area| element
          ## with the same |href=""| and that |area| elemnet's
          ## |alt=""| attribute is not an empty string, then this
          ## is conforming.
          for (@{$self->{flag}->{in_map} or []}) {
            push @{$_->{$url} ||= []}, $attr{alt}
                unless exists $_->{$url} and not $_->{$url};
          }
        }
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'alt',
                           level => 'm');
      }
    } else {
      for (qw/target ping rel hreflang type alt/) {
        if (defined $attr{$_}) {
          $self->{onerror}->(node => $attr{$_},
                             type => 'attribute not allowed',
                             level => 'm');
        }
      }

      if (defined $attr{itemprop}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'href',
                           level => 'm');
      }
    }

    $ShapeCoordsChecker->($self, $item, \%attr, 'rectangle');
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    if (not ($self->{flag}->{in_map} or $self->{flag}->{is_template}) and
        $item->{node}->manakai_parent_element) {
      $self->{onerror}->(node => $item->{node},
                         type => 'element not allowed:area',
                         level => 'm');
    }
  },
}; # area

# ---- Tabular data ----

$Element->{+HTML_NS}->{table} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = 'before caption';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } elsif ($element_state->{phase} eq 'in tbodys') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'tbody') {
        #$element_state->{phase} = 'in tbodys';
      } elsif (not $element_state->{has_tfoot} and
               $child_nsuri eq HTML_NS and $child_ln eq 'tfoot') {
        $element_state->{phase} = 'after tfoot';
        $element_state->{has_tfoot} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'in trs') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
        #$element_state->{phase} = 'in trs';
      } elsif (not $element_state->{has_tfoot} and
               $child_nsuri eq HTML_NS and $child_ln eq 'tfoot') {
        $element_state->{phase} = 'after tfoot';
        $element_state->{has_tfoot} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'after thead') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'tbody') {
        $element_state->{phase} = 'in tbodys';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
        $element_state->{phase} = 'in trs';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tfoot') {
        $element_state->{phase} = 'in tbodys';
        $element_state->{has_tfoot} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'in colgroup') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'colgroup') {
        $element_state->{phase} = 'in colgroup';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'thead') {
        $element_state->{phase} = 'after thead';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tbody') {
        $element_state->{phase} = 'in tbodys';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
        $element_state->{phase} = 'in trs';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tfoot') {
        $element_state->{phase} = 'in tbodys';
        $element_state->{has_tfoot} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'before caption') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'caption') {
        $element_state->{phase} = 'in colgroup';
        if (($item->{parent_state}->{figure_table_count} || 0) == 1 and
            not $item->{parent_state}->{figure_has_non_table}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:figure table caption',
                             level => 's');
        }
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'colgroup') {
        $element_state->{phase} = 'in colgroup';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'thead') {
        $element_state->{phase} = 'after thead';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tbody') {
        $element_state->{phase} = 'in tbodys';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
        $element_state->{phase} = 'in trs';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tfoot') {
        $element_state->{phase} = 'in tbodys';
        $element_state->{has_tfoot} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'after tfoot') {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    } else {
      die "check_child_element: Bad |table| phase: $element_state->{phase}";
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## Table model errors

    require Web::HTML::Table;
    my $tbl = Web::HTML::Table->new;
    $tbl->onerror ($self->{onerror});
    my $table = $tbl->form_table ($item->{node});

    my @headers_cell;
    for my $x (0..$#{$table->{cell}}) {
      for my $y (0..$#{$table->{cell}->[$x]}) {
        my $cell = $table->{cell}->[$x]->[$y] or next;
        $cell = $cell->[0];
        next unless $cell->{x} == $x;
        next unless $cell->{y} == $y;

        push @headers_cell, $cell if $cell->{header_ids};
      }
    }

    my @id;
    for my $headers_cell (@headers_cell) {
      my $headers_attr = $headers_cell->{element}->get_attribute_node_ns
          (undef, 'headers');
      my %word;
      for my $word (@{$headers_cell->{header_ids}}) {
        unless ($word{$word}) {
          my $referenced_cell = $table->{id_cell}->{$word};
          if ($referenced_cell) {
            if ($referenced_cell->{element}->local_name eq 'th') {
              push @id, $word;
            } else {
              $self->{onerror}->(node => $headers_attr,
                                 value => $word,
                                 type => 'not th',
                                 level => 'm');
            }
          } else {
            $self->{onerror}->(node => $headers_attr,
                               value => $word,
                               type => 'no referenced header cell',
                               level => 'm');
          }
          $word{$word} = 1;
        } else {
          $self->{onerror}->(node => $headers_attr,
                             value => $word,
                             type => 'duplicate token',
                             level => 'm');
        }
      }

      my %checked_id;
      while (@id) {
        my $id = shift @id;
        next if $checked_id{$id};
        my $referenced_cell = $table->{id_cell}->{$id};
        if ($referenced_cell->{element} eq $headers_cell->{element}) {
          $self->{onerror}->(node => $headers_attr,
                             type => 'self targeted',
                             level => 'm');
          last;
        }
        push @id, @{$referenced_cell->{header_ids} or []};
        $checked_id{$id} = 1;
      }
    } # $headers_cell

    push @{$self->{return}->{table}}, $table;

    $AnyChecker{check_end}->(@_);
  }, # check_end

  # XXXwarn no tbody/tr child
  # XXXwarn tr child is not serializable as HTML
}; # table

# XXX sortable table

$Element->{+HTML_NS}->{colgroup} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    char => $CharChecker,
    width => sub {
      my ($self, $attr) = @_;
      unless ($attr->value =~ /\A(?>[0-9]+[%*]?|\*)\z/) {
        $self->{onerror}->(node => $attr,
                           type => 'multilength:syntax error',
                           level => 'm');
      }
    },
  }), # check_attrs
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and
             ($child_ln eq 'col' or $child_ln eq 'template')) {
      if ($item->{node}->has_attribute_ns (undef, 'span')) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:colgroup',
                           level => 'm');
      }
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:colgroup',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed:colgroup',
                         level => 'm');
    }
  },
}; # colgroup

$Element->{+HTML_NS}->{col} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    char => $CharChecker,
  }), # check_attrs
}; # col

$Element->{+HTML_NS}->{tbody} = {
  %AnyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    char => $CharChecker,
  }), # check_attrs
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
      #
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
}; # tbody

$Element->{+HTML_NS}->{thead} = {
  %{$Element->{+HTML_NS}->{tbody}},
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{in_thead} = 1;
    $AnyChecker{check_start}->(@_);
  }, # check_start
}; # thead

$Element->{+HTML_NS}->{tfoot} = {
  %{$Element->{+HTML_NS}->{tbody}},
}; # tfoot

$Element->{+HTML_NS}->{tr} = {
  %AnyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    char => $CharChecker,
  }), # check_attrs
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'td') {
      #
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'th') {
      #
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
}; # tr

$Element->{+HTML_NS}->{td} = {
  %HTMLFlowContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    char => $CharChecker,
    headers => sub {
      ## NOTE: Will be checked as part of |table| element checker.
      ## Although the conformance of |headers| attribute is not
      ## checked if the element does not form a part of a table, the
      ## element is non-conforming in that case anyway.
    },
  }),
}; # td

$ElementAttrChecker->{(HTML_NS)}->{th}->{''}->{char} = $CharChecker;

$ElementAttrChecker->{(HTML_NS)}->{th}->{''}->{headers} = sub {};
## NOTE: Will be checked as part of |table| element checker.  Although
## the conformance of |headers| attribute is not checked if the
## element does not form a part of a table, the element is
## non-conforming in that case anyway.

# ------ Forms ------

$Element->{+HTML_NS}->{form} = {
  %HTMLFlowContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    ## XXX warning: action="" URL scheme is not submittable
    name => sub {
      my ($self, $attr) = @_;
      
      my $value = $attr->value;
      if ($value eq '') {
        $self->{onerror}->(type => 'empty form name',
                           node => $attr,
                           level => 'm');
      } else {
        if ($self->{form}->{$value}) {
          $self->{onerror}->(type => 'duplicate form name',
                             node => $attr,
                             value => $value,
                             level => 'm');
        } else {
          $self->{form}->{$value} = 1;
        }
      }
    },
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    my $target_attr = $el->get_attribute_node_ns (undef, 'target');
    if ($target_attr) {
      for (qw(lcs utn)) {
        if ($el->has_attribute_ns (undef, $_)) {
          $self->{onerror}->(node => $target_attr,
                             type => 'attribute not allowed',
                             level => 'm');
          last;
        }
      }
    }
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{id_type} = 'form';
    $HTMLFlowContentChecker{check_start}->(@_);
  },
}; # form

# XXX warn if there is no ancestor <dialog> of <form method=dialog> or
# of <form> of <input/button formmethod=dialog>

$Element->{+HTML_NS}->{fieldset} = {
  %HTMLFlowContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $FormControlNameAttrChecker,
  }), # check_attrs
  ## Optional |legend| element, followed by flow content.
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'legend') {
      if ($element_state->{in_flow_content}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      } else {
        $element_state->{in_flow_content} = 1;
      }
    } else { # flow content
      if ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow style',
                           level => 'm')
            if $element_state->{has_non_style};
        $element_state->{in_flow_content} = 1;
      } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
               $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{has_non_style} = 1;
        $element_state->{in_flow_content} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $element_state->{in_flow_content} = 1;
      $element_state->{has_non_style} = 1;
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{onerror}->(node => $item->{node},
                       level => 's',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # fieldset

$Element->{+HTML_NS}->{label} = {
  %HTMLPhrasingContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $self->_add_minus_elements ($element_state, {(HTML_NS) => {label => 1}});

    ## If $self->{flag}->{has_label} is true, then there is at least
    ## an ancestor |label| element.

    ## If $self->{flag}->{has_labelable} is equal to 1, then there is
    ## an ancestor |label| element with its |for| attribute specified.
    ## If the value is equal to 2, then there is an ancestor |label|
    ## element with its |for| attribute unspecified but there is an
    ## associated form control element.

    $element_state->{has_label_original} = $self->{flag}->{has_label};
    $element_state->{has_labelable_original} = $self->{flag}->{has_labelable};
    $element_state->{label_for_original} = $self->{flag}->{label_for};

    $self->{flag}->{has_label} = 1;
    $self->{flag}->{has_labelable}
        = $item->{node}->has_attribute_ns (undef, 'for') ? 1 : 0;
    $self->{flag}->{label_for}
        = $item->{node}->get_attribute_ns (undef, 'for');

    $HTMLPhrasingContentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->_remove_minus_elements ($element_state);
    
    if ($self->{flag}->{has_labelable} == 1) { # has for="" but no labelable
      $self->{flag}->{has_labelable}
          = $element_state->{has_labelable_original};
    }
    delete $self->{flag}->{has_label}
        unless $element_state->{has_label_original};
    $self->{flag}->{label_for} = $element_state->{label_for_original};

    ## TODO: Warn if no labelable descendant?

    $HTMLPhrasingContentChecker{check_end}->(@_);
  },
}; # label

# XXX
$CheckerByType->{'global date and time string'} = $GetDateTimeAttrChecker->('global_date_and_time_string');
$CheckerByType->{'date string'} = $GetDateTimeAttrChecker->('date_string');
$CheckerByType->{'month string'} = $GetDateTimeAttrChecker->('month_string');
$CheckerByType->{'week string'} = $GetDateTimeAttrChecker->('week_string');
$CheckerByType->{'time string'} = $GetDateTimeAttrChecker->('time_string');
$CheckerByType->{'local date and time string'} = $GetDateTimeAttrChecker->('local_date_and_time_string');
$CheckerByType->{'simple color'} = sub {
  my ($self, $attr) = @_;
  unless ($attr->value =~ /\A#[0-9A-Fa-f]{6}\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'scolor:syntax error',
                       level => 'm');
  }
};
$CheckerByType->{'one-line text'} = sub {
  my ($self, $attr) = @_;
  if ($attr->value =~ /[\x0D\x0A]/) {
    $self->{onerror}->(node => $attr,
                       type => 'newline in value',
                       level => 'm');
  }
};

$Element->{+HTML_NS}->{input} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    alt => sub {
      my ($self, $attr) = @_;
      my $value = $attr->value;
      unless (length $value) {
        $self->{onerror}->(node => $attr,
                           type => 'empty anchor image alt',
                           level => 'm');
      }
    }, # alt
    autocomplete => $GetHTMLEnumeratedAttrChecker->({ # XXX old
      on => 1, off => 1,
    }),
    format => $TextFormatAttrChecker,
    loop => $LegacyLoopChecker,
    max => sub {}, ## check_attrs2
    min => sub {}, ## check_attrs2
    name => $FormControlNameAttrChecker,
    precision => sub {
      my ($self, $attr) = @_;
      unless ($attr->value =~ /\A(?>[0-9]+(?>dp|sf)|integer|float)\z/) {
        $self->{onerror}->(node => $attr,
                           type => 'precision:syntax error',
                           level => 'm');
      }
    }, # precision
    ## XXXresource src="" referenced resource type
    value => sub {}, ## check_attrs2
    viblength => $GetHTMLNonNegativeIntegerAttrChecker->(sub {
      1 <= $_[0] and $_[0] <= 9;
    }),
  }),
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $input_type = $item->{node}->get_attribute_ns (undef, 'type');
    $input_type = 'text' unless defined $input_type;
    $input_type =~ tr/A-Z/a-z/;
    $input_type = 'text' unless $_Defs->{elements}
        ->{'http://www.w3.org/1999/xhtml'}->{input}->{attrs}
        ->{''}->{type}->{enumerated}->{$input_type}->{conforming};

    my $value_type = $_Defs->{input}->{attrs}->{value}->{$input_type};
    if (defined $value_type) {
      my $attr = $item->{node}->get_attribute_node_ns (undef, 'value');
      if (not $attr) {
        #
      } elsif ($input_type eq 'hidden') {
        my $name = $item->{node}->get_attribute_ns (undef, 'name');
        if (defined $name and $name eq '_charset_') { ## case-sensitive
          $self->{onerror}->(node => $attr,
                             type => '_charset_ value',
                             level => 'm');
        }
      } else {
        if ($attr->value ne '') {
          my $checker = $CheckerByType->{$value_type} || sub {
            ## Strictly speaking, this error type is wrong.
            $self->{onerror}->(node => $attr,
                               type => 'unknown attribute',
                               level => 'u');
          };
          $checker = $CheckerByType->{'e-mail address'}
              if $value_type eq 'email' and
                 not $item->{node}->has_attribute_ns (undef, 'multiple');
          $checker->($self, $attr, $item, $element_state);
        }
      }
    } # value=""
    for my $attr_name (qw(min max)) {
      next unless $_Defs->{input}->{attrs}->{$attr_name}->{$input_type};
      my $attr = $item->{node}->get_attribute_node_ns (undef, $attr_name)
          or next;
      my $checker = $CheckerByType->{$value_type} || sub {
        ## Strictly speaking, this error type is wrong.
        $self->{onerror}->(node => $attr,
                           type => 'unknown attribute',
                           level => 'u');
      };
      $checker->($self, $attr, $item, $element_state);
    } # min="" max=""

    if ($input_type eq 'number') {
      for my $attr_name (qw(maxlength size)) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, $attr_name);
        $self->{onerror}->(node => $attr,
                           type => 'attribute not allowed',
                           level => 's') # obsolete but conforming
            if $attr;
      }
    } elsif ($_Defs->{input}->{attrs}->{maxlength}->{$input_type}) {
      my $attr = $item->{node}->get_attribute_node_ns (undef, 'maxlength');
      if ($attr and $attr->value =~ /^[\x09\x0A\x0C\x0D\x20]*([0-9]+)/) {
        ## NOTE: Applying the rules for parsing non-negative integers
        ## results in a number.
        my $max_allowed_value_length = 0+$1;
        my $value = $item->{node}->get_attribute_ns (undef, 'value');
        if (defined $value) {
          my $codepoint_length = length $value;
          if ($codepoint_length > $max_allowed_value_length) {
            $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'value'),
                               type => 'value too long',
                               level => 'm');
          }
        }
      }
    } # maxlength=""
    # XXX minlength=""

    if ($_Defs->{input}->{attrs}->{pattern}->{$input_type} and
        $item->{node}->has_attribute_ns (undef, 'pattern')) {
      $element_state->{require_title} ||= 's';
    } # pattern=""

    ## XXX warn <input type=hidden disabled>
    ## XXX warn <input type=hidden> (no name="")
    ## XXX warn <input type=hidden name=_charset_> (no value="")
    ## XXX <input type=radio name="">'s name="" MUST be unique
    ## XXX war if multiple <input type=radio checked>
    ## XXX <input type=image> requires alt="" and src=""
    ## XXX <input type=url value> MUST be absolute IRI.
    ## XXX warn <input type=file> without enctype="multipart/form-data"

    my $el = $item->{node};

    if ($input_type eq 'button') {
      unless ($el->get_attribute_node_ns (undef, 'value')) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => 'value',
                           level => 'm');
      }
    } elsif ($input_type eq 'range') {
      $element_state->{number_value}->{min} ||= 0;
      $element_state->{number_value}->{max} = 100
          unless defined $element_state->{number_value}->{max};
    } elsif ($input_type eq 'submit') {
      my $dk_attr = $el->get_attribute_node_ns (undef, 'directkey');
      if ($dk_attr) {
        unless ($el->has_attribute_ns (undef, 'value')) {
          $self->{onerror}->(node => $dk_attr,
                             type => 'attribute missing',
                             text => 'value',
                             level => 'm');
        }
      }

      unless ($el->has_attribute_ns (undef, 'src')) {
        for (qw(volume soundstart)) {
          my $attr = $el->get_attribute_node_ns (undef, $_);
          if ($attr) {
            $self->{onerror}->(node => $attr,
                               type => 'attribute not allowed',
                               level => 'm');
          }
        }
      }
    } elsif ($input_type eq 'image') {
      if (my $attr = $el->get_attribute_node_ns (undef, 'start')) {
        unless ($el->has_attribute_ns (undef, 'dynsrc')) {
          $self->{onerror}->(node => $attr,
                             type => 'attribute not allowed',
                             level => 'm');
        }
      }
    }

    my $vl_attr = $el->get_attribute_node_ns (undef, 'viblength');
    if ($vl_attr) {
      unless ($el->has_attribute_ns (undef, 'vibration')) {
        $self->{onerror}->(node => $vl_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }

    if (defined $element_state->{date_value}->{min} or
        defined $element_state->{date_value}->{max}) {
      my $min_value = $element_state->{date_value}->{min};
      my $max_value = $element_state->{date_value}->{max};
      my $value_value = $element_state->{date_value}->{value};

      if (defined $min_value and $min_value eq '' and
          (defined $max_value or defined $value_value)) {
        my $min = $item->{node}->get_attribute_node_ns (undef, 'min');
        $self->{onerror}->(node => $min,
                           type => 'date value not supported', ## TODOC: type
                           value => $min->value,
                           level => 'u');
        undef $min_value;
      }
      if (defined $max_value and $max_value eq '' and
          (defined $max_value or defined $value_value)) {
        my $max = $item->{node}->get_attribute_node_ns (undef, 'max');
        $self->{onerror}->(node => $max,
                           type => 'date value not supported', ## TODOC: type
                           value => $max->value,
                           level => 'u');
        undef $max_value;
      }
      if (defined $value_value and $value_value eq '' and
          (defined $max_value or defined $min_value)) {
        my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
        $self->{onerror}->(node => $value,
                           type => 'date value not supported', ## TODOC: type
                           value => $value->value,
                           level => 'u');
        undef $value_value;
      }

      if (defined $min_value and defined $max_value) {
        if ($min_value->to_html_number > $max_value->to_html_number) {
          my $max = $item->{node}->get_attribute_node_ns (undef, 'max');
          $self->{onerror}->(node => $max,
                             type => 'max lt min',
                             level => 'm');
        }
      }
      
      if (defined $min_value and defined $value_value) {
        if ($min_value->to_html_number > $value_value->to_html_number) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value lt min',
                             level => 'w');
          ## NOTE: Not an error.
        }
      }
      
      if (defined $max_value and defined $value_value) {
        if ($max_value->to_html_number < $value_value->to_html_number) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value gt max',
                             level => 'w');
          ## NOTE: Not an error.
        }
      }
    } elsif (defined $element_state->{number_value}->{min} or
             defined $element_state->{number_value}->{max}) {
      my $min_value = $element_state->{number_value}->{min};
      my $max_value = $element_state->{number_value}->{max};
      my $value_value = $element_state->{number_value}->{value};

      if (defined $min_value and defined $max_value) {
        if ($min_value > $max_value) {
          my $attr = $item->{node}->get_attribute_node_ns (undef, 'max')
              || $item->{node}->get_attribute_node_ns (undef, 'min');
          $self->{onerror}->(node => $attr,
                             type => 'max lt min',
                             level => 'm');
        }
      }
      
      if (defined $min_value and defined $value_value) {
        if ($min_value > $value_value) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value lt min',
                             level => 'w');
          ## NOTE: Not an error.
        }
      }
      
      if (defined $max_value and defined $value_value) {
        if ($max_value < $value_value) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value gt max',
                             level => 'w');
          ## NOTE: Not an error.
        }
      }
    }
    
    ## TODO: Warn unless value = min * x where x is an integer.

    ## XXXresource: Dimension attributes have requirements on width
    ## and height of referenced resource.

    $FAECheckAttrs2->($self, $item, $element_state);
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckStart->($self, $item, $element_state);
  }, # check_start
}; # input

$ElementAttrChecker->{(HTML_NS)}->{input}->{''}->{accept} = sub {
  my ($self, $attr) = @_;
  
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive

  ## A set of comma-separated tokens.
  my @value = length $value ? split /,/, $value, -1 : ();

  my %has_value;
  for my $v (@value) {
    $v =~ s/^[\x09\x0A\x0C\x0D\x20]+//; # space characters
    $v =~ s/[\x09\x0A\x0C\x0D\x20]+\z//; # space characters

    if ($has_value{$v}) {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token',
                         value => $v,
                         level => 'm');
      next;
    }
    $has_value{$v} = 1;
    
    if ($v eq 'audio/*' or $v eq 'video/*' or $v eq 'image/*' or $v =~ /^\./) {
      #
    } else {
      require Web::MIME::Type;
      my $onerror = sub {
        $self->{onerror}->(value => $v, @_, node => $attr);
      };
      
      ## Syntax-level validation
      my $type = Web::MIME::Type->parse_web_mime_type ($v, $onerror);

      if ($type) {
        if (@{$type->attrs}) {
          $self->{onerror}->(node => $attr,
                             type => 'IMT:no param allowed',
                             level => 'm');
        }
        
        ## Vocabulary-level validation
        $type->validate ($onerror, no_required_param => 1);
      }
    }
  }
}; # <input accept="">

# XXX warning for inputmode="tel|email|url"

$Element->{+HTML_NS}->{button} = {
  %HTMLPhrasingContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $FormControlNameAttrChecker,
  }), # check_attrs
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckStart->($self, $item, $element_state);

    $element_state->{no_interactive_original}
        = $self->{flag}->{no_interactive};
    $self->{flag}->{no_interactive} = 1;

    $HTMLPhrasingContentChecker{check_start}->(@_);
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckAttrs2->($self, $item, $element_state);

    my $type = $item->{node}->get_attribute_ns (undef, 'type') || '';
    $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive
    if ($type eq 'button' or $type eq 'reset') {
      for (
        $item->{node}->get_attribute_node_ns (undef, 'formaction'),
        $item->{node}->get_attribute_node_ns (undef, 'formmethod'),
        $item->{node}->get_attribute_node_ns (undef, 'formnovalidate'),
        $item->{node}->get_attribute_node_ns (undef, 'formenctype'),
        $item->{node}->get_attribute_node_ns (undef, 'formtarget'),
      ) {
        next unless $_;
        $self->{onerror}->(node => $_,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }
    my $menu_attr = $item->{node}->get_attribute_node_ns (undef, 'menu');
    if ($type eq 'menu') {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'menu',
                         level => 'm') unless $menu_attr;
    } else {
      $self->{onerror}->(node => $menu_attr,
                         type => 'attribute not allowed',
                         level => 'm') if $menu_attr;
    }
  }, # check_attrs2
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{no_interactive}
        unless $element_state->{no_interactive_orig};

    $HTMLPhrasingContentChecker{check_end}->(@_);
  }, # check_end
}; # button

$Element->{+HTML_NS}->{select} = {
  %AnyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $FormControlNameAttrChecker,
  }), # check_attrs
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckStart->($self, $item, $element_state);

    $element_state->{has_option_selected_orig}
        = $self->{flag}->{has_option_selected}
        unless $self->{flag}->{in_select_single};
    $element_state->{in_select_single_orig}
        = $self->{flag}->{in_select_single};
    $self->{flag}->{in_select_single}
        = not $item->{node}->has_attribute_ns (undef, 'multiple');
    $element_state->{in_select_orig} = $self->{flag}->{in_select};
    $self->{flag}->{in_select} = 1;
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckAttrs2->($self, $item, $element_state);

    my $el = $item->{node};
    if ($el->has_attribute_ns (undef, 'required') and
        not $el->has_attribute_ns (undef, 'multiple')) {
      ## Display size of the |select| element
      my $size = $el->get_attribute_ns (undef, 'size');
      if (not defined $size or
          ## Rules for parsing non-negative integers
          $size =~ /\A[\x09\x0A\x0C\x0D\x20]*(\+?[0-9]+|-0+)/) {
        $size = $1 || 1;
      } else {
        undef $size;
      }

      if (defined $size and $size == 1) {
        my $opt_el;

        ## Find the placeholder label option from list of options
        SELECT: for my $el (@{$el->child_nodes}) {
          next SELECT unless $el->node_type == 1;
          my $nsurl = $el->namespace_uri;
          next SELECT unless defined $nsurl;
          next SELECT unless $nsurl eq HTML_NS;
          my $ln = $el->local_name;
          if ($ln eq 'option') {
            $opt_el = $el;
            last SELECT;
          } elsif ($ln eq 'optgroup') {
            for my $el (@{$el->child_nodes}) {
              next unless $el->node_type == 1;
              my $nsurl = $el->namespace_uri;
              next unless defined $nsurl;
              next unless $nsurl eq HTML_NS;
              if ($el->local_name eq 'option') {
                last SELECT;
              }
            }
          }
        }
        my $value = $opt_el ? $opt_el->get_attribute_ns (undef, 'value') : undef;
        if (not defined $value and $opt_el) {
          $value = $opt_el->text_content;
          $value =~ s/^[\x09\x0A\x0C\x0D\x20]+//;
        }
        if (defined $value and $value eq '') {
          #
        } else {
          $self->{onerror}->(node => $el,
                             type => 'no placeholder label option',
                             level => 'm');
        }
      }
    }
  }, # check_attrs2
  check_child_element => sub {
    ## NOTE: (option | optgroup)*

    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and
             ($child_ln eq 'option' or $child_ln eq 'optgroup')) {
      #
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $self->{flag}->{in_select_single}
        = $element_state->{in_select_single_orig};
    $self->{flag}->{in_select} = $element_state->{in_select_orig};
    delete $self->{flag}->{has_option_selected}
        unless $self->{flag}->{in_select_single};
    
    $AnyChecker{check_end}->(@_);
  }, # check_end
}; # select

$Element->{+HTML_NS}->{datalist} = {
  %HTMLPhrasingContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    $element_state->{phase} = 'any'; # any | phrasing | option

    $element_state->{id_type} = 'datalist';

    $HTMLPhrasingContentChecker{check_start}->(@_);
  },
  ## NOTE: phrasing | option*
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'phrasing') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:phrasing',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'option') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'option') {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'any') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{phase} = 'phrasing';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'option') {
        $element_state->{phase} = 'option';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');        
      }
    } else {
      die "check_child_element: Bad |datalist| phase: $element_state->{phase}";
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      if ($element_state->{phase} eq 'phrasing') {
        #
      } elsif ($element_state->{phase} eq 'any') {
        $element_state->{phase} = 'phrasing';
      } else {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed',
                           level => 'm');
      }
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{phase} eq 'phrasing') {
      #$HTMLPhrasingContentChecker{check_end}->(@_);
    } else {
      ## NOTE: Since the content model explicitly allows a |datalist| element
      ## being empty, we don't raise "no significant content" error for this
      ## element when there is no element.  (We should raise an error for
      ## |<datalist><br></datalist>|, however.)
      ## NOTE: As a side-effect, when the |datalist| element only contains
      ## non-conforming content, then the |phase| flag has not changed from
      ## |any|, no "no significant content" error is raised neither.
      $AnyChecker{check_end}->(@_);
    }
  }, # check_end
}; # datalist

$Element->{+HTML_NS}->{optgroup} = {
  %AnyChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    
    unless ($item->{node}->has_attribute_ns (undef, 'label')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'label',
                         level => 'm');
    }
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'option') {
      #
    } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
}; # optgroup

$Element->{+HTML_NS}->{option} = {
  %HTMLTextChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    my $selected_node = $el->get_attribute_node_ns (undef, 'selected');
    if ($selected_node) {
      if ($self->{flag}->{in_select_single} and
          $self->{flag}->{has_option_selected}) {
        $self->{onerror}->(node => $selected_node,
                           type => 'multiple selected in select1',
                           level => 'm');
      }
      $self->{flag}->{has_option_selected} = 1;
    }
  }, # check_attrs2
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'label')) {
      if ($item->{node}->has_attribute_ns (undef, 'value')) {
        $self->{onerror}->(node => $item->{node},
                           type => '<option label value> not empty',
                           level => 'm')
            if $element_state->{has_palpable};
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'no significant content',
                         level => 'm')
          unless $element_state->{has_palpable};
    }
    $HTMLTextChecker{check_end}->(@_);
  }, # check_end
}; # option

$Element->{+HTML_NS}->{textarea} = {
  %HTMLTextChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    format => $TextFormatAttrChecker,
    maxlength => sub {
      my ($self, $attr, $item, $element_state) = @_;
      
      $GetHTMLNonNegativeIntegerAttrChecker->(sub { 1 })->(@_);
      
      if ($attr->value =~ /^[\x09\x0A\x0C\x0D\x20]*(\+?[0-9]+|-0+)/) {
        ## NOTE: Applying the rules for parsing non-negative integers
        ## results in a number.
        my $max_allowed_value_length = 0+$1;

        ## ISSUE: This constraint is applied w/o CRLF normalization to
        ## |value| attribute, but w/ CRLF normalization to
        ## concept-value.
        my $value = $item->{node}->text_content;
        if (defined $value) {
          my $codepoint_length = length $value;
          
          if ($codepoint_length > $max_allowed_value_length) {
            $self->{onerror}->(node => $item->{node},
                               type => 'value too long',
                               level => 'm');
          }
        }
      }
    },
    name => $FormControlNameAttrChecker,
  }),
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckStart->($self, $item, $element_state);
  },
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    if ($item->{node}->has_attribute_ns (undef, 'pattern')) {
      $element_state->{require_title} ||= 's';
    }
    
    unless ($item->{node}->has_attribute_ns (undef, 'cols')) {
      my $wrap = $item->{node}->get_attribute_ns (undef, 'wrap');
      if (defined $wrap) {
        $wrap =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        if ($wrap eq 'hard') {
          $self->{onerror}->(node => $item->{node},
                             type => 'attribute missing',
                             text => 'cols',
                             level => 'm');
        }
      }
    }
    
    $FAECheckAttrs2->($self, $item, $element_state);
  }, # check_attrs2
}; # textarea

$Element->{+HTML_NS}->{keygen} = {
  %HTMLEmptyChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $FormControlNameAttrChecker,
  }), # check_attrs
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckStart->($self, $item, $element_state);
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    $FAECheckAttrs2->($self, $item, $element_state);

    my $el = $item->{node};
    my $keytype = $el->get_attribute_ns (undef, 'keytype') || '';
    $keytype =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
    if ($keytype eq 'dsa') {
      if ($el->has_attribute_ns (undef, 'keyparams')) {
        my $pqg_attr = $el->get_attribute_node_ns (undef, 'pqg');
        if ($pqg_attr) {
          $self->{onerror}->(node => $pqg_attr,
                             type => 'attribute not allowed',
                             level => 'm');
        }
      } else {
        unless ($el->has_attribute_ns (undef, 'pqg')) {
          $self->{onerror}->(node => $el,
                             type => 'attribute missing:keyparams|pqg',
                             level => 'm');
        }
      }
    } elsif ($keytype eq 'ec') {
      unless ($el->has_attribute_ns (undef, 'keyparams')) {
        $self->{onerror}->(node => $el,
                           type => 'attribute missing',
                           text => 'keyparams',
                           level => 'm');
      }
      my $pqg_attr = $el->get_attribute_node_ns (undef, 'pqg');
      if ($pqg_attr) {
        $self->{onerror}->(node => $pqg_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    } else {
      my $keyparams_attr = $el->get_attribute_node_ns (undef, 'keyparams');
      if ($keyparams_attr) {
        $self->{onerror}->(node => $keyparams_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
      my $pqg_attr = $el->get_attribute_node_ns (undef, 'pqg');
      if ($pqg_attr) {
        $self->{onerror}->(node => $pqg_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }
  }, # check_attrs2
}; # keygen

$Element->{+HTML_NS}->{output} = {
  %HTMLPhrasingContentChecker,
  check_attrs => $GetHTMLAttrsChecker->({
    name => $FormControlNameAttrChecker,
  }),
}; # output

# XXX labelable
$Element->{+HTML_NS}->{progress} = {
  %HTMLPhrasingContentChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $max = $element_state->{number_value}->{max};
    if (defined $max) {
      unless ($max > 0) {
        $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'max'),
                           type => 'float:out of range',
                           level => 'm');
      }
    } else {
      $max = 1.0;
    }

    my $value = $element_state->{number_value}->{value};
    if (defined $value) {
      unless ($value >= 0) {
        $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'value'),
                           type => 'float:out of range',
                           level => 'm');
      }
      unless ($value <= $max) {
        $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'value'),
                           type => 'progress value out of range',
                           value => "$value <= $max",
                           level => 'm');
      }
    }
  }, # check_attrs2

  ## "Authors are encouraged to include a textual representation" -
  ## This is not really testable.
}; # progress

## XXX labelable element
$Element->{+HTML_NS}->{meter} = {
  %HTMLPhrasingContentChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    
    my $value = $element_state->{number_value}->{value};
    if (not defined $value and
        not $item->{node}->has_attribute_ns (undef, 'value')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'value',
                         level => 'm');
      $value = 0;
    }
    $value ||= 0;
    my $min = $element_state->{number_value}->{min} || 0;
    my $max = $element_state->{number_value}->{max};
    $max = 1.0 unless defined $max;

    $self->{onerror}->(node => $item->{node},
                       type => 'meter:min > max',
                       value => "$min <= $max",
                       level => 'm')
        unless $min <= $max;
    for (
      [value => $value],
      [low => $element_state->{number_value}->{low}],
      [high => $element_state->{number_value}->{high}],
      [optimum => $element_state->{number_value}->{optimum}],
    ) {
      next unless defined $_->[1];
      $self->{onerror}->(node => $item->{node},
                         type => 'meter:out of range',
                         text => $_->[0],
                         value => "$min <= $_->[1] <= $max",
                         level => 'm')
          unless $min <= $_->[1] and $_->[1] <= $max;
    }
    if (defined $element_state->{number_value}->{low} and
        defined $element_state->{number_value}->{high}) {
      unless ($element_state->{number_value}->{low} <=
              $element_state->{number_value}->{high}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'meter:low > high',
                           value => "$element_state->{number_value}->{low} <= $element_state->{number_value}->{high}",
                           level => 'm');
      }
    }
  }, # check_attrs2

  ## "Authors are encouraged to also include the current value and the
  ## maximum value inline as text" - This is not really testable.
}; # meter

$ElementAttrChecker->{(HTML_NS)}->{input}->{''}->{autofocus} =
$ElementAttrChecker->{(HTML_NS)}->{button}->{''}->{autofocus} =
$ElementAttrChecker->{(HTML_NS)}->{select}->{''}->{autofocus} =
$ElementAttrChecker->{(HTML_NS)}->{textarea}->{''}->{autofocus} =
$ElementAttrChecker->{(HTML_NS)}->{keygen}->{''}->{autofocus} = sub {
  my ($self, $attr) = @_;

  ## A boolean attribute
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  $self->{onerror}->(node => $attr,
                     type => 'boolean:invalid',
                     level => 'm')
      unless $value eq '' or $value eq 'autofocus';

  if ($self->{flag}->{has_autofocus}) {
    $self->{onerror}->(node => $attr,
                       type => 'duplicate autofocus',
                       level => 'm');
  } else {
    $self->{flag}->{has_autofocus} = 1;
  }
}; # autofocus=""

# ------ Interactive elements ------

$Element->{+HTML_NS}->{details} = {
  %HTMLFlowContentChecker,
  ## The |summary| element followed by flow content.
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'summary') {
      if ($element_state->{in_flow_content}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
      $element_state->{in_flow_content} = 1;
      $element_state->{has_summary} = 1;
    } else { # flow content
      if ($child_nsuri eq HTML_NS and $child_ln eq 'style') {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow style',
                           level => 'm')
            if $element_state->{has_non_style};
        $element_state->{in_flow_content} = 1;
      } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
               $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{has_non_style} = 1;
        $element_state->{in_flow_content} = 1;
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $element_state->{in_flow_content} = 1;
      $element_state->{has_non_style} = 1;
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    unless ($element_state->{has_summary}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'summary',
                         level => 'm');
    }
    $self->{onerror}->(node => $item->{node},
                       level => 's',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # details

$Element->{+HTML_NS}->{menu} = {
  %AnyChecker,
  ## <menu type=toolbar>: (li | script-supporting)* | flow
  ## <menu type=popup>: (menuitem | hr | <menu type=popup> | script-supporting)*
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = $item->{node}->type; # "toolbar" or "popup"
      ## $element_state->{phase}
      ##   toolbar -> toolbar-li | toolbar-flow
      ##   toolbar-li
      ##   toolbar-flow
      ##   popup
    $element_state->{id_type} = 'popup' if $item->{node}->type eq 'popup';
    $AnyChecker{check_start}->(@_);
  }, # check_start
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $label_attr = $item->{node}->get_attribute_node_ns (undef, 'label');
    if ($label_attr) {
      my $parent = $item->{node}->parent_node;
      if ($parent and
          $parent->node_type == 1 and # ELEMENT_NODE
          $parent->manakai_element_type_match (HTML_NS, 'menu') and
          $parent->type eq 'popup') {
        #
      } else {
        $self->{onerror}->(node => $label_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($element_state->{phase} eq 'toolbar') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'li') {
        $element_state->{phase} = 'toolbar-li';
      } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
        #
      } elsif ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
               $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        $element_state->{phase} = 'toolbar-flow';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:menu type=toolbar',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'toolbar-li') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'li') {
        $element_state->{phase} = 'toolbar-li';
      } elsif ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:menu type=toolbar',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'toolbar-flow') {
      if ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:menu type=toolbar',
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'popup') {
      if (($child_nsuri eq HTML_NS and
           ($child_ln eq 'menuitem' or
            $child_ln eq 'hr' or
            ($child_ln eq 'menu' and
             not (($child_el->get_attribute_ns (undef, 'type') || '') =~ /\A[Tt][Oo][Oo][Ll][Bb][Aa][Rr]\z/)))) or # type=toolbar
          $_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:menu type=popup',
                           level => 'm');
      }
    } else {
      die "Bad phase: |$element_state->{phase}|";
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      if ($element_state->{phase} eq 'toolbar') {
        $element_state->{phase} = 'toolbar-flow';
      } elsif ($element_state->{phase} eq 'toolbar-flow') {
        #
      } else {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed',
                           level => 'm');
      }
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{phase} eq 'toolbar-flow') {
      $self->{onerror}->(node => $item->{node},
                         level => 's',
                         type => 'no significant content')
          unless $element_state->{has_palpable};
    }
    $AnyChecker{check_end}->(@_);
  }, # check_end
}; # menu

$Element->{+HTML_NS}->{menuitem} = {
  %HTMLEmptyChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'command')) {
      ## Indirect command mode.
      for (qw(type label icon disabled checked radiogroup)) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, $_) or next;
        $self->{onerror}->(node => $attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    } else {
      ## Explicit command mode.
      unless ($item->{node}->has_attribute_ns (undef, 'label')) {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'label',
                           level => 'm');
      }
    }

    my $type = $item->{node}->get_attribute_ns (undef, 'type') || '';
    $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.

    unless ($type eq 'checkbox' or $type eq 'radio') {
      my $cd_attr = $item->{node}->get_attribute_node_ns (undef, 'checked');
      if ($cd_attr) {
        $self->{onerror}->(node => $cd_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }

    unless ($type eq 'radio') {
      my $rg_attr = $item->{node}->get_attribute_node_ns (undef, 'radiogroup');
      if ($rg_attr) {
        $self->{onerror}->(node => $rg_attr,
                           type => 'attribute not allowed',
                           level => 'm');
      }
    }
  }, # check_attrs2
}; # menuitem

$Element->{+HTML_NS}->{dialog} = {
  %HTMLFlowContentChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{has_autofocus_original} = $self->{flag}->{has_autofocus};
    $self->{flag}->{has_autofocus} = 0;

    $HTMLFlowContentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{has_autofocus}
        unless $element_state->{has_autofocus_original};

    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # dialog

# ------ Frames ------

$Element->{+HTML_NS}->{frameset} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq HTML_NS and
             ($child_ln eq 'frameset' or $child_ln eq 'frame')) {
      $item->{has_frame_or_frameset} = 1;
    } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'noframes') {
      if ($item->{has_noframes} or
          ($self->{flag}->{in_frameset} || 0) > 1) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed',
                           level => 'm');
      } else {
        $item->{has_noframes} = 1;
      }
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  }, # check_child_text
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $self->{flag}->{in_frameset}++;

    $AnyChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{flag}->{in_frameset}--;

    unless ($item->{has_frame_or_frameset}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:frame|frameset',
                         level => 'm');
    }

    $AnyChecker{check_end}->(@_);
  }, # check_end
}; # frameset

$Element->{+HTML_NS}->{noframes} = {
  %HTMLTextChecker, # XXX content model restriction (same as iframe)
}; # noframes

## ------ Microdata ------

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{itemtype} = sub {
  my ($self, $attr) = @_;
  ## Unordered set of unique space-separated tokens.
  my %word;
  for my $word (grep { length $_ }
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;

      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($word);
      $chk->onerror (sub {
        $self->{onerror}->(value => $word, @_, node => $attr);
      });
      $chk->check_iri_reference; # XXX absolute URL
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }

  $self->{onerror}->(node => $attr,
                     type => 'empty itemtype', # XXXdoc
                     level => 'm')
      unless keys %word;
}; # itemtype=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{itemprop} = sub {
  my ($self, $attr) = @_;
  ## Unordered set of unique space-separated tokens.
  my %word;
  for my $word (grep { length $_ }
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
      if ($word =~ /:/) {
        require Web::URL::Checker;
        my $chk = Web::URL::Checker->new_from_string ($word);
        $chk->onerror (sub {
          $self->{onerror}->(value => $word, @_, node => $attr);
        });
        $chk->check_iri_reference; # XXX absolute URL
      } else {
        $self->{onerror}->(node => $attr,
                           type => '. in itemprop',
                           level => 'm')
            if $word =~ /\./;
      }
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'm');
    }
  }

  $self->{onerror}->(node => $attr,
                     type => 'empty itemprop', # XXXdoc
                     level => 'm')
      unless keys %word;
}; # itemprop=""

sub _validate_microdata ($) {
  my ($self) = @_;

  require Web::HTML::Microdata;
  my $md = Web::HTML::Microdata->new;
  $md->onerror (sub { $self->onerror->(@_) });

  for my $el (@{$self->{top_level_item_elements}}) {
    my $item = $md->get_item_of_element ($el);
    $self->_validate_microdata_item ($item);
  }

  while (@{$self->{itemprop_els}}) {
    my $el = shift @{$self->{itemprop_els}};
    $self->{onerror}->(node => $el,
                       type => 'microdata:unused itemprop',
                       level => 'm');
    if ($el->has_attribute_ns (undef, 'itemscope')) {
      my $item = $md->get_item_of_element ($el);
      $self->_validate_microdata_item ($item);
    }
  }
} # _validate_microdata

sub _validate_microdata_item ($$;$) {
  my ($self, $item, $item_def) = @_;

  my $typed = !!$item_def;
  my $vocab = '';
  my $type_defs = $item_def ? [$item_def] : [];
  for my $itemtype (sort { $a cmp $b } # For stability of errors
                    keys %{$item->{types}}) {
    next unless $item->{types}->{$itemtype};
    $typed = 1;
    my $it = $itemtype;
    if (($_Defs->{md}->{$itemtype} and
         defined $_Defs->{md}->{$itemtype}->{vocab}) or
        ( ## <http://schema.org/docs/extension.html>
         $itemtype =~ m{^(http://schema\.org/[^/]+)/.}s and
         $_Defs->{md}->{$1} and
         defined $_Defs->{md}->{$1}->{vocab} and
         $it = $1
        )) {
      if ($vocab ne '') {
        unless ($vocab eq $_Defs->{md}->{$it}->{vocab}) {
          $self->{onerror}->(node => $item->{node},
                             type => 'microdata:mixed vocab',
                             text => $vocab, # expected
                             value => $itemtype, # actual
                             level => 'm');
        }
      } else {
        $vocab = $_Defs->{md}->{$it}->{vocab};
      }
      unless ($it eq $itemtype) {
        $self->{onerror}->(node => $item->{node},
                           type => 'microdata:schemaorg:private',
                           value => $itemtype,
                           level => 'w');
      }
      push @$type_defs, $_Defs->{md}->{$it};
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'microdata:item type not defined',
                         value => $itemtype,
                         level => 'm');
    }
  } # $itemtype

  if (defined $item->{id}) {
    my $use_id;
    for (@$type_defs) {
      if ($_->{use_itemid}) {
        $use_id = 1;
        last;
      }
    }
    $self->{onerror}->(node => $item->{node},
                       type => 'microdata:itemid not supported',
                       level => 'm')
        unless $use_id;
  } # $item->{id}

  for my $prop (keys %{$item->{props}}) {
    next unless $item->{props}->{$prop};
    my $prop_def;
    PROPDEF: {
      my @all_def = @$type_defs;
      for (@$type_defs) {
        if ($_->{props}->{$prop}) {
          $prop_def = $_->{props}->{$prop};
          last PROPDEF;
        }
      }
      my %super = map { %{$_->{subclass_of} || {}} } @$type_defs;
      for (keys %super) {
        next unless $super{$_};
        my $type_def = $_Defs->{md}->{$_} or next;
        if ($type_def->{props}->{$prop}) {
          $prop_def = $type_def->{props}->{$prop};
          last PROPDEF;
        }
        push @all_def, $type_def;
      }
      if ($vocab eq 'http://schema.org/') {
        for my $type_def (@all_def) {
          for (keys %{$type_def->{props} or {}}) {
            next unless $type_def->{props}->{$_};
            if ($prop =~ m{^\Q$_\E/.}s) {
              $prop_def = $type_def->{props}->{$_};
              $self->{onerror}->(node => $_,
                                 type => 'microdata:schemaorg:itemprop private',
                                 value => $prop,
                                 level => 'w')
                  for map { $_->{node} } @{$item->{props}->{$prop} or []};
              last PROPDEF;
            }
          }
        }
      }
    } # PROPDEF

    if (defined $prop_def) {
      if ($prop_def->{discouraged}) {
        $self->{onerror}->(node => $_,
                           type => 'microdata:itemprop:discouraged',
                           value => $prop,
                           level => 'w')
            for map { $_->{node} } @{$item->{props}->{$prop} or []};
      }
    } elsif ($prop =~ /:/) { ## An absolute URL
      if ($typed) {
        $self->{onerror}->(node => $_,
                           type => 'microdata:itemprop proprietary',
                           value => $prop,
                           level => 'w')
            for map { $_->{node} } @{$item->{props}->{$prop} or []};
      }
    } else { ## Non-URL property with no definition
      if ($typed) {
        if ($vocab eq 'http://schema.org/' and
            $_Defs->{schemaorg_props}->{$prop}) {
          $self->{onerror}->(node => $_,
                             type => 'microdata:schemaorg:bad domain',
                             text => (join ' ', grep { $item->{types}->{$_} } keys %{$item->{types} or {}}),
                             value => $prop,
                             level => 'm')
              for map { $_->{node} } @{$item->{props}->{$prop} or []};
        } else {
          $self->{onerror}->(node => $_,
                             type => 'microdata:itemprop not defined',
                             text => (join ' ', grep { $item->{types}->{$_} } keys %{$item->{types} or {}}),
                             value => $prop,
                             level => $vocab eq 'http://schema.org/' ? 'w' : 'm')
              for map { $_->{node} } @{$item->{props}->{$prop} or []};
        }
      }
    } ## $prop_def or not

    for my $value (@{$item->{props}->{$prop}}) {
      @{$self->{itemprop_els}} = grep { $_ ne $value->{node} } @{$self->{itemprop_els}};

      if ($value->{type} eq 'error') {
        $self->{onerror}->(node => $value->{node},
                           type => 'microdata:nested item loop',
                           level => 'm');
      } elsif ($value->{type} eq 'item') {
        my $has_type;
        my $type_ok;
        if (defined $prop_def) {
          if ($prop_def->{item}) {
            for (keys %{$value->{types}}) {
              $has_type = 1;
              if ($prop_def->{item}->{types}->{$_} and $value->{types}->{$_}) {
                $type_ok = 1;
                last;
              }
            }
          }

          if ($type_ok) {
            ## The child item has an item type expected by the parent item.
            #
          } else {
            ## The child item has a item type, but:
            if ($prop_def->{item}) { ## Different type is expected
              $self->{onerror}->(node => $value->{node},
                                 type => 'microdata:unexpected nested item type',
                                 text => (join ' ', grep { $prop_def->{item}->{types}->{$_} } keys %{$prop_def->{item}->{types} or {}}), # expected
                                 value => (join ' ', grep { $value->{types}->{$_} } keys %{$value->{types}}), # actual
                                 level => 'm')
                  if keys %{$prop_def->{item}->{types} or {}};
            } elsif (defined $prop_def->{value} or ## Non-item is expected
                     $prop_def->{is_url} or
                     keys %{$prop_def->{enum} or {}}) {
              $self->{onerror}->(node => $value->{node},
                                 type => 'microdata:itemvalue not text',
                                 text => $prop,
                                 level => 'm');
            } # else, no constraint
          }
        }

        if (defined $prop_def and not $type_ok and $prop_def->{item}) {
          $self->_validate_microdata_item ($value, $prop_def->{item});
        } else {
          $self->_validate_microdata_item ($value);
        }
      } else { # $value->{type} eq 'url' or 'text'
        if (defined $prop_def) {
          if (not $value->{type} eq 'url' and
              $prop_def->{is_url} and
              not defined $prop_def->{value} and
              not %{$prop_def->{enum} or {}}) {
            $self->{onerror}->(node => $value->{node},
                               type => 'microdata:not url prop element',
                               text => $prop,
                               level => 'm');
          }

          if ($prop_def->{item} and
              not ($prop_def->{is_url} or
                   defined $prop_def->{value} or
                   keys %{$prop_def->{enum} or {}})) {
            $self->{onerror}->(node => $value->{node},
                               type => 'microdata:not item',
                               text => $prop,
                               level => 'm');
          }

          if (defined $prop_def->{value} or keys %{$prop_def->{enum} or {}}) {
            if (defined $prop_def->{value}) {
              my $checker = $ItemValueChecker->{$prop_def->{value}};
              if ($checker) {
                $checker->($self, $value->{text}, $value->{node});
              } else {
                $self->{onerror}->(node => $value->{node},
                                   type => 'microdata:unknown type',
                                   text => $prop_def->{value},
                                   value => $value->{text},
                                   level => 'u');
              }

              # XXX dtstart and dtend must have same datatype
              # XXX dtstart < dtend
            } else { # enum
              unless ($prop_def->{enum}->{$value->{text}}) {
                $self->{onerror}->(node => $value->{node},
                                   type => 'microdata:enum:bad',
                                   text => $prop,
                                   value => $value->{text},
                                   level => 'm');
              }
            }
          } # value or enum
        } # $prop_def
      } # $value->{type}
    } # $value
  } # $item->{props}

  for my $type_def (@$type_defs) {
    for my $prop (keys %{$type_def->{props} or {}}) {
      my $prop_def = $type_def->{props}->{$prop} or next;
      if (defined $prop_def->{min} and $prop_def->{min} > 0) {
        if (@{$item->{props}->{$prop} or []} < $prop_def->{min}) {
          $self->{onerror}->(node => $item->{node},
                             type => 'microdata:no required itemprop',
                             text => $prop,
                             level => 'm');
        }
      }
      if (defined $prop_def->{max} and not $prop_def->{max} eq 'Infinity') {
        if ($prop_def->{max} < @{$item->{props}->{$prop} or []}) {
          $self->{onerror}->(node => $item->{node},
                             type => 'microdata:too many itemprop',
                             text => $prop_def->{max},
                             value => $prop,
                             level => 'm');
        }
      }
    }
  } # @$type_defs

  if ($item->{types}->{'http://microformats.org/profile/hcalendar#vevent'} and
      @{$item->{props}->{dtend} or []} and
      @{$item->{props}->{duration} or []}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'microdata:vevent:dtend and duration',
                       level => 'm');
  }
} # _validate_microdata_item

# XXX itemvalue text syntax:
#    currency
#    vcard telephone number
#    vcard sex
#    vcard geo
#    vevent duration
#    vevent rdate
#    date string
#    global date and time string
#    global or local date and time string
#    date string or global date and time string
#    icalendar recur
#    time string
#    vcard tz

## ------ SVG ------

# XXX
$_Defs->{elements}->{(SVG_NS)}->{$_}->{conforming} = 1
    for qw(svg g rect circle foreignObject title desc metadata);

## ------ MathML ------

# XXX
$_Defs->{elements}->{(MML_NS)}->{$_}->{conforming} = 1
    for qw(math mi mo mn mtext annotation-xml);

## ------ Atom ------

sub ATOM_NS () { q<http://www.w3.org/2005/Atom> }
sub THR_NS () { q<http://purl.org/syndication/thread/1.0> }
sub FH_NS () { q<http://purl.org/syndication/history/1.0> }
sub LINK_REL () { q<http://www.iana.org/assignments/relation/> }

## XXX Comments and PIs are not explicitly allowed in Atom.

# XXX Update checks to align with HTML Standard's reqs and quality

## Atom 1.0 [RFC 4287] cites RFC 4288 (Media Type Registration) for
## "MIME media type".  However, RFC 4288 only defines syntax of
## component such as |type|, |subtype|, and |parameter-name| and does
## not define the whole syntax.  We use Web Applications 1.0's "valid
## MIME type" definition here.

## XXX Replace IRI by URL Standard

## Any element MAY have xml:base, xml:lang.  Although Atom spec does
## not explictly specify that unknown attribute cannot be used, HTML
## Standard does not allow use of unknown attributes.

# XXX
my $GetAtomAttrsChecker = sub {
  my $element_specific_checker = shift;
  return sub {
    my ($self, $item, $element_state) = @_;
    $self->_check_element_attrs ($item, $element_state,
                                 element_specific_checker => $element_specific_checker);
  };
}; # $GetAtomAttrsChecker

my %AtomChecker = (%AnyChecker);


# XXXXXX XXXerrortypes

our $CheckDIVContent; # XXX

my %AtomTextConstruct = (
  %AtomChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{type} = 'text';
    $element_state->{value} = '';
  },
  check_attrs => $GetAtomAttrsChecker->({
    type => sub {
      my ($self, $attr, $item, $element_state) = @_;
      my $value = $attr->value;
      if ($value eq 'text' or $value eq 'html' or $value eq 'xhtml') { # MUST
        $element_state->{type} = $value;
      } else {
        ## NOTE: IMT MUST NOT be used here.
        $self->{onerror}->(node => $attr,
                           type => 'invalid attribute value',
                           level => 'm');
      }
    }, # checked in |checker|
  }),
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      if ($element_state->{type} eq 'text' or
          $element_state->{type} eq 'html') { # MUST NOT
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:atom|TextConstruct',
                           level => 'm');
      } elsif ($element_state->{type} eq 'xhtml') {
        if ($child_nsuri eq q<http://www.w3.org/1999/xhtml> and
            $child_ln eq 'div') { # MUST
          if ($element_state->{has_div}) {
            $self->{onerror}
                ->(node => $child_el,
                   type => 'element not allowed:atom|TextConstruct',
                   level => 'm');
          } else {
            $element_state->{has_div} = 1;
            ## TODO: SHOULD be suitable for handling as HTML [XHTML10]
          }
        } else {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:atom|TextConstruct',
                             level => 'm');
        }
      } else {
        die "atom:TextConstruct type error: $element_state->{type}";
      }
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($element_state->{type} eq 'text') {
      #
    } elsif ($element_state->{type} eq 'html') {
      $element_state->{value} .= $child_node->text_content;
      ## NOTE: Markup MUST be escaped.
    } elsif ($element_state->{type} eq 'xhtml') {
      if ($has_significant) {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed:atom|TextConstruct',
                           level => 'm');
      }
    } else {
      die "atom:TextConstruct type error: $element_state->{type}";
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{type} eq 'xhtml') {
      unless ($element_state->{has_div}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'child element missing',
                           text => 'div',
                           level => 'm');
      }
    } elsif ($element_state->{type} eq 'html') {
      $CheckDIVContent->($self, $item->{node}, $element_state->{value});
    }

    $AtomChecker{check_end}->(@_);
  },
); # %AtomTextConstruct

my %AtomPersonConstruct = (
  %AtomChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq ATOM_NS) {
      if ($child_ln eq 'name') {
        if ($element_state->{has_name}) {
          $self->{onerror}
              ->(node => $child_el,
                 type => 'element not allowed:atom|PersonConstruct',
                 level => 'm');
        } else {
          $element_state->{has_name} = 1;
        }
      } elsif ($child_ln eq 'uri') {
        if ($element_state->{has_uri}) {
          $self->{onerror}
              ->(node => $child_el,
                 type => 'element not allowed:atom|PersonConstruct',
                 level => 'm');
        } else {
          $element_state->{has_uri} = 1;
        }
      } elsif ($child_ln eq 'email') {
        if ($element_state->{has_email}) {
          $self->{onerror}
              ->(node => $child_el,
                 type => 'element not allowed:atom|PersonConstruct',
                 level => 'm');
        } else {
          $element_state->{has_email} = 1;
        }
      } else {
        $self->{onerror}
            ->(node => $child_el,
               type => 'element not allowed:atom|PersonConstruct',
               level => 'm');
      }
    } else {
      $self->{onerror}
          ->(node => $child_el,
             type => 'element not allowed:atom|PersonConstruct',
             level => 'm');
    }
    ## TODO: extension element
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed:atom|PersonConstruct',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    unless ($element_state->{has_name}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'name',
                         level => 'm');
    }

    $AtomChecker{check_end}->(@_);
  },
); # %AtomPersonConstruct

$Element->{+ATOM_NS}->{''} = {
  %AtomChecker,
};

$Element->{+ATOM_NS}->{name} = {
  %AtomChecker,

  ## NOTE: Strictly speaking, structure and semantics for atom:name
  ## element outside of Person construct is not defined.

  ## NOTE: No constraint.
};

$Element->{+ATOM_NS}->{uri} = {
  %AtomChecker,

  ## NOTE: Strictly speaking, structure and semantics for atom:uri
  ## element outside of Person construct is not defined.

  ## NOTE: Elements are not explicitly disallowed.

  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## NOTE: There MUST NOT be any white space.
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($element_state->{value});
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $item->{node});
    });
    $chk->check_iri_reference;

    $AtomChecker{check_end}->(@_);
  },
};

$Element->{+ATOM_NS}->{email} = {
  %AtomChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed',
                       level => 'm');
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{onerror}->(node => $item->{node},
                       type => 'email:syntax error', ## TODO: type
                       level => 'm')
        unless $item->{node}->text_content =~ /\A$ValidEmailAddress\z/o;
    $AtomChecker{check_end}->(@_);
  },
}; # atom:email

## MUST NOT be any white space
my %AtomDateConstruct = (
  %AtomChecker,

  ## NOTE: It does not explicitly say that there MUST NOT be any element.

  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## MUST: RFC 3339 |date-time| with uppercase |T| and |Z|
    if ($element_state->{value} =~ /\A([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?>\.[0-9]+)?(?>Z|[+-]([0-9]{2}):([0-9]{2}))\z/) {
      my ($y, $M, $d, $h, $m, $s, $zh, $zm)
          = ($1, $2, $3, $4, $5, $6, $7 || 0, $8 || 0);
      my $node = $item->{node};

      ## Check additional constraints described or referenced in
      ## comments of ABNF rules for |date-time|.
      if (0 < $M and $M < 13) {      
        $self->{onerror}->(node => $node, type => 'datetime:bad day',
                           level => 'm')
            if $d < 1 or
                $d > [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]->[$M];
        $self->{onerror}->(node => $node, type => 'datetime:bad day',
                           level => 'm')
            if $M == 2 and $d == 29 and
                not ($y % 400 == 0 or ($y % 4 == 0 and $y % 100 != 0));
      } else {
        $self->{onerror}->(node => $node, type => 'datetime:bad month',
                           level => 'm');
      }
      $self->{onerror}->(node => $node, type => 'datetime:bad hour',
                         level => 'm') if $h > 23;
      $self->{onerror}->(node => $node, type => 'datetime:bad minute',
                         level => 'm') if $m > 59;
      $self->{onerror}->(node => $node, type => 'datetime:bad second',
                         level => 'm')
          if $s > 60; ## NOTE: Validness of leap seconds are not checked.
      $self->{onerror}->(node => $node, type => 'datetime:bad timezone hour',
                         level => 'm') if $zh > 23;
      $self->{onerror}->(node => $node, type => 'datetime:bad timezone minute',
                         level => 'm') if $zm > 59;
    } else {
      $self->{onerror}->(node => $item->{node},
                         type => 'datetime:syntax error',
                         level => 'm');
    }
    ## NOTE: SHOULD be accurate as possible (cannot be checked)

    $AtomChecker{check_end}->(@_);
  },
); # %AtomDateConstruct

$Element->{+ATOM_NS}->{entry} = {
  %AtomChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    ## NOTE: metadata elements, followed by atom:entry* (no explicit MAY)

    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq ATOM_NS) {
      my $not_allowed;
      if ({ # MUST (0, 1)
           content => 1,
           id => 1,
           published => 1,
           rights => 1,
           source => 1,
           summary => 1,
           title => 1,
           updated => 1,
          }->{$child_ln}) {
        unless ($element_state->{has_element}->{$child_ln}) {
          $element_state->{has_element}->{$child_ln} = 1;
          $not_allowed = $element_state->{has_element}->{entry};
        } else {
          $not_allowed = 1;
        }
      } elsif ($child_ln eq 'link') { # MAY
        if ($child_el->rel eq LINK_REL . 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = $child_el->get_attribute_ns (undef, 'hreflang');
          $hreflang = '' unless defined $hreflang;
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_element}->{$key}) {
            $element_state->{has_element}->{$key} = 1;
            $element_state->{has_element}->{'link.alternate'} = 1;
          } else {
            $not_allowed = 1;
          }
        }
        
        ## NOTE: MAY
        $not_allowed ||= $element_state->{has_element}->{entry};
      } elsif ({ # MAY
                category => 1,
                contributor => 1,
               }->{$child_ln}) {
        $not_allowed = $element_state->{has_element}->{entry};
      } elsif ($child_ln eq 'author') { # MAY
        $not_allowed = $element_state->{has_element}->{entry};
        $element_state->{has_author} = 1; # ./author | ./source/author
        $element_state->{has_element}->{$child_ln} = 1; # ./author
      } else {
        $not_allowed = 1;
      }
      if ($not_allowed) {
        $self->{onerror}->(node => $child_el, type => 'element not allowed',
                           level => 'm');
      }
    } elsif ($child_nsuri eq THR_NS and $child_ln eq 'in-reply-to') {
      ## ISSUE: Where |thr:in-reply-to| is allowed is not explicit;y
      ## defined in RFC 4685.
      #
    } elsif ($child_nsuri eq THR_NS and $child_ln eq 'total') {
      #
    } else {
      ## TODO: extension element
      $self->{onerror}->(node => $child_el, type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node, type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{has_author}) {
      ## NOTE: There is either a child atom:author element
      ## or a child atom:source element which contains an atom:author
      ## child element.
      #
    } else {
      A: {
        my $root = $item->{node}->owner_document->document_element;
        if ($root and $root->local_name eq 'feed') {
          my $nsuri = $root->namespace_uri;
          if (defined $nsuri and $nsuri eq ATOM_NS) {
            ## NOTE: An Atom Feed Document.
            for my $root_child (@{$root->child_nodes}) {
              ## NOTE: Entity references are not supported.
              next unless $root_child->node_type == 1; # ELEMENT_NODE
              next unless $root_child->local_name eq 'author';
              my $root_child_nsuri = $root_child->namespace_uri;
              next unless defined $root_child_nsuri;
              next unless $root_child_nsuri eq ATOM_NS;
              last A;
            }
          }
        }
        
        $self->{onerror}->(node => $item->{node},
                           type => 'child element missing:atom',
                           text => 'author',
                           level => 'm');
      } # A
    }

    unless ($element_state->{has_element}->{author}) {
      $item->{parent_state}->{has_no_author_entry} = 1; # for atom:feed's check
    }

    ## TODO: If entry's with same id, then updated SHOULD be different

    unless ($element_state->{has_element}->{id}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'id',
                         level => 'm');
    }
    unless ($element_state->{has_element}->{title}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'title',
                         level => 'm');
    }
    unless ($element_state->{has_element}->{updated}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'updated',
                         level => 'm');
    }
    if (not $element_state->{has_element}->{content} and
        not $element_state->{has_element}->{'link.alternate'}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom:link:alternate',
                         level => 'm');
    }

    if ($element_state->{require_summary} and
        not $element_state->{has_element}->{summary}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'summary',
                         level => 'm');
    }
  },
};

$Element->{+ATOM_NS}->{feed} = {
  %AtomChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    ## NOTE: metadata elements, followed by atom:entry* (no explicit MAY)

    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq ATOM_NS) {
      my $not_allowed;
      if ($child_ln eq 'entry') {
        $element_state->{has_element}->{entry} = 1;
      } elsif ({ # MUST (0, 1)
                generator => 1,
                icon => 1,
                id => 1,
                logo => 1,
                rights => 1,
                subtitle => 1,
                title => 1,
                updated => 1,
               }->{$child_ln}) {
        unless ($element_state->{has_element}->{$child_ln}) {
          $element_state->{has_element}->{$child_ln} = 1;
          $not_allowed = $element_state->{has_element}->{entry};
        } else {
          $not_allowed = 1;
        }
      } elsif ($child_ln eq 'link') {
        my $rel = $child_el->rel;
        if ($rel eq LINK_REL . 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = $child_el->get_attribute_ns (undef, 'hreflang');
          $hreflang = '' unless defined $hreflang;
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_element}->{$key}) {
            $element_state->{has_element}->{$key} = 1;
          } else {
            $not_allowed = 1;
          }
        } elsif ($rel eq LINK_REL . 'self') {
          $element_state->{has_element}->{'link.self'} = 1;
        }
        
        ## NOTE: MAY
        $not_allowed = $element_state->{has_element}->{entry};
      } elsif ({ # MAY
                category => 1,
                contributor => 1,
               }->{$child_ln}) {
        $not_allowed = $element_state->{has_element}->{entry};
      } elsif ($child_ln eq 'author') { # MAY
        $not_allowed = $element_state->{has_element}->{entry};
        $element_state->{has_element}->{author} = 1;
      } else {
        $not_allowed = 1;
      }
      $self->{onerror}->(node => $child_el, type => 'element not allowed',
                         level => 'm')
          if $not_allowed;
    } else {
      ## TODO: extension element
      $self->{onerror}->(node => $child_el, type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node, type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{has_no_author_entry} and
        not $element_state->{has_element}->{author}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'author',
                         level => 'm');
      ## ISSUE: If there is no |atom:entry| element,
      ## there should be an |atom:author| element?
    }

    ## TODO: If entry's with same id, then updated SHOULD be different

    unless ($element_state->{has_element}->{id}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'id',
                         level => 'm');
    }
    unless ($element_state->{has_element}->{title}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'title',
                         level => 'm');
    }
    unless ($element_state->{has_element}->{updated}) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'updated',
                         level => 'm');
    }
    unless ($element_state->{has_element}->{'link.self'}) {
      $self->{onerror}->(node => $item->{node}, 
                         type => 'child element missing:atom:link:self',
                         level => 's');
    }

    $AtomChecker{check_end}->(@_);
  },
};

$Element->{+ATOM_NS}->{content} = {
  %AtomChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{type} = 'text';
    $element_state->{value} = '';
  },
  check_attrs => $GetAtomAttrsChecker->({
    src => sub {
      my ($self, $attr, $item, $element_state) = @_;

      $element_state->{has_src} = 1;
      $item->{parent_state}->{require_summary} = 1;

      ## NOTE: There MUST NOT be any white space.
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($attr->value);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $item->{node});
      });
      $chk->check_iri_reference;
    },
    type => sub {
      my ($self, $attr, $item, $element_state) = @_;

      $element_state->{has_type} = 1;

      my $value = $attr->value;
      if ($value eq 'text' or $value eq 'html' or $value eq 'xhtml') {
        # MUST
      } else {
        my $type = $MIMETypeChecker->(@_);
        if ($type) {
          if ($type->is_composite_type) {
            $self->{onerror}->(node => $attr, type => 'IMT:composite',
                               level => 'm');
          }

          if ($type->is_xml_mime_type) {
            $value = 'xml';
          } elsif ($type->type eq 'text') {
            $value = 'mime_text';
          } else {
            $item->{parent_state}->{require_summary} = 1;
          }
        } else {
          $item->{parent_state}->{require_summary} = 1;
        }
      }

      $element_state->{type} = $value;
    },
  }),
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      if ($element_state->{type} eq 'text' or
          $element_state->{type} eq 'html' or
          $element_state->{type} eq 'mime_text') {
        # MUST NOT
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:atom|content',
                           level => 'm');
      } elsif ($element_state->{type} eq 'xhtml') {
        if ($element_state->{has_div}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:atom|content',
                             level => 'm');
        } else {
          ## TODO: SHOULD be suitable for handling as HTML [XHTML10]
          $element_state->{has_div} = 1;
        }
      } elsif ($element_state->{type} eq 'xml') {
        ## MAY contain elements
        if ($element_state->{has_src}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:atom|content',
                             level => 'm');
        }
      } else {
        ## NOTE: Elements are not explicitly disallowed.
      }
    }
  },
  ## NOTE: If @src, the element MUST be empty.  What is "empty"?
  ## Is |<e><!----></e>| empty?  |<e>&e;</e>| where |&e;| has
  ## empty replacement tree shuld be empty, since Atom is defined
  ## in terms of XML Information Set where entities are expanded.
  ## (but what if |&e;| is an unexpanded entity?)
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;    
    if ($has_significant) {
      if ($element_state->{has_src}) {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed:empty',
                           level => 'm');
      } elsif ($element_state->{type} eq 'xhtml' or
               $element_state->{type} eq 'xml') {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed:atom|content',
                           level => 'm');
      }
    }

    $element_state->{value} .= $child_node->data;

    ## NOTE: type=text/* has no further restriction (i.e. the content don't
    ## have to conform to the definition of the type).
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{has_src}) {
      if (not $element_state->{has_type}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'type',
                           level => 's');
      } elsif ($element_state->{type} eq 'text' or
               $element_state->{type} eq 'html' or
               $element_state->{type} eq 'xhtml') {
        $self->{onerror}
            ->(node => $item->{node}->get_attribute_node_ns (undef, 'type'),
               type => 'not IMT', level => 'm');
      }
    }

    if ($element_state->{type} eq 'xhtml') {
      unless ($element_state->{has_div}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'child element missing',
                           text => 'div',
                           level => 'm');
      }
    } elsif ($element_state->{type} eq 'html') {
      $CheckDIVContent->($self, $item->{node}, $element_state->{value});
    } elsif ($element_state->{type} eq 'xml') {
      ## NOTE: SHOULD be suitable for handling as $value.
      ## If no @src, this would normally mean it contains a 
      ## single child element that would serve as the root element.
      $self->{onerror}->(node => $item->{node},
                         type => 'atom|content not supported',
                         text => $item->{node}->get_attribute_ns
                             (undef, 'type'),
                         level => 'u');
    } elsif ($element_state->{type} eq 'text' or
             $element_state->{type} eq 'mime-text') {
      #
    } else {
      ## TODO: $s = valid Base64ed [RFC 3548] where 
      ## MAY leading and following "white space" (what?)
      ## and lines separated by a single U+000A

      ## NOTE: SHOULD be suitable for the indicated media type.
      $self->{onerror}->(node => $item->{node},
                         type => 'atom|content not supported',
                         text => $item->{node}->get_attribute_ns
                             (undef, 'type'),
                         level => 'u');
    }

    $AtomChecker{check_end}->(@_);
  },
}; # atom:content

$Element->{+ATOM_NS}->{author} = \%AtomPersonConstruct;

$Element->{+ATOM_NS}->{category} = {
  %AtomChecker,
  check_attrs => $GetAtomAttrsChecker->({
    label => sub { 1 }, # no value constraint
    scheme => sub { # NOTE: No MUST.
      my ($self, $attr) = @_;
      ## NOTE: There MUST NOT be any white space.
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($attr->value);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $attr);
      });
      $chk->check_iri;
    },
    term => sub {
      my ($self, $attr, $item, $element_state) = @_;
      
      ## NOTE: No value constraint.
      
      $element_state->{has_term} = 1;
    },
  }),
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    unless ($element_state->{has_term}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'term',
                         level => 'm');
    }

    $AtomChecker{check_end}->(@_);
  },
  ## NOTE: Meaning of content is not defined.
};

$Element->{+ATOM_NS}->{contributor} = \%AtomPersonConstruct;

## TODO: Anything below does not support <html:nest/> yet.

$Element->{+ATOM_NS}->{generator} = {
  %AtomChecker,
  check_attrs => $GetAtomAttrsChecker->({
    uri => sub { # MUST
      my ($self, $attr) = @_;
      ## NOTE: There MUST NOT be any white space.
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($attr->value);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $attr);
      });
      $chk->check_iri_reference;
      ## NOTE: Dereferencing SHOULD produce a representation
      ## that is relevant to the agent.
    },
    version => sub { 1 }, # no value constraint
  }),

  ## NOTE: Elements are not explicitly disallowed.

  ## NOTE: Content MUST be a string that is a human-readable name for
  ## the generating agent.
};

$Element->{+ATOM_NS}->{icon} = {
  %AtomChecker,
  check_start =>  sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  ## NOTE: Elements are not explicitly disallowed.
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## NOTE: No MUST.
    ## NOTE: There MUST NOT be any white space.
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($element_state->{value});
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $item->{node});
    });
    $chk->check_iri_reference;

    ## NOTE: Image SHOULD be 1:1 and SHOULD be small

    $AtomChecker{check_end}->(@_);
  },
};

$Element->{+ATOM_NS}->{id} = {
  %AtomChecker,
  check_start =>  sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  ## NOTE: Elements are not explicitly disallowed.
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## NOTE: There MUST NOT be any white space.
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($element_state->{value});
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $item->{node});
    });
    $chk->check_iri;
    ## TODO: SHOULD be normalized

    $AtomChecker{check_end}->(@_);
  },
};

my $AtomIRIReferenceAttrChecker = sub {
  my ($self, $attr) = @_;
  ## NOTE: There MUST NOT be any white space.
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($attr->value);
  $chk->onerror (sub {
    $self->{onerror}->(@_, node => $attr);
  });
  $chk->check_iri_reference;
  $self->{has_uri_attr} = 1;
}; # $AtomIRIReferenceAttrChecker

$Element->{+ATOM_NS}->{link} = {
  %AtomChecker,
  check_attrs => $GetAtomAttrsChecker->({
    href => $AtomIRIReferenceAttrChecker,
    hreflang => $CheckerByType->{'language tag'},
    length => sub { }, # No MUST; in octets.
    rel => sub { # MUST
      my ($self, $attr) = @_;
      my $value = $attr->value;
      if ($value =~ /\A(?>[0-9A-Za-z._~!\$&'()*+,;=\x{A0}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFEF}\x{10000}-\x{1FFFD}\x{20000}-\x{2FFFD}\x{30000}-\x{3FFFD}\x{40000}-\x{4FFFD}\x{50000}-\x{5FFFD}\x{60000}-\x{6FFFD}\x{70000}-\x{7FFFD}\x{80000}-\x{8FFFD}\x{90000}-\x{9FFFD}\x{A0000}-\x{AFFFD}\x{B0000}-\x{BFFFD}\x{C0000}-\x{CFFFD}\x{D0000}-\x{DFFFD}\x{E1000}-\x{EFFFD}-]|%[0-9A-Fa-f][0-9A-Fa-f]|\@)+\z/) {
        $value = LINK_REL . $value;
      }

      ## NOTE: There MUST NOT be any white space.
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($value);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $attr);
      });
      $chk->check_iri;

      ## TODO: Warn if unregistered

      ## TODO: rel=license [RFC 4946]
      ## MUST NOT multiple rel=license with same href="",type="" pairs
      ## href="" SHOULD be dereferencable
      ## title="" SHOULD be there if multiple rel=license
      ## MUST NOT "unspecified" and other rel=license
    },
    title => sub {},
    type => $MIMETypeChecker,
  }),
  check_start =>  sub {
    my ($self, $item, $element_state) = @_;

    unless ($item->{node}->has_attribute_ns (undef, 'href')) { # MUST
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'href',
                         level => 'm');
    }

    if ($item->{node}->rel eq LINK_REL . 'enclosure' and
        not $item->{node}->has_attribute_ns (undef, 'length')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'length',
                         level => 's');
    }
  },
};

$Element->{+ATOM_NS}->{logo} = {
  %AtomChecker,
  ## NOTE: Child elements are not explicitly disallowed
  check_start =>  sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  ## NOTE: Elements are not explicitly disallowed.
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;  

    ## NOTE: There MUST NOT be any white space.
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($element_state->{value});
    $chk->onerror (sub {
      $self->{onerror}->(@_, node => $item->{node});
    });
    $chk->check_iri_reference;
    
    ## NOTE: Image SHOULD be 2:1

    $AtomChecker{check_end}->(@_);
  },
};

$Element->{+ATOM_NS}->{published} = \%AtomDateConstruct;

$Element->{+ATOM_NS}->{rights} = \%AtomTextConstruct;
## NOTE: SHOULD NOT be used to convey machine-readable information.

$Element->{+ATOM_NS}->{source} = {
  %AtomChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } elsif ($child_nsuri eq ATOM_NS) {
      my $not_allowed;
      if ($child_ln eq 'entry') {
        $element_state->{has_element}->{entry} = 1;
      } elsif ({
                generator => 1,
                icon => 1,
                id => 1,
                logo => 1,
                rights => 1,
                subtitle => 1,
                title => 1,
                updated => 1,
               }->{$child_ln}) {
        unless ($element_state->{has_element}->{$child_ln}) {
          $element_state->{has_element}->{$child_ln} = 1;
          $not_allowed = $element_state->{has_element}->{entry};
        } else {
          $not_allowed = 1;
        }
      } elsif ($child_ln eq 'link') {
        if ($child_el->rel eq LINK_REL . 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = $child_el->get_attribute_ns (undef, 'hreflang');
          $hreflang = '' unless defined $hreflang;
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_element}->{$key}) {
            $element_state->{has_element}->{$key} = 1;
          } else {
            $not_allowed = 1;
          }
        }
        $not_allowed ||= $element_state->{has_element}->{entry};
      } elsif ({
                category => 1,
                contributor => 1,
               }->{$child_ln}) {
        $not_allowed = $element_state->{has_element}->{entry};
      } elsif ($child_ln eq 'author') {
        $not_allowed = $element_state->{has_element}->{entry};
        $item->{parent_state}->{has_author} = 1; # parent::atom:entry's flag
      } else {
        $not_allowed = 1;
      }
      if ($not_allowed) {
        $self->{onerror}->(node => $child_el, type => 'element not allowed',
                           level => 'm');
      }
    } else {
      ## TODO: extension element
      $self->{onerror}->(node => $child_el, type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      $self->{onerror}->(node => $child_node, type => 'character not allowed',
                         level => 'm');
    }
  },
};

$Element->{+ATOM_NS}->{subtitle} = \%AtomTextConstruct;

$Element->{+ATOM_NS}->{summary} = \%AtomTextConstruct;

$Element->{+ATOM_NS}->{title} = \%AtomTextConstruct;

$Element->{+ATOM_NS}->{updated} = \%AtomDateConstruct;

## TODO: signature element

## TODO: simple extension element and structured extension element

## -- Atom Threading 1.0 [RFC 4685]

$Element->{+THR_NS}->{''} = {
  %AtomChecker,
};

## ISSUE: Strictly speaking, thr:* element/attribute,
## where * is an undefined local name, is not disallowed.

$Element->{+THR_NS}->{'in-reply-to'} = {
  %AtomChecker,
  check_attrs => $GetAtomAttrsChecker->({
    href => $AtomIRIReferenceAttrChecker,
        ## TODO: fact-level.
        ## TODO: MUST be dereferencable.
    ref => sub {
      my ($self, $attr, $item, $element_state) = @_;
      $element_state->{has_ref} = 1;

      ## NOTE: Same as |atom:id|.
      ## NOTE: There MUST NOT be any white space.
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($attr->value);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $attr);
      });
      $chk->check_iri;
      $self->{has_uri_attr} = 1;

      ## TODO: Check against ID guideline...
    },
    source => $AtomIRIReferenceAttrChecker,
        ## TODO: fact-level.
        ## TODO: MUST be dereferencable.
    type => $MIMETypeChecker,
  }),
  check_end => sub {
    my ($self, $item, $element_state) = @_;
  
    unless ($element_state->{has_ref}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'ref',
                         level => 'm');
    }

    $AtomChecker{check_end}->(@_);
  },
  ## NOTE: Content model has no constraint.
};

$Element->{+THR_NS}->{total} = {
  %AtomChecker,
  check_start =>  sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{value} = '';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($self->{minus_elements}->{$child_nsuri}->{$child_ln} and
        $self->_is_minus_element ($child_el, $child_nsuri, $child_ln)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:minus',
                         level => 'm');
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    $element_state->{value} .= $child_node->data;
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    ## NOTE: xsd:nonNegativeInteger
    unless ($element_state->{value} =~ /\A(?>[0-9]+|-0+)\z/) {
      $self->{onerror}->(node => $item->{node},
                         type => 'invalid attribute value', 
                         level => 'm');
    }

    $AtomChecker{check_end}->(@_);
  },
};

## TODO: fh:complete

## TODO: fh:archive

## TODO: Check as archive document, page feed document, ...

## TODO: APP [RFC 5023]

## ------ Nested document ------

sub _check_fallback_html ($$$$) {
  my ($self, $context, $disallowed, $container_ln) = @_;
  my $container = $context->owner_document->create_element ($container_ln);
  
  my $onerror = $GetNestedOnError->($self->onerror, $context);
  # XXX pos

  require Web::DOM::Document;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);

  require Web::HTML::Parser;
  my $parser = Web::HTML::Parser->new;
  $parser->onerror ($onerror);
  $parser->scripting ($self->scripting);
  my $children = $parser->parse_char_string_with_context
      ($context->text_content, $container => $doc);
  
  my $checker = Web::HTML::Validator->new;
  $checker->_init;
  $checker->scripting ($self->scripting);
  $checker->onerror ($onerror);
  $checker->{flag}->{in_media} = $self->{flag}->{in_media};
  $checker->{flag}->{no_interactive} = $self->{flag}->{no_interactive};
  $checker->{flag}->{has_label} = $self->{flag}->{has_label};
  $checker->{flag}->{has_labelable} = $self->{flag}->{has_labelable};
  $checker->{flag}->{in_canvas} = $self->{flag}->{in_canvas};

  $checker->_check_node
      ([{type => 'element', node => $container, parent_state => {},
         disallowed => $disallowed,
         content => $children,
         is_noscript => $container_ln eq 'head',
         validation_mode => 'default'}]);

  $checker->_validate_microdata;
  $checker->_validate_aria ($children);
  $checker->_check_refs;
  $checker->_terminate;
} # _check_fallback_html

$ElementAttrChecker->{(HTML_NS)}->{iframe}->{''}->{srcdoc} = sub {
  my ($self, $attr) = @_;
  require Web::DOM::Document;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_srcdoc (1);
  my $parser;
  if ($attr->owner_document->manakai_is_html) {
    $doc->manakai_is_html (1);
    require Web::HTML::Parser;
    $parser = Web::HTML::Parser->new;
    $parser->scripting ($self->scripting);
  } else {
    require Web::XML::Parser;
    $parser = Web::XML::Parser->new;
  }
  my $onerror = $GetNestedOnError->($self->onerror, $attr);
  $parser->onerror ($onerror);
  $parser->parse_char_string ($attr->value => $doc);
  
  my $checker = Web::HTML::Validator->new;
  $checker->onerror ($onerror);
  $checker->scripting ($self->scripting);
  $checker->check_node ($doc);
}; # <iframe srcdoc="">

## For Atom Text construct with type=html and <atom:content type=html>
## elements
$CheckDIVContent = sub {
  my ($self, $node, $value) = @_;
  require Web::DOM::Document;
  my $doc = new Web::DOM::Document;
  my $div = $doc->create_element ('div');

  require Web::HTML::Parser;
  my $parser = Web::HTML::Parser->new;
  $parser->scripting ($self->scripting);
  my $onerror = $GetNestedOnError->($self->onerror, $node);
  $parser->onerror ($onerror);
  for (@{$parser->parse_char_string_with_context ($value, $div => $doc)}) {
    $div->append_child ($_);
  }

  require Web::HTML::Validator;
  my $checker = Web::HTML::Validator->new;
  $checker->scripting ($self->scripting);
  $checker->onerror ($onerror);
  $checker->check_node ($div);
}; # $CheckDIVContent

# XXX unserializable waring for any children
$Element->{+HTML_NS}->{template} = {
  %HTMLEmptyChecker,
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my $df = $item->{node}->content;
    my @children = @{$df->child_nodes};

    my $model;
    my $has_flow;
    for my $child (@children) {
      if ($child->node_type == 1) { # ELEMENT_NODE
        my $ns = $child->namespace_uri || '';
        my $ln = $child->local_name;

        if ($ns eq HTML_NS) {
          $model = {
            li => 'ul', #'ulol',
            dt => 'dl',
            dd => 'dl',
            figcaption => 'figure',
            rt => 'ruby',
            rp => 'ruby',
            param => 'object',
            source => 'video', #'media',
            track => 'video', #'media',
            col => 'colgroup',
            tbody => 'table',
            thead => 'table',
            tfoot => 'table',
            th => 'tr',
            td => 'tr',
            legend => 'fieldset',
            optgroup => 'select',
            option => 'select',
            summary => 'details',
            menuitem => 'popup menu',
          }->{$ln};
          last if defined $model;

          if ($ln eq 'tr') {
            $model = 'table'; #tr-container
            #not last;
          } elsif ($ln eq 'style') {
            unless ($child->has_attribute_ns (undef, 'scoped')) {
              $model = 'metadata';
              last;
            }
          }
        }
        if ($_Defs->{categories}->{'metadata content'}->{elements}->{$ns}->{$ln} and
            not $_Defs->{categories}->{'flow content'}->{elements}->{$ns}->{$ln} and
            not $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$ns}->{$ln}) {
          ## Metadata content
          $model = 'metadata';
          last;
        }

        if (not $_Defs->{categories}->{'metadata content'}->{elements}->{$ns}->{$ln}) {
          $has_flow = 1;
        }

        ## Metadata content (<link> <meta> <script> <template>), flow
        ## content, figure, ruby, object, media, table (<script>
        ## <template>), colgroup (<script> <template>), table body
        ## (<script> <template>), tr (<script> <template>), fieldset,
        ## details, <menu type=popup> (<hr> <script> <template>)
        #
      } elsif ($child->node_type == 3) { # TEXT_NODE
        if ($child->data =~ /[^\x09\x0A\x0C\x0D\x20]/) { # non-space chars
          ## Flow content, figure, ruby, object, media
          $has_flow = 1;
        }
      }
    } # $child

    my $container;
    if (not defined $model) {
      ## Flow content or metadata content
      $container = $df->owner_document->create_element
          ($has_flow ? 'div' : 'head');
    } elsif ($model eq 'metadata') {
      $container = $df->owner_document->create_element ('head');
    } elsif ($model eq 'popup menu') {
      $container = $df->owner_document->create_element ('menu');
      $container->set_attribute_ns (undef, type => 'popup');
    } else {
      $container = $df->owner_document->create_element ($model);
      $container->set_attribute_ns (undef, data => 'http://test/') if $model eq 'object';
    }

    my $checker = Web::HTML::Validator->new;
    $checker->_init;
    $checker->scripting ($self->scripting);
    $checker->{flag}->{is_template} = 1;
    my $onerror = $self->onerror;
    my $node = $item->{node};
    $checker->onerror (sub {
      my %args = @_;
      $args{node} = $node if $args{node} eq $container;
      $onerror->(%args);
    });

    $checker->_check_node
        ([{type => 'element', node => $container, parent_state => {},
           is_template => 1,
           content => \@children,
           validation_mode => 'default'}]);

    $checker->_check_refs;
    $checker->_validate_microdata;
    $checker->_validate_aria (\@children);
    $checker->_terminate;

    $HTMLEmptyChecker{check_end}->(@_);
  }, # check_end
}; # template

## ------ CSS ------

sub _css_parser ($$) {
  my ($self, $node) = @_;
  require Web::CSS::Parser;
  require Web::CSS::Context;
  my $parser = Web::CSS::Parser->new;
  my $context = Web::CSS::Context->new_from_nscallback (sub {
    return $node->lookup_namespace_uri ($_[0]); # XXX is this really necessary??
  });
  $context->url ($node->owner_document->url);
  $context->manakai_compat_mode ($node->owner_document->manakai_compat_mode);
  $context->base_url ($node->base_uri);
  $parser->context ($context);
  $parser->media_resolver->set_supported (all => 1);
  $parser->onerror ($GetNestedOnError->($self->onerror, $node));
  #$parser->init_parser;
  return $parser;
} # _create_css_parser

## CSS styling attribute [HTML] [CSSSTYLEATTR]
$CheckerByType->{'CSS styling'} = sub {
  my ($self, $attr) = @_;
  my $parser = $self->_css_parser ($attr);
  my $props = $parser->parse_char_string_as_prop_decls ($attr->value);
  # XXX Web::CSS::Checker->new->check_props ($props);
}; # CSS styling

## Media query list [MQ]
$CheckerByType->{'media query list'} = sub {
  my ($self, $attr) = @_;
  my $parser = $self->_css_parser ($attr);
  my $mqs = $parser->parse_char_string_as_mq_list ($attr->value);

  require Web::CSS::MediaQueries::Checker;
  my $checker = Web::CSS::MediaQueries::Checker->new;
  $checker->onerror ($parser->onerror);
  $checker->check_mq_list ($mqs);
}; # media query list

## ------ JavaScript ------

## JavaScript regular expression [HTML] [ES] [JS]
$CheckerByType->{'JavaScript Pattern'} = sub {
  my ($self, $attr) = @_;
  ## NOTE: "value must match the Pattern production" [HTML].  In
  ## addition, requirements for the Pattern, as defined in ECMA-262
  ## specification, are also applied (e.g. {n,m} then n>=m must be
  ## true).

  require Regexp::Parser::JavaScript;
  my $parser = Regexp::Parser::JavaScript->new;
  $parser->onerror (sub {
    my %opt = @_;
    if ($opt{code} == [$parser->RPe_BADESC]->[0]) {
      $opt{type} =~ s{%s%s}{
        '%s' . (defined $opt{args}->[1] ? $opt{args}->[1] : '')
      }e;
    } elsif ($opt{code} == [$parser->RPe_FRANGE]->[0] or
             $opt{code} == [$parser->RPe_IRANGE]->[0]) {
      $opt{text} = $opt{args}->[0] . '-';
      $opt{text} .= $opt{args}->[1] if defined $opt{args}->[1];
    } elsif ($opt{code} == [$parser->RPe_BADFLG]->[0]) {
      ## NOTE: Not used by JavaScript regexp parser in fact.
      $opt{text} = $opt{args}->[0] . $opt{args}->[1];
    } else {
      $opt{text} = $opt{args}->[0];
    }
    delete $opt{args};
    my $pos_start = delete $opt{pos_start};
    my $value = substr ${delete $opt{valueref} or \''}, $pos_start, (delete $opt{pos_end}) - $pos_start;
    $self->onerror->(%opt, value => $value, node => $attr);
  }); # onerror
  eval { $parser->parse ($attr->value) };
  $parser->onerror (undef);

  ## TODO: Warn if @value does not match @pattern.
}; # JavaScript Pattern

## ------ Documents ------

sub _check_doc_charset ($$) {
  my ($self, $doc) = @_;
  if ($doc->manakai_is_html) {
    if ($self->{flag}->{has_meta_charset}) {
      require Web::Encoding;
      my $name = Web::Encoding::encoding_label_to_name ($doc->input_encoding);
      $self->{onerror}->(node => $doc,
                         type => 'charset:not ascii compat',
                         value => $doc->input_encoding,
                         level => 'm')
          unless Web::Encoding::is_ascii_compat_encoding_name ($name);
    } else {
      if ($doc->manakai_has_bom) {
        #
      } elsif ($doc->manakai_is_srcdoc) { # iframe srcdoc document
        #
      } elsif (defined $doc->manakai_charset) { # Content-Type metadata's charset=""
        #
      } else {
        require Web::Encoding;
        my $name = Web::Encoding::encoding_label_to_name ($doc->input_encoding);
        $self->{onerror}->(node => $doc,
                           type => 'charset:not ascii compat',
                           value => $doc->input_encoding,
                           level => 'm')
            unless Web::Encoding::is_ascii_compat_encoding_name ($name);
        $self->{onerror}->(node => $doc,
                           type => 'no character encoding declaration',
                           level => 'm');
      }
    }

    unless ($doc->input_encoding eq 'utf-8') {
      $self->{onerror}->(node => $doc,
                         type => 'non-utf-8 character encoding',
                         value => $doc->input_encoding,
                         level => 's');
    }
  } else { # XML document
    if ($self->{flag}->{has_meta_charset} and not defined $doc->xml_encoding) {
      $self->{onerror}->(node => $doc,
                         type => 'no xml encoding',
                         level => 's');
    }

    # XXX MUST be UTF-8, ...
    # XXX check <?xml encoding=""?>
  } # XML document
} # _check_doc_charset

## ------ Nodes ------

## <http://suika.suikawiki.org/www/markup/xml/validation-langs#determine-the-validation-mode>
sub _determine_validation_mode ($$$) {
  my ($self, $el, $parent_mode) = @_;
  if (($parent_mode eq 'RDF' or $parent_mode eq 'RSS1') and
      0 and 'is RDF XML literal') {
    $parent_mode = 'default';
  }
  if ((0 and 'XXX is XSLT element') or
      ($parent_mode eq 'XSLT' and 0 and 'XXX is XSLT literal result element')) {
    return 'XSLT';
  }
  if (($el->namespace_uri || '') eq RDF_NS and $el->local_name eq 'RDF') {
    my $xmlns = $el->get_attribute_ns (XMLNS_NS, 'xmlns') || '';
    my $rdfns = $el->get_attribute_ns (XMLNS_NS, 'rdf') || '';
    if ($xmlns eq RSS1_NS and $rdfns eq RDF_NS) {
      return 'RSS1';
    } else {
      return 'RDF';
    }
  }
  if (($parent_mode eq 'RDF' or $parent_mode eq 'RSS1') and
      0 and 'XXX is RDF/XML') {
    return $parent_mode;
  }
  return 'default';
} # _determine_validation_mode

sub _check_node ($$) {
  my $self = $_[0];
  my @item = (@{$_[1]});
  while (@item) {
    my $item = shift @item;
    if (ref $item eq 'ARRAY') {
      ## $item
      ##   0     The code reference
      ##   1..$# Arguments for the code
      my $code = shift @$item;
      $code->(@$item) if $code;
    } elsif ($item->{type} eq 'element') {
      ## $item
      ##   type            |element|
      ##   node            The element node
      ##   is_root         Handled as if it had no parent
      ##   content         Chlildren (optional)
      ##   is_template     Is template content (boolean)
      ##   is_noscript     Is |noscript| in |head| (boolean)
      ##   disallowed      Disallowed descendant list (optional)
      ##   parent_state    State hashref for the parent of the element node
      ##   validation_mode Validation mode for the element node
      my $el = $item->{node};
      my $el_nsuri = $el->namespace_uri;
      $el_nsuri = '' if not defined $el_nsuri;
      my $el_ln = $el->local_name;
      
      my $element_state = {};
      my $eldef = $Element->{$el_nsuri}->{$el_ln} ||
          $Element->{$el_nsuri}->{''} ||
          $ElementDefault;

      my $prefix = $el->prefix;
      if (defined $prefix and $prefix eq 'xml') {
        if ($el_nsuri ne XML_NS) {
          $self->{onerror}->(node => $el,
                             type => 'Reserved Prefixes and Namespace Names:Prefix',
                             text => 'xml',
                             level => 'w');
        }
      } elsif (defined $prefix and $prefix eq 'xmlns') {
        $self->{onerror}->(node => $el,
                           type => 'Reserved Prefixes and Namespace Names:<xmlns:>',
                           level => 'm');
      } elsif (($el_nsuri eq XML_NS and not (($prefix || '') eq 'xml')) or
               $el_nsuri eq XMLNS_NS) {
        $self->{onerror}->(node => $el,
                           type => 'Reserved Prefixes and Namespace Names:Name',
                           text => $el_nsuri,
                           level => 'w');
      }

      ## <http://suika.suikawiki.org/www/markup/xml/validation-langs#checking-an-element>.
      my $mode = $item->{validation_mode};
      if ($mode eq 'XSLT') {
        # XXX
      } elsif ($mode eq 'RDF') {
        # XXX
      } else {
        # XXX if $mode eq 'RSS1'
        # XXX if $self->{rss2}

        my $el_def = $_Defs->{elements}->{$el_nsuri}->{$el_ln};
        if ($el_def->{conforming}) {
          unless ($Element->{$el_nsuri}->{$el_ln}) {
            ## According to the attribute list, this element is
            ## conforming.  However, current version of the validator
            ## does not support the element.  The conformance is
            ## unknown.
            $self->{onerror}->(node => $el,
                               type => 'unknown element',
                               level => 'u');
          }
          my $status = $el_def->{status} || '';
          if ($status eq 'REC' or $status eq 'CR' or $status eq 'LC') {
            #
          } else {
            ## The element is conforming, but is in earlier stage such
            ## that it should not be used without caution.
            $self->{onerror}->(node => $el,
                               type => 'status:wd:element',
                               level => 'i')
          }
        } elsif ($_Defs->{namespaces}->{$el_nsuri}->{supported}) {
          ## "Authors must not use elements, attributes, or attribute
          ## values that are not permitted by this specification or
          ## other applicable specifications" [HTML]
          $self->{onerror}->(node => $el,
                             type => 'element not defined',
                             level => 'm');
        } else {
          $self->{onerror}->(node => $el,
                             type => 'unknown namespace element',
                             value => $el_nsuri,
                             level => 'w');
        }
      } # validation mode

      my @new_item;
      my $disallowed = $item->{disallowed} ||
          $ElementDisallowedDescendants->{$el_nsuri}->{$el_ln};
      push @new_item, {type => '_add_minus_elements',
                       element_state => $element_state,
                       disallowed => $disallowed}
          if $disallowed;
      push @new_item, [$eldef->{check_start}, $self, $item, $element_state];
      push @new_item, [$eldef->{check_attrs}, $self, $item, $element_state];
      push @new_item, [$eldef->{check_attrs2}, $self, $item, $element_state];
      push @new_item, {type => 'check_html_attrs',
                       node => $el,
                       element_state => $element_state}
          if $el_nsuri eq HTML_NS;
      
      my @child = @{$item->{content} || $el->child_nodes};
      while (@child) {
        my $child = shift @child;
        my $child_nt = $child->node_type;
        if ($child_nt == 1) { # ELEMENT_NODE
          my $child_nsuri = $child->namespace_uri;
          $child_nsuri = '' unless defined $child_nsuri;
          my $child_ln = $child->local_name;

          if ($element_state->{has_palpable}) {
            #
          } elsif ($_Defs->{categories}->{'palpable content'}->{elements}->{$child_nsuri}->{$child_ln}) {
            $element_state->{has_palpable} = 1
                if not $child_nsuri eq HTML_NS or
                   not $child->has_attribute_ns (undef, 'hidden');
          } elsif ($_Defs->{categories}->{'palpable content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
            $element_state->{has_palpable} = 1
                if $IsPalpableContent->{$child_nsuri}->{$child_ln}->($child) and
                   (not $child_nsuri eq HTML_NS or
                    not $child->has_attribute_ns (undef, 'hidden'));
          }
          push @new_item, [$eldef->{check_child_element},
                           $self, $item, $child,
                           $child_nsuri, $child_ln,
                           0,
                           $element_state, $element_state];
          push @new_item, {type => 'element', node => $child,
                           parent_state => $element_state,
                           validation_mode => $self->_determine_validation_mode
                               ($child, $item->{validation_mode})};
        } elsif ($child_nt == 3) { # TEXT_NODE
          my $has_significant = ($child->data =~ /[^\x09\x0A\x0C\x0D\x20]/);
          push @new_item, [$eldef->{check_child_text},
                           $self, $item, $child, $has_significant,
                           $element_state, $element_state];
          $element_state->{has_palpable} = 1 if $has_significant;
          $self->_check_data ($child, 'data');
          ## Adjacent text nodes and empty text nodes are not
          ## round-trippable, but harmless, so not warned here.
        } elsif ($child_nt == 7) { # PROCESSING_INSTRUCTION_NODE
          ## XXX PROCESSING_INSTRUCTION_NODE
        } # $child_nt
      } # $child
      
      push @new_item, [$eldef->{check_end}, $self, $item, $element_state];
      push @new_item, {type => '_remove_minus_elements',
                       element_state => $element_state}
          if $disallowed;
      my $cm = $_Defs->{elements}->{$el_nsuri}->{$el_ln}->{content_model} || '';
      push @new_item, {type => 'check_palpable_content',
                       node => $el,
                       element_state => $element_state}
          if ($cm eq 'flow content' or
              $cm eq 'phrasing content' or
              $cm eq 'transparent') and
             not $item->{is_template};
      
      unshift @item, @new_item;
    } elsif ($item->{type} eq '_add_minus_elements') {
      $self->_add_minus_elements ($item->{element_state}, $item->{disallowed});
    } elsif ($item->{type} eq '_remove_minus_elements') {
      $self->_remove_minus_elements ($item->{element_state});
    } elsif ($item->{type} eq 'check_html_attrs') {
      for my $attr (@{$item->{node}->attributes}) {
        next if defined $attr->namespace_uri;
        $self->_check_attr_bidi ($attr);
      }

      unless ($item->{node}->has_attribute_ns (undef, 'title')) {
        if ($item->{element_state}->{require_title} or
            $item->{node}->has_attribute_ns (undef, 'draggable') or
            $item->{node}->has_attribute_ns (undef, 'dropzone')) {
          $self->{onerror}->(node => $item->{node},
                             type => 'attribute missing',
                             text => 'title',
                             level => $item->{element_state}->{require_title} || 's');
        }
      }

      if ($item->{node}->has_attribute_ns (undef, 'itemscope')) {
        push @{$self->{top_level_item_elements}}, $item->{node}
            unless $item->{node}->has_attribute_ns (undef, 'itemprop');
      } else {
        for my $name (qw(itemtype itemid itemref)) {
          my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
          $self->{onerror}->(node => $attr,
                             type => 'attribute not allowed',
                             level => 'm') if $attr;
        }
      }

      if ($item->{node}->has_attribute_ns (undef, 'itemprop')) {
        push @{$self->{itemprop_els}}, $item->{node};
      }
    } elsif ($item->{type} eq 'check_palpable_content') {
      $self->{onerror}->(node => $item->{node},
                         level => 's',
                         type => 'no significant content')
          unless $item->{element_state}->{has_palpable};
    } elsif ($item->{type} eq 'document') {
      ## $item
      ##   type  |document|
      ##   node  The document node

      ## Although not allowed by DOM Standard, manakai DOM
      ## implementations support multiple element childs, text node
      ## childs, and document type node following siblings in
      ## non-strict mode.
      my $has_element;
      my $has_doctype;
      my $parent_state = {};
      my @new_item;
      for my $node (@{$item->{node}->child_nodes}) {
        my $nt = $node->node_type;
        if ($nt == 1) { # ELEMENT_NODE
          my $mode = 'default';
          if ($has_element) {
            $self->{onerror}->(node => $node,
                               type => 'duplicate document element',
                               level => 'm'); # [MANAKAI] [DOM]
          } else {
            $has_element = 1;

            my $ct = $item->{node}->content_type;
            my $nsurl = $node->namespace_uri;
            $nsurl = '' if not defined $nsurl;
            my $ln = $node->local_name;

            ## <http://suika.suikawiki.org/www/markup/xml/validation-langs#determine-the-validation-mode>.
            MODE: {
              if ($ct eq 'application/xml' or $ct eq 'text/xml') {
                if (0 and 'XXX is XSLT literal result element' and
                    $node->has_attribute_ns (XSLT_NS, 'version')) {
                  $mode = 'XSLT';
                  last MODE;
                }
              } elsif ($ct eq 'application/xslt+xml' or $ct eq 'text/xsl') {
                if (0 and 'XXX is XSLT literal result element') {
                  $mode = 'XSLT';
                  last MODE;
                }
              } elsif ($ct eq 'application/rdf+xml') {
                if (0 and 'XXX is RDF nodeElement') {
                  $mode = 'RDF';
                  last MODE;
                }
              } else {
                #
              }
              $mode = $self->_determine_validation_mode
                  ($node, $parent_state->{validation_mode} || 'default');
            } # MODE

            ## <http://suika.suikawiki.org/www/markup/xml/validation-langs#document-element>.
            if ($mode eq 'XSLT') {
              if ($nsurl eq XSLT_NS and
                  $_Defs->{elements}->{$nsurl}->{$ln}->{root}) {
                #
              } elsif (0 and 'XXX is XSLT literal result element') {
                $self->{onerror}->(node => $node,
                                   type => 'xslt:root literal result element', # XXX
                                   level => 's')
                    unless $ct eq 'application/xslt+xml' or $ct eq 'text/xsl';
                $self->{onerror}->(node => $node,
                                   type => 'attribute missing',
                                   text => 'xslt:version',
                                   level => 'm')
                    unless $node->has_attribute_ns (XSLT_NS, 'version');
              } else {
                $self->{onerror}->(node => $node,
                                   type => 'element not allowed:root',
                                   level => 'm');
              }
            } elsif ($mode eq 'RDF') {
              if ($nsurl eq RDF_NS and
                  $_Defs->{elements}->{$nsurl}->{$ln}->{root}) {
                #
              } elsif (0 and 'XXX is RDF nodeElement') {
                #
              } else {
                $self->{onerror}->(node => $node,
                                   type => 'element not allowed:root',
                                   level => 'm');
              }
            } elsif ($mode eq 'RSS1') {
              if ($nsurl eq RDF_NS and $ln eq 'RDF') {
                #
              } else {
                $self->{onerror}->(node => $node,
                                   type => 'element not allowed:root',
                                   level => 'm');
              }
            } else { # default
              if ($_Defs->{elements}->{$nsurl}->{$ln}->{root}) {
                #
              } elsif ($nsurl eq '' and $ln eq 'rss') {
                # XXX $self->{rss2} = 1;
              } elsif ($_Defs->{namespaces}->{$nsurl}->{supported}) {
                $self->{onerror}->(node => $node,
                                   type => 'element not allowed:root',
                                   level => 'm');
              } else {
                #
              }
            } # $mode

            unless ($nsurl eq HTML_NS and $ln eq 'html') {
              if ($item->{node}->manakai_is_html) {
                $self->{onerror}->(node => $node,
                                   type => 'document element not serializable',
                                   level => 'w');
              }
            }
            # XXX $doc->content_type vs root element
          } # first element child
          push @new_item, {type => 'element', node => $node,
                           parent_state => $parent_state,
                           validation_mode => $mode};
        } elsif ($nt == 10) { # DOCUMENT_TYPE_NODE
          if ($has_element) {
            $self->{onerror}->(node => $node,
                               type => 'doctype after element',
                               level => 'm'); # [MANAKAI] [DOM]
          } elsif ($has_doctype) {
            $self->{onerror}->(node => $node,
                               type => 'duplicate doctype',
                               level => 'm'); # [MANAKAI] [DOM]
          } else {
            $has_doctype = 1;
          }
          # XXX check the node
        } elsif ($nt == 3) { # TEXT_NODE
          $self->{onerror}->(node => $node,
                             type => 'root text',
                             level => 'm'); # [MANAKAI] [DOM]
          $self->_check_data ($node, 'data');
        }
        
        # XXX PI, Comment validation
      } # $node
      
      $self->{onerror}->(node => $item->{node},
                         type => 'no document element',
                         level => 'w')
          unless $has_element;

      push @item, {type => '_check_doc_charset', node => $item->{node}};
      unshift @item, @new_item;
    } elsif ($item->{type} eq '_check_doc_charset') {
      ## $item
      ##   type   |_check_doc_charset|
      ##   node   The document node
      $self->_check_doc_charset ($item->{node});
    } elsif ($item->{type} eq 'document_fragment') {
      ## $item
      ##   type   |document_fragment|
      ##   node   The document fragment node
      my @new_item;
      my $parent_state = {};
      for my $node (@{$item->{node}->child_nodes}) {
        my $nt = $node->node_type;
        if ($nt == 1) { # ELEMENT_NODE
          push @new_item, {type => 'element', node => $node,
                           parent_state => $parent_state,
                           validation_mode => $self->_determine_validation_mode
                               ($node, 'default')};
        } elsif ($nt == 3) { # TEXT_NODE
          $self->_check_data ($node, 'data');
        }
        # XXX Comment PI
      } # $node
      unshift @item, @new_item;
    } else {
      die "$0: Internal error: Unsupported checking action type |$item->{type}|";
    }
  } # @item
} # _check_node

sub _check_refs ($) {
  my $self = $_[0];
  ## |usemap| attribute values MUST be valid hash-name references
  ## pointing |map| elements.
  for (@{$self->{usemap}}) {
    ## $_->[0]: Original |usemap| attribute value without leading '#'.
    ## $_->[1]: The |usemap| attribute node.

    if ($self->{map_exact}->{$_->[0]}) {
      ## There is at least one |map| element with the specified name.
      #
    } else {
      my $name_compat = lc $_->[0]; ## XXX compatibility caseless match.
      if ($self->{map_compat}->{$name_compat}) {
        ## There is at least one |map| element with the specified name
        ## in different case combination.
        $self->{onerror}->(node => $_->[1],
                           type => 'hashref:wrong case',
                           level => 'm');
      } else {
        ## There is no |map| element with the specified name at all.
        $self->{onerror}->(node => $_->[1],
                           type => 'no referenced map',
                           level => 'm');
      }
    }
  }

  ## @{$self->{idref}}       Detected ID references to be checked:
  ##                         [id-type, id-value, id-node]
  ## @{$self->{id}->{$id}}   Detected ID nodes, in tree order
  ## $self->{id_type}->{$id} Type of first ID node's element
  ## ID types:
  ##   any       Any type is allowed (For |idref| only)
  ##   command   Master command
  ##   form      <form>
  ##   datalist  <datalist>
  ##   labelable Labelable element
  ##   object    <object>
  ## Note that headers=""'s IDs are not checked here.
  for (@{$self->{idref}}) {
    if ($self->{id}->{$_->[1]} and $self->{id_type}->{$_->[1]} eq $_->[0]) {
      #
    } elsif ($_->[0] eq 'any' and $self->{id}->{$_->[1]}) {
      #
    } else {
      my $error_type = {
        any => 'no referenced element',
        form => 'no referenced form',
        labelable => 'no referenced control',
        datalist => 'no referenced datalist',
        object => 'no referenced object',
        popup => 'no referenced menu',
        command => 'no referenced master command',
      }->{$_->[0]};
      $self->{onerror}->(node => $_->[2],
                         type => $error_type,
                         value => $_->[1],
                         level => 'm');
    }
  } # $self->{idref}
} # _check_refs

sub check_node ($$) {
  my ($self, $node) = @_;
  $self->onerror;
  $self->_init;
  my $nt = $node->node_type;
  if ($nt == 1) { # ELEMENT_NODE
    $self->_check_node
        ([{type => 'element', node => $node, parent_state => {},
           is_root => 1,
           validation_mode => $self->_determine_validation_mode
               ($node, 'default')}]);
  } elsif ($nt == 9) { # DOCUMENT_NODE
    $self->_check_node ([{type => 'document', node => $node}]);
  } elsif ($nt == 3) { # TEXT_NODE
    $self->_check_data ($node, 'data');
  } elsif ($nt == 2) { # ATTRIBUTE_NODE
    $self->_check_data ($node, 'value');
  } elsif ($nt == 11) { # DOCUMENT_FRAGMENT_NODE
    $self->_check_node ([{type => 'document_fragment', node => $node}]);
  }
  # XXX PI Comment DocumentType Entity Notation ElementTypeDefinition AttributeDefinition
  $self->_check_refs;
  $self->_validate_microdata;
  $self->_validate_aria ([$node]);
  $self->_terminate;

  # XXX More useful return object
  #return
  delete $self->{return}; # XXX
} # check_node

# XXX
package Web::HTML::Validator::HTML::Metadata;
use strict;
use warnings;
our $VERSION = '1.0';

use constant STATUS_NOT_REGISTERED => 0;
use constant STATUS_PROPOSED => 1;
use constant STATUS_RATIFIED => 2;
use constant STATUS_DISCONTINUED => 3;
use constant STATUS_STANDARD => 4;

our $Defs;

$Defs->{'application-name'} = {
  unique => 1,
  status => STATUS_STANDARD,
};

$Defs->{author} = {
  unique => 0,
  status => STATUS_STANDARD,
};

$Defs->{description} = {
  unique => 1,
  status => STATUS_STANDARD,
};

$Defs->{generator} = {
  unique => 0,
  status => STATUS_STANDARD,
};

$Defs->{keywords} = {
  unique => 0,
  status => STATUS_PROPOSED,
};

$Defs->{cache} = {
  unique => 0,
  status => STATUS_DISCONTINUED,
};

# XXX Implement all values listed in WHATWG Wiki
# <http://wiki.whatwg.org/wiki/MetaExtensions>

our $DefaultDef = {
  unique => 0,
  status => STATUS_NOT_REGISTERED,
};

sub check ($@) {
  my ($class, %args) = @_;
  
  my $def = $Defs->{$args{name}} || $DefaultDef;

  ## XXX name pattern match (e.g. /^dc\..+/)

  ## --- Name conformance ---

  ## XXX synonyms (necessary to support some of wiki-documented
  ## metadata names

  if ($def->{status} == STATUS_STANDARD or $def->{status} == STATUS_RATIFIED) {
    #
  } elsif ($def->{status} == STATUS_PROPOSED) {
    $args{checker}->{onerror}->(type => 'metadata:proposed', # XXX TODOC
                                text => $args{name},
                                node => $args{name_attr},
                                level => 'w');
  } elsif ($def->{status} == STATUS_DISCONTINUED) {
    $args{checker}->{onerror}->(type => 'metadata:discontinued', # XXX TODOC
                                text => $args{name},
                                node => $args{name_attr},
                                level => 's');
  } else {
    $args{checker}->{onerror}->(type => 'metadata:not registered', # XXX TODOC
                                text => $args{name},
                                node => $args{name_attr},
                                level => 'm');
  }

  ## --- Metadata uniqueness ---

  if ($def->{unique}) {
    unless ($args{checker}->{flag}->{html_metadata}->{$args{name}}) {
      $args{checker}->{flag}->{html_metadata}->{$args{name}} = 1;
    } else {
      $args{checker}->{onerror}->(type => 'metadata:duplicate', # XXX TODOC
                                  text => $args{name},
                                  node => $args{name_attr},
                                  level => 'm');
    }
  }

  ## --- Value conformance ---

  ## XXX implement value conformance checking (not necessary for
  ## standard metadata names)

} # check

$Web::HTML::Validator::LinkType = {
          'accessibility' => {
                               'effect' => [
                                             'hyperlink',
                                             'hyperlink'
                                           ],
                               'status' => 'proposal'
                             },
          'acquaintance' => {
                              'effect' => [
                                            'hyperlink',
                                            'hyperlink'
                                          ],
                              'status' => 'accepted'
                            },
          'admin' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'proposal'
                     },
          'ajax' => {
                      'effect' => [
                                    undef,
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'alternate' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'accepted'
                         },
          'answer' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'proposal'
                      },
          'appendix' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'synonym'
                        },
          'application-manifest' => {
                                      'effect' => [
                                                    'external resource',
                                                    undef
                                                  ],
                                      'status' => 'proposal'
                                    },
          'archive' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'archives' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'accepted'
                        },
          'author' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'accepted'
                      },
          'begin' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'synonym'
                     },
          'bookmark' => {
                          'effect' => [
                                        undef,
                                        'hyperlink'
                                      ],
                          'status' => 'accepted'
                        },
          'canonical' => {
                           'effect' => [
                                         'hyperlink',
                                         undef
                                       ],
                           'status' => 'proposal'
                         },
          'canonical-domain' => {
                                  'effect' => [
                                                'external resource',
                                                undef
                                              ],
                                  'status' => 'proposal'
                                },
          'canonical-first' => {
                                 'effect' => [
                                               'external resource',
                                               'hyperlink'
                                             ],
                                 'status' => 'proposal'
                               },
          'canonical-human' => {
                                 'effect' => [
                                               'external resource',
                                               'hyperlink'
                                             ],
                                 'status' => 'proposal'
                               },
          'canonical-organization' => {
                                        'effect' => [
                                                      'external resource',
                                                      'hyperlink'
                                                    ],
                                        'status' => 'proposal'
                                      },
          'canonical-wwwnone' => {
                                   'effect' => [
                                                 'external resource',
                                                 'hyperlink'
                                               ],
                                   'status' => 'proposal'
                                 },
          'chapter' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'proposal'
                       },
          'child' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'accepted'
                     },
          'co-resident' => {
                             'effect' => [
                                           'hyperlink',
                                           'hyperlink'
                                         ],
                             'status' => 'accepted'
                           },
          'co-worker' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'accepted'
                         },
          'colleague' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'accepted'
                         },
          'comment' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'contact' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'accepted'
                       },
          'content-negotiation' => {
                                     'effect' => [
                                                   'external resource',
                                                   undef
                                                 ],
                                     'status' => 'synonym'
                                   },
          'contents' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'synonym'
                        },
          'contributor' => {
                             'effect' => [
                                           'hyperlink',
                                           'hyperlink'
                                         ],
                             'status' => 'proposal'
                           },
          'copyright' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'synonym'
                         },
          'crush' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'accepted'
                     },
          'date' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'dns-prefetch' => {
                              'effect' => [
                                            'external resource',
                                            undef
                                          ],
                              'status' => 'proposal'
                            },
          'edit' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'edituri' => {
                         'effect' => [
                                       'hyperlink',
                                       undef
                                     ],
                         'status' => 'proposal'
                       },
          'enclosure' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'proposal'
                         },
          'end' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'synonym'
                   },
          'enlarged' => {
                          'effect' => [
                                        undef,
                                        'hyperlink'
                                      ],
                          'status' => 'proposal'
                        },
          'extension' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'proposal'
                         },
          'external' => {
                          'effect' => [
                                        undef,
                                        'hyperlink'
                                      ],
                          'status' => 'accepted'
                        },
          'first' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'accepted'
                     },
          'friend' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'accepted'
                      },
          'gallery' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'proposal'
                       },
          'glossary' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'proposal'
                        },
          'help' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'hub' => {
                     'effect' => [
                                   'hyperlink',
                                   undef
                                 ],
                     'status' => 'proposal'
                   },
          'i18nrules' => {
                           'effect' => [
                                         'hyperlink',
                                         undef
                                       ],
                           'status' => 'proposal'
                         },
          'icon' => {
                      'effect' => [
                                    'external resource',
                                    undef
                                  ],
                      'status' => 'accepted'
                    },
          'index' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'accepted'
                     },
          'jump' => {
                      'effect' => [
                                    undef,
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'kin' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'accepted'
                   },
          'last' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'latest-version' => {
                                'effect' => [
                                              'hyperlink',
                                              'hyperlink'
                                            ],
                                'status' => 'proposal'
                              },
          'license' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'accepted'
                       },
          'login' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'proposal'
                     },
          'logout' => {
                        'effect' => [
                                      'external resource',
                                      undef
                                    ],
                        'status' => 'proposal'
                      },
          'longdesc' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'proposal'
                        },
          'maintainer' => {
                            'effect' => [
                                          'hyperlink',
                                          'hyperlink'
                                        ],
                            'status' => 'synonym'
                          },
          'map' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'proposal'
                   },
          'me' => {
                    'effect' => [
                                  'hyperlink',
                                  'hyperlink'
                                ],
                    'status' => 'accepted'
                  },
          'met' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'accepted'
                   },
          'meta' => {
                      'effect' => [
                                    'external resource',
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'muse' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'neighbor' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'accepted'
                        },
          'next' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'next-archive' => {
                              'effect' => [
                                            'hyperlink',
                                            'hyperlink'
                                          ],
                              'status' => 'proposal'
                            },
          'nofollow' => {
                          'effect' => [
                                        undef,
                                        'annotation'
                                      ],
                          'status' => 'accepted'
                        },
          'noprefetch' => {
                            'effect' => [
                                          'external resource',
                                          'hyperlink'
                                        ],
                            'status' => 'proposal'
                          },
          'noreferrer' => {
                            'effect' => [
                                          undef,
                                          'annotation'
                                        ],
                            'status' => 'accepted'
                          },
          'note' => {
                      'effect' => [
                                    undef,
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'openid.delegate' => {
                                 'effect' => [
                                               'external resource',
                                               undef
                                             ],
                                 'status' => 'proposal'
                               },
          'openid.server' => {
                               'effect' => [
                                             'external resource',
                                             undef
                                           ],
                               'status' => 'proposal'
                             },
          'openid2.local_id' => {
                                  'effect' => [
                                                'external resource',
                                                undef
                                              ],
                                  'status' => 'proposal'
                                },
          'openid2.provider' => {
                                  'effect' => [
                                                'external resource',
                                                undef
                                              ],
                                  'status' => 'proposal'
                                },
          'option' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'synonym'
                      },
          'parent' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'accepted'
                      },
          'payment' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'proposal'
                       },
          'pgpkey' => {
                        'effect' => [
                                      'hyperlink',
                                      undef
                                    ],
                        'status' => 'proposal'
                      },
          'pingback' => {
                          'effect' => [
                                        'external resource',
                                        undef
                                      ],
                          'status' => 'accepted',
                          'unique' => 1
                        },
          'posting' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'prefetch' => {
                          'effect' => [
                                        'external resource',
                                        undef
                                      ],
                          'status' => 'accepted'
                        },
          'prerender' => {
                           'effect' => [
                                         'external resource',
                                         undef
                                       ],
                           'status' => 'proposal'
                         },
          'presentation' => {
                              'effect' => [
                                            'external resource',
                                            'hyperlink'
                                          ],
                              'status' => 'proposal'
                            },
          'prev' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'accepted'
                    },
          'prev-archive' => {
                              'effect' => [
                                            'hyperlink',
                                            'hyperlink'
                                          ],
                              'status' => 'proposal'
                            },
          'previous' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'synonym'
                        },
          'print' => {
                       'effect' => [
                                     'external resource',
                                     'hyperlink'
                                   ],
                       'status' => 'proposal'
                     },
          'problem' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'profile' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'proposal'
                       },
          'pronunciation' => {
                               'effect' => [
                                             'external resource',
                                             undef
                                           ],
                               'status' => 'proposal'
                             },
          'question' => {
                          'effect' => [
                                        'hyperlink',
                                        'hyperlink'
                                      ],
                          'status' => 'proposal'
                        },
          'related' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'proposal'
                       },
          'reply' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'proposal'
                     },
          'resource-description' => {
                                      'effect' => [
                                                    'external resource',
                                                    undef
                                                  ],
                                      'status' => 'synonym'
                                    },
          'resource-package' => {
                                  'effect' => [
                                                'external resource',
                                                undef
                                              ],
                                  'status' => 'proposal'
                                },
          'resources' => {
                           'effect' => [
                                         'external resource',
                                         undef
                                       ],
                           'status' => 'proposal'
                         },
          'reviewer' => {
                          'effect' => [
                                        'hyperlink',
                                        undef
                                      ],
                          'status' => 'proposal'
                        },
          'script' => {
                        'effect' => [
                                      undef,
                                      undef
                                    ],
                        'status' => 'rejected'
                      },
          'search' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'accepted'
                      },
          'section' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'self' => {
                      'effect' => [
                                    'hyperlink',
                                    'hyperlink'
                                  ],
                      'status' => 'proposal'
                    },
          'service' => {
                         'effect' => [
                                       'external resource',
                                       undef
                                     ],
                         'status' => 'proposal'
                       },
          'shortlink' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'proposal'
                         },
          'sibling' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'accepted'
                       },
          'sidebar' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'accepted'
                       },
          'slides' => {
                        'effect' => [
                                      'external resource',
                                      'hyperlink'
                                    ],
                        'status' => 'synonym'
                      },
          'slideshow' => {
                           'effect' => [
                                         'external resource',
                                         'hyperlink'
                                       ],
                           'status' => 'synonym'
                         },
          'spouse' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'accepted'
                      },
          'start' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'synonym'
                     },
          'statechart' => {
                            'effect' => [
                                          'external resource',
                                          undef
                                        ],
                            'status' => 'proposal'
                          },
          'stylesheet' => {
                            'effect' => [
                                          'external resource',
                                          undef
                                        ],
                            'status' => 'accepted'
                          },
          'subject' => {
                         'effect' => [
                                       'hyperlink',
                                       'hyperlink'
                                     ],
                         'status' => 'synonym'
                       },
          'subresource' => {
                             'effect' => [
                                           'hyperlink',
                                           undef
                                         ],
                             'status' => 'proposal'
                           },
          'subsection' => {
                            'effect' => [
                                          'hyperlink',
                                          'hyperlink'
                                        ],
                            'status' => 'synonym'
                          },
          'sweetheart' => {
                            'effect' => [
                                          'hyperlink',
                                          'hyperlink'
                                        ],
                            'status' => 'accepted'
                          },
          'tag' => {
                     'effect' => [
                                   undef,
                                   'hyperlink'
                                 ],
                     'status' => 'accepted'
                   },
          'technicalauthor' => {
                                 'effect' => [
                                               'hyperlink',
                                               'hyperlink'
                                             ],
                                 'status' => 'proposal'
                               },
          'thread' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'proposal'
                      },
          'timesheet' => {
                           'effect' => [
                                         'external resource',
                                         undef
                                       ],
                           'status' => 'proposal'
                         },
          'toc' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'synonym'
                   },
          'top' => {
                     'effect' => [
                                   'hyperlink',
                                   'hyperlink'
                                 ],
                     'status' => 'synonym'
                   },
          'topic' => {
                       'effect' => [
                                     'hyperlink',
                                     'hyperlink'
                                   ],
                       'status' => 'synonym'
                     },
          'translatedfrom' => {
                                'effect' => [
                                              'hyperlink',
                                              'hyperlink'
                                            ],
                                'status' => 'proposal'
                              },
          'translator' => {
                            'effect' => [
                                          'hyperlink',
                                          'hyperlink'
                                        ],
                            'status' => 'proposal'
                          },
          'up' => {
                    'effect' => [
                                  'hyperlink',
                                  'hyperlink'
                                ],
                    'status' => 'accepted'
                  },
          'us' => {
                    'effect' => [
                                  'hyperlink',
                                  'hyperlink'
                                ],
                    'status' => 'proposal'
                  },
          'webmaster' => {
                           'effect' => [
                                         'hyperlink',
                                         'hyperlink'
                                       ],
                           'status' => 'proposal'
                         },
          'widget' => {
                        'effect' => [
                                      'hyperlink',
                                      'hyperlink'
                                    ],
                        'status' => 'proposal'
                      },
          'wlwmanifest' => {
                             'effect' => [
                                           'hyperlink',
                                           undef
                                         ],
                             'status' => 'proposal'
                           }
        };

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
