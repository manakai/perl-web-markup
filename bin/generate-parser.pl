package TreeParser::ig3;
use strict;
use warnings;
use Path::Tiny;
use JSON::PS;


my $GeneratedPackageName = q{Web::HTML::Parser};
my $DefDataPath = path (__FILE__)->parent->parent->child (q{local});
my $UseLibCode = q{};

# XXX indexes and parse errors
# XXX fragment parsing

sub new ($) {
  return bless {}, $_[0];
} # new

sub package_name { $GeneratedPackageName }

sub _expanded_tokenizer_defs ($) {
  my $expanded_json_path = $DefDataPath->child
      ('html-tokenizer-expanded.json');
  return json_bytes2perl $expanded_json_path->slurp;
} # _expanded_tokenizer_defs

sub _parser_defs ($) {
  my $expanded_json_path = $DefDataPath->child
      ('html-tree-constructor-expanded-no-isindex.json');
  return json_bytes2perl $expanded_json_path->slurp;
} # _parser_defs

sub _element_defs ($) {
  my $json_path = $DefDataPath->child ('elements.json');
  return json_bytes2perl $json_path->slurp;
} # _element_defs

my $Vars = {
  Scripting => {input => 1, type => 'boolean'},
  IframeSrcdoc => {input => 1, type => 'boolean'},
  Confident => {save => 1, type => 'boolean'},
  EOF => {save => 1, type => 'boolean'},
  Offset => {save => 1, type => 'index', default => 0},
  State => {save => 1, type => 'enum'},
  Token => {save => 1, type => 'struct?'},
  Attr => {save => 1, type => 'struct?'},
  Temp => {save => 1, type => 'string?'},
  LastStartTagName => {save => 1, type => 'string?'},
  IM => {save => 1, type => 'enum'},
  TEMPLATE_IMS => {unchanged => 1, type => 'list'},
  ORIGINAL_IM => {save => 1, type => 'enum?'},
  FRAMESET_OK => {save => 1, type => 'boolean', default => 'true'},
  QUIRKS => {save => 1, type => 'boolean'},
  NEXT_ID => {save => 1, type => 'index', default => 1},
  HEAD_ELEMENT => {save => 1, type => 'struct?'},
  FORM_ELEMENT => {save => 1, type => 'struct?'},
  CONTEXT => {input => 1, type => 'struct?'},
  OE => {unchanged => 1, type => 'list'},
  AFE => {unchanged => 1, type => 'list'},
  TABLE_CHARS => {unchanged => 1, type => 'list'},
  Tokens => {unchanged => 1, type => 'list'},
  Errors => {unchanged => 1, type => 'list'},
  OP => {unchanged => 1, type => 'list'},
  Input => {type => 'string'},
  InForeign => {type => 'boolean'},
  Callbacks => {unchanged => 1, type => 'list'},
};

## ------ Input byte stream ------

sub generate_input_bytes_handler ($) {
  my @code;

  push @code, q{

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
  $self->{input_encoding} = 'windows-1252';
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
  if ($self->{input_encoding} eq 'utf-16le' or
      $self->{input_encoding} eq 'utf-16be') {
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
                  token => $attr};

  ## Step 5. Change the encoding on the fly
  ## Not implemented.

  ## Step 6. Navigate with replace.
  return $name; # change!

#XXX move this to somewhere else (when callback can't handle restart)
  ## Step 6. If can't restart
  $Confident = 1; # certain
  return undef;
} # _change_the_encoding

  };

  return join "\n", @code;
} # generate_input_bytes_handler

## ------ Tokenizer ------

my $TOKEN_TYPE_TO_NAME = [];
my $TOKEN_NAME_TO_TYPE = {};
my $ShortTokenTypeToTokenTypeID = {};
my $StateNameToStateConst = {};

sub state_const ($) {
  my $s = uc shift;
  $s =~ s/ -- / /g;
  $s =~ s/\[/_5B/g;
  $s =~ s/\]/_5D/g;
  $s =~ s/[^A-Z0-9]/_/g;
  $s =~ s/CHARACTER_REFERENCE/CHARREF/g;
  $s =~ s/MARKUP_DECLARATION_OPEN/MDO/g;
  $s =~ s/DOUBLE_QUOTED/DQ/g;
  $s =~ s/SINGLE_QUOTED/SQ/g;
  $s =~ s/ATTRIBUTE/ATTR/g;
  $s =~ s/HEXADECIMAL/HEX/g;
  $s =~ s/IDENTIFIER/ID/g;
  $s =~ s/AFTER_000D/CR/g;
  return $s;
} # state_const

sub ns_const ($) {
  return ((uc $_[0]) . 'NS');
}

sub im_const ($) {
  my $const = uc shift;
  $const =~ s/([^A-Za-z0-9])/_/g;
  return $const . '_IM';
} # im_const

sub serialize_actions ($) {
  ## Generate |return 1| to abort tokenizer, |return 0| to abort
  ## current steps.
  my @result;
  my $reconsume;
  for (@{$_[0]->{actions}}) {
    my $type = $_->{type};
    if ($type eq 'parse error') {
      push @result, sprintf q[
        push @$Errors, {type => '%s', level => 'm',
                        index => $Offset + pos $Input};
      ], $_->{name};
    } elsif ($type eq 'switch') {
      if (not defined $_->{if}) {
        push @result, sprintf q[$State = %s;], state_const $_->{state};
      } elsif ($_->{if} eq 'appropriate end tag') {
        die unless $_->{break};
        push @result, sprintf q[
          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = %s;
            return 1;
          }
        ], state_const $_->{state};
      } elsif ($_->{if} eq 'in-foreign') {
        die unless $_->{break};
        push @result, sprintf q{
          if (not defined $InForeign) {
            pos ($Input) -= length $1;
            return 1;
          } else {
            if ($InForeign) {
              $State = %s;
              return 0;
            }
          }
        }, state_const $_->{state};
      } else {
        die "Unknown if |$_->{if}|";
      }
    } elsif ($type eq 'switch-and-emit') {
      die "Unknown if |$_->{if}|" unless $_->{if} eq 'appropriate end tag';
      die unless $_->{break};
      push @result, sprintf q[
        if ($Token->{tag_name} eq $LastStartTagName) {
          $State = %s;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      ], state_const $_->{state}, $_->{break};
    } elsif ($type eq 'switch-by-temp') {
      push @result, sprintf q[
        if ($Temp eq 'script') {
          $State = %s;
        } else {
          $State = %s;
        }
      ], state_const $_->{script_state}, state_const $_->{state};
    } elsif ($type eq 'reconsume') {
      $reconsume = 1;
    } elsif ($type eq 'emit') {
      if ($_->{possible_token_types}->{'end tag token'}) {
        push @result, q{
          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        };
      }
      push @result, q[push @$Tokens, $Token;];
      if ($_->{possible_token_types}->{'start tag token'}) {
        push @result, q{
          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
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
        };
      }
      if ($_->{possible_token_types}->{'end tag token'}) {
        push @result, q{
          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        };
      }
    } elsif ($type eq 'emit-eof') {
      push @result, q{
        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      };
    } elsif ($type eq 'emit-temp') {
      push @result, q{
        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      };
    } elsif ($type eq 'create') {
      push @result, sprintf q{
        $Token = {type => %s_TOKEN, tn => 0, index => $Offset + pos $Input};
      }, map { s/ token$//; s/[- ]/_/g; uc $_ } $_->{token};
    } elsif ($type eq 'create-attr') {
      push @result, q[$Attr = {index => $Offset + pos $Input};];
    } elsif ($type eq 'set-attr') {
      push @result, q{
        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      };
    } elsif ($type eq 'set' or
             $type eq 'set-to-attr' or
             $type eq 'set-to-temp' or
             $type eq 'append' or
             $type eq 'emit-char' or
             $type eq 'append-to-attr' or
             $type eq 'append-to-temp') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      die if defined $field and $field eq 'type';
      my $value;
      my $index = $_->{capture_index} || 1;
      if (defined $_->{value}) {
        $value = sprintf q[q@%s@], $_->{value};
      } elsif (defined $_->{offset}) {
        $value = sprintf q[chr ((ord $%d) + %d)],
            $index, $_->{offset};
      } else {
        $value = sprintf q[$%d], $index;
      }
      if ($type eq 'set') {
        push @result, sprintf q[$Token->{q<%s>} = %s;], $field, $value;
      } elsif ($type eq 'set-to-attr') {
        push @result, sprintf q[$Attr->{q<%s>} = %s;], $field, $value;
      } elsif ($type eq 'set-to-temp') {
        push @result, sprintf q[$Temp = %s;], $value;
      } elsif ($type eq 'append') {
        push @result, sprintf q[$Token->{q<%s>} .= %s;], $field, $value;
      } elsif ($type eq 'append-to-attr') {
        push @result, sprintf q[$Attr->{q<%s>} .= %s;], $field, $value;
      } elsif ($type eq 'append-to-temp') {
        push @result, sprintf q[$Temp .= %s;], $value;
      } elsif ($type eq 'emit-char') {
        push @result, sprintf q{
          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => %s,
                          index => $Offset + pos $Input};
        }, $value;
      }
    } elsif ($type eq 'set-empty') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Token->{q<%s>} = '';], $field;
    } elsif ($type eq 'set-empty-to-attr') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Attr->{q<%s>} = '';], $field;
    } elsif ($type eq 'set-empty-to-temp') {
      push @result, q[$Temp = '';];
    } elsif ($type eq 'append-temp') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Token->{q<%s>} .= $Temp;], $field;
    } elsif ($type eq 'append-temp-to-attr') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Attr->{q<%s>} .= $Temp;], $field;
    } elsif ($type eq 'set-flag') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Token->{q<%s>} = 1;], $field;
    } elsif ($type eq 'process-temp-as-decimal') {
      push @result, q{
        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      };
    } elsif ($type eq 'process-temp-as-hexadecimal') {
      push @result, q{
        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      };
    } elsif ($type eq 'process-temp-as-named') {
      if ($_->{in_attr}) {
        push @result, sprintf q{
          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (%d) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        }, !!$_->{before_equals};
      } else { # in content
        push @result, q{
          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        };
      }
    } else {
      die "Bad action type |$type|";
    }
  }
  push @result, q[pos ($Input)--;] if $reconsume;
  return join '', map { $_ . "\n" } @result;
} # serialize_actions

sub generate_tokenizer {
  my $self = shift;
  
  my $defs = $self->_expanded_tokenizer_defs->{tokenizer};
  my @def_code;

  my $next_token_type_id = 1;
  for my $key (sort { $a cmp $b } keys %{$defs->{tokens}}) {
    my $const_name = uc $key;
    $const_name =~ s/([^A-Z0-9])/_/g;
    my $short_name = $defs->{tokens}->{$key}->{short_name};
    my $id = $next_token_type_id++;
    $TOKEN_TYPE_TO_NAME->[$id] = $const_name;
    $TOKEN_NAME_TO_TYPE->{$const_name} = $id;
    $ShortTokenTypeToTokenTypeID->{$short_name} = $id;
    push @def_code, sprintf q{sub %s () { %d }}, $const_name, $id;
  }

  my @sub_code;
  my $next_state_id = 1;
  for my $state (sort { $a cmp $b } keys %{$defs->{states}}) {
    {
      my $const = state_const $state;
      push @def_code, sprintf q{sub %s () { %d }},
          $const, $next_state_id;
      $StateNameToStateConst->{$state} = $const;
      $next_state_id++;
    }
    my $code = sprintf q[$StateActions->[%s] = sub {]."\n",
        $StateNameToStateConst->{$state};
    my $else_key;
    my $non_else_chars = '';
    my $cond_has_error = {};
    my @case;
    for my $cond (keys %{$defs->{states}->{$state}->{conds}}) {
      if ($cond =~ /EOF/) {
        $cond_has_error->{$cond} = 1;
        next;
      }
      for (@{$defs->{states}->{$state}->{conds}->{$cond}->{actions}}) {
        if ($_->{type} eq 'parse error') {
          $cond_has_error->{$cond} = 2;
          last;
        }
      }
    }
    for my $pattern (sort { length $b <=> length $a } keys %{$defs->{states}->{$state}->{compound_conds} or {}}) {
      my $case = sprintf q[if ($Input =~ /\G%s/gcs) {]."\n", $pattern;
      $case .= serialize_actions ($defs->{states}->{$state}->{compound_conds}->{$pattern});
      $case .= q[} els];
      push @case, $case;
    }
    my $eof_cond;
    for my $cond (sort { ($cond_has_error->{$a} or 0) <=> ($cond_has_error->{$b} or 0) or
                         $a cmp $b } keys %{$defs->{states}->{$state}->{conds}}) {
      ($else_key = $cond and next) if " $cond " =~ / ELSE /;
      my $has_eof;
      my $chars = quotemeta join '', map {
        if ($_ eq 'EOF') {
          $has_eof = 1;
          ();
         } else {
           chr hex $_;
         }
      } split /[ ,]/, $cond;
      $non_else_chars .= $chars;
      my $cc;
      my $repeat = $defs->{states}->{$state}->{conds}->{$cond}->{repeat} ? '+' : '';
      if ($has_eof and length $chars) {
        die "Both EOF and chars";
        #$cc = sprintf q<\G([%s]%s|\z)>, $chars, $repeat;
      } elsif ($has_eof) {
        $eof_cond = $cond;
      } elsif (length $chars) {
        $cc = sprintf q<\G([%s]%s)>, $chars, $repeat;
        my $case = sprintf q[if ($Input =~ /%s/gcs) {]."\n", $cc;
        $case .= serialize_actions ($defs->{states}->{$state}->{conds}->{$cond});
        $case .= q[} els];
        push @case, $case;
      } else {
        die "empty cond";
        #$cc = '\G(?=_)X'.'XX';
      }
    }
    { # ELSE
      if ($defs->{states}->{$state}->{conds}->{$else_key}->{repeat}) {
        my $case = sprintf q[if ($Input =~ /\G([^%s]+)/gcs) {]."\n",
            $non_else_chars;
        $case .= serialize_actions ($defs->{states}->{$state}->{conds}->{$else_key});

$case .= q[
];

        $case .= q[} els];
        unshift @case, $case;
      } else {
        my $case = q[if ($Input =~ /\G(.)/gcs) {]."\n";
        $case .= serialize_actions ($defs->{states}->{$state}->{conds}->{$else_key});
        $case .= q[} els];
        push @case, $case;
      }
    }
    { ## EOF
      my $case = q<e {> . "\n";
      $case .= q[if ($EOF) {] . "\n";
      $case .= serialize_actions ($defs->{states}->{$state}->{conds}->{$eof_cond});
      $case .= q[} else {]."\n";
      $case .= q[return 1;]."\n";
      $case .= q[}]."\n";
      $case .= q<}>."\n";
      push @case, $case;
    }
    $code .= join '', @case;
    $code .= "return 0;\n";
    $code .= q[};];
    push @sub_code, $code;
  } # $state

  push @def_code, q{
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
  };

  my $generated = sprintf q[
    my $StateActions = [];
    %s

    sub _tokenize ($) {
      TOKENIZER: while (1) {
        my $code = $StateActions->[$State]
            or die "Unknown state |$State|";
        &$code and last TOKENIZER;
      } # TOKENIZER
    } # _tokenize
  ],
      (join "\n", @sub_code);

  my $def_code = join "\n", @def_code;
  return ($def_code, $generated);
}

## ------ Tree constructor ------

our $Defs;
my $im_to_id;
my $IM_ID_TO_NAME = [];

my $GROUP_ID_TO_NAME = [];
my $TAG_NAME_TO_GROUP = {};
my $GroupNameToElementTypeConst = {};
my $ElementToElementGroupExpr = {};

sub node_expr_to_code ($) {
  my $pattern = shift;
  if ($pattern =~ /^oe\[(-?[0-9]+)\]$/) {
    return sprintf q{$OE->[%d]}, $1;
  } elsif ($pattern eq 'node') {
    return sprintf q{$_node};
  } elsif ($pattern eq 'head element pointer') {
    return sprintf q{$HEAD_ELEMENT};
  } elsif ($pattern eq 'form element pointer') {
    return sprintf q{$FORM_ELEMENT};
  } else {
    die "Bad pattern |$pattern|";
  }
} # node_expr_to_code

sub pattern_to_code ($$);
sub pattern_to_code ($$) {
  my ($pattern, $var) = @_;
  if (not ref $pattern) {
    if ($pattern =~ /^oe\[(-?[0-9]+)\]$/) {
      return sprintf q{%s eq $OE->[%d]}, $var, $1;
    } elsif ($pattern eq 'node') {
      return sprintf q{%s eq $_node}, $var;
    } elsif ($pattern eq 'head element pointer') {
      return sprintf q{$HEAD_ELEMENT eq %s}, $var;
    } elsif ($pattern eq 'form element pointer') {
      return sprintf q{$FORM_ELEMENT eq %s}, $var;
    } elsif ($pattern eq 'HTML-same-tag-name') {
      return sprintf q{%s->{et} & HTML_NS_ELS and %s->{local_name} eq $token->{tag_name}}, $var, $var;
    } else {
      my @const;
      for (split / /, $pattern) {
        my $const = $GroupNameToElementTypeConst->{$_}
            or die "|$_| has no const";
        push @const, $const;
      }
      if (@const == 1 and $const[0] =~ /_EL$/) {
        return sprintf q{%s->{et} == %s},
            $var, $const[0];
      } else {
        return sprintf q{%s->{et} & (%s)},
            $var, join ' | ', @const;
      }
    }
  } elsif (ref $pattern eq 'ARRAY' and $pattern->[0] eq 'or') {
    return join ' or ', map { '(' . pattern_to_code ($_, $var) . ')' } @$pattern[1..$#$pattern];
  } elsif (not ref $pattern eq 'HASH') {
    use Data::Dumper;
    warn "Bad pattern";
    die Dumper $pattern;
  } elsif ($pattern->{same_tag_name_as_token}) {
    my $name_pattern;
    if ($pattern->{_lc}) {
      die if defined $pattern->{ns};
      return sprintf q{(
        %s->{local_name} eq $token->{tag_name} or
        do {
          my $ln = %s->{local_name};
          $ln =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $ln eq $token->{tag_name};
        }
      )}, $var, $var;
    } else {
      die if not defined $pattern->{ns};
      return sprintf q{%s->{ns} == %s and %s->{local_name} eq $token->{tag_name}},
          $var, ns_const $pattern->{ns}, $var;
    }
  } else {
    die "Broken pattern @{[join ' ', %$pattern]}";
  }
} # pattern_to_code

sub cond_to_code ($);
sub cond_to_code ($) {
  my $cond = shift;
  if ($cond->[0] eq 'and') {
    return join " and \n", map { '(' . (cond_to_code $_) . ')' } @$cond[1..$#$cond];
  } elsif ($cond->[0] eq 'or') {
    return join " or \n", map { '(' . (cond_to_code $_) . ')' } @$cond[1..$#$cond];
  } elsif ($cond->[0] eq 'oe') {
    my $cond1 = 'if';
    my $cond2 = '';
    if ($cond->[1] eq 'in scope') {
      #
    } elsif ($cond->[1] eq 'in scope not') {
      $cond1 = 'unless';
    } elsif ($cond->[1] eq 'not in scope') {
      $cond2 = 'not';
    } elsif ($cond->[1] eq 'is empty') {
      return q{not @$OE};
    } else {
      die "Unknown cond expr |$cond->[1]|";
    }
    my $scope_code = '';
    if ($cond->[2] eq 'scope') {
      my $p = $Defs->{tree_patterns}->{'has an element in scope'}
          or die "No pattern definition";
      $scope_code = sprintf q<} elsif (%s) { last; >,
          pattern_to_code $p, '$_';
    } elsif ($cond->[2] eq 'all') {
      #
    } else {
      my $p = $Defs->{tree_patterns}->{"has an element in $cond->[2] scope"};
      if ($p) {
        $scope_code = sprintf q<} elsif (%s) { last; >,
            pattern_to_code $p, '$_';
      } else {
        my $p = $Defs->{tree_patterns_not}->{"has an element in $cond->[2] scope"};
        if ($p) {
          $scope_code = sprintf q<} elsif (not (%s)) { last; >,
              pattern_to_code $p, '$_';
        } else {
          die "No pattern definition for scope |$cond->[2]|";
        }
      }
    }
    return sprintf q{
      do {
        my $result = 0;
        for (reverse @$OE) {
          %s (%s) {
            $result = 1;
            last;
          %s
          }
        }
        %s $result;
      }
    }, $cond1, pattern_to_code ($cond->[3], '$_'), $scope_code, $cond2;
  } elsif ($cond->[0] eq 'afe' and
           $cond->[1] eq 'in scope' and
           $cond->[2] eq 'marker') {
    return sprintf q{
      do {
        my $result = 0;
        for (reverse @$AFE) {
          last if not ref $_;
          if (%s) {
            $result = 1;
            last;
          }
        }
        $result;
      }
    }, pattern_to_code ($cond->[3], '$_');
  } elsif ($cond->[0] =~ /^oe\[-?[0-9]+\]$/ or $cond->[0] eq 'node') {
    my $left = node_expr_to_code $cond->[0];
    if ($cond->[1] eq 'is') {
      return pattern_to_code $cond->[2], $left;
    } elsif ($cond->[1] eq 'is not') {
      return sprintf q{not (%s)}, pattern_to_code $cond->[2], $left;
    } elsif ($cond->[1] eq 'lc is') {
      return pattern_to_code {%{$cond->[2]}, _lc => 1}, $left;
    } elsif ($cond->[1] eq 'lc is not') {
      return sprintf q{not (%s)}, pattern_to_code {%{$cond->[2]}, _lc => 1}, $left;
    } elsif ($cond->[1] eq 'is null') {
      return sprintf q{not defined %s}, $left;
    } else {
      die "Unknown expr |$cond->[1]|";
    }
  } elsif ($cond->[0] eq 'adjusted current node') {
    if ($cond->[1] eq 'is') {
      my $code = pattern_to_code $cond->[2], '$OE->[-1]';
      $code =~ s/->\{et\}/->{aet}/g;
      return $code;
    } else {
      die "Unknown expr |$cond->[1]|";
    }
  } elsif ($cond->[0] eq 'token') {
    if ($cond->[1] eq 'has' and $cond->[2] eq 'self-closing flag') {
      return q{$token->{self_closing_flag}};
    } elsif ($cond->[1] eq 'has attr' and defined $cond->[2]) {
      if (ref $cond->[2]) {
        return join " or \n", map { sprintf q{$token->{attrs}->{q@%s@}}, $_ } @{$cond->[2]};
      } else {
        return sprintf q{$token->{attrs}->{q@%s@}}, $cond->[2];
      }
    } elsif ($cond->[1] eq 'is a') {
      if ($cond->[2] =~ /^[A-Z]+$/) {
        my $tt = $ShortTokenTypeToTokenTypeID->{$cond->[2]}
            or die "|$cond->[2]| has no type const";
        return sprintf q{$token->{type} == %s}, $tt;
      } elsif ($cond->[2] =~ /^([A-Z]+)(-NOT|):(.+)$/) {
        my ($type, $not, $groups) = ($1, $2, $3);
        my %group_id;
        for (split /[, ]/, $groups) {
          $group_id{$TAG_NAME_TO_GROUP->{$_} or die "|$_| has no group"} = 1;
        }
        $groups = join " or \n", map {
          sprintf q{$token->{tn} == %s}, $_;
        } sort { $a cmp $b } keys %group_id;
        my $tt = {
          START => 'START_TAG_TOKEN',
          END => 'END_TAG_TOKEN',
        }->{$type} or die "|$type| has no type const";
        if ($not) {
          return sprintf q{$token->{type} == %s and not (%s)},
              $tt, $groups;
        } else {
          return sprintf q{$token->{type} == %s and %s},
              $tt, $groups;
        }
      } else {
        die "Unknown token type |$cond->[2]|";
      }
    } else {
      die "Unknown condition |@$cond|";
    }
  } elsif ($cond->[0] eq 'token tag_name' and
           $cond->[1] eq 'is' and
           defined $cond->[2]) {
    return sprintf q{$token->{tag_name} eq q@%s@}, $cond->[2];
  } elsif ($cond->[0] eq 'token[type]' and
           $cond->[1] eq 'lc is not' and
           defined $cond->[2]) {
    return sprintf q{
      defined $token->{attrs}->{type} and
      do {
        my $value = $token->{attrs}->{type}->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        $value eq q@%s@;
      }
    }, $cond->[2];
  } elsif ($cond->[0] eq 'fragment') {
    return q{defined $CONTEXT};
  } elsif ($cond->[0] eq 'form element pointer' and
           $cond->[1] eq 'is not null') {
    return q{defined $FORM_ELEMENT};
  } elsif ($cond->[0] eq 'frameset-ok flag' and
           $cond->[1] eq 'is' and
           $cond->[2] eq 'not ok') {
    return q{not $FRAMESET_OK};
  } elsif ($cond->[0] eq 'im' and
           $cond->[1] eq 'is' and
           ref $cond->[2] eq 'ARRAY') {
    return join ' or ', map { sprintf q{$IM == %s}, im_const $_ } @{$cond->[2]};
  } elsif ($cond->[0] eq 'stack of template insertion modes' and
           $cond->[1] eq 'is not empty') {
    return q{@$TEMPLATE_IMS};
  } elsif ($cond->[0] eq 'not quirks') {
    return q{not $QUIRKS};
  } elsif ($cond->[0] eq 'pending table character tokens list' and
           $cond->[1] eq 'has non-space') {
    return q{grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS};
  } elsif ($cond->[0] eq 'scripting') {
    return q{$Scripting};
  } else {
    die "Unknown condition |$cond->[0]|";
  }
} # cond_to_code

sub foster_code ($$$;$) {
  my ($act, $cmd, $value_code, $target_code) = @_;
  $target_code ||= q{$OE->[-1]};
  if ($act->{foster_parenting}) {
    return sprintf q{
      if (%s) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if (%s) { # table
              push @$OP, ['%s-foster', %s => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif (%s) { # template
              push @$OP, ['%s', %s => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['%s', %s => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['%s', %s => %s->{id}];
      }
    },
        (pattern_to_code 'HTML:table HTML:tbody,HTML:tfoot,HTML:thead HTML:tr', $target_code),
          (pattern_to_code 'HTML:table', '$OE->[$i]'),
            $cmd, $value_code,
          (pattern_to_code 'HTML:template', '$OE->[$i]'),
            $cmd, $value_code,
          $cmd, $value_code,
        $cmd, $value_code, $target_code;
  } else {
    return sprintf q{
      push @$OP, ['%s', %s => %s->{id}];
    }, $cmd, $value_code, $target_code;
  }
} # foster_code

sub actions_to_code ($;%);
sub actions_to_code ($;%) {
  my ($actions, %args) = @_;
  $actions = [@$actions];
  my @code;
  my $ignore_newline;
  my $new_im;
  my $last_node_var;
  warn "actions is not action list", Carp::longmess unless ref $actions;
  while (@$actions) {
    my $act = shift @$actions;
    if ($act->{type} eq 'if') {
      if (defined $act->{false_actions}) {
        push @code, sprintf q{
          if (%s) {
            %s
          } else {
            %s
          }
        },
            (cond_to_code $act->{cond}),
            (actions_to_code $act->{actions}),
            (actions_to_code $act->{false_actions});
      } elsif (@{$act->{actions}} == 1 and
               ($act->{actions}->[0]->{type} eq 'adjust SVG attributes' or
                $act->{actions}->[0]->{type} eq 'adjust MathML attributes')) {
        ## Processed by "insert a foreign element"
        #
      } elsif ($act->{cond}->[0] eq 'not iframe srcdoc document' and
               @{$act->{actions}} == 2 and
               $act->{actions}->[0]->{type} eq 'parse error' and
               $act->{actions}->[1]->{type} eq 'set-compat-mode') {
        push @code, q{
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        };
      } elsif ($act->{cond}->[0] eq 'legacy doctype' and
               @{$act->{actions}} == 1 and
               $act->{actions}->[0]->{type} eq 'parse error') {
        ## Processed by "doctype-switch"
        #
      } else {
        push @code, sprintf q{
          if (%s) {
            %s
          }
        },
            (cond_to_code $act->{cond}),
            (actions_to_code $act->{actions});
      }
    } elsif ($act->{type} eq 'switch the insertion mode') {
      if (ref $act->{im}) {
        if ($act->{im}->[0] eq 'original') {
          push @code, sprintf q{
            $IM = $ORIGINAL_IM;
          }, $act->{im};
        } else {
          die "Unknown IM |$act->{im}->[0]|"
        }
      } else {
        push @code, sprintf q{
          $IM = %s;
          #warn "Insertion mode changed to |%s| ($IM)";
        }, im_const $act->{im}, $act->{im};
        $new_im = $act->{im};
      }
    } elsif ($act->{type} eq 'reprocess the token') {
      push @code, sprintf q{
        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      };
    } elsif ($act->{type} eq 'process-using-in-body-im') {
      push @code, sprintf q{
        goto &{$ProcessIM->[%s]->[$token->{type}]->[$token->{tn}]};
      }, im_const 'in body';
    } elsif ($act->{type} eq 'process-using-current-im') {
      push @code, sprintf q{
        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      };
    } elsif ($act->{type} eq 'insert an HTML element') {
      my $tag_name = $act->{tag_name};
      my $var = '$node';
      $var .= '_' . $tag_name if defined $tag_name;
      $last_node_var = $var;
      $tag_name = [keys %{$act->{possible_tag_names}}]->[0]
          if 1 == keys %{$act->{possible_tag_names} or {}} and
             not $act->{possible_tag_names}->{ELSE};
      my $et_code;
      if (defined $tag_name) {
        $et_code = '(' . ($ElementToElementGroupExpr->{HTML}->{$tag_name} ||
                          $ElementToElementGroupExpr->{HTML}->{'*'}) . ')';
      } else {
        $et_code = sprintf q{$Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
      }
      push @code, sprintf q{
        my %s = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => %s,
                 attr_list => %s,
                 et => %s, aet => %s %s};
      },
          $var,
          (defined $tag_name ? "'$tag_name'" : '$token->{tag_name}'),
          (defined $act->{attrs} ? $act->{attrs} eq 'none' ? '[]' : (die $act->{attrs}) : '$token->{attr_list}'),
          $et_code, $et_code,
          ($act->{with_script_flags} ? ', script_flags => 1' : '');
      my $reset_n = 0;
      for (values %{$act->{possible_tag_names} or {}}) {
        $reset_n++ if $_->{associate_form_owner};
      }
      my $form_code = '';
      if ($reset_n) {
        my $code = sprintf q{
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           (%s); # reassociateable
              for my $oe (@$OE) {
                if (%s) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              %s->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        },
            pattern_to_code ($Defs->{tree_patterns}->{'category-form-attr'}, $var),
            pattern_to_code ('HTML:template', '$oe'),
            $var;
        if ($reset_n == keys %{$act->{possible_tag_names}}) {
          $form_code = $code;
        } else {
          $form_code = sprintf q{
            if (%s) {
              %s
            }
          },
              (pattern_to_code $Defs->{tree_patterns}->{'form-associated element'}, $var),
              $code;
        }
      }
      push @code, (foster_code $act => 'insert', $var), $form_code;
      my %has_popped = map { s/^HTML://; $_ => 1 } split /[ ,]/, $Defs->{tree_patterns}->{has_popped_action};
      if (@$actions and
          $actions->[0]->{type} eq 'pop-oe' and
          1 == keys %{$actions->[0]} and
          ((defined $tag_name and not $has_popped{$tag_name}) or
           (not grep { $act->{possible_tag_names}->{$_} } keys %has_popped))) {
        shift @$actions;
      } else {
        push @code, sprintf q{push @$OE, %s;}, $var;
      }
    } elsif ($act->{type} eq 'create an HTML element') {
      my $tag_name = $act->{local_name};
      $tag_name = [keys %{$act->{possible_tag_names}}]->[0]
          if 1 == keys %{$act->{possible_tag_names} or {}} and
             not $act->{possible_tag_names}->{ELSE};
      die unless $tag_name eq 'html';
      my $et_code;
      if (defined $tag_name) {
        $et_code = '(' . ($ElementToElementGroupExpr->{HTML}->{$tag_name} ||
                          $ElementToElementGroupExpr->{HTML}->{'*'}) . ')';
      } else {
        $et_code = sprintf q{$Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
      }
      push @code, sprintf q{
        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => %s,
                    attr_list => %s,
                    et => %s, aet => %s};
      },
          (defined $tag_name ? "'$tag_name'" : '$token->{tag_name}'),
          (defined $act->{attrs} ? $act->{attrs} eq 'none' ? '[]' : 'XX'.'X' : '$token->{attr_list}'),
          $et_code, $et_code;
      ## Note that local_name is always |html|.  As such, we don't
      ## have to associate the form owner.
    } elsif ($act->{type} eq 'insert a foreign element') {
      if ($act->{ns} eq 'inherit') {
        push @code, q{
          ## Adjusted current node
          my $ns = ((defined $CONTEXT and @$OE == 1) ? $CONTEXT : $OE->[-1])->{ns};
        };
      } elsif ($act->{ns} eq 'SVG' or $act->{ns} eq 'MathML') {
        push @code, sprintf q{my $ns = %s;}, ns_const $act->{ns};
      } else {
        die $act->{ns};
      }
      
      push @code, sprintf q{
        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      };
      if ($act->{ns} eq 'inherit') {
        push @code, sprintf q{
          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = $token->{attrs}->{encoding}->{value};
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} = $node->{et} = M_ANN_M_ANN_ELS;
            }
          }
        };
      }

      ## "Create an element for a token", step 2.
      push @code, q{
        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      };

      push @code,
          (foster_code $act => 'insert', q{$node}),
          q{push @$OE, $node;};

      ## As a non-HTML element can't be a form-associated element, we
      ## don't have to associate the form owner.
    } elsif ($act->{type} eq 'append-to-document') {
      if (defined $act->{item}) {
        if ($act->{item} eq 'DocumentType') {
          push @code, q{push @$OP, ['doctype', $token => 0];};
        } else {
          die "Unknown item |$act->{item}|";
        }
      } else {
        push @code, q{push @$OP, ['insert', $node => 0];};
      }
    } elsif ($act->{type} eq 'push-oe') {
      if (defined $act->{item}) {
        if ($act->{item} eq 'head element pointer') {
          push @code, q{push @$OE, $HEAD_ELEMENT;};
        } else {
          die "Unknown item |$act->{item}|";
        }
      } else {
        push @code, sprintf q{push @$OE, $node;};
      }
    } elsif ($act->{type} eq 'pop-oe') {
      if (defined $act->{until}) {
        push @code, sprintf q{{
          my @popped;
          push @popped, pop @$OE while not (%s);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }}, pattern_to_code $act->{until}, '$OE->[-1]';
      } elsif ($act->{while}) {
        if (defined $act->{except}) {
          # XXX can't this removed???
          die if not ref $act->{except};
          push @code, sprintf q{{
            my @popped;
            push @popped, pop @$OE while %s and not (%s);
            push @$OP, ['popped', \@popped];
          }},
              (pattern_to_code $act->{while}, '$OE->[-1]'),
              (pattern_to_code $act->{except}, '$OE->[-1]');
        } else {
          die if ref $act->{while};
          my %has_popped = map { $_ => 0 } split /[ ,]/, $Defs->{tree_patterns}->{has_popped_action};
          for (split /[ ,]/, $act->{while}) {
            $has_popped{$_} = 1 if defined $has_popped{$_};
          }
          die if grep { $_ } values %has_popped;
          push @code, sprintf q{pop @$OE while %s;},
              pattern_to_code $act->{while}, '$OE->[-1]';
        }
      } elsif ($act->{while_not}) {
        die if defined $act->{except};
        push @code, sprintf q{{
          my @popped;
          push @popped, pop @$OE while not (%s);
          push @$OP, ['popped', \@popped];
        }}, pattern_to_code $act->{while_not}, '$OE->[-1]';
      } else {
        push @code, q{push @$OP, ['popped', [pop @$OE]];};
      }
      # XXX |pop @$OE while not $OE->[1] eq $OE->[-1]| can be optimized
    } elsif ($act->{type} eq 'remove-oe') {
      if ($act->{item} eq 'head element pointer') {
        push @code, q{@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;};
        ## 'popped' is redundant so that not done here.
      } elsif ($act->{item} eq 'node') {
        push @code, q{@$OE = grep { $_ ne $_node } @$OE;};
        ## 'popped' is redundant so that not done here.
      } else {
        die "Unknown item |$act->{item}|";
      }
    } elsif ($act->{type} eq 'insert a comment') {
      if (defined $act->{position}) {
        if ($act->{position} eq 'document') {
          push @code, sprintf q{
            push @$OP, ['comment', $token->{data} => 0];
          };
        } elsif ($act->{position} eq 'oe[0]') {
          push @code, sprintf q{
            push @$OP, ['comment', $token->{data} => $OE->[0]->{id}];
          };
        } else {
          die "Unknown insertion position |$act->{position}|";
        }
      } else {
        push @code, sprintf q{
          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        };
      }
    } elsif ($act->{type} eq 'insert-chars') {
      my $value_code;
      if (defined $act->{value}) {
        if (ref $act->{value}) {
          if ($act->{value}->[0] eq 'pending table character tokens list') {
            $value_code = q{(join '', map { $_->{value} } @$TABLE_CHARS)};
          #} elsif ($act->{value}->[0] eq 'prompt-string') {
          #  $value_code = '"Isindex prompt"';
          } else {
            die "Unknown value |$act->{value}->[0]|";
          }
        } else {
          $value_code = sprintf q{q@%s@}, $act->{value};
        }
      } else {
        $value_code = $args{chars} // q{$token->{value}};
      }
      push @code, foster_code $act => 'text', $value_code;
    } elsif ($act->{type} eq 'pop-template-ims') {
      push @code, q{pop @$TEMPLATE_IMS;};
    } elsif ($act->{type} eq 'push-template-ims') {
      push @code, sprintf q{
        push @$TEMPLATE_IMS, q@%s@;
      }, $act->{im};
    } elsif ($act->{type} eq 'remove-tree') {
      push @code, sprintf q{
        push @$OP, ['remove', %s->{id}];
      }, node_expr_to_code $act->{item};
    } elsif ($act->{type} eq 'for-each-reverse-oe-as-node') {
      if (@{$act->{between_actions}}) {
        push @code, sprintf q{
          my $_node_i = $#$OE;
          my $_node = $OE->[$_node_i];
          {
            %s
            $_node_i--;
            $_node = $OE->[$_node_i];
            %s
            redo;
          }
        },
            (actions_to_code $act->{actions}),
            (actions_to_code $act->{between_actions});
      } else {
        push @code, sprintf q{
          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            %s
          }
        }, (actions_to_code $act->{actions});
      }
    } elsif ($act->{type} eq 'break-for-each') {
      push @code, q{last;};
    } elsif ($act->{type} eq 'set-form-element-pointer') {
      push @code, sprintf q{$FORM_ELEMENT = $node;};
    } elsif ($act->{type} eq 'set-head-element-pointer') {
      push @code, sprintf q{$HEAD_ELEMENT = %s;}, $last_node_var || die;
    } elsif ($act->{type} eq 'set-attrs-if-missing' and
             $act->{node} =~ /^oe\[([0-9]+)\]$/) {
      push @code, sprintf q{
        push @$OP, ['set-if-missing', $token->{attr_list} => $OE->[%d]->{id}]
            if @{$token->{attr_list}};
      }, $1;
    } elsif ($act->{type} eq 'fixup-svg-tag-name') {
      push @code, q{
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      };
      ## $token->{tn} don't have to be updated
    } elsif ($act->{type} eq 'doctype-switch') {
      push @code, q{
        if (not $token->{name} eq 'html') {
          push @$Errors, {type => 'XXX', token => $token};
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        } elsif (defined $token->{public_identifier}) {
          if (defined $OPPublicIDToSystemID->{$token->{public_identifier}}) {
            if (defined $token->{system_identifier}) {
              if ($OPPublicIDToSystemID->{$token->{public_identifier}} eq $token->{system_identifier}) {
                push @$Errors, {type => 'XXXobsolete permitted DOCTYPE', level => 's', token => $token};
              } else {
                push @$Errors, {type => 'XXX', token => $token};
              }
            } else {
              if ($OPPublicIDOnly->{$token->{public_identifier}}) {
                push @$Errors, {type => 'XXXobsolete permitted DOCTYPE', level => 's', token => $token};
              } else {
                push @$Errors, {type => 'XXX', token => $token};
              }
            }
          } else {
            push @$Errors, {type => 'XXX', token => $token};
            unless ($IframeSrcdoc) {
              my $pubid = $token->{public_identifier};
              $pubid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
              if ($QPublicIDs->{$pubid}) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif ($pubid =~ /^$QPublicIDPrefixPattern/o) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif (defined $token->{system_identifier} and
                       do {
                         my $sysid = $token->{system_identifier};
                         $sysid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
                         $QSystemIDs->{$sysid};
                       }) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif ($pubid =~ /^$LQPublicIDPrefixPattern/o) {
                push @$OP, ['set-compat-mode', 'limited quirks'];
              } elsif ($pubid =~ /^$QorLQPublicIDPrefixPattern/o) {
                if (defined $token->{system_identifier}) {
                  push @$OP, ['set-compat-mode', 'limited quirks'];
                } else {
                  push @$OP, ['set-compat-mode', 'quirks'];
                  $QUIRKS = 1;
                }
              }
            }
          }
        } elsif (defined $token->{system_identifier}) {
          if ($token->{system_identifier} eq 'about:legacy-compat') {
            push @$Errors, {type => 'XXXlegacy DOCTYPE', level => 's', token => $token};
          } else {
            push @$Errors, {type => 'XXX', token => $token};
            unless ($IframeSrcdoc) {
              my $sysid = $token->{system_identifier};
              $sysid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
              if ($QSystemIDs->{$sysid}) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              }
            }
          }
        }
        if ($token->{force_quirks_flag}) {
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        }
      };
    } elsif ($act->{type} eq 'change-the-encoding-if-appropriate') {
      push @code, q{
        if (defined $token->{attrs}->{charset}) {
          push @$OP, ['change-the-encoding', $token->{attrs}->{charset}->{value}, $token->{attrs}->{charset}];
        } elsif (defined $token->{attrs}->{'http-equiv'} and
                 defined $token->{attrs}->{content}) {
          if ($token->{attrs}->{'http-equiv'}->{value}
                  =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
              $token->{attrs}->{content}->{value}
                  =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                        [\x09\x0A\x0C\x0D\x20]*=
                        [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                        ([^"'\x09\x0A\x0C\x0D\x20]
                         [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            push @$OP, ['change-the-encoding', $1, $token->{attrs}->{content}];
          }
        }
      };
    } elsif ($act->{type} eq 'appcache-processing') {
      if ($act->{can_have_manifest}) { # XXXxml
        push @code, q{push @$OP, ['appcache', $token->{attrs}->{manifest}];};
      } else {
        push @code, q{push @$OP, ['appcache'];};
      }
    } elsif ($act->{type} eq 'script-processing-1') {
      push @code, q{my $script = $OE->[-1];};
    } elsif ($act->{type} eq 'script-processing-2') {
      push @code, q{push @$OP, ['script', $script->{id}];};
    } elsif ($act->{type} eq 'set-node-flag' and
             $act->{target} eq 'already started') {
      push @code, q{push @$OP, ['ignore-script', $OE->[-1]->{id}];};

    } elsif ($act->{type} eq 'set-false' and $act->{target} eq 'frameset-ok') {
      push @code, sprintf q{
        $FRAMESET_OK = 0;
      };
    } elsif ($act->{type} eq 'set-null' and
             $act->{target} eq 'form element pointer') {
      push @code, q{$FORM_ELEMENT = undef;};
    } elsif ($act->{type} eq 'set-null' and
             $act->{target} eq 'head element pointer') {
      push @code, q{$FORM_ELEMENT = undef;};
    } elsif ($act->{type} eq 'set-node') {
      if ($act->{value} =~ /^oe\[(-?[0-9]+)\]$/) {
        push @code, sprintf q{my $_node = $OE->[%d];}, $1;
      } elsif ($act->{value} eq 'form element pointer') {
        push @code, q{my $_node = $FORM_ELEMENT;};
      } else {
        die "Unknown set-node |$act->{value}|";
      }
    } elsif ($act->{type} eq 'set-current-im' and
             $act->{target} eq 'original insertion mode') {
      push @code, q{$ORIGINAL_IM = $IM;};
    } elsif ($act->{type} eq 'append-marker-to-afe') {
      push @code, q{push @$AFE, '#marker';};
    } elsif ($act->{type} eq 'adoption agency algorithm') {
      my $method = $act->{foster_parenting} ? 'aaa_foster' : 'aaa';
      if (defined $act->{tag_name}) {
        if ($act->{remove_from_afe_and_oe}) {
          push @code, sprintf q{%s ($token, '%s', remove_from_afe_and_oe => 1);},
              $method, $act->{tag_name};
        } else {
          push @code, sprintf q{%s ($token, '%s');},
              $method, $act->{tag_name};
        }
      } else {
        push @code, sprintf q{%s ($token, $token->{tag_name});}, $method;
      }
    } elsif ($act->{type} eq 'parse error') {
      push @code, sprintf q{push @$Errors, {type => '%s', index => $token->{index}};},
          $act->{name};
    } elsif ($act->{type} eq 'switch the tokenizer') {
      push @code, sprintf q{$State = %s;}, state_const $act->{state};
    } elsif ($act->{type} eq 'reconstruct the active formatting elements') {
      if ($act->{foster_parenting}) {
        push @code, q{&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];};
      } else {
        push @code, q{&reconstruct_afe if @$AFE and ref $AFE->[-1];};
      }
    } elsif ($act->{type} eq 'push onto the list of active formatting elements') {
      push @code, q{
        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      };
    } elsif ($act->{type} eq 'clear the list of active formatting elements up to the last marker') {
      push @code, q{
        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      };
    } elsif ($act->{type} eq "acknowledge the token's self-closing flag") {
      if ($act->{foreign}) {
        push @code, q{delete $token->{self_closing_flag};};
      } else {
        push @code, q{
          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        };
      }
    } elsif ($act->{type} eq 'reset the insertion mode appropriately') {
      push @code, q{&reset_im;};
    } elsif ($act->{type} eq "change the token's tag name") {
      push @code, sprintf q{$token->{tag_name} = '%s';}, $act->{tag_name};
    } elsif ($act->{type} eq 'adjust foreign attributes' or
             $act->{type} eq 'adjust SVG attributes' or
             $act->{type} eq 'adjust MathML attributes') {
      ## Processed in "insert a foreign element".
    } elsif ($act->{type} eq 'stop parsing') {
      push @code, q{push @$OP, ['stop-parsing'];};
    } elsif ($act->{type} eq 'take a deep breath') {
      push @code, q{
        ## Take a deep breath!
      };
    } elsif ($act->{type} eq 'ignore the token') {
      #

    } elsif ($act->{type} eq 'text-with-optional-ws-prefix') {
      die if $act->{pending_table_character_tokens};
      # XXX index
      push @code, sprintf q{
        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          %s
        }
        if (length $token->{value}) {
          %s
        }
      }, (actions_to_code $act->{ws_actions}, chars => '$1'),
         (actions_to_code $act->{actions});
    } elsif ($act->{type} eq 'process-chars') {
      my $codes = {};
      for (
        ['ws_char_actions', 'ws_seq_actions' => 'ws'],
        ['null_char_actions', 'null_seq_actions' => 'null'],
        ['char_actions', 'actions' => 'else'],
      ) {
        my ($char_key, $seq_key, $key) = @$_;
        if (not defined $act->{$char_key} and defined $act->{$seq_key}) {
          $codes->{$key} = actions_to_code $act->{$seq_key} || [], chars => '$1';
        } elsif (defined $act->{$char_key} or defined $act->{$seq_key}) {
          # XXX index
          $codes->{$key} = sprintf q{
            my $value = $1;
            while ($value =~ /(.)/gs) {
              %s
            }
            %s
          },
              (actions_to_code $act->{$char_key} || [], chars => '$1'),
              (actions_to_code $act->{$seq_key} || [], chars => '$value');
        }
      }

      my $code;
      if (defined $codes->{ws} and defined $codes->{null}) {
        # XXX index
        if ($codes->{else} =~ /^\s*\Q$codes->{ws}\E\s*\$\QFRAMESET_OK = 0;\E\s*$/) {
          my $ws2 = $codes->{ws};
          $ws2 =~ s/\$1\b/\$token->{value}/g;
          $code = sprintf q{
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  %s
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  %s
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  %s
                }
              }
            } else {
              %s
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          }, $codes->{else}, $codes->{ws}, $codes->{null}, $ws2;
        } else {
          $code = sprintf q{
            while (pos $token->{value} < length $token->{value}) {
              if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                %s
              }
              if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                %s
              }
              if ($token->{value} =~ /\G([\x00]+)/gc) {
                %s
              }
            }
          }, $codes->{else}, $codes->{ws}, $codes->{null};
        }
      } elsif (defined $codes->{ws}) {
        # XXX index
        $code = sprintf q{
          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              %s
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              %s
            }
          }
        }, $codes->{else}, $codes->{ws};
      } elsif (defined $codes->{null}) {
        # XXX index
        $code = sprintf q{
          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              %s
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              %s
            }
          }
        }, $codes->{else}, $codes->{null};
      } else {
        if (defined $act->{char_actions}) {
          # XXX index
          $code = sprintf q{
            while ($token->{value} =~ /(.)/gs) {
              %s
            }
            %s
          },
              (actions_to_code $act->{char_actions} || [], chars => '$1'),
              (actions_to_code $act->{actions} || []);
        } else {
          $code = actions_to_code $act->{actions} || [];
        }
      }
      if ($act->{pending_table_character_tokens}) {
        $code = sprintf q{
          for my $token (@$TABLE_CHARS) {
            %s
          }
        }, $code;
      }
      push @code, $code;
    } elsif ($act->{type} eq 'set-empty' and
             $act->{target} eq 'pending table character tokens') {
      push @code, q{$TABLE_CHARS = [];};
    } elsif ($act->{type} eq 'append-to-pending-table-character-tokens-list') {
      push @code, q{push @$TABLE_CHARS, {%$token, value => $1};};

    } elsif ($act->{type} eq 'abort these steps') {
      push @code, q{return;};
    } elsif ($act->{type} eq 'ignore-next-lf') {
      $ignore_newline = 1;
    } else {
      die "Unknown tree construction action |$act->{type}|";
    }
  } # $actions
  if ($ignore_newline) {
    if (defined $new_im and $new_im eq 'text') {
      push @code, sprintf q{
        $IM = %s;
      }, im_const 'before ignored newline and text';
    } else {
      push @code, sprintf q{
        $ORIGINAL_IM = $IM;
        $IM = %s;
      }, im_const 'before ignored newline';
    }
  }
  return join "\n", @code;
} # actions_to_code

sub generate_tree_constructor ($) {
  my $self = shift;

  my $defs = $self->_parser_defs;
  local $Defs = $defs;

  my @def_code;

  my @group_code;
  my $tag_name_group_to_id = {};
  my $i = 0;
  for my $tn (@{$defs->{tag_name_groups}}) {
    my $name = uc $tn;
    $name =~ tr/ -/__/;
    $i++;
    $tag_name_group_to_id->{$tn} = $i;
    push @group_code, sprintf q{sub TAG_NAME_%s () { %d }}, $name, $i;
    for (split / /, $tn) {
      push @group_code, sprintf q{$TagName2Group->{q@%s@} = %d;}, $_, $i;
      $TAG_NAME_TO_GROUP->{$_} = 'TAG_NAME_' . $name;
    }
    $GROUP_ID_TO_NAME->[$i] = $tn;
  }

  ## ---- DOCTYPE definitions ----
  {
    push @def_code, sprintf q{my $QPublicIDPrefixPattern = qr{%s};},
        $defs->{doctype_switch}->{quirks}->{regexp}->{public_id_prefix};
    push @def_code, sprintf q{my $LQPublicIDPrefixPattern = qr{%s};},
        $defs->{doctype_switch}->{limited_quirks}->{regexp}->{public_id_prefix};
    push @def_code, sprintf q{my $QorLQPublicIDPrefixPattern = qr{%s};},
        $defs->{doctype_switch}->{limited_quirks}->{regexp}->{public_id_prefix_if_system_id};
    push @def_code, sprintf q{my $QPublicIDs = {%s};},
        join ', ', map { qq{q<$_> => 1} } sort { $a cmp $b } keys %{$defs->{doctype_switch}->{quirks}->{values}->{public_id}};
    push @def_code, sprintf q{my $QSystemIDs = {%s};},
        join ', ', map { qq{q<$_> => 1} } sort { $a cmp $b } keys %{$defs->{doctype_switch}->{quirks}->{values}->{system_id}};
    my $op_pub_to_sys = {};
    my $op_pub_wo_sys = {};
    for (@{$defs->{doctype_switch}->{obsolete_permitted}}) {
      $op_pub_to_sys->{$_->[0]} = $_->[1] if defined $_->[1];
      $op_pub_wo_sys->{$_->[0]} = 1 if not defined $_->[1];
    }
    push @def_code, sprintf q{my $OPPublicIDToSystemID = {%s};},
        join ', ', map { qq{q<$_> => q<$op_pub_to_sys->{$_}>} } sort { $a cmp $b } keys %$op_pub_to_sys;
    push @def_code, sprintf q{my $OPPublicIDOnly = {%s};},
        join ', ', map { qq{q<$_> => 1} } sort { $a cmp $b } keys %$op_pub_wo_sys;
  }

  ## ---- Injecting pseudo-IM definitions ----
  $defs->{actions}->{'before ignored newline;TEXT'} = q{
    $_->{value} =~ s/^\x0A//; # XXXindex
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  };
  $defs->{actions}->{'before ignored newline;ELSE'} = q{
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  };
  $defs->{actions}->{'before ignored newline and text;TEXT'} = sprintf q{
    $_->{value} =~ s/^\x0A//; # XXXindex
    $IM = %s;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  }, im_const 'text';
  $defs->{actions}->{'before ignored newline and text;ELSE'} = sprintf q{
    $IM = %s;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  }, im_const 'text';
  for my $im ('before ignored newline', 'before ignored newline and text') {
    $defs->{ims}->{$im}->{conds}->{TEXT} = $im.';TEXT';
    $defs->{ims}->{$im}->{conds}->{'START-ELSE'} = $im.';ELSE';
    $defs->{ims}->{$im}->{conds}->{'END-ELSE'} = $im.';ELSE';
    for my $short_name (keys %$ShortTokenTypeToTokenTypeID) {
      next if {TEXT => 1, START => 1, END => 1}->{$short_name};
      $defs->{ims}->{$im}->{conds}->{$short_name} = $im.';ELSE';
    }
    for my $tag_name_group (keys %$tag_name_group_to_id) {
      $defs->{ims}->{$im}->{conds}->{"START:$tag_name_group"} = $im.';ELSE';
      $defs->{ims}->{$im}->{conds}->{"END:$tag_name_group"} = $im.';ELSE';
    }
  }

  my @im_code;
  $im_to_id = {};
  {
    my $i = 1;
    for my $im (sort { $a cmp $b } keys %{$defs->{ims}}) {
      my $const = im_const $im;
      push @im_code, sprintf q{sub %s () { %d }}, $const, $i;
      $im_to_id->{$im} = $i;
      $IM_ID_TO_NAME->[$i] = $im;
      $i++;
    }
  }

  {
    my $els = {};
    my $i = 0b1;
    for my $group_name (@{$defs->{element_matching}->{element_groups}}) {
      my $const_name = $group_name;
      if ($const_name =~ /^([A-Za-z]+):\*$/) {
        $const_name = (uc $1) . '_NS_ELS';
        push @{$els->{$1}->{'*'} ||= []}, $const_name;
      } else {
        my @list;
        my @cn = split /,/, $const_name;
        $const_name = join @cn > 5 ? '' : '_', map {
          if (/^([^:\@]+):([^:\@]+)$/) {
            push @list, ($els->{$1}->{$2} ||= []);
          }
          if (s/^HTML://) {
            substr $_, 0, @cn > 5 ? 1 : 3;
          } else {
            s/^([^:])[^:]*:/$1:/;
            substr $_, 0, 5;
          }
        } @cn;
        $const_name =~ s/[^A-Za-z0-9]/_/g;
        $const_name = (uc $const_name) . '_ELS';
        push @$_, $const_name for @list;
      }
      push @group_code, sprintf q{
        ## %s
        sub %s () { %d }
      }, $group_name, $const_name, $i;
      $GroupNameToElementTypeConst->{$group_name} = $const_name;
      $i = $i << 1;
    }
    my $et_codes = {};
    for my $ns (sort { $a cmp $b } keys %$els) {
      for my $ln (sort { $a cmp $b } keys %{$els->{$ns}}) {
        my %found;
        $et_codes->{$ns}->{$ln} = join ' | ', grep { not $found{$_}++ } @{$els->{$ns}->{'*'}}, @{$els->{$ns}->{$ln}};
      }
    }
    my @need_def;
    my $const_el_count = {};
    my $need_el_const = {};
    for my $group_name (@{$defs->{element_matching}->{element_types}}) {
      if ($group_name =~ /^([^:\@]+):([^:\@]+)$/) {
        my $ns = $1;
        my $ln = $2;
        if (defined $et_codes->{$ns}->{$ln}) {
          push @need_def, [$ns, $ln];
          $const_el_count->{$et_codes->{$ns}->{$ln}}++;
        } else {
          $et_codes->{$ns}->{$ln} = $et_codes->{$ns}->{'*'};
          push @need_def, [$ns, $ln];
          $const_el_count->{$et_codes->{$ns}->{$ln}} += 2;
        }
        $need_el_const->{$ns}->{$ln} = 1;
      }
    }
    my $next_id_by_const = {};
    for (@need_def) {
      my ($ns, $ln) = @$_;
      if ($const_el_count->{$et_codes->{$ns}->{$ln}} > 1) {
        my $id = ($next_id_by_const->{$et_codes->{$ns}->{$ln}} ||= $i);
        $next_id_by_const->{$et_codes->{$ns}->{$ln}} += $i;
        $et_codes->{$ns}->{$ln} .= " | $id";
      }
    }
    for my $ns (sort { $a cmp $b } keys %$et_codes) {
      for my $ln (sort { $a cmp $b } keys %{$et_codes->{$ns}}) {
        if ($need_el_const->{$ns}->{$ln}) {
          my $const_name = $ns eq 'HTML' ? $ln : $ns . '_' . $ln;
          $const_name = (uc $const_name) . '_EL';
          $const_name =~ s/[^A-Z0-9]/_/g;
          push @group_code,
              sprintf q{sub %s () { %s } $Element2Type->[%s]->{q@%s@} = %s;},
                  $const_name, $et_codes->{$ns}->{$ln},
                  ns_const $ns, $ln, $const_name;
          $GroupNameToElementTypeConst->{"$ns:$ln"} ||= $const_name;
          $ElementToElementGroupExpr->{$ns}->{$ln} = $const_name;
        } else {
          push @group_code,
              sprintf q{$Element2Type->[%s]->{q@%s@} = %s;},
                  ns_const $ns, $ln, $et_codes->{$ns}->{$ln};
          $ElementToElementGroupExpr->{$ns}->{$ln} = $et_codes->{$ns}->{$ln};
        }
      }
    }
  }
  ## Note that we require 64-bit integer.

  ## ---- Actions in tree construction stage ----
  my $action_name_to_id = {};
  {
    my $next_action_id = 1;
    my @action_code;
    for my $action_name (sort { $a cmp $b } keys %{$defs->{actions}}) {
      $action_name_to_id->{$action_name} = $next_action_id++;
      my $action_code = $defs->{actions}->{$action_name};
      $action_code = actions_to_code $action_code if ref $action_code;
      if ($action_code =~ /\$token/ ) {
        $action_code = q{my $token = $_;} . "\n" . $action_code;
      }
      push @action_code, sprintf q{
        ## [%d] %s
        sub {
          %s
        },
      }, $action_name_to_id->{$action_name}, $action_name, $action_code;
    }
    push @def_code, sprintf q{
      my $TCA = [%s];
    }, join ',', 'undef', @action_code;
  }

  ## ---- IM/token -> action mapping ----
  {
    my $map = [];
    for my $im_name (keys %{$defs->{ims}}) {
      my $im_id = $im_to_id->{$im_name} or die "IM |$im_name| has no ID";
      for my $cond (keys %{$defs->{ims}->{$im_name}->{conds}}) {
        my $short_token_type;
        my $tn_id = 0;
        if ($cond =~ /^(START|END)-ELSE$/) {
          $short_token_type = $1;
        } elsif ($cond =~ /^(START|END):(.+)$/) {
          $short_token_type = $1;
          $tn_id = $tag_name_group_to_id->{$2}
              or die "Tag name group |$2| has no ID";
        } else {
          $short_token_type = $cond;
        }
        my $token_type_id = $ShortTokenTypeToTokenTypeID->{$short_token_type}
            or die "Unknown token type |$short_token_type|";
        my $action_name = $defs->{ims}->{$im_name}->{conds}->{$cond};
        my $action_id = $action_name_to_id->{$action_name}
            or die "Action |$action_name| has no ID";
        $map->[$im_id]->[$token_type_id]->[$tn_id] = $action_id;
      }
    }
    my @x = ('undef');
    for my $im_id (1..$#$map) {
      my @w = ('undef');
      for my $token_type_id (1..$#{$map->[$im_id]}) {
        my @v;
        for my $tn_id (0..$#{$map->[$im_id]->[$token_type_id] or []}) {
          my $v = $map->[$im_id]->[$token_type_id]->[$tn_id];
          push @v, defined $v ? sprintf q{$TCA->[%d]}, $v : q{undef};
        }
        push @w, '[' . (join ', ', @v) . ']';
      }
      push @x, '[' . (join ', ', @w) . ']';
    }
    push @def_code, sprintf q{$ProcessIM = [%s];}, join ",\n", @x;
  }

  ## ---- Substeps invoked from the main tree construction actions ----
  {
    my @substep_code;

    for my $key ('always', 'last_is_false') {
      my $map = {};
      for my $el_name (keys %{$defs->{reset_im_by_html_element}->{$key}}) {
        my $im = $defs->{reset_im_by_html_element}->{$key}->{$el_name};
        my $im_const = im_const $im;
        my $el_expr = $ElementToElementGroupExpr->{HTML}->{$el_name};
        $map->{$el_expr} = $im_const;
      }
      my @x;
      for (sort { $a cmp $b } keys %$map) {
        push @x, sprintf q{  (%s) => %s,}, $_, $map->{$_};
      }
      if ($key eq 'always') {
        push @def_code, 'my $ResetIMByET = {' . (join "\n", @x) . '};';
      } else {
        push @def_code, 'my $ResetIMByETUnlessLast = {' . (join "\n", @x) . '};';
      }
    }
    push @substep_code, sprintf q{
      sub reset_im () {
        my $last = 0;
        my $node_i = $#$OE;
        my $node = $OE->[$node_i];
        LOOP: {
          if ($node_i == 0) {
            $last = 1;
            $node = $CONTEXT if defined $CONTEXT;
          }

          if (ET_IS ($node, 'HTML:select')) {
            SELECT: {
              last SELECT if $last;
              my $ancestor_i = $node_i;
              INNERLOOP: {
                if ($ancestor_i == 0) {
                  last SELECT;
                }
                $ancestor_i--;
                my $ancestor = $OE->[$ancestor_i];
                if (ET_IS ($ancestor, 'HTML:template')) {
                  last SELECT;
                }
                if (ET_IS ($ancestor, 'HTML:table')) {
                  $IM = IM ("in select in table");
                  return;
                }
                redo INNERLOOP;
              } # INNERLOOP
            } # SELECT
            $IM = IM ("in select");
            return;
          }

          $IM = $ResetIMByET->{$node->{et}};
          return if defined $IM;

          unless ($last) {
            $IM = $ResetIMByETUnlessLast->{$node->{et}};
            return if defined $IM;
          }

          if (ET_IS ($node, 'HTML:template')) {
            $IM = $TEMPLATE_IMS->[-1];
            return;
          }
          if (ET_IS ($node, 'HTML:html')) {
            if (not defined $HEAD_ELEMENT) {
              $IM = IM ("before head");
              return;
            } else {
              $IM = IM ("after head");
              return;
            }
          }
          if ($last) {
            $IM = IM ("in body");
            return;
          }
          $node_i--;
          $node = $OE->[$node_i];
          redo LOOP;
        } # LOOP
      } # reset_im
    };

    for (
      ['aaa', (foster_code {}, 'append', q{$last_node->{id}}, q{$common_ancestor})],
      ['aaa_foster', (foster_code {foster_parenting => 1}, 'append', q{$last_node->{id}}, q{$common_ancestor})],
    ) {
      my $aaa_code = sprintf q{
        sub %s ($$;%%) {
          my ($token, $tag_name, %%args) = @_;
          my @popped;
          if ($OE->[-1]->{ns} == HTMLNS and
              $OE->[-1]->{local_name} eq $tag_name) {
            my $found;
            for (reverse @$AFE) {
              if ($_ eq $OE->[-1]) {
                $found = 1;
                last;
              }
            }
            unless ($found) {
              #push @popped,
              pop @$OE;
              ## $args{remove_from_afe_and_oe} - nop
              #push @$OP, ['popped', \@popped];
              return;
            }
          }

          my $outer_loop_counter = 0;
          OUTER_LOOP: {
            if ($outer_loop_counter >= 8) {
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
            $outer_loop_counter++;
            my $formatting_element;
            my $formatting_element_afe_i;
            for (reverse 0..$#$AFE) {
              if (not ref $AFE->[$_]) {
                last;
              } elsif ($AFE->[$_]->{local_name} eq $tag_name) { # ->{ns} == HTMLNS
                $formatting_element = $AFE->[$_];
                $formatting_element_afe_i = $_;
                last;
              }
            }
            unless (defined $formatting_element) {
              ## The "in body" insertion mode, END_TAG_TOKEN, ELSE
              local $_ = $token;
              $ProcessIM->[%s]->[END_TAG_TOKEN]->[0]->();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
        my $beyond_scope;
        my $formatting_element_i;
        my $furthest_block;
        my $furthest_block_i;
        for (reverse 0..$#$OE) {
          if ($OE->[$_] eq $formatting_element) {
            $formatting_element_i = $_;
            last;
          } else {
            if (ET_CATEGORY_IS ($OE->[$_], 'has an element in scope')) {
              $beyond_scope = 1;
            }
            if (ET_CATEGORY_IS ($OE->[$_], 'special category')) {
              $furthest_block = $OE->[$_];
              $furthest_block_i = $_;
            }
          }
        }
            unless (defined $formatting_element_i) {
              push @$Errors, {type => 'XXX', token => $token};
              splice @$AFE, $formatting_element_afe_i, 1, ();
              if ($args{remove_from_afe_and_oe}) {
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            if ($beyond_scope) {
              push @$Errors, {type => 'XXX', token => $token};
              if ($args{remove_from_afe_and_oe}) {
                splice @$AFE, $formatting_element_afe_i, 1, ();
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            unless ($formatting_element eq $OE->[-1]) {
              push @$Errors, {type => 'XXX', token => $token};
            }
            unless (defined $furthest_block) {
              #push @popped,
              splice @$OE, $formatting_element_i;
              splice @$AFE, $formatting_element_afe_i, 1, ();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }

        my $common_ancestor = $OE->[$formatting_element_i-1];
        my $bookmark = $formatting_element_afe_i;
        my $node = $furthest_block;
        my $node_i = $furthest_block_i;
        my $last_node = $furthest_block;
        my $inner_loop_counter = 0;
        INNER_LOOP: {
          $inner_loop_counter++;
          $node_i--;
          $node = $OE->[$node_i];
          last INNER_LOOP if $node eq $formatting_element;
          my $node_afe_i;
          for (reverse 0..$#$AFE) {
            if ($AFE->[$_] eq $node) {
              $node_afe_i = $_;
              last;
            }
          }
          if ($inner_loop_counter > 3 and defined $node_afe_i) {
            splice @$AFE, $node_afe_i, 1, ();
          }
          if (not defined $node_afe_i) {
            push @popped, splice @$OE, $node_i, 1, ();
            redo INNER_LOOP;
          }

          ## Create an HTML element
          $node = {id => $NEXT_ID++,
                   token => $node->{token},
                   ns => HTMLNS,
                   local_name => $node->{token}->{tag_name},
                   attr_list => $node->{token}->{attr_list},
                   et => $Element2Type->[HTMLNS]->{$node->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
          $node->{aet} = $node->{et};
          $AFE->[$node_afe_i] = $node;
          $OE->[$node_i] = $node;
          ## As $node seems never to be a form-assosicated element,
          ## and it will be appended (not inserted) to another node
          ## later anyway, we don't have to associate the form owner
          ## here.  Note that /intended parent/ is $common_ancestor.

          if ($last_node eq $furthest_block) {
            $bookmark = $node_afe_i + 1;
          }

          push @$OP,
              ['create', $node],
              ['append', $last_node->{id} => $node->{id}];
          $last_node = $node;
          redo INNER_LOOP;
        } # INNER_LOOP

            %s

            ## Create an HTML element
            my $new_element = {id => $NEXT_ID++,
                               token => $formatting_element->{token},
                               ns => HTMLNS,
                               local_name => $formatting_element->{token}->{tag_name},
                               attr_list => $formatting_element->{token}->{attr_list},
                               et => $Element2Type->[HTMLNS]->{$formatting_element->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $new_element->{aet} = $new_element->{et};
            push @$OP,
                ['create', $new_element],
                ['move-children', $furthest_block->{id} => $new_element->{id}],
                ['append', $new_element->{id} => $furthest_block->{id}];
            ## As $formatting_element is always a formatting element,
            ## it can't be a form-associated element.  Note that
            ## /intended parent/ is $furthest_block.

            splice @$AFE, $formatting_element_afe_i, 1, ();
            splice @$AFE, $bookmark, 0, $new_element;

            splice @$OE, $furthest_block_i + 1, 0, ($new_element);
            #push @popped,
            splice @$OE, $formatting_element_i, 1, ();

            redo OUTER_LOOP;
          } # OUTER_LOOP
        }
      },
          $_->[0],
          im_const 'in body',
          $_->[1];
      push @substep_code, $aaa_code;
    }

    for (
      ['reconstruct_afe', (foster_code {}, 'insert', '$node')],
      ['reconstruct_afe_foster', (foster_code {foster_parenting => 1}, 'insert', '$node')],
    ) {
      my $reconstruct_code = sprintf q{
        sub %s () {
          #return unless @$AFE;
          #return if not ref $AFE->[-1];
          for (reverse @$OE) {
            return if $_ eq $AFE->[-1];
          }
          my $entry_i = $#$AFE;
          my $entry = $AFE->[$entry_i];
          while (not $entry_i == 0) {
            $entry_i--;
            $entry = $AFE->[$entry_i];
            last if not ref $entry;
            for (reverse @$OE) {
              last if $_ eq $entry;
            }
          }

          for my $entry_i ($entry_i..$#$AFE) {
            $entry = $AFE->[$entry_i];

            ## Insert an HTML element
            my $node = {id => $NEXT_ID++,
                        token => $entry->{token},
                        ns => HTMLNS,
                        local_name => $entry->{token}->{tag_name},
                        attr_list => $entry->{token}->{attr_list},
                        et => $Element2Type->[HTMLNS]->{$entry->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $node->{aet} = $node->{et};
            %s
            push @$OE, $node;

            $AFE->[$entry_i] = $node;
          }
        }
      }, $_->[0], $_->[1];
      push @substep_code, $reconstruct_code;
    }

    for (@substep_code) {
      s{\bIM\s*\("([^"]+)"\)}{im_const $1}ge;
      s{\bET_IS\s*\(\s*([^()"',\s]+)\s*,\s*'([^']+)'\s*\)}{
        pattern_to_code $2, $1;
      }ge;
      s{\bET_CATEGORY_IS\s*\(\s*([^()"',\s]+)\s*,\s*'([^']+)'\s*\)}{
        my $var = $1;
        my $p = $Defs->{tree_patterns}->{$2} or die "No definition for |$2|";
        pattern_to_code $p, $var;
      }ge;
      push @def_code, $_;
    }
  }

  my $def_code = join "\n",
      q{my $Element2Type = [];},
      q{my $ProcessIM = [];},
      (join "\n", @group_code),
      (join "\n", @im_code),
      (join "\n", @def_code);

  my $code = sprintf q{
    sub _construct_tree ($$) {
      my $self = shift;

      for my $token (@$Tokens) {
        local $_ = $token;
        if (%s) {
          &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
        } else {
          &{$ProcessIM->[%s]->[$token->{type}]->[$token->{tn}]};
        }
      }

      ## Adjusted current node
      $InForeign = !!(
        @$OE and $OE->[-1]->{aet} & (MATHML_NS_ELS | SVG_NS_ELS)
      );

      $self->dom_tree ($OP);
      @$OP = ();
      @$Tokens = ();
    } # _construct_tree
  },
      (cond_to_code $defs->{dispatcher_html}),
      im_const 'in foreign content';

  return ($def_code, $code);
} # generate_tree_constructor

## ------ Integration ------

sub generate_dom_glue ($) {
  my $self = shift;
  my $defs = $self->_parser_defs;

  my $grep_popped_code = pattern_to_code $defs->{tree_patterns}->{has_popped_action}, '$_';
  my $code = sprintf q{
sub dom_tree ($$) {
  my ($self, $ops) = @_;

  my $doc = $self->{document};
  my $strict = $doc->strict_error_checking;
  $doc->strict_error_checking (0);

  my $nodes = $self->{nodes};
  for my $op (@$ops) {
    if ($op->[0] eq 'insert' or
        $op->[0] eq 'insert-foster' or
        $op->[0] eq 'create') {
      my $data = $op->[1];
      my $el = $doc->create_element_ns
          ($NSToURL->[$data->{ns}], [undef, $data->{local_name}]);
      for my $attr (@{$data->{attr_list} or []}) {
        $el->set_attribute_ns (@{$attr->{name_args}} => $attr->{value});
      }
      # XXX index
      if ($data->{ns} == HTMLNS and $data->{local_name} eq 'template') {
        $nodes->[$data->{id}] = $el->content;
      } else {
        $nodes->[$data->{id}] = $el;
      }
      # XXX $data->{script_flags}

      if (defined $data->{form}) {
        my $form = $nodes->[$data->{form}];
        #warn "XXX set form owner of $el to $form if $nodes->[$op->[2]] and $form are in the same home subtree";
      }

      if ($op->[0] eq 'insert') {
        $nodes->[$op->[2]]->append_child ($el);
      } elsif ($op->[0] eq 'insert-foster') {
        my $next_sibling = $nodes->[$op->[2]];
        my $parent = $next_sibling->parent_node;
        if (defined $parent) {
          if ($parent->node_type == $parent->DOCUMENT_NODE) {
            #
          } else {
            $parent->insert_before ($el, $next_sibling);
          }
        } else {
          $nodes->[$op->[3]]->append_child ($el);
        }
      }
    } elsif ($op->[0] eq 'text') {
      $nodes->[$op->[2]]->manakai_append_text ($op->[1]);
    } elsif ($op->[0] eq 'text-foster') {
      my $next_sibling = $nodes->[$op->[2]];
      my $parent = $next_sibling->parent_node;
      if (defined $parent) {
        if ($parent->node_type == $parent->DOCUMENT_NODE) {
          #
        } else {
          my $prev_sibling = $next_sibling->previous_sibling;
          if (defined $prev_sibling and
              $prev_sibling->node_type == $prev_sibling->TEXT_NODE) {
            $prev_sibling->manakai_append_text ($op->[1]);
          } else {
            $parent->insert_before
              ($doc->create_text_node ($op->[1]), $next_sibling);
          }
        }
      } else {
        $nodes->[$op->[3]]->manakai_append_text ($op->[1]);
      }

    } elsif ($op->[0] eq 'append') {
      $nodes->[$op->[2]]->append_child ($nodes->[$op->[1]]);
    } elsif ($op->[0] eq 'append-foster') {
      my $next_sibling = $nodes->[$op->[2]];
      my $parent = $next_sibling->parent_node;
      if (defined $parent) {
        if ($parent->node_type == $parent->DOCUMENT_NODE) {
          #
        } else {
          $parent->insert_before ($nodes->[$op->[1]], $next_sibling);
        }
      } else {
        $nodes->[$op->[3]]->append_child ($nodes->[$op->[1]]);
      }
    } elsif ($op->[0] eq 'move-children') {
      my $new_parent = $nodes->[$op->[2]];
      # XXX mutation observer?
      for ($nodes->[$op->[1]]->child_nodes->to_list) {
        $new_parent->append_child ($_);
      }

    } elsif ($op->[0] eq 'comment') {
      $nodes->[$op->[2]]->append_child ($doc->create_comment ($op->[1]));
    } elsif ($op->[0] eq 'doctype') {
      my $data = $op->[1];
      my $dt = $doc->implementation->create_document_type
          ($data->{name},
           defined $data->{public_identifier} ? $data->{public_identifier} : '',
           defined $data->{system_identifier} ? $data->{system_identifier} : '');
      $nodes->[$op->[2]]->append_child ($dt);

    } elsif ($op->[0] eq 'set-if-missing') {
      my $el = $nodes->[$op->[2]];
      for my $attr (@{$op->[1]}) {
        $el->set_attribute_ns (@{$attr->{name_args}} => $attr->{value})
            unless $el->has_attribute_ns ($attr->{name_args}->[0], $attr->{name_args}->[1]->[1]);
      }
      # XXX index

    } elsif ($op->[0] eq 'change-the-encoding') {
      unless ($Confident) {
        my $changed = $self->_change_the_encoding ($op->[1], $op->[2]);
        push @$Callbacks, [$self->onrestartwithencoding, $changed]
            if defined $changed;
      }
      # XXX conformance error if bad index (has reference)
    } elsif ($op->[0] eq 'script') {
      # XXX insertion point setup
      push @$Callbacks, [$self->onscript, $nodes->[$op->[1]]];
    } elsif ($op->[0] eq 'ignore-script') {
      warn "XXX set already started flag of $nodes->[$op->[1]]";
    } elsif ($op->[0] eq 'appcache') {
      if (defined $op->[1] and length $op->[1]->{value}) {
        push @$Callbacks, [$self->onappcacheselection, $op->[1]->{value}];
      } else {
        push @$Callbacks, [$self->onappcacheselection, undef];
      }

    } elsif ($op->[0] eq 'popped') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { %s } @{$op->[1]}]];
    } elsif ($op->[0] eq 'stop-parsing') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { %s } @$OE]];
      #@$OE = ();

      # XXX stop parsing
    } elsif ($op->[0] eq 'abort') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { %s } @$OE]];
      #@$OE = ();

      # XXX abort

    } elsif ($op->[0] eq 'remove') {
      my $parent = $nodes->[$op->[1]]->parent_node;
      $parent->remove_child ($nodes->[$op->[1]]) if defined $parent;
    } elsif ($op->[0] eq 'set-compat-mode') {
      $doc->manakai_compat_mode ($op->[1]);
    } else {
      die "Unknown operation |$op->[0]|";
    }
  }

  $doc->strict_error_checking ($strict);
} # dom_tree

  }, $grep_popped_code, $grep_popped_code, $grep_popped_code;
  return $code;
} # generate_dom_glue

sub generate_api ($) {
  my @code;

  my $vars_codes = {};
  {
    $vars_codes->{LOCAL} = sprintf q{local (%s);}, join ', ', map { sprintf q{$%s}, $_ } sort { $a cmp $b } keys %$Vars;

    my @init_code;
    push @init_code, map {
      sprintf q{$%s = 1;}, $_;
    } sort { $a cmp $b } grep {
      $Vars->{$_}->{type} eq 'boolean' and
      ($Vars->{$_}->{default} // '') eq 'true';
    } keys %$Vars;
    push @init_code, map {
      sprintf q{$%s = %d;}, $_, $Vars->{$_}->{default};
    } sort { $a cmp $b } grep {
      $Vars->{$_}->{type} eq 'index' and
      defined $Vars->{$_}->{default};
    } keys %$Vars;
    my @list_var = sort { $a cmp $b } grep { $Vars->{$_}->{type} eq 'list' } keys %$Vars;
    push @init_code, q[$self->{saved_lists} = {] . (join ', ', map {
      sprintf q{%s => ($%s = [])}, $_, $_;
    } @list_var) . q[};];
    $vars_codes->{INIT} = join "\n", @init_code;

    $vars_codes->{RESET} = join "\n", map {
      sprintf q{$%s = $self->{%s};}, $_, $_;
    } sort { $a cmp $b } grep { $Vars->{$_}->{input} } keys %$Vars;

    my @saved_var = sort { $a cmp $b } grep { $Vars->{$_}->{save} } keys %$Vars;
    $vars_codes->{SAVE} = q[$self->{saved_states} = {] . (join ', ', map {
      sprintf q{%s => $%s}, $_, $_;
    } @saved_var) . q[};];

    my @restore_code;
    push @restore_code, sprintf q{(%s) = @{$self->{saved_states}}{qw(%s)};},
        (join ', ', map { sprintf q{$%s}, $_ } @saved_var),
        (join ' ', @saved_var);
    push @restore_code, sprintf q{(%s) = @{$self->{saved_lists}}{qw(%s)};},
        (join ', ', map { sprintf q{$%s}, $_ } @list_var),
        (join ' ', @list_var);
    $vars_codes->{RESTORE} = join "\n", @restore_code;
  }

  push @code, sprintf q{
    sub _run ($) {
      my ($self) = @_;
      my $is = $self->{input_stream};
      my $length = @$is == 0 ? 0 : defined $is->[0]->[0] ? length $is->[0]->[0] : 0;
      my $in_offset = 0;
      {
        my $len = 10000;
        $len = $length - $in_offset if $in_offset + $len > $length;
        if ($len > 0) {
          $Input = substr $is->[0]->[0], $in_offset, $len;
        } else {
          shift @$is;
          if (@$is) {
            if (defined $is->[0]->[0]) {
              $length = length $is->[0]->[0];
              $in_offset = 0;
              redo;
            } else {
              $EOF = 1;
            }
          } else {
            last;
          }
        }
        {
          $self->_tokenize;
          $self->_construct_tree;

          if (@$Callbacks or @$Errors) {
            VARS::SAVE;

            $self->onerrors->($self, $Errors) if @$Errors;
            for my $cb (@$Callbacks) {
              $cb->[0]->($self, $cb->[1]);
            }
            @$Errors = ();
            @$Callbacks = ();

            if ($self->{restart}) {
              delete $self->{restart};
              return 0;
            }

            VARS::RESTORE;
          }

          redo unless pos $Input == length $Input; # XXX parser pause flag
        }
        $Offset += $len;
        $in_offset += $len;
        redo unless $EOF;
      }
      return 1;
    } # _run

    sub _feed_chars ($$) {
      my ($self, $input) = @_;
      pos ($input->[0]) = 0;
      while ($input->[0] =~ /[\x{0001}-\x{0008}\x{000B}\x{000E}-\x{001F}\x{007F}-\x{009F}\x{D800}-\x{DFFF}\x{FDD0}-\x{FDEF}\x{FFFE}-\x{FFFF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gc) {
        push @$Errors, {type => 'XXX', index => $-[0], level => 'm'};
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
      #my ($self, $string, $document) = @_;
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      $self->{input_stream} = [];
      my $doc = $self->{document} = $_[2];
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      $Confident = 1; # irrelevant
      $State = STATE ("data state");
      $IM = IM ("initial");

      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      $self->_cleanup_states;
      return;
    } # parse_char_string

    sub parse_char_string_with_context ($$$$) {
      #my ($self, $string, $context, $document) = @_;
      my $self = $_[0];
      my $context = $_[2];
      ## $context MUST be an Element or undef.
      ## $document MUST be an empty Document.

      ## HTML fragment parsing algorithm
      ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-html-fragments>.

      ## 1.
      my $doc = $self->{document} = $_[3];
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      my $nodes = $self->{nodes} = [$doc];

      ## 2.
      $doc->manakai_compat_mode ($context->owner_document->manakai_compat_mode)
          if defined $context;

      ## 3.
      my $input = [$_[1]]; # string copy
      $self->{input_stream} = [];
      # XXX index

      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      $State = STATE ("data state");
      $IM = IM ("initial");

      ## 4.
      my $root;
      if (defined $context) {
        ## 4.1.
        my $node_ns = $context->namespace_uri || '';
        my $node_ln = $context->local_name;
        if ($node_ns eq 'http://www.w3.org/1999/xhtml') {
          # XXX JSON
          if ($node_ln eq 'title' or $node_ln eq 'textarea') {
            $State = STATE ("RCDATA state");
          } elsif ($node_ln eq 'script') {
            $State = STATE ("script data state");
          } elsif ({
            style => 1,
            xmp => 1,
            iframe => 1,
            noembed => 1,
            noframes => 1,
            noscript => $Scripting,
          }->{$node_ln}) {
            $State = STATE ("RAWTEXT state");
          } elsif ($node_ln eq 'plaintext') {
            $State = STATE ("PLAINTEXT state");
          }
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => HTMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[HTMLNS]->{$node_ln} || $Element2Type->[HTMLNS]->{'*'},
                      aet => $Element2Type->[HTMLNS]->{$node_ln} || $Element2Type->[HTMLNS]->{'*'}};
        } elsif ($node_ns eq 'http://www.w3.org/2000/svg') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => SVGNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[SVGNS]->{$node_ln} || $Element2Type->[SVGNS]->{'*'},
                      aet => $Element2Type->[SVGNS]->{$node_ln} || $Element2Type->[SVGNS]->{'*'}};
        } elsif ($node_ns eq 'http://www.w3.org/1998/Math/MathML') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => MATHMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[MATHMLNS]->{$node_ln} || $Element2Type->[MATHMLNS]->{'*'},
                      aet => $Element2Type->[MATHMLNS]->{$node_ln} || $Element2Type->[MATHMLNS]->{'*'}};
          if ($node_ln eq 'annotation-xml') {
            my $encoding = $context->get_attribute_ns (undef, 'encoding');
            if (defined $encoding) {
              $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
              if ($encoding eq 'text/html' or
                  $encoding eq 'application/xhtml+xml') {
                $CONTEXT->{et} = $CONTEXT->{aet} = M_ANN_M_ANN_ELS;
              }
            }
          }
        } else {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => 0,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => 0,
                      aet => 0};
        }
        $nodes->[$CONTEXT->{id}] = $context;

        ## 4.2.
        $root = $doc->create_element ('html');

        ## 4.3.
        $doc->append_child ($root);

        ## 4.4.
        @$OE = ({id => $NEXT_ID++,
                 #token => undef,
                 ns => HTMLNS,
                 local_name => 'html',
                 attr_list => {},
                 et => $Element2Type->[HTMLNS]->{html},
                 aet => $CONTEXT->{aet}});

        ## 4.5.
        if ($node_ns eq 'http://www.w3.org/1999/xhtml' and
            $node_ln eq 'template') {
          push @$TEMPLATE_IMS, IM ("in template");
          $nodes->[$OE->[-1]->{id}] = $root->content;
        } else {
          $nodes->[$OE->[-1]->{id}] = $root;
        }

        ## 4.6.
        &reset_im;

        ## 4.7.
        my $anode = $context;
        while (defined $anode) {
          if ($anode->node_type == 1 and
              ($anode->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml' and
              $anode->local_name eq 'form') {
            if ($anode eq $context) {
              $FORM_ELEMENT = $CONTEXT;
            } else {
              $FORM_ELEMENT = {id => $NEXT_ID++,
                               #token => undef,
                               ns => HTMLNS,
                               local_name => 'form',
                               attr_list => {}, # not relevant
                               et => $Element2Type->[HTMLNS]->{form},
                               aet => $Element2Type->[HTMLNS]->{form}};
            }
            last;
          }
          $anode = $anode->parent_node;
        }
      } # $context

      ## 5.
      $Confident = 1; # irrelevant

      ## 6.
      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      $self->_cleanup_states;

      ## 7.
      return defined $context ? $root->child_nodes : $doc->child_nodes;
    } # parse_char_string_with_context

    sub parse_chars_start ($$) {
      my ($self, $doc) = @_;

      $self->{input_stream} = [];
      $self->{document} = $doc;
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      $Confident = 1; # irrelevant
      $State = STATE ("data state");
      $IM = IM ("initial");

      VARS::SAVE;
      return;
    } # parse_chars_start

    sub parse_chars_feed ($$) {
      my $self = $_[0];
      my $input = [$_[1]];

      VARS::LOCAL;
      VARS::RESET;
      VARS::RESTORE;

      $self->_feed_chars ($input) or die "Can't restart";

      VARS::SAVE;
      return;
    } # parse_chars_feed

    sub parse_chars_end ($) {
      my $self = $_[0];
      VARS::LOCAL;
      VARS::RESET;
      VARS::RESTORE;

      $self->_feed_eof or die "Can't restart";
      
      $self->_cleanup_states;
      return;
    } # parse_chars_end

    sub parse_byte_string ($$$$) {
      #my ($self, $charset_name, $string, $doc) = @_;
      my $self = $_[0];

      my $doc = $self->{document} = $_[3];
      $doc->manakai_is_html (1);
      $self->{can_restart} = 1;

      PARSER: {
        $self->{input_stream} = [];
        $self->{nodes} = [$doc];
        $doc->remove_child ($_) for $doc->child_nodes->to_list;

        VARS::LOCAL;
        VARS::INIT;
        VARS::RESET;

        my $inputref = \($_[2]);
        $self->_encoding_sniffing
            (transport_encoding_name => $_[1],
             read_head => sub {
          return \substr $$inputref, 0, 1024;
        }); # $Confident is set within this method.
        $doc->input_encoding ($self->{input_encoding});

        my $input = [decode $self->{input_encoding}, $$inputref]; # XXXencoding

        # XXX index

        $State = STATE ("data state");
        $IM = IM ("initial");

        $self->_feed_chars ($input) or redo PARSER;
        $self->_feed_eof or redo PARSER;
      } # PARSER

      $self->_cleanup_states;
      return;
    } # parse_byte_string

    sub _parse_bytes_init ($) {
      my $self = $_[0];

      my $doc = $self->{document};
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      delete $self->{parse_bytes_started};
      $self->{input_stream} = [];
      VARS::INIT;
      VARS::RESET;
      $State = STATE ("data state");
      $IM = IM ("initial");
    } # _parse_bytes_init

    sub _parse_bytes_start_parsing ($;%%) {
      my ($self, %%args) = @_;
      
      $self->_encoding_sniffing
          (transport_encoding_name => $self->{transport_encoding_label},
           no_body_data_yet => $args{no_body_data_yet},
           read_head => sub {
             return \(substr $self->{byte_buffer}, 0, 1024);
           }); # $Confident is set within this method.
      if (not defined $self->{input_encoding} and $args{no_body_data_yet}) {
        return 1;
      }
      $self->{document}->input_encoding ($self->{input_encoding});

      $self->{parse_bytes_started} = 1;
      #XXXxml $self->{is_xml} = 1;

      my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding

      $self->_feed_chars ($input) or return 0;
      $self->_feed_eof or return 0;

      return 1;
    } # _parse_bytes_start_parsing

    sub parse_bytes_start ($$$) {
      my ($self, $charset_name, $doc) = @_;

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $charset_name;

      $self->{document} = $doc;
      $doc->manakai_is_html (1);
      $self->{can_restart} = 1;

      VARS::LOCAL;
      PARSER: {
        $self->_parse_bytes_init;
        $self->_parse_bytes_start_parsing (no_body_data_yet => 1) or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          redo PARSER;
        };
      } # PARSER

      VARS::SAVE;
      return;
    } # parse_bytes_start

    ## The $args{start_parsing} flag should be set true if it has
    ## taken more than 500ms from the start of overall parsing
    ## process.
    sub parse_bytes_feed ($$) {
      my ($self, undef, %%args) = @_;

      VARS::LOCAL;
      VARS::RESET;
      VARS::RESTORE;

      $self->{byte_buffer} .= $_[1];
      $self->{byte_buffer_orig} .= $_[1];
      PARSER: {
        if ($self->{parse_bytes_started}) {
          my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding
          if (length $self->{byte_buffer} and 0 == length $input->[0]) {
            substr ($self->{byte_buffer}, 0, 1) = '';
            $input->[0] .= "\x{FFFD}" . decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET; # XXX Encoding Standard
          }

          $self->_feed_chars ($input) or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        } else {
          if ($args{start_parsing} or 1024 <= length $self->{byte_buffer}) {
            $self->_parse_bytes_start_parsing or do {
              $self->{byte_buffer} = $self->{byte_buffer_orig};
              $self->_parse_bytes_init;
              redo PARSER;
            };
          }
        }
      } # PARSER

      VARS::SAVE;
      return;
    } # parse_bytes_feed

    sub parse_bytes_end ($) {
      my $self = $_[0];
      VARS::LOCAL;
      VARS::RESET;
      VARS::RESTORE;

      PARSER: {
        unless ($self->{parse_bytes_started}) {
          $self->_parse_bytes_start_parsing or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        }

        if (length $self->{byte_buffer}) {
          my $input = [decode $self->{input_encoding}, $self->{byte_buffer}]; # XXX encoding
          $self->_feed_chars ($input) or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        }

        $self->_feed_eof or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          $self->_parse_bytes_init;
          redo PARSER;
        };
      } # PARSER
      
      $self->_cleanup_states;
      return;
    } # parse_bytes_end
  };
  $code[-1] =~ s/\bSTATE\s*\("([^"]+)"\)/state_const $1/ge;
  $code[-1] =~ s/\bIM\s*\("([^"]+)"\)/im_const $1/ge;
  $code[-1] =~ s/\bVARS::(\w+);/$vars_codes->{$1}/ge;

  return join "\n", @code;
} # generate_api

sub generate ($) {
  my $self = shift;

  my $var_decls = join '', map { sprintf q{our $%s;}, $_ } sort { $a cmp $b } keys %$Vars;
  my ($tokenizer_defs_code, $tokenizer_code) = $self->generate_tokenizer;
  my ($tree_defs_code, $tree_code) = $self->generate_tree_constructor;

  return sprintf q{
    package %s;
    use strict;
    use warnings;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    use warnings FATAL => 'redefine';
    use utf8;
    our $VERSION = '7.0';
    use Carp qw(croak);
    %s
    use Encode qw(decode); # XXX
    use Web::Encoding;
    use Web::HTML::ParserData;

    sub HTMLNS () { 1 }
    sub SVGNS () { 2 }
    sub MATHMLNS () { 3 }
    my $NSToURL = [
      undef,
      'http://www.w3.org/1999/xhtml',
      'http://www.w3.org/2000/svg',
      'http://www.w3.org/1998/Math/MathML',
    ];
    my $ForeignAttrMap = [
      undef, undef,
      $Web::HTML::ParserData::ForeignAttrNameToArgs->{'http://www.w3.org/2000/svg'},
      $Web::HTML::ParserData::ForeignAttrNameToArgs->{'http://www.w3.org/1998/Math/MathML'},
    ];
    my $TagName2Group = {};

# XXX defs from json
my $InvalidCharRefs = {};

for (0x0000, 0xD800..0xDFFF) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} = [0xFFFD, 'must'];
}
for (0x0001..0x0008, 0x000B, 0x000E..0x001F) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'must'];
}
$InvalidCharRefs->{1.0}->{0x000C} = [0x000C, 'must'];
$InvalidCharRefs->{0}->{0x007F} = [0x007F, 'must'];
for (0x007F..0x009F) {
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'warn'];
}
for (keys %%$Web::HTML::ParserData::NoncharacterCodePoints) {
  $InvalidCharRefs->{0}->{$_} = [$_, 'must'];
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'warn'];
}
for (0xFFFE, 0xFFFF) {
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'must'];
}
for (keys %%$Web::HTML::ParserData::CharRefReplacements) {
  $InvalidCharRefs->{0}->{$_}
      = [$Web::HTML::ParserData::CharRefReplacements->{$_}, 'must'];
}

    ## ------ Common handlers ------

sub new ($) {
  return bless {}, $_[0];
} # new

our $DefaultErrorHandler = sub {
  my $error = {@_};
  my $index = $error->{token} ? $error->{token}->{index} : $error->{index};
  $index = -1 if not defined $index;
  my $text = defined $error->{text} ? qq{ - $error->{text}} : '';
  my $value = defined $error->{value} ? qq{ "$error->{value}"} : '';
  warn "Parse error ($error->{type}$text) at index $index$value\n";
}; # $DefaultErrorHandler

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || $DefaultErrorHandler;
} # onerror

sub onerrors ($;$) {
  if (@_ > 1) {
    $_[0]->{onerrors} = $_[1];
  }
  return $_[0]->{onerrors} || sub {
    my $onerror = $_[0]->onerror;
    $onerror->(%%$_) for @{$_[1]};
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

    sub restart ($) {
      unless ($_[0]->{can_restart}) {
        croak "The current parsing method can't restart the parser";
      }
      $_[0]->{restart} = 1;
    } # restart

    sub _cleanup_states ($) {
      my $self = $_[0];
      delete $self->{input_stream};
      delete $self->{input_encoding};
      delete $self->{saved_states};
      delete $self->{saved_lists};
      delete $self->{nodes};
      delete $self->{document};
      delete $self->{can_restart};
      delete $self->{restart};
    } # _cleanup_states

    ## ------ Common defs ------
    %s
    ## ------ Tokenizer defs ------
    %s
    ## ------ Tree constructor defs ------
    %s

    ## ------ Input byte stream ------
    %s
    ## ------ Tokenizer ------
    %s
    ## ------ Tree constructor ------
    %s
    ## ------ DOM integration ------
    %s
    ## ------ API ------
    %s

    1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

  },
      $self->package_name,
      $UseLibCode,
      $var_decls,
      $tokenizer_defs_code,
      $tree_defs_code,
      $self->generate_input_bytes_handler,
      $tokenizer_code,
      $tree_code,
      $self->generate_dom_glue,
      $self->generate_api;
} # generate

sub parser ($) {
  my $self = shift;
  return $self->{parser} ||= do {
    my $class = $self->package_name;
    my $parser = $class->new;
    $parser;
  };
} # parser

sub parse_char_string ($$) {
  my $self = shift;
  my $parser = $self->parser;
  $self->load_dom;
  my $doc = Web::DOM::Document->new;
  $parser->parse_char_string (shift, $doc);
  $self->{document} = $doc;
} # parse_char_string

1;
binmode STDOUT, qw(:utf8); print __PACKAGE__->new->generate;
