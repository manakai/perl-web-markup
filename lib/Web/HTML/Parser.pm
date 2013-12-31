package Web::HTML::Parser; # -*- Perl -*-
use strict;
#use warnings;
no warnings 'utf8';
our $VERSION = '5.0';
use Encode;
use Web::HTML::Defs;
use Web::HTML::Tokenizer;
push our @ISA, qw(Web::HTML::Tokenizer);



use Web::HTML::Tokenizer;

## Namespace URLs

sub HTML_NS () { q<http://www.w3.org/1999/xhtml> }
sub MML_NS () { q<http://www.w3.org/1998/Math/MathML> }
sub SVG_NS () { q<http://www.w3.org/2000/svg> }

## Element categories

## Bits 16-20
sub BUTTON_SCOPING_EL () { 0b1_00000000000000000000 } ## Special
sub SPECIAL_EL () { 0b1_0000000000000000000 }         ## Special
sub SCOPING_EL () { 0b1_000000000000000000 }          ## Special
sub FORMATTING_EL () { 0b1_00000000000000000 }        ## Formatting
sub PHRASING_EL () { 0b1_0000000000000000 }           ## Ordinary

## Bits 12-15
sub SVG_EL () { 0b1_000000000000000 }
sub MML_EL () { 0b1_00000000000000 }
#sub FOREIGN_EL () { 0b1_0000000000000 } # see Web::HTML::Defs
sub FOREIGN_FLOW_CONTENT_EL () { 0b1_000000000000 }

## Bits 8-11
sub TABLE_SCOPING_EL () { 0b1_00000000000 }
sub TABLE_ROWS_SCOPING_EL () { 0b1_0000000000 }
sub TABLE_ROW_SCOPING_EL () { 0b1_000000000 }
sub TABLE_ROWS_EL () { 0b1_00000000 }

## Bit 6-7
sub LIST_CONTAINER_EL () { 0b1_0000000 }
sub ADDRESS_DIV_P_EL () { 0b1_000000 }

## NOTE: Used in </body> and EOF algorithms.
## Bit 5
sub ALL_END_TAG_OPTIONAL_EL () { 0b1_00000 }

## NOTE: Used in "generate implied end tags" algorithm.
## NOTE: There is a code where a modified version of
## END_TAG_OPTIONAL_EL is used in "generate implied end tags"
## implementation (search for the algorithm name).
## Bit 4
sub END_TAG_OPTIONAL_EL () { 0b1_0000 }

## Bits 0-3

sub MISC_SPECIAL_EL () { SPECIAL_EL | 0b0000 }
sub FORM_EL () { SPECIAL_EL | 0b0001 }
sub FRAMESET_EL () { SPECIAL_EL | 0b0010 }
sub HEADING_EL () { SPECIAL_EL | 0b0011 }
sub SELECT_EL () { SPECIAL_EL | 0b0100 }
sub SCRIPT_EL () { SPECIAL_EL | 0b0101 }
sub BUTTON_EL () { SPECIAL_EL | BUTTON_SCOPING_EL | 0b0110 }
sub HEAD_EL () { SPECIAL_EL | 0b0111 }
sub COLGROUP_EL () { SPECIAL_EL | 0b1000 }

sub ADDRESS_DIV_EL () { SPECIAL_EL | ADDRESS_DIV_P_EL | 0b0001 }
sub BODY_EL () { SPECIAL_EL | ALL_END_TAG_OPTIONAL_EL | 0b0001 }

sub DTDD_EL () {
  SPECIAL_EL |
  END_TAG_OPTIONAL_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0010
}
sub ULOL_EL () {
  SPECIAL_EL |
  LIST_CONTAINER_EL |
  0b0001
}
sub LI_EL () {
  SPECIAL_EL |
  END_TAG_OPTIONAL_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0100
}
sub P_EL () {
  SPECIAL_EL |
  ADDRESS_DIV_P_EL |
  END_TAG_OPTIONAL_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0001
}

sub TABLE_ROW_EL () {
  SPECIAL_EL |
  TABLE_ROWS_EL |
  TABLE_ROW_SCOPING_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0001
}
sub TABLE_ROW_GROUP_EL () {
  SPECIAL_EL |
  TABLE_ROWS_EL |
  TABLE_ROWS_SCOPING_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0001
}

sub MISC_SCOPING_EL () { SCOPING_EL | BUTTON_SCOPING_EL | 0b0000 }
sub CAPTION_EL () { SCOPING_EL | BUTTON_SCOPING_EL | 0b0010 }
sub HTML_EL () {
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  TABLE_SCOPING_EL |
  TABLE_ROWS_SCOPING_EL |
  TABLE_ROW_SCOPING_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0001
}
sub TABLE_EL () {
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  TABLE_ROWS_EL |
  TABLE_SCOPING_EL |
  0b0001
}
sub TABLE_CELL_EL () {
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  ALL_END_TAG_OPTIONAL_EL |
  0b0001
}
sub TEMPLATE_EL () {
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  TABLE_SCOPING_EL |
  TABLE_ROWS_SCOPING_EL |
  TABLE_ROW_SCOPING_EL |
  0b0001
}

sub MISC_FORMATTING_EL () { FORMATTING_EL | 0b0000 }
sub A_EL () { FORMATTING_EL | 0b0001 }
sub NOBR_EL () { FORMATTING_EL | 0b0010 }

sub RUBY_EL () { PHRASING_EL | 0b0001 }

## NOTE: These elements are not included in |ALL_END_TAG_OPTIONAL_EL|.
sub OPTGROUP_EL () { PHRASING_EL | END_TAG_OPTIONAL_EL | 0b0001 }
sub OPTION_EL () { PHRASING_EL | END_TAG_OPTIONAL_EL | 0b0010 }
sub RUBY_COMPONENT_EL () { PHRASING_EL | END_TAG_OPTIONAL_EL | 0b0100 }

## "MathML text integration point" elements.
sub MML_TEXT_INTEGRATION_EL () {
  MML_EL |
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  FOREIGN_EL |
  FOREIGN_FLOW_CONTENT_EL
} # MML_TEXT_INTEGRATION_EL

sub MML_AXML_EL () {
  MML_EL |
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  FOREIGN_EL |
  0b0001
} # MML_AXML_EL

## "HTML integration point" elements in SVG namespace.
sub SVG_INTEGRATION_EL () {
  SVG_EL |
  SCOPING_EL |
  BUTTON_SCOPING_EL |
  FOREIGN_EL |
  FOREIGN_FLOW_CONTENT_EL
} # SVG_INTEGRATION_EL

sub SVG_SCRIPT_EL () {
  SVG_EL |
  FOREIGN_EL |
  0b0101
} # SVG_SCRIPT_EL

my $el_category = {
  a => A_EL,
  address => ADDRESS_DIV_EL,
  applet => MISC_SCOPING_EL,
  area => MISC_SPECIAL_EL,
  article => MISC_SPECIAL_EL,
  aside => MISC_SPECIAL_EL,
  b => FORMATTING_EL,
  base => MISC_SPECIAL_EL,
  basefont => MISC_SPECIAL_EL,
  bgsound => MISC_SPECIAL_EL,
  big => FORMATTING_EL,
  blockquote => MISC_SPECIAL_EL,
  body => BODY_EL,
  br => MISC_SPECIAL_EL,
  button => BUTTON_EL,
  caption => CAPTION_EL,
  center => MISC_SPECIAL_EL,
  code => FORMATTING_EL,
  col => MISC_SPECIAL_EL,
  colgroup => COLGROUP_EL,
  #datagrid => MISC_SPECIAL_EL,
  dd => DTDD_EL,
  details => MISC_SPECIAL_EL,
  dir => MISC_SPECIAL_EL,
  div => ADDRESS_DIV_EL,
  dl => MISC_SPECIAL_EL,
  dt => DTDD_EL,
  em => FORMATTING_EL,
  embed => MISC_SPECIAL_EL,
  fieldset => MISC_SPECIAL_EL,
  figcaption => MISC_SPECIAL_EL,
  figure => MISC_SPECIAL_EL,
  font => FORMATTING_EL,
  footer => MISC_SPECIAL_EL,
  form => FORM_EL,
  frame => MISC_SPECIAL_EL,
  frameset => FRAMESET_EL,
  h1 => HEADING_EL,
  h2 => HEADING_EL,
  h3 => HEADING_EL,
  h4 => HEADING_EL,
  h5 => HEADING_EL,
  h6 => HEADING_EL,
  head => HEAD_EL,
  header => MISC_SPECIAL_EL,
  hgroup => MISC_SPECIAL_EL,
  hr => MISC_SPECIAL_EL,
  html => HTML_EL,
  i => FORMATTING_EL,
  iframe => MISC_SPECIAL_EL,
  img => MISC_SPECIAL_EL,
  #image => MISC_SPECIAL_EL, ## NOTE: Commented out in the spec.
  input => MISC_SPECIAL_EL,
  isindex => MISC_SPECIAL_EL,
  ## XXX keygen? (Whether a void element is in Special or not does not
  ## affect to the processing, however.)
  li => LI_EL,
  link => MISC_SPECIAL_EL,
  listing => MISC_SPECIAL_EL,
  main => MISC_SPECIAL_EL,
  marquee => MISC_SCOPING_EL,
  menu => MISC_SPECIAL_EL,
  menuitem => MISC_SPECIAL_EL,
  meta => MISC_SPECIAL_EL,
  nav => MISC_SPECIAL_EL,
  nobr => NOBR_EL,
  noembed => MISC_SPECIAL_EL,
  noframes => MISC_SPECIAL_EL,
  noscript => MISC_SPECIAL_EL,
  object => MISC_SCOPING_EL,
  ol => ULOL_EL,
  optgroup => OPTGROUP_EL,
  option => OPTION_EL,
  p => P_EL,
  param => MISC_SPECIAL_EL,
  plaintext => MISC_SPECIAL_EL,
  pre => MISC_SPECIAL_EL,
  rp => RUBY_COMPONENT_EL,
  rt => RUBY_COMPONENT_EL,
  ruby => RUBY_EL,
  s => FORMATTING_EL,
  script => MISC_SPECIAL_EL,
  select => SELECT_EL,
  section => MISC_SPECIAL_EL,
  small => FORMATTING_EL,
  source => MISC_SPECIAL_EL,
  strike => FORMATTING_EL,
  strong => FORMATTING_EL,
  style => MISC_SPECIAL_EL,
  summary => MISC_SPECIAL_EL,
  table => TABLE_EL,
  template => TEMPLATE_EL,
  tbody => TABLE_ROW_GROUP_EL,
  td => TABLE_CELL_EL,
  textarea => MISC_SPECIAL_EL,
  tfoot => TABLE_ROW_GROUP_EL,
  th => TABLE_CELL_EL,
  thead => TABLE_ROW_GROUP_EL,
  title => MISC_SPECIAL_EL,
  tr => TABLE_ROW_EL,
  track => MISC_SPECIAL_EL,
  tt => FORMATTING_EL,
  u => FORMATTING_EL,
  ul => ULOL_EL,
  wbr => MISC_SPECIAL_EL,
  xmp => MISC_SPECIAL_EL,
  ## When an element is added to the "special" category, add a test
  ## like: "<!DOCTYPE html><span><main>aab</span>bbbb".
}; # $el_category

my $el_category_f = {
  (MML_NS) => {
    'annotation-xml' => MML_AXML_EL,
    mi => MML_TEXT_INTEGRATION_EL,
    mo => MML_TEXT_INTEGRATION_EL,
    mn => MML_TEXT_INTEGRATION_EL,
    ms => MML_TEXT_INTEGRATION_EL,
    mtext => MML_TEXT_INTEGRATION_EL,
  },
  (SVG_NS) => {
    foreignObject => SVG_INTEGRATION_EL,
    desc => SVG_INTEGRATION_EL,
    title => SVG_INTEGRATION_EL,
    script => SVG_SCRIPT_EL,
  },
  ## NOTE: In addition, FOREIGN_EL is set to non-HTML elements, MML_EL
  ## is set to MathML elements, and SVG_EL is set to SVG elements.
}; # $el_category_f

require Web::HTML::ParserData;

my $svg_attr_name = $Web::HTML::ParserData::SVGAttrNameFixup;
my $mml_attr_name = $Web::HTML::ParserData::MathMLAttrNameFixup;
my $foreign_attr_xname = $Web::HTML::ParserData::ForeignAttrNamespaceFixup;

## TODO: Invoke the reset algorithm when a resettable element is
## created (cf. HTML5 revision 2259).

## ------ String parse API ------

sub parse_byte_string ($$$$) {
  #my ($self, $charset_name, $string, $doc) = @_;
  my $self = ref $_[0] ? $_[0] : $_[0]->new;
  my $doc = $self->{document} = $_[3];

  my $embedded_encoding_name;
  PARSER: {
    {
      local $self->{document}->dom_config->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'} = 0;
      $self->{document}->text_content ('');
    }
    
    my $inputref = \($_[2]);
    $self->_encoding_sniffing
        (transport_encoding_name => $_[1],
         embedded_encoding_name => $embedded_encoding_name,
         read_head => sub {
           return \substr $$inputref, 0, 1024;
         }); # $self->{confident} is set within this method.
    $self->{document}->input_encoding ($self->{input_encoding});

    $self->{line_prev} = $self->{line} = 1;
    $self->{column_prev} = -1;
    $self->{column} = 0;

    $self->{chars} = [split //, decode $self->{input_encoding}, $$inputref]; # XXX encoding standard
    $self->{chars_pos} = 0;
    $self->{chars_pull_next} = sub { 0 };
    delete $self->{chars_was_cr};

    $self->{restart_parser} = sub {
      $embedded_encoding_name = $_[0];
      die bless {}, 'Web::HTML::InputStream::RestartParser';
      return 0;
    };

    my $onerror = $self->onerror;
    $self->{parse_error} = sub {
      $onerror->(line => $self->{line}, column => $self->{column}, @_);
    };

    $self->_initialize_tokenizer;
    $self->_initialize_tree_constructor;
    $self->{t} = $self->_get_next_token;
    my $error;
    {
      local $@;
      eval { $self->_construct_tree; 1 } or $error = $@;
    }
    if ($error) {
      if (ref $error eq 'Web::HTML::InputStream::RestartParser') {
        redo PARSER;
      }
      die $error;
    }
    $self->_on_terminate;
  } # PARSER

  return $doc;
} # parse_byte_string

## NOTE: HTML5 spec says that the encoding layer MUST NOT strip BOM
## and the HTML layer MUST ignore it.  However, we does strip BOM in
## the encoding layer and the HTML layer does not ignore any U+FEFF,
## because the core part of our HTML parser expects a string of
## character, not a string of bytes or code units or anything which
## might contain a BOM.  Therefore, any parser interface that accepts
## a string of bytes, such as |parse_byte_string| in this module, must
## ensure that it does strip the BOM and never strip any ZWNBSP.

## XXX The policy mentioned above might change when we implement
## Encoding Standard spec.

sub parse_char_string ($$$) {
  #my ($self, $string, $document) = @_;
  my $self = ref $_[0] ? $_[0] : $_[0]->new;
  my $doc = $self->{document} = $_[2];
  {
    local $self->{document}->dom_config->{'http://suika.fam.cx/www/2006/dom-config/strict-document-children'} = 0;
    $self->{document}->text_content ('');
  }

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

  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor;
  $self->{t} = $self->_get_next_token;
  $self->_construct_tree;
  $self->_on_terminate;

  return {};
} # parse_char_string

## ------ Stream parse API (experimental) ------

## XXX tests

sub parse_bytes_start ($$$) {
  #my ($self, $charset_name, $doc) = @_;
  my $self = ref $_[0] ? $_[0] : $_[0]->new;
  my $doc = $self->{document} = $_[2];
  
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
  
  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor;

  push @{$self->{chars}}, split //,
      decode $self->{input_encoding}, $self->{byte_buffer}, # XXX Encoding Standard
          Encode::FB_QUIET;
  $self->{t} = $self->_get_next_token;
  $self->_construct_tree;
  if ($self->{embedded_encoding_name}) {
    ## Restarting
    $self->_parse_bytes_start_parsing;
  }
} # _parse_bytes_start_parsing

## The $args{start_parsing} flag should be set true if it has taken
## more than 500ms from the start of overall parsing process.
sub parse_bytes_feed ($$;%) {
  my ($self, undef, %args) = @_;

  if ($self->{parse_bytes_started}) {
    $self->{byte_buffer} .= $_[1];
    $self->{byte_buffer_orig} .= $_[1];
    $self->{chars}
        = [split //, decode $self->{input_encoding}, $self->{byte_buffer},
                         Encode::FB_QUIET]; # XXX encoding standard
    $self->{chars_pos} = 0;
    my $i = 0;
    if (length $self->{byte_buffer} and @{$self->{chars}} == $i) {
      substr ($self->{byte_buffer}, 0, 1) = '';
      push @{$self->{chars}}, "\x{FFFD}", split //,
          decode $self->{input_encoding}, $self->{byte_buffer},
              Encode::FB_QUIET; # XXX Encoding Standard
      $i++;
    }
    
    $self->{t} = $self->_get_next_token;
    $self->_construct_tree;
    if ($self->{embedded_encoding_name}) {
      ## Restarting the parser
      $self->_parse_bytes_start_parsing;
    }
  } else {
    $self->{byte_buffer} .= $_[1];
    $self->{byte_buffer_orig} .= $_[1];
    if ($args{start_parsing} or 1024 <= length $self->{byte_buffer}) {
      $self->_parse_bytes_start_parsing;
    }
  }
} # parse_bytes_feed

sub parse_bytes_end {
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
  $self->{t} = $self->_get_next_token;
  $self->_construct_tree;
  if ($self->{embedded_encoding_name}) {
    ## Restarting the parser
    $self->_parse_bytes_start_parsing;
  }

  $self->_on_terminate;
} # parse_bytes_end

sub _on_terminate ($) {
  $_[0]->_terminate_tree_constructor;
  $_[0]->_clear_refs;
} # _on_terminate

## ------ Insertion modes ------

sub AFTER_HTML_IMS () { 0b100 }
sub HEAD_IMS ()       { 0b1000 }
sub BODY_IMS ()       { 0b10000 }
sub BODY_TABLE_IMS () { 0b100000 }
sub TABLE_IMS ()      { 0b1000000 }
sub ROW_IMS ()        { 0b10000000 }
sub BODY_AFTER_IMS () { 0b100000000 }
sub FRAME_IMS ()      { 0b1000000000 }
sub SELECT_IMS ()     { 0b10000000000 }
sub IN_CDATA_RCDATA_IM () { 0b1000000000000 }
    ## NOTE: "in CDATA/RCDATA" insertion mode is also special; it is
    ## combined with the original insertion mode.  In thie parser,
    ## they are stored together in the bit-or'ed form.

sub IM_MASK () { 0b11111111111 }

## NOTE: These insertion modes are special.
sub INITIAL_IM () { -1 }
sub BEFORE_HTML_IM () { -2 }

## NOTE: "after after body" insertion mode.
sub AFTER_HTML_BODY_IM () { AFTER_HTML_IMS | BODY_AFTER_IMS }

## NOTE: "after after frameset" insertion mode.
sub AFTER_HTML_FRAMESET_IM () { AFTER_HTML_IMS | FRAME_IMS }

sub IN_HEAD_IM () { HEAD_IMS | 0b00 }
sub IN_HEAD_NOSCRIPT_IM () { HEAD_IMS | 0b01 }
sub AFTER_HEAD_IM () { HEAD_IMS | 0b10 }
sub BEFORE_HEAD_IM () { HEAD_IMS | 0b11 }
sub IN_BODY_IM () { BODY_IMS }
sub IN_CELL_IM () { BODY_IMS | BODY_TABLE_IMS | 0b01 }
sub IN_CAPTION_IM () { BODY_IMS | BODY_TABLE_IMS | 0b10 }
sub IN_TEMPLATE_IM () { BODY_IMS | 0b11 }
sub IN_ROW_IM () { TABLE_IMS | ROW_IMS | 0b01 }
sub IN_TABLE_BODY_IM () { TABLE_IMS | ROW_IMS | 0b10 }
sub IN_TABLE_IM () { TABLE_IMS }
sub AFTER_BODY_IM () { BODY_AFTER_IMS }
sub IN_FRAMESET_IM () { FRAME_IMS | 0b01 }
sub AFTER_FRAMESET_IM () { FRAME_IMS | 0b10 }
sub IN_SELECT_IM () { SELECT_IMS | 0b01 }
sub IN_SELECT_IN_TABLE_IM () { SELECT_IMS | 0b10 }
sub IN_COLUMN_GROUP_IM () { 0b10 }



sub _initialize_tree_constructor ($) {
  my $self = shift;
  ## NOTE: $self->{document} MUST be specified before this method is called
  $self->{document}->strict_error_checking (0);
  ## TODO: Turn mutation events off # MUST
  ## TODO: Turn loose Document option (manakai extension) on
  $self->{document}->manakai_is_html (1); # MUST
  $self->{document}->set_user_data (manakai_source_line => 1);
  $self->{document}->set_user_data (manakai_source_column => 1);

  $self->{frameset_ok} = 1;
  delete $self->{active_formatting_elements};
  delete $self->{insert};
  delete $self->{open_tables};

  $self->{insertion_mode} = INITIAL_IM;
  undef $self->{form_element};
  undef $self->{head_element};
  $self->{open_elements} = [];
  undef $self->{inner_html_node};
  undef $self->{ignore_newline};
  $self->{template_ims} = []; # stack of template insertion modes
} # _initialize_tree_constructor

sub _terminate_tree_constructor ($) {
  my $self = shift;
  $self->{document}->strict_error_checking (1) if $self->{document};
  ## TODO: Turn mutation events on
} # _terminate_tree_constructor

## ISSUE: Should append_child (for example) in script executed in tree construction stage fire mutation events?

## When an interactive UA render the $self->{document} available to
## the user, or when it begin accepting user input, are not defined.

sub _reset_insertion_mode ($) {
  my $self = shift;

  ## Reset the insertion mode appropriately
  ## <http://www.whatwg.org/specs/web-apps/current-work/#reset-the-insertion-mode-appropriately>

  ## Step 1
  my $last;
  
  ## Step 2
  my $i = -1;
  my $node = $self->{open_elements}->[$i];
    
  ## LOOP: Step 3
  LOOP: {
    if ($self->{open_elements}->[0]->[0] eq $node->[0]) {
      $last = 1;
      if (defined $self->{inner_html_node}) {
        
        $node = $self->{inner_html_node};
      }
    }
    
    my $new_mode;
    if ($node->[1] == TABLE_CELL_EL) {
      ## Step 5 |td| or |th|
      if ($last) {
        
        #
      } else {
        
        $new_mode = IN_CELL_IM;
      }
    } elsif ($node->[1] == SELECT_EL) {
      ## Step 4 |select|
      $new_mode = IN_SELECT_IM; ## 4.8 Done
      unless ($last) { ## 4.1
        my $j = $i;
        while (1) { ## 4.2, 4.3 Loop, 4.4, 4.7
          if ($self->{open_elements}->[$j]->[1] == TEMPLATE_EL) {
            last; ## 4.5
          } elsif ($self->{open_elements}->[$j]->[1] == TABLE_EL) {
            $new_mode = IN_SELECT_IN_TABLE_IM; ## 4.6
            last;
          } elsif ($self->{open_elements}->[$j]->[1] == HTML_EL) {
            last; # $self->{open_elements}->[0]
          }
          $j--;
        }
      }
    } elsif ($node->[1] == TEMPLATE_EL) {
      $new_mode = $self->{template_ims}->[-1]; ## Current template insertion mode
    } elsif ($node->[1] == HEAD_EL) {
      if ($last) {
        ## Commented out in the spec
        ##$new_mode = IN_BODY_IM;
      } else {
        $new_mode = IN_HEAD_IM;
      }
    } elsif ($node->[1] & FOREIGN_EL) {
      #
    } else {
      ## Step 6-10, 13, 14
      
      $new_mode = {
        ## NOTE: |option| and |optgroup| do not set insertion mode to
        ## "in select" by themselves.
        tr => IN_ROW_IM,
        tbody => IN_TABLE_BODY_IM,
        thead => IN_TABLE_BODY_IM,
        tfoot => IN_TABLE_BODY_IM,
        caption => IN_CAPTION_IM,
        colgroup => IN_COLUMN_GROUP_IM,
        table => IN_TABLE_IM,
        body => IN_BODY_IM,
        frameset => IN_FRAMESET_IM,
      }->{$node->[0]->local_name};
    }
    $self->{insertion_mode} = $new_mode and last LOOP if defined $new_mode;
    
    ## Step 15
    if ($node->[1] == HTML_EL) {
      unless (defined $self->{head_element}) {
        $self->{insertion_mode} = BEFORE_HEAD_IM;
      } else {
        $self->{insertion_mode} = AFTER_HEAD_IM;
      }
      last LOOP;
    } else {
      
    }
    
    ## Step 16
    $self->{insertion_mode} = IN_BODY_IM and last LOOP if $last;
    
    ## Step 17
    $i--;
    $node = $self->{open_elements}->[$i];
    
    ## Step 18
    redo LOOP;
  } # LOOP
  
  ## END
} # _reset_insertion_mode

  my $parse_rcdata = sub ($$$$) {
    my ($self, $insert, $open_tables, $parse_refs) = @_;

    ## Step 1
    my $start_tag_name = $self->{t}->{tag_name};
    
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

    ## Step 2
    if ($parse_refs) {
      $self->{state} = RCDATA_STATE;
    } else {
      $self->{state} = RAWTEXT_STATE;
    }
    delete $self->{escape}; # MUST

    ## Step 3, 4
    $self->{insertion_mode} |= IN_CDATA_RCDATA_IM;

    
    $self->{t} = $self->_get_next_token;
  }; # $parse_rcdata

  my $script_start_tag = sub ($$$) {
    my ($self, $insert, $open_tables) = @_;

    ## Step 1
    my $script_el;
    
      $script_el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'script']);
    
        for my $attr_name (keys %{ $self->{t}->{attributes}}) {
          my $attr_t =  $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $script_el->set_attribute_node_ns ($attr);
        }
      
        $script_el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $script_el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      

    ## Step 2
    ## TODO: mark as "parser-inserted"

    ## Step 3
    ## TODO: Mark as "already executed", if ...

    ## Step 4 (HTML5 revision 2702)
    $insert->($self, $script_el, $open_tables);
    push @{$self->{open_elements}}, [$script_el, $el_category->{script}];

    ## Step 5
    $self->{state} = SCRIPT_DATA_STATE;
    delete $self->{escape}; # MUST

    ## Step 6-7
    $self->{insertion_mode} |= IN_CDATA_RCDATA_IM;

    
    $self->{t} = $self->_get_next_token;
  }; # $script_start_tag

sub push_afe ($$) {
  my ($item => $afes) = @_;
  my $item_token = $item->[2];

  ## 1. The Noah's Ark clause.
  my $depth = 0;
  OUTER: for my $i (reverse 0..$#$afes) {
    my $afe = $afes->[$i];
    if ($afe->[0] eq '#marker') {
      last OUTER;
    } else {
      my $afe_token = $afe->[2];
      ## Both |$afe_token| and |$item_token| should be start tag tokens.
      if ($afe_token->{tag_name} eq $item_token->{tag_name}) {
        if ((keys %{$afe_token->{attributes}}) !=
            (keys %{$item_token->{attributes}})) {
          next OUTER;
        }
        for my $attr_name (keys %{$item_token->{attributes}}) {
          next OUTER unless $afe_token->{attributes}->{$attr_name};
          next OUTER unless
              $afe_token->{attributes}->{$attr_name}->{value} eq 
              $item_token->{attributes}->{$attr_name}->{value};
        }

        $depth++;
        if ($depth == 3) {
          splice @$afes, $i, 1 => ();
          last OUTER;
        }
      }

      ## We don't have to check namespaces of elements and attributes,
      ##  nevertheless the spec requires it, because |$afes| could
      ##  never contain a non-HTML element at the time of writing.  In
      ##  addition, scripted changes would never change the original
      ##  start tag token.
    }
  } # OUTER

  ## 2.
  push @$afes, $item;
} # push_afe

## The adoption agency algorithm (AAA)
## <http://www.whatwg.org/specs/web-apps/current-work/#adoption-agency-algorithm>.
sub _aaa ($$) {
  my ($self, $token) = @_;

  ## $end_tag_token is an end tag token or <a>/<nobr> (start tag
  ## token).  Don't edit it as it might be used later to create
  ## another element.

  ## 1.
  if (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
      $self->{open_elements}->[-1]->[0]->local_name eq $token->{tag_name}) {
    my $el = $self->{open_elements}->[-1]->[0]; ## 1.1.
    pop @{$self->{open_elements}}; ## 1.2.
    @{$self->{active_formatting_elements}} ## 1.3.
        = grep { $_->[0] != $el } @{$self->{active_formatting_elements}};
    return; ## 1.4.
  }

  my $oes = [@{$self->{open_elements}}];

  ## 2.
  my $outer_loop_counter = 0;

  ## 3. Outer loop
  OUTER: {
    return if $outer_loop_counter >= 8;

    ## 4.
    $outer_loop_counter++;
    
    ## 5.
    my $formatting_element;
    my $formatting_element_i_in_active;
    AFE: for (reverse 0..$#{$self->{active_formatting_elements}}) {
      if ($self->{active_formatting_elements}->[$_]->[0] eq '#marker') {
        last AFE;
      } elsif ($self->{active_formatting_elements}->[$_]->[0]->local_name eq $token->{tag_name}) {
        ## NOTE: Non-HTML elements can't be in the list of active
        ## formatting elements.
        $formatting_element = $self->{active_formatting_elements}->[$_];
        $formatting_element_i_in_active = $_;
        last AFE;
      }
    } # AFE
    unless (defined $formatting_element) {
      $self->_in_body_any_other_end_tag;
      return;
    }

    ## 6.-7.
    my $formatting_element_i_in_open;
    my $formatting_element_is_in_scope = 1;
    OE: for (reverse 0..$#{$self->{open_elements}}) {
      if ($self->{open_elements}->[$_]->[0] eq $formatting_element->[0]) {
        $formatting_element_i_in_open = $_;
        last OE;
      } elsif ($self->{open_elements}->[$_]->[1] & SCOPING_EL) {
        $formatting_element_is_in_scope = 0;
      }
    } # OE
    unless (defined $formatting_element_i_in_open) {
      ## 6.
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'AAA:in afe but not in open elements', # XXXdoc
                      text => $formatting_element->[0]->local_name,
                      value => $token->{tag_name},
                      token => $token);
      splice @{$self->{active_formatting_elements}},
          $formatting_element_i_in_active, 1 => ();
      return;
    }
    unless ($formatting_element_is_in_scope) {
      ## 7.
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'AAA:formatting element not in scope', # XXXdoc
                      text => $formatting_element->[0]->local_name,
                      value => $token->{tag_name},
                      token => $token);
      return;
    }

    ## 8.
    unless ($formatting_element->[0] eq $self->{open_elements}->[-1]->[0]) {
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'AAA:formatting element not current', # XXXdoc
                      text => $formatting_element->[0]->local_name,
                      value => $token->{tag_name},
                      token => $token);
    }

    ## 9.
    my $furthest_block;
    my $furthest_block_i_in_open;
    OE: for (reverse (($formatting_element_i_in_open + 1)..$#{$self->{open_elements}})) {
      if ($self->{open_elements}->[$_]->[1] & (SPECIAL_EL | SCOPING_EL)) { ## "Special"
        $furthest_block = $self->{open_elements}->[$_];
        $furthest_block_i_in_open = $_;
        ## NOTE: The topmost (eldest) node.
        last OE;
      }
    } # OE
    
    ## 10.
    unless (defined $furthest_block) {
      splice @{$self->{open_elements}}, $formatting_element_i_in_open;
      splice @{$self->{active_formatting_elements}},
          $formatting_element_i_in_active, 1 => ();
      return;
    }
    
    ## 11.
    my $common_ancestor_node = $self->{open_elements}->[$formatting_element_i_in_open - 1];
    
    ## 12.
    my $bookmark_prev_el = $self->{active_formatting_elements}->[$formatting_element_i_in_active - 1]->[0];
    
    ## 13.
    my $node = $furthest_block;
    my $node_i_in_open = $furthest_block_i_in_open;
    my $last_node = $furthest_block;
    my $inner_loop_counter = 0; ## 13.1.

    ## 13.2. Inner loop
    INNER: {
      $inner_loop_counter++;

      ## 13.3.
      $node_i_in_open--;
      $node = $oes->[$node_i_in_open];

      ## 13.4. Go to 14.
      last INNER if $node->[0] eq $formatting_element->[0];

      ## 13.5., 13.6.
      if ($inner_loop_counter > 3) {
        @{$self->{active_formatting_elements}}
            = grep { $_->[0] ne $node->[0] } @{$self->{active_formatting_elements}};
        @{$self->{open_elements}}
            = grep { $_->[0] ne $node->[0] } @{$self->{open_elements}};
        redo INNER;
      }

      ## 13.6.
      my $node_i_in_active;
      AFE: for (reverse 0..$#{$self->{active_formatting_elements}}) {
        if ($self->{active_formatting_elements}->[$_]->[0] eq $node->[0]) {
          $node_i_in_active = $_;
          last AFE;
        }
      } # AFE
      unless (defined $node_i_in_active) {
        @{$self->{open_elements}}
            = grep { $_->[0] ne $node->[0] } @{$self->{open_elements}};
        redo INNER;
      }

      ## 13.7.
      ## AFE->[$_]->[2] contains the token that creates $NODE.
      my $node_token = $self->{active_formatting_elements}->[$node_i_in_active]->[2];
      my $new_element = [];
      # XXX intended parent is $common_ancestor
      
      $new_element->[0] = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $node_token->{tag_name}]);
    
        for my $attr_name (keys %{ $node_token->{attributes}}) {
          my $attr_t =  $node_token->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $new_element->[0]->set_attribute_node_ns ($attr);
        }
      
        $new_element->[0]->set_user_data (manakai_source_line => $node_token->{line})
            if defined $node_token->{line};
        $new_element->[0]->set_user_data (manakai_source_column => $node_token->{column})
            if defined $node_token->{column};
      
      $new_element->[1] = $node->[1];
      $new_element->[2] = $node_token;
      $self->{active_formatting_elements}->[$node_i_in_active] = $new_element;
      $self->{open_elements}->[$node_i_in_open] = $new_element;
      $node = $new_element;
      
      ## 13.8.
      if ($last_node->[0] eq $furthest_block->[0]) {
        $bookmark_prev_el = $node->[0];
      }
      
      ## 13.9.
      $node->[0]->append_child ($last_node->[0]);
      
      ## 13.10.
      $last_node = $node;

      ## 13.11.
      redo INNER;
    } # INNER

    ## 14.
    if ($common_ancestor_node->[1] & TABLE_ROWS_EL) {
      ## Foster parenting (in AAA).
      my $foster_parent_element;
      my $next_sibling;
      OE: for (reverse 0..$#{$self->{open_elements}}) {
        if ($self->{open_elements}->[$_]->[1] == TABLE_EL) {
          $foster_parent_element = $self->{open_elements}->[$_ - 1]->[0]; # XXX wrong
          $foster_parent_element = $foster_parent_element->content
              if $foster_parent_element->manakai_element_type_match (HTML_NS, 'template');
          $next_sibling = $self->{open_elements}->[$_]->[0];
          undef $next_sibling
              unless $next_sibling->parent_node eq $foster_parent_element;
          last OE;
        } elsif ($self->{open_elements}->[$_]->[1] == TEMPLATE_EL) {
          $foster_parent_element = $self->{open_elements}->[$_]->[0]->content;
          $next_sibling = undef;
          last OE;
        }
      } # OE
      $foster_parent_element ||= $self->{open_elements}->[0]->[0];

      ## $foster_parent_element is the template content if that were
      ## the |template| element.
      $foster_parent_element->insert_before ($last_node->[0], $next_sibling);
    } else {
      $common_ancestor_node->[0]->manakai_append_content ($last_node->[0]);
    }
    
    ## 15.
    my $new_element = [];
    ## XXX intended parent is $furthest_block
    
      $new_element->[0] = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $formatting_element->[2]->{tag_name}]);
    
        for my $attr_name (keys %{ $formatting_element->[2]->{attributes}}) {
          my $attr_t =  $formatting_element->[2]->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $new_element->[0]->set_attribute_node_ns ($attr);
        }
      
        $new_element->[0]->set_user_data (manakai_source_line => $formatting_element->[2]->{line})
            if defined $formatting_element->[2]->{line};
        $new_element->[0]->set_user_data (manakai_source_column => $formatting_element->[2]->{column})
            if defined $formatting_element->[2]->{column};
      
    $new_element->[1] = $formatting_element->[1];
    $new_element->[2] = $formatting_element->[2];
    
    ## 16.
    $new_element->[0]->append_child ($_)
        for $furthest_block->[0]->child_nodes->to_list;
    
    ## 17.
    $furthest_block->[0]->append_child ($new_element->[0]);
    
    ## 18.
    my $i;
    AFE: for (reverse 0..$#{$self->{active_formatting_elements}}) {
      if ($self->{active_formatting_elements}->[$_]->[0] eq $formatting_element->[0]) {
        splice @{$self->{active_formatting_elements}}, $_, 1;
        $i-- and last AFE if defined $i;
      } elsif ($self->{active_formatting_elements}->[$_]->[0] eq $bookmark_prev_el) {
        $i = $_;
      }
    } # AFE
    splice @{$self->{active_formatting_elements}}, $i + 1, 0 => $new_element;
    
    ## 19.
    {
      my $i;
      OE: for (reverse 0..$#{$self->{open_elements}}) {
        if ($self->{open_elements}->[$_]->[0] eq $formatting_element->[0]) {
          splice @{$self->{open_elements}}, $_, 1;
          $i-- and last OE if defined $i;
        } elsif ($self->{open_elements}->[$_]->[0] eq $furthest_block->[0]) {
          $i = $_;
        }
      } # OE
      splice @{$self->{open_elements}}, $i + 1, 0, $new_element;
    }
    
    ## 20.
    redo OUTER;
  } # OUTER
} # _aaa

sub _in_body_any_other_end_tag ($) {
  my ($self) = @_;

  ## The "in body" insertion mode, any other end tag

  ## 1.
  my $node_i = -1;
  my $node = $self->{open_elements}->[$node_i];

  ## 2. Loop
  LOOP: {
    if (not ($node->[1] & FOREIGN_EL) and
        $node->[0]->local_name eq $self->{t}->{tag_name}) {
      ## 2.1. Generate implied end tags
      while ($self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL and
             not (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
                  $self->{open_elements}->[-1]->[0]->local_name eq $self->{t}->{tag_name})) {
        ## NOTE: |<ruby><rt></ruby>|.
        pop @{$self->{open_elements}};
        $node_i++;
      }
      
      ## 2.2.
      unless ($node->[0] eq $self->{open_elements}->[-1]->[0]) {
        ## NOTE: <x><y></x>
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                        text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                        value => $self->{t}->{tag_name}, # actual
                        token => $self->{t});
      }
      
      ## 2.3.
      splice @{$self->{open_elements}}, $node_i if $node_i < 0;

      return;
    } else {
      ## 3.
      if ($node->[1] & SPECIAL_EL or $node->[1] & SCOPING_EL) { ## "Special"
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                        text => $self->{t}->{tag_name},
                        token => $self->{t});
        ## Ignore the token.
        return;

        ## NOTE: |<span><dd></span>a|: In Safari 3.1.2 and Opera 9.27,
        ## "a" is a child of <dd> (conforming).  In Firefox 3.0.2, "a"
        ## is a child of <body>.  In WinIE 7, "a" is a child of both
        ## <body> and <dd>.
      }
    }
    
    ## 4.
    $node_i--;
    $node = $self->{open_elements}->[$node_i];
    
    ## 5.
    redo LOOP;
  } # LOOP
  die;
} # _in_body_any_other_end_tag

  my $reconstruct_active_formatting_elements = sub ($$$$) {
    my ($self, $insert, $active_formatting_elements, $open_tables) = @_;

    ## Step 1
    return unless @$active_formatting_elements;

    ## Step 3
    my $i = -1;
    my $entry = $active_formatting_elements->[$i];

    ## Step 2
    return if $entry->[0] eq '#marker';
    for (@{$self->{open_elements}}) {
      if ($entry->[0] eq $_->[0]) {
        
        return;
      }
    }
    
    S4: {
      ## Step 4
      last S4 if $active_formatting_elements->[0]->[0] eq $entry->[0];

      ## Step 5
      $i--;
      $entry = $active_formatting_elements->[$i];

      ## Step 6
      if ($entry->[0] eq '#marker') {
        
        #
      } else {
        my $in_open_elements;
        OE: for (@{$self->{open_elements}}) {
          if ($entry->[0] eq $_->[0]) {
            
            $in_open_elements = 1;
            last OE;
          }
        }
        if ($in_open_elements) {
          
          #
        } else {
          ## NOTE: <!DOCTYPE HTML><p><b><i><u></p> <p>X
          
          redo S4;
        }
      }

      ## Step 7
      $i++;
      $entry = $active_formatting_elements->[$i];
    } # S4

    S7: {
      ## Step 8
      my $clone = [$entry->[0]->clone_node (0), $entry->[1], $entry->[2]];
    
      ## Step 9
      $insert->($self, $clone->[0], $open_tables);
      push @{$self->{open_elements}}, $clone;
      
      ## Step 10
      $active_formatting_elements->[$i] = $self->{open_elements}->[-1];

      ## Step 11
      unless ($clone->[0] eq $active_formatting_elements->[-1]->[0]) {
        
        ## Step 7'
        $i++;
        $entry = $active_formatting_elements->[$i];
        
        redo S7;
      }

      
    } # S7
  }; # $reconstruct_active_formatting_elements

  my $clear_up_to_marker = sub ($) {
    my $active_formatting_elements = $_[0];
    for (reverse 0..$#$active_formatting_elements) {
      if ($active_formatting_elements->[$_]->[0] eq '#marker') {
        
        splice @$active_formatting_elements, $_;
        return;
      }
    }

    
  }; # $clear_up_to_marker
  my $insert_to_current = sub {
    #my ($self, $child, $open_tables) = @_;
    $_[0]->{open_elements}->[-1]->[0]->manakai_append_content ($_[1]);
  }; # $insert_to_current

  ## Foster parenting.  Note that there are three "foster parenting"
  ## code in the parser: for elements (this one), for texts, and for
  ## elements in the AAA code.
  my $insert_to_foster = sub {
    my ($self, $child, $open_tables) = @_;
    if ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_EL) {
      # MUST
      my $foster_parent_element;
      my $next_sibling;
      OE: for (reverse 0..$#{$self->{open_elements}}) {
        if ($self->{open_elements}->[$_]->[1] == TABLE_EL) {
          
          $foster_parent_element = $self->{open_elements}->[$_ - 1]->[0]; # XXX wrong
          $foster_parent_element = $foster_parent_element->content
              if $foster_parent_element->manakai_element_type_match (HTML_NS, 'template');
          $next_sibling = $self->{open_elements}->[$_]->[0];
          undef $next_sibling
              unless $next_sibling->parent_node eq $foster_parent_element;
          last OE;
        } elsif ($self->{open_elements}->[$_]->[1] == TEMPLATE_EL) {
          $foster_parent_element = $self->{open_elements}->[$_]->[0]->content;
          $next_sibling = undef;
          last OE;
        }
      } # OE
      $foster_parent_element ||= $self->{open_elements}->[0]->[0];

      ## $foster_parent_element is the template content if that were
      ## the |template| element.
      $foster_parent_element->insert_before ($child, $next_sibling);
    } else {
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($child);
    }
  }; # $insert_to_foster


my $template_end_tag = sub {
  my ($self) = @_;

  my $i;
  OE: for (reverse 0..$#{$self->{open_elements}}) {
    if ($self->{open_elements}->[$_]->[1] == TEMPLATE_EL) {
      $i = $_;
      last OE;
    }
  } # OE
  unless (defined $i) {
    $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                    text => 'template',
                    token => $self->{t});
    ## Ignore the token.
    $self->{t} = $self->_get_next_token;
    return;
  }

  ## 1. Generate implied end tags.
  pop @{$self->{open_elements}}
      while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;

  ## 2.
  unless ($self->{open_elements}->[-1]->[1] == TEMPLATE_EL) {
    $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                    text => 'template',
                    token => $self->{t});
  }

  ## 3.
  splice @{$self->{open_elements}}, $i;

  ## 4.
  $clear_up_to_marker->($self->{active_formatting_elements});

  ## 5.
  pop @{$self->{template_ims}};

  ## 6.
  $self->_reset_insertion_mode;

  $self->{t} = $self->_get_next_token;
}; # $template_end_tag

sub _close_p ($;$) {
  my ($self, $imply_start_tag) = @_;

  ## "have a |p| element in button scope"
  my $i;
  INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
    if ($self->{open_elements}->[$_]->[1] == P_EL) {
      $i = $_;
      last INSCOPE;
    } elsif ($self->{open_elements}->[$_]->[1] & BUTTON_SCOPING_EL) {
      last INSCOPE;
    }
  } # INSCOPE
  if (defined $i) {
    ## Close a |p| element
    
    ## 1. Generate implied end tags.
    pop @{$self->{open_elements}}
        while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL and
              $self->{open_elements}->[-1]->[1] != P_EL;
    
    ## 2.
    if ($self->{open_elements}->[-1]->[1] != P_EL) {
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                      text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                      value => $self->{t}->{tag_name}, # actual
                              token => $self->{t});
    }

    ## 3.
    splice @{$self->{open_elements}}, $i;
  } else {
    if ($imply_start_tag) {
      ## The "in body" insertion mode, </p> with no |p| element in
      ## button scope
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                      text => 'p',
                      token => $self->{t});

      my ($insert, $open_tables) = @$imply_start_tag;
      
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'p']);
    
        for my $attr_name (keys %{  +{}}) {
          my $attr_t =   +{}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'p'} || 0];
    }
  
      pop @{$self->{open_elements}}; # <p>
    }
  }
} # _close_p

sub _construct_tree ($) {
  my $self = $_[0];

  ## "List of active formatting elements".  Each item in this array is
  ## an array reference, which contains: [0] - the element node; [1] -
  ## the local name of the element; [2] - the token that is used to
  ## create [0].
  my $active_formatting_elements = $self->{active_formatting_elements} ||= [];

  my $insert = $self->{insert} ||= $insert_to_current;

  ## NOTE: $open_tables->[-1]->[0] is the "current table" element node.
  ## NOTE: $open_tables->[-1]->[1] is unused.
  ## NOTE: $open_tables->[-1]->[2] is set false when non-Text node inserted.
  my $open_tables = $self->{open_tables} ||= [];

  B: while (1) {
    

    if ($self->{t}->{type} == ABORT_TOKEN) {
      return;
    }

    if ($self->{t}->{n}++ == 100) {
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'parser impl error', # XXXtest
                      token => $self->{t});
      require Data::Dumper;
      warn "====== HTML Parser Error ======\n";
      warn join (' ', map { $_->[0]->manakai_local_name } @{$self->{open_elements}}) . ' #' . $self->{insertion_mode} . "\n";
      warn Data::Dumper::Dumper ($self->{t});
      $self->{t} = $self->_get_next_token;
      next B;
    }

    if ($self->{insertion_mode} == INITIAL_IM) {
      if ($self->{t}->{type} == DOCTYPE_TOKEN) {
        ## NOTE: Conformance checkers MAY, instead of reporting "not
        ## HTML5" error, switch to a conformance checking mode for
        ## another language.  (We don't support such mode switchings;
        ## it is nonsense to do anything different from what browsers
        ## do.)
        my $doctype_name = $self->{t}->{name};
        $doctype_name = '' unless defined $doctype_name;
        my $doctype = $self->{document}->create_document_type_definition
            ($doctype_name);
        
        if ($doctype_name ne 'html') {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not HTML5', token => $self->{t});
        } elsif (defined $self->{t}->{pubid}) {
          ## Obsolete permitted DOCTYPEs (case-sensitive)
          my $xsysid = $Web::HTML::ParserData::ObsoletePermittedDoctypes
              ->{$self->{t}->{pubid}};
          if (defined $xsysid and
              ((not defined $self->{t}->{sysid} and
                $self->{t}->{pubid} =~ /HTML 4/) or
               (defined $self->{t}->{sysid} and
                $self->{t}->{sysid} eq $xsysid))) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'obs DOCTYPE', token => $self->{t},
                            level => $self->{level}->{obsconforming});
          } else {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not HTML5', token => $self->{t});
          }
        } elsif (defined $self->{t}->{sysid}) {
          if ($self->{t}->{sysid} eq 'about:legacy-compat') {
            ## <!DOCTYPE HTML SYSTEM "about:legacy-compat">
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'XSLT-compat', token => $self->{t},
                            level => $self->{level}->{should});
          } else {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not HTML5', token => $self->{t});
          }
        } else { ## <!DOCTYPE HTML>
          
          #
        }
        
        ## NOTE: Default value for both |public_id| and |system_id|
        ## attributes are empty strings, so that we don't set any
        ## value in missing cases.
        $doctype->public_id ($self->{t}->{pubid})
            if defined $self->{t}->{pubid};
        $doctype->system_id ($self->{t}->{sysid})
            if defined $self->{t}->{sysid};
        
        ## NOTE: Other DocumentType attributes are null or empty
        ## lists.  In Firefox3, |internalSubset| attribute is set to
        ## the empty string, while |null| is an allowed value for the
        ## attribute according to DOM3 Core.

        $self->{document}->append_child ($doctype);
        
        ## Resetting the quirksness.  Not in the spec, but this has to
        ## be done for reusing Document object (or for
        ## |document.open|).
        $self->{document}->manakai_compat_mode ('no quirks');
        
        unless ($self->{document}->manakai_is_srcdoc) {
          if ($self->{t}->{quirks} or $doctype_name ne 'html') {
            
            $self->{document}->manakai_compat_mode ('quirks');
          } elsif (defined $self->{t}->{pubid}) {
            my $pubid = $self->{t}->{pubid};
            $pubid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
            my $prefix = $Web::HTML::ParserData::QuirkyPublicIDPrefixes;
            my $match;
            for (@$prefix) {
              if (substr ($pubid, 0, length $_) eq $_) {
                $match = 1;
                last;
              }
            }
            if ($match or
                $Web::HTML::ParserData::QuirkyPublicIDs->{$pubid}) {
              
              $self->{document}->manakai_compat_mode ('quirks');
            } elsif ($pubid =~ m[^-//W3C//DTD HTML 4.01 FRAMESET//] or
                     $pubid =~ m[^-//W3C//DTD HTML 4.01 TRANSITIONAL//]) {
              if (not defined $self->{t}->{sysid}) {
                
                $self->{document}->manakai_compat_mode ('quirks');
              } else {
                
                $self->{document}->manakai_compat_mode ('limited quirks');
              }
            } elsif ($pubid =~ m[^-//W3C//DTD XHTML 1.0 FRAMESET//] or
                     $pubid =~ m[^-//W3C//DTD XHTML 1.0 TRANSITIONAL//]) {
              
              $self->{document}->manakai_compat_mode ('limited quirks');
            } else {
              
            }
          } else {
            
          }
          if (defined $self->{t}->{sysid}) {
            my $sysid = $self->{t}->{sysid};
            $sysid =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($sysid eq "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd") {
              ## NOTE: Ensure that |PUBLIC "(limited quirks)"
              ## "(quirks)"| is signaled as in quirks mode!
              $self->{document}->manakai_compat_mode ('quirks');
              
            } else {
              
            }
          } else {
            
          }
        } # not iframe srcdoc
        
        $self->{insertion_mode} = BEFORE_HTML_IM;
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
                START_TAG_TOKEN, 1,
                END_TAG_TOKEN, 1,
                END_OF_FILE_TOKEN, 1,
               }->{$self->{t}->{type}}) {
        unless ($self->{document}->manakai_is_srcdoc) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'no DOCTYPE', token => $self->{t});
          $self->{document}->manakai_compat_mode ('quirks');
        } else {
          
        }
        $self->{insertion_mode} = BEFORE_HTML_IM;
        ## Reprocess the token.
        
        redo B;
      } elsif ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          ## Ignore the token
          
          unless (length $self->{t}->{data}) {
            
            ## Stay in the insertion mode.
            $self->{t} = $self->_get_next_token;
            redo B;
          } else {
            
          }
        } else {
          
        }
        
        unless ($self->{document}->manakai_is_srcdoc) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'no DOCTYPE', token => $self->{t});
          $self->{document}->manakai_compat_mode ('quirks');
        } else {
          
        }
        $self->{insertion_mode} = BEFORE_HTML_IM;
        ## Reprocess the token.
        redo B;
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        
        my $comment = $self->{document}->create_comment
            ($self->{t}->{data});
        $self->{document}->append_child ($comment);
        
        ## Stay in the insertion mode.
        $self->{t} = $self->_get_next_token;
        next B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } elsif ($self->{insertion_mode} == BEFORE_HTML_IM) {
      if ($self->{t}->{type} == DOCTYPE_TOKEN) {
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in html:#DOCTYPE', token => $self->{t});
        ## Ignore the token.
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        
        my $comment = $self->{document}->create_comment
            ($self->{t}->{data});
        $self->{document}->append_child ($comment);
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          ## Ignore the token.
          
          unless (length $self->{t}->{data}) {
            
            $self->{t} = $self->_get_next_token;
            redo B;
          } else {
            
          }
        } else {
          
        }
        
        $self->{application_cache_selection}->(undef);
        
        #
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'html') {
          my $root_element;
          
      $root_element = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{ $self->{t}->{attributes}}) {
          my $attr_t =  $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $root_element->set_attribute_node_ns ($attr);
        }
      
        $root_element->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $root_element->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
          $self->{document}->append_child ($root_element);
          push @{$self->{open_elements}},
              [$root_element, $el_category->{html}];
          
          if ($self->{t}->{attributes}->{manifest}) {
            
            ## XXX resolve URL and drop fragment
            ## <http://html5.org/tools/web-apps-tracker?from=3479&to=3480>
            ## <http://manakai.g.hatena.ne.jp/task/2/95>
            $self->{application_cache_selection}
                 ->($self->{t}->{attributes}->{manifest}->{value});
          } else {
            
            $self->{application_cache_selection}->(undef);
          }
          
          
          
          $self->{t} = $self->_get_next_token;
          $self->{insertion_mode} = BEFORE_HEAD_IM;
          next B;
        } else {
          
          #
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ({
             head => 1, body => 1, html => 1, br => 1,
            }->{$self->{t}->{tag_name}}) {
          
          #
        } else {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        
        #
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
      
      my $root_element;
      
      $root_element = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'html']);
    
        $root_element->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $root_element->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{document}->append_child ($root_element);
      push @{$self->{open_elements}},
          [$root_element, $el_category->{html}];
      push @$open_tables, [[$root_element]];
      
      $self->{application_cache_selection}->(undef);
      
      ## Reprocess the token.
      
      $self->{insertion_mode} = BEFORE_HEAD_IM;
      redo B;
    } # insertion mode

    ## The tree construction dispatcher.
    if (do {
      my $adjusted_current_node ## The adjusted current node
          = (@{$self->{open_elements}} == 1 and
             defined $self->{inner_html_node} and
             ($self->{inner_html_node}->[1] & FOREIGN_EL))
              ? $self->{inner_html_node}
              : @{$self->{open_elements}}
                  ? $self->{open_elements}->[-1] : undef;
      not defined $adjusted_current_node or
      not ($adjusted_current_node->[1] & FOREIGN_EL) or ## HTML element
      ($adjusted_current_node->[1] == MML_TEXT_INTEGRATION_EL and
       (($self->{t}->{type} == START_TAG_TOKEN and
         $self->{t}->{tag_name} ne 'mglyph' and
         $self->{t}->{tag_name} ne 'malignmark') or
        $self->{t}->{type} == CHARACTER_TOKEN)) or
      ($adjusted_current_node->[1] & MML_AXML_EL and
       $self->{t}->{type} == START_TAG_TOKEN and
       $self->{t}->{tag_name} eq 'svg') or
      ( ## If the current node is an HTML integration point (other
        ## than |annotation-xml|).
       $adjusted_current_node->[1] == SVG_INTEGRATION_EL and
       ($self->{t}->{type} == START_TAG_TOKEN or
        $self->{t}->{type} == CHARACTER_TOKEN)) or
      ( ## If the current node is an |annotation-xml| whose |encoding|
        ## is |text/html| or |application/xhtml+xml| (HTML integration
        ## point).
       $adjusted_current_node->[1] == MML_AXML_EL and
       ($self->{t}->{type} == START_TAG_TOKEN or
        $self->{t}->{type} == CHARACTER_TOKEN) and
       do {
         my $encoding = $adjusted_current_node->[0]->get_attribute_ns (undef, 'encoding') || '';
         $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
         if ($encoding eq 'text/html' or 
             $encoding eq 'application/xhtml+xml') {
           1;
         } else {
           0;
         }
       }) or
      ($self->{t}->{type} == END_OF_FILE_TOKEN);
    }) {
      
      ## Use the rules for the current insertion mode in HTML content.
      #
    } else {
      ## Use the rules for the foreign content.

      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        ## "In foreign content", character tokens.
        my $data = $self->{t}->{data};
        while ($data =~ s/\x00/\x{FFFD}/) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'NULL', token => $self->{t});
        }
        $self->{open_elements}->[-1]->[0]->manakai_append_content ($data);
        if ($data =~ /[^\x09\x0A\x0C\x0D\x20]/) {
          delete $self->{frameset_ok};
        }
        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        ## "In foreign content", start tag token.

        if (
          $Web::HTML::ParserData::ForeignContentBreakers->{$self->{t}->{tag_name}} or
          ($self->{t}->{tag_name} eq 'font' and
           ($self->{t}->{attributes}->{color} or
            $self->{t}->{attributes}->{face} or
            $self->{t}->{attributes}->{size}))
        ) {
          ## "In foreign content", HTML-only start tag.
          

          if (defined $self->{inner_html_node}) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'HTML start tag in foreign',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            #
          } else {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                            text => $self->{open_elements}->[-1]->[0]
                                ->manakai_local_name,
                            token => $self->{t});

            pop @{$self->{open_elements}};
            V: {
              my $current_node = $self->{open_elements}->[-1];
              if (
                ## An HTML element.
                not $current_node->[1] & FOREIGN_EL or

                ## An MathML text integration point.
                $current_node->[1] == MML_TEXT_INTEGRATION_EL or

                ## An HTML integration point.
                $current_node->[1] == SVG_INTEGRATION_EL or
                ($current_node->[1] == MML_AXML_EL and
                 do {
                   my $encoding = $current_node->[0]->get_attribute_ns (undef, 'encoding') || '';
                   $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
                   ($encoding eq 'text/html' or
                    $encoding eq 'application/xhtml+xml');
                 })
               ) {
                last V;
              }
              
              pop @{$self->{open_elements}};
              redo V;
            }
            
            ## Reprocess the token.
            next B;
          } # not innerHTML
        } # HTML start tag

        ## "In foreign content", "any other start tag".

        ## The adjusted current node's namespace URL
        my $nsuri = ((@{$self->{open_elements} or []} == 1 and
                      defined $self->{inner_html_node} and
                      $self->{inner_html_node}->[1] & FOREIGN_EL)
            ? $self->{inner_html_node} : $self->{open_elements}->[-1])
                ->[0]->namespace_uri;

        my $tag_name = $self->{t}->{tag_name};
        if ($nsuri eq SVG_NS) {
          $tag_name = $Web::HTML::ParserData::SVGElementNameFixup
              ->{$tag_name} || $tag_name;
        }

        ## "adjust SVG attributes" (SVG only) - done in insert-element-f

        ## "adjust foreign attributes" - done in insert-element-f

        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        ($nsuri, [undef,   $tag_name]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (
          @{
            $foreign_attr_xname->{$attr_name} ||
            [undef, [undef,
                     ($nsuri) eq SVG_NS ?
                         ($svg_attr_name->{$attr_name} || $attr_name) :
                     ($nsuri) eq MML_NS ?
                         ($mml_attr_name->{$attr_name} || $attr_name) :
                         $attr_name]]
          }
        );
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, ($el_category_f->{$nsuri}->{ $tag_name} || 0) | FOREIGN_EL | (($nsuri) eq SVG_NS ? SVG_EL : ($nsuri) eq MML_NS ? MML_EL : 0)];

      if ( $self->{t}->{attributes}->{xmlns} and  $self->{t}->{attributes}->{xmlns}->{value} ne ($nsuri)) {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'bad namespace', token =>  $self->{t});
## TODO: Error type documentation
      }
      if ( $self->{t}->{attributes}->{'xmlns:xlink'} and
           $self->{t}->{attributes}->{'xmlns:xlink'}->{value} ne q<http://www.w3.org/1999/xlink>) {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'bad namespace', token =>  $self->{t});
      }
    }
  

        if ($self->{self_closing}) {
          pop @{$self->{open_elements}}; # XXX Also, if $tag_name is 'script', run script
          delete $self->{self_closing};
        } else {
          
        }

        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        ## "In foreign content", end tag.

        if ($self->{t}->{tag_name} eq 'script' and
            $self->{open_elements}->[-1]->[1] == SVG_SCRIPT_EL) {
          ## "In foreign content", "script" end tag, if the current
          ## node is an SVG |script| element.
          
          pop @{$self->{open_elements}};

          ## XXXscript: Execute script here.
          $self->{t} = $self->_get_next_token;
          next B;

        } else {
          ## "In foreign content", "any other end tag".
          
          
          ## 1.
          my $i = -1;
          my $node = $self->{open_elements}->[$i];
          
          ## 2.
          my $tag_name = $node->[0]->manakai_local_name;
          $tag_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          if ($tag_name ne $self->{t}->{tag_name}) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name}, # $tag_name expected
                            token => $self->{t});
          }

          ## 3.
          LOOP: {
            if (@{$self->{open_elements}} == 1) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{t}->{tag_name},
                              token => $self->{t}); # </html> ## XXX not in spec
              $self->{t} = $self->_get_next_token;
              next B;
            }

            my $tag_name = $node->[0]->manakai_local_name;
            $tag_name =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($tag_name eq $self->{t}->{tag_name}) {
              splice @{$self->{open_elements}}, $i, -$i, ();
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## 4.
            $i--;
            $node = $self->{open_elements}->[$i];

            ## 5.
            if ($node->[1] & FOREIGN_EL) {
              redo LOOP;
            }
          } # LOOP

          ## Step 6 (Use the current insertion mode in HTML content)
          #
        }

      } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
        ## "In foreign content", comment token.
        my $comment = $self->{document}->create_comment ($self->{t}->{data});
        $self->{open_elements}->[-1]->[0]->manakai_append_content ($comment);
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == DOCTYPE_TOKEN) {
        
        ## "In foreign content", DOCTYPE token.
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in html:#DOCTYPE', token => $self->{t});
        ## Ignore the token.
        $self->{t} = $self->_get_next_token;
        next B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";        
      }
    } # foreign

    ## The "in template" insertion mode.
    if ($self->{insertion_mode} == IN_TEMPLATE_IM) {
      if ($self->{t}->{type} == CHARACTER_TOKEN or
          $self->{t}->{type} == COMMENT_TOKEN or
          $self->{t}->{type} == DOCTYPE_TOKEN) {
        #
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ({
          base => 1, basefont => 1, bgsound => 1, link => 1, meta => 1,
          noframes => 1, script => 1, style => 1, template => 1,
          title => 1,
        }->{$self->{t}->{tag_name}}) {
          ## Process the token using the rules for the "in head"
          ## insertion mode.  Since they are processed using the rules
          ## for the "in head" insertion mode in the "in body"
          ## insertion mode, use the "in body" insertion mode
          ## instead...
          #
        } elsif (my $new_mode = {
          caption => IN_TABLE_IM, colgroup => IN_TABLE_IM,
          tbody => IN_TABLE_IM, tfoot => IN_TABLE_IM, thead => IN_TABLE_IM,
          col => IN_COLUMN_GROUP_IM,
          tr => IN_TABLE_BODY_IM,
          td => IN_ROW_IM, th => IN_ROW_IM,
        }->{$self->{t}->{tag_name}}) {
          pop @{$self->{template_ims}};
          push @{$self->{template_ims}},
              $self->{insertion_mode} = $new_mode;
          ## Reprocess the token.
          #
        } else {
          pop @{$self->{template_ims}};
          push @{$self->{template_ims}},
              $self->{insertion_mode} = IN_BODY_IM;
          ## Reprocess the token.
          #
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'template') {
          #
        } else {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          redo B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        my $i;
        OE: for (reverse 0..$#{$self->{open_elements}}) {
          if ($self->{open_elements}->[$_]->[1] == TEMPLATE_EL) {
            $i = $_;
            last OE;
          }
        } # OE
        unless (defined $i) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => 'template',
                          token => $self->{t});
          ## Stop parsing.
          last B;
        }

        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body:#eof', token => $self->{t});
        splice @{$self->{open_elements}}, $i;
        $clear_up_to_marker->($active_formatting_elements);
        pop @{$self->{template_ims}};
        $self->_reset_insertion_mode;
        
        ## Reprocess the token.
        redo B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } # IN_TEMPLATE_IM

    ## The "in table text" insertion mode.
    if ($self->{insertion_mode} & TABLE_IMS and
        not $self->{insertion_mode} & IN_CDATA_RCDATA_IM) {
      C: {
        my $s;
        if ($self->{t}->{type} == CHARACTER_TOKEN) {
          if (($self->{open_elements}->[-1]->[0]->namespace_uri || '') eq HTML_NS and
              {table => 1, tbody => 1, thead => 1, tfoot => 1, tr => 1}->{$self->{open_elements}->[-1]->[0]->local_name}) {
            
            $self->{pending_chars} ||= [];
            push @{$self->{pending_chars}}, $self->{t};
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            ## Will be processed by the "in table" insertion mode's
            ## "in body text" code clone.
            last C;
          }
        } else {
          ## There is an "insert pending chars" code clone.
          if ($self->{pending_chars}) {
            $s = join '', map { $_->{data} } @{$self->{pending_chars}};
            delete $self->{pending_chars};
            while ($s =~ s/\x00//) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'NULL', token => $self->{t});
            }
            if ($s eq '') {
              last C;
            } elsif ($s =~ /[^\x09\x0A\x0C\x0D\x20]/) {
              
              #
            } else {
              
              $self->{open_elements}->[-1]->[0]->manakai_append_content ($s);
              last C;
            }
          } else {
            
            last C;
          }
        }

        ## "in table" insertion mode, "Anything else".

        ## Foster parenting of the character tokens in the pending
        ## table character tokens list.
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table:#text', token => $self->{t});

        ## NOTE: As if in body, but insert into the foster parent element.
        $reconstruct_active_formatting_elements
            ->($self, $insert_to_foster, $active_formatting_elements,
               $open_tables);
            
        if ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_EL) {
          # MUST
          my $foster_parent_element;
          my $next_sibling;
          OE: for (reverse 0..$#{$self->{open_elements}}) {
            if ($self->{open_elements}->[$_]->[1] == TABLE_EL) {
              
              $foster_parent_element = $self->{open_elements}->[$_ - 1]->[0]; # XXX wrong
              $foster_parent_element = $foster_parent_element->content
                  if $foster_parent_element->manakai_element_type_match (HTML_NS, 'template');
              $next_sibling = $self->{open_elements}->[$_]->[0];
              undef $next_sibling
                unless $next_sibling->parent_node eq $foster_parent_element;
              last OE;
            } elsif ($self->{open_elements}->[$_]->[1] == TEMPLATE_EL) {
              $foster_parent_element = $self->{open_elements}->[$_]->[0]->content;
              $next_sibling = undef;
              last OE;
            }
          } # OE
          $foster_parent_element ||= $self->{open_elements}->[0]->[0];

          
          ## $foster_parent_element is the template content if that
          ## were the |template| element.
          $foster_parent_element->insert_before
              ($self->{document}->create_text_node ($s), $next_sibling);

          $open_tables->[-1]->[2] = 1; # ~node inserted
        } else {
          ## NOTE: Fragment case or in a foster parent'ed element
          ## (e.g. |<table><span>a|).  In fragment case, whether the
          ## character is appended to existing node or a new node is
          ## created is irrelevant, since the foster parent'ed nodes
          ## are discarded and fragment parsing does not invoke any
          ## script.
          
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($s);
        }
      } # C

      ## Continue processing...
    } # TABLE_IMS

    if ($self->{t}->{type} == DOCTYPE_TOKEN) {
      
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'in html:#DOCTYPE', token => $self->{t});
      ## Ignore the token
      ## Stay in the phase
      $self->{t} = $self->_get_next_token;
      next B;
    } elsif ($self->{t}->{type} == START_TAG_TOKEN and
             $self->{t}->{tag_name} eq 'html') {
      if ($self->{insertion_mode} == AFTER_HTML_BODY_IM) {
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html', text => 'html', token => $self->{t});
        $self->{insertion_mode} = AFTER_BODY_IM;
      } elsif ($self->{insertion_mode} == AFTER_HTML_FRAMESET_IM) {
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html', text => 'html', token => $self->{t});
        $self->{insertion_mode} = AFTER_FRAMESET_IM;
      } else {
        
      }

      
      $self->{parse_error}->(level => $self->{level}->{must}, type => 'not first start tag', token => $self->{t});
      my $has_template;
      OE: for (reverse @{$self->{open_elements}}) {
        if ($_->[1] == TEMPLATE_EL) {
          $has_template = 1;
          last OE;
        }
      } # OE
      unless ($has_template) {
        my $top_el = $self->{open_elements}->[0]->[0];
        for my $attr_name (keys %{$self->{t}->{attributes}}) {
          unless ($top_el->has_attribute_ns (undef, $attr_name)) {
            
            $top_el->set_attribute_ns
                (undef, [undef, $attr_name], 
                 $self->{t}->{attributes}->{$attr_name}->{value});
          }
        }
      } # $has_template
      
      $self->{t} = $self->_get_next_token;
      next B;
    } elsif ($self->{t}->{type} == COMMENT_TOKEN) {
      my $comment = $self->{document}->create_comment ($self->{t}->{data});
      if ($self->{insertion_mode} & AFTER_HTML_IMS) {
        
        $self->{document}->append_child ($comment);
      } elsif ($self->{insertion_mode} == AFTER_BODY_IM) {
        
        $self->{open_elements}->[0]->[0]->append_child ($comment);
      } else {
        
        $self->{open_elements}->[-1]->[0]->manakai_append_content ($comment);
        $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
      }
      $self->{t} = $self->_get_next_token;
      next B;
    } elsif ($self->{insertion_mode} & IN_CDATA_RCDATA_IM) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        $self->{t}->{data} =~ s/^\x0A// if $self->{ignore_newline};
        delete $self->{ignore_newline};

        if (length $self->{t}->{data}) {
          
          ## NOTE: NULLs are replaced into U+FFFDs in tokenizer.
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{t}->{data});
        } else {
          
        }
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        delete $self->{ignore_newline};

        if ($self->{t}->{tag_name} eq 'script') {
          
          
          ## Para 1-2
          my $script = pop @{$self->{open_elements}};
          
          ## Para 3
          $self->{insertion_mode} &= ~ IN_CDATA_RCDATA_IM;

          ## Para 4
          ## TODO: $old_insertion_point = $current_insertion_point;
          ## TODO: $current_insertion_point = just before $self->{nc};

          ## Para 5
          ## TODO: Run the $script->[0].

          ## Para 6
          ## TODO: $current_insertion_point = $old_insertion_point;

          ## Para 7
          ## TODO: if ($pending_external_script) {
            ## TODO: ...
          ## TODO: }

          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          
 
          pop @{$self->{open_elements}};

          $self->{insertion_mode} &= ~ IN_CDATA_RCDATA_IM;
          $self->{t} = $self->_get_next_token;
          next B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        delete $self->{ignore_newline};

        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                        text => $self->{open_elements}->[-1]->[0]
                            ->manakai_local_name,
                        token => $self->{t});

        #if ($self->{open_elements}->[-1]->[1] == SCRIPT_EL) {
        #  ## TODO: Mark as "already executed"
        #}

        pop @{$self->{open_elements}};

        $self->{insertion_mode} &= ~ IN_CDATA_RCDATA_IM;
        ## Reprocess.
        next B;
      } else {
        die "$0: $self->{t}->{type}: In CDATA/RCDATA: Unknown token type";        
      }
    } # insertion_mode

    if ($self->{insertion_mode} & HEAD_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          unless ($self->{insertion_mode} == BEFORE_HEAD_IM) {
            
            $self->{open_elements}->[-1]->[0]->manakai_append_content ($1);
          } else {
            
            ## Ignore the token.
            #
          }
          unless (length $self->{t}->{data}) {
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
## TODO: set $self->{t}->{column} appropriately
        }

        if ($self->{insertion_mode} == BEFORE_HEAD_IM) {
          
          ## As if <head>
          
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'head']);
    
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
          push @{$self->{open_elements}},
              [$self->{head_element}, $el_category->{head}];

          ## Reprocess in the "in head" insertion mode...
          pop @{$self->{open_elements}};

          ## Reprocess in the "after head" insertion mode...
        } elsif ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
          
          ## As if </noscript>
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript:#text', token => $self->{t});
          pop @{$self->{open_elements}}; # <noscript>
          
          ## Reprocess in the "in head" insertion mode...
          ## As if </head>
          pop @{$self->{open_elements}};

          ## Reprocess in the "after head" insertion mode...
        } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
          
          pop @{$self->{open_elements}};

          ## Reprocess in the "after head" insertion mode...
        } else {
          
        }

        ## "after head" insertion mode
        ## Fake <body> without resetting frameset-ok
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'body']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'body'} || 0];
    }
  
        $self->{insertion_mode} = IN_BODY_IM;
        next B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'head') {
          if ($self->{insertion_mode} == BEFORE_HEAD_IM) {
            
            
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{ $self->{t}->{attributes}}) {
          my $attr_t =  $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $self->{head_element}->set_attribute_node_ns ($attr);
        }
      
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
            $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
            $self->{insertion_mode} = IN_HEAD_IM;
            
            $self->{t} = $self->_get_next_token;
            next B;
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head', text => 'head',
                            token => $self->{t});
            ## Ignore the token
            
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in head:head',
                            token => $self->{t}); # or in head noscript
            ## Ignore the token
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
        } elsif ($self->{insertion_mode} == BEFORE_HEAD_IM) {
          
          ## As if <head>
          
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'head']);
    
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
          push @{$self->{open_elements}},
              [$self->{head_element}, $el_category->{head}];

          $self->{insertion_mode} = IN_HEAD_IM;
          ## Reprocess in the "in head" insertion mode...
        } else {
          
        }

        if ($self->{t}->{tag_name} eq 'base') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            ## As if </noscript>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript', text => 'base',
                            token => $self->{t});
            pop @{$self->{open_elements}}; # <noscript>
          
            $self->{insertion_mode} = IN_HEAD_IM;
            ## Reprocess in the "in head" insertion mode...
          } else {
            
          }

          ## NOTE: There is a "as if in head" code clone.
          if ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          pop @{$self->{open_elements}};
          pop @{$self->{open_elements}} # <head>
              if $self->{insertion_mode} == AFTER_HEAD_IM;
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ({
          link => 1, basefont => 1, bgsound => 1,
        }->{$self->{t}->{tag_name}}) {
          ## NOTE: There is a "as if in head" code clone.
          if ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          pop @{$self->{open_elements}};
          pop @{$self->{open_elements}} # <head>
              if $self->{insertion_mode} == AFTER_HEAD_IM;
          delete $self->{self_closing};
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'meta') {
          ## NOTE: There is a "as if in head" code clone.
          if ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          my $meta_el = pop @{$self->{open_elements}};

              unless ($self->{confident}) {
                if ($self->{t}->{attributes}->{charset}) {
                  
                  ## NOTE: Whether the encoding is supported or not,
                  ## an ASCII-compatible charset is not, is handled in
                  ## the |_change_encoding| method.
                  if ($self->_change_encoding
                          ($self->{t}->{attributes}->{charset}->{value},
                           $self->{t})) {
                    return {type => ABORT_TOKEN};
                  }
                  
                  $meta_el->[0]->get_attribute_node_ns (undef, 'charset')
                      ->set_user_data (manakai_has_reference =>
                                           $self->{t}->{attributes}->{charset}
                                               ->{has_reference});
                } elsif ($self->{t}->{attributes}->{content} and
                         $self->{t}->{attributes}->{'http-equiv'}) {
                  if ($self->{t}->{attributes}->{'http-equiv'}->{value}
                      =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
                      $self->{t}->{attributes}->{content}->{value}
                      =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                          [\x09\x0A\x0C\x0D\x20]*=
                          [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                          ([^"'\x09\x0A\x0C\x0D\x20]
                           [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
                    
                    ## NOTE: Whether the encoding is supported or not,
                    ## an ASCII-compatible charset is not, is handled
                    ## in the |_change_encoding| method.
                    if ($self->_change_encoding
                            (defined $1 ? $1 : defined $2 ? $2 : $3,
                             $self->{t})) {
                      return {type => ABORT_TOKEN};
                    }
                    $meta_el->[0]->get_attribute_node_ns (undef, 'content')
                        ->set_user_data (manakai_has_reference =>
                                             $self->{t}->{attributes}->{content}
                                                   ->{has_reference});
                  } else {
                    
                  }
                }
              } else {
                if ($self->{t}->{attributes}->{charset}) {
                  
                  $meta_el->[0]->get_attribute_node_ns (undef, 'charset')
                      ->set_user_data (manakai_has_reference =>
                                           $self->{t}->{attributes}->{charset}
                                               ->{has_reference});
                }
                if ($self->{t}->{attributes}->{content}) {
                  
                  $meta_el->[0]->get_attribute_node_ns (undef, 'content')
                      ->set_user_data (manakai_has_reference =>
                                           $self->{t}->{attributes}->{content}
                                               ->{has_reference});
                }
              }

              pop @{$self->{open_elements}} # <head>
                  if $self->{insertion_mode} == AFTER_HEAD_IM;
              delete $self->{self_closing};
              $self->{t} = $self->_get_next_token;
              next B;
        } elsif ($self->{t}->{tag_name} eq 'title') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            ## As if </noscript>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript', text => 'title',
                            token => $self->{t});
            pop @{$self->{open_elements}}; # <noscript>
          
            $self->{insertion_mode} = IN_HEAD_IM;
            ## Reprocess in the "in head" insertion mode...
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }

          ## NOTE: There is a "as if in head" code clone.
          $parse_rcdata->($self, $insert, $open_tables, 1); # RCDATA

          ## NOTE: At this point the stack of open elements contain
          ## the |head| element (index == -2) and the |script| element
          ## (index == -1).  In the "after head" insertion mode the
          ## |head| element is inserted only for the purpose of
          ## providing the context for the |script| element, and
          ## therefore we can now and have to remove the element from
          ## the stack.
          splice @{$self->{open_elements}}, -2, 1, () # <head>
              if ($self->{insertion_mode} & IM_MASK) == AFTER_HEAD_IM;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'style' or
                 $self->{t}->{tag_name} eq 'noframes') {
          ## NOTE: Or (scripting is enabled and tag_name eq 'noscript' and
          ## insertion mode IN_HEAD_IM)
          ## NOTE: There is a "as if in head" code clone.
          if ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }
          $parse_rcdata->($self, $insert, $open_tables, 0); # RAWTEXT
          splice @{$self->{open_elements}}, -2, 1, () # <head>
              if ($self->{insertion_mode} & IM_MASK) == AFTER_HEAD_IM;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'noscript') {
              if ($self->{insertion_mode} == IN_HEAD_IM) {
                
                ## NOTE: and scripting is disalbed
                
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
                $self->{insertion_mode} = IN_HEAD_NOSCRIPT_IM;
                
                $self->{t} = $self->_get_next_token;
                next B;
              } elsif ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript', text => 'noscript',
                                token => $self->{t});
                ## Ignore the token
                
                $self->{t} = $self->_get_next_token;
                next B;
              } else {
                
                #
              }
        } elsif ($self->{t}->{tag_name} eq 'script') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            ## As if </noscript>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript', text => 'script',
                            token => $self->{t});
            pop @{$self->{open_elements}}; # <noscript>
          
            $self->{insertion_mode} = IN_HEAD_IM;
            ## Reprocess in the "in head" insertion mode...
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
          } else {
            
          }

          ## NOTE: There is a "as if in head" code clone.
          $script_start_tag->($self, $insert, $open_tables);
          splice @{$self->{open_elements}}, -2, 1 # <head>
              if ($self->{insertion_mode} & IM_MASK) == AFTER_HEAD_IM;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            ## The "in head noscript" insertion mode, anything else
            ## (<template>)

            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript', text => 'script',
                            token => $self->{t});
            pop @{$self->{open_elements}}; # <noscript>
          
            $self->{insertion_mode} = IN_HEAD_IM;
            ## Reprocess in the "in head" insertion mode...
            #
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            ## The "after head" insertion mode, <template>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after head',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];
            ## Process the token using the rules for the "in head"
            ## insertion mode.
            #
          }

          ## The "in head" insertion mode, <template>

          ## This is a variant of "template start tag" code clone.
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          push @$active_formatting_elements, ['#marker', '', undef];
          delete $self->{frameset_ok}; # not ok

          splice @{$self->{open_elements}}, -2, 1 # <head>
              if ($self->{insertion_mode} & IM_MASK) == AFTER_HEAD_IM;

          push @{$self->{template_ims}},
              $self->{insertion_mode} = IN_TEMPLATE_IM;

          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'body' or
                 $self->{t}->{tag_name} eq 'frameset') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            ## As if </noscript>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            pop @{$self->{open_elements}}; # <noscript>
            
            ## Reprocess in the "in head" insertion mode...
            ## As if </head>
            pop @{$self->{open_elements}};
            
            ## Reprocess in the "after head" insertion mode...
          } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
            
            pop @{$self->{open_elements}};
            
            ## Reprocess in the "after head" insertion mode...
          } else {
            
          }

          ## "after head" insertion mode
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          if ($self->{t}->{tag_name} eq 'body') {
            
            delete $self->{frameset_ok};
            $self->{insertion_mode} = IN_BODY_IM;
          } elsif ($self->{t}->{tag_name} eq 'frameset') {
            
            $self->{insertion_mode} = IN_FRAMESET_IM;
          } else {
            die "$0: tag name: $self->{tag_name}";
          }
          
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          
          #
        }

        if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
          
          ## As if </noscript>
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript:/',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          pop @{$self->{open_elements}}; # <noscript>
          
              ## Reprocess in the "in head" insertion mode...
              ## As if </head>
              pop @{$self->{open_elements}};

              ## Reprocess in the "after head" insertion mode...
            } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
              
              ## As if </head>
              pop @{$self->{open_elements}};

              ## Reprocess in the "after head" insertion mode...
            } else {
              
            }

        ## "after head" insertion mode
        ## Fake <body> without resetting frameset-ok
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'body']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'body'} || 0];
    }
  
        $self->{insertion_mode} = IN_BODY_IM;
        
        next B;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        ## "Before head", "in head", and "after head" insertion modes
        ## ignore most of end tags.  Exceptions are "body", "html",
        ## and "br" end tags.  "Before head" and "in head" insertion
        ## modes also recognize "head" end tag.  "In head noscript"
        ## insertion modes ignore end tags except for "noscript" and
        ## "br".

        if ($self->{t}->{tag_name} eq 'head') {
          if ($self->{insertion_mode} == BEFORE_HEAD_IM) {
            
            ## As if <head>
            
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'head']);
    
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
            $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
            push @{$self->{open_elements}},
                [$self->{head_element}, $el_category->{head}];

            ## Reprocess in the "in head" insertion mode...
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = AFTER_HEAD_IM;
            $self->{t} = $self->_get_next_token;
            next B;
          } elsif ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            #
          } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
            
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = AFTER_HEAD_IM;
            $self->{t} = $self->_get_next_token;
            next B;
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            #
          } else {
            die "$0: $self->{insertion_mode}: Unknown insertion mode";
          }
        } elsif ($self->{t}->{tag_name} eq 'noscript') {
          if ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = IN_HEAD_IM;
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            
            #
          }
        } elsif ({
            body => ($self->{insertion_mode} != IN_HEAD_NOSCRIPT_IM),
            html => ($self->{insertion_mode} != IN_HEAD_NOSCRIPT_IM),
            br => 1,
        }->{$self->{t}->{tag_name}}) {
          if ($self->{insertion_mode} == BEFORE_HEAD_IM) {
            
            ## (before head) as if <head>, (in head) as if </head>
            
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'head']);
    
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
            $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
            $self->{insertion_mode} = AFTER_HEAD_IM;
  
            ## Reprocess in the "after head" insertion mode...
          } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
            
            ## As if </head>
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = AFTER_HEAD_IM;
  
            ## Reprocess in the "after head" insertion mode...
          } elsif ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            
            ## NOTE: Two parse errors for <head><noscript></br>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});

            ## As if </noscript>
            $self->{insertion_mode} = IN_HEAD_IM;
            pop @{$self->{open_elements}}; # <noscript>

            ## Reprocess in the "in head" insertion mode...
            ## As if </head>
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = AFTER_HEAD_IM;

            ## Reprocess in the "after head" insertion mode...
          } elsif ($self->{insertion_mode} == AFTER_HEAD_IM) {
            
            #
          } else {
            die "$0: $self->{insertion_mode}: Unknown insertion mode";
          }

          ## "after head" insertion mode
          ## Fake <body> without resetting frameset-ok
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'body']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'body'} || 0];
    }
  
          $self->{insertion_mode} = IN_BODY_IM;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          ## In head insertion modes, </template>
          if ($self->{insertion_mode} == IN_HEAD_IM or
              $self->{insertion_mode} == AFTER_HEAD_IM) {
            $template_end_tag->($self);
            next B;
          } elsif ($self->{insertion_mode} == BEFORE_HEAD_IM or
                   $self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
            #
          } else {
            die "$0: $self->{insertion_mode}: Unknown insertion mode";
          }
        } # tag name

        ## End tags are ignored by default.
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                        text => $self->{t}->{tag_name}, token => $self->{t});
        ## Ignore the token.
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        if ($self->{insertion_mode} == BEFORE_HEAD_IM) {
          

          ## NOTE: As if <head>
          
      $self->{head_element} = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'head']);
    
        $self->{head_element}->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $self->{head_element}->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{head_element});
          #push @{$self->{open_elements}},
          #    [$self->{head_element}, $el_category->{head}];
          #$self->{insertion_mode} = IN_HEAD_IM;
          ## NOTE: Reprocess.

          ## NOTE: As if </head>
          #pop @{$self->{open_elements}};
          #$self->{insertion_mode} = IN_AFTER_HEAD_IM;
          ## NOTE: Reprocess.
          
          #
        } elsif ($self->{insertion_mode} == IN_HEAD_IM) {
          

          ## NOTE: As if </head>
          pop @{$self->{open_elements}};
          #$self->{insertion_mode} = IN_AFTER_HEAD_IM;
          ## NOTE: Reprocess.

          #
        } elsif ($self->{insertion_mode} == IN_HEAD_NOSCRIPT_IM) {
          

          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in noscript:#eof', token => $self->{t});

          ## As if </noscript>
          pop @{$self->{open_elements}};
          #$self->{insertion_mode} = IN_HEAD_IM;
          ## NOTE: Reprocess.

          ## NOTE: As if </head>
          pop @{$self->{open_elements}};
          #$self->{insertion_mode} = IN_AFTER_HEAD_IM;
          ## NOTE: Reprocess.

          #
        } else {
          
          #
        }

        ## Fake <body> without resetting frameset-ok
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'body']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'body'} || 0];
    }
  
        $self->{insertion_mode} = IN_BODY_IM;
        next B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }

    } elsif ($self->{insertion_mode} & BODY_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        ## "In body" insertion mode, character token.  It is also used
        ## for character tokens "in foreign content" for certain
        ## cases.  This is an "in body text" code clone.

        while ($self->{t}->{data} =~ s/\x00//g) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'NULL', token => $self->{t});
        }
        if ($self->{t}->{data} eq '') {
          $self->{t} = $self->_get_next_token;
          next B;
        }

        
        $reconstruct_active_formatting_elements
            ->($self, $insert_to_current, $active_formatting_elements,
               $open_tables);
        
        $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{t}->{data});

        if ($self->{frameset_ok} and
            $self->{t}->{data} =~ /[^\x09\x0A\x0C\x0D\x20]/) {
          delete $self->{frameset_ok};
        }

        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ({
          caption => 1, col => 1, colgroup => 1, tbody => 1,
          td => 1, tfoot => 1, th => 1, thead => 1, tr => 1,
        }->{$self->{t}->{tag_name}}) {
          if (($self->{insertion_mode} & IM_MASK) == IN_CELL_IM) {
            ## The "in cell" insertion mode, start tag of table
            ## elements.

            ## have a |td| or |th| element in table scope
            my $i;
            OE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_CELL_EL) {
                $i = $_;
                last OE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last OE;
              }
            } # OE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'in cell',
                              value => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              
              $self->{t} = $self->_get_next_token;
              next B;
            }

            ## Close the cell (There are two similar but different
            ## "close the cell" implementations).

            ## 1.
            pop @{$self->{open_elements}}
                while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;

            ## 2.
            unless ($self->{open_elements}->[-1]->[1] == TABLE_CELL_EL) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                              text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                              value => $self->{t}->{tag_name}, # actual
                              token => $self->{t});
            }

            ## 3.
            splice @{$self->{open_elements}}, $i;

            ## 4.
            $clear_up_to_marker->($active_formatting_elements);

            ## 5.
            $self->{insertion_mode} = IN_ROW_IM;

            ## Reprocess the token.
            next B;

          } elsif (($self->{insertion_mode} & IM_MASK) == IN_CAPTION_IM) {
            ## The "in caption" insertion mode, <caption> <col>
            ## <colgroup> <tbody> <td> <tfoot> <th> <thead> <tr>
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed', text => 'caption',
                            token => $self->{t});
            
            ## have a |caption| element in table scope
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == CAPTION_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              ## Ignore the token.
              
              $self->{t} = $self->_get_next_token;
              redo B;
            }

            splice @{$self->{open_elements}}, $i;
            
            $clear_up_to_marker->($active_formatting_elements);
            
            $self->{insertion_mode} = IN_TABLE_IM;
            
            ## Reprocess the token.
            
            next B;
          } else {
            
            #
          }
        } else {
          
          #
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'td' or
            $self->{t}->{tag_name} eq 'th') {
          if (($self->{insertion_mode} & IM_MASK) == IN_CELL_IM) {
            ## The "in cell" insertion mode, </td> </th>
            
            ## have an element in table scope
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if (not ($self->{open_elements}->[$_]->[1] & FOREIGN_EL) and
                  $self->{open_elements}->[$_]->[0]->local_name eq $self->{t}->{tag_name}) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## Generate implied end tags.
            pop @{$self->{open_elements}}
                while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;

            unless (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
                    $self->{open_elements}->[-1]->[0]->local_name eq $self->{t}->{tag_name}) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                              text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                              value => $self->{t}->{tag_name}, # actual
                              token => $self->{t});
            }
            
            splice @{$self->{open_elements}}, $i;
            
            $clear_up_to_marker->($active_formatting_elements);
            
            $self->{insertion_mode} = IN_ROW_IM;
            
            $self->{t} = $self->_get_next_token;
            next B;
          } elsif (($self->{insertion_mode} & IM_MASK) == IN_CAPTION_IM) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                text => $self->{t}->{tag_name}, token => $self->{t});
                ## Ignore the token
                $self->{t} = $self->_get_next_token;
                next B;
              } else {
                
                #
              }
            } elsif ($self->{t}->{tag_name} eq 'caption') {
              if (($self->{insertion_mode} & IM_MASK) == IN_CAPTION_IM) {
                ## have a table element in table scope
                my $i;
                INSCOPE: {
                  for (reverse 0..$#{$self->{open_elements}}) {
                    my $node = $self->{open_elements}->[$_];
                    if ($node->[1] == CAPTION_EL) {
                      
                      $i = $_;
                      last INSCOPE;
                    } elsif ($node->[1] & TABLE_SCOPING_EL) {
                      
                      last;
                    }
                  }

                  
                  $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                  text => $self->{t}->{tag_name}, token => $self->{t});
                  ## Ignore the token
                  $self->{t} = $self->_get_next_token;
                  next B;
                } # INSCOPE
                
                ## generate implied end tags
                while ($self->{open_elements}->[-1]->[1]
                           & END_TAG_OPTIONAL_EL) {
                  
                  pop @{$self->{open_elements}};
                }
                
                unless ($self->{open_elements}->[-1]->[1] == CAPTION_EL) {
                  
                  $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                                  text => $self->{open_elements}->[-1]->[0]
                                      ->manakai_local_name,
                                  token => $self->{t});
                } else {
                  
                }
                
                splice @{$self->{open_elements}}, $i;
                
                $clear_up_to_marker->($active_formatting_elements);
                
                $self->{insertion_mode} = IN_TABLE_IM;
                
                $self->{t} = $self->_get_next_token;
                next B;
              } elsif (($self->{insertion_mode} & IM_MASK) == IN_CELL_IM) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                text => $self->{t}->{tag_name}, token => $self->{t});
                ## Ignore the token
                $self->{t} = $self->_get_next_token;
                next B;
              } else {
                
                #
              }
        } elsif (($self->{insertion_mode} & IM_MASK) == IN_CELL_IM and {
          table => 1, tbody => 1, tfoot => 1, thead => 1, tr => 1,
        }->{$self->{t}->{tag_name}}) {
          ## The "in cell" insertion mode, table end tags.

          ## have an element in table scope
          my $i;
          OE: for (reverse 0..$#{$self->{open_elements}}) {
            if (not ($self->{open_elements}->[$_]->[1] & FOREIGN_EL) and
                $self->{open_elements}->[$_]->[0]->local_name eq $self->{t}->{tag_name}) {
              $i = $_;
              last OE;
            } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
              last OE;
            }
          } # OE
          unless (defined $i) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'stray end tag',
                            value => $self->{t}->{tag_name},
                            token => $self->{t});
            ## Ignore the token.
            $self->{t} = $self->_get_next_token;
            next B;
          }

          ## Close the cell (There are two similar but different
          ## "close the cell" implementations).

          ## 1.
          pop @{$self->{open_elements}}
              while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;

          ## 2.
          unless ($self->{open_elements}->[-1]->[1] == TABLE_CELL_EL) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                            text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                            value => $self->{t}->{tag_name}, # actual
                            token => $self->{t});
          }

          ## 3.
          pop @{$self->{open_elements}}
              while $self->{open_elements}->[-1]->[1] != TABLE_CELL_EL;
          pop @{$self->{open_elements}}; # <td> or <th>

          ## 4.
          $clear_up_to_marker->($active_formatting_elements);

          ## 5.
          $self->{insertion_mode} = IN_ROW_IM;

          ## Reprocess the token.
          next B;
        } elsif ($self->{t}->{tag_name} eq 'table' and
                 ($self->{insertion_mode} & IM_MASK) == IN_CAPTION_IM) {
          ## The "in caption" insertion mode, </table>
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed', text => 'caption',
                          token => $self->{t});

          ## have a |caption| element in table scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            if ($self->{open_elements}->[$_]->[1] == CAPTION_EL) {
              $i = $_;
              last INSCOPE;
            } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            
            ## Ignore the token.
            $self->{t} = $self->_get_next_token;
            next B;
          }
          
          splice @{$self->{open_elements}}, $i;

          $clear_up_to_marker->($active_formatting_elements);

          $self->{insertion_mode} = IN_TABLE_IM;

          ## Reprocess the token.
          next B;
        } elsif ({
          body => 1, col => 1, colgroup => 1, html => 1,
        }->{$self->{t}->{tag_name}}) {
              if ($self->{insertion_mode} & BODY_TABLE_IMS) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                text => $self->{t}->{tag_name}, token => $self->{t});
                ## Ignore the token
                $self->{t} = $self->_get_next_token;
                next B;
              } else {
                
                #
              }
        } elsif ({
                  tbody => 1, tfoot => 1,
                  thead => 1, tr => 1,
                 }->{$self->{t}->{tag_name}} and
                 ($self->{insertion_mode} & IM_MASK) == IN_CAPTION_IM) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          ## Ignore the token
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          
          #
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        for my $entry (@{$self->{open_elements}}) {
          unless ($entry->[1] & ALL_END_TAG_OPTIONAL_EL) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body:#eof', token => $self->{t});
            last;
          }
        }

        if (@{$self->{template_ims}}) {
          ## Process the token using the rules for the "in template"
          ## insertion mode.
          $self->{insertion_mode} = IN_TEMPLATE_IM;
          next B;
        } else {
          ## Stop parsing.
          last B;
        }
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }

      $self->{insert} = $insert = $insert_to_current;
      #
    } elsif ($self->{insertion_mode} & TABLE_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        ## A character token, if the current node is /not/ |table|,
        ## |tbody|, |tfoot|, |thead|, or |tr| element.  (If the
        ## current node is one of these elements, the token is already
        ## handled by the code for the "in table text" insertion mode
        ## above.)

        ## In the spec, the token is handled by the "anything else"
        ## entry in the "in table" insertion mode.

        ## "In body" insertion mode, character token.  It is also used
        ## for character tokens "in foreign content" for certain
        ## cases.

        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table:#text', token => $self->{t});
        ## Strictly speaking, this parse error must be reported for
        ## each character per the spec.  In the current implementation
        ## the number of the parse error here depends on how the
        ## tokenizer emits character*s* tokens, which is not good...

        ## Process the token using the rules for the "in body"
        ## insertion mode.  This is an "in body text" code clone,
        ## except for the line marked by "FOSTER".
        {
          while ($self->{t}->{data} =~ s/\x00//g) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'NULL', token => $self->{t});
          }
          if ($self->{t}->{data} eq '') {
            $self->{t} = $self->_get_next_token;
            next B;
          }

          $reconstruct_active_formatting_elements
              ->($self, $insert_to_foster, # FOSTER
                 $active_formatting_elements, $open_tables);
          
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($self->{t}->{data});

          if ($self->{frameset_ok} and
              $self->{t}->{data} =~ /[^\x09\x0A\x0C\x0D\x20]/) {
            delete $self->{frameset_ok};
          }

          $self->{t} = $self->_get_next_token;
          next B;
        } # "in body text" code clone
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ({
          tr => (($self->{insertion_mode} & IM_MASK) != IN_ROW_IM),
          th => 1, td => 1,
        }->{$self->{t}->{tag_name}}) {
          if (($self->{insertion_mode} & IM_MASK) == IN_TABLE_IM) {
            ## The "in table" insertion mode, <tr><td><th>

            ## Clear back to table context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_SCOPING_EL);
            
            
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'tbody']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'tbody'} || 0];
    }
  
            $self->{insertion_mode} = IN_TABLE_BODY_IM;
            ## Reprocess the token...
            #
          }
          
          if (($self->{insertion_mode} & IM_MASK) == IN_TABLE_BODY_IM) {
            ## The "in table body" insertion mode, <tr><th><td>
            unless ($self->{t}->{tag_name} eq 'tr') {
              
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'missing start tag:tr',
                              token => $self->{t});
            }
            
            ## Clear back to table body context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_SCOPING_EL);
            
            if ($self->{t}->{tag_name} eq 'tr') {
              
              
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
              $self->{insertion_mode} = IN_ROW_IM;
              $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
              
              $self->{t} = $self->_get_next_token;
              next B;
            } else {
              
              
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'tr']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'tr'} || 0];
    }
  
              $self->{insertion_mode} = IN_ROW_IM;
              ## Reprocess the token...
              #
            }
          } else {
            
          }

              ## Clear back to table row context
              while (not ($self->{open_elements}->[-1]->[1]
                              & TABLE_ROW_SCOPING_EL)) {
                
                pop @{$self->{open_elements}};
              }
              
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
          $self->{insertion_mode} = IN_CELL_IM;

          push @$active_formatting_elements, ['#marker', '', undef];
          
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ({
          caption => 1, col => 1, colgroup => 1,
          tbody => 1, tfoot => 1, thead => 1,
          tr => 1, # $self->{insertion_mode} == IN_ROW_IM
        }->{$self->{t}->{tag_name}}) {
          if (($self->{insertion_mode} & IM_MASK) == IN_ROW_IM) {
            ## The "in row" insertion mode, <caption> <col> <colgroup>
            ## <tbody> <tfoot> <thead> <tr>

            ## have a |tr| element in table scope.
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_ROW_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'in tr', # XXX
                              value => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## Clear back to a table row context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROW_SCOPING_EL);
            
            pop @{$self->{open_elements}}; # <tr>
            $self->{insertion_mode} = IN_TABLE_BODY_IM;
            if ($self->{t}->{tag_name} eq 'tr') {
              ## Reprocess the token.
              
              next B;
            } else {
              ## Reprocess the token...
              #
            }
          } # in row

          if (($self->{insertion_mode} & IM_MASK) == IN_TABLE_BODY_IM) {
            ## The "in table body" insertion mode, <caption> <col>
            ## <colgroup> <tbody> <tfoot> <thead>

            ## have a |tbody|, |thead|, |tfoot| element in table scope
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_ROW_GROUP_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table body', # XXXdoc
                              value => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token.
              
              $self->{t} = $self->_get_next_token;
              next B;
            }

            ## Clear back to a table body context.
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_SCOPING_EL);
            
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = IN_TABLE_IM;
            ## Reprocess the token...
            #
          } # in table body

          if ($self->{t}->{tag_name} eq 'col') {
            ## Clear back to table context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_SCOPING_EL);

            
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'colgroup']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{'colgroup'} || 0];
    }
  
            $self->{insertion_mode} = IN_COLUMN_GROUP_IM;
            ## Reprocess the token.
            $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
            
            next B;
          } elsif ({
                    caption => 1,
                    colgroup => 1,
                    tbody => 1, tfoot => 1, thead => 1,
                   }->{$self->{t}->{tag_name}}) {
            ## Clear back to table context
            while (not ($self->{open_elements}->[-1]->[1]
                        & TABLE_SCOPING_EL)) {
              
              ## ISSUE: Can this state be reached?
              pop @{$self->{open_elements}};
            }
            
            push @$active_formatting_elements, ['#marker', '', undef]
                if $self->{t}->{tag_name} eq 'caption';
            
            
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
            $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
            $self->{insertion_mode} = {
                                       caption => IN_CAPTION_IM,
                                       colgroup => IN_COLUMN_GROUP_IM,
                                       tbody => IN_TABLE_BODY_IM,
                                       tfoot => IN_TABLE_BODY_IM,
                                       thead => IN_TABLE_BODY_IM,
                                      }->{$self->{t}->{tag_name}};
            $self->{t} = $self->_get_next_token;
            
            next B;
          } else {
            die "$0: in table: <>: $self->{t}->{tag_name}";
          }
        } elsif ($self->{t}->{tag_name} eq 'table') {
          ## The "in table" insertion mode, <table>
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                          text => $self->{open_elements}->[-1]->[0]->local_name,
                          token => $self->{t});

          ## have a |table| element in table scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            my $node = $self->{open_elements}->[$_];
            if ($node->[1] == TABLE_EL) {
              
              $i = $_;
              last INSCOPE;
            } elsif ($node->[1] & TABLE_SCOPING_EL) {
              
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            ## Ignore the token.
            
            $self->{t} = $self->_get_next_token;
            next B;
          }

          splice @{$self->{open_elements}}, $i;
          pop @{$open_tables};

          $self->_reset_insertion_mode;

          ## Reprocess the token.
          
          next B;
        } elsif ($self->{t}->{tag_name} eq 'style') {
          
          ## NOTE: This is a "as if in head" code clone.
          $parse_rcdata->($self, $insert, $open_tables, 0); # RAWTEXT
          $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
          next B;
        } elsif ($self->{t}->{tag_name} eq 'script') {
          
          ## NOTE: This is a "as if in head" code clone.
          $script_start_tag->($self, $insert, $open_tables);
          $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          ## This is a "template start tag" code clone.
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          push @$active_formatting_elements, ['#marker', '', undef];
          delete $self->{frameset_ok}; # not ok
          push @{$self->{template_ims}},
              $self->{insertion_mode} = IN_TEMPLATE_IM;
          $self->{t} = $self->_get_next_token;

          $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted
          next B;
        } elsif ($self->{t}->{tag_name} eq 'input') {
          ## The "in table" insertion mode, <input>
          if ($self->{t}->{attributes}->{type}) {
            my $type = $self->{t}->{attributes}->{type}->{value};
            $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($type eq 'hidden') {
              ## <input type=hidden> in table
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table',
                              text => $self->{t}->{tag_name},
                              token => $self->{t});

              
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
              $open_tables->[-1]->[2] = 0 if @$open_tables; # ~node inserted

              ## TODO: form element pointer

              pop @{$self->{open_elements}}; # <input type=hidden>

              delete $self->{self_closing};
              $self->{t} = $self->_get_next_token;
              next B;
            } else {
              
              #
            }
          } else {
            
            #
          }
        } elsif ($self->{t}->{tag_name} eq 'form') {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'form in table', token => $self->{t}); # XXX documentation
          
          if ($self->{form_element}) {
            ## Ignore the token.
            $self->{t} = $self->_get_next_token;
            
            next B;
          } else {
            
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
            $self->{form_element} = $self->{open_elements}->[-1]->[0];
            
            pop @{$self->{open_elements}};
            
            $self->{t} = $self->_get_next_token;
            
            next B;
          }
        } else {
          
          #
        }

        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table', text => $self->{t}->{tag_name},
                        token => $self->{t});

        $self->{insert} = $insert = $insert_to_foster;
        #
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'tr' and
            ($self->{insertion_mode} & IM_MASK) == IN_ROW_IM) {
          ## have an element in table scope
              my $i;
              INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
                my $node = $self->{open_elements}->[$_];
                if ($node->[1] == TABLE_ROW_EL) {
                  
                  $i = $_;
                  last INSCOPE;
                } elsif ($node->[1] & TABLE_SCOPING_EL) {
                  
                  last INSCOPE;
                }
              } # INSCOPE
              unless (defined $i) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                text => $self->{t}->{tag_name}, token => $self->{t});
                ## Ignore the token
                
                $self->{t} = $self->_get_next_token;
                next B;
              } else {
                
              }

              ## Clear back to table row context
              while (not ($self->{open_elements}->[-1]->[1]
                              & TABLE_ROW_SCOPING_EL)) {
                
## ISSUE: Can this state be reached?
                pop @{$self->{open_elements}};
              }

              pop @{$self->{open_elements}}; # tr
              $self->{insertion_mode} = IN_TABLE_BODY_IM;
              $self->{t} = $self->_get_next_token;
              
              next B;
        } elsif ($self->{t}->{tag_name} eq 'table') {
          if (($self->{insertion_mode} & IM_MASK) == IN_ROW_IM) {
            ## The "in row" insertion mode, </table>

            ## have a |tr| element in table scope.
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_ROW_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## Clear back to a table row context.
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROW_SCOPING_EL);
            
            pop @{$self->{open_elements}}; # <tr>
            $self->{insertion_mode} = IN_TABLE_BODY_IM;
            ## Reprocess the token...
            #
          } # in row

          if (($self->{insertion_mode} & IM_MASK) == IN_TABLE_BODY_IM) {
            ## The "in table body" insertion mode, </table>

            ## have a |tbody|, |thead|, |tfoot| element in table scope.
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_ROW_GROUP_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## Clear back to table body context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_SCOPING_EL);
            
            pop @{$self->{open_elements}};
            $self->{insertion_mode} = IN_TABLE_IM;
            ## Reprocess the token...
            #
          } # in table body

              ## NOTE: </table> in the "in table" insertion mode.
              ## When you edit the code fragment below, please ensure that
              ## the code for <table> in the "in table" insertion mode
              ## is synced with it.

              ## have a table element in table scope
              my $i;
              INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
                my $node = $self->{open_elements}->[$_];
                if ($node->[1] == TABLE_EL) {
                  
                  $i = $_;
                  last INSCOPE;
                } elsif ($node->[1] & TABLE_SCOPING_EL) {
                  
                  last INSCOPE;
                }
              } # INSCOPE
              unless (defined $i) {
                
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                                text => $self->{t}->{tag_name}, token => $self->{t});
                ## Ignore the token
                
                $self->{t} = $self->_get_next_token;
                next B;
              }
                
              splice @{$self->{open_elements}}, $i;
              pop @{$open_tables};
              
              $self->_reset_insertion_mode;
              
              $self->{t} = $self->_get_next_token;
              next B;
        } elsif ($self->{insertion_mode} & ROW_IMS and {
          tbody => 1, tfoot => 1, thead => 1,
        }->{$self->{t}->{tag_name}}) {
          if (($self->{insertion_mode} & IM_MASK) == IN_ROW_IM) {
            ## The "in row" insertion mode, </tbody> </tfoot> </thead>

            ## have an element in table scope.
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if (not ($self->{open_elements}->[$_]->[1] & FOREIGN_EL) and
                  $self->{open_elements}->[$_]->[0]->local_name eq $self->{t}->{tag_name}) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                              value => $self->{t}->{tag_name}, # actual
                              token => $self->{t});
              ## Ignore the token
              
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## have a |tr| element in table scope
            my $i;
            INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[1] == TABLE_ROW_EL) {
                $i = $_;
                last INSCOPE;
              } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
                last INSCOPE;
              }
            } # INSCOPE
            unless (defined $i) {
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                              text => $self->{t}->{tag_name},
                              token => $self->{t});
              ## Ignore the token
              
              $self->{t} = $self->_get_next_token;
              next B;
            }
            
            ## Clear back to table row context
            pop @{$self->{open_elements}}
                while not ($self->{open_elements}->[-1]->[1] & TABLE_ROW_SCOPING_EL);
            
            pop @{$self->{open_elements}}; # <tr>
            $self->{insertion_mode} = IN_TABLE_BODY_IM;
            ## Reprocess the token...
            #
          } # in row

          ## The "in table body" insertion mode, </tbody> </thead>
          ## </tfoot>

          ## have an element in table scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            my $node = $self->{open_elements}->[$_];
            if (not ($node->[1] & FOREIGN_EL) and
                $node->[0]->local_name eq $self->{t}->{tag_name}) {
              $i = $_;
              last INSCOPE;
            } elsif ($node->[1] & TABLE_SCOPING_EL) {
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            ## Ignore the token.
            
            $self->{t} = $self->_get_next_token;
            next B;
          }

          ## Clear back to table body context
          pop @{$self->{open_elements}}
              while not ($self->{open_elements}->[-1]->[1] & TABLE_ROWS_SCOPING_EL);

          pop @{$self->{open_elements}}; # <tbody> <thead> <tfoot>
          $self->{insertion_mode} = IN_TABLE_IM;
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ({
          body => 1, caption => 1, col => 1, colgroup => 1,
          html => 1, td => 1, th => 1,
          tr => 1, # $self->{insertion_mode} == IN_ROW_IM
          tbody => 1, tfoot => 1, thead => 1, # $self->{insertion_mode} == IN_TABLE_IM
        }->{$self->{t}->{tag_name}}) {
          ## The "in table" insertion mode, table end tags
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'stray end tag',
                          value => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          $template_end_tag->($self);
          next B;
        } else {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in table:/',
                          text => $self->{t}->{tag_name}, token => $self->{t});

          $self->{insert} = $insert = $insert_to_foster;
          #
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        $self->{insert} = $insert = $insert_to_foster;
        ## Process the token using the rules for the "in body"
        ## insertion mode.
        $self->{insertion_mode} = IN_BODY_IM;
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } elsif (($self->{insertion_mode} & IM_MASK) == IN_COLUMN_GROUP_IM) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($1);
          unless (length $self->{t}->{data}) {
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
        }
        
        
        #
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'col') {
          
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          pop @{$self->{open_elements}};
          delete $self->{self_closing};
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          ## The "in column group" insertion mode, <template>

          ## This is a "template start tag" code clone.
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          push @$active_formatting_elements, ['#marker', '', undef];
          delete $self->{frameset_ok}; # not ok
          push @{$self->{template_ims}},
              $self->{insertion_mode} = IN_TEMPLATE_IM;
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          
          #
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'colgroup') {
          ## The "in column group" insertion mode, </colgroup>
          if ($self->{open_elements}->[-1]->[1] != COLGROUP_EL) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => 'colgroup',
                            token => $self->{t});
            ## Ignore the token
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            
            pop @{$self->{open_elements}}; # colgroup
            $self->{insertion_mode} = IN_TABLE_IM;
            $self->{t} = $self->_get_next_token;
            next B;
          }
        } elsif ($self->{t}->{tag_name} eq 'col') {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => 'col',
                          token => $self->{t});
          ## Ignore the token
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          ## The "in column group" insertion mode, </template>
          $template_end_tag->($self);
          next B;
        } else {
          
          #
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        ## Process the token using the rules for the "in body"
        ## insertion mode.
        $self->{insertion_mode} = IN_BODY_IM;
        next B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }

      ## The "in column group" insertion mode, anything else
      if ($self->{open_elements}->[-1]->[1] != COLGROUP_EL) {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in colgroup', # XXXdoc
                        text => 'colgroup',
                        token => $self->{t});
        ## Ignore the token.
        
        $self->{t} = $self->_get_next_token;
        next B;
      } else {
        pop @{$self->{open_elements}}; # <colgroup>
        $self->{insertion_mode} = IN_TABLE_IM;
        
        ## Reprocess the token.
        next B;
      }
    } elsif ($self->{insertion_mode} & SELECT_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        
        my $data = $self->{t}->{data};
        while ($data =~ s/\x00//) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'NULL', token => $self->{t});
        }
        $self->{open_elements}->[-1]->[0]->manakai_append_content ($data)
            if $data ne '';
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'option') {
          pop @{$self->{open_elements}}
              if $self->{open_elements}->[-1]->[1] == OPTION_EL;

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'optgroup') {
          pop @{$self->{open_elements}}
              if $self->{open_elements}->[-1]->[1] == OPTION_EL;
          pop @{$self->{open_elements}}
              if $self->{open_elements}->[-1]->[1] == OPTGROUP_EL;

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          
          $self->{t} = $self->_get_next_token;
          next B;

        } elsif ({
          select => 1,
          input => 1, textarea => 1, keygen => 1,
        }->{$self->{t}->{tag_name}} or (
          ($self->{insertion_mode} & IM_MASK) == IN_SELECT_IN_TABLE_IM and
          {
            caption => 1, table => 1, tbody => 1, tfoot => 1, thead => 1,
            tr => 1, td => 1, th => 1,
          }->{$self->{t}->{tag_name}}
        )) {
          ## The "in select" insertion mode, <select> <input>
          ## <textarea> <keygen>

          ## The "in select in table" insertion mode, <select> <input>
          ## <textarea> <keygen> <caption> <table> <tbody> <tfoot>
          ## <thead> <tr> <td> <th>

          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed', text => 'select',
                          token => $self->{t});

          ## have a |select| element in select scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            if ($self->{open_elements}->[$_]->[1] == SELECT_EL) {
              $i = $_;
              last INSCOPE;
            } elsif ($self->{open_elements}->[$_]->[1] == OPTION_EL or
                     $self->{open_elements}->[$_]->[1] == OPTGROUP_EL) {
              #
            } else {
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            ## This check is redundant for <select> case and is not in
            ## the spec.

            ## Ignore the token.
            
            $self->{t} = $self->_get_next_token;
            next B;
          }

          splice @{$self->{open_elements}}, $i;

          $self->_reset_insertion_mode;

          if ($self->{t}->{tag_name} eq 'select') {
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            ## Reprocess the token.
            next B;
          }

        } elsif ($self->{t}->{tag_name} eq 'script') {
          
          ## NOTE: This is an "as if in head" code clone
          $script_start_tag->($self, $insert, $open_tables);
          next B;
        } elsif ($self->{t}->{tag_name} eq 'template') {
          ## This is a "template start tag" code clone.
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          push @$active_formatting_elements, ['#marker', '', undef];
          delete $self->{frameset_ok}; # not ok
          push @{$self->{template_ims}},
              $self->{insertion_mode} = IN_TEMPLATE_IM;
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in select',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          ## Ignore the token
          
          $self->{t} = $self->_get_next_token;
          next B;
        }

      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'optgroup') {
          if ($self->{open_elements}->[-1]->[1] == OPTION_EL and
              $self->{open_elements}->[-2]->[1] == OPTGROUP_EL) {
            splice @{$self->{open_elements}}, -2; # <optgroup><option>
          } elsif ($self->{open_elements}->[-1]->[1] == OPTGROUP_EL) {
            pop @{$self->{open_elements}}; # <optgroup>
          } else {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            ## Ignore the token.
          }
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'option') {
          if ($self->{open_elements}->[-1]->[1] == OPTION_EL) {
            pop @{$self->{open_elements}}; # <option>
          } else {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            ## Ignore the token.
          }
          
          $self->{t} = $self->_get_next_token;
          next B;

        } elsif ($self->{t}->{tag_name} eq 'select') {
          ## The "in select" / "in select in table" insertion mode,
          ## </select>

          ## have a |select| element in select scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            my $node = $self->{open_elements}->[$_];
            if ($node->[1] == SELECT_EL) {
              $i = $_;
              last INSCOPE;
            } elsif ($node->[1] == OPTION_EL or $node->[1] == OPTGROUP_EL) {
              #
            } else {
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name},
                            token => $self->{t});
            ## Ignore the token.
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
          
          splice @{$self->{open_elements}}, $i;

          $self->_reset_insertion_mode;

          
          $self->{t} = $self->_get_next_token;
          next B;

        } elsif (
          ($self->{insertion_mode} & IM_MASK) == IN_SELECT_IN_TABLE_IM and
          {
            caption => 1, table => 1, tbody => 1, tfoot => 1, thead => 1,
            tr => 1, td => 1, th => 1,
          }->{$self->{t}->{tag_name}}
        ) {
          ## The "in select in table" insertion mode, </caption>
          ## </table> </tbody> </tfoot> </thead> </tr> </td> </th>

          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});

          ## have a |$self->{t}->{tag_name}| element in table scope
          my $i;
          INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
            if (not ($self->{open_elements}->[$_]->[1] & FOREIGN_EL) and
                $self->{open_elements}->[$_]->[0]->local_name eq $self->{t}->{tag_name}) {
              $i = $_;
              last INSCOPE;
            } elsif ($self->{open_elements}->[$_]->[1] & TABLE_SCOPING_EL) {
              
              last INSCOPE;
            }
          } # INSCOPE
          unless (defined $i) {
            ## Ignore the token
            
            $self->{t} = $self->_get_next_token;
            next B;
          }

          ## There is always |select| in the stack.
          pop @{$self->{open_elements}}
              while not ($self->{open_elements}->[-1]->[1] == SELECT_EL);
          pop @{$self->{open_elements}}; # <select>

          $self->_reset_insertion_mode;

          ## Reprocess the token.
          next B;

        } elsif ($self->{t}->{tag_name} eq 'template') {
          $template_end_tag->($self);
          next B;
        } else {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in select:/',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          ## Ignore the token
          
          $self->{t} = $self->_get_next_token;
          next B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        ## Process the token using the rules for the "in body"
        ## insertion mode.
        $self->{insertion_mode} = IN_BODY_IM;
        next B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } elsif ($self->{insertion_mode} & BODY_AFTER_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          my $data = $1;
          ## As if in body
          $reconstruct_active_formatting_elements
              ->($self, $insert_to_current, $active_formatting_elements,
                 $open_tables);
              
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($data);
          
          unless (length $self->{t}->{data}) {
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
        }
        
        if ($self->{insertion_mode} == AFTER_HTML_BODY_IM) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html:#text', token => $self->{t});
          #
        } else {
          
          ## "after body" insertion mode
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after body:#text', token => $self->{t});
          #
        }

        $self->{insertion_mode} = IN_BODY_IM;
        ## reprocess
        next B;
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{insertion_mode} == AFTER_HTML_BODY_IM) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          #
        } else {
          
          ## "after body" insertion mode
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after body',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          #
        }

        $self->{insertion_mode} = IN_BODY_IM;
        
        ## reprocess
        next B;
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{insertion_mode} == AFTER_HTML_BODY_IM) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html:/',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          
          $self->{insertion_mode} = IN_BODY_IM;
          ## Reprocess.
          next B;
        } else {
          
        }

        ## "after body" insertion mode
        if ($self->{t}->{tag_name} eq 'html') {
          if (defined $self->{inner_html_node}) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => 'html', token => $self->{t});
            ## Ignore the token
            $self->{t} = $self->_get_next_token;
            next B;
          } else {
            
            $self->{insertion_mode} = AFTER_HTML_BODY_IM;
            $self->{t} = $self->_get_next_token;
            next B;
          }
        } else {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'after body:/',
                          text => $self->{t}->{tag_name}, token => $self->{t});

          $self->{insertion_mode} = IN_BODY_IM;
          ## reprocess
          next B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        
        ## Stop parsing
        last B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } elsif ($self->{insertion_mode} & FRAME_IMS) {
      if ($self->{t}->{type} == CHARACTER_TOKEN) {
        if ($self->{t}->{data} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          $self->{open_elements}->[-1]->[0]->manakai_append_content ($1);
          
          unless (length $self->{t}->{data}) {
            
            $self->{t} = $self->_get_next_token;
            next B;
          }
        }
        
        if ($self->{t}->{data} =~ s/^[^\x09\x0A\x0C\x20]+//) {
          if ($self->{insertion_mode} == IN_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in frameset:#text', token => $self->{t});
          } elsif ($self->{insertion_mode} == AFTER_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after frameset:#text', token => $self->{t});
          } else { # "after after frameset"
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after html:#text', token => $self->{t});
          }
          
          ## Ignore the token.
          if (length $self->{t}->{data}) {
            
            ## reprocess the rest of characters
          } else {
            
            $self->{t} = $self->_get_next_token;
          }
          next B;
        }
        
        die qq[$0: Character "$self->{t}->{data}"];
      } elsif ($self->{t}->{type} == START_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'frameset' and
            $self->{insertion_mode} == IN_FRAMESET_IM) {
          
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'frame' and
                 $self->{insertion_mode} == IN_FRAMESET_IM) {
          
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $self->{open_elements}->[-1]->[0]->manakai_append_content ($el);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
          pop @{$self->{open_elements}};
          delete $self->{self_closing};
          $self->{t} = $self->_get_next_token;
          next B;
        } elsif ($self->{t}->{tag_name} eq 'noframes') {
          
          ## NOTE: As if in head.
          $parse_rcdata->($self, $insert, $open_tables, 0); # RAWTEXT
          next B;

          ## NOTE: |<!DOCTYPE HTML><frameset></frameset></html><noframes></noframes>|
          ## has no parse error.
        } else {
          if ($self->{insertion_mode} == IN_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in frameset',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          } elsif ($self->{insertion_mode} == AFTER_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after frameset',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          } else { # "after after frameset"
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after after frameset',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          }
          ## Ignore the token
          
          $self->{t} = $self->_get_next_token;
          next B;
        }
      } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
        if ($self->{t}->{tag_name} eq 'frameset' and
            $self->{insertion_mode} == IN_FRAMESET_IM) {
          if ($self->{open_elements}->[-1]->[1] == HTML_EL and
              @{$self->{open_elements}} == 1) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                            text => $self->{t}->{tag_name}, token => $self->{t});
            ## Ignore the token
            $self->{t} = $self->_get_next_token;
          } else {
            
            pop @{$self->{open_elements}};
            $self->{t} = $self->_get_next_token;
          }

          if (not defined $self->{inner_html_node} and
              not ($self->{open_elements}->[-1]->[1] == FRAMESET_EL)) {
            
            $self->{insertion_mode} = AFTER_FRAMESET_IM;
          } else {
            
          }
          next B;
        } elsif ($self->{t}->{tag_name} eq 'html' and
                 $self->{insertion_mode} == AFTER_FRAMESET_IM) {
          
          $self->{insertion_mode} = AFTER_HTML_FRAMESET_IM;
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          if ($self->{insertion_mode} == IN_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in frameset:/',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          } elsif ($self->{insertion_mode} == AFTER_FRAMESET_IM) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after frameset:/',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          } else { # "after after html"
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'after after frameset:/',
                            text => $self->{t}->{tag_name}, token => $self->{t});
          }
          ## Ignore the token
          $self->{t} = $self->_get_next_token;
          next B;
        }
      } elsif ($self->{t}->{type} == END_OF_FILE_TOKEN) {
        unless ($self->{open_elements}->[-1]->[1] == HTML_EL and
                @{$self->{open_elements}} == 1) { # redundant, maybe
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body:#eof', token => $self->{t});
        } else {
          
        }
        
        ## Stop parsing
        last B;
      } else {
        die "$0: $self->{t}->{type}: Unknown token type";
      }
    } else {
      die "$0: $self->{insertion_mode}: Unknown insertion mode";
    }

    ## "in body" insertion mode
    if ($self->{t}->{type} == START_TAG_TOKEN) {
      if ($self->{t}->{tag_name} eq 'script') {
        
        ## NOTE: This is an "as if in head" code clone
        $script_start_tag->($self, $insert, $open_tables);
        next B;
      } elsif ($self->{t}->{tag_name} eq 'style') {
        
        ## NOTE: This is an "as if in head" code clone
        $parse_rcdata->($self, $insert, $open_tables, 0); # RAWTEXT
        next B;
      } elsif ($self->{t}->{tag_name} eq 'template') {
        ## This is a "template start tag" code clone.
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        push @$active_formatting_elements, ['#marker', '', undef];
        delete $self->{frameset_ok}; # not ok
        push @{$self->{template_ims}},
            $self->{insertion_mode} = IN_TEMPLATE_IM;
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
        base => 1, link => 1, basefont => 1, bgsound => 1,
      }->{$self->{t}->{tag_name}}) {
        
        ## NOTE: This is an "as if in head" code clone, only "-t" differs
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        pop @{$self->{open_elements}};
        delete $self->{self_closing};
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'meta') {
        ## NOTE: This is an "as if in head" code clone, only "-t" differs
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        my $meta_el = pop @{$self->{open_elements}};

        unless ($self->{confident}) {
          if ($self->{t}->{attributes}->{charset}) {
            
            ## NOTE: Whether the encoding is supported or not, an
            ## ASCII-compatible charset is not, is handled in the
            ## |_change_encoding| method.
            if ($self->_change_encoding
                    ($self->{t}->{attributes}->{charset}->{value},
                     $self->{t})) {
              return {type => ABORT_TOKEN};
            }
            
            $meta_el->[0]->get_attribute_node_ns (undef, 'charset')
                ->set_user_data (manakai_has_reference =>
                                     $self->{t}->{attributes}->{charset}
                                         ->{has_reference});
          } elsif ($self->{t}->{attributes}->{content} and
                   $self->{t}->{attributes}->{'http-equiv'}) {
            if ($self->{t}->{attributes}->{'http-equiv'}->{value}
                =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
                $self->{t}->{attributes}->{content}->{value}
                =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                    [\x09\x0A\x0C\x0D\x20]*=
                    [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                    ([^"'\x09\x0A\x0C\x0D\x20][^\x09\x0A\x0C\x0D\x20\x3B]*))
                   /x) {
              
              ## NOTE: Whether the encoding is supported or not, an
              ## ASCII-compatible charset is not, is handled in the
              ## |_change_encoding| method.
              if ($self->_change_encoding
                      (defined $1 ? $1 : defined $2 ? $2 : $3,
                       $self->{t})) {
                return {type => ABORT_TOKEN};
              }
              $meta_el->[0]->get_attribute_node_ns (undef, 'content')
                  ->set_user_data (manakai_has_reference =>
                                       $self->{t}->{attributes}->{content}
                                             ->{has_reference});
            }
          }
        } else {
          if ($self->{t}->{attributes}->{charset}) {
            
            $meta_el->[0]->get_attribute_node_ns (undef, 'charset')
                ->set_user_data (manakai_has_reference =>
                                     $self->{t}->{attributes}->{charset}
                                         ->{has_reference});
          }
          if ($self->{t}->{attributes}->{content}) {
            
            $meta_el->[0]->get_attribute_node_ns (undef, 'content')
                ->set_user_data (manakai_has_reference =>
                                     $self->{t}->{attributes}->{content}
                                         ->{has_reference});
          }
        }

        delete $self->{self_closing};
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'title') {
        
        ## NOTE: This is an "as if in head" code clone
        $parse_rcdata->($self, $insert, $open_tables, 1); # RCDATA
        next B;

      } elsif ($self->{t}->{tag_name} eq 'body') {
        ## "In body" insertion mode, "body" start tag token.
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body', text => 'body', token => $self->{t});
        
        if (@{$self->{open_elements}} == 1 or
            not ($self->{open_elements}->[1]->[1] == BODY_EL) or 
            do {
              my $has_template;
              OE: for (reverse @{$self->{open_elements}}) {
                if ($_->[1] == TEMPLATE_EL) {
                  $has_template = 1;
                  last OE;
                }
              } # OE
              $has_template;
            }) {
          
          ## Ignore the token
        } else {
          delete $self->{frameset_ok};
          my $body_el = $self->{open_elements}->[1]->[0];
          for my $attr_name (keys %{$self->{t}->{attributes}}) {
            unless ($body_el->has_attribute_ns (undef, $attr_name)) {
              
              $body_el->set_attribute_ns
                (undef, [undef, $attr_name],
                 $self->{t}->{attributes}->{$attr_name}->{value});
            }
          }
        }
        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'frameset') {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body', text => $self->{t}->{tag_name},
                        token => $self->{t});

        if (@{$self->{open_elements}} == 1 or
            not ($self->{open_elements}->[1]->[1] == BODY_EL)) {
          
          ## Ignore the token.
        } elsif (not $self->{frameset_ok}) {
          
          ## Ignore the token.
        } else {
          
          
          ## 1. Remove the second element.
          my $body = $self->{open_elements}->[1]->[0];
          my $body_parent = $body->parent_node;
          $body_parent->remove_child ($body) if $body_parent;

          ## 2. Pop nodes.
          splice @{$self->{open_elements}}, 1;

          ## 3. Insert.
          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

          ## 4. Switch.
          $self->{insertion_mode} = IN_FRAMESET_IM;
        }

        
        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ({
        ## "In body" insertion mode, non-phrasing flow-content
        ## elements start tags.

        address => 1, article => 1, aside => 1, blockquote => 1,
        center => 1, details => 1, dialog => 1, dir => 1, div => 1, dl => 1,
        fieldset => 1, figcaption => 1, figure => 1, footer => 1,
        header => 1, hgroup => 1, main => 1, menu => 1, nav => 1, ol => 1,
        p => 1, section => 1, ul => 1, summary => 1,
        # datagrid => 1,

        ## Closing any heading element
        h1 => 1, h2 => 1, h3 => 1, h4 => 1, h5 => 1, h6 => 1, 

        ## Ignoring any leading newline in content
        pre => 1, listing => 1,

        ## Form element pointer
        form => 1,
        
        ## A quirk & switching of insertion mode
        table => 1,

        ## Flow void element
        hr => 1,
      }->{$self->{t}->{tag_name}}) {

        ## 1. When there is an opening |form| element:
        if ($self->{t}->{tag_name} eq 'form' and defined $self->{form_element}) {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'in form:form', token => $self->{t});
          ## Ignore the token
          
          $self->{t} = $self->_get_next_token;
          next B;
        }

        ## 2. If there is a |p| element in button scope, close it.
        if ($self->{t}->{tag_name} ne 'table' or # The Hixie Quirk
            $self->{document}->manakai_compat_mode ne 'quirks') {
          $self->_close_p;
        }

        ## 3. Close the opening <hn> element, if any.
        if ({h1 => 1, h2 => 1, h3 => 1,
             h4 => 1, h5 => 1, h6 => 1}->{$self->{t}->{tag_name}}) {
          if ($self->{open_elements}->[-1]->[1] == HEADING_EL) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                            text => $self->{open_elements}->[-1]->[0]->local_name,
                            token => $self->{t});
            pop @{$self->{open_elements}};
          }
        }

        ## 4. Insertion.
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        if ($self->{t}->{tag_name} eq 'pre' or $self->{t}->{tag_name} eq 'listing') {
          
          $self->{t} = $self->_get_next_token;
          if ($self->{t}->{type} == CHARACTER_TOKEN) {
            $self->{t}->{data} =~ s/^\x0A//;
            unless (length $self->{t}->{data}) {
              
              $self->{t} = $self->_get_next_token;
            } else {
              
            }
          } else {
            
          }

          delete $self->{frameset_ok};
        } elsif ($self->{t}->{tag_name} eq 'form') {
          
          $self->{form_element} = $self->{open_elements}->[-1]->[0];

          
          $self->{t} = $self->_get_next_token;
        } elsif ($self->{t}->{tag_name} eq 'table') {
          
          push @{$open_tables}, [$self->{open_elements}->[-1]->[0]];

          delete $self->{frameset_ok};
          
          $self->{insertion_mode} = IN_TABLE_IM;

          
          $self->{t} = $self->_get_next_token;
        } elsif ($self->{t}->{tag_name} eq 'hr') {
          
          pop @{$self->{open_elements}};
          
          delete $self->{self_closing};

          delete $self->{frameset_ok};

          $self->{t} = $self->_get_next_token;
        } else {
          
          $self->{t} = $self->_get_next_token;
        }
        next B;

      } elsif ($self->{t}->{tag_name} eq 'li' or
               $self->{t}->{tag_name} eq 'dt' or
               $self->{t}->{tag_name} eq 'dd') {
        ## The "in body" insertion mode, <li>, <dt>, or <dd>.  As
        ## normal, but end tag is implied.

        ## 1. Frameset-ng
        delete $self->{frameset_ok};

        ## 2., <li> 5. / <dt><dd> 6.
        my @el_name = $self->{t}->{tag_name} eq 'li' ? ('li') : ('dd', 'dt');
        LOOP: for (reverse 0..$#{$self->{open_elements}}) {
          for my $el_name (@el_name) {
            ## <li><dt><dd> 3. Loop, <dt><dd> 4.
            if ($self->{open_elements}->[$_]->[1] != FOREIGN_EL and
                $self->{open_elements}->[$_]->[0]->local_name eq $el_name) {
              ## 3.1. Generate implied end tags.
              pop @{$self->{open_elements}}
                  while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL and
                        not ($self->{open_elements}->[-1]->[1] != FOREIGN_EL and
                             $self->{open_elements}->[-1]->[0]->local_name eq $el_name);
              
              ## 3.2.
              unless ($self->{open_elements}->[-1]->[1] != FOREIGN_EL and
                      $self->{open_elements}->[-1]->[0]->local_name eq $el_name) {
                $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                                text => $self->{open_elements}->[-1]->[0]->local_name,
                                token => $self->{t});
              }

              ## 3.3.
              splice @{$self->{open_elements}}, $_;

              ## 3.4.
              last LOOP;
            }
          } # $el_name

          ## <li> 4. / <dt><dd> 5.
          last LOOP
              if $self->{open_elements}->[$_]->[1] & (SPECIAL_EL | SCOPING_EL) and # Special
                 not $self->{open_elements}->[$_]->[1] & ADDRESS_DIV_P_EL;
        } # LOOP

        ## <li> 6. Done / <dt><dd> 7. Done
        $self->_close_p;

        ## <li> 7. / <dt><dd> 8.
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        
        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ($self->{t}->{tag_name} eq 'plaintext') {
        ## "In body" insertion mode, "plaintext" start tag.  As
        ## normal, but effectively ends parsing.

        $self->_close_p;
        
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        
        $self->{state} = PLAINTEXT_STATE;
          
        
        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ($self->{t}->{tag_name} eq 'a') {
        ## The "in body" insertion mode, <a>

        AFE: for my $i (reverse 0..$#$active_formatting_elements) {
          my $node = $active_formatting_elements->[$i];
          if ($node->[1] == A_EL) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in a:a', token => $self->{t});
            $self->_aaa ($self->{t});
            AFE2: for (reverse 0..$#$active_formatting_elements) {
              if ($active_formatting_elements->[$_]->[0] eq $node->[0]) {
                splice @$active_formatting_elements, $_, 1;
                last AFE2;
              }
            } # AFE2
            OE: for (reverse 0..$#{$self->{open_elements}}) {
              if ($self->{open_elements}->[$_]->[0] eq $node->[0]) {
                splice @{$self->{open_elements}}, $_, 1;
                last OE;
              }
            } # OE
            last AFE;
          } elsif ($node->[0] eq '#marker') {
            
            last AFE;
          }
        } # AFE
        
        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);

        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        push_afe [$self->{open_elements}->[-1]->[0],
                  $self->{open_elements}->[-1]->[1],
                  $self->{t}]
            => $active_formatting_elements;

        
        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ($self->{t}->{tag_name} eq 'nobr') {
        ## The "in body" insertion mode, <nobr>

        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);

        ## has a |nobr| element in scope
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          my $node = $self->{open_elements}->[$_];
          if ($node->[1] == NOBR_EL) {
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in nobr:nobr', token => $self->{t});
            $self->_aaa ($self->{t});
            $reconstruct_active_formatting_elements
                ->($self, $insert, $active_formatting_elements, $open_tables);
            last INSCOPE;
          } elsif ($node->[1] & SCOPING_EL) {
            last INSCOPE;
          }
        } # INSCOPE
        
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        push_afe [$self->{open_elements}->[-1]->[0],
                  $self->{open_elements}->[-1]->[1],
                  $self->{t}]
            => $active_formatting_elements;
        
        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'button') {
        ## 1. has a |button| element in scope
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          if ($self->{open_elements}->[$_]->[1] == BUTTON_EL) {
            ## 1.1.
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'in button:button', token => $self->{t});

            ## 1.2. Generate implied end tags.
            pop @{$self->{open_elements}}
                while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;

            ## 1.3.
            splice @{$self->{open_elements}}, $_;
            last INSCOPE;
          } elsif ($self->{open_elements}->[$_]->[1] & SCOPING_EL) {
            last INSCOPE;
          }
        } # INSCOPE
        
        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;

        ## 2.
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);

        ## 3.
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

        ## TODO: associate with $self->{form_element} if defined

        ## 4.
        delete $self->{frameset_ok};

        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
                xmp => 1,
                iframe => 1,
                noembed => 1,
                noframes => 1, ## NOTE: This is an "as if in head" code clone.
                noscript => 0, ## TODO: 1 if scripting is enabled
               }->{$self->{t}->{tag_name}}) {
        if ($self->{t}->{tag_name} eq 'xmp') {
          ## "In body" insertion mode, "xmp" start tag.  As normal
          ## flow-content element start tag, but CDATA parsing.
          

          $self->_close_p;

          my $insert = $self->{insertion_mode} & TABLE_IMS
              ? $insert_to_foster : $insert_to_current;
          $reconstruct_active_formatting_elements
              ->($self, $insert, $active_formatting_elements,
                 $open_tables);

          delete $self->{frameset_ok};
        } elsif ($self->{t}->{tag_name} eq 'iframe') {
          
          delete $self->{frameset_ok};
        } else {
          
        }
        ## NOTE: There is an "as if in body" code clone.
        $parse_rcdata->($self, $insert, $open_tables, 0); # RAWTEXT
        next B;
      } elsif ($self->{t}->{tag_name} eq 'isindex') {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'isindex', token => $self->{t});
        if (defined $self->{form_element} and
            not do {
              my $has_template;
              OE: for (reverse @{$self->{open_elements}}) {
                if ($_->[1] == TEMPLATE_EL) {
                  $has_template = 1;
                  last OE;
                }
              } # OE
              $has_template;
            }) {
          
          ## Ignore the token
           ## NOTE: Not acknowledged.
          $self->{t} = $self->_get_next_token;
          next B;
        } else {
          delete $self->{self_closing};

          delete $self->{frameset_ok}; # not ok

          $self->_close_p;

          my $insert = $self->{insertion_mode} & TABLE_IMS
              ? $insert_to_foster : $insert_to_current;
          my $input_attrs = $self->{t}->{attributes};
          my $form_attrs = {};
          $form_attrs->{action} = delete $input_attrs->{action}
              if exists $input_attrs->{action};
          my $prompt_attr = delete $input_attrs->{prompt};
          $input_attrs->{name} = {name => 'name', value => 'isindex'};

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'form']);
    
        for my $attr_name (keys %{  $form_attrs}) {
          my $attr_t =   $form_attrs->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'form'} || 0];
    }
  
          # XXX If no |template| in $self->{open_elements}, set form element pointer

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'hr']);
    
        for my $attr_name (keys %{  +{}}) {
          my $attr_t =   +{}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'hr'} || 0];
    }
  
          pop @{$self->{open_elements}}; # <hr>

          $reconstruct_active_formatting_elements
              ->($self, $insert, $active_formatting_elements, $open_tables);

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'label']);
    
        for my $attr_name (keys %{  +{}}) {
          my $attr_t =   +{}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'label'} || 0];
    }
  

          if ($prompt_attr) {
            $self->{open_elements}->[-1]->[0]->manakai_append_content
                ($prompt_attr->{value}) if length $prompt_attr->{value};
          } else {
            # XXX SHOULD: localization
            $self->{open_elements}->[-1]->[0]->manakai_append_content
                ('This is a searchable index. Enter search keywords: ');
          }

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'input']);
    
        for my $attr_name (keys %{  $input_attrs}) {
          my $attr_t =   $input_attrs->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'input'} || 0];
    }
  
          pop @{$self->{open_elements}}; # <input>

          {
            # XXX SHOULD: localization
            $self->{open_elements}->[-1]->[0]->manakai_append_content
                ('XXX') if 0;
          }

          pop @{$self->{open_elements}}; # <label>

          
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'hr']);
    
        for my $attr_name (keys %{  +{}}) {
          my $attr_t =   +{}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{'hr'} || 0];
    }
  
          pop @{$self->{open_elements}}; # <hr>

          pop @{$self->{open_elements}}; # <form> (or some formatting element)
          # XXX If no |template| in $self->{open_elements}, set form element pointer to null

          $self->{t} = $self->_get_next_token;
          next B;
        }
      } elsif ($self->{t}->{tag_name} eq 'textarea') {
        ## 1. Insert
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        
        ## Step 2 # XXX
        ## TODO: $self->{form_element} if defined

        ## 2. Drop U+000A LINE FEED
        $self->{ignore_newline} = 1;

        ## 3. RCDATA
        $self->{state} = RCDATA_STATE;
        delete $self->{escape}; # MUST

        ## 4., 6. Insertion mode
        $self->{insertion_mode} |= IN_CDATA_RCDATA_IM;

        ## 5. Frameset-ng.
        delete $self->{frameset_ok};

        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'optgroup' or
               $self->{t}->{tag_name} eq 'option') {
        pop @{$self->{open_elements}}
            if $self->{open_elements}->[-1]->[1] == OPTION_EL;

        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);

        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

        
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{tag_name} eq 'rt' or
               $self->{t}->{tag_name} eq 'rp') {
        ## has a |ruby| element in scope
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          my $node = $self->{open_elements}->[$_];
          if ($node->[1] == RUBY_EL) {
            
            ## generate implied end tags
            while ($self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL) {
              
              pop @{$self->{open_elements}};
            }
            unless ($self->{open_elements}->[-1]->[1] == RUBY_EL) {
              
              $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                              text => $self->{open_elements}->[-1]->[0]
                                  ->manakai_local_name,
                              token => $self->{t});
            }
            last INSCOPE;
          } elsif ($node->[1] & SCOPING_EL) {
            
            last INSCOPE;
          }
        } # INSCOPE

        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

        
        $self->{t} = $self->_get_next_token;
        redo B;
      } elsif ($self->{t}->{tag_name} eq 'math' or
               $self->{t}->{tag_name} eq 'svg') {
        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);

        ## "Adjust MathML attributes" ('math' only) - done in insert-element-f

        ## "adjust SVG attributes" ('svg' only) - done in insert-element-f

        ## "adjust foreign attributes" - done in insert-element-f
        
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        ($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS, [undef,   $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (
          @{
            $foreign_attr_xname->{$attr_name} ||
            [undef, [undef,
                     ($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS) eq SVG_NS ?
                         ($svg_attr_name->{$attr_name} || $attr_name) :
                     ($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS) eq MML_NS ?
                         ($mml_attr_name->{$attr_name} || $attr_name) :
                         $attr_name]]
          }
        );
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, ($el_category_f->{$self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS}->{ $self->{t}->{tag_name}} || 0) | FOREIGN_EL | (($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS) eq SVG_NS ? SVG_EL : ($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS) eq MML_NS ? MML_EL : 0)];

      if ( $self->{t}->{attributes}->{xmlns} and  $self->{t}->{attributes}->{xmlns}->{value} ne ($self->{t}->{tag_name} eq 'math' ? MML_NS : SVG_NS)) {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'bad namespace', token =>  $self->{t});
## TODO: Error type documentation
      }
      if ( $self->{t}->{attributes}->{'xmlns:xlink'} and
           $self->{t}->{attributes}->{'xmlns:xlink'}->{value} ne q<http://www.w3.org/1999/xlink>) {
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'bad namespace', token =>  $self->{t});
      }
    }
  
        
        if ($self->{self_closing}) {
          pop @{$self->{open_elements}};
          delete $self->{self_closing};
        } else {
          
        }

        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
                caption => 1, col => 1, colgroup => 1, frame => 1,
                head => 1,
                tbody => 1, td => 1, tfoot => 1, th => 1,
                thead => 1, tr => 1,
               }->{$self->{t}->{tag_name}}) {
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'in body',
                        text => $self->{t}->{tag_name}, token => $self->{t});
        ## Ignore the token
         ## NOTE: |<col/>| or |<frame/>| here is an error.
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
        param => 1, source => 1, track => 1, menuitem => 1,
      }->{$self->{t}->{tag_name}}) { ## Void elements only allowed in some elements
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  
        pop @{$self->{open_elements}};

        delete $self->{self_closing};
        $self->{t} = $self->_get_next_token;
        redo B;
      } else {
        if ($self->{t}->{tag_name} eq 'image') {
          
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'image', token => $self->{t});
          $self->{t}->{tag_name} = 'img';
        } else {
          
        }

        ## NOTE: There is an "as if <br>" code clone.
        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);
        
        
    {
      my $el;
      
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  $self->{t}->{tag_name}]);
    
        for my $attr_name (keys %{  $self->{t}->{attributes}}) {
          my $attr_t =   $self->{t}->{attributes}->{$attr_name};
          my $attr = $self->{document}->create_attribute_ns (undef, [undef, $attr_name]);
          $attr->value ($attr_t->{value});
          $attr->set_user_data (manakai_source_line => $attr_t->{line});
          $attr->set_user_data (manakai_source_column => $attr_t->{column});
          $attr->set_user_data (manakai_pos => $attr_t->{pos}) if $attr_t->{pos};
          $el->set_attribute_node_ns ($attr);
        }
      
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
      $insert->($self, $el, $open_tables);
      push @{$self->{open_elements}}, [$el, $el_category->{$self->{t}->{tag_name}} || 0];
    }
  

        if ({
             applet => 1, marquee => 1, object => 1,
            }->{$self->{t}->{tag_name}}) {
          

          push @$active_formatting_elements, ['#marker', '', undef];

          delete $self->{frameset_ok};

          
        } elsif ({
                  b => 1, big => 1, code => 1, em => 1, font => 1, i => 1,
                  s => 1, small => 1, strike => 1,
                  strong => 1, tt => 1, u => 1,
                 }->{$self->{t}->{tag_name}}) {
          
          push_afe [$self->{open_elements}->[-1]->[0],
               $self->{open_elements}->[-1]->[1],
               $self->{t}]
              => $active_formatting_elements;
          
        } elsif ($self->{t}->{tag_name} eq 'input') {
          
          ## TODO: associate with $self->{form_element} if defined

          pop @{$self->{open_elements}};

          if ($self->{t}->{attributes}->{type}) {
            my $type = $self->{t}->{attributes}->{type}->{value};
            $type =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($type eq 'hidden') {
              #
            } else {
              delete $self->{frameset_ok};
            }
          } else {
            delete $self->{frameset_ok};
          }

          delete $self->{self_closing};
        } elsif ({
          area => 1, br => 1, embed => 1, img => 1, wbr => 1, keygen => 1,
        }->{$self->{t}->{tag_name}}) { ## Phrasing void elements
          

          pop @{$self->{open_elements}};

          delete $self->{frameset_ok};

          delete $self->{self_closing};
        } elsif ($self->{t}->{tag_name} eq 'select') {
          ## TODO: associate with $self->{form_element} if defined

          delete $self->{frameset_ok};
          
          if ($self->{insertion_mode} & TABLE_IMS or
              $self->{insertion_mode} & BODY_TABLE_IMS) {
            
            $self->{insertion_mode} = IN_SELECT_IN_TABLE_IM;
          } else {
            
            $self->{insertion_mode} = IN_SELECT_IM;
          }
          
        } else {
          
        }
        
        $self->{t} = $self->_get_next_token;
        next B;
      }
    } elsif ($self->{t}->{type} == END_TAG_TOKEN) {
      if ($self->{t}->{tag_name} eq 'body' or
          $self->{t}->{tag_name} eq 'html') {

        ## 1. If not "have an element in scope":
        ## "has a |body| element in scope"
        my $i;
        INSCOPE: {
          for (reverse @{$self->{open_elements}}) {
            if ($_->[1] == BODY_EL) {
              
              $i = $_;
              last INSCOPE;
            } elsif ($_->[1] & SCOPING_EL) {
              
              last;
            }
          }

          ## NOTE: |<marquee></body>|, |<svg><foreignobject></body>|,
          ## and fragment cases.

          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name}, token => $self->{t});
          ## Ignore the token.  (</body> or </html>)
          $self->{t} = $self->_get_next_token;
          next B;
        } # INSCOPE

        ## 2. If unclosed elements:
        for (@{$self->{open_elements}}) {
          unless ($_->[1] & ALL_END_TAG_OPTIONAL_EL ||
                  $_->[1] == OPTGROUP_EL ||
                  $_->[1] == OPTION_EL ||
                  $_->[1] == RUBY_COMPONENT_EL) {
            
            $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                            text => $_->[0]->manakai_local_name,
                            token => $self->{t});
            last;
          } else {
            
          }
        }

        ## 3. Switch the insertion mode.
        $self->{insertion_mode} = AFTER_BODY_IM;
        if ($self->{t}->{tag_name} eq 'body') {
          $self->{t} = $self->_get_next_token;
        } else { # html
          ## Reprocess.
        }
        next B;

      } elsif ({
                address => 1, article => 1, aside => 1, blockquote => 1,
                center => 1,
                #datagrid => 1,
                details => 1, dialog => 1,
                dir => 1, div => 1, dl => 1, fieldset => 1, figure => 1,
                footer => 1, header => 1, hgroup => 1,
                listing => 1, main => 1, menu => 1, nav => 1,
                ol => 1, pre => 1, section => 1, ul => 1,
                figcaption => 1, summary => 1,

                ## NOTE: As normal, but ... optional tags
                dd => 1, dt => 1, li => 1,

                applet => 1, button => 1, marquee => 1, object => 1,
      }->{$self->{t}->{tag_name}}) {
        ## The "in body" insertion mode, end tags for non-phrasing
        ## flow content elements.

        ## has an element in scope
        my $scoping = $self->{t}->{tag_name} eq 'li'
            ? SCOPING_EL | LIST_CONTAINER_EL : SCOPING_EL;
        my $i;
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          my $node = $self->{open_elements}->[$_];
          if (not ($node->[1] & FOREIGN_EL) and
              $node->[0]->local_name eq $self->{t}->{tag_name}) {
            $i = $_;
            last INSCOPE;
          } elsif ($node->[1] & $scoping) {
            last INSCOPE;
          }
        } # INSCOPE
        unless (defined $i) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          next B;
        }

        ## Step 1. Generate implied end tags
        pop @{$self->{open_elements}}
            while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL and
                  not (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
                       $self->{open_elements}->[-1]->[0]->local_name eq $self->{t}->{tag_name});

        ## Step 2.
        unless (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
                $self->{open_elements}->[-1]->[0]->local_name eq $self->{t}->{tag_name}) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed',
                          text => $self->{open_elements}->[-1]->[0]->local_name,
                          token => $self->{t});
        }

        ## Step 3.
        splice @{$self->{open_elements}}, $i;

        ## Step 4.
        $clear_up_to_marker->($active_formatting_elements)
            if {
              applet => 1, marquee => 1, object => 1,
            }->{$self->{t}->{tag_name}};

        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'form') {
        ## The "in body" insertion mode, </form>

        # XXX template

        # XXX 1.

        ## 2.
        undef $self->{form_element};

        ## 3. has an element in scope
        my $i;
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          my $node = $self->{open_elements}->[$_];
          if ($node->[1] == FORM_EL) { # XXX
            
            $i = $_;
            last INSCOPE;
          } elsif ($node->[1] & SCOPING_EL) {
            
            last INSCOPE;
          }
        } # INSCOPE
        unless (defined $i) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          next B;
        }

        ## 4. generate implied end tags
        pop @{$self->{open_elements}}
            while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;
        
        ## 5.
        if ($self->{open_elements}->[-1]->[0]->manakai_local_name ne $self->{t}->{tag_name}) { # XXX
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                          text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                          value => $self->{t}->{tag_name}, # actual
                          token => $self->{t});
        }

        ## 6.
        splice @{$self->{open_elements}}, $i;

        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
        h1 => 1, h2 => 1, h3 => 1, h4 => 1, h5 => 1, h6 => 1,
      }->{$self->{t}->{tag_name}}) {
        ## The "in body" insertion mode, <hn>

        ## has an element in scope
        my $i;
        INSCOPE: for (reverse 0..$#{$self->{open_elements}}) {
          my $node = $self->{open_elements}->[$_];
          if ($node->[1] == HEADING_EL) {
            $i = $_;
            last INSCOPE;
          } elsif ($node->[1] & SCOPING_EL) {
            last INSCOPE;
          }
        } # INSCOPE
        unless (defined $i) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                          text => $self->{t}->{tag_name},
                          token => $self->{t});
          ## Ignore the token.
          $self->{t} = $self->_get_next_token;
          next B;
        }

        ## Step 1. generate implied end tags
        pop @{$self->{open_elements}}
            while $self->{open_elements}->[-1]->[1] & END_TAG_OPTIONAL_EL;
        
        ## Step 2.
        unless (not ($self->{open_elements}->[-1]->[1] & FOREIGN_EL) and
                $self->{open_elements}->[-1]->[0]->local_name eq $self->{t}->{tag_name}) {
          $self->{parse_error}->(level => $self->{level}->{must}, type => 'not closed before ancestor end tag',
                          text => $self->{open_elements}->[-1]->[0]->local_name, # expected
                          value => $self->{t}->{tag_name}, # actual
                          token => $self->{t});
        }

        ## Step 3.
        splice @{$self->{open_elements}}, $i;
        
        $self->{t} = $self->_get_next_token;
        next B;

      } elsif ($self->{t}->{tag_name} eq 'p') {
        ## "In body" insertion mode, "p" start tag. As normal, except
        ## </p> implies <p> and ...
        $self->_close_p ([$insert, $open_tables]);
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ({
        a => 1,
        b => 1, big => 1, code => 1, em => 1, font => 1, i => 1,
        nobr => 1, s => 1, small => 1, strike => 1,
        strong => 1, tt => 1, u => 1,
      }->{$self->{t}->{tag_name}}) {
        ## The "in body" insertion mode, formatting end tags.
        $self->_aaa ($self->{t});
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'br') {
        
        $self->{parse_error}->(level => $self->{level}->{must}, type => 'unmatched end tag',
                        text => 'br', token => $self->{t});

        ## As if <br>
        my $insert = $self->{insertion_mode} & TABLE_IMS
            ? $insert_to_foster : $insert_to_current;
        $reconstruct_active_formatting_elements
            ->($self, $insert, $active_formatting_elements, $open_tables);
        
        my $el;
        
      $el = $self->{document}->create_element_ns
        (HTML_NS, [undef,  'br']);
    
        $el->set_user_data (manakai_source_line => $self->{t}->{line})
            if defined $self->{t}->{line};
        $el->set_user_data (manakai_source_column => $self->{t}->{column})
            if defined $self->{t}->{column};
      
        $insert->($self, $el, $open_tables);

        ## Acknowledge the token's self-closing flag - noop

        delete $self->{frameset_ok};
        
        $self->{t} = $self->_get_next_token;
        next B;
      } elsif ($self->{t}->{tag_name} eq 'template') {
        $template_end_tag->($self);
        next B;
      } else {
        if ($self->{t}->{tag_name} eq 'sarcasm') {
          ## Take a deep breath
        }
        $self->_in_body_any_other_end_tag;
        $self->{t} = $self->_get_next_token;
        next B;
      }
    }
    die "Token is not handled";
    #next B;
  } # B

  ## Stop parsing # MUST
  
  ## TODO: script stuffs
} # _tree_construct_main

sub parse_char_string_with_context ($$$$) {
  my $self = $_[0];
  # $s $_[1]
  my $context = $_[2]; # Element or undef
  # $empty_doc $_[3]

  ## HTML fragment parsing algorithm
  ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-html-fragments>

  # 1.
  my $doc = $_[3];
  $doc->manakai_is_html (1);
  $self->{document} = $doc;

  # 2.
  $doc->manakai_compat_mode ($context->owner_document->manakai_compat_mode)
      if defined $context;

  # 3.
  $self->{line_prev} = $self->{line} = 1;
  $self->{column_prev} = -1;
  $self->{column} = 0;

  $self->{chars} = [split //, $_[1]];
  $self->{chars_pos} = 0;
  $self->{chars_pull_next} = sub { 0 };
  delete $self->{chars_was_cr};

  my $ponerror = $self->onerror;
  $self->{parse_error} = sub {
    $ponerror->(line => $self->{line}, column => $self->{column}, @_);
  };

  $self->_initialize_tokenizer;
  $self->_initialize_tree_constructor;

  # 4.
  my $root;
  if (defined $context) {
    my $node_ns = $context->namespace_uri || '';
    my $node_ln = $context->local_name;
    if ($node_ns eq HTML_NS) {
      ## 4.1.
      if ($node_ln eq 'title' or $node_ln eq 'textarea') {
        $self->{state} = RCDATA_STATE;
      } elsif ($node_ln eq 'script') {
        $self->{state} = SCRIPT_DATA_STATE;
      } elsif ({
        style => 1,
        script => 1,
        xmp => 1,
        iframe => 1,
        noembed => 1,
        noframes => 1,
        noscript => 1, # $self->{scripting_flag}, # XXX
      }->{$node_ln}) {
        $self->{state} = RAWTEXT_STATE;
      } elsif ($node_ln eq 'plaintext') {
        $self->{state} = PLAINTEXT_STATE;
      }
      
      $self->{inner_html_node} = [$context, $el_category->{$node_ln} || 0];
    } elsif ($node_ns eq SVG_NS) {
      $self->{inner_html_node} = [$context,
                                  $el_category_f->{$node_ns}->{$node_ln}
                                      || FOREIGN_EL | SVG_EL];
    } elsif ($node_ns eq MML_NS) {
      $self->{inner_html_node} = [$context,
                                  $el_category_f->{$node_ns}->{$node_ln}
                                      || FOREIGN_EL | MML_EL];
    } else {
      $self->{inner_html_node} = [$context, FOREIGN_EL];
    }
    
    ## 4.2.
    $root = $doc->create_element_ns (HTML_NS, [undef, 'html']);

    ## 4.3.
    $doc->append_child ($root);

    ## 4.4.
    push @{$self->{open_elements}}, [$root, $el_category->{html}];
    $self->{open_tables} = [[$root]];
    undef $self->{head_element};

    ## 4.5.
    push @{$self->{template_ims}}, IN_TEMPLATE_IM
        if $node_ns eq HTML_NS and $node_ln eq 'template';

    ## 4.6.
    $self->_reset_insertion_mode;

    ## 4.7.
    my $anode = $context;
    while (defined $anode) {
      if ($anode->node_type == 1 and
          ($anode->namespace_uri || '') eq HTML_NS and
          $anode->local_name eq 'form') {
        $self->{form_element} = $anode;
        last;
      }
      $anode = $anode->parent_node;
    }
  } # $context

  # 5.
  $self->{confident} = 1; ## Confident: irrelevant.

  # 6.
  $self->{t} = $self->_get_next_token;
  $self->_construct_tree;

  $self->_on_terminate;

  # 7.
  return defined $context ? $root->child_nodes : $doc->child_nodes;
} # parse_char_string_with_context

1;

=head1 LICENSE

Copyright 2007-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
