
    package Web::Temma::Tokenizer;
    use strict;
    use warnings;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    use warnings FATAL => 'redefine';
    use warnings FATAL => 'uninitialized';
    use utf8;
    our $VERSION = '8.0';
    use Carp qw(croak);
    
    use Encode qw(decode); # XXX
    use Web::Encoding;
    use Web::HTML::ParserData;
    use Web::HTML::_SyntaxDefs;

    
        sub HTMLNS () { q<http://www.w3.org/1999/xhtml> }
      
    my $TagName2Group = {};

    ## ------ Common handlers ------

    sub new ($) {
      return bless {
        ## Input parameters
        # Scripting IframeSrcdoc DI known_definite_encoding locale_tag
        # di_data_set is_sub_parser

        ## Callbacks
        # onerror onerrors onappcacheselection onscript
        # onelementspopped onrestartwithencoding
        # onextentref onparsed

        ## Parser internal states
        # input_stream input_encoding saved_states saved_lists saved_maps
        # nodes document can_restart restart
        # parse_bytes_started transport_encoding_label
        # byte_bufer byte_buffer_orig
      }, $_[0];
    } # new

my $GetDefaultErrorHandler = sub {
  my $dids = $_[0]->di_data_set;
  return sub {
    my $error = {@_};
    require Web::HTML::SourceMap;
    my ($di, $index) = Web::HTML::SourceMap::resolve_index_pair ($dids, $error->{di}, $error->{index});
    my $text = defined $error->{text} ? qq{ - $error->{text}} : '';
    my $value = defined $error->{value} ? qq{ "$error->{value}"} : '';
    my $level = {
      m => 'Parse error',
      s => 'SHOULD-level error',
      w => 'Warning',
      i => 'Information',
    }->{$error->{level} || ''} || $error->{level};
    my $doc = 'document #' . $error->{di};
    if (not $di == -1) {
      my $did = $dids->[$di];
      if (defined $did->{name}) {
        $doc = $did->{name};
      } elsif (defined $did->{url}) {
        $doc = 'document <' . $did->{url} . '>';
      }
    }
    warn "$level ($error->{type}$text) at $doc index $index$value\n";
  };
}; # $GetDefaultErrorHandler

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= $GetDefaultErrorHandler->($_[0]);
} # onerror

sub onerrors ($;$) {
  if (@_ > 1) {
    $_[0]->{onerrors} = $_[1];
  }
  return $_[0]->{onerrors} || sub {
    my $onerror = $_[0]->onerror;
    $onerror->(%$_) for @{$_[1]};
  };
} # onerrors

sub onappcacheselection ($;$) {
  if (@_ > 1) {
    $_[0]->{onappcacheselection} = $_[1];
  }
  return $_[0]->{onappcacheselection} || sub { };
} # onappcacheselection

sub onscript ($;$) {
  if (@_ > 1) {
    $_[0]->{onscript} = $_[1];
  }
  return $_[0]->{onscript} || sub { };
} # onscript

sub onextentref ($;$) {
  if (@_ > 1) {
    $_[0]->{onextentref} = $_[1];
  }
  return $_[0]->{onextentref} || sub {
    my ($self, $data, $sub) = @_;
    $self->cant_expand_extentref ($data, $sub);
  };
} # onextentref

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

sub onelementspopped ($;$) {
  if (@_ > 1) {
    $_[0]->{onelementspopped} = $_[1];
  }
  return $_[0]->{onelementspopped} || sub { };
} # onelementspopped

sub onrestartwithencoding ($;$) {
  if (@_ > 1) {
    $_[0]->{onrestartwithencoding} = $_[1];
  }
  return $_[0]->{onrestartwithencoding} || sub {
    my ($self, $encoding) = @_;
    $self->known_definite_encoding ($encoding);
    $self->restart;
  };
} # onrestartwithencoding

    sub throw ($$) { $_[1]->() }

    sub restart ($) {
      unless ($_[0]->{can_restart}) {
        croak "The current parsing method can't restart the parser";
      }
      $_[0]->{restart} = 1;
    } # restart

    sub scripting ($;$) {
      if (@_ > 1) {
        $_[0]->{Scripting} = $_[1];
      }
      return $_[0]->{Scripting};
    } # scripting

    sub onparsed ($;$) {
      if (@_ > 1) {
        $_[0]->{onparsed} = $_[1];
      }
      return $_[0]->{onparsed} || sub { };
    } # onparsed

    sub _cleanup_states ($) {
      my $self = $_[0];
      delete $self->{input_stream};
      delete $self->{input_encoding};
      delete $self->{saved_states};
      delete $self->{saved_lists};
      delete $self->{saved_maps};
      delete $self->{nodes};
      delete $self->{document};
      delete $self->{can_restart};
      delete $self->{restart};
      delete $self->{pause};
      delete $self->{main_parser};
    } # _cleanup_states

    ## ------ Common defs ------
    our $AnchoredIndex;our $Attr;our $Callbacks;our $Confident;our $DI;our $EOF;our $Errors;our $IframeSrcdoc;our $Input;our $LastStartTagName;our $Offset;our $Scripting;our $State;our $Temp;our $TempIndex;our $Token;our $Tokens;
    ## ------ Tokenizer defs ------
    my $InvalidCharRefs = $Web::HTML::_SyntaxDefs->{charref_invalid};
sub DOCTYPE_TOKEN () { 1 }
sub COMMENT_TOKEN () { 2 }
sub END_TAG_TOKEN () { 3 }
sub END_OF_FILE_TOKEN () { 4 }
sub PROCESSING_INSTRUCTION_TOKEN () { 5 }
sub START_TAG_TOKEN () { 6 }
sub TEXT_TOKEN () { 7 }
sub CDATA_SECTION_BRACKET_STATE () { 1 }
sub CDATA_SECTION_END_STATE () { 2 }
sub CDATA_SECTION_STATE () { 3 }
sub CDATA_SECTION_STATE_CR () { 4 }
sub DOCTYPE_NAME_STATE () { 5 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE () { 6 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE_CR () { 7 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE () { 8 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE_CR () { 9 }
sub DOCTYPE_STATE () { 10 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE () { 11 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE_CR () { 12 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE () { 13 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE_CR () { 14 }
sub PLAINTEXT_STATE () { 15 }
sub PLAINTEXT_STATE_CR () { 16 }
sub RAWTEXT_END_TAG_NAME_STATE () { 17 }
sub RAWTEXT_END_TAG_OPEN_STATE () { 18 }
sub RAWTEXT_LESS_THAN_SIGN_STATE () { 19 }
sub RAWTEXT_STATE () { 20 }
sub RAWTEXT_STATE_CR () { 21 }
sub RCDATA_END_TAG_NAME_STATE () { 22 }
sub RCDATA_END_TAG_OPEN_STATE () { 23 }
sub RCDATA_LESS_THAN_SIGN_STATE () { 24 }
sub RCDATA_STATE () { 25 }
sub RCDATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE () { 26 }
sub RCDATA_STATE___CHARREF_DECIMAL_NUM_STATE () { 27 }
sub RCDATA_STATE___CHARREF_HEX_NUM_STATE () { 28 }
sub RCDATA_STATE___CHARREF_NAME_STATE () { 29 }
sub RCDATA_STATE___CHARREF_NUM_STATE () { 30 }
sub RCDATA_STATE___CHARREF_STATE () { 31 }
sub RCDATA_STATE___CHARREF_STATE_CR () { 32 }
sub RCDATA_STATE_CR () { 33 }
sub A_DOCTYPE_NAME_STATE () { 34 }
sub A_DOCTYPE_NAME_STATE_P () { 35 }
sub A_DOCTYPE_NAME_STATE_PU () { 36 }
sub A_DOCTYPE_NAME_STATE_PUB () { 37 }
sub A_DOCTYPE_NAME_STATE_PUBL () { 38 }
sub A_DOCTYPE_NAME_STATE_PUBLI () { 39 }
sub A_DOCTYPE_NAME_STATE_S () { 40 }
sub A_DOCTYPE_NAME_STATE_SY () { 41 }
sub A_DOCTYPE_NAME_STATE_SYS () { 42 }
sub A_DOCTYPE_NAME_STATE_SYST () { 43 }
sub A_DOCTYPE_NAME_STATE_SYSTE () { 44 }
sub A_DOCTYPE_PUBLIC_ID_STATE () { 45 }
sub A_DOCTYPE_PUBLIC_KWD_STATE () { 46 }
sub A_DOCTYPE_SYSTEM_ID_STATE () { 47 }
sub A_DOCTYPE_SYSTEM_KWD_STATE () { 48 }
sub A_ATTR_NAME_STATE () { 49 }
sub A_ATTR_VALUE__QUOTED__STATE () { 50 }
sub ATTR_NAME_STATE () { 51 }
sub ATTR_VALUE__DQ__STATE () { 52 }
sub ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE () { 53 }
sub ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUM_STATE () { 54 }
sub ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUM_STATE () { 55 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE () { 56 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NUM_STATE () { 57 }
sub ATTR_VALUE__DQ__STATE___CHARREF_STATE () { 58 }
sub ATTR_VALUE__DQ__STATE_CR () { 59 }
sub ATTR_VALUE__SQ__STATE () { 60 }
sub ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE () { 61 }
sub ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUM_STATE () { 62 }
sub ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUM_STATE () { 63 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE () { 64 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NUM_STATE () { 65 }
sub ATTR_VALUE__SQ__STATE___CHARREF_STATE () { 66 }
sub ATTR_VALUE__SQ__STATE_CR () { 67 }
sub ATTR_VALUE__UNQUOTED__STATE () { 68 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUM_STATE () { 69 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUM_STATE () { 70 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUM_STATE () { 71 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE () { 72 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUM_STATE () { 73 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE () { 74 }
sub ATTR_VALUE__UNQUOTED__STATE_CR () { 75 }
sub B_DOCTYPE_NAME_STATE () { 76 }
sub B_DOCTYPE_PUBLIC_ID_STATE () { 77 }
sub B_DOCTYPE_SYSTEM_ID_STATE () { 78 }
sub B_ATTR_NAME_STATE () { 79 }
sub B_ATTR_VALUE_STATE () { 80 }
sub BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE () { 81 }
sub BOGUS_DOCTYPE_STATE () { 82 }
sub BOGUS_COMMENT_STATE () { 83 }
sub BOGUS_COMMENT_STATE_CR () { 84 }
sub CHARREF_IN_RCDATA_STATE () { 85 }
sub CHARREF_IN_DATA_STATE () { 86 }
sub COMMENT_END_BANG_STATE () { 87 }
sub COMMENT_END_DASH_STATE () { 88 }
sub COMMENT_END_STATE () { 89 }
sub COMMENT_START_DASH_STATE () { 90 }
sub COMMENT_START_STATE () { 91 }
sub COMMENT_STATE () { 92 }
sub COMMENT_STATE_CR () { 93 }
sub DATA_STATE () { 94 }
sub DATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE () { 95 }
sub DATA_STATE___CHARREF_DECIMAL_NUM_STATE () { 96 }
sub DATA_STATE___CHARREF_HEX_NUM_STATE () { 97 }
sub DATA_STATE___CHARREF_NAME_STATE () { 98 }
sub DATA_STATE___CHARREF_NUM_STATE () { 99 }
sub DATA_STATE___CHARREF_STATE () { 100 }
sub DATA_STATE___CHARREF_STATE_CR () { 101 }
sub DATA_STATE_CR () { 102 }
sub END_TAG_OPEN_STATE () { 103 }
sub MDO_STATE () { 104 }
sub MDO_STATE__ () { 105 }
sub MDO_STATE_D () { 106 }
sub MDO_STATE_DO () { 107 }
sub MDO_STATE_DOC () { 108 }
sub MDO_STATE_DOCT () { 109 }
sub MDO_STATE_DOCTY () { 110 }
sub MDO_STATE_DOCTYP () { 111 }
sub MDO_STATE__5B () { 112 }
sub MDO_STATE__5BC () { 113 }
sub MDO_STATE__5BCD () { 114 }
sub MDO_STATE__5BCDA () { 115 }
sub MDO_STATE__5BCDAT () { 116 }
sub MDO_STATE__5BCDATA () { 117 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE () { 118 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR () { 119 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE () { 120 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR () { 121 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE () { 122 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE () { 123 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE () { 124 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_STATE () { 125 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR () { 126 }
sub SCRIPT_DATA_END_TAG_NAME_STATE () { 127 }
sub SCRIPT_DATA_END_TAG_OPEN_STATE () { 128 }
sub SCRIPT_DATA_ESCAPE_START_DASH_STATE () { 129 }
sub SCRIPT_DATA_ESCAPE_START_STATE () { 130 }
sub SCRIPT_DATA_ESCAPED_DASH_DASH_STATE () { 131 }
sub SCRIPT_DATA_ESCAPED_DASH_STATE () { 132 }
sub SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE () { 133 }
sub SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE () { 134 }
sub SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE () { 135 }
sub SCRIPT_DATA_ESCAPED_STATE () { 136 }
sub SCRIPT_DATA_ESCAPED_STATE_CR () { 137 }
sub SCRIPT_DATA_LESS_THAN_SIGN_STATE () { 138 }
sub SCRIPT_DATA_STATE () { 139 }
sub SCRIPT_DATA_STATE_CR () { 140 }
sub SELF_CLOSING_START_TAG_STATE () { 141 }
sub TAG_NAME_STATE () { 142 }
sub TAG_OPEN_STATE () { 143 }
 sub cant_expand_extentref ($$$) { } 

my $TokenizerAbortingTagNames = {
  title => 1,
  textarea => 1,
  plaintext => 1,
  style => 1,
  script => 1,
  xmp => 1,
  iframe => 1,
  noembed => 1,
  noframes => 1,
  noscript => 1,

  #html => 1, # for <html manifest> -> see the line with "first start tag"
  #meta => 1, # for <meta charset>
};
  


sub strict_checker ($;$) {
  if (@_ > 1) {
    $_[0]->{strict_checker} = $_[1];
  }
  return $_[0]->{strict_checker} || 'Web::XML::Parser::MinimumChecker';
} # strict_checker

  
    ## ------ Tree constructor defs ------
    my $StateByElementName = {};

    ## ------ Input byte stream ------
    

## ------ Character encoding processing ------

sub locale_tag ($;$) {
  if (@_ > 1) {
    $_[0]->{locale_tag} = $_[1];
    $_[0]->{locale_tag} =~ tr/A-Z/a-z/ if defined $_[0]->{locale_tag};
  }
  return $_[0]->{locale_tag};
} # locale_tag

sub known_definite_encoding ($;$) {
  if (@_ > 1) {
    $_[0]->{known_definite_encoding} = $_[1];
  }
  return $_[0]->{known_definite_encoding};
} # known_definite_encoding

## Encoding sniffing algorithm
## <http://www.whatwg.org/specs/web-apps/current-work/#determining-the-character-encoding>.
sub _encoding_sniffing ($;%) {
  my ($self, %args) = @_;

  ## One of followings:
  ##   - Step 1. User-specified encoding
  ##   - The new character encoding by change the encoding
  ##     <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>
  ##     step 5. Encoding from <meta charset>
  ##   - A known definite encoding
  my $kde = $self->known_definite_encoding;
  if (defined $kde) {
    ## If specified, it must be an encoding label from the Encoding
    ## Standard.
    my $name = Web::Encoding::encoding_label_to_name $kde;
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 1; # certain
      return;
    }
  }

  return if $args{no_body_data_yet};
  ## $args{no_body_data_yet} flag must be set to true if the body of
  ## the resource is not available to the parser such that
  ## $args{read_head} callback ought not be invoked yet.

  ## Step 2. Wait 500ms or 1024 bytes, whichever came first (See
  ## Web::HTML::Parser for how and when to use this callback).
  my $head = $args{read_head} ? $args{read_head}->() : undef;
  ## $args{read_head} must be a callback which, when invoked, returns
  ## a byte string used to sniff the character encoding of the input
  ## stream.  As described in the HTML Standard, it should be at most
  ## 1024 bytes.  The callback should not invoke sync I/O.  This
  ## method should be invoked with $args{no_body_data_yet} flag unset
  ## only after 500ms has past or 1024 bytes has been received.  The
  ## callback should not invoke any exception.

  ## Step 3. BOM
  ## XXX Now this step is part of "decode" in the specs
  if (defined $head) {
    if ($$head =~ /^\xFE\xFF/) {
      $self->{input_encoding} = 'utf-16be';
      $Confident = 1; # certain
      return;
    } elsif ($$head =~ /^\xFF\xFE/) {
      $self->{input_encoding} = 'utf-16le';
      $Confident = 1; # certain
      return;
    } elsif ($$head =~ /^\xEF\xBB\xBF/) {
      $self->{input_encoding} = 'utf-8';
      $Confident = 1; # certain
      return;
    }
  }

  ## Step 4. Transport-layer encoding
  if ($args{transport_encoding_name}) {
    ## $args{transport_encoding_name} must be specified iff the
    ## underlying protocol provides the character encoding for the
    ## input stream.  For HTTP, the |charset=""| parameter in the
    ## |Content-Type:| header specifies the character encoding.  The
    ## value is interpreted as an encoding name or alias defined in
    ## the Encoding Standard.  (Invalid encoding name will be
    ## ignored.)
    my $name = Web::Encoding::encoding_label_to_name $args{transport_encoding_name};
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 1; # certain
      return;
    }
  }

  ## Step 5. <meta charset>
  if (defined $head) {
    my $name = $self->_prescan_byte_stream ($$head);
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 6. Parent browsing context
  if ($args{parent_document}) {
    ## $args{parent_document}, if specified, must be the |Document|
    ## through which the new (to be parsed) document is nested, or the
    ## active document of the parent browsing context of the new
    ## document.

    # XXX
    # if $args{parent_document}->origin equals $self->document->origin and
    #    $args{parent_document}->charset is ASCII compatible {
    #   $self->{input_encoding} = $args{parent_document}->charset;
    #   $Confident = 0; # tentative
    #   return;
    # }
  }

  ## Step 7. History
  if ($args{get_history_encoding_name}) {
    ## EXPERIMENTAL: $args{get_history_encoding_name}, if specified,
    ## must be a callback which returns the canonical character
    ## encoding name for the input stream, guessed by e.g. last visit
    ## to this page.
    # XXX how to handle async access to history DB?
    my $name = Web::Encoding::encoding_label_to_name $args{get_history_encoding_name}->();
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. UniversalCharDet
  if (defined $head) {
    require Web::Encoding::UnivCharDet;
    my $det = Web::Encoding::UnivCharDet->new;
    # XXX locale-dependent configuration
    my $name = Web::Encoding::encoding_label_to_name $det->detect_byte_string ($$head);
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. Locale-dependent default
  my $locale = $self->locale_tag;
  if ($locale) {
    my $name = Web::Encoding::encoding_label_to_name (
        Web::Encoding::locale_default_encoding_name $locale ||
        Web::Encoding::locale_default_encoding_name [split /-/, $locale, 2]->[0]
    );
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. Default of default
  $self->{input_encoding} = Web::Encoding::encoding_label_to_name 'windows-1252';
  $Confident = 0; # tentative
  return;

  # XXX expose sniffing info for validator
} # _encoding_sniffing

# prescan a byte stream to determine its encoding
# <http://www.whatwg.org/specs/web-apps/current-work/#prescan-a-byte-stream-to-determine-its-encoding>
sub _prescan_byte_stream ($$) {
  # 1.
  (pos $_[1]) = 0;

  # 2.
  LOOP: {
    $_[1] =~ /\G<!--+>/gc;
    $_[1] =~ /\G<!--.*?-->/gcs;
    if ($_[1] =~ /\G<[Mm][Ee][Tt][Aa](?=[\x09\x0A\x0C\x0D\x20\x2F])/gc) {
      # 1.
      #

      # 2.-5.
      my $attr_list = {};
      my $got_pragma = 0;
      my $need_pragma = undef;
      my $charset;

      # 6.
      ATTRS: {
        my $attr = $_[0]->_get_attr ($_[1]) or last ATTRS;

        # 7.
        redo ATTRS if $attr_list->{$attr->{name}};
        
        # 8.
        $attr_list->{$attr->{name}} = $attr;

        # 9.
        if ($attr->{name} eq 'http-equiv') {
          $got_pragma = 1 if $attr->{value} eq 'content-type';
        } elsif ($attr->{name} eq 'content') {
          # algorithm for extracting a character encoding from a
          # |meta| element
          # <http://www.whatwg.org/specs/web-apps/current-work/#algorithm-for-extracting-a-character-encoding-from-a-meta-element>
          if (not defined $charset and
              $attr->{value} =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                                 [\x09\x0A\x0C\x0D\x20]*=
                                 [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                                 ([^"'\x09\x0A\x0C\x0D\x20]
                                  [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            $charset = Web::Encoding::encoding_label_to_name
                (defined $1 ? $1 : defined $2 ? $2 : $3);
            $need_pragma = 1;
          }
        } elsif ($attr->{name} eq 'charset') {
          $charset = Web::Encoding::encoding_label_to_name $attr->{value};
          $need_pragma = 0;
        }

        # 10.
        return undef if pos $_[1] >= length $_[1];
        redo ATTRS;
      } # ATTRS

      # 11. Processing, 12.
      if (not defined $need_pragma or
          ($need_pragma and not $got_pragma)) {
        #
      } elsif (defined $charset) {
        # 13.-14.
        $charset = Web::Encoding::fixup_html_meta_encoding_name $charset;

        # 15.-16.
        return $charset if defined $charset;
      }
    } elsif ($_[1] =~ m{\G</?[A-Za-z][^\x09\x0A\x0C\x0D\x20>]*}gc) {
      {
        $_[0]->_get_attr ($_[1]) and redo;
      }
    } elsif ($_[1] =~ m{\G<[!/?][^>]*}gc) {
      #
    }

    # 3. Next byte
    $_[1] =~ /\G[^<]+/gc || $_[1] =~ /\G</gc;
    return undef if pos $_[1] >= length $_[1];
    redo LOOP;
  } # LOOP
} # _prescan_byte_stream

# get an attribute
# <http://www.whatwg.org/specs/web-apps/current-work/#concept-get-attributes-when-sniffing>
sub _get_attr ($$) {
  # 1.
  $_[1] =~ /\G[\x09\x0A\x0C\x0D\x20\x2F]+/gc;

  # 2.
  if ($_[1] =~ /\G>/gc) {
    pos ($_[1])--;
    return undef;
  }
  
  # 3.
  my $attr = {name => '', value => ''};

  # 4.-5.
  if ($_[1] =~ m{\G([^\x09\x0A\x0C\x0D\x20/>][^\x09\x0A\x0C\x0D\x20/>=]*)}gc) {
    $attr->{name} .= $1;
    $attr->{name} =~ tr/A-Z/a-z/;
  }
  return undef if $_[1] =~ m{\G\z}gc;
  return $attr if $_[1] =~ m{\G(?=[/>])}gc;

  # 6.
  $_[1] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 7.-8.
  return $attr unless $_[1] =~ m{\G=}gc;

  # 9.
  $_[1] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 10.-12.
  if ($_[1] =~ m{\G\x22([^\x22]*)\x22}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[1] =~ m{\G\x27([^\x27]*)\x27}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[1] =~ m{\G([^\x09\x0A\x0C\x0D\x20>]+)}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  }
  return undef if $_[1] =~ m{\G\z}gc;
  return $attr;
} # _get_attr

sub _change_the_encoding ($$$) {
  my ($self, $name, $attr) = @_;

  ## "meta" start tag
  ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inhead>.

  ## "meta". Confidence is /tentative/
  #return undef if $Confident; # certain or irrelevant

  $name = Web::Encoding::encoding_label_to_name $name;
  unless (defined $name) {
    ## "meta". Supported encoding
    return undef;
  }

  ## "meta". ASCII-compatible or UTF-16
  ## All encodings in Encoding Standard are ASCII-compatible or UTF-16.

  ## Change the encoding
  ## <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>.

  ## Step 1. UTF-16
  if (Web::Encoding::is_utf16_encoding_key $self->{input_encoding}) {
    $Confident = 1; # certain
    return undef;
  }

  ## Step 2.-3.
  $name = Web::Encoding::fixup_html_meta_encoding_name $name;
  
  ## Step 4. Same
  if ($name eq $self->{input_encoding}) {
    $Confident = 1; # certain
    return undef;
  }

  push @$Errors, {type => 'charset label detected',
                  text => $self->{input_encoding},
                  value => $name,
                  level => 'i',
                  di => $attr->{di}, index => $attr->{index}};

  ## Step 5. Change the encoding on the fly
  ## Not implemented.

  ## Step 6. Navigate with replace.
  return $name; # change!

#XXX move this to somewhere else (when callback can't handle restart)
  ## Step 6. If can't restart
  $Confident = 1; # certain
  return undef;
} # _change_the_encoding

    sub di_data_set ($;$) {
      if (@_ > 1) {
        $_[0]->{di_data_set} = $_[1];
      }
      return $_[0]->{di_data_set} ||= [];
    } # di_data_set

    sub di ($;$) {
      if (@_ > 1) {
        $_[0]->{di} = $_[1];
      }
      return $_[0]->{di}; # or undef
    } # di

  
    ## ------ Tokenizer ------
    
    my $StateActions = [];
    $StateActions->[CDATA_SECTION_BRACKET_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 1};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = CDATA_SECTION_END_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 1};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_END_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]]@,
                          di => $DI, index => $Offset + (pos $Input) - 2};
        

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE] = sub {
if ($Input =~ /\G([^\\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = CDATA_SECTION_BRACKET_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = CDATA_SECTION_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = CDATA_SECTION_BRACKET_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = A_DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<name>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'no DOCTYPE name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[PLAINTEXT_STATE] = sub {
if ($Input =~ /\G([^\\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = PLAINTEXT_STATE_CR;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[PLAINTEXT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = PLAINTEXT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = PLAINTEXT_STATE_CR;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = PLAINTEXT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = PLAINTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = PLAINTEXT_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $LastStartTagName and
            $Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = RAWTEXT_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = RAWTEXT_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = RAWTEXT_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_STATE] = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = RAWTEXT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RAWTEXT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $LastStartTagName and
            $Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = RCDATA_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = RCDATA_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = RCDATA_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE] = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_DECIMAL_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
return 1 if $return;
} elsif ($Input =~ /\G([\&])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\<])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
return 1 if $return;
} elsif ($Input =~ /\G([\=])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
return 1 if $return;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
return 1 if $return;
} elsif ($Input =~ /\G(.)/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
return 1 if $return;
} else {
if ($EOF) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_DECIMAL_NUM_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = RCDATA_STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([P])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = A_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = A_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = A_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = A_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_P] = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PU;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PU;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_PU] = sub {
if ($Input =~ /\G([B])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUB;
} elsif ($Input =~ /\G([b])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUB;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_PUB] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUBL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUBL;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_PUBL] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_PUBLI] = sub {
if ($Input =~ /\G([C])/gcs) {
$State = A_DOCTYPE_PUBLIC_KWD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {
$State = A_DOCTYPE_PUBLIC_KWD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_S] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SY;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_SY] = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYS;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYS;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_SYS] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYST;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYST;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_SYST] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = A_DOCTYPE_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_NAME_STATE_SYSTE] = sub {
if ($Input =~ /\G([M])/gcs) {
$State = A_DOCTYPE_SYSTEM_KWD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {
$State = A_DOCTYPE_SYSTEM_KWD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_PUBLIC_KWD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_DOCTYPE_SYSTEM_KWD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {
$State = B_ATTR_VALUE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[A_ATTR_VALUE__QUOTED__STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\=\>ABCDEFGHJKNQRVWZILMOPSTUXY\ \"\'\<]+)/gcs) {
$Attr->{q<name>} .= $1;

} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
push @{$Attr->{q<value>}}, [$2, $DI, $Offset + $-[2]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
push @{$Attr->{q<value>}}, [$2, $DI, $Offset + $-[2]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
push @{$Attr->{q<value>}}, [$2, $DI, $Offset + $-[2]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = A_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
push @{$Attr->{q<value>}}, [$2, $DI, $Offset + $-[2]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = A_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + $-[1]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G[\	\
\\\ ][\	\
\\\ ]*\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\/\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\>/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = A_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = B_ATTR_VALUE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} else {
if ($EOF) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\&\ ]+)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
return 1 if $return;
} elsif ($Input =~ /\G([\"])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\&])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\=])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G(.)/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} else {
if ($EOF) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUM_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE] = sub {
if ($Input =~ /\G([^\\&\'\ ]+)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
return 1 if $return;
} elsif ($Input =~ /\G([\&])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\'])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
return 1 if $return;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\=])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G(.)/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} else {
if ($EOF) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUM_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = A_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\&\>\ \"\'\<\=\`]+)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\&])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\>])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
return 1 if $return;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([\"])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([\'])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([\<])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([\=])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G([\`])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} elsif ($Input =~ /\G(.)/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
return 1 if $return;
} else {
if ($EOF) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                    last REF;
                  } else {
                    ## <HTML>
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    ## </HTML>
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {type => 'entity not declared',
                              value => $Temp,
                              level => 'm',
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUM_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[B_DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[B_DOCTYPE_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[B_DOCTYPE_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[B_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;
} elsif ($Input =~ /\G\/\>/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\>/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[B_ATTR_VALUE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_DOCTYPE_STATE] = sub {
if ($Input =~ /\G([^\>]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_COMMENT_STATE] = sub {
if ($Input =~ /\G([^\ \\>]+)/gcs) {
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];

} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_COMMENT_STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\
])/gcs) {
$State = BOGUS_COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[CHARREF_IN_RCDATA_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = RCDATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[CHARREF_IN_DATA_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_BANG_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@--!@, $DI, $Offset + (pos $Input) - (length $1) - 3];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
push @{$Token->{q<data>}}, [q@--!@, $DI, $Offset + (pos $Input) - (length $1) - 3];
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@--!�@, $DI, $Offset + (pos $Input) - (length $1) - 3];
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Token->{q<data>}}, [q@--!@, $DI, $Offset + (pos $Input) - (length $1) - 3];
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + (pos $Input) - (length $1) - 1];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@-�@, $DI, $Offset + (pos $Input) - (length $1) - 1];
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + (pos $Input) - (length $1) - 1];
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@--�@, $DI, $Offset + (pos $Input) - (length $1) - 2];
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@--@, $DI, $Offset + (pos $Input) - (length $1) - 2];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\!])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = COMMENT_END_BANG_STATE;
} elsif ($Input =~ /\G([\-])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@--@, $DI, $Offset + (pos $Input) - (length $1) - 2];
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_START_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + (pos $Input) - (length $1) - 1];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@-�@, $DI, $Offset + (pos $Input) - (length $1) - 1];
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:comment closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + (pos $Input) - (length $1) - 1];
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_START_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_START_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:comment closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_STATE] = sub {
if ($Input =~ /\G([^\\-\ ]+)/gcs) {
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = COMMENT_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G(.)/gcs) {
$State = COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE] = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_DECIMAL_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_HEX_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        ## 
        }
        $Temp = chr $code;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
return 1 if $return;
} elsif ($Input =~ /\G([\&])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;
return 1 if $return;
} elsif ($Input =~ /\G([\<])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
return 1 if $return;
} elsif ($Input =~ /\G([\=])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
return 1 if $return;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
return 1 if $return;
} elsif ($Input =~ /\G(.)/gcs) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
return 1 if $return;
} else {
if ($EOF) {

          my $return;
          REF: {
            ## 

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  ## <HTML>
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};
                  ## </HTML>

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## 

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              ## 
            }
          } # REF
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_NUM_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_DECIMAL_NUM_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_BEFORE_HEX_NUM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DATA_STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUM_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = '';

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare etago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} = [[q@�@, $DI, $Offset + (pos $Input) - length $1]];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare etago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [[q@
@, $DI, $Offset + (pos $Input) - length $1]];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare etago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} = [[$1, $DI, $Offset + (pos $Input) - length $1]];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE] = sub {
if ($Input =~ /\G([\-])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;
} elsif ($Input =~ /\G([D])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\[])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} = [[q@�@, $DI, $Offset + (pos $Input) - length $1]];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [[q@
@, $DI, $Offset + (pos $Input) - length $1]];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} = [[$1, $DI, $Offset + (pos $Input) - length $1]];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__] = sub {
if ($Input =~ /\G([\-])/gcs) {

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
$State = COMMENT_START_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_D] = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DO;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DO;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DO] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOC;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOC;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOC] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCT] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTY;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCTY] = sub {
if ($Input =~ /\G([P])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTYP;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTYP;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCTYP] = sub {
if ($Input =~ /\G([E])/gcs) {
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([e])/gcs) {
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5B] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BC;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BC] = sub {
if ($Input =~ /\G([D])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCD;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCD] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDA;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDA] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDAT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDAT] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDATA;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDATA] = sub {
if ($Input =~ /\G([\[])/gcs) {
$State = CDATA_SECTION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [q@�@, $DI, $Offset + (pos $Input) - (length $1) - 0];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @{$Token->{q<data>}}, [q@
@, $DI, $Offset + (pos $Input) - (length $1) - 0];
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
$State = BOGUS_COMMENT_STATE;
push @{$Token->{q<data>}}, [$1, $DI, $Offset + (pos $Input) - (length $1)];
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
push @{$Token->{q<data>}}, [$Temp, $DI, $TempIndex];
push @$Tokens, $Token;
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@>@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@/@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_STATE] = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $LastStartTagName and
            $Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = SCRIPT_DATA_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = SCRIPT_DATA_END_TAG_NAME_STATE;
$Token->{q<tag_name>} = $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPE_START_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPE_START_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPE_START_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_DASH_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@>@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = B_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {

          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $LastStartTagName and
            $Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $Temp,
                          di => $DI,
                          index => $TempIndex} if length $Temp;
        

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE;
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE;
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_STATE] = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\!])/gcs) {
$State = SCRIPT_DATA_ESCAPE_START_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<!@,
                          di => $DI, index => $AnchoredIndex};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = SCRIPT_DATA_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_STATE] = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} else {
if ($EOF) {

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[SELF_CLOSING_START_TAG_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\/])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<tag_name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<tag_name>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_OPEN_STATE] = sub {
if ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
$State = COMMENT_START_DASH_STATE;
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + $-[2] - 1];
push @{$Token->{q<data>}}, [$2, $DI, $Offset + $-[2]];
push @{$Token->{q<data>}}, [$3, $DI, $Offset + $-[3]];
$State = COMMENT_END_DASH_STATE;
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + $-[4] - 1];
push @{$Token->{q<data>}}, [$4, $DI, $Offset + $-[4]];
$State = COMMENT_STATE;
push @{$Token->{q<data>}}, [$5, $DI, $Offset + $-[5]];
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]\]([^\\>\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = CDATA_SECTION_END_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $8,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $9,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [[$2, $DI, $Offset + $-[2]]];
push @{$Token->{q<data>}}, [$3, $DI, $Offset + $-[3]];
$State = COMMENT_END_DASH_STATE;
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + $-[4] - 1];
push @{$Token->{q<data>}}, [$4, $DI, $Offset + $-[4]];
$State = COMMENT_STATE;
push @{$Token->{q<data>}}, [$5, $DI, $Offset + $-[5]];
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = B_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]([^\\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = CDATA_SECTION_BRACKET_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 1};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $8,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $9,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)([^\\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $8,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $9,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
$State = COMMENT_START_DASH_STATE;
push @{$Token->{q<data>}}, [q@-@, $DI, $Offset + $-[2] - 1];
push @{$Token->{q<data>}}, [$2, $DI, $Offset + $-[2]];
push @{$Token->{q<data>}}, [$3, $DI, $Offset + $-[3]];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]\]\]/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = CDATA_SECTION_END_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [[$2, $DI, $Offset + $-[2]]];
push @{$Token->{q<data>}}, [$3, $DI, $Offset + $-[3]];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]\]\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = DATA_STATE;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]\]\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = CDATA_SECTION_END_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\]\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$State = CDATA_SECTION_BRACKET_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@]@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 1};
        
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G\!(\-)\-\-\-\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = [['', $DI, $Offset + pos $Input]];
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\/\>/gcs) {
$State = DATA_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = '';

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == END_TAG_TOKEN) {
            ## 
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            ## 
          }
        
} elsif ($Input =~ /\G([\!])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = chr ((ord $1) + 32);
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} = $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'pio', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0, 
                  di => $DI, index => $AnchoredIndex};
      
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} = [[$1, $DI, $Offset + (pos $Input) - length $1]];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare stago', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        
return 1;
} else {
return 1;
}
}
return 0;
};

    sub _tokenize ($) {
      TOKENIZER: while (1) {
        my $code = $StateActions->[$State]
            or die "Unknown state |$State|";
        &$code and last TOKENIZER;
      } # TOKENIZER
    } # _tokenize
  
    ## ------ Tree constructor ------
    
       sub _construct_tree ($) {
         my $self = $_[0];
         my $state = $self->ontokens->($self, $Tokens);
         if (defined $state) {
           if ($state eq 'script data state') {
             $State = SCRIPT_DATA_STATE;
           } elsif ($state eq 'RCDATA state') {
             $State = RCDATA_STATE;
           } elsif ($state eq 'RAWTEXT state') {
             $State = RAWTEXT_STATE;
           }
         }
         @$Tokens = ();
       } # _construct_tree

       sub ontokens ($;$) {
         if (@_ > 1) {
           $_[0]->{ontokens} = $_[1];
         }
         return $_[0]->{ontokens} || sub { };
       } # ontokens
     
    ## ------ DOM integration ------
    
    ## ------ API ------
    
    sub _run ($) {
      my ($self) = @_;
      return 1 if $self->{pause};
      my $is = $self->{input_stream};
      # XXX rewrite loop conditions
      my $length = @$is == 0 ? 0 : defined $is->[0]->[0] ? length $is->[0]->[0] : 0;
      my $in_offset = 0;
      {
        my $len = 10000;
        $len = $length - $in_offset if $in_offset + $len > $length;
        if ($len > 0) {
          $Input = substr $is->[0]->[0], $in_offset, $len;
        } elsif (@$is and not defined $is->[0]->[0]) {
          $Input = '';
          pos ($Input) = 0;
          $EOF = 1;
        } else {
          shift @$is;
          if (@$is) {
            if (defined $is->[0]->[0]) {
              $length = length $is->[0]->[0];
              $in_offset = 0;
              redo;
            } else {
              $Input = '';
              pos ($Input) = 0;
              $EOF = 1;
            }
          } else {
            last;
          }
        }
        {
          $self->_tokenize;
          $self->_construct_tree;

          if (@$Callbacks or @$Errors or $self->{is_sub_parser}) {
            $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, Confident => $Confident, DI => $DI, EOF => $EOF, LastStartTagName => $LastStartTagName, Offset => $Offset, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};
            {
              my $Errors = $Errors;
              my $Callbacks = $Callbacks;

              $self->onerrors->($self, $Errors) if @$Errors;
              @$Errors = ();
              while (@$Callbacks) {
                my $cb = shift @$Callbacks;
                $cb->[0]->($self, $cb->[1]);
              }

              if ($self->{restart}) {
                delete $self->{restart};
                return 0;
              }

              if ($self->{pause}) {
                my $pos = pos $Input;
                $is->[0] = [substr $is->[0]->[0], $in_offset + $pos]
                    if defined $is->[0]->[0];
                $Offset += $pos;
                $self->{saved_states}->{Offset} = $Offset;
                return 1;
              }
            }
            ($AnchoredIndex, $Attr, $Confident, $DI, $EOF, $LastStartTagName, $Offset, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr Confident DI EOF LastStartTagName Offset State Temp TempIndex Token)};
($Callbacks, $Errors, $Tokens) = @{$self->{saved_lists}}{qw(Callbacks Errors Tokens)};
() = @{$self->{saved_maps}}{qw()};
          }

          redo unless pos $Input == length $Input; # XXX parser pause flag
        }
        $Offset += $len;
        $in_offset += $len;
        redo unless $EOF;
      }
      if ($EOF) {
## 
        $self->onparsed->($self);
        $self->_cleanup_states;
      }
      return 1;
    } # _run
  

    sub _feed_chars ($$) {
      my ($self, $input) = @_;
      pos ($input->[0]) = 0;
      while ($input->[0] =~ /[\x{0001}-\x{0008}\x{000B}\x{000E}-\x{001F}\x{007F}-\x{009F}\x{D800}-\x{DFFF}\x{FDD0}-\x{FDEF}\x{FFFE}-\x{FFFF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gc) {
        my $index = $-[0];
        my $char = ord substr $input->[0], $index, 1;
        if ($char < 0x100) {
          push @$Errors, {type => 'control char', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        } elsif ($char < 0xE000) {
          push @$Errors, {type => 'char:surrogate', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        } else {
          push @$Errors, {type => 'nonchar', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        }
      }
      push @{$self->{input_stream}}, $input;

      return $self->_run;
    } # _feed_chars
  

    sub _feed_eof ($) {
      my $self = $_[0];
      push @{$self->{input_stream}}, [undef];
      return $self->_run;
    } # _feed_eof
  

    sub parse_char_string ($$$) {
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      $self->{document} = my $doc = $_[2];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      ## <HTML>
      $doc->manakai_is_html (1);
      ## </HTML>
      ## 
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];
      local ($AnchoredIndex, $Attr, $Callbacks, $Confident, $DI, $EOF, $Errors, $IframeSrcdoc, $Input, $LastStartTagName, $Offset, $Scripting, $State, $Temp, $TempIndex, $Token, $Tokens);
      $AnchoredIndex = 0;
$Offset = 0;
$self->{saved_lists} = {Callbacks => ($Callbacks = []), Errors => ($Errors = []), Tokens => ($Tokens = [])};
$self->{saved_maps} = {};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $Confident = 1; # irrelevant
      $State = DATA_STATE;;
      ## 

      $self->{input_stream} = [];
      my $dids = $self->di_data_set;
      $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
      $dids->[$DI] ||= {} if $DI >= 0;
      ## 
      $doc->manakai_set_source_location (['', $DI, 0]);

      local $self->{onextentref};
      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      return;
    } # parse_char_string
  

    1;

=head1 LICENSE

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This library derived from a JSON file, which contains data extracted
from HTML Standard.  "Written by Ian Hickson (Google, ian@hixie.ch) -
Parts Â© Copyright 2004-2014 Apple Inc., Mozilla Foundation, and Opera
Software ASA; You are granted a license to use, reproduce and create
derivative works of this document."

=cut

  