package Web::HTML::Validator;
use strict;
use warnings;
use warnings FATAL => 'recursion';
no warnings 'utf8';
our $VERSION = '136.0';
use Scalar::Util qw(refaddr);
use Web::HTML::Validator::_Defs;
use Web::HTML::SourceMap;
use Web::XML::_CharClasses;

## ------ Constructor ------

sub new ($) {
  return bless {}, $_[0];
} # new

## ------ Validator error handler ------

sub di_data_set ($;$) {
  if (@_ > 1) {
    $_[0]->{di_data_set} = $_[1];
  }
  return $_[0]->{di_data_set} ||= [];
} # di_data_set

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{_onerror} = $_[1];
  }
  $_[0]->{_onerror} ||= sub {
    my %args = @_;
    return if $args{level} eq 'mh';
    warn sprintf "%s%s%s%s (%s)%s\n",
        defined $args{node} ? $args{node}->node_name . ': ' : '',
        $args{type},
        defined $args{text} ? ' ' . $args{text} : '',
        defined $args{value} ? ' "' . $args{value} . '"' : '',
        $args{level} . ($args{in_template} ? ' (in template)' : ''),
        (defined $args{column} ? sprintf ' at line %d column %d%s',
                                     $args{line}, $args{column}, (defined $args{di} ? ' document #' . $args{di} : '') : '');
  };
  return $_[0]->{onerror};
} # onerror

my $GetNestedOnError = sub ($$) {
  my ($_onerror, $node) = @_;
  my $onerror = sub {
    my %args = @_;
    if (not defined $args{index} and defined $args{node}) {
      my $loc = $args{node}->manakai_get_source_location;
      if ($loc->[1] >= 0) {
        $args{di} = $loc->[1];
        $args{index} = $loc->[2];
      }
    }
    if (defined $args{node} and not defined $args{di} and not defined $args{value}) {
      $args{value} = $args{node}->node_value;
    }
    $args{node} = $node;
    delete $args{line};
    delete $args{column};
    delete $args{uri}; # XXX
    $_onerror->(%args);
  };
}; # $GetNestedOnError

## ------ Validator definitions and states ------

## Variable |$_Defs| (|$Web::HTML::Validator::_Defs|), defined in
## |Web::HTML::Validator::_Defs| module, is generated from
## |element.json| in <https://github.com/manakai/data-web-defs/>.  It
## contains various properties of elements and attributes, described
## in
## <https://github.com/manakai/data-web-defs/blob/master/doc/elements.txt>.

## $self->{is_rss2}      Whether it is an RSS2 document or not.

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
##   {in_a}              Set to true if there is an ancestor |a| element.
##   {in_a_href}         Set to true if there is an ancestor |a| element
##                       with a |href| attribute.
##   {in_canvas}         Set to true if there is an ancestor |canvas| element.
##   {in_head}           Set to true if there is an ancestor |head| element.
##   {in_media}          Set to true if there is an ancestor media element.
##   {in_phrasing}       Set to true if in phrasing content expecting element.
##   {is_template}       The checker is in the template mode [VALLANGS].
##   {is_xslt_stylesheet} The document is an XSLT stylesheet [VALLANGS].
##   {no_interactive}    Set to true if no interactive content is allowed.
##   {node_is_hyperlink}->{refaddr $node}
##                       Whether $node creates a hyperlink link or not.
##   {ogp_expected_types}->{refaddr $node} = [$node, {$type => true}]
##                       Allowed og:type values by $node.
##   {ogp_has_prop}->{$prop} Set to true if the property is specified.
##   {ogp_required_prop}->{$prop} Set to $node if it requires $prop.
##   {ogtype}            The value of og:type property.
##   {rss1_data}         RSS1 states.
##   {slots}->{$name}    Whether there is <slot name=$name> or not.

## $element_state
##
##   figcaptions     Used by |figure| element checker.
##   figure_embedded_count If the element is a |figure| element, the number
##                   of embedded content child elements.
##   figure_has_non_table If the element is a |figure| element, whether
##                   there is a non-|table| content or not.
##   figure_table_count If the element is a |figure| element, the number
##                   of |table| child elements.
##   has_datetime    Whether there is a |datetime| attribute or not.
##   has_dc_creator  There is a child |dc:creator| or not.
##   has_figcaption_content The element is a |figure| element and
##                   there is a |figcaption| child element whose content
##                   has elements and/or texts other than inter-element
##                   whitespaces.
##   has_heading     Has heading content (used for <summary> validation).
##   has_palpable    Set to true if a palpable content child is found.
##                   (Handled specially for <ruby>.)
##   has_phrasing    Has phrasing content (used for <summary> validation).
##   has_prop        Used by %PropContainerChecker.
##   has_rss2_author There is a child RSS2 |author| or not.
##   has_rss2_description There is a child RSS2 |description| or not.
##   has_rss2_title  There is a child RSS2 |title| or not.
##   has_summary     Used by |details| element checker.
##   in_flow_content Set to true while the content model checker is
##                   in the "flow content" checking mode.
##   in_picture      Used by |picture|/|source| element checker.
##   is_rss1_channel Is a |channel| element in the RSS namespace or not.
##   is_rss1_item    Is an |item| element in the RSS namespace or not.
##   is_rss1_items   Is an |items| element in the RSS namespace or not.
##   is_rss1_items_seq Is a |Seq| element in the RDF namespace in a
##                   |is_rss1_items| element or not.
##   is_rss1_rdf     Is an RSS 1.0 |rdf:RDF| element or not.
##   is_rss1_textinput Is a |textinput| element in the RSS namespace or not.
##   is_rss2_channel Is an RSS 2.0 |channel| element or not.
##   is_rss2_image   Is an RSS 2.0 |image| element or not.
##   is_rss2_item    Is an RSS 2.0 |item| element or not.
##   not_prop_container Used by %PropContainerChecker.
##   phase           Content model checker state name.  Possible values
##                   depend on the element.
##   require_title   Set to 'm' (MUST) or 's' (SHOULD) if the element
##                   is expected to have the |title| attribute.
##   rss2_channel_data RSS2 |channel| element and its descendants' data.
##   rss2_skip_data  RSS2 |skip*| element and its descendants' data.
##   style_type      The styling language's MIME type object.
##   text            Text data in the element.
##   *_original      Used to preserve |$self->{flag}->{*}|'s value.

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
  };
  $self->{onerror} = sub {
    if ($self->{flag}->{is_template}) {
      $self->{_onerror}->(@_, in_template => 1);
    } else {
      $self->{_onerror}->(@_);
    }
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
  delete $self->{top_level_item_elements};
  delete $self->{itemprop_els};
  delete $self->{flag};
  delete $self->{onerror};
} # _terminate

## For XML documents c.f. <http://www.whatwg.org/specs/web-apps/current-work/#serializing-xhtml-fragments>
## XXX warning public ID chars
## XXX warning system ID chars
## XXX warning "xmlns" attribute in no namespace
## XXX warning attribute name duplication
## XXX warning Comment.data =~ /--/ or =~ /-\z/
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
## XXX prefix SHOULD NOT begin with "xml" in upper or lower case [XMLNS]
## XXX warn if element and attribute names starts with "xml:" [XML]
## XXX warn if attribute definition is not serializable

## XXX In HTML documents
##   warning doctype name, pubid, sysid
##   warning element type definition, attribute definition
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
sub RSS_NS () { q<http://purl.org/rss/1.0/> }
sub RSS_CONTENT_NS () { q<http://purl.org/rss/1.0/modules/content/> }
sub ATOM_NS () { q<http://www.w3.org/2005/Atom> }
sub ATOM03_NS () { q<http://purl.org/atom/ns#> }
sub APP_NS () { q<http://www.w3.org/2007/app> }
sub THR_NS () { q<http://purl.org/syndication/thread/1.0> }
sub FH_NS () { q<http://purl.org/syndication/history/1.0> }
sub AT_NS () { q<http://purl.org/atompub/tombstones/1.0> }
sub LINK_REL () { q<http://www.iana.org/assignments/relation/> }
sub DC_NS () { q<http://purl.org/dc/elements/1.1/> }
sub MRSS1_NS () { q<http://search.yahoo.com/mrss/> }
sub MRSS2_NS () { q<http://search.yahoo.com/mrss> }

our $_Defs;

## ------ Text checker ------

## <http://www.whatwg.org/specs/web-apps/current-work/#text-content>
## <http://chars.suikawiki.org/set?expr=%24html%3AUnicode-characters+-+%5B%5Cu0000%5D+-+%24unicode%3ANoncharacter_Code_Point+-+%24html%3Acontrol-characters%20|%20$html:space-characters>
## + U+000C, U+000D
my $InvalidChar = qr{[^\x09\x0A\x{0020}-~\x{00A0}-\x{D7FF}\x{E000}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{1FFFD}\x{20000}-\x{2FFFD}\x{30000}-\x{3FFFD}\x{40000}-\x{4FFFD}\x{50000}-\x{5FFFD}\x{60000}-\x{6FFFD}\x{70000}-\x{7FFFD}\x{80000}-\x{8FFFD}\x{90000}-\x{9FFFD}\x{A0000}-\x{AFFFD}\x{B0000}-\x{BFFFD}\x{C0000}-\x{CFFFD}\x{D0000}-\x{DFFFD}\x{E0000}-\x{EFFFD}\x{F0000}-\x{FFFFD}\x{100000}-\x{10FFFD}]};

sub _check_data ($$) {
  my ($self, $node, $method) = @_;
  my $value = $node->$method;

  # XXX line/column by manakai_sps

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

  # XXX index
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
my $ElementTextCheckerByType = {};
my $ElementTextCheckerByName = {};
our $Element = {};
my $RSS2Element = {};

sub _check_element_attrs ($$$;%) {
  my ($self, $item, $element_state, %args) = @_;
  my $el_ns = $item->{node}->namespace_uri;
  $el_ns = '' unless defined $el_ns;
  my $el_ln = $item->{node}->local_name;
  my $allow_dataset = $el_ns eq HTML_NS;
  my $allow_custom = $el_ns eq HTML_NS && ($el_ln eq 'embed' || $el_ln =~ /-/);
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

    my $Ens = ($el_ns eq '' and $self->{is_rss2})
        ? $_Defs->{rss2_elements} : $_Defs->{elements}->{$el_ns};

    my $checker = $ElementAttrChecker->{$el_ns}->{$el_ln}->{$attr_ns}->{$attr_ln};
    my $attr_def = ($Ens->{$el_ln} or {})->{attrs}->{$attr_ns}->{$attr_ln};
    $checker ||= $CheckerByType->{$attr_def->{value_type} || ''}
        if defined $attr_def;

    $checker ||= $ElementAttrChecker->{$el_ns}->{'*'}->{$attr_ns}->{$attr_ln};
    $attr_def ||= $Ens->{'*'}->{attrs}->{$attr_ns}->{$attr_ln};
    $checker ||= $CheckerByType->{$attr_def->{value_type} || ''}
        if defined $attr_def;

    $checker ||= $NamespacedAttrChecker->{$attr_ns}->{$attr_ln};
    $attr_def ||= $_Defs->{elements}->{'*'}->{'*'}->{attrs}->{$attr_ns}->{$attr_ln};
    $checker ||= $CheckerByType->{$attr_def->{value_type} || ''}
        if defined $attr_def;

    $checker ||= $NamespacedAttrChecker->{$attr_ns}->{'*'};

    my $conforming = $attr_def->{conforming};
    if ($allow_dataset and
        $attr_ns eq '' and
        $attr_ln =~ /^data-\p{InNCNameChar}+\z/ and
        $attr_ln !~ /[A-Z]/) {
      ## |data-*=""| - XML-compatible + no uppercase letter
      $checker = $CheckerByType->{any};
      $conforming = 1;
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
    }
    if ($allow_custom and
        $attr_ns eq '' and
        $attr_ln !~ /[A-Z]/ and
        $attr_ln =~ /\A\p{InNCNameStartChar}\p{InNCNameChar}*\z/ and
        not $attr_def->{non_conforming}) {
      ## XML-compatible + no uppercase letter
      $checker ||= $CheckerByType->{any};
      $conforming = 1;
      if (not $attr_def->{conforming} and
          ($attr_def->{browser} or
           (not $ElementAttrChecker->{$el_ns}->{$el_ln}->{$attr_ns}->{$attr_ln} and
            $ElementAttrChecker->{$el_ns}->{'*'}->{$attr_ns}->{$attr_ln}))) {
        $self->{onerror}->(node => $attr,
                           type => 'attr:obsolete',
                           level => 'w');
      }
    }
    $checker->($self, $attr, $item, $element_state, $attr_def) if $checker;

    if ($conforming or $attr_def->{obsolete_but_conforming}) {
      unless ($checker) {
        ## According to the attribute list, this attribute is
        ## conforming.  However, current version of the validator does
        ## not support the attribute.  The conformance is unknown.
        $self->{onerror}->(node => $attr,
                           type => 'unknown attribute', level => 'u');
      } elsif ($attr_def->{limited_use} or
               $_Defs->{namespaces}->{$attr_ns}->{limited_use}) {
        $self->{onerror}->(node => $attr,
                           type => 'limited use',
                           level => 'w');
      }
    } else { # not conforming
      if (($_Defs->{namespaces}->{$el_ns}->{supported} and not $el_ns eq XSLT_NS) or
          $_Defs->{namespaces}->{$attr_ns}->{supported} or
          $_Defs->{namespaces}->{$el_ns}->{obsolete} or
          $_Defs->{namespaces}->{$attr_ns}->{obsolete} or
          $Element->{$el_ns}->{$el_ln} or
          ($el_ns eq '' and $self->{is_rss2})) {
        ## "Authors must not use elements, attributes, or attribute
        ## values that are not permitted by this specification or
        ## other applicable specifications" [HTML]
        if ($attr_ns eq '' and
            $attr_ln eq 'generator-unable-to-provide-required-alt' and
            $el_ns eq HTML_NS and
            $el_ln eq 'img') {
          #
        } else {
          if ($attr_def->{preferred}) {
            $self->{onerror}->(node => $attr,
                               type => 'attr:obsolete',
                               level => 'm',
                               preferred => $attr_def->{preferred});
          } else {
            $self->{onerror}->(node => $attr,
                               type => 'attribute not defined',
                               level => 'm');
          }
        }
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'unknown attribute',
                           level => 'u')
            unless defined $checker;
      }
    }

    $self->_check_data ($attr, 'value');
  } # $attr
} # _check_element_attrs

$CheckerByType->{any} = 
$ElementTextCheckerByType->{any} =
$CheckerByType->{text} =
$ItemValueChecker->{text} =
$ElementTextCheckerByType->{text} = sub { };

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

## One-line text
$CheckerByType->{'one-line text'} = sub {
  my ($self, $attr) = @_;
  if ($attr->value =~ /[\x0D\x0A]/) {
    $self->{onerror}->(node => $attr,
                       type => 'newline in value',
                       level => 'm');
  }
};

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

$CheckerByType->{'case-sensitive enumerated'} = sub {
  my ($self, $attr, undef, undef, $def) = @_;
  my $value = $attr->value;
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
}; # case-sensitive enumerated
$ElementTextCheckerByType->{'case-sensitive enumerated'} = sub {
  my ($self, $value, $onerror, $item) = @_;
  my $def = $item->{def_data};
  if ($def->{enumerated}->{$value} and not $value =~ /^#/) {
    if ($def->{enumerated}->{$value}->{conforming}) {
      return;
    } elsif ($def->{enumerated}->{$value}->{non_conforming}) {
      $onerror->(type => 'enumerated:non-conforming', level => 'm');
      return;
    }
  }
  $onerror->(type => 'enumerated:invalid', level => 'm');
}; # case-sensitive enumerated

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

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{tabindex} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  if ($value =~ /\A-0*[01]\z/ or $value =~ /\A0+\z/) {
    #
  } elsif ($value =~ /\A-?[0-9]+\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'tabindex:indexed',
                       level => 's');
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'integer:syntax error',
                       level => 'm');
  }
}; # tabindex=""

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
$ElementTextCheckerByType->{'non-negative integer'} = sub {
  my ($self, $value, $onerror) = @_;
  if ($value =~ /\A[0-9]+\z/) {
    #
  } else {
    $onerror->(type => 'nninteger:syntax error',
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
$ItemValueChecker->{'non-negative integer greater than zero'} = sub {
  my ($self, $value, $node) = @_;
  if ($value =~ /\A[0-9]+\z/) {
    if ($value > 0) {
      #
    } else {
      $self->{onerror}->(node => $node, type => 'nninteger:zero',
                         level => 'm');
    }
  } else {
    $self->{onerror}->(node => $node,
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

## Simple color [HTML]
$CheckerByType->{'simple color'} = sub {
  my ($self, $attr) = @_;
  unless ($attr->value =~ /\A#[0-9A-Fa-f]{6}\z/) {
    $self->{onerror}->(node => $attr,
                       type => 'scolor:syntax error',
                       level => 'm');
  }
};

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
$ItemValueChecker->{'MIME type'} = sub {
  my ($self, $value, $node) = @_;

  require Web::MIME::Type;
  my $onerror = sub {
    $self->{onerror}->(@_, node => $node);
  };

  ## Syntax-level validation
  my $type = Web::MIME::Type->parse_web_mime_type ($value, $onerror);

  ## Vocabulary-level validation
  if ($type) {
    $type->validate ($onerror);
  }

  return $type; # or undef
}; # MIME type

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
$ElementTextCheckerByType->{'language tag'} = sub {
  my ($self, $value, $onerror) = @_;
  require Web::LangTag;
  my $lang = Web::LangTag->new;
  $lang->onerror (sub {
    $onerror->(value => $value, @_);
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

## ISO 4217 currency code
$ItemValueChecker->{currency} = sub {
  my ($self, $value, $node) = @_;
  require Web::LangTag;
  my $lang = Web::LangTag->new;
  $value =~ tr/A-Z/a-z/;
  my $data = $lang->tag_registry_data ('u_cu', $value);
  unless ($data->{_registry}->{unicode}) {
    $self->{onerror}->(node => $node,
                       value => $value,
                       type => 'currency:not registered',
                       level => 'm');
  }
}; # currency

## OGP locale
$ItemValueChecker->{'OGP locale'} = sub {
  my ($self, $value, $node) = @_;
  if ($value =~ /\A[a-z]{2}_[A-Z]{2}\z/) {
    $value =~ tr/_/-/;
    require Web::LangTag;
    my $lang = Web::LangTag->new;
    $lang->onerror (sub {
      $self->{onerror}->(@_, node => $node);
    });
    my $parsed = $lang->parse_tag ($value);
    $lang->check_parsed_tag ($parsed);
  } else {
    $self->{onerror}->(node => $node,
                       value => $value,
                       type => 'OGP locale:bad value',
                       level => 'm');
  }
}; # OGP locale

## OGP country
$ItemValueChecker->{'OGP country'} = sub {
  my ($self, $value, $node) = @_;
  require Web::LangTag;
  my $lang = Web::LangTag->new;
  my $data = $lang->tag_registry_data ('region', $value);
  if (not $value =~ /\A[A-Z]{2}\z/ or
      not $data->{_registry}->{iana}) {
    $self->{onerror}->(node => $node,
                       value => $value,
                       type => 'langtag:region:invalid',
                       level => 'm');
  }
}; # OGP country

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

## URL
$CheckerByType->{URL} = sub {
  my ($self, $attr) = @_;
  ## NOTE: There MUST NOT be any white space.
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($attr->value);
  $chk->onerror (sub {
    $self->{onerror}->(@_, node => $attr);
  });
  $chk->check_iri_reference; # XXX URL Standard
  $self->{has_uri_attr} = 1;
}; # URL
$ElementTextCheckerByType->{URL} = sub {
  my ($self, $value, $onerror) = @_;
  ## NOTE: There MUST NOT be any white space.
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($value);
  $chk->onerror ($onerror);
  $chk->check_iri_reference; # XXX URL Standard
}; # URL
$ItemValueChecker->{URL} = sub {
  my ($self, $value, $node) = @_;
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($value);
  $chk->onerror (sub {
    $self->{onerror}->(@_, node => $node);
  });
  $chk->check_iri_reference; # XXX URL Standard
}; # URL

## Absolute URL
$ElementTextCheckerByType->{'absolute URL'} = sub {
  my ($self, $value, $onerror) = @_;
  ## NOTE: There MUST NOT be any white space.
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($value);
  $chk->onerror ($onerror);
  $chk->check_iri; # XXX URL Standard
}; # absolute URL
$CheckerByType->{'absolute URL'} = sub {
  my ($self, $attr) = @_;
  ## NOTE: There MUST NOT be any white space.
  require Web::URL::Checker;
  my $chk = Web::URL::Checker->new_from_string ($attr->value);
  $chk->onerror (sub {
    $self->{onerror}->(@_, node => $attr);
  });
  $chk->check_iri; # XXX URL Standard
  $self->{has_uri_attr} = 1;
}; # absolute URL

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
$ElementTextCheckerByType->{'e-mail address'} = sub {
  my ($self, $value, $onerror) = @_;
  $onerror->(type => 'email:syntax error',
             level => 'm')
      unless $value =~ qr/\A$ValidEmailAddress\z/o;
}; # e-mail address
$ItemValueChecker->{'e-mail address'} = sub {
  my ($self, $value, $node) = @_;
  $self->{onerror}->(node => $node,
                     type => 'email:syntax error',
                     level => 'm')
      unless $value =~ qr/\A$ValidEmailAddress\z/o;
}; # e-mail address

$ElementTextCheckerByType->{'RSS 2.0 person'} = sub {
  my ($self, $value, $onerror) = @_;
  $onerror->(type => 'rss2:person:syntax error',
             level => 's')
      unless $value =~ qr/\A$ValidEmailAddress \([^()]*\)\z/o;
}; # RSS 2.0 person

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

## OGP unit
$ItemValueChecker->{'OGP unit'} = sub {
  my ($self, $value, $node) = @_;
  $self->{onerror}->(node => $node,
                     type => 'OGP unit:bad value',
                     level => 'm')
      unless $Web::HTML::Validator::_Defs->{ogp}->{units}->{$value};
}; # OGP unit

## ------ ID references ------

## ID reference
$CheckerByType->{idref} = sub {
  my ($self, $attr, undef, undef, $def) = @_;
  push @{$self->{idref}}, [$def->{id_type} || 'any', $attr->value => $attr];
}; # ID reference

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

## XML DTD

sub force_dtd_validation ($;$) {
  if (@_ > 1) {
    $_[0]->{force_dtd_validation} = $_[1];
  }
  return $_[0]->{force_dtd_validation};
} # force_dtd_validation

sub _dtd ($$) {
  my ($self, $doc) = @_;
  if ($self->force_dtd_validation) {
    #
  } elsif ($doc->manakai_is_html) {
    return;
  } elsif (defined $doc->doctype) {
    #
  } else {
    $self->onerror->(level => 'i',
                     type => 'xml:no DTD validation',
                     node => $doc);
    return;
  }
  require Web::XML::DTDValidator;
  my $validator = Web::XML::DTDValidator->new;
  $validator->onerror ($self->onerror);
  $validator->validate_document ($doc);
} # _dtd

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

$NamespacedAttrChecker->{(XML_NS)}->{'*'} = sub {
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

$NamespacedAttrChecker->{(XMLNS_NS)}->{'*'} = sub {
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

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{role} = sub { };
$ElementAttrChecker->{(SVG_NS)}->{'*'}->{''}->{role} = sub { };
  ## ARIA requires the author to not mutate the "role" attribute value
  ## <https://w3c.github.io/aria/aria/aria.html#roles>.  This is a
  ## willful violation to that spec; we don't enforce such a strange
  ## requirement for compatibility with a broken implementation
  ## strategy.

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

  ## <https://w3c.github.io/aria/aria/aria.html#aria-dropeffect>
  ## aria-dropeffect="" is deprecated (reported through "preferred"
  ## checking).

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

## <https://w3c.github.io/aria/aria/aria.html#aria-grabbed>
## aria-grabbed="" is deprecated (reported through "preferred"
## checks).

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

sub _aria_not_preferred ($$$$) {
  my ($self, $node, $value, $preferred) = @_;
  if ($preferred->{type} eq 'html_attr' and
      ($node->owner_element->namespace_uri || '') eq HTML_NS) {
    if ($node->owner_element->has_attribute_ns (undef, $preferred->{name})) {
      $self->{onerror}->(node => $node,
                         type => 'aria:redundant:html-attr',
                         text => $preferred->{name},
                         level => 'w');
    } else {
      $self->{onerror}->(node => $node,
                         type => 'aria:not preferred markup:html-attr',
                         text => $preferred->{name},
                         level => 'w',
                         preferred => $preferred);
    }
  } else {
    my $type = $preferred->{type};
    $type =~ tr/_/-/;
    $self->{onerror}->(node => $node,
                       type => 'aria:not preferred markup:' . $type,
                       text => $preferred->{name} || $preferred->{scope}, # or undef
                       value => $value, # or undef
                       level => 'w',
                       preferred => $preferred);
  }
} # _aria_not_preferred

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
        if (($_Defs->{elements}->{$ns}->{$ln} or {})->{aria} or
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

        ## <https://w3c.github.io/aria/aria/aria.html#aria-owns>
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
          $state->{in_select} = $node->multiple ? 'multilist' : $node->size > 1 ? 'singlelist' : 'dropdown';
        } elsif ($ln eq 'optgroup') {
          $state->{in_select_optgroup} = $ancestor_state->{in_select};
          $state->{in_disabled_optgroup} = 1
              if $node->has_attribute_ns (undef, 'disabled');
        } elsif ($ln eq 'hgroup') {
          $state->{in_hgroup} = 1;
        } elsif ($ln eq 'datalist') {
          $state->{in_datalist} = 1;
        } elsif ($ln eq 'ul' or $ln eq 'ol' or # in spec
                 $ln eq 'menu' or $ln eq 'dir') { # not in spec
          $state->{in_ulol} = 1;
        }
        $state->{is_inert} = 1
            if $ancestor_state->{is_inert}; # XXX or inert by <dialog> or inert by browsing context container
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

    ## |aria-owns| attributes implied by HTML's semantics is not taken
    ## into account...  Is it really matter?
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

    my $aria_defs = ($_Defs->{elements}->{$ns}->{$ln} or {})->{aria};
    if ($ns eq HTML_NS and $ln eq 'input') {
      $aria_defs = $_Defs->{input}->{aria}->{$node->type};
    }

    # XXX need to update
    my $adef;
    if ($ns eq HTML_NS) {
      if ($ln eq 'img') {
        my $alt = $node->get_attribute_ns (undef, 'alt');
        if (defined $alt and not length $alt) {
          $adef = $aria_defs->{'empty-alt'};
        } else {
          $adef = $aria_defs->{'not-empty-alt'};
        }
      } elsif ($ln eq 'a' or $ln eq 'area' or $ln eq 'link') {
        $adef = $aria_defs->{'hyperlink'}
            if $node->has_attribute_ns (undef, 'href');
      } elsif ($ln eq 'select') {
        $adef = $aria_defs->{$node->multiple ? 'multilist' : 'singlelist'};
      } elsif ($ln eq 'option') {
        my $context = $node_context->{refaddr $node};
        if ($context->{in_select} or $context->{in_select_optgroup}) {
          $adef = $aria_defs->{'in-select'};
        } elsif ($context->{in_datalist}) {
          $adef = $aria_defs->{'in-datalist'};
        }
      } elsif ($ln eq 'li') {
        $adef = $aria_defs->{'in-ulol'}
            if $node_context->{refaddr $node}->{in_ulol};
      } elsif ($ln =~ /\Ah[1-6]\z/) {
        $adef = $aria_defs->{'no-hgroup'}
            unless $node_context->{refaddr $node}->{in_hgroup};
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
      if (defined $default_role and $default_role eq $role) {
        $self->{onerror}->(node => $role_attr,
                           type => 'aria:role:default role',
                           value => $role,
                           level => 'm');
        next;
      }

      my $conflict_error;
      if (($adef->{default_role} or $adef->{allowed_roles}) and
          not $adef->{allowed_roles}->{$role}) {
        $self->{onerror}->(node => $role_attr,
                           type => 'aria:role:conflict with semantics',
                           value => $role,
                           level => 'm');
        $conflict_error = 1;
      }

      my $preferred = $_Defs->{roles}->{$role}->{preferred};
      if ($preferred) {
        if ($preferred->{type} eq 'html_element' and
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
        } elsif ($preferred->{type} eq 'textbox' and
                 $ns eq HTML_NS and
                 (($ln eq 'input' and $node->type eq 'text') or
                  $ln eq 'textarea')) {
          $self->{onerror}->(node => $role_attr,
                             type => 'aria:redundant role',
                             value => $role,
                             level => 'w')
              unless $conflict_error;
        } else {
          _aria_not_preferred $self, $role_attr, $role, $preferred;
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

      # XXX element-specific disallowed ARIA attributes
      # XXX strong semantics attribute value validation

      if (not $allowed) {
        $self->{onerror}->(node => $attr,
                           type => 'aria:attr not allowed for role',
                           text => (join ' ', sort { $a cmp $b } keys %role),
                           level => 'm');
      } elsif ($adef->{attrs}->{$attr_ln} or
               ($attr_ln eq 'aria-hidden' and
                ($node->namespace_uri || '') eq HTML_NS and
                $node->has_attribute_ns (undef, 'hidden'))) {
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
        _aria_not_preferred $self, $attr, undef, $attr_def->{preferred};
      }
    } # $attr

    for my $role (keys %role) {
      next if $role{$role} eq 'implicit';
      my $role_def = $_Defs->{roles}->{$role};
      for my $attr_ln (keys %{$role_def->{attrs} or {}}) {
        if ($adef->{attrs}->{$attr_ln}) {
          #
        } elsif ($role_def->{attrs}->{$attr_ln}->{must}) {
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

    ## IMPLATTRCHK: Some codes below checks existence of an attribute.
    ## Strictly speaking, it should also check
    ## |$adef->{attrs}->{$attr_ln}| in addition to the element's
    ## attribute.  They skip it as this only occurs in invalid cases.

    ## <https://w3c.github.io/aria/aria/aria.html#aria-checked>
    if (defined $attr{'aria-checked'}) {
      if ($role{radio} or $role{menuitemradio}) {
        my $value = $attr{'aria-checked'}->value;
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
        $self->{onerror}->(node => $attr{'aria-checked'},
                           type => 'aria:checked:mixed but radio',
                           level => 'w')
            if $value eq 'mixed';
      }

# XXX role=switch aria-checked=mixed is "not supported"
# <http://w3c.github.io/aria/aria/aria.html#switch>.

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
        ## See IMPLATTRCHK note above.
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
        ## See IMPLATTRCHK note above.
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
          ## <https://w3c.github.io/aria/aria/aria.html#definition>
          # XXX aria-labelledby SHOULD point role=term.
          my $el = $attr->owner_element;
          if (($el->namespace_uri || '') eq HTML_NS and
              $el->local_name eq 'dfn') { # XXX
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
      ## See IMPLATTRCHK note above.
      $self->{onerror}->(node => $node,
                         type => 'attribute missing',
                         text => 'aria-describedby',
                         level => 's')
          if not defined $attr{'aria-describedby'} and
             ($node->namespace_uri || '') eq HTML_NS and
             $node->local_name eq 'img';
    }

    if ($role{dialog} and not $role{dialog} eq 'implicit') {
      ## See IMPLATTRCHK note above.
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
                           text => (join ' ', sort { $a cmp $b } keys %{$role_def->{must_contain}}),
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

      ## <https://w3c.github.io/aria/aria/aria.html#toolbar>
      if ($roles->{application} and @{$els->{toolbar}} > 1) {
        for (@{$els->{toolbar}}) {
          ## See IMPLATTRCHK note above.
          $self->{onerror}->(node => $_,
                             type => 'attribute missing',
                             text => 'aria-label',
                             level => 'm')
              unless $_->has_attribute_ns (undef, 'aria-label');
        }
      }

      if ((defined $roles->{document} and not $roles->{document} eq 'implicit') or
          (defined $roles->{application} and not $roles->{application} eq 'implicit')) {
        ## See IMPLATTRCHK note above.
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

    ## <https://w3c.github.io/aria/aria/aria.html#columnheader>
    ## XXX role=table > role=columnheader SHOULD NOT have aria-required, aria-readonly
    ## <https://w3c.github.io/aria/aria/aria.html#rowheader>
    ## XXX role=table > role=rowheader SHOULD NOT have aria-required, aria-readonly

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
      next if $roles->{$role} eq 'implicit';
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

# XXX role=text element SHOULD NOT be an interactive content or have
# an interactive content descendant
# <http://w3c.github.io/aria/aria/aria.html#text>.

# XXX <https://w3c.github.io/aria/aria/aria.html#combobox>
# role=combobox MUST must_contain <role=textbox|searchbox aria-multiline=false>.
# <role=combobox aria-expanded=true> MUST must_contain role=listbox|tree|grid|dialog (combobox popup).  <role=combobox aria-expanded=true> MUST has aria-controls={combobox popup}
# <role=combobox>'s aria-haspopup MUST be <role=combobox>'s combobox popup's role

# XXX <https://w3c.github.io/aria/aria/aria.html#dialog>
# <role=dialog> SHOULD have at least one focusable descendant element

# XXX <https://w3c.github.io/aria/aria/aria.html#feed>
# <role=feed> > <role=article> SHOULD be focusable

# XXX <https://w3c.github.io/aria/aria/aria.html#grid>
# <role=grid> with multiple <role=gridcell aria-selected=true> SHOULD have aria-multiselectable=true
# <role=gridcell aria-rowspan aria-colspan> SHOULD use rowspan="" colspan="" instead

# XXX <https://w3c.github.io/aria/aria/aria.html#group>
# <role=group> is used in list, its *children* must be role=listitem

# XXX <https://w3c.github.io/aria/aria/aria.html#none>
# role=none is equivalent to role=presentation

# XXX <https://w3c.github.io/aria/aria/aria.html#separator>
# focusable role=separator MUST have aria-valuenow
# In applications with multiple focusable role=separator, SHOULD have accessible name

# XXX <https://w3c.github.io/aria/aria/aria.html#switch>
# <role=switch aria-checked=mixed> is equivalent to aria-checked=false

# XXX <https://w3c.github.io/aria/aria/aria.html#table>
# role=table -> HTML <table>

# XXX <https://w3c.github.io/aria/aria/aria.html#term>
# role=term SHOULD NOT be interactive

# XXX <https://w3c.github.io/aria/aria/aria.html#aria-current>
# aria-current element MUST be unique

# XXX <https://w3c.github.io/aria/aria/aria.html#aria-errormessage>
# aria-errormessage MUST have aria-invalid=true

# XXX <https://w3c.github.io/aria/aria/aria.html#aria-roledescription>
# aria-roledescription SHOULD have explicit or implicit role
# aria-roledescription SHOULD have non whitespace character

# XXX role-based content model
# <https://w3c.github.io/html-aria/#allowed-aria-roles-states-and-properties>
# XXX separator is interactive content if focusable

## XXX <input readonly contenteditable> implies aria-readonly=true
## aria-readonly=false, which is really broken and should be detected
## by another steps of conformance checkers.

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

$IsPalpableContent->{(HTML_NS)}->{ul} =
$IsPalpableContent->{(HTML_NS)}->{ol} =
$IsPalpableContent->{(HTML_NS)}->{menu} = sub {
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
    if ($_->node_type == 1 and # ELEMENT_NODE
        ($_->namespace_uri || '') eq HTML_NS) {
      my $ln = $_->local_name;
      if ($ln eq 'dt' or $ln eq 'dd') {
        return 1;
      } elsif ($ln eq 'div') {
        for (@{$_->child_nodes}) {
          if ($_->node_type == 1 and # ELEMENT_NODE
              ($_->namespace_uri || '') eq HTML_NS) {
            return 1 if $_->local_name =~ /\Ad[td]\z/;
          }
        }
      }
    }
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
    #my ($self, $item, $child_el, $child_nsuri, $child_ln,
    #    $child_is_transparent, $element_state) = @_;
    #
  }, # check_child_element
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
      } else { ## in canvas
        return not {
          hidden => 1,
          checkbox => 1,
          radio => 1,
          submit => 1, image => 1, reset => 1, button => 1,
        }->{$value};
      }
    } elsif ($ln eq 'img') {
      if ($self->{flag}->{no_interactive} or not $self->{flag}->{in_canvas}) {
        return $el->has_attribute_ns (undef, 'usemap');
      } else { ## in canvas
        return 0;
      }
    } elsif ($ln eq 'object') {
      return $el->has_attribute_ns (undef, 'usemap');
    } elsif ($ln eq 'video' or $ln eq 'audio') {
      ## No media element is allowed as a descendant of a media
      ## element.
      return 1 if $self->{flag}->{in_media};

      return $el->has_attribute_ns (undef, 'controls');
    } elsif ($ln eq 'a') {
      return (($self->{flag}->{no_interactive} || !$self->{flag}->{in_canvas}) &&
              ($self->{flag}->{in_a} || $el->has_attribute_ns (undef, 'href')));
    } elsif ($ln eq 'button') {
      return $self->{flag}->{no_interactive} || !$self->{flag}->{in_canvas};
    } elsif ($ln eq 'select') {
      if ($self->{flag}->{no_interactive} or not $self->{flag}->{in_canvas}) {
        return 1;
      } else { ## in canvas
        return not ($el->multiple || $el->size > 1);
      }
    } else {
      return 1;
    }
  } # ns
} # _is_minus_element

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

## ---- XXX Common attribute syntacx checkers ----

# XXX deprecated
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

  my $value = $attr->value;
  if ($value eq '') {
    $self->{onerror}->(node => $attr,
                       type => 'empty control name',
                       level => 'm');
  } elsif ($value eq 'isindex') {
    $self->{onerror}->(node => $attr,
                       type => 'control name:isindex',
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

## Superglobal attribute id=""
$NamespacedAttrChecker->{''}->{id} = sub {
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

## Superglobal attribute class=""
$NamespacedAttrChecker->{''}->{class} = sub {
  my ($self, $attr) = @_;
  ## NOTE: "set of unique space-separated tokens".
  my %word;
  for my $word (grep {length $_}
                split /[\x09\x0A\x0C\x0D\x20]+/, $attr->value) {
    unless ($word{$word}) {
      $word{$word} = 1;
        push @{$self->{return}->{class}->{$word}||=[]}, $attr;
    } else {
      $self->{onerror}->(node => $attr,
                         type => 'duplicate token', value => $word,
                         level => 'w'); # not non-conforming
    }
  } # $word
}; # class=""

## Superglobal attribute slot=""
$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{slot} =
$NamespacedAttrChecker->{''}->{slot} = sub {
  my ($self, $attr) = @_;

  ## Any value.

  my $oe = $attr->owner_element;
  if (defined $oe) {
    my $parent = $oe->parent_node;
    if (defined $parent) {
      if (($parent->node_type == 1 and # ELEMENT_NODE
           $_Defs->{categories}->{'shadow_attachable'}->{elements}->{$parent->namespace_uri || ''}->{$parent->local_name}) or
          ($parent->node_type == 11)) { # DOCUMENT_FRAGMENT_NODE # XXX bare DocumentFragment and template content, not shadow root
        # XXX custom elements
        # XXX and if $parent->shadow_root is not null
        #
      } else {
        $self->{onerror}->(node => $attr,
                           type => 'slot:parent not host',
                           level => 'w');
      }
    }
  }
}; # slot=""

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{dir} = $GetHTMLEnumeratedAttrChecker->({
  ltr => 1,
  rtl => 1,
  auto => 'last resort:good',
}); # dir=""

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
                       level => 'w',
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

$ElementAttrChecker->{(HTML_NS)}->{'*'}->{''}->{is} = sub {
  my ($self, $attr) = @_;

  my $value = $attr->value;
  unless ($value =~ /\A[a-z]\p{InPCENChar}*\z/ and
          $value =~ /-/ and
          not $_Defs->{not_custom_element_names}->{$value}) {
    $self->{onerror}->(node => $attr,
                       type => 'is:not custom element name',
                       value => $value,
                       level => 'm');
  }

  ## XXX autonomous custom element's local names and is="" attribute
  ## values share same namespace.  Warn if is="" value is also used
  ## for local names.
  
  ## is="" can't be specified on autonomous custom elements.  This is
  ## checked by |*-*|'s |check_attrs2|.
}; # is=""

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
    $coords = [split /,/, $attrs->{coords}->value, -1];
    $coords = [''] unless @$coords;
    for (@$coords) {
      unless (m{\A
        (-? (?> [0-9]+ (?>(\.[0-9]+))? | \.[0-9]+))
        (?>[Ee] ([+-]?[0-9]+) )?
      \z}x) {
        $self->{onerror}->(node => $attrs->{coords},
                           type => 'coords:syntax error',
                           level => 'm',
                           value => $_);
        return;
      }
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
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:empty',
                       level => 'm');
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
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    my $el_nsurl = $item->{node}->namespace_uri || '';
    my $el_ln = $item->{node}->local_name;
    my $tt = $item->{def_data}->{text_type};
    my $checker = $ElementTextCheckerByName->{$el_nsurl}->{$el_ln}
        || $ElementTextCheckerByType->{$tt || ''};
    if (defined $checker) {
      my ($value, undef, $sps, undef) = node_to_text_and_tc_and_sps $item->{node};
      my $onerror = $GetNestedOnError->($self->onerror, $item->{node});
      $checker->($self, $value, $onerror, $item);
    } elsif (defined $tt) {
      $self->{onerror}->(node => $item->{node},
                         type => 'unknown value type',
                         text => $tt,
                         level => 'u');
    } # $checker
  }, # check_end
); # %HTMLTextChecker

my %HTMLFlowContentChecker = (
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    unless ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
            $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
            ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:flow',
                         level => 'm');
    }
  }, # check_child_element
); # %HTMLFlowContentChecker

my %HTMLPhrasingContentChecker = (
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    ## Will be restored by |check_end| of
    ## |%HTMLPhrasingContentChecker|.
    $element_state->{in_phrasing_original} = $self->{flag}->{in_phrasing};
    $self->{flag}->{in_phrasing} = 1;
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    unless ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
            $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
            ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
    if ($self->{flag}->{in_phrasing}) { # phrasing content
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
        #
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:phrasing',
                           level => 'm');
      }
    } else { # flow content
      unless ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
              $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
              ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
    }
  }, # check_child_element
); # %TransparentChecker

my %PropContainerChecker = (
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    return if $element_state->{not_prop_container};

    if (($element_state->{phase} || '') eq 'rdfresourceref') {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed',
                         level => 'm');
      return;
    }

    my $el_def_data = $item->{def_data};

    my $children = $el_def_data->{child_elements}->{$child_nsuri}->{$child_ln};
    if (defined $children->{min}) {
      my $n = ++$element_state->{has_element}->{$child_nsuri}->{$child_ln};
      if (defined $children->{max}) { # max < +Infinity
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:duplicate',
                           level => 'm')
            if $children->{max} < $n;
      }
      return;
    }

    if ($el_def_data->{unknown_children}) {
      if ($el_def_data->{unknown_children} eq 'nordf') {
        if (defined $element_state->{has_prop}->{$child_nsuri}->{$child_ln}) {
          $self->{onerror}->(node => $child_el,
                             type => 'rss1:duplicate prop',
                             level => 'm');
          return;
        } else {
          $element_state->{has_prop}->{$child_nsuri}->{$child_ln} = 1;
        }
      }

      if ($child_nsuri eq '') { # null namespace
        # XXX if RSS2
        return unless $el_def_data->{unknown_children} eq 'nordf';
      } elsif ($_Defs->{namespaces}->{$child_nsuri}->{supported}) { # fully supported [VALLANGS]
        #
      } else { # partially supported or not supported [VALLANGS]
        unless ($el_def_data->{unknown_children} eq 'nordf' and
                ($child_nsuri eq RDF_NS or
                 ($child_ln =~ /^[Xx][Mm][Ll]/ and not defined $child_el->prefix) or
                 ($child_el->prefix || '') =~ /^[Xx][Mm][Ll]/)) {
          return unless defined $_Defs->{elements}->{$child_nsuri}->{$child_ln};
        }
      }
    } # unknown children

    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed',
                       level => 'm');
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    return if $element_state->{not_prop_container};
    if ($has_significant) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    return if $element_state->{not_prop_container};
    return if ($element_state->{phase} || '') eq 'rdfresourceref';

    my $children = $item->{def_data}->{child_elements};
    for my $ns (keys %$children) {
      for my $ln (keys %{$children->{$ns} or {}}) {
        my $min = $children->{$ns}->{$ln}->{min} || 0;
        my $n = $element_state->{has_element}->{$ns}->{$ln} || 0;
        $self->{onerror}->(node => $item->{node},
                           type => {
                             ATOM_NS, 'child element missing:atom',
                             ATOM03_NS, 'child element missing:atom',
                             APP_NS, 'child element missing:app',
                           }->{$ns} || 'child element missing',
                           text => $ln,
                           level => 'm')
            if $min > $n;
      }
    }
  }, # check_end
); # %PropContainerChecker

my $AtomTextConstructTypeAttrChecker = sub {
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
}; # $AtomTextConstructTypeAttrChecker

my $Atom03ContentConstructModeAttrChecker = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  unless ($value eq 'xml' or $value eq 'escaped' or $value eq 'base64') {
    $self->{onerror}->(node => $attr,
                       type => 'invalid attribute value',
                       level => 'm');
  }
}; # $Atom03ContentConstructModeAttrChecker

our $CheckDIVContent; # XXX
my %AtomTextConstruct = (
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{type} = 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($element_state->{type} eq 'text' or
        $element_state->{type} eq 'html') { # MUST NOT
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:atom|TextConstruct',
                         level => 'm');
    } elsif ($element_state->{type} eq 'xhtml') {
      if ($child_nsuri eq q<http://www.w3.org/1999/xhtml> and
          $child_ln eq 'div') { # MUST
        if ($element_state->{has_div}) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:atom|TextConstruct',
                             level => 'm');
        } else {
          $element_state->{has_div} = 1;
        }
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:atom|TextConstruct',
                           level => 'm');
      }
    } else {
      die "atom:TextConstruct type error: $element_state->{type}";
    }
  },
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($element_state->{type} eq 'text') {
      #
    } elsif ($element_state->{type} eq 'html') {
      #
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
      $CheckDIVContent->($self, $item->{node});
    }

    $AnyChecker{check_end}->(@_);
  },
); # %AtomTextConstruct

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
    } elsif ($cm eq 'atomTextConstruct') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $AtomTextConstruct{$_} for keys %AtomTextConstruct;
      $ElementAttrChecker->{$ns}->{$ln}->{''}->{type}
          = $AtomTextConstructTypeAttrChecker;
    } elsif ($cm eq 'props' or
             $cm eq 'atomPersonConstruct' or
             $cm eq 'atom03PersonConstruct') {
      $Element->{$ns}->{$ln eq '*' ? '' : $ln}->{$_}
          = $PropContainerChecker{$_} for keys %PropContainerChecker;
    } elsif ($cm eq 'atom03ContentConstruct') {
      $ElementAttrChecker->{$ns}->{$ln}->{''}->{mode}
          = $Atom03ContentConstructModeAttrChecker;
    }
  }
}
for my $ln (keys %{$_Defs->{rss2_elements}}) {
  my $cm = $_Defs->{rss2_elements}->{$ln}->{content_model} or next;
  if ($cm eq 'text') {
    $RSS2Element->{$ln eq '*' ? '' : $ln}->{$_}
        = $HTMLTextChecker{$_} for keys %HTMLTextChecker;
  } elsif ($cm eq 'empty') {
    $RSS2Element->{$ln eq '*' ? '' : $ln}->{$_}
        = $HTMLEmptyChecker{$_} for keys %HTMLEmptyChecker;
  } elsif ($cm eq 'props') {
    $RSS2Element->{$ln eq '*' ? '' : $ln}->{$_}
        = $PropContainerChecker{$_} for keys %PropContainerChecker;
  }
}

## ---- Date and time ----
{
  my $attr_checker = sub ($) {
    my $type = shift;
    return sub {
      my ($self, $attr, $item, $element_state) = @_;
      
      require Web::DateTime::Parser;
      my $dp = Web::DateTime::Parser->new;
      $dp->onerror (sub {
        my %opt = @_;
        $self->{onerror}->(%opt, node => $attr);
      });
      
      my $method = 'parse_' . $type;
      my $obj = $dp->$method ($attr->value);
      $element_state->{date_value}->{$attr->name} = $obj;
    };
  }; # $attr_checker
  my $value_checker = sub ($) {
    my $type = shift;
    return sub {
      my ($self, $value, $node) = @_;
      
      require Web::DateTime::Parser;
      my $dp = Web::DateTime::Parser->new;
      $dp->onerror (sub {
        my %opt = @_;
        $self->{onerror}->(%opt, node => $node);
      });
      
      my $method = 'parse_' . $type;
      $dp->$method ($value);
    };
  }; # $value_checker
  my $text_checker = sub {
    my $type = shift;
    return sub {
      my ($self, $value, $onerror) = @_;
      
      require Web::DateTime::Parser;
      my $dp = Web::DateTime::Parser->new;
      $dp->onerror ($onerror);
      
      my $method = 'parse_' . $type;
      $dp->$method ($value);
    };
  }; # $text_checker

  $CheckerByType->{'global date and time string'}
      = $attr_checker->('global_date_and_time_string');
  $ItemValueChecker->{'global date and time string'}
      = $value_checker->('global_date_and_time_string');

  $CheckerByType->{'local date and time string'}
      = $attr_checker->('local_date_and_time_string');

  $CheckerByType->{'date string'} = $attr_checker->('date_string');
  $ItemValueChecker->{'date string'} = $value_checker->('date_string');

  $CheckerByType->{'month string'} = $attr_checker->('month_string');
  $CheckerByType->{'week string'} = $attr_checker->('week_string');
  $CheckerByType->{'time string'} = $attr_checker->('time_string');

  $CheckerByType->{'date string with optional time'}
      = $attr_checker->('date_string_with_optional_time');
  $ItemValueChecker->{'date string with optional time'}
      = $value_checker->('date_string_with_optional_time');

  $ItemValueChecker->{'vcard tz'}
      = $value_checker->('vcard_time_zone_offset_string');
  $ItemValueChecker->{'vevent duration'} =
      $value_checker->('vevent_duration_string');
  $ItemValueChecker->{'vevent rdate'} =
      $value_checker->('date_string_with_optional_time_and_duration');
  $ItemValueChecker->{'ISO 8601 date'} =
      $value_checker->('iso8601_date_string');
  $ItemValueChecker->{'ISO 8601 duration'} =
      $value_checker->('iso8601_duration_string');
  $ItemValueChecker->{'schema.org date'} =
      $value_checker->('iso8601_date_string');
  $ItemValueChecker->{'schema.org datetime'} =
      $value_checker->('schema_org_date_time_string');
  $ItemValueChecker->{'schema.org duration'} =
      $value_checker->('iso8601_duration_string');
  $ItemValueChecker->{'schema.org time'} =
      $value_checker->('xs_time_string');
  $ItemValueChecker->{'weekly time range'} =
      $value_checker->('weekly_time_range_string');
  $ItemValueChecker->{'OGP DateTime'} =
      $value_checker->('ogp_date_time_string');

  $CheckerByType->{'atomDateConstruct'} =
      $attr_checker->('rfc3339_xs_date_time_string');
  $ElementTextCheckerByType->{'atomDateConstruct'} =
      $text_checker->('rfc3339_xs_date_time_string');

  $ElementTextCheckerByType->{'atom03DateConstruct'} =
  $ElementTextCheckerByType->{'W3C-DTF'} =
      $text_checker->('w3c_dtf_string');

  $ElementTextCheckerByType->{'RSS 2.0 date'} =
      $text_checker->('rss2_date_time_string');

  ## <time>
  $ElementAttrChecker->{(HTML_NS)}->{time}->{''}->{datetime} = sub { };
  $Element->{+HTML_NS}->{time}->{check_start} = sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'datetime')) {
      $element_state->{has_datetime} = 1;
      $HTMLPhrasingContentChecker{check_start}->(@_);
    } else {
      $HTMLTextChecker{check_start}->(@_);
    }
  }; # check_start
  $Element->{+HTML_NS}->{time}->{check_child_element} = sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($element_state->{has_datetime}) {
      $HTMLPhrasingContentChecker{check_child_element}->(@_);
    } else {
      $HTMLTextChecker{check_child_element}->(@_);
    }
  }; # check_child_element
  $Element->{+HTML_NS}->{time}->{check_child_text} = sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($element_state->{has_datetime}) {
      $HTMLPhrasingContentChecker{check_child_text}->(@_);
    } else {
      $HTMLTextChecker{check_child_text}->(@_);
    }
  }; # check_child_text
  $Element->{+HTML_NS}->{time}->{check_end} = sub {
    my ($self, $item, $element_state) = @_;

    my $node;
    my $value;
    if ($element_state->{has_datetime}) {
      $node = $item->{node}->get_attribute_node_ns (undef, 'datetime');
      $value = $node->value;
    } else {
      $node = $item->{node};
      $value = $node->text_content;
    }

    require Web::DateTime::Parser;
    my $dp = Web::DateTime::Parser->new;
    $dp->onerror (sub {
      $self->{onerror}->(@_, node => $node);
    });
    $dp->parse_html_datetime_value ($value);

    if ($element_state->{has_datetime}) {
      $HTMLPhrasingContentChecker{check_end}->(@_);
    } else {
      $HTMLTextChecker{check_end}->(@_);
    }
  }; # check_end
}

## ---- The root element ----

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
    if ($element_state->{phase} eq 'before head') {
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
  ## $item->{is_noscript} - It is actually a |noscript|, not |head|
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{in_head_original} = $self->{flag}->{in_head};
    $self->{flag}->{in_head} = 1;
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($child_nsuri eq HTML_NS and $child_ln eq 'title') {
      if ($item->{is_noscript}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:head noscript',
                           level => 'm');
      } elsif (not $element_state->{has_title}) {
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
    my $rel = $rel_attr ? $self->_link_types ($rel_attr, multiple => 1, context => 'html_link') : {};

    if ($item->{node}->has_attribute_ns (undef, 'href')) {
      $self->{has_hyperlink_element} = 1 if $rel->{is_hyperlink};
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
      my $body_ok = 1;
      for (keys %{$rel->{link_types}}) {
        my $def = $Web::HTML::Validator::_Defs->{link_types}->{$_} || {};
        unless ($def->{body_ok}) {
          $body_ok = 0;
          last;
        }
      }
      unless ($body_ok) {
        $self->{onerror}->(node => $item->{node},
                           type => 'link:not body-ok',
                           text => $rel_attr->value,
                           level => 'm');
      }
    }

    for my $name (qw(sizes as
                     color integrity)) {
      my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
      next unless defined $attr;

      my $allowed = 0;
      for (keys %{$rel->{link_types} or {}}) {
        my $def = $Web::HTML::Validator::_Defs->{link_types}->{$_} || {};
        if ($def->{$name}) {
          $allowed = 1;
          last;
        }
      }

      unless ($allowed) {
        $self->{onerror}->(node => $attr,
                           # link:ignored sizes
                           # link:ignored as
                           # link:ignored color
                           # link:ignored integrity
                           type => 'link:ignored ' . $name,
                           level => 'm');
      }
    } # $name

    if ($rel->{link_types}->{alternate} and $rel->{link_types}->{stylesheet}) {
      my $title_attr = $item->{node}->get_attribute_node_ns (undef, 'title');
      unless ($title_attr) {
        $element_state->{require_title} = 'm';
      } elsif ($title_attr->value eq '') {
        $self->{onerror}->(node => $title_attr,
                           type => 'empty style sheet title',
                           level => 'm');
      }
    }

    unless ($rel->{is_external_resource_link}) {
      for my $name (qw(nonce crossorigin)) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
        $self->{onerror}->(node => $attr,
                           # non external resource crossorigin
                           # non external resource nonce
                           type => 'non external resource ' . $name,
                           level => 'w')
            if defined $attr;
      }
    }
  }, # check_attrs2
}; # link

$ElementAttrChecker->{(HTML_NS)}->{meta}->{''}->{$_} = sub {}
    for qw(charset content http-equiv name property); ## Checked by |check_attrs2|

my $HTTPEquivChecker = { };
$HTTPEquivChecker->{'content-type'} = sub { };
$HTTPEquivChecker->{'default-style'} = $CheckerByType->{'non-empty text'};
$HTTPEquivChecker->{'refresh'} = sub {
  my ($self, $attr) = @_;
  my $content = $attr->value;
  if ($content =~ /\A[0-9]+\z/) { # Non-negative integer.
    #
  } elsif ($content =~ s/\A[0-9]+;[\x09\x0A\x0C\x0D\x20]+[Uu][Rr][Ll]=//) { # Non-negative integer, ";", space characters, "URL" ASCII case-insensitive, "="
    if ($content =~ m{^[\x22\x27]}) {
      $self->{onerror}->(node => $attr,
                         value => $content,
                         type => 'refresh:bad url',
                         level => 'm');
    }

    ## URL [URL]
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($content);
    $chk->onerror (sub {
      $self->{onerror}->(value => $content, @_, node => $attr);
    });
    $chk->check_iri_reference; # XXX
    $self->{has_uri_attr} = 1; ## NOTE: One of "attributes with URLs".
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'refresh:syntax error',
                       level => 'm');
  }
}; # <meta http-equiv=refresh>
$HTTPEquivChecker->{'x-ua-compatible'} = sub {
  my ($self, $attr) = @_;
  $self->{onerror}->(node => $attr,
                     type => 'invalid attribute value',
                     level => 'm')
      unless $attr->value =~ /\A[Ii][Ee]=[Ee][Dd][Gg][Ee]\z/;
}; # <meta http-equiv=x-ua-compatible>
## BCP 47 language tag [OBSVOCAB]
$HTTPEquivChecker->{'content-language'} = $CheckerByType->{'language tag'};
## XXX set-cookie-string [OBSVOCAB]
#$HTTPEquivChecker->{'set-cookie'}


## <meta name> content validators
my $CheckerByMetadataName = { };
$CheckerByMetadataName->{keywords} = sub { };

$CheckerByMetadataName->{'referrer'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  if (length $value and ($_Defs->{elements}->{+HTML_NS}->{a}->{attrs}->{''}->{referrerpolicy}->{enumerated}->{$value} || {})->{conforming}) {
    #
  } elsif ($value eq 'always' or
           $value eq 'default' or
           $value eq 'never' or
           $value eq 'origin-when-crossorigin') {
    $self->{onerror}->(node => $attr,
                       type => 'enumerated:non-conforming',
                       level => 'm');
  } else {
    $self->{onerror}->(node => $attr,
                       type => 'enumerated:invalid',
                       level => 'm');
  }

  my $oe = $attr->owner_element;
  if (defined $oe) {
    my $parent = $oe->parent_node;
    if (defined $parent and
        $parent->node_type == 1) { # ELEMENT_NODE
      my $head = $oe->owner_document->head;
      unless (defined $head and $parent eq $head) {
        $self->{onerror}->(node => $oe,
                           type => 'element not allowed',
                           level => 'w');
      }
    }
  }
}; # referrer

# <color>
$ElementAttrChecker->{(HTML_NS)}->{link}->{''}->{color} =
$CheckerByMetadataName->{'theme-color'} = sub {
  my ($self, $attr) = @_;
  require Web::CSS::Parser;
  my $parser = Web::CSS::Parser->new;
  $parser->media_resolver->set_supported (all => 1);
  $parser->init_parser;
  $parser->onerror ($GetNestedOnError->($self->onerror, $attr));
  my $parsed = $parser->parse_char_string_as_prop_value ('color', $attr->value);
  if (not defined $parsed) {
    ## Reported to $parser->onerror
    #
  } else {
    my $value = $parsed->{prop_values}->{color};
    if ($value->[0] eq 'KEYWORD' and
        {
          inherit => 1, initial => 1, # XXX non-<color> values
        }->{$value->[1]}) {
      $self->{onerror}->(node => $attr,
                         type => 'css:color:syntax error',
                         level => 'm');
    }
  }
}; # theme-color

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
      my $property_attr = $el->get_attribute_node_ns (undef, 'property'),
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
    } # name="" http-equiv="" charset="" itemprop="" property=""

    my $content_attr = $el->get_attribute_node_ns (undef, 'content');
    if ($name_attr or $http_equiv_attr or $itemprop_attr or $property_attr) {
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

      my $def = $Web::HTML::Validator::_Defs->{metadata_names}->{$name} || {};
      my $checker = $CheckerByMetadataName->{$name} || $CheckerByType->{$def->{value_type} || ''};
      if ($def->{conforming}) {
        $checker ||= sub {
          $self->{onerror}->(node => $name_attr,
                             type => 'unknown metadata name',
                             value => $name,
                             level => 'u');
        };
      } else {
        if (defined $def->{whatwg_wiki_status} and
            ($def->{whatwg_wiki_status} eq 'unendorsed' or
             $def->{whatwg_wiki_status} eq 'incomplete proposal' or
             $def->{whatwg_wiki_status} eq 'proposal')) { # registered but non-conforming
          $self->{onerror}->(type => 'metadata:discontinued',
                             text => $name,
                             node => $name_attr,
                             level => 'm',
                             preferred => $def->{preferred}); # or undef
        } else {
          $self->{onerror}->(type => 'metadata:not registered',
                             text => $name,
                             node => $name_attr,
                             level => 'm',
                             preferred => $def->{preferred}); # or undef
        }
      }
      $checker->($self, $content_attr) if defined $content_attr and defined $checker;

      if ($def->{unique} or $def->{unique_per_lang}) { # XXX lang="" support
        unless ($self->{flag}->{html_metadata}->{$name}) {
          $self->{flag}->{html_metadata}->{$name} = 1;
        } else {
          $self->{onerror}->(type => 'metadata:duplicate',
                             text => $name,
                             node => $name_attr,
                             level => 'm');
        }
      }
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

      if ($keyword eq 'content-type') {
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
      }

      my $def = $Web::HTML::Validator::_Defs->{http_equiv}->{$keyword} || {};
      my $content_checker = $HTTPEquivChecker->{$keyword};
      if ($def->{conforming}) {
        $content_checker ||= sub {
          $self->{onerror}->(node => $http_equiv_attr,
                             type => 'unknown http-equiv',
                             value => $keyword,
                             level => 'u');
        };
      } else {
        if (($def->{spec} || '') eq 'HTML') {
          $self->{onerror}->(node => $http_equiv_attr,
                             type => 'enumerated:non-conforming',
                             level => 'm');
        } else {
          $self->{onerror}->(node => $http_equiv_attr,
                             type => 'enumerated:invalid',
                             level => 'm');
        }
      }

      if ($content_attr) {
        $content_checker->($self, $content_attr) if defined $content_checker;
      }
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
                         type => 'srcdoc:charset',
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

    if (defined $property_attr) {
      ## <meta property="" content="">: Only OGP (and its extensions)
      ## is supported:
      ## <http://suika.suikawiki.org/www/markup/xml/validation-langs#ogp>,
      ## <https://github.com/manakai/data-web-defs/blob/master/data/ogp.json>.

      ## If there is one or more <meta property> element:
      for (keys %{$Web::HTML::Validator::_Defs->{ogp}->{types}->{'*'}->{requires} or {}}) {
        $self->{flag}->{ogp_required_prop}->{$_} = $property_attr;
      }

      my $prop = $property_attr->value;
      my $prop_def = $Web::HTML::Validator::_Defs->{ogp}->{props}->{$prop};
      if ($prop_def) {
        if ($prop_def->{deprecated}) {
          $self->{onerror}->(node => $property_attr,
                             type => 'ogp:prop:deprecated',
                             level => 's');
        }
        if ($prop_def->{target_type} and
            not $prop_def->{target_type}->{'*'}) {
          $self->{flag}->{ogp_expected_types}->{refaddr $property_attr}
              = [$property_attr, $prop_def->{target_type}];
        }
        unless ($prop_def->{array} or $prop_def->{array_item}) {
          $self->{onerror}->(node => $property_attr,
                             type => 'ogp:prop:duplicate',
                             level => 'm')
              if $self->{flag}->{ogp_has_prop}->{$prop};
        }
        $self->{flag}->{ogp_has_prop}->{$_}++
            for $prop, keys %{$prop_def->{aliases} or {}};
        for (keys %{$Web::HTML::Validator::_Defs->{ogp}->{props}->{$prop}->{requires} or {}}) {
          $self->{flag}->{ogp_required_prop}->{$_} = $property_attr;
        }
        if (defined $content_attr) {
          if ($prop eq 'og:type') {
            my $content = $self->{flag}->{ogtype} = $content_attr->value;
            if ($Web::HTML::Validator::_Defs->{ogp}->{types}->{$content} and not $content eq '*') {
              for (keys %{$Web::HTML::Validator::_Defs->{ogp}->{types}->{$content}->{requires} or {}}) {
                $self->{flag}->{ogp_required_prop}->{$_} = $content_attr;
              }
            } elsif ($content =~ /\A([^:]+):(.+)\z/s) {
              if ($Web::HTML::Validator::_Defs->{ogp}->{prefixes}->{$1}) {
                $self->{onerror}->(node => $content_attr,
                                   type => 'ogp:og:type:bad value',
                                   level => 'm');
              } else {
                $self->{onerror}->(node => $content_attr,
                                   type => 'ogp:og:type:private value',
                                   level => 'w');
              }
            } else {
              $self->{onerror}->(node => $content_attr,
                                 type => 'ogp:og:type:bad value',
                                 level => 'm');
            }
          } elsif (defined $prop_def->{value_type}) {
            my $checker = $ItemValueChecker->{$prop_def->{value_type}};
            if ($checker) {
              $checker->($self, $content_attr->value, $content_attr);
            } else {
              $self->{onerror}->(node => $content_attr,
                                 type => 'microdata:unknown type',
                                 text => $prop_def->{value_type},
                                 level => 'u');
            }
          } elsif (defined $prop_def->{enums}) {
            my $content = $content_attr->value;
            unless (defined $prop_def->{enums}->{$content}) {
              $self->{onerror}->(node => $content_attr,
                                 type => 'ogp:enum:bad value',
                                 text => $prop,
                                 level => 'm');
            }
          }
        }
      } elsif ($prop =~ /\A([^:]+):(.+)\z/s) {
        if ($Web::HTML::Validator::_Defs->{ogp}->{prefixes}->{$1}) {
          $self->{onerror}->(node => $property_attr,
                             type => 'ogp:bad property',
                             level => 'm');
        } else {
          $self->{onerror}->(node => $property_attr,
                             type => 'ogp:private property',
                             level => 'w');
        }
      } else {
        $self->{onerror}->(node => $property_attr,
                           type => 'ogp:bad property',
                           level => 'm');
      }
    } # $property_attr

    ## Whether the character encoding declaration's encoding is UTF-8
    ## or not is not checked here.  If it is inconsitent with the
    ## document's encoding, it is an error detected here.  If it is
    ## consitent but the document's encoding is not UTF-8, the
    ## |_check_doc_charset| method detects an error.
  }, # check_attrs2
}; # meta

$Element->{+HTML_NS}->{style} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed',
                       level => 'm');
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my ($text, $tc, $text_sps, $tc_sps)
        = node_to_text_and_tc_and_sps $item->{node};

    my $parser = $self->_css_parser ($item->{node}, $text, $text_sps);
    my $ss = $parser->parse_char_string_as_ss ($text);
    # XXX Web::CSS::Checker->new->check_ss ($ss);

    $AnyChecker{check_end}->(@_);
  },
}; # style

$ElementAttrChecker->{(HTML_NS)}->{style}->{''}->{type} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  if ($value =~ m{\A[Tt][Ee][Xx][Tt]/[Cc][Ss][Ss]\z}) {
    $self->{onerror}->(node => $attr, type => 'style type:text/css',
                       level => 's'); # obsolete but conforming
  } else {
    $self->{onerror}->(node => $attr, type => 'style type', level => 'm');
  }
}; # <style type="">

sub _link_types ($$%) {
  my ($self, $attr, %args) = @_;

  my @link_type;
  my %word;
  if ($args{multiple}) {
    die if $args{case_sensitive};
    ## HTML |rel| attribute - set of space separated tokens, whose
    ## allowed values are defined by the section on link types

    my $value = $attr->value;

    for my $word (grep {length $_} split /[\x09\x0A\x0C\x0D\x20]+/, $value) {
      $word =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
      unless ($word{$word}) {
        $word{$word} = 1;
        push @link_type, $word;
      } elsif ($word eq 'up') {
        ## |up up| has special semantics [HTMLPRE5924]
        #
      } else {
        $self->{onerror}->(node => $attr, value => $word,
                           type => 'duplicate token',
                           level => 'm');
      }
    } # $word
  } else { # single
    die unless $args{case_sensitive};
    push @link_type, $attr->value;
    $word{$link_type[-1]} = 1;
  }

  my $is_hyperlink;
  my $is_external_resource_link;
  for my $link_type (@link_type) {
    my $def = $Web::HTML::Validator::_Defs->{link_types}->{$link_type} || {};
    my $effect = $def->{$args{context}} || 'not allowed';
    if ($def->{conforming}) {
      if ($effect eq 'hyperlink' or $effect eq '1') {
        ## |alternate stylseheet| has special semantics [HTML]
        $is_hyperlink = 1 unless $link_type eq 'alternate' and $word{stylesheet};
      } elsif ($effect eq 'external resource') {
        $is_external_resource_link = 1;
      } elsif ($effect eq 'annotation') {
        #
      } else {
        $self->{onerror}->(node => $attr, value => $link_type,
                           type => 'link type:bad context',
                           level => 'm');
      }
    } elsif ($link_type =~ /:/ and $args{extension_by_url}) { # for Web Linking
      ## NOTE: There MUST NOT be any white space [ATOM].
      require Web::URL::Checker;
      my $chk = Web::URL::Checker->new_from_string ($link_type);
      $chk->onerror (sub {
        $self->{onerror}->(@_, node => $attr);
      });
      $chk->check_iri; # XXX URL Standard
    } else {
      if ($effect eq 'hyperlink' or $effect eq '1') {
        $is_hyperlink = 1;
      } elsif ($effect eq 'external resource') {
        $is_external_resource_link = 1;
      }
      $self->{onerror}->(node => $attr, value => $link_type,
                         type => 'link type:non-conforming',
                         level => 'm',
                         preferred => $def->{preferred}); # or undef
    }

    ## Global uniqueness
    if ($link_type eq 'pingback' or $link_type eq 'canonical') {
      unless ($self->{has_link_type}->{$link_type}) {
        $self->{has_link_type}->{$link_type} = 1;
      } else {
        $self->{onerror}->(node => $attr, value => $link_type,
                           type => 'link type:duplicate',
                           level => $link_type eq 'canonical' ? 'w' : 'm');
      }
    }
  } # $link_type

  ## "shortcut icon" has special restriction [HTML]
  if ($word{shortcut} and
      not $attr->value =~ /\A[Ss][Hh][Oo][Rr][Tt][Cc][Uu][Tt]\x20[Ii][Cc][Oo][Nn]\z/) {
    $self->{onerror}->(node => $attr, value => 'shortcut',
                       type => 'link type:bad context',
                       level => 'm');
  }

  ## XXX rel=pingback has special syntax restrictions and requirements
  ## on interaction with X-Pingback: header [PINGBACK]

  # XXXresource rel=canonical linked resource

  $self->{flag}->{node_is_hyperlink}->{refaddr $attr->owner_element} = $attr->owner_element
      if $is_hyperlink;
  return {is_hyperlink => $is_hyperlink,
          is_external_resource_link => $is_external_resource_link,
          link_types => \%word};
} # _link_types

# ---- Scripting ----

sub scripting ($;$) {
  if (@_ > 1) {
    $_[0]->{scripting} = $_[1];
  }
  return $_[0]->{scripting};
} # scripting

$Element->{+HTML_NS}->{script} = {
  %AnyChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $el = $item->{node};

    ## <https://wiki.suikawiki.org/n/script%20block%27s%20type%20string#anchor-143>
    my $type = $item->{node}->get_attribute_ns (undef, 'type');
    my $language = $item->{node}->get_attribute_ns (undef, 'language');
    my $computed_type;
    if (defined $type) {
      if ($type eq '') {
        $computed_type = 'text/javascript';
      } else {
        $computed_type = $type;
        $computed_type =~ s/\A[\x09\x0A\x0C\x0D\x20]+//; # space characters
        $computed_type =~ s/[\x09\x0A\x0C\x0D\x20]+\z//; # space characters
      }
    } elsif (defined $language) {
      if ($language eq '') {
        $computed_type = 'text/javascript';
      } else {
        $computed_type = 'text/' . $language;
      }
    } else {
      $computed_type = 'text/javascript';
    }

    if ($computed_type =~ m{\A[Mm][Oo][Dd][Uu][Ll][Ee]\z}) {
      $element_state->{content_type} = 'module';
      $self->{onerror}->(node => $item->{node}->get_attribute_node_ns (undef, 'type'),
                         value => $type,
                         type => 'script type:bad spaces',
                         level => 'm')
          if $type =~ /[^MODULEmodule]/;
      for my $name (qw(charset defer nomodule integrity)) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
        $self->{onerror}->(node => $attr,
                           # script:ignored charset
                           # script:ignored defer
                           # script:ignored nomodule
                           # script:ignored integrity
                           type => 'script:ignored ' . $name,
                           level => 'm')
            if defined $attr;
      }
    } else {
      require Web::MIME::Type;
      my $mime_type;
      if (defined $type) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, 'type');
        my $onerror = sub { $self->{onerror}->(@_, node => $attr) };
        $mime_type = Web::MIME::Type->parse_web_mime_type
            ($computed_type, $onerror);
        $mime_type->validate ($onerror) if defined $mime_type;
      } elsif ($computed_type eq 'text/javascript') {
        $mime_type = Web::MIME::Type->parse_web_mime_type
            ($computed_type, sub { });
      } else {
        my $attr = $item->{node}->get_attribute_node_ns (undef, 'language');
        my $onerror = sub { $self->{onerror}->(@_, node => $attr) };
        $mime_type = Web::MIME::Type->parse_web_mime_type
            ($computed_type, $onerror);
        $mime_type->validate ($onerror) if defined $mime_type;
      }
      my $type_attr = $item->{node}->get_attribute_node_ns (undef, 'type') ||
                      $item->{node}->get_attribute_node_ns (undef, 'language');
      if (defined $mime_type and
          $mime_type->is_javascript and
          $computed_type =~ m{\A[^\x00-\x20\x3B]+\z}) {
        $element_state->{content_type} = 'classic';
        if (defined $type) {
          if ($type eq '') {
            $self->{onerror}->(node => $type_attr,
                               value => $computed_type,
                               type => 'script type:empty',
                               level => 's'); # obsolete but conforming
          } else {
            $self->{onerror}->(node => $type_attr,
                               value => $computed_type,
                               type => 'script type:classic',
                               level => ($type =~ /[\x00-\x20]/ ? 'm' : 's')); # obsolete but conforming
          }
        }
        my $async_attr = $item->{node}->get_attribute_node_ns (undef, 'async');
        my $defer_attr = $item->{node}->get_attribute_node_ns (undef, 'defer');
        my $src_attr = $item->{node}->get_attribute_node_ns (undef, 'src');
        $self->{onerror}->(node => $defer_attr,
                           type => 'script:ignored defer',
                           level => 'w')
            if defined $defer_attr and defined $async_attr and defined $src_attr;
        my $co_attr = $item->{node}->get_attribute_node_ns (undef, 'crossorigin');
        $self->{onerror}->(node => $co_attr,
                           type => 'script:ignored crossorigin',
                           level => 'w')
            if defined $co_attr and not defined $src_attr;
        if (not defined $src_attr) {
          for my $name (qw(charset async defer integrity)) {
            my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
            $self->{onerror}->(node => $attr,
                               # script:ignored charset
                               # script:ignored async
                               # script:ignored defer
                               # script:ignored integrity
                               type => 'script:ignored ' . $name,
                               level => 'm')
                if defined $attr;
          }
        } else { # <script src>
          my $attr = $item->{node}->get_attribute_node_ns (undef, 'charset');
          if (defined $attr) {
            my $value = $attr->value;
            $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
            if ($value eq 'utf-8') {
              $self->{onerror}->(node => $attr,
                                 type => 'script charset utf-8',
                                 level => 's'); # obsolete but conforming
            } else {
              $self->{onerror}->(node => $attr,
                                 type => 'script charset',
                                 level => 'm');
            }
          }
        }
      } else { # data block
        $element_state->{content_type} = $mime_type; # or undef; data block
        for my $name (qw(async charset crossorigin defer nonce src nomodule integrity)) {
          my $attr = $item->{node}->get_attribute_node_ns (undef, $name);
          $self->{onerror}->(node => $attr,
                             # script:ignored charset
                             # script:ignored async
                             # script:ignored defer
                             # script:ignored integrity
                             # script:ignored crossorigin
                             # script:ignored nonce
                             # script:ignored src
                             # script:ignored nomodule
                             type => 'script:ignored ' . $name,
                             level => 'm')
              if defined $attr;
        }

        if (not defined $mime_type) {
          #
        } elsif ($mime_type->is_javascript) {
          $self->{onerror}->(node => $type_attr,
                             value => $computed_type,
                             type => 'script type:bad params',
                             level => 'w');
        } elsif ($mime_type->is_scripting_lang) {
          $self->{onerror}->(node => $type_attr,
                             value => $computed_type,
                             type => 'script type:scripting lang',
                             level => 'w');
        }
      }
    } # script element type

    if (defined $language) {
      my $attr = $item->{node}->get_attribute_node_ns (undef, 'language');
      if ($language =~ /\A[Jj][Aa][Vv][Aa][Ss][Cc][Rr][Ii][Pp][Tt]\z/) {
        if (not defined $type or
            $type =~ m{\A[Tt][Ee][Xx][Tt]/[Jj][Aa][Vv][Aa][Ss][Cc][Rr][Ii][Pp][Tt]\z}) {
          $self->{onerror}->(node => $attr,
                             type => 'script language',
                             level => 's'); # obsolete but conforming
        } else {
          $self->{onerror}->(node => $attr,
                             type => 'script language:ne type',
                             level => 'm');
        }
      } elsif ($language eq '') {
        $self->{onerror}->(node => $attr,
                           type => 'script type:empty',
                           level => 'm');
      } else {
        $self->{onerror}->(node => $attr,
                           value => $language,
                           type => 'script language:not js',
                           level => 'm');
      }
    }
  }, # check_attrs2
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    ## In theory, a MIME type can define that a |script| element data
    ## block can contain a child element in XML or by scripting.
    ## However, at the time of writing, there is no known MIME type
    ## that allows child elements in data block.
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed',
                       level => 'm');
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my ($text, $tc, $text_sps, $tc_sps)
        = node_to_text_and_tc_and_sps $item->{node};

    ## Common
    my $length = length $tc;
    $tc =~ s{\G(.*?<!--)(.*?)-->}{
      my $pos = length $1;
      if ($2 =~ /<[Ss][Cc][Rr][Ii][Pp][Tt][\x09\x0A\x0C\x0D\x20\x2F>]/) {
        $pos += $-[0];
        my $p = pos_to_lc $tc_sps, $pos;
        $self->{onerror}->(node => $item->{node},
                           %$p,
                           type => 'script:nested <script>',
                           level => 'm');
      }
      '';
    }gse;
    $length -= length $tc;
    if ($tc =~ /<!--/) {
      my $p = pos_to_lc $tc_sps, $length + $-[0];
      $self->{onerror}->(node => $item->{node},
                         %$p,
                         type => 'style:unclosed cdo', # sic
                         level => 'm');
    }

    if ($item->{node}->has_attribute_ns (undef, 'src')) {
      ## Documentation
      unless ($text =~ m{\A(?>(?>[\x20\x09]|/\*(?>[^*]|\*[^/])*\*+/)*(?>//[^\x0A]*)?\x0A)*\z}) {
        ## Non-Unicode character error is detected by other place.
        $self->{onerror}->(node => $item->{node},
                           type => 'script:inline doc:invalid',
                           level => 'm');
      }
    } else {
      if (not defined $element_state->{content_type}) {
        ## Data block with bad type=""
        #
      } elsif (ref $element_state->{content_type}) {
        $self->{onerror}->(node => $item->{node},
                           value => $element_state->{content_type}->as_valid_mime_type,
                           type => 'unknown script lang',
                           level => 'u');
      } else { # classic / module
        # XXX Module validation is not supported yet
        require Web::JS::Checker;
        my $jsc = Web::JS::Checker->new;
        $jsc->impl ('JE');
        $jsc->onerror ($GetNestedOnError->($self->onerror, $item->{node}));
        $jsc->check_char_string ($text);
      }
    }

    $AnyChecker{check_end}->(@_);
  }, # check_end

  ## XXXresource: <script type=""> must match the MIME type of the
  ## referenced resource.  <script type=""> must be specified if the
  ## referenced resource is not JavaScript.  <script charset=""> must
  ## match the charset="" of the referenced resource.
  ## XXX warn if bad nonce=""
}; # script
$ElementAttrChecker->{(HTML_NS)}->{script}->{''}->{type} = sub {};
$ElementAttrChecker->{(HTML_NS)}->{script}->{''}->{language} = sub {};

## Event handler content attribute [HTML]
$CheckerByType->{'event handler'} = sub {
  my ($self, $attr) = @_;
  ## MUST be JavaScript |FunctionBody|.
  require Web::JS::Checker;
  my $jsc = Web::JS::Checker->new;
  $jsc->impl ('JE');
  $jsc->onerror ($GetNestedOnError->($self->onerror, $attr));
  $jsc->check_char_string ($attr->value);
}; # event handler

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

$Element->{+HTML_NS}->{slot} = {
  %TransparentChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;
    my $name = $item->{node}->get_attribute_node_ns (undef, 'name');
    my $value = defined $name ? $name->value : '';
    if ($self->{flag}->{slots}->{$value}) {
      $self->{onerror}->(node => $name || $item->{node},
                         type => 'duplicate slot name',
                         value => $value,
                         level => 'w');
    } else {
      $self->{flag}->{slots}->{$value} = 1;
    }

    unless ($self->{flag}->{XXX_in_shadow_tree}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'light slot',
                         level => 'w');
    }
  }, # check_attrs2
}; # slot

## Autonomous custom elements
$Element->{+HTML_NS}->{'*-*'} = {
  %TransparentChecker,
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    ## Local name MUST be a valid custom element name.
    my $ln = $item->{node}->local_name;
    unless ($ln =~ /\A[a-z]\p{InPCENChar}*\z/ and
            $ln =~ /-/ and
            not $_Defs->{not_custom_element_names}->{$ln}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'not custom element name',
                         value => $ln,
                         level => 'm');
    }

    ## is="" not allowed
    my $attr = $item->{node}->get_attribute_node_ns (undef, 'is');
    $self->{onerror}->(node => $attr,
                       type => 'attribute not allowed',
                       level => 'm') if defined $attr;
  }, # check_attrs2
}; # *-*

# ---- Sections ----

$Element->{+HTML_NS}->{$_}->{check_start} = sub {
  my ($self, $item, $element_state) = @_;
  $self->{flag}->{has_hn} = 1;
  $item->{parent_state}->{has_hn} = 1;
  $HTMLPhrasingContentChecker{check_start}->(@_);
} for qw(h1 h2 h3 h4 h5 h6); # check_start

## TODO: Explicit sectioning is "encouraged".

$Element->{+HTML_NS}->{hgroup} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state, $element_state2) = @_;
    if ($child_nsuri eq HTML_NS and $child_ln =~ /\Ah[1-6]\z/) {
      #
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
$Element->{+HTML_NS}->{menu} =
$Element->{+HTML_NS}->{dir} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($child_nsuri eq HTML_NS and $child_ln eq 'li') {
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
}; # ul ol menu dir

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

  my $allowed = 1;
  {
    my $node = $attr->owner_element;
    last unless defined $node;

    $node = $node->manakai_parent_element;
    last unless defined $node;

    my $ns = $node->namespace_uri;
    last unless defined $ns;

    my $ln = $node->local_name;
    if ($ln eq 'ul' or $ln eq 'menu') {
      $allowed = 0;
    }
  }

  $self->{onerror}->(node => $attr,
                     type => 'non-ol li value',
                     level => 'm')
      unless $allowed;
  
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
    $element_state->{dl_phase} = 'before dt';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } elsif ($element_state->{dl_phase} eq 'in dds') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        #$element_state->{dl_phase} = 'in dds';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $element_state->{dl_phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:div:mixed',
                           level => 'm');
        $element_state->{dl_phase} = 'before second dt';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'in dts') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        #$element_state->{dl_phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $element_state->{dl_phase} = 'in dds';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing:dd',
                           level => 'm');
        $self->{onerror}->(node => $child_el,
                           type => 'dl:div:mixed',
                           level => 'm');
        $element_state->{dl_phase} = 'before second dt';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'before dt') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $element_state->{dl_phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $element_state->{dl_phase} = 'before div';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing:dt',
                           level => 'm');
        $element_state->{dl_phase} = 'in dds';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'before second dt') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $element_state->{dl_phase} = 'in dts';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:div:mixed',
                           level => 'm');
        $element_state->{dl_phase} = 'before second dt';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing:dt',
                           level => 'm');
        $element_state->{dl_phase} = 'in dds';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'before div') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        #$element_state->{dl_phase} = 'before div';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        $element_state->{dl_phase} = 'before div dt';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing:dt',
                           level => 'm');
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        $element_state->{dl_phase} = 'before div dd';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'before div dt') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $self->{onerror}->(node => $child_el,
                           type => 'ps element missing:dd',
                           level => 'm');
        $element_state->{dl_phase} = 'before div';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        #$element_state->{dl_phase} = 'before div dt';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        $element_state->{dl_phase} = 'before div dd';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } elsif ($element_state->{dl_phase} eq 'before div dd') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'div') {
        $element_state->{dl_phase} = 'before div';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        $element_state->{dl_phase} = 'before div dt';
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
        $self->{onerror}->(node => $child_el,
                           type => 'dl:no div',
                           level => 'm');
        #$element_state->{dl_phase} = 'before div dd';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:dl',
                           level => 'm');
      }
    } else {
      die "check_child_element: Bad |dl| phase: $element_state->{dl_phase}";
    }

    if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
      my $name = $child_el->text_content; # XXX inner_text ?
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
                         type => 'character not allowed:dl',
                         level => 'm');
    }
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{dl_phase} eq 'in dts' or
        $element_state->{dl_phase} eq 'before div dt') {
      $self->{onerror}->(node => $item->{node},
                         type => 'dl:last dd missing',
                         level => 'm');
    }

    $AnyChecker{check_end}->(@_);
  },
}; # dl

$Element->{+HTML_NS}->{div} = {
  %HTMLFlowContentChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if (defined $item->{parent_state}->{dl_phase}) { # in dl
      if ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
        #
      } elsif (not defined $element_state->{dl_phase}) { # before dt
        if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
          $element_state->{dl_phase} = 'in dts';
        } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
          $self->{onerror}->(node => $child_el,
                             type => 'ps element missing:dt',
                             level => 'm');
          $element_state->{dl_phase} = 'in dds';
        } else {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:dl',
                             level => 'm');
        }
      } elsif ($element_state->{dl_phase} eq 'in dts') {
        if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
          #$element_state->{dl_phase} = 'in dts';
        } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
          $element_state->{dl_phase} = 'in dds';
        } else {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:dl',
                             level => 'm');
        }
      } elsif ($element_state->{dl_phase} eq 'in dds') {
        if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
          $self->{onerror}->(node => $child_el,
                             type => 'dl:div:second dt',
                             level => 'm');
          $element_state->{dl_phase} = 'in dts';
        } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'dd') {
          #$element_state->{dl_phase} = 'in dds';
        } else {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:dl',
                             level => 'm');
        }
      } else {
        die "Bad |dl_phase|: |$element_state->{dl_phase}|";
      }

      if ($child_nsuri eq HTML_NS and $child_ln eq 'dt') {
        my $name = $child_el->text_content; # XXX inner_text ?
        if (defined $item->{parent_state}->{dl_names}->{$name}) {
          $self->{onerror}->(node => $child_el,
                             type => 'duplicate dl name',
                             level => 's');
        } else {
          $item->{parent_state}->{dl_names}->{$name} = 1;
        }
      }
    } else { # flow content
      if ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
    if ($has_significant and defined $item->{parent_state}->{dl_phase}) {
      $self->{onerror}->(node => $child_node,
                         type => 'character not allowed:dl',
                         level => 'm');
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if (defined $item->{parent_state}->{dl_phase}) {
      if (not defined $element_state->{dl_phase}) {
        $self->{onerror}->(node => $item->{node},
                           type => 'child element missing:dt',
                           level => 'm');
      } elsif ($element_state->{dl_phase} eq 'in dts') {
        $self->{onerror}->(node => $item->{node},
                           type => 'dl:last dd missing',
                           level => 'm');
      }
    } else {
      $self->{onerror}->(node => $item->{node},
                         level => 's',
                         type => 'no significant content')
          unless $element_state->{has_palpable};
      $HTMLFlowContentChecker{check_end}->(@_);
    }
  }, # check_end
}; # div

$ElementAttrChecker->{(HTML_NS)}->{marquee}->{''}->{loop} = sub {
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
}; # <marquee loop>

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
    name => $NameAttrChecker,
    rel => sub {}, ## checked in check_attrs2
  }), # check_attrs
  check_attrs2 => sub {
    my ($self, $item, $element_state) = @_;

    my $rel_attr = $item->{node}->get_attribute_node_ns (undef, 'rel');
    $self->_link_types ($rel_attr, multiple => 1, context => 'html_a') if $rel_attr;

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
        target ping rel hreflang type referrerpolicy
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

    $ShapeCoordsChecker->($self, $item, \%attr, 'missing');
  }, # check_attrs2
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{no_interactive_original}
        = $self->{flag}->{no_interactive};
    $self->{flag}->{no_interactive} = 1;
    $element_state->{in_a_original} = $self->{flag}->{in_a};
    $self->{flag}->{in_a} = 1;
    $TransparentChecker{check_start}->(@_);
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    delete $self->{flag}->{in_a_href}
        unless $element_state->{in_a_href_original};
    delete $self->{flag}->{no_interactive}
        unless $element_state->{no_interactive};
    delete $self->{flag}->{in_a}
        unless $element_state->{in_a_original};

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
# XXX has_paplable checking is somewhat broken
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
    if ($element_state->{phase} eq 'before-rb') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
                $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
                ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
                $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
                ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
          $self->{onerror}->(node => $child_el,
                             type => 'element not allowed:ruby base',
                             level => 'm');
        }
        $element_state->{phase} = 'in-rb';
      }
    } elsif ($element_state->{phase} eq 'after-rp2') {
      if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_ln eq HTML_NS and $child_ln =~ /-/)) {
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

## ---- Edits ----

# XXX "paragraph" vs ins/del

$Element->{+HTML_NS}->{ins} = {
  %TransparentChecker,
}; # ins

$Element->{+HTML_NS}->{del} = {
  %TransparentChecker,
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    # "in_phrasing" don't have to be restored here, because of the
    # "transparent"ness.

    #$TransparentChecker{check_end}->(@_);
  }, # check_end
}; # del

## ---- Embedded content ----

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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'figcaption') {
      push @{$element_state->{figcaptions} ||= []}, $child_el;
    } else { # flow content
      if ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
        $element_state->{in_flow_content} = 1;
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

$Element->{+HTML_NS}->{iframe}->{check_attrs2} = sub {
  my ($self, $item) = @_;
  if ($item->{node}->has_attribute_ns (undef, 'itemprop') and
      not $item->{node}->has_attribute_ns (undef, 'src')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'src',
                       level => 'm');
  }
}; # check_attrs2

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
    if ($word{'allow-top-navigation'} and $word{'allow-top-navigation-by-user-activation'}) {
      $self->{onerror}->(node => $attr,
                         type => 'sandbox duplicate allow-top-navigation',
                         level => 'm');
    }
  }; # <iframe sandbox="">
}

sub image_viewable ($;$) {
  if (@_ > 1) {
    $_[0]->{image_viewable} = $_[1];
  }
  return $_[0]->{image_viewable};
} # image_viewable

$Element->{+HTML_NS}->{picture} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = 'before source';
    $element_state->{in_picture} = 1;
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
      #
    } elsif ($element_state->{phase} eq 'before source') {
      if ($child_nsuri eq HTML_NS and $child_ln eq 'source') {
        #
      } elsif ($child_nsuri eq HTML_NS and $child_ln eq 'img') {
        $element_state->{phase} = 'after img';
      } else {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:picture', # XXXdoc
                           level => 'm');
      }
    } elsif ($element_state->{phase} eq 'after img') {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:picture', # XXXdoc
                         level => 'm');
    } else {
      die "check_child_element: Bad |dl| phase: $element_state->{phase}";
    }

    # XXX <* srcset type> constraints
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
    unless ($element_state->{phase} eq 'after img') {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing',
                         text => 'img',
                         level => 'm');
    }
    $AnyChecker{check_end}->(@_);
  },
}; # picture

# XXX <picture srcset>

# XXX <picture sizes>

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
                         type => 'img:longnameattr',
                         level => 'mh')
          if defined $long_attr;
    } else { # has alt=""
      $self->{onerror}->(node => $long_attr,
                         type => 'img:longnameattr:has alt',
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
                           level => 'w');
      }
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'param') {
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'source') {
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
  if ($item->{parent_state}->{in_picture}) {
    unless ($item->{node}->has_attribute_ns (undef, 'srcset')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'srcset',
                         level => 'm');
    }

    for my $name (qw(src)) {
      my $node = $item->{node}->get_attribute_node_ns (undef, $name);
      $self->{onerror}->(node => $node,
                         type => 'attribute not allowed:media source', # XXXtype
                         level => 'm') if defined $node;
    }
  } else {
    unless ($item->{node}->has_attribute_ns (undef, 'src')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'src',
                         level => 'm');
    }

    for my $name (qw(sizes media srcset)) {
      my $node = $item->{node}->get_attribute_node_ns (undef, $name);
      $self->{onerror}->(node => $node,
                         type => 'attribute not allowed:picture source', # XXXtype
                         level => 'm') if defined $node;
    }
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
      if (length $value) {
        if ($value =~ /[\x09\x0A\x0C\x0D\x20]/) {
          $self->{onerror}->(node => $attr,
                             type => 'space in map name',
                             level => 'm');
        }
        
        if ($self->{map_exact}->{$value}) {
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
    $self->_link_types ($rel_attr, multiple => 1, context => 'html_a') if $rel_attr;

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
      for (qw/target ping rel alt referrerpolicy/) {
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
    if (not $self->{flag}->{in_map} and
        $item->{node}->manakai_parent_element) {
      $self->{onerror}->(node => $item->{node},
                         type => 'element not allowed:area',
                         level => 'm');
    }
  },
}; # area

#XXX
$_Defs->{elements}->{+HTML_NS}->{area}->{attrs}->{''}->{referrerpolicy}->{conforming} = 1;

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
    if ($_Defs->{categories}->{'script-supporting elements'}->{elements}->{$child_nsuri}->{$child_ln}) {
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
        $element_state->{phase} = 'after tfoot';
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
        $element_state->{phase} = 'after tfoot';
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
        $element_state->{phase} = 'after tfoot';
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
    if ($child_nsuri eq HTML_NS and
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'tr') {
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'td') {
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'legend') {
      if ($element_state->{in_flow_content}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      } else {
        $element_state->{in_flow_content} = 1;
      }
    } else { # flow content
      if ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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
                               text => $value_type,
                               level => 'u');
          };
          $checker = $CheckerByType->{'e-mail address'}
              if $input_type eq 'email' and
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
                           text => $value_type,
                           level => 'u');
      };
      $checker = $CheckerByType->{'floating-point number'}
          if $input_type eq 'range';
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
    } elsif ($input_type eq 'image') {
      if (my $attr = $el->get_attribute_node_ns (undef, 'start')) {
        unless ($el->has_attribute_ns (undef, 'dynsrc')) {
          $self->{onerror}->(node => $attr,
                             type => 'attribute not allowed',
                             level => 'm');
        }
      }
    }

    if (defined $element_state->{date_value}->{min} or
        defined $element_state->{date_value}->{max}) {
      my $min_value = $element_state->{date_value}->{min};
      my $max_value = $element_state->{date_value}->{max};
      my $value_value = $element_state->{date_value}->{value};

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

      if (defined $min_value and defined $max_value) {
        if (not $min_value <= $max_value) {
          my $attr = $item->{node}->get_attribute_node_ns (undef, 'max')
              || $item->{node}->get_attribute_node_ns (undef, 'min');
          $self->{onerror}->(node => $attr,
                             value => "$min_value <= $max_value",
                             type => 'max lt min',
                             level => 'm');
        }
      }

      for my $value_value (
        (defined $element_state->{number_value}->{value}
            ? ($element_state->{number_value}->{value}) : ()),
        @{$element_state->{number_values}->{value} or []},
      ) {
        if (defined $min_value and not $min_value <= $value_value) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value lt min',
                             value => "$min_value <= $value_value",
                             level => 'w');
        }
        if (defined $max_value and not $value_value <= $max_value) {
          my $value = $item->{node}->get_attribute_node_ns (undef, 'value');
          $self->{onerror}->(node => $value,
                             type => 'value gt max',
                             value => "$value_value <= $max_value",
                             level => 'w');
        }
      } # $value_value
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
    if ($child_nsuri eq HTML_NS and
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
    if ($element_state->{phase} eq 'phrasing') {
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'option') {
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
      unless ($element_state->{has_palpable}) {
        my $parent = $item->{node}->parent_node;
        if (defined $parent and
            $parent->node_type == 1 and # ELEMENT_NODE
            $parent->manakai_element_type_match (HTML_NS, 'datalist')) {
          $self->{onerror}->(node => $item->{node},
                             type => 'no significant content',
                             level => 'w');
        } else {
          $self->{onerror}->(node => $item->{node},
                             type => 'no significant content',
                             level => 'm');
        }
      }
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
$ElementAttrChecker->{(HTML_NS)}->{textarea}->{''}->{autofocus} = sub {
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
    if ($child_nsuri eq HTML_NS and $child_ln eq 'summary') {
      if ($element_state->{in_flow_content}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:flow',
                           level => 'm');
      }
      $element_state->{in_flow_content} = 1;
      $element_state->{has_summary} = 1;
    } else { # flow content
      if ($_Defs->{categories}->{'flow content'}->{elements}->{$child_nsuri}->{$child_ln} or
          $_Defs->{categories}->{'flow content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln} or
          ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
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

$Element->{+HTML_NS}->{summary} = {
  %HTMLPhrasingContentChecker,
  ## Phrasing content or a heading content element
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($_Defs->{categories}->{'phrasing content'}->{elements}->{$child_nsuri}->{$child_ln} or
        $_Defs->{categories}->{'phrasing content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
      if ($element_state->{has_heading}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:a heading',
                           level => 'm');
      } else {
        $element_state->{has_phrasing} = 1;
      }
    } elsif ($_Defs->{categories}->{'heading content'}->{elements}->{$child_nsuri}->{$child_ln}) {
      if ($element_state->{has_phrasing}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:phrasing',
                           level => 'm');
      } elsif ($element_state->{has_heading}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:a heading',
                           level => 'm');
      } else {
        $element_state->{has_heading} = 1;
      }
    } else {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:phrasing',
                         level => 'm');
    }
  }, # check_child_element
  check_child_text => sub {
    my ($self, $item, $child_node, $has_significant, $element_state) = @_;
    if ($has_significant) {
      if ($element_state->{has_heading}) {
        $self->{onerror}->(node => $child_node,
                           type => 'character not allowed:a heading',
                           level => 'm');
      } else {
        $element_state->{has_phrasing} = 1;
      }
    }
  }, # check_child_text
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    $self->{onerror}->(node => $item->{node},
                       level => 's',
                       type => 'no significant content')
        unless $element_state->{has_palpable};
    $HTMLPhrasingContentChecker{check_end}->(@_);
  }, # check_end
}; # summary

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

    my $tabindex_attr = $item->{node}->get_attribute_node_ns
        (undef, 'tabindex');
    $self->{onerror}->(node => $tabindex_attr,
                       type => 'attribute not allowed:dialog tabindex',
                       level => 'm')
        if defined $tabindex_attr;

    $HTMLFlowContentChecker{check_end}->(@_);
  }, # check_end
}; # dialog

# ------ Frames ------

$Element->{+HTML_NS}->{frameset} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($child_nsuri eq HTML_NS and
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
                     type => 'empty itemprop',
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
                             text => (join ' ', sort { $a cmp $b } grep { $item->{types}->{$_} } keys %{$item->{types} or {}}),
                             value => $prop,
                             level => 'm')
              for map { $_->{node} } @{$item->{props}->{$prop} or []};
        } else {
          $self->{onerror}->(node => $_,
                             type => 'microdata:itemprop not defined',
                             text => (join ' ', sort { $a cmp $b } grep { $item->{types}->{$_} } keys %{$item->{types} or {}}),
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
                                 text => (join ' ', sort { $a cmp $b } grep { $prop_def->{item}->{types}->{$_} } keys %{$prop_def->{item}->{types} or {}}), # expected
                                 value => (join ' ', sort { $a cmp $b } grep { $value->{types}->{$_} } keys %{$value->{types}}), # actual
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
#    vcard telephone number
#    vcard sex
#    vcard geo
#    icalendar recur

## ------ SVG ------

# XXX
$_Defs->{elements}->{(SVG_NS)}->{$_}->{conforming} = 1
    for qw(svg g rect circle foreignObject title desc metadata);

## ------ MathML ------

# XXX
$_Defs->{elements}->{(MML_NS)}->{$_}->{conforming} = 1
    for qw(math mi mo mn mtext annotation-xml);

## ------ RSS1 ------

$Element->{+RDF_NS}->{RDF} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    $element_state->{rss1_data_original} = $self->{flag}->{rss1_data};
    $self->{flag}->{rss1_data} = {};

    ## RSS 1.0 rdf:RDF element
    ## <https://manakai.github.io/spec-dom/validation-langs#rss-1.0-rdf:rdf-element>
    $element_state->{is_rss1_rdf} = do {
      #($item->{node}->namespace_uri || '') eq RDF_NS and
      #$item->{node}->local_name eq 'RDF' and
      (
        (
          defined $item->{node}->parent_node and
          $item->{node}->parent_node->node_type == $item->{node}->DOCUMENT_NODE and
          $item->{node}->parent_node->content_type eq 'application/rss+xml'
        ) or (
          ($item->{node}->prefix || '') eq 'rdf' and
          ($item->{node}->get_attribute_ns (XMLNS_NS, 'xmlns') || '') eq RSS_NS and
          ($item->{node}->get_attribute_ns (XMLNS_NS, 'rdf') || '') eq RDF_NS
        )
      )
    };

    if ($element_state->{is_rss1_rdf}) {
      unless (($item->{node}->prefix || '') eq 'rdf') {
        $self->{onerror}->(node => $item->{node},
                           type => 'rss1:rdf:RDF:bad prefix',
                           value => $item->{node}->prefix,
                           level => 'm');
      }
    } else {
      $element_state->{not_prop_container} = 1;
      $self->{onerror}->(node => $item->{node},
                         type => 'unknown RDF element',
                         level => 'u');
    }
  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if (defined $self->{flag}->{rss1_data}->{image_about} and
        defined $self->{flag}->{rss1_data}->{image_resource}) {
      unless ($self->{flag}->{rss1_data}->{image_about}->value eq
              $self->{flag}->{rss1_data}->{image_resource}->value) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{image_resource},
                           type => 'rss1:bad rdf:resource',
                           text => $self->{flag}->{rss1_data}->{image_about}->value,
                           level => 'm');
      }
    } elsif (defined $self->{flag}->{rss1_data}->{image_about} and
             not defined $self->{flag}->{rss1_data}->{image_resource}) {
      $self->{onerror}->(node => $self->{flag}->{rss1_data}->{image_about},
                         type => 'rss1:no rdf:resource',
                         text => 'image',
                         level => 'm');
    } elsif (not defined $self->{flag}->{rss1_data}->{image_about} and
             defined $self->{flag}->{rss1_data}->{image_resource}) {
      $self->{onerror}->(node => $self->{flag}->{rss1_data}->{image_resource},
                         type => 'rss1:no rdf:about',
                         text => 'image',
                         level => 'm');
    }

    if (defined $self->{flag}->{rss1_data}->{textinput_about} and
        defined $self->{flag}->{rss1_data}->{textinput_resource}) {
      unless ($self->{flag}->{rss1_data}->{textinput_about}->value eq
              $self->{flag}->{rss1_data}->{textinput_resource}->value) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_resource},
                           type => 'rss1:bad rdf:resource',
                           text => $self->{flag}->{rss1_data}->{textinput_about}->value,
                           level => 'm');
      }
    } elsif (defined $self->{flag}->{rss1_data}->{textinput_about} and
             not defined $self->{flag}->{rss1_data}->{textinput_resource}) {
      $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_about},
                         type => 'rss1:no rdf:resource',
                         text => 'textinput',
                         level => 'm');
    } elsif (not defined $self->{flag}->{rss1_data}->{textinput_about} and
             defined $self->{flag}->{rss1_data}->{textinput_resource}) {
      $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_resource},
                         type => 'rss1:no rdf:about',
                         text => 'textinput',
                         level => 'm');
    }
    if (defined $self->{flag}->{rss1_data}->{textinput_about}) {
      my $v = $self->{flag}->{rss1_data}->{textinput_about}->value;
      if ($self->{flag}->{rss1_data}->{item_abouts}->{$v}) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_about},
                           type => 'rss1:duplicate rdf:about',
                           level => 'm');
      } elsif (defined $self->{flag}->{rss1_data}->{image_about} and
               $self->{flag}->{rss1_data}->{image_about}->value eq $v) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_about},
                           type => 'rss1:duplicate rdf:about',
                           level => 'm');
      } elsif (defined $self->{flag}->{rss1_data}->{channel_about} and
               $self->{flag}->{rss1_data}->{channel_about}->value eq $v) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{textinput_about},
                           type => 'rss1:duplicate rdf:about',
                           level => 'm');
      }
    }

    for my $url (keys %{$self->{flag}->{rss1_data}->{item_abouts} or {}}) {
      unless (delete $self->{flag}->{rss1_data}->{item_resources}->{$url}) {
        $self->{onerror}->(node => $self->{flag}->{rss1_data}->{item_abouts}->{$url},
                           type => 'rss1:no rdf:resource',
                           text => 'rdf:li',
                           level => 'm');
      }
    }
    for my $url (keys %{$self->{flag}->{rss1_data}->{item_resources} or {}}) {
      $self->{onerror}->(node => $self->{flag}->{rss1_data}->{item_resources}->{$url},
                         type => 'rss1:no rdf:about',
                         text => 'item',
                         level => 'm');
    }

    $self->{flag}->{rss1_data} = $element_state->{rss1_data_original};

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # rdf:RDF

$Element->{+RSS_NS}->{channel}->{check_start} = sub {
  my ($self, $item, $element_state) = @_;

  $element_state->{is_rss1_channel} = 1;
  $self->{flag}->{rss1_data}->{channel_about}
      = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');

}; # rss:channel check_start

$Element->{+RSS_NS}->{image} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    $element_state->{phase}
        = $item->{parent_state}->{is_rss1_channel} ? 'rdfresourceref' :
          $item->{parent_state}->{is_rss1_rdf} ? 'props' : 'unknown';

  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{phase} eq 'rdfresourceref') {
      my $a1 = $item->{node}->get_attribute_node_ns (RDF_NS, 'resource');
      if (defined $a1) {
        $self->{flag}->{rss1_data}->{image_resource} = $a1;
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'rdf:resource',
                           level => 'm');
      }
      my $attr = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');
      $self->{onerror}->(node => $attr,
                         type => 'attribute not allowed',
                         level => 'm')
          if defined $attr;
    } elsif ($element_state->{phase} eq 'props') {
      my $a1 = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');
      if (defined $a1) {
        $self->{flag}->{rss1_data}->{image_about} = $a1;
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'rdf:about',
                           level => 'm');
      }
      my $attr = $item->{node}->get_attribute_node_ns (RDF_NS, 'resource');
      $self->{onerror}->(node => $attr,
                         type => 'attribute not allowed',
                         level => 'm')
          if defined $attr;
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # rss:image

$Element->{+RSS_NS}->{textinput} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    $element_state->{phase}
        = $item->{parent_state}->{is_rss1_channel} ? 'rdfresourceref' :
          $item->{parent_state}->{is_rss1_rdf} ? 'props' : 'unknown';
    $element_state->{is_rss1_textinput} = 1;

  }, # check_start
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{phase} eq 'rdfresourceref') {
      my $a1 = $item->{node}->get_attribute_node_ns (RDF_NS, 'resource');
      if (defined $a1) {
        $self->{flag}->{rss1_data}->{textinput_resource} = $a1;
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'rdf:resource',
                           level => 'm');
      }
      my $attr = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');
      $self->{onerror}->(node => $attr,
                         type => 'attribute not allowed',
                         level => 'm')
          if defined $attr;
    } elsif ($element_state->{phase} eq 'props') {
      my $a1 = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');
      if (defined $a1) {
        $self->{flag}->{rss1_data}->{textinput_about} = $a1;
      } else {
        $self->{onerror}->(node => $item->{node},
                           type => 'attribute missing',
                           text => 'rdf:about',
                           level => 'm');
      }
      my $attr = $item->{node}->get_attribute_node_ns (RDF_NS, 'resource');
      $self->{onerror}->(node => $attr,
                         type => 'attribute not allowed',
                         level => 'm')
          if defined $attr;
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # rss:textinput

$Element->{+RSS_NS}->{link}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;

  if ($item->{parent_state}->{is_rss1_item} or
      $item->{parent_state}->{is_rss1_textinput}) {
    my $about = $item->{node}->parent_node->get_attribute_ns (RDF_NS, 'about');
    if (defined $about and
        not $about eq $item->{node}->text_content) { # XXX child text content?
      $self->{onerror}->(node => $item->{node},
                         type => 'rss1:item:link ne rdf:about',
                         text => $about,
                         level => 's');
    }
  }

}; # rss:link check_attrs2

$Element->{+RSS_NS}->{item}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  $element_state->{is_rss1_item} = 1;

  my $about = $item->{node}->get_attribute_node_ns (RDF_NS, 'about');
  if (defined $about) {
    if (defined $self->{flag}->{rss1_data}->{item_abouts}->{$about->value}) {
      $self->{onerror}->(node => $about,
                         type => 'rss1:item:duplicate rdf:about',
                         level => 'm');
    } else {
      $self->{flag}->{rss1_data}->{item_abouts}->{$about->value} = $about;
    }
  }

}; # rss:item check_attrs2

$Element->{+RSS_NS}->{items}->{check_start} = sub {
  my ($self, $item, $element_state) = @_;
  $element_state->{is_rss1_items} = 1;
}; # rss:items check_start

$Element->{+RDF_NS}->{Seq} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    if ($item->{parent_state}->{is_rss1_items}) {
      $element_state->{is_rss1_items_seq} = 1;
    } else {
      $element_state->{not_prop_container} = 1;
      $self->{onerror}->(node => $item->{node},
                         type => 'unknown RDF element',
                         level => 'u');
    }
  }, # check_start
}; # rdf:Seq

$Element->{+RDF_NS}->{li} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;

    if ($item->{parent_state}->{is_rss1_items_seq}) {
      my $res = $item->{node}->get_attribute_node_ns (RDF_NS, 'resource');
      if (defined $res) {
        if (defined $self->{flag}->{rss1_data}->{item_resources}->{$res->value}) {
          $self->{onerror}->(node => $res,
                             type => 'rss1:items:duplicate rdf:resource',
                             level => 'w');
        } else {
          $self->{flag}->{rss1_data}->{item_resources}->{$res->value} = $res;
        }
      }
    } else {
      $element_state->{not_prop_container} = 1;
      $self->{onerror}->(node => $item->{node},
                         type => 'unknown RDF element',
                         level => 'u');
    }
  }, # check_start
}; # rdf:li

$Element->{+RSS_NS}->{description} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase}
        = $item->{parent_state}->{is_rss1_item} ? 'html' : 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $CheckDIVContent->($self, $item->{node})
        if $element_state->{phase} eq 'html';

    $AnyChecker{check_end}->(@_);
  },
}; # rss:description

$Element->{+RSS_CONTENT_NS}->{encoded} = {
  %AnyChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $CheckDIVContent->($self, $item->{node});

    $AnyChecker{check_end}->(@_);
  },
}; # content:encoded

$Element->{+DC_NS}->{creator}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  if ($item->{parent_state}->{has_rss2_author}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'element not allowed:rss2 author dc:creator',
                       level => 's');
  }
  $item->{parent_state}->{has_dc_creator} = 1;
};

## ------ RSS2 ------

$RSS2Element->{channel}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  $element_state->{is_rss2_channel} = 1;
};

$RSS2Element->{channel}->{check_end} = sub {
  my ($self, $item, $element_state) = @_;
  
  my $cd = $element_state->{rss2_channel_data};
  if (defined $cd->{channel_link} and
      defined $cd->{image_link}) {
    unless ($cd->{channel_link}->text_content eq $cd->{image_link}->text_content) {
      # XXX child text content
      $self->{onerror}->(node => $cd->{image_link},
                         type => 'rss2:image != channel',
                         level => 's');
    }
  }
  if (defined $cd->{channel_title} and
      defined $cd->{image_title}) {
    unless ($cd->{channel_title}->text_content eq $cd->{image_title}->text_content) {
      # XXX child text content
      $self->{onerror}->(node => $cd->{image_title},
                         type => 'rss2:image != channel',
                         level => 's');
    }
  }
  
  $PropContainerChecker{check_end}->(@_);
};

$RSS2Element->{item}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  $element_state->{is_rss2_item} = 1;
};

$RSS2Element->{item}->{check_end} = sub {
  my ($self, $item, $element_state) = @_;

  unless ($element_state->{has_rss2_title} or
          $element_state->{has_rss2_description}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'child element missing:rss2:title|description',
                       level => 'm');
  }

  $PropContainerChecker{check_end}->(@_);
};

$RSS2Element->{image}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  $element_state->{is_rss2_image} = 1;
  $element_state->{rss2_channel_data} = $item->{parent_state}->{rss2_channel_data} ||= {};
};

$RSS2Element->{link}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  if ($item->{parent_state}->{is_rss2_channel}) {
    $item->{parent_state}->{rss2_channel_data}->{channel_link} = $item->{node};
  } elsif ($item->{parent_state}->{is_rss2_image}) {
    $item->{parent_state}->{rss2_channel_data}->{image_link} = $item->{node};
  }
};

$RSS2Element->{title}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  if ($item->{parent_state}->{is_rss2_channel}) {
    $item->{parent_state}->{rss2_channel_data}->{channel_title} = $item->{node};
  } elsif ($item->{parent_state}->{is_rss2_image}) {
    $item->{parent_state}->{rss2_channel_data}->{image_title} = $item->{node};
  }
  $item->{parent_state}->{has_rss2_description} = 1;
};

$RSS2Element->{author}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  if ($item->{parent_state}->{has_dc_creator}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'element not allowed:rss2 author dc:creator',
                       level => 's');
  }
  $item->{parent_state}->{has_rss2_author} = 1;
};

$RSS2Element->{description} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase}
        = $item->{parent_state}->{is_rss2_item} ? 'html' : 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $CheckDIVContent->($self, $item->{node})
        if $element_state->{phase} eq 'html';
    $item->{parent_state}->{has_rss2_description} = 1;

    $AnyChecker{check_end}->(@_);
  },
}; # rss2:description

$RSS2Element->{day}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  my $v = $item->{node}->text_content; # XXX child text content
  if ($item->{parent_state}->{rss2_skip_data}->{$v}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'duplicate token', value => $v,
                       level => 'm');
  } else {
    $item->{parent_state}->{rss2_skip_data}->{$v} = 1;
  }
};

$RSS2Element->{hour}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;
  my $v = $item->{node}->text_content; # XXX child text content
  if ($item->{parent_state}->{rss2_skip_data}->{$v}) {
    $self->{onerror}->(node => $item->{node},
                       type => 'duplicate token', value => $v,
                       level => 'm');
  } else {
    $item->{parent_state}->{rss2_skip_data}->{$v} = 1;
  }
};

$RSS2Element->{guid} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase} = ($item->{node}->get_attribute_ns (undef, 'isPermaLink') || '') eq 'true' ? 'url' : 'any';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    # XXX child text content
    $ItemValueChecker->{URL}->($self, $item->{node}->text_content, $item->{node})
        if $element_state->{phase} eq 'url';

    $AnyChecker{check_end}->(@_);
  },
}; # rss2:guid

$Element->{+MRSS1_NS}->{title} =
$Element->{+MRSS2_NS}->{title} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase}
        = (($item->{node}->get_attribute_ns (undef, 'type') || '') eq 'html')
            ? 'html' : 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $CheckDIVContent->($self, $item->{node})
        if $element_state->{phase} eq 'html';

    $AnyChecker{check_end}->(@_);
  },
}; # media:title

$Element->{+MRSS1_NS}->{description} =
$Element->{+MRSS2_NS}->{description} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{phase}
        = (($item->{node}->get_attribute_ns (undef, 'type') || '') eq 'html')
            ? 'html' : 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    $self->{onerror}->(node => $child_el,
                       type => 'element not allowed:text',
                       level => 'm');
  },
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    $CheckDIVContent->($self, $item->{node})
        if $element_state->{phase} eq 'html';

    $AnyChecker{check_end}->(@_);
  },
}; # media:description

## ------ Atom ------

$Element->{+ATOM_NS}->{entry} = {
  %PropContainerChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($child_nsuri eq ATOM_NS) {
      if ($child_ln eq 'link') {
        if ($child_el->rel eq LINK_REL . 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = $child_el->get_attribute_ns (undef, 'hreflang');
          $hreflang = '' unless defined $hreflang;
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_link}->{$key}) {
            $element_state->{has_link}->{$key} = 1;
            $element_state->{has_link}->{'link.alternate'} = 1;
          } else {
            $self->{onerror}->(node => $child_el,
                               type => 'element not allowed:atom|link rel=alternate',
                               level => 'm');
          }
        }
      } elsif ($child_ln eq 'author') {
        $element_state->{has_author} = 1; # ./author | ./source/author
      }
    }

    $PropContainerChecker{check_child_element}->(@_);
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($element_state->{has_author}) {
      ## NOTE: There is either a child atom:author element
      ## or a child atom:source element which contains an atom:author
      ## child element.
      #
    } else {
      A: {
        # XXX
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

    unless ($element_state->{has_element}->{(ATOM_NS)}->{author}) {
      $item->{parent_state}->{has_no_author_entry} = 1; # for atom:feed's check
    }

    ## TODO: If entry's with same id, then updated SHOULD be different

    if (not $element_state->{has_element}->{(ATOM_NS)}->{content} and
        not $element_state->{has_link}->{'link.alternate'}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom:link:alternate',
                         level => 'm');
    }

    if ($element_state->{require_summary} and
        not $element_state->{has_element}->{(ATOM_NS)}->{summary}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'summary',
                         level => 'm');
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # <atom:entry>

# XXX atom:entry in Collection Document SHOULD have app:edited

$Element->{(ATOM03_NS)}->{entry} = {
  %PropContainerChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($child_nsuri eq ATOM03_NS) {
      if ($child_ln eq 'link') {
        my $rel = $child_el->get_attribute_ns (undef, 'rel');
        if ($rel eq 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = '';
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_link}->{$key}) {
            $element_state->{has_link}->{$key} = 1;
          } else {
            $self->{onerror}->(node => $child_el,
                               type => 'element not allowed:atom|link rel=alternate',
                               level => 'm');
          }
          $element_state->{has_link}->{'link.alternate'} = 1;
        } elsif ($rel eq 'self') {
          $element_state->{has_link}->{'link.self'} = 1;
        }
      }
    }

    $PropContainerChecker{check_child_element}->(@_);
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    unless ($element_state->{has_element}->{(ATOM03_NS)}->{author}) {
      $item->{parent_state}->{has_no_author_entry} = 1; # for atom:feed's check
    }

    if (not $item->{parent_state}->{is_atom_feed} and
        not $element_state->{has_element}->{(ATOM03_NS)}->{author}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'author',
                         level => 'm');
      ## Note that if there is no |atom:entry| element, |atom:author|
      ## element is not required.
    }

    unless ($element_state->{has_link}->{'link.alternate'}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom:link:alternate',
                         level => 'm');
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # <atom03:entry>

$Element->{(ATOM_NS)}->{source} = {
  %PropContainerChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($child_nsuri eq ATOM_NS) {
      if ($child_ln eq 'link') {
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
            $self->{onerror}->(node => $child_el,
                               type => 'element not allowed:atom|link rel=alternate',
                               level => 'm');
          }
        }
      } elsif ($child_ln eq 'author') {
        $item->{parent_state}->{has_author} = 1; # parent::atom:entry's flag
      }
    }
    $PropContainerChecker{check_child_element}->(@_);
  }, # check_child_element
}; # <atom:source>

$Element->{+ATOM_NS}->{feed} = {
  %PropContainerChecker,
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    ## metadata elements, followed by atom:entry*

    if (not $element_state->{has_non_entry_after_entry} and
        $element_state->{has_element}->{(ATOM_NS)}->{entry} and
        not ($child_nsuri eq ATOM_NS and $child_ln eq 'entry')) {
      $self->{onerror}->(node => $child_el,
                         type => 'element after entry',
                         level => 'm');
      $element_state->{has_non_entry_after_entry} = 1;
    }

    if ($child_nsuri eq ATOM_NS) {
      if ($child_ln eq 'link') {
        my $rel = $child_el->rel;
        if ($rel eq LINK_REL . 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = $child_el->get_attribute_ns (undef, 'hreflang');
          $hreflang = '' unless defined $hreflang;
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_link}->{$key}) {
            $element_state->{has_link}->{$key} = 1;
          } else {
            $self->{onerror}->(node => $child_el,
                               type => 'element not allowed:atom|link rel=alternate',
                               level => 'm');
          }
        } elsif ($rel eq LINK_REL . 'self') {
          $element_state->{has_link}->{'link.self'} = 1;
        }
      }
    }

    # XXX no duplicate <at:deleted-entry ref when> (MUST)
    # XXX warn duplicate <entry><id> (MAY, semantics not defined)
    # XXX warn if <entry><id> vs <at:deleted-entry ref> (MAY, older ignored)

    $PropContainerChecker{check_child_element}->(@_);
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    if ($element_state->{has_no_author_entry} and
        not $element_state->{has_element}->{(ATOM_NS)}->{author}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'author',
                         level => 'm');
      ## Note that if there is no |atom:entry| element, |atom:author|
      ## element is not required.
    }

    ## TODO: If entry's with same id, then updated SHOULD be different

    unless ($element_state->{has_link}->{'link.self'}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom:link:self',
                         level => 's');
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # <atom:feed>

$Element->{(ATOM03_NS)}->{feed} = {
  %PropContainerChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{is_atom_feed} = 1; # for atom:entry checker
  }, # check_start
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;

    if ($child_nsuri eq ATOM03_NS) {
      if ($child_ln eq 'link') {
        my $rel = $child_el->get_attribute_ns (undef, 'rel');
        if ($rel eq 'alternate') {
          my $type = $child_el->get_attribute_ns (undef, 'type');
          $type = '' unless defined $type;
          my $hreflang = '';
          my $key = 'link:'.(defined $type ? ':'.$type : '').':'.
              (defined $hreflang ? ':'.$hreflang : '');
          unless ($element_state->{has_link}->{$key}) {
            $element_state->{has_link}->{$key} = 1;
          } else {
            $self->{onerror}->(node => $child_el,
                               type => 'element not allowed:atom|link rel=alternate',
                               level => 'm');
          }
          $element_state->{has_link}->{'link.alternate'} = 1;
        } elsif ($rel eq 'self') {
          $element_state->{has_link}->{'link.self'} = 1;
        }
      }
    }

    $PropContainerChecker{check_child_element}->(@_);
  }, # check_child_element
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    unless ($item->{node}->has_attribute_ns (XML_NS, 'lang')) {
      $self->{onerror}->(node => $item->{node},
                         type => 'attribute missing',
                         text => 'xml:lang',
                         level => 's');
    }

    if ($element_state->{has_no_author_entry} and
        not $element_state->{has_element}->{(ATOM03_NS)}->{author}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom',
                         text => 'author',
                         level => 'm');
      ## Note that if there is no |atom:entry| element, |atom:author|
      ## element is not required.
    }

    unless ($element_state->{has_link}->{'link.alternate'}) {
      $self->{onerror}->(node => $item->{node},
                         type => 'child element missing:atom:link:alternate',
                         level => 'm');
    }

    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # <atom03:feed>

$ElementAttrChecker->{(ATOM_NS)}->{content}->{''}->{src} = sub {
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
}; # <atom:content src="">

$ElementAttrChecker->{(ATOM_NS)}->{content}->{''}->{type} = sub {
  my ($self, $attr, $item, $element_state) = @_;

  $element_state->{has_type} = 1;

  my $value = $attr->value;
  if ($value eq 'text' or $value eq 'html' or $value eq 'xhtml') {
    # MUST
  } else {
    my $type = $MIMETypeChecker->(@_);
    if ($type) {
      if ($type->is_composite_type) {
        $self->{onerror}->(node => $attr,
                           type => 'IMT:composite',
                           value => $type->as_valid_mime_type_with_no_params,
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
}; # <atom:content type="">

$Element->{+ATOM_NS}->{content} = {
  %AnyChecker,
  check_start => sub {
    my ($self, $item, $element_state) = @_;
    $element_state->{type} = 'text';
  },
  check_child_element => sub {
    my ($self, $item, $child_el, $child_nsuri, $child_ln,
        $child_is_transparent, $element_state) = @_;
    if ($element_state->{type} eq 'text' or
        $element_state->{type} eq 'html' or
        $element_state->{type} eq 'mime_text') {
      $self->{onerror}->(node => $child_el,
                         type => 'element not allowed:atom|TextConstruct',
                         level => 'm');
    } elsif ($element_state->{type} eq 'xhtml') {
      if ($element_state->{has_div}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:atom|TextConstruct',
                           level => 'm');
      } else {
        $element_state->{has_div} = 1;
      }
    } elsif ($element_state->{type} eq 'xml') {
      ## MAY contain elements
      if ($element_state->{has_src}) {
        $self->{onerror}->(node => $child_el,
                           type => 'element not allowed:empty',
                           level => 'm');
      }
    } else {
      ## NOTE: Elements are not explicitly disallowed.
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
                           type => 'character not allowed:atom|TextConstruct',
                           level => 'm');
      }
    }

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
               type => 'not IMT',
               level => 'm');
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
      $CheckDIVContent->($self, $item->{node});
    } elsif ($element_state->{type} eq 'xml') {
      ## NOTE: SHOULD be suitable for handling as $value.
      ## If no @src, this would normally mean it contains a 
      ## single child element that would serve as the root element.
      $self->{onerror}->(node => $item->{node},
                         type => 'atom|content not supported', # XXX
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
                         type => 'atom|content not supported', # XXX
                         text => $item->{node}->get_attribute_ns
                             (undef, 'type'),
                         level => 'u');
    }

    $AnyChecker{check_end}->(@_);
  },
}; # atom:content

# XXX Atom 0.3 Content construct content validation

## XXXresource: |atom:icon|'s image SHOULD be 1:1 and SHOULD be small.

## XXX |atom:id| URL SHOULD be normalized.

$ElementAttrChecker->{(ATOM_NS)}->{link}->{''}->{rel} = sub {
  my ($self, $attr) = @_;
  $self->_link_types ($attr, extension_by_url => 1, context => 'atom',
                      case_sensitive => 1);

  ## XXX: rel=license [RFC 4946]
  ## MUST NOT multiple rel=license with same href="",type="" pairs
  ## href="" SHOULD be dereferencable
  ## title="" SHOULD be there if multiple rel=license
  ## MUST NOT "unspecified" and other rel=license
}; # <atom:link rel="">

$ElementAttrChecker->{(ATOM03_NS)}->{link}->{''}->{rel} = sub {
  my ($self, $attr) = @_;
  $self->_link_types ($attr, context => 'atom03', case_sensitive => 1);
}; # <atom03:link rel="">

$Element->{(ATOM_NS)}->{link}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;

  if ($item->{node}->rel eq LINK_REL . 'enclosure' and
      not $item->{node}->has_attribute_ns (undef, 'length')) {
    $self->{onerror}->(node => $item->{node},
                       type => 'attribute missing',
                       text => 'length',
                       level => 's');
  }
}; # <atom:link> check_attrs2

# XXXresource dimension of |atom:logo|'s image SHOULD be 2:1.

## TODO: <thr:in-reply-to href=""> MUST be dereferencable.
## TODO: <thr:in-reply-to source=""> MUST be dereferencable.
# XXX <thr:in-reply-to ref="">, <at:deleted-entry ref=""> - same rule as |atom:id|
# XXX <atom03:generator url=""> SHOULD be dereferencable.

$Element->{(THR_NS)}->{total} = {%HTMLTextChecker};
$ElementTextCheckerByName->{(THR_NS)}->{total} = sub {
  ## NOTE: xsd:nonNegativeInteger
  my ($self, $value, $onerror) = @_;
  $onerror->(type => 'xs:nonNegativeInteger:bad value', level => 'm')
      unless $value =~ /\A(?>[0-9]+|[+][0-9]+|[+-]0+)\z/;
}; # <thr:total> text

$Element->{(APP_NS)}->{categories} = {
  %PropContainerChecker,
  check_end => sub {
    my ($self, $item, $element_state) = @_;
    if ($item->{node}->has_attribute_ns (undef, 'href')) {
      for (qw(fixed scheme)) {
        my $attr = $item->{node}->get_attribute_node_ns (undef, $_);
        $self->{onerror}->(node => $attr,
                           type => 'attribute not allowed',
                           level => 'm')
            if defined $attr;
      }
      if ($element_state->{has_element}->{(ATOM_NS)}->{category}) {
        $self->{onerror}->(node => $_,
                           type => 'element not allowed:empty',
                           level => 'm')
            for grep { $_->manakai_element_type_match (ATOM_NS, 'category') }
                $item->{node}->children->to_list;
      }
    }
    $PropContainerChecker{check_end}->(@_);
  }, # check_end
}; # <app:categories>

#$Element->{(THR_NS)}->{total} = {%HTMLTextChecker};
#$ElementTextCheckerByName->{(APP_NS)}->{accept} = sub {
  # XXX
#}; # <app:accept> text

## ------ XSLT1 ------

# XXX attribute validation with AVT
# XXX extension elements
# XXX stylesheet/transform content
# XXX template content
# XXX for-each content
# XXX choose content
# XXX template/@mode MUST NOT if no template/@match
# XXX warn xml:lang and xml:space on XSLT elements

$NamespacedAttrChecker->{+XSLT_NS}->{version} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  my $value = $attr->value;
  unless ($value eq '1.0') {
    $self->{onerror}->(node => $attr,
                       type => 'enumerated:invalid',
                       level => 'm');
  }
  $self->{onerror}->(node => $attr,
                     type => 'attribute not allowed',
                     level => 'm')
      unless $item->{is_root_literal_result};
}; # xsl:version

$NamespacedAttrChecker->{+XSLT_NS}->{'extension-element-prefixes'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  # XXX 
  $self->{onerror}->(node => $attr,
                     type => 'unknown attribute',
                     level => 'u');
}; # xsl:extension-element-prefixes

$NamespacedAttrChecker->{+XSLT_NS}->{'exclude-result-prefixes'} = sub {
  my ($self, $attr, $item, $element_state) = @_;
  # XXX 
  $self->{onerror}->(node => $attr,
                     type => 'unknown attribute',
                     level => 'u');
}; # xsl:exclude-result-prefixes

$Element->{+XSLT_NS}->{output}->{check_attrs2} = sub {
  my ($self, $item, $element_state) = @_;

  my $attr = $item->{node}->get_attribute_node_ns (undef, 'version');
  $self->{onerror}->(node => $attr,
                     type => 'attribute not allowed',
                     level => 's')
      if defined $attr;
}; # <xsl:output> check_attrs2

## ------ PIs ------

sub _check_pi ($$$) {
  my ($self, $node, $parent_state) = @_;

  ## [VALLANGS]
  my $target = $node->target;
  if ($target eq 'xml-stylesheet') {
    # XXX 
    $self->{onerror}->(node => $node,
                       type => 'unknown pi',
                       level => 'u');
  } elsif ($target =~ /^[Xx][Mm][Ll]-/) {
    $self->{onerror}->(node => $node,
                       type => 'pi not defined',
                       level => 'm');
  } elsif ($target =~ /\A[Xx][Mm][Ll]\z/) {
    # XXX warn (unserializable)
  } else {
    $self->{onerror}->(node => $node,
                       type => 'unknown pi',
                       level => 'u');
  }

  # XXX not serializable if HTML document
  ## XXX warning PI.target == xml
  ## XXX warning PI.data =~ /\?>/ or =~ /^<S>/

} # _check_pi

## ------ Nested document ------

sub _check_fallback_html ($$$$) {
  my ($self, $context, $disallowed, $container_ln) = @_;
  my $container = $context->owner_document->create_element_ns
      (HTML_NS, $container_ln);

  my $onerror = $GetNestedOnError->($self->onerror, $context);

  require Web::DOM::Document;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);

  require Web::HTML::Parser;
  my $parser = Web::HTML::Parser->new;
  my $dids = $self->di_data_set;
  my $is = $context->manakai_get_indexed_string;
  $dids->[@$dids]->{map} = indexed_string_to_mapping $is;
  $parser->di_data_set ($dids);
  $parser->di ($#$dids);
  $parser->onerror ($onerror);
  $parser->scripting ($self->scripting);
  my $children = $parser->parse_char_string_with_context
      ((join '', map { $_->[0] } @$is), $container => $doc);
  
  my $checker = Web::HTML::Validator->new;
  $checker->_init;
  $checker->di_data_set ($dids);
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
         is_noscript => $container_ln eq 'head'}]);

  $checker->_validate_microdata;
  $checker->_validate_aria ($children);
  $checker->_check_refs;
  $checker->_terminate;
} # _check_fallback_html

$ElementAttrChecker->{(HTML_NS)}->{iframe}->{''}->{srcdoc} = sub {
  my ($self, $attr) = @_;
  require Web::DOM::Document;
  require Web::HTML::Parser;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_srcdoc (1);
  $doc->manakai_is_html (1);
  my $parser = Web::HTML::Parser->new;
  $parser->scripting ($self->scripting);
  my $onerror = $GetNestedOnError->($self->onerror, $attr);
  $parser->onerror ($onerror);
  my $dids = $self->di_data_set;
  $parser->di_data_set ($dids);
  my $is = $attr->manakai_get_indexed_string;
  $dids->[@$dids]->{map} = indexed_string_to_mapping $is;
  $parser->di ($#$dids);
  $parser->parse_char_string ((join '', map { $_->[0] } @$is) => $doc);
  
  my $checker = Web::HTML::Validator->new;
  $checker->onerror ($onerror);
  $checker->di_data_set ($dids);
  $checker->scripting ($self->scripting);
  $checker->check_node ($doc);
}; # <iframe srcdoc="">

## For HTML fragment content [VALLANGS]
$CheckDIVContent = sub {
  my ($self, $node) = @_;
  require Web::DOM::Document;
  my $doc = new Web::DOM::Document;
  my $div = $doc->create_element_ns (HTML_NS, 'div');

  require Web::HTML::Parser;
  my $parser = Web::HTML::Parser->new;
  $parser->scripting ($self->scripting);

  my $onerror = $GetNestedOnError->($self->onerror, $node);
  $parser->onerror ($onerror);
  my $dids = $self->di_data_set;
  $parser->di_data_set ($dids);

  my $is = [];
  for ($node->child_nodes->to_list) {
    if ($_->node_type == 3) { # TEXT_NODE
      push @$is, @{$_->manakai_get_indexed_string};
    }
  }
  $dids->[@$dids]->{map} = indexed_string_to_mapping $is;
  $parser->di ($#$dids);
  my $nodes = $parser->parse_char_string_with_context
      ((join '', map { $_->[0] } @$is), $div => $doc);
  $div->append_child ($_) for $nodes->to_list;

  require Web::HTML::Validator;
  my $checker = Web::HTML::Validator->new;
  $checker->scripting ($self->scripting);
  $checker->onerror ($onerror);
  $checker->di_data_set ($dids);
  $checker->check_node ($div);

  # XXX RSS2BP: SHOULD NOT have relative URL
}; # $CheckDIVContent

# XXX unserializable waring for any children
$Element->{+HTML_NS}->{template} = {
  %HTMLEmptyChecker,
  check_end => sub {
    my ($self, $item, $element_state) = @_;

    my $df = $item->{node}->content;
    my @children = @{$df->child_nodes};

    my $checker = Web::HTML::Validator->new;
    $checker->_init;
    $checker->di_data_set ($self->di_data_set);
    $checker->scripting ($self->scripting);
    $checker->onerror ($self->onerror);
    $checker->{flag}->{is_template} = 1
        unless $self->{flag}->{is_xslt_stylesheet};

    $checker->_check_node ([{type => 'document_fragment', node => $df}]);

    $checker->_check_refs;
    $checker->_validate_microdata;
    $checker->_validate_aria (\@children);
    $checker->_terminate;

    $HTMLEmptyChecker{check_end}->(@_);
  }, # check_end
}; # template

## ------ CSS ------

sub _css_parser ($$$;$) {
  my ($self, $node, $value, $sps) = @_;
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
} # _css_parser

## CSS styling attribute [HTML] [CSSSTYLEATTR]
$CheckerByType->{'CSS styling'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  my $parser = $self->_css_parser ($attr, $value);
  my $props = $parser->parse_char_string_as_prop_decls ($value);
  # XXX Web::CSS::Checker->new->check_props ($props);
}; # CSS styling

## Media query list [MQ]
$CheckerByType->{'media query list'} = sub {
  my ($self, $attr) = @_;
  my $value = $attr->value;
  my $parser = $self->_css_parser ($attr, $value);
  my $mqs = $parser->parse_char_string_as_mq_list ($value);

  require Web::CSS::MediaQueries::Checker;
  my $checker = Web::CSS::MediaQueries::Checker->new;
  $checker->onerror ($parser->onerror);
  $checker->check_mq_list ($mqs);
}; # media query list

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

    unless ($doc->input_encoding eq 'UTF-8') {
      $self->{onerror}->(node => $doc,
                         type => 'non-utf-8 character encoding',
                         value => $doc->input_encoding,
                         level => 'm');
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
      ##   is_root_literal_result Is XSLT literal result element root (boolean)
      ##   disallowed      Disallowed descendant list (optional)
      ##   parent_state    State hashref for the parent of the element node
      my $el = $item->{node};
      my $el_nsuri = $el->namespace_uri;
      $el_nsuri = '' if not defined $el_nsuri;
      my $el_ln = $el->local_name;
      
      my $element_state = {};

      my $Dns = ($el_nsuri eq '' and $self->{is_rss2})
          ? $RSS2Element : $Element->{$el_nsuri};
      my $Ens = ($el_nsuri eq '' and $self->{is_rss2})
          ? $_Defs->{rss2_elements} : $_Defs->{elements}->{$el_nsuri};
      my $e_eldef = $Dns->{$el_ln};
      my $el_def_data = $Ens->{$el_ln};
      if ($el_ln =~ /-/) {
        $e_eldef ||= $Dns->{'*-*'};
        $el_def_data ||= $Ens->{'*-*'};
      }
      my $eldef = $e_eldef || $Element->{$el_nsuri}->{''} || $ElementDefault;
      $el_def_data ||= {};
      $item->{def_data} = $el_def_data;

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

      if ($el_def_data->{conforming}) {
        unless (defined $e_eldef) {
          ## Though the element is conforming, we does not support the
          ## validation of the element yet.
          $self->{onerror}->(node => $el,
                             type => 'unknown element',
                             level => 'u');
        } elsif ($el_def_data->{limited_use} or
                 $_Defs->{namespaces}->{$el_nsuri}->{limited_use}) {
          $self->{onerror}->(node => $el,
                             type => 'limited use',
                             level => 'w');
        }
      } elsif ($_Defs->{namespaces}->{$el_nsuri}->{supported} or
               $_Defs->{namespaces}->{$el_nsuri}->{obsolete} or
               ($el_nsuri eq '' and $self->{is_rss2})) {
        ## "Authors must not use elements, attributes, or attribute
        ## values that are not permitted by this specification or
        ## other applicable specifications" [HTML]
        if ($el_def_data->{preferred}) {
          $self->{onerror}->(node => $el,
                             type => 'element:obsolete',
                             level => 'm',
                             preferred => $el_def_data->{preferred});
        } else {
          $self->{onerror}->(node => $el,
                             type => 'element not defined',
                             level => 'm');
        }
      } else {
        $self->{onerror}->(node => $el,
                           type => 'unknown namespace element',
                           value => $el_nsuri,
                           level => 'u');
      }

      for my $ans (keys %{$el_def_data->{attrs}}) {
        for my $aln (keys %{$el_def_data->{attrs}->{$ans}}) {
          if ($el_def_data->{attrs}->{$ans}->{$aln}->{required}) {
            $self->{onerror}->(node => $item->{node},
                               type => 'attribute missing',
                               text => $aln,
                               level => 'm')
                unless $item->{node}->has_attribute_ns ($ans, $aln);
          }
        }
      }

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

          my $child_is_hidden = ($child_nsuri eq HTML_NS and
                                 $child->has_attribute_ns (undef, 'hidden'));

          if ($element_state->{has_palpable}) {
            #
          } elsif ($_Defs->{categories}->{'palpable content'}->{elements}->{$child_nsuri}->{$child_ln} or
                   ($child_nsuri eq HTML_NS and $child_ln =~ /-/)) {
            $element_state->{has_palpable} = 1 unless $child_is_hidden;
          } elsif ($_Defs->{categories}->{'palpable content'}->{elements_with_exceptions}->{$child_nsuri}->{$child_ln}) {
            $element_state->{has_palpable} = 1
                if not $child_is_hidden and
                   $IsPalpableContent->{$child_nsuri}->{$child_ln}->($child);
          }

          push @new_item, {type => 'check_child_element',
                           code => $eldef->{check_child_element},
                           args => [$self, $item, $child,
                                    $child_nsuri, $child_ln,
                                    0,
                                    $element_state, $element_state]};

          my $old_it;
          push @new_item,
              [sub {
                 $old_it = $self->{flag}->{is_template};
                 $self->{flag}->{is_template} = 1;
               }]
                  if $child_is_hidden;

          push @new_item, {type => 'element', node => $child,
                           parent_state => $element_state};

          push @new_item, [sub { $self->{flag}->{is_template} = $old_it }]
              if $child_is_hidden;
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
          $self->_check_pi ($child, $element_state);
        } # $child_nt
      } # $child
      
      push @new_item, [$eldef->{check_end}, $self, $item, $element_state];
      push @new_item, {type => '_remove_minus_elements',
                       element_state => $element_state}
          if $disallowed;
      my $cm = $el_def_data->{content_model} || '';
      push @new_item, {type => 'check_palpable_content',
                       node => $el,
                       element_state => $element_state}
          if ($cm eq 'flow content' or
              $cm eq 'phrasing content' or
              $cm eq 'transparent');
      
      unshift @item, @new_item;
    } elsif ($item->{type} eq '_add_minus_elements') {
      $self->_add_minus_elements ($item->{element_state}, $item->{disallowed});
    } elsif ($item->{type} eq '_remove_minus_elements') {
      $self->_remove_minus_elements ($item->{element_state});
    } elsif ($item->{type} eq 'check_child_element') {
      my $args = $item->{args};
      if (($self->{minus_elements}->{$args->[3]}->{$args->[4]} and
           $self->_is_minus_element ($args->[2], $args->[3], $args->[4])) or
          ($self->{flag}->{no_interactive} and
           $args->[3] eq HTML_NS and
           $args->[2]->has_attribute_ns (undef, 'tabindex'))) {
        $self->{onerror}->(node => $args->[2],
                           type => 'element not allowed:minus',
                           level => 'm');
      } else {
        $item->{code}->(@$args);
      }
    } elsif ($item->{type} eq 'check_html_attrs') {
      for my $attr (@{$item->{node}->attributes}) {
        next if defined $attr->namespace_uri;
        $self->_check_attr_bidi ($attr);
      }

      unless ($item->{node}->has_attribute_ns (undef, 'title')) {
        if ($item->{element_state}->{require_title} or
            $item->{node}->has_attribute_ns (undef, 'draggable')) {
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
          my $is_root_literal_result;
          if ($has_element) {
            $self->{onerror}->(node => $node,
                               type => 'duplicate document element',
                               level => 'm'); # [MANAKAI] [DOM]
          } else {
            $has_element = 1;

            my $mime = $item->{node}->content_type;
            my $nsurl = $node->namespace_uri;
            $nsurl = '' if not defined $nsurl;
            my $ln = $node->local_name;

            ## XSLT stylesheet [VALLANGS]
            if (($nsurl eq XSLT_NS and $ln eq 'stylesheet') or
                ($nsurl eq XSLT_NS and $ln eq 'transform')) {
              $self->{flag}->{is_xslt_stylesheet} = 1;
            } elsif ($mime eq 'application/xslt+xml' or
                     $mime eq 'text/xsl' or
                     $node->has_attribute_ns (XSLT_NS, 'version')) {
              $self->{flag}->{is_xslt_stylesheet} = 1;
              ## This should be a literal result element.
              $is_root_literal_result = 1;

              $self->{onerror}->(node => $node,
                                 type => 'element not allowed',
                                 level => 'm')
                  if $nsurl eq XSLT_NS;
              
              # XXX this MUST NOT be an extension element

              $self->{onerror}->(node => $node,
                                 type => 'xslt:root literal result element',
                                 level => 's')
                  unless $mime eq 'application/xslt+xml' or
                         $mime eq 'text/xsl';
              $self->{onerror}->(node => $node,
                                 type => 'attribute missing',
                                 text => 'xslt:version',
                                 level => 'm')
                  unless $node->has_attribute_ns (XSLT_NS, 'version');
            } elsif (($_Defs->{elements}->{$nsurl}->{$ln} or {})->{root}) {
              #
            } elsif ($_Defs->{namespaces}->{$nsurl}->{supported}) {
              $self->{onerror}->(node => $node,
                                 type => 'element not allowed:root',
                                 level => 'm');
            } else { # unknown element
              #
            }

            unless ($nsurl eq HTML_NS and $ln eq 'html') {
              if ($item->{node}->manakai_is_html) {
                $self->{onerror}->(node => $node,
                                   type => 'document element not serializable',
                                   level => 'w');
              }
            }
            # XXX $doc->content_type vs root element
            # XXX     - should be text/xml, application/xml, xslt mime type if XSLT
          } # first element child
          push @new_item, {type => 'element', node => $node,
                           is_root_literal_result => $is_root_literal_result,
                           parent_state => $parent_state};
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
          # XXX check the node, child PIs
        } elsif ($nt == 3) { # TEXT_NODE
          $self->{onerror}->(node => $node,
                             type => 'root text',
                             level => 'm'); # [MANAKAI] [DOM]
          $self->_check_data ($node, 'data');
        } elsif ($nt == 7) { # PROCESSING_INSTRUCTION_NODE
          $self->_check_pi ($node, $parent_state);
        }
        
        # XXX Comment validation
      } # $node
      
      $self->{onerror}->(node => $item->{node},
                         type => 'no document element',
                         level => 'w')
          unless $has_element;

      $self->_dtd ($item->{node});

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
                           is_root => 1};
        } elsif ($nt == 3) { # TEXT_NODE
          $self->_check_data ($node, 'data');
        } elsif ($nt == 7) { # PROCESSING_INSTRUCTION_NODE
          $self->_check_pi ($node, $parent_state);
        }
        # XXX Comment
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
      ## There is no |map| element with the specified name at all.
      $self->{onerror}->(node => $_->[1],
                         type => 'no referenced map',
                         level => 'm');
    }
  }

  ## @{$self->{idref}}       Detected ID references to be checked:
  ##                         [id-type, id-value, id-node]
  ## @{$self->{id}->{$id}}   Detected ID nodes, in tree order
  ## $self->{id_type}->{$id} Type of first ID node's element
  ## ID types:
  ##   any       Any type is allowed (For |idref| only)
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
      }->{$_->[0]};
      $self->{onerror}->(node => $_->[2],
                         type => $error_type,
                         value => $_->[1],
                         level => 'm');
    }
  } # $self->{idref}

  ## OGP
  for my $prop (keys %{$self->{flag}->{ogp_required_prop} or {}}) {
    $self->{onerror}->(node => $self->{flag}->{ogp_required_prop}->{$prop},
                       type => 'ogp:missing prop',
                       text => $prop,
                       level => 'm')
        unless $self->{flag}->{ogp_has_prop}->{$prop};
  }
  my $ogtype = $self->{flag}->{ogtype} || '';
  for (values %{$self->{flag}->{ogp_expected_types} or {}}) {
    unless ($_->[1]->{$ogtype}) {
      $self->{onerror}->(node => $_->[0],
                         type => 'ogp:prop:bad og:type',
                         text => (join ' ', sort { $a cmp $b } keys %{$_->[1]}),
                         level => 'm');
    }
  }
} # _check_refs

sub check_node ($$) {
  my ($self, $node) = @_;
  $self->onerror;
  $self->_init;

  ## RSS2 document
  ## <https://manakai.github.io/spec-dom/validation-langs#rss2-document>.
  my $de = ($node->owner_document || $node)->document_element;
  $self->{is_rss2} = (defined $de and $de->manakai_element_type_match (undef, 'rss'));

  my $nt = $node->node_type;
  if ($nt == 1) { # ELEMENT_NODE
    my $is_hidden = (($node->namespace_uri || '') eq HTML_NS and
                     $node->has_attribute_ns (undef, 'hidden'));
    $self->{flag}->{is_template} = 1 if $is_hidden;

    $self->_check_node
        ([{type => 'element', node => $node, parent_state => {},
           is_root => 1}]);
  } elsif ($nt == 9) { # DOCUMENT_NODE
    $self->_check_node ([{type => 'document', node => $node}]);
  } elsif ($nt == 3) { # TEXT_NODE
    $self->_check_data ($node, 'data');
  } elsif ($nt == 2) { # ATTRIBUTE_NODE
    $self->_check_data ($node, 'value');
  } elsif ($nt == 11) { # DOCUMENT_FRAGMENT_NODE
    # XXX shadow root
    $self->_check_node ([{type => 'document_fragment', node => $node}]);
  } elsif ($nt == 7) { # PROCESSING_INSTRUCTION_NODE
    $self->_check_pi ($node, {});
  }
  # XXX Comment DocumentType Entity Notation ElementTypeDefinition AttributeDefinition
  $self->_check_refs;
  $self->_validate_microdata;
  $self->_validate_aria ([$node]);
  $self->_terminate;

  # XXX More useful return object
  #return
  delete $self->{return}; # XXX
} # check_node

1;

=head1 LICENSE

Copyright 2007-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
