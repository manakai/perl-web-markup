
use strict;
use warnings;
use Path::Tiny;
use JSON::PS;

my $LANG = $ENV{PARSER_LANG} ||= 'HTML';

my $GeneratedPackageName = q{Web::}.$LANG.q{::Parser};
my $DefDataPath = path (__FILE__)->parent->parent->child (q{local});
my $UseLibCode = q{};

sub new ($) {
  return bless {}, $_[0];
} # new

sub package_name { $GeneratedPackageName }

sub _expanded_tokenizer_defs ($) {
  if ($LANG eq 'XML') {
    my $expanded_json_path = $DefDataPath->child
        ('../../../../../data-web-defs/data/xml-tokenizer-expanded.json'); # XXX
    return json_bytes2perl $expanded_json_path->slurp;
  } else {
    my $expanded_json_path = $DefDataPath->child
        ('html-tokenizer-expanded.json');
    return json_bytes2perl $expanded_json_path->slurp;
  }
} # _expanded_tokenizer_defs

sub _parser_defs ($) {
  if ($LANG eq 'XML') {
    my $expanded_json_path = $DefDataPath->child
        ('../../../../../data-web-defs/data/xml-tree-constructor-expanded.json'); # XXX
    return json_bytes2perl $expanded_json_path->slurp;
  } else {
    my $expanded_json_path = $DefDataPath->child
        ('html-tree-constructor-expanded-no-isindex.json');
    return json_bytes2perl $expanded_json_path->slurp;
  }
} # _parser_defs

sub _element_defs ($) {
  my $json_path = $DefDataPath->child ('elements.json');
  return json_bytes2perl $json_path->slurp;
} # _element_defs

my $Vars = {
  Scripting => {input => 1, type => 'boolean'},
  IframeSrcdoc => {input => 1, type => 'boolean'},
  Confident => {save => 1, type => 'boolean'},
  DI => {save => 1, type => 'index'},
  AnchoredIndex => {save => 1, type => 'index', default => 0},
  EOF => {save => 1, type => 'boolean'},
  Offset => {save => 1, type => 'index', default => 0},
  State => {save => 1, type => 'enum'},
  Token => {save => 1, type => 'struct?'},
  Attr => {save => 1, type => 'struct?'},
  Temp => {save => 1, type => 'string?'},
  TempIndex => {save => 1, type => 'index'},
  LastStartTagName => {save => 1, type => 'string?'},
  IM => {save => 1, type => 'enum'},
  TEMPLATE_IMS => {unchanged => 1, type => 'list'},
  ORIGINAL_IM => {save => 1, type => 'enum?'},
  FRAMESET_OK => {save => 1, type => 'boolean', default => 'true'},
  QUIRKS => {save => 1, type => 'boolean'},
  NEXT_ID => {save => 1, type => 'index', default => 1},
  HEAD_ELEMENT => {save => 1, type => 'struct?'},
  FORM_ELEMENT => {save => 1, type => 'struct?'},
  CONTEXT => {save => 1, type => 'struct?'},
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

if ($LANG eq 'XML') {
  $Vars->{DTDMode} = {type => 'enum', save => 1, default => 'N/A'};
  $Vars->{OpenMarkedSections} = {unchanged => 1, type => 'list'};
  $Vars->{OpenCMGroups} = {unchanged => 1, type => 'list'};
  $Vars->{InitialCMGroupDepth} = {save => 1, type => 'integer', default => 0};
  $Vars->{DTDDefs} = {unchanged => 1, type => 'map'};
  $Vars->{OriginalState} = {save => 1, type => 'enum'};
  $Vars->{SC} = {input => 1, from_method => 1};
  $Vars->{InMDEntity} = {input => 1, unchanged => 1, type => 'boolean'};
  $Vars->{InLiteral} = {save => 1, type => 'boolean'};
}

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
  $s =~ s/PARAMETER_ENTITY/PE/g;
  $s =~ s/DECLARATION/DECL/g;
  $s =~ s/CONTENT_MODEL/CM/g;
  $s =~ s/KEYWORD/KWD/g;
  $s =~ s/ENTITY/ENT/g;
  $s =~ s/REFERENCE/REF/g;
  $s =~ s/NUMBER/NUM/g;
  $s =~ s/^BEFORE_/B_/;
  $s =~ s/^AFTER_/A_/;
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

sub switch_state_code ($) {
  my $state = $_[0];
  my @code;
  push @code, sprintf q{$State = %s;}, state_const $state;
  if ($state =~ /(?<!end )tag open state/ or
      $state =~ /less-than sign state/) {
    push @code,
        q{$AnchoredIndex = $Offset + (pos $Input) - 1;};
  }
  #push @code, qq{warn "State changed to $state";};
  return join "\n", @code;
} # switch_state_code

sub serialize_actions ($;%);
sub serialize_actions ($;%) {
  my ($acts, %args) = @_;
  ## Generate |return 1| to abort tokenizer, |return 0| to abort
  ## current steps.
  my @result;
  my $return;
  my $reconsume;
  for (@{$acts->{actions}}) {
    my $type = $_->{type};
    if ($type eq 'parse error') {
      if (defined $_->{if}) {
        if ($_->{if} eq 'temp-wrong-case') {
          push @result, sprintf q{
            unless ($Temp eq q{%s}) {
              push @$Errors, {type => '%s', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1%s};
            }
          },
              $_->{expected_keyword}, $_->{error_type} // $_->{name},
              (defined $_->{index_offset} ? sprintf q{ - %d}, $_->{index_offset} : '');
        } elsif ($_->{if} eq 'OE is empty') {
          push @result, sprintf q{
            unless (@$OE) {
              push @$Errors, {type => '%s', level => 'm',
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          }, $_->{error_type} // $_->{name};
        } elsif ($_->{if} eq 'sections is not empty') {
          push @result, sprintf q{
            if (@$OpenMarkedSections) {
              push @$Errors, {type => '%s', level => 'm',
                              di => $DI, index => $Offset + (pos $Input)%s};
            }
          },
              $_->{error_type} // $_->{name},
              $args{in_eof} ? '' : ' - 1';
        } else {
          die "Unknown condition |$_->{if}|";
        }
      } else {
        if ($args{in_eof}) {
          push @result, sprintf q[
            push @$Errors, {type => '%s', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)%s};
          ],
              $_->{error_type} // $_->{name},
              (defined $_->{index_offset} ? sprintf q{ - %d}, $_->{index_offset} : '');
        } else {
          push @result, sprintf q[
            push @$Errors, {type => '%s', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1%s};
          ],
              $_->{error_type} // $_->{name},
              (defined $_->{index_offset} ? sprintf q{ - %d}, $_->{index_offset} : '');
        }
      }
    } elsif ($type eq 'switch') {
      if (not defined $_->{if}) {
        push @result, switch_state_code $_->{state};
      } elsif ($_->{if} eq 'appropriate end tag') {
        die unless $_->{break};
        push @result, sprintf q[
          if (defined $LastStartTagName and
              $Token->{tag_name} eq $LastStartTagName) {
            %s
            return 1;
          }
        ], switch_state_code $_->{state};
      } elsif ($_->{if} eq 'in-foreign') {
        die unless $_->{break};
        push @result, sprintf q{
          if (not defined $InForeign) {
            pos ($Input) -= length $1;
            return 1;
          } else {
            if ($InForeign) {
              %s
              return 0;
            }
          }
        }, switch_state_code $_->{state};
      } elsif ($_->{if} eq 'DTD mode is not internal subset') {
        die unless $_->{break};
        push @result, sprintf q[
          unless ($DTDMode eq 'internal subset' or
                  $DTDMode eq 'parameter entity in internal subset') {
            %s
            return 1;
          }
        ], switch_state_code $_->{state};
      } elsif ($_->{if} eq 'DTD mode is internal subset') {
        die unless $_->{break};
        push @result, sprintf q[
          if ($DTDMode eq 'internal subset' or
              $DTDMode eq 'parameter entity in internal subset') {
            %s
            return 1;
          }
        ], switch_state_code $_->{state};
      } elsif ($_->{if} eq 'fragment') {
        die unless $_->{break};
        push @result, sprintf q[
          if (defined $CONTEXT) {
            %s
            return 1;
          }
        ], switch_state_code $_->{state};
      } else {
        die "Unknown if |$_->{if}|";
      }
    } elsif ($type eq 'parse error-and-switch') {
      if (defined $_->{if}) {
        die unless $_->{break};
        my $cond;
        if ($_->{if} eq 'fragment') {
          $cond = 'defined $CONTEXT';
        } elsif ($_->{if} eq 'md-fragment') {
          $cond = '$InMDEntity';
        } else {
          die $_->{if};
        }
        push @result, sprintf q{
          if (%s) {
            push @$Errors, {type => '%s', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1%s};
            %s
            return 1;
          }
        },
            $cond,
            $_->{error_type} // $_->{name},
            (defined $_->{index_offset} ? sprintf q{ - %d}, $_->{index_offset} : ''),
            switch_state_code $_->{state};
      } else {
        push @result, sprintf q{
          push @$Errors, {type => '%s', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)%s%s};
          %s
        },
            $_->{error_type} // $_->{name},
            ($args{in_eof} ? '' : ' - 1'),
            (defined $_->{index_offset} ? sprintf q{ - %d}, $_->{index_offset} : ''),
            switch_state_code $_->{state};
      }
    } elsif ($type eq 'switch-and-emit') {
      die "Unknown if |$_->{if}|" unless $_->{if} eq 'appropriate end tag';
      die unless $_->{break};
      push @result, sprintf q[
        if (defined $LastStartTagName and
            $Token->{tag_name} eq $LastStartTagName) {
          %s
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      ], switch_state_code $_->{state}, $_->{break};
    } elsif ($type eq 'switch-by-temp') {
      push @result, sprintf q[
        if ($Temp eq 'script') {
          %s
        } else {
          %s
        }
      ], switch_state_code $_->{script_state}, switch_state_code $_->{state};
    } elsif ($type eq 'break') { # XML
      if ($_->{if} eq 'md-fragment') {
        push @result, sprintf q{if ($InMDEntity) { return %s }}, $return // '1';
      } else {
        die $_->{if};
      }
    } elsif ($type eq 'reconsume') {
      $reconsume = 1;
    } elsif ($type eq 'emit') {
      if ($_->{possible_token_types}->{'end tag token'}) {
        push @result, q{
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
            return 1 if @$OE <= 1;
          }
        };
      }
      if ($_->{possible_token_types}->{'ENTITY token'} or
          $_->{possible_token_types}->{'NOTATION token'} or
          $_->{possible_token_types}->{'ATTLIST token'} or
          $_->{possible_token_types}->{'ELEMENT token'}) {
        push @result, q{$Token->{StopProcessing} = 1 if $DTDDefs->{StopProcessing};};
      }
      if ($_->{possible_token_types}->{'DOCTYPE token'} and
          $LANG eq 'XML') {
        $return = q{1 if $Token->{type} == DOCTYPE_TOKEN};
      }
      if ($_->{possible_token_types}->{'ENTITY token'}) {
        $return = q{1 if $Token->{type} == ENTITY_TOKEN};
      }
    } elsif ($type eq 'emit-eof') {
      if (defined $_->{if}) {
        if ($_->{if} eq 'fragment' and $_->{break}) {
          push @result, q{
            if (defined $CONTEXT) {
              push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                              di => $DI,
                              index => $Offset + pos $Input};
              return 1;
            }
          };
        } else {
          die $_->{if};
        }
      } else {
        push @result, q{
          push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                          di => $DI,
                          index => $Offset + pos $Input};
        };
        $return = 1;
      }
    } elsif ($type eq 'emit-temp') {
      push @result, q{
        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      };
    } elsif ($type eq 'create') {
      push @result, sprintf q{
        $Token = {type => %s_TOKEN, tn => 0, DTDMode => $DTDMode,
                  di => $DI, index => $AnchoredIndex};
      }, map { s/ token$//; s/[- ]/_/g; uc $_ } $_->{token};
    } elsif ($type eq 'create-attr') {
      push @result, q[$Attr = {di => $DI};];
    } elsif ($type eq 'set-attr') {
      push @result, q{
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
      };
    } elsif ($type eq 'set' or
             $type eq 'set-to-attr' or
             $type eq 'set-to-temp' or
             $type eq 'set-to-allowed-token' or
             $type eq 'set-to-cmgroup' or
             $type eq 'set-to-cmelement' or
             $type eq 'append' or
             $type eq 'emit-char' or
             $type eq 'append-to-attr' or
             $type eq 'append-to-temp' or
             $type eq 'append-to-allowed-token' or
             $type eq 'append-to-cmelement') {
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
        if ($field eq 'value' or $field eq 'data') {
          # IndexedString
          if (defined $_->{capture_index}) {
            push @result, sprintf q[$Token->{q<%s>} = [[%s, $DI, $Offset + $-[%d]]];], $field, $value, $_->{capture_index};
          } elsif ($args{in_eof}) {
            push @result, sprintf q[$Token->{q<%s>} = [[%s, $DI, $Offset + (pos $Input)]];], $field, $value;
          } else {
            push @result, sprintf q[$Token->{q<%s>} = [[%s, $DI, $Offset + (pos $Input) - length $1]];], $field, $value;
          }
        } else {
          push @result, sprintf q[$Token->{q<%s>} = %s;], $field, $value;
        }
      } elsif ($type eq 'set-to-attr') {
        #die if $field eq 'value' or $field eq 'data';
        push @result, sprintf q[$Attr->{q<%s>} = %s;], $field, $value;
        if ($field eq 'name') {
          if (defined $_->{capture_index}) {
            push @result, sprintf q{$Attr->{index} = $Offset + $-[%d];},
                $_->{capture_index};
          } else {
            push @result, sprintf q{$Attr->{index} = $Offset + (pos $Input) - length $1;};
          }
        }
      } elsif ($type eq 'append') {
        if ($field eq 'value' or $field eq 'data') {
          # IndexedString
          if (defined $_->{capture_index}) {
            push @result, sprintf q[push @{$Token->{q<%s>}}, [%s, $DI, $Offset + $-[%d]%s];],
                $field, $value, $_->{capture_index},
                (defined $_->{index_offset} ? ' - ' . $_->{index_offset} : '');
          } elsif ($args{in_eof}) {
            push @result, sprintf q[push @{$Token->{q<%s>}}, [%s, $DI, $Offset + (pos $Input)%s];], $field, $value,
                (defined $_->{index_offset} ? ' - ' . $_->{index_offset} : '');
          } else {
            push @result, sprintf q[push @{$Token->{q<%s>}}, [%s, $DI, $Offset + (pos $Input) - (length $1)%s];], $field, $value,
                (defined $_->{index_offset} ? ' - ' . $_->{index_offset} : '');
          }
        } else {
          push @result, sprintf q[$Token->{q<%s>} .= %s;], $field, $value;
        }
      } elsif ($type eq 'append-to-attr') {
        if ($field eq 'value' or $field eq 'data') {
          # IndexedString
          if (defined $_->{capture_index}) {
            push @result, sprintf q[push @{$Attr->{q<%s>}}, [%s, $DI, $Offset + $-[%d]];], $field, $value, $_->{capture_index};
          } else {
            push @result, sprintf q[push @{$Attr->{q<%s>}}, [%s, $DI, $Offset + (pos $Input) - length $1];], $field, $value;
          }
        } else {
          push @result, sprintf q[$Attr->{q<%s>} .= %s;], $field, $value;
        }
      } elsif ($type eq 'append-to-temp') {
        push @result, sprintf q[$Temp .= %s;], $value;
      } elsif ($type eq 'set-to-temp') {
        push @result, sprintf q[$Temp = %s;], $value;
        my $index_delta = q{$Offset + (pos $Input)};
        $index_delta .= q{ - (length $1)} unless $args{in_eof};
        if (defined $_->{value}) {
          $index_delta .= sprintf q{ - %d}, $_->{index_offset};
        }
        push @result, sprintf q{$TempIndex = %s;}, $index_delta;
      } elsif ($type eq 'set-to-allowed-token') {
        push @result, sprintf q[$Attr->{allowed_tokens}->[-1] = %s;], $value;
      } elsif ($type eq 'append-to-allowed-token') {
        push @result, sprintf q[$Attr->{allowed_tokens}->[-1] .= %s;], $value;
      } elsif ($type eq 'set-to-cmgroup') {
        push @result, sprintf q[$OpenCMGroups->[-1]->{q<%s>} = %s;],
            $field, $value;
      } elsif ($type eq 'append-to-cmelement') {
        push @result, sprintf q[$OpenCMGroups->[-1]->{items}->[-1]->{q<%s>} .= %s;],
            $field, $value;
      } elsif ($type eq 'set-to-cmelement') {
        push @result, sprintf q[$OpenCMGroups->[-1]->{items}->[-1]->{q<%s>} = %s;],
            $field, $value;
      } elsif ($type eq 'emit-char') {
        my $index_delta = q{$Offset + (pos $Input) - (length $1)};
        if (defined $_->{value}) {
          if ($_->{value} =~ /^</) { # e.g. |</| of non-matching RCDATA end tag
            $index_delta = q{$AnchoredIndex};
          } else {
            $index_delta .= sprintf q{ - %d}, $_->{index_offset};
          }
        } else {
          $index_delta .= sprintf q{ - %d}, $_->{index_offset}
              if defined $_->{index_offset};
        }
        push @result, sprintf q{
          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => %s,
                          di => $DI, index => %s};
        }, $value, $index_delta;
      } else {
        die $type;
      }
    } elsif ($type eq 'set-empty') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      if ($field eq 'value' or $field eq 'data') {
        if (defined $_->{index_offset}) {
          push @result, sprintf q[$Token->{q<%s>} = [['', $DI, $Offset + (pos $Input) - %d]];], $field, $_->{index_offset}; # IndexedString
        } else {
          push @result, sprintf q[$Token->{q<%s>} = [['', $DI, $Offset + pos $Input]];], $field; # IndexedString
        }
      } else {
        push @result, sprintf q[$Token->{q<%s>} = '';], $field;
      }
    } elsif ($type eq 'set-empty-to-attr') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      if ($field eq 'value' or $field eq 'data') {
        push @result, sprintf q[$Attr->{q<%s>} = [['', $Attr->{di}, $Attr->{index}]];], $field; # IndexedString
      } else {
        push @result, sprintf q[$Attr->{q<%s>} = '';], $field;
      }
    } elsif ($type eq 'set-empty-to-temp') {
      push @result, q{
        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      };
    } elsif ($type eq 'append-temp') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      if ($field eq 'value' or $field eq 'data') {
        push @result, sprintf q[push @{$Token->{q<%s>}}, [$Temp, $DI, $TempIndex];], $field; # IndexedString
      } else {
        push @result, sprintf q[$Token->{q<%s>} .= $Temp;], $field;
      }
    } elsif ($type eq 'append-temp-to-attr') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      if ($field eq 'value' or $field eq 'data') {
        push @result, sprintf q[push @{$Attr->{q<%s>}}, [$Temp, $DI, $TempIndex];], $field; # IndexedString
      } else {
        push @result, sprintf q[$Attr->{q<%s>} .= $Temp;], $field;
      }
    } elsif ($type eq 'set-flag') {
      my $field = $_->{field};
      $field =~ tr/ -/__/ if defined $field;
      push @result, sprintf q[$Token->{q<%s>} = 1;], $field;
    } elsif ($type eq 'process-temp-as-decimal') {
      use Data::Dumper;
      push @result, sprintf q{
        if (not @$OE and $DTDMode eq 'N/A') {
          push @$Errors, {level => 'm',
                          type => 'ref outside of root element',
                          value => $Temp.';',
                          di => $DI, index => $TempIndex};
        }
      } if $LANG eq 'XML' and not $_->{in_attr};
      push @result, q{
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
        ## <XML>
        } elsif ($Web::HTML::_SyntaxDefs->{xml_char_discouraged}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'w',
                          di => $DI, index => $TempIndex};
        ## </XML>
        }
        $Temp = chr $code;
      };
      $result[-1] =~ s{<XML>.*?</XML>}{}gs unless $LANG eq 'XML';
      push @result, q{$Attr->{has_ref} = 1;} if $_->{in_attr};
    } elsif ($type eq 'process-temp-as-hexadecimal') {
      push @result, q{
        if (not @$OE and $DTDMode eq 'N/A') {
          push @$Errors, {level => 'm',
                          type => 'ref outside of root element',
                          value => $Temp.';',
                          di => $DI, index => $TempIndex};
        }
      } if $LANG eq 'XML' and not $_->{in_attr};
      push @result, q{
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
        ## <XML>
        } elsif ($Web::HTML::_SyntaxDefs->{xml_char_discouraged}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'w',
                          di => $DI, index => $TempIndex};
        ## </XML>
        }
        $Temp = chr $code;
      };
      $result[-1] =~ s{<XML>.*?</XML>}{}gs unless $LANG eq 'XML';
      push @result, q{$Attr->{has_ref} = 1;} if $_->{in_attr};
    } elsif ($type eq 'process-temp-as-named') {
      if ($_->{in_attr}) {
        push @result, sprintf q{
          my $return;
          REF: {
            ## <XML>
            if (defined $DTDDefs->{ge}->{$Temp}) {
              my $ent = $DTDDefs->{ge}->{$Temp};

              if (my $ext = $ent->{external}) {
                if (not $ext->{vc_error_reported} and $DTDDefs->{XMLStandalone}) {
                  push @$Errors, {level => 'm',
                                  type => 'VC:Standalone Document Declaration:entity',
                                  value => $Temp,
                                  di => $DI, index => $TempIndex};
                  $ext->{vc_error_reported} = 1;
                }
              }

              if (defined $ent->{notation_name}) {
                ## Unparsed entity
                push @$Errors, {level => 'm',
                                type => 'unparsed entity',
                                value => $Temp,
                                di => $DI, index => $TempIndex};
                last REF;
              } elsif ($ent->{open}) {
                push @$Errors, {level => 'm',
                                type => 'WFC:No Recursion',
                                value => $Temp,
                                di => $DI, index => $TempIndex};
                last REF;
              } elsif (defined $ent->{value}) {
                ## Internal entity with "&" and/or "<"
                my $value = join '', map { $_->[0] } @{$ent->{value}}; # IndexedString
                if ($value =~ /</) {
                  push @$Errors, {level => 'm',
                                  type => 'entref in attr has element',
                                  value => $Temp,
                                  di => $DI, index => $TempIndex};
                  last REF;
                } else {
                  push @$Callbacks, [$OnAttrEntityReference,
                                     {entity => $ent,
                                      ref => {di => $DI, index => $TempIndex},
                                      in_default_attr => %d}];
                  $TempIndex += length $Temp;
                  $Temp = '';
                  $return = 1;
                  last REF;
                }
              } else {
                ## External parsed entity
                push @$Errors, {level => 'm',
                                type => 'WFC:No External Entity References',
                                value => $Temp,
                                di => $DI, index => $TempIndex};
                last REF;
              }
            }
            ## </XML>

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (%d) { # before_equals
                    #push @$Errors, {type => 'no refc',
                    #                level => 'm',
                    #                di => $DI,
                    #                index => $TempIndex + $_};
                    last REF;
                  } else {
                    #push @$Errors, {type => 'no refc',
                    #                level => 'm',
                    #                di => $DI,
                    #                index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }

                ## <XML>
                if ($DTDDefs->{has_charref_decls}) {
                  if ($DTDDefs->{charref_vc_error}) {
                    push @$Errors, {level => 'm',
                                    type => 'VC:Standalone Document Declaration:entity',
                                    value => $Temp,
                                    di => $DI, index => $temp_index};
                  }
                } elsif ({
                  '&amp;' => 1, '&quot;' => 1, '&lt;' => 1, '&gt;' => 1,
                  '&apos;' => 1,
                }->{$Temp}) {
                  if ($DTDDefs->{need_predefined_decls} or
                      not $DTDMode eq 'N/A') {
                    push @$Errors, {level => 's',
                                    type => 'entity not declared',
                                    value => $Temp,
                                    di => $DI, index => $temp_index};
                  }
                  ## If the document has no DOCTYPE, skip warning.
                } else {
                  ## Not a declared XML entity.
                  push @$Errors, {level => 'm',
                                  type => 'entity not declared',
                                  value => $Temp,
                                  di => $DI, index => $temp_index};
                }
                ## </XML>

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
              $DTDDefs->{entity_names}->{$Temp}
                  ||= {di => $DI, index => $TempIndex};
            }
          } # REF
        }, !!$_->{in_default_attr}, !!$_->{before_equals};
      } elsif ($_->{in_entity_value}) { ## XML only
        die;
      } else { # in content
        push @result, q{
          my $return;
          REF: {
            ## <XML>

            if (not @$OE) {
              push @$Errors, {level => 'm',
                              type => 'ref outside of root element',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              $TempIndex += length $Temp;
              $Temp = '';
              last REF;
            }

            if (defined $DTDDefs->{ge}->{$Temp}) {
              my $ent = $DTDDefs->{ge}->{$Temp};

              if (my $ext = $ent->{external}) {
                if (not $ext->{vc_error_reported} and $DTDDefs->{XMLStandalone}) {
                  push @$Errors, {level => 'm',
                                  type => 'VC:Standalone Document Declaration:entity',
                                  value => $Temp,
                                  di => $DI, index => $TempIndex};
                  $ext->{vc_error_reported} = 1;
                }
              }

              if ($ent->{only_text}) {
                ## Internal entity with no "&" or "<"

                ## A variant of |emit-temp|
                push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                value => $_->[0],
                                di => $_->[1], index => $_->[2]}
                    for @{$ent->{value}};
                $TempIndex += length $Temp;
                $Temp = '';
                last REF;
              } elsif (defined $ent->{notation_name}) {
                ## Unparsed entity
                push @$Errors, {level => 'm',
                                type => 'unparsed entity',
                                value => $Temp,
                                di => $DI, index => $TempIndex};
                last REF;
              } elsif ($ent->{open}) {
                push @$Errors, {level => 'm',
                                type => 'WFC:No Recursion',
                                value => $Temp,
                                di => $DI, index => $TempIndex};
                last REF;
              } else {
                ## Internal entity with "&" and/or "<"
                ## External parsed entity
                push @$Callbacks, [$OnContentEntityReference,
                                   {entity => $ent,
                                    ref => {di => $DI, index => $TempIndex},
                                    ops => $OP}];
                $TempIndex += length $Temp;
                $Temp = '';
                $return = 1;
                last REF;
              }
            }
            ## </XML>

            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                my $temp_index = $TempIndex;

                unless (';' eq substr $Temp, $_-1, 1) {
                  #push @$Errors, {type => 'no refc',
                  #                level => 'm',
                  #                di => $DI,
                  #                index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }

                ## <XML>
                if ($DTDDefs->{has_charref_decls}) {
                  if ($DTDDefs->{charref_vc_error}) {
                    push @$Errors, {level => 'm',
                                    type => 'VC:Standalone Document Declaration:entity',
                                    value => $Temp,
                                    di => $DI, index => $temp_index};
                  }
                } elsif ({
                  '&amp;' => 1, '&quot;' => 1, '&lt;' => 1, '&gt;' => 1,
                  '&apos;' => 1,
                }->{$Temp}) {
                  if ($DTDDefs->{need_predefined_decls} or
                      not $DTDMode eq 'N/A') {
                    push @$Errors, {level => 's',
                                    type => 'entity not declared',
                                    value => $Temp,
                                    di => $DI, index => $temp_index};
                  }
                  ## If the document has no DOCTYPE, skip warning.
                } else {
                  ## Not a declared XML entity.
                  push @$Errors, {level => 'm',
                                  type => 'entity not declared',
                                  value => $Temp,
                                  di => $DI, index => $temp_index};
                }
                ## </XML>

                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            if ($Temp =~ /;\z/) {
              push @$Errors, {level => 'm',
                              type => 'entity not declared',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
              $DTDDefs->{entity_names}->{$Temp}
                  ||= {di => $DI, index => $TempIndex};
            }
          } # REF
        };
      }
      $return = '1 if $return';
      $result[-1] =~ s{<XML>.*?</XML>}{}gs unless $LANG eq 'XML';
    } elsif ($type eq 'validate-temp-as-entref') {
      push @result, q{
        $DTDDefs->{entity_names_in_entity_values}->{$Temp}
            ||= {di => $DI, index => $TempIndex};
      };
    } elsif ($type eq 'process-temp-as-peref-dtd') { # XML only
      push @result, q{
        my $return;
        REF: {
          if ($DTDDefs->{StopProcessing}) {
            $TempIndex += length $Temp;
            $Temp = '';
            last REF;
          } elsif (defined $DTDDefs->{pe}->{$Temp}) {
            my $ent = $DTDDefs->{pe}->{$Temp};
            if ($ent->{open}) {
              push @$Errors, {level => 'm',
                              type => 'WFC:No Recursion',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
            } elsif (defined $ent->{public_identifier} and
                     $Web::HTML::_SyntaxDefs->{charrefs_pubids}->{$ent->{public_identifier}}) {
              ## Public identifier normalization is intentionally not
              ## done (Chrome behavior).

              $DTDDefs->{has_charref_decls} = 1;
              $DTDDefs->{charref_vc_error} = 1 if $DTDDefs->{XMLStandalone};
              $TempIndex += length $Temp;
              $Temp = '';
              $return = 1;
              last REF;
            } else {
              push @$Callbacks, [$OnDTDEntityReference,
                                 {entity => $ent,
                                  ref => {di => $DI, index => $TempIndex}}];
              $TempIndex += length $Temp;
              $Temp = '';
              $return = 1;
              last REF;
            }
          } else {
            push @$Errors, {level => 'm',
                            type => 'entity not declared',
                            value => $Temp,
                            di => $DI, index => $TempIndex};
            $DTDDefs->{entity_names}->{$Temp}
              ||= {di => $DI, index => $TempIndex};
          }

          if (not $DTDDefs->{StopProcessing} and
              not $DTDDefs->{XMLStandalone}) {
            push @$Errors, {level => 'i',
                            type => 'stop processing',
                            di => $DI, index => $TempIndex};
            $DTDDefs->{StopProcessing} = 1;
          }
        } # REF
      };
      $return = '1 if $return';
    } elsif ($type eq 'process-temp-as-peref-entity-value') { # XML only
      push @result, q{
        my $return;
        REF: {
          if ($DTDDefs->{StopProcessing}) {
            $TempIndex += length $Temp;
            $Temp = '';
            last REF;
          } elsif (defined $DTDDefs->{pe}->{$Temp}) {
            my $ent = $DTDDefs->{pe}->{$Temp};
            if ($ent->{open}) {
              push @$Errors, {level => 'm',
                              type => 'WFC:No Recursion',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
            } elsif ($DTDMode eq 'internal subset' or
                     $DTDMode eq 'parameter entity in internal subset') {
              ## In a markup declaration in internal subset
              push @$Errors, {level => 'm',
                              type => 'WFC:PEs in Internal Subset',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
            } else {
              push @$Callbacks, [$OnEntityValueEntityReference,
                                 {entity => $ent,
                                  ref => {di => $DI, index => $TempIndex}}];
              $TempIndex += length $Temp;
              $Temp = '';
              $return = 1;
              last REF;
            }
          } else {
            push @$Errors, {level => 'm',
                            type => 'entity not declared',
                            value => $Temp,
                            di => $DI, index => $TempIndex};
            $DTDDefs->{entity_names}->{$Temp}
              ||= {di => $DI, index => $TempIndex};
          }

          if (not $DTDDefs->{StopProcessing} and
              not $DTDDefs->{XMLStandalone}) {
            push @$Errors, {level => 'i',
                            type => 'stop processing',
                            di => $DI, index => $TempIndex};
            $DTDDefs->{StopProcessing} = 1;
          }
        } # REF
      };
      $return = '1 if $return';
    } elsif ($type eq 'process-temp-as-peref-md') { # XML only
      push @result, sprintf q{
        my $return;
        REF: {
          if ($DTDDefs->{StopProcessing}) {
            $TempIndex += length $Temp;
            $Temp = '';
            last REF;
          } elsif (defined $DTDDefs->{pe}->{$Temp}) {
            my $ent = $DTDDefs->{pe}->{$Temp};
            if ($ent->{open}) {
              push @$Errors, {level => 'm',
                              type => 'WFC:No Recursion',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
            } elsif ($DTDMode eq 'internal subset' or
                     $DTDMode eq 'parameter entity in internal subset') {
              ## In a markup declaration in internal subset
              push @$Errors, {level => 'm',
                              type => 'WFC:PEs in Internal Subset',
                              value => $Temp,
                              di => $DI, index => $TempIndex};
            } else {
              push @$Callbacks, [$OnMDEntityReference,
                                 {entity => $ent,
                                  ref => {di => $DI, index => $TempIndex}}];
              $TempIndex += length $Temp;
              $Temp = '';
              $return = 1;
              last REF;
            }
          } else {
            push @$Errors, {level => 'm',
                            type => 'entity not declared',
                            value => $Temp,
                            di => $DI, index => $TempIndex};
            $DTDDefs->{entity_names}->{$Temp}
              ||= {di => $DI, index => $TempIndex};
          }

          if (not $DTDDefs->{StopProcessing} and
              not $DTDDefs->{XMLStandalone}) {
            push @$Errors, {level => 'i',
                            type => 'stop processing',
                            di => $DI, index => $TempIndex};
            %s
            $DTDDefs->{StopProcessing} = 1;
          }
        } # REF
      }, switch_state_code 'bogus markup declaration state';
      $return = '1 if $return';
    } elsif ($type eq 'set-original-state') { # XML only
      push @result, sprintf q{$OriginalState = [%s, %s];},
          state_const $_->{state}, state_const $_->{external_state};

    } elsif ($type eq 'process-xml-declaration-in-temp') {
      push @result, sprintf q{
        if ($Temp =~ s{^<\?xml(?=[\x09\x0A\x0C\x20?])(.*?)\?>}{}s) {
          my $text_decl = {data => [[$1, $DI, $TempIndex + 5]], # IndexedString
                           di => $DI, index => $TempIndex};
          $TempIndex += length $1;
          $text_decl->{data}->[0]->[0] =~ s/^([\x09\x0A\x0C\x20]*)//;
          $text_decl->{data}->[0]->[2] += length $1;
          _process_xml_decl $text_decl;
        } else {
          push @$Errors, {level => 's',
                          type => 'no XML decl',
                          di => $DI, index => $TempIndex};
          %s
        }
      }, (serialize_actions {actions => $_->{false_actions} || []}, %args);

    } elsif ($type eq 'set-in-literal') {
      push @result, q{$InLiteral = 1;};
    } elsif ($type eq 'unset-in-literal') {
      push @result, q{undef $InLiteral;};

    } elsif ($type eq 'set-DTD-mode') {
      push @result, sprintf q{$DTDMode = q{%s};}, $_->{value};
    } elsif ($type eq 'emit-end-of-DOCTYPE') {
      push @result, q{
        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
      };
      $return = 1;
    } elsif ($type eq 'insert-IGNORE') {
      push @result, q{push @$OpenMarkedSections, 'IGNORE';};
    } elsif ($type eq 'insert-INCLUDE') {
      push @result, q{push @$OpenMarkedSections, 'INCLUDE';};
    } elsif ($type eq 'pop-section') { # and reset
      push @result, sprintf q{
        if (@$OpenMarkedSections) {
          pop @$OpenMarkedSections;
          if (@$OpenMarkedSections) {
            if ($OpenMarkedSections->[-1] eq 'INCLUDE') {
              %s
            } else {
              %s
            }
          } else {
            %s
          }
        } else {
          push @$Errors, {level => 'm',
                          type => 'string in internal subset', # ]]>
                          di => $DI, index => $Offset + (pos $Input) - 3};
          %s
        }
      },
          switch_state_code 'DTD state',
          switch_state_code 'ignored section state',
          switch_state_code 'DTD state',
          switch_state_code 'DTD state';
    } elsif ($type eq 'create-attrdef') {
      push @result, q[
        $Attr = {di => $DI, index => $Offset + pos $Input};
      ];
    } elsif ($type eq 'insert-attrdef') {
      push @result, q[
        push @{$Token->{attr_list} ||= []}, $Attr;
      ];
    } elsif ($type eq 'insert-allowed-token') {
      push @result, q{push @{$Attr->{allowed_tokens} ||= []}, '';};
    } elsif ($type eq 'create-cmgroup') {
      push @result, q{my $cmgroup = {items => [], separators => [], di => $DI, index => $Offset + pos $Input};};
    } elsif ($type eq 'set-cmgroup') {
      push @result, q{$Token->{cmgroup} = $cmgroup;};
    } elsif ($type eq 'push-cmgroup') {
      push @result, q{push @$OpenCMGroups, $cmgroup;};
    } elsif ($type eq 'push-cmgroup-as-only-item') {
      push @result, q{@$OpenCMGroups = ($cmgroup);};
    } elsif ($type eq 'append-cmgroup') {
      push @result, q{push @{$OpenCMGroups->[-1]->{items}}, $cmgroup;};
    } elsif ($type eq 'pop-cmgroup') {
      push @result, sprintf q{
        if ($InitialCMGroupDepth < @$OpenCMGroups) {
          pop @$OpenCMGroups;
        } else {
          push @$Errors, {level => 'm',
                          type => 'unmatched mgc',
                          di => $DI, index => $Offset + (pos $Input)};
          %s
        }
      }, switch_state_code 'bogus markup declaration state';
    } elsif ($type eq 'insert-cmelement') {
      push @result, q{
        push @{$OpenCMGroups->[-1]->{items}},
            {di => $DI, index => $Offset + pos $Input};
      };
    } elsif ($type eq 'append-separator-to-cmgroup') {
      push @result, sprintf q{
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $%d};
      }, $_->{capture_index} || 1;
    } elsif ($type eq 'if-empty') {
      my $list = $_->{list};
      if ($list eq 'cm-group') {
        $list = q{@$OpenCMGroups};
      } else {
        die "Unknown list type |$list|";
      }
      push @result, sprintf q{
        if (not %s) {
          %s
        } else {
          %s
        }
      }, $list,
          (serialize_actions {actions => $_->{false_actions} || []}, %args),
          (serialize_actions $_, %args);

    } else {
      die "Bad action type |$type|";
    }
  }
  push @result, q[pos ($Input)--;] if $reconsume;
  if (defined $return) {
    push @result, qq{return $return;};
  }
  return join '', map { $_ . "\n" } @result;
} # serialize_actions

sub generate_tokenizer {
  my $self = shift;
  
  my $defs = $self->_expanded_tokenizer_defs->{tokenizer};
  my @def_code;

  if ($LANG eq 'HTML') {
    push @def_code, q{my $InvalidCharRefs = $Web::HTML::_SyntaxDefs->{charref_invalid};};
  } else {
    push @def_code, q{my $InvalidCharRefs = $Web::HTML::_SyntaxDefs->{xml_charref_invalid};};
  }

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
      $case .= serialize_actions ($defs->{states}->{$state}->{conds}->{$eof_cond}, in_eof => 1);
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

  push @def_code, q{

sub _tokenize_attr_value ($) { # IndexedString
  my $token = $_[0];
  my @v;
  my $non_sp = 0;
  for my $v (@{$token->{value}}) {
    next unless length $v->[0];
    if ($v->[0] =~ /\x20/) {
      my $pos = $v->[2];
      for (grep { length } split /(\x20+)/, $v->[0], -1) {
        if (/\x20/) {
          push @v, [' ', $v->[1], $pos] if $non_sp;
          $non_sp = 0;
        } else {
          push @v, [$_, $v->[1], $pos];
          $non_sp = 1;
        }
        $pos += length;
      }
    } else {
      push @v, $v;
      $non_sp = 1;
    }
  } # $v
  if (@v and $v[-1]->[0] eq ' ') {
    pop @v;
  }
  return 0 if (join '', map { $_->[0] } @{$token->{value}}) eq
              (join '', map { $_->[0] } @v);
  $token->{value} = \@v;
  return 1;
} # _tokenize_attr_value

  } if $LANG eq 'XML';

  push @def_code, q{

sub strict_checker ($;$) {
  if (@_ > 1) {
    $_[0]->{strict_checker} = $_[1];
  }
  return $_[0]->{strict_checker} || 'Web::XML::Parser::MinimumChecker';
} # strict_checker

  };

  push @def_code, q{

sub _sc ($) {
  return $_[0]->{_sc} ||= do {
    my $sc = $_[0]->strict_checker;
    eval qq{ require $sc } or die $@;
    $sc;
  };
} # _sc

    sub _process_xml_decl ($) {
      my $token = $_[0];
      my $data = join '', map { $_->[0] } @{$token->{data}}; # IndexedString

      my $di = $token->{data}->[0]->[1];
      my $pos = $token->{data}->[0]->[2];
      for (@{$token->{data}}) {
        $di = $_->[1];
        $pos = $_->[2];
        last if length $_->[0];
      }
      my $req_sp = 0;

      if ($data =~ s/\Aversion[\x09\x0A\x20]*=[\x09\x0A\x20]*
                       (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
          my $v = defined $1 ? $1 : $2;
          my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
          $pos += $+[0] - $-[0];
          $req_sp = not length $3;
          $SC->check_hidden_version
              (name => $v,
               onerror => sub {
                 push @$Errors, {@_, di => $di, index => $p};
               });
          unless (defined $CONTEXT) { # XML declaration
            push @$OP, ['xml-version', $v];
          }
      } else {
          if (not defined $CONTEXT) { # XML declaration
            push @$Errors, {level => 'm',
                            type => 'attribute missing:version',
                            di => $di, index => $pos};
          }
      }

      if ($data =~ s/\Aencoding[\x09\x0A\x20]*=[\x09\x0A\x20]*
                       (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
          my $v = defined $1 ? $1 : $2;
          my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
          if ($req_sp) {
            push @$Errors, {level => 'm',
                            type => 'no space before attr name',
                            di => $di, index => $pos};
          }
          $pos += $+[0] - $-[0];
          $req_sp = not length $3;
          $SC->check_hidden_encoding
              (name => $v,
               onerror => sub {
                 push @$Errors, {@_, di => $di, index => $p};
               });
          unless (defined $CONTEXT) { # XML declaration
            push @$OP, ['xml-encoding', $v];
          }
      } else {
        if (defined $CONTEXT) { # text declaration
          push @$Errors, {level => 'm',
                          type => 'attribute missing:encoding',
                          di => $di, index => $pos};
        }
      }

      if ($data =~ s/\Astandalone[\x09\x0A\x20]*=[\x09\x0A\x20]*
                       (?>"([^"]*)"|'([^']*)')[\x09\x0A\x20]*//x) {
          my $v = defined $1 ? $1 : $2;
          if ($req_sp) {
            push @$Errors, {level => 'm',
                            type => 'no space before attr name',
                            di => $di, index => $pos};
          }
          if ($v eq 'yes' or $v eq 'no') {
            if (defined $CONTEXT) { # text declaration
              push @$Errors, {level => 'm',
                              type => 'attribute not allowed:standalone',
                              di => $di, index => $pos};
            } else {
              push @$OP, ['xml-standalone',
                          $DTDDefs->{XMLStandalone} = ($v ne 'no')];
            }
          } else {
            my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
            push @$Errors, {level => 'm',
                            type => 'XML standalone:syntax error',
                            di => $di, index => $p, value => $v};
          }
          $pos += $+[0] - $-[0];
      }

      if (length $data) {
          push @$Errors, {level => 'm',
                          type => 'bogus XML declaration',
                          di => $di, index => $pos};
      }
    } # _process_xml_decl
  } if $LANG eq 'XML';

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
  } elsif ($pattern->{tag_name}) {
    return sprintf q{$tag_name eq %s->{token}->{tag_name}}, $var;
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
    } elsif ($cond->[1] eq '> 1') {
      return q{@$OE > 1};
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
    my $pre = '';
    if ($cond->[0] eq 'oe[1]' or $cond->[0] eq 'oe[-2]') {
      $pre = q{@$OE >= 2 and };
    }
    my $left = node_expr_to_code $cond->[0];
    if ($cond->[1] eq 'is') {
      return $pre.pattern_to_code $cond->[2], $left;
    } elsif ($cond->[1] eq 'is not') {
      return $pre.sprintf q{not (%s)}, pattern_to_code $cond->[2], $left;
    } elsif ($cond->[1] eq 'lc is') {
      return $pre.pattern_to_code {%{$cond->[2]}, _lc => 1}, $left;
    } elsif ($cond->[1] eq 'lc is not') {
      return $pre.sprintf q{not (%s)}, pattern_to_code {%{$cond->[2]}, _lc => 1}, $left;
    } elsif ($cond->[1] eq 'is null') {
      return $pre.sprintf q{not defined %s}, $left;
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
    } elsif ($cond->[1] eq 'has' and $cond->[2] eq 'has internal subset flag') {
      return q{$token->{has_internal_subset_flag}};
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
    } elsif ($cond->[1] eq 'non-empty') {
      if ($cond->[2] eq 'system identifier') {
        return sprintf q{(defined $token->{system_identifier} and length $token->{system_identifier})};
      } else {
        die "Unknown condition |@$cond|";
      }
    } else {
      die "Unknown condition |@$cond|";
    }
  } elsif ($cond->[0] eq 'token tag_name' and
           $cond->[1] eq 'is' and
           defined $cond->[2]) {
    return sprintf q{$token->{tag_name} eq q@%s@}, $cond->[2];
  } elsif ($cond->[0] eq 'token target' and
           $cond->[1] eq 'is' and
           defined $cond->[2]) {
    return sprintf q{$token->{target} eq q@%s@}, $cond->[2];
  } elsif ($cond->[0] eq 'token[type]' and
           $cond->[1] eq 'lc is not' and
           defined $cond->[2]) {
    return sprintf q{
      not (
        defined $token->{attrs}->{type} and
        do {
          my $value = join '', map { $_->[0] } @{$token->{attrs}->{type}->{value}}; # IndexedString
          $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
          $value eq q@%s@;
        }
      )
    }, $cond->[2];
  } elsif ($cond->[0] eq 'fragment') {
    return q{defined $CONTEXT};
  } elsif ($cond->[0] eq 'not fragment') {
    return q{not defined $CONTEXT};
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
  } elsif ($cond->[0] eq 'DOCTYPE system identifier' and
           $cond->[1] eq 'non-empty') {
    return q{length $DTDDefs->{system_identifier}};
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
    die "Unknown condition |@$cond|";
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

sub E2Tns ($) {
  if ($LANG eq 'HTML') {
    return sprintf q{$Element2Type->[%s]}, $_[0];
  } else {
    return sprintf q{$Element2Type->{(%s)}}, $_[0];
  }
} # E2Tns

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
        push @code, sprintf q{
          unless ($IframeSrcdoc) {
            %s
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        }, actions_to_code [$act->{actions}->[0]];
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
    } elsif ($act->{type} eq 'construct the DOCTYPE node, if necessary') { # XML
      push @code, q{push @$OP, ['construct-doctype'];};
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
        $et_code = sprintf q{%s->{$token->{tag_name}} || %s->{'*'}},
            E2Tns 'HTMLNS', E2Tns 'HTMLNS';
      }
      push @code, sprintf q{
        my %s = {id => $NEXT_ID++,
                 token => $token,
                 di => $token->{di}, index => $token->{index},
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
        $et_code = sprintf q{%s->{$token->{tag_name}} || %s->{'*'}},
            E2Tns 'HTMLNS', E2Tns 'HTMLNS';
      }
      push @code, sprintf q{
        my $node = {id => $NEXT_ID++,
                    token => $token,
                    di => $token->{di}, index => $token->{index},
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
        ## Note that $ns can be 0 if $CONTEXT is not an HTML, SVG, or
        ## MathML element.
      } elsif ($act->{ns} eq 'SVG' or $act->{ns} eq 'MathML') {
        push @code, sprintf q{my $ns = %s;}, ns_const $act->{ns};
      } else {
        die $act->{ns};
      }
      
      push @code, sprintf q{
        my $node = {id => $NEXT_ID++,
                    token => $token,
                    di => $token->{di}, index => $token->{index},
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => %s->{$token->{tag_name}} || %s->{'*'} || 0,
                    aet => %s->{$token->{tag_name}} || %s->{'*'} || 0};
      }, E2Tns '$ns', E2Tns '$ns', E2Tns '$ns', E2Tns '$ns';
      if ($act->{ns} eq 'inherit') {
        push @code, sprintf q{
          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = join '', map { $_->[0] } @{$token->{attrs}->{encoding}->{value}}; # IndexedString
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} |= M_ANN_M_ANN_ELS;
              $node->{et} |= M_ANN_M_ANN_ELS;
            }
          }
        };
      }

      ## "Create an element for a token", step 2.
      push @code, q{
        if (defined $token->{attrs}->{xmlns}) {
          # IndexedString
          my $xmlns = join '', map { $_->[0] } @{$token->{attrs}->{xmlns}->{value}};
          if ($ns == SVGNS and $xmlns eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $xmlns eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'foreign:bad xmlns value',
                            level => 'm',
                            value => $xmlns,
                            di => $token->{attrs}->{xmlns}->{di},
                            index => $token->{attrs}->{xmlns}->{index}};
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          # IndexedString
          my $xmlns = join '', map { $_->[0] } @{$token->{attrs}->{'xmlns:xlink'}->{value}};
          unless ($xmlns eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'foreign:bad xmlns value',
                            level => 'm',
                            value => $xmlns,
                            di => $token->{attrs}->{'xmlns:xlink'}->{di},
                            index => $token->{attrs}->{'xmlns:xlink'}->{index}};
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
    } elsif ($act->{type} eq 'create an XML element') { # XML
      push @code, sprintf q{
        my $nsmap = @$OE ? {%%{$OE->[-1]->{nsmap}}} : {
          xml => q<http://www.w3.org/XML/1998/namespace>,
          xmlns => q<http://www.w3.org/2000/xmlns/>,
        };

        my $attrs = $token->{attrs};
        my $attrdefs = $DTDDefs->{attrdefs}->{$token->{tag_name}};
        for my $def (@{$attrdefs or []}) {
          my $attr_name = $def->{name};
          if (defined $attrs->{$attr_name}) {
            $attrs->{$attr_name}->{declared_type} = $def->{declared_type} || 0;
            if ($def->{tokenize}) {
              if (_tokenize_attr_value $attrs->{$attr_name} and
                  $def->{external} and
                  not $def->{external}->{vc_error_reported} and
                  $DTDDefs->{XMLStandalone}) {
                push @$Errors, {level => 'm',
                                type => 'VC:Standalone Document Declaration:attr',
                                di => $def->{di}, index => $def->{index},
                                value => $attr_name};
                $def->{external}->{vc_error_reported} = 1;
              }
            }
          } elsif (defined $def->{value}) {
            push @{$token->{attr_list}},
            $attrs->{$attr_name} = {
              name => $attr_name,
              value => $def->{value},
              declared_type => $def->{declared_type} || 0,
              not_specified => 1,
              di => $def->{di}, index => $def->{index},
            };

            if ($def->{external} and
                not $def->{external}->{vc_error_reported} and
                $DTDDefs->{XMLStandalone}) {
              push @$Errors, {level => 'm',
                              type => 'VC:Standalone Document Declaration:attr',
                              di => $def->{di}, index => $def->{index},
                              value => $attr_name};
              $def->{external}->{vc_error_reported} = 1;
            }
          }
        }
        
        for (keys %%$attrs) {
          if (/^xmlns:./s) {
            my $prefix = substr $_, 6;
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
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
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
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
        my ($prefix, $ln) = split /:/, $token->{tag_name}, 2;
        
        if (defined $ln and $prefix ne '' and $ln ne '') { # prefixed
          if (defined $nsmap->{$prefix}) {
            $ns = $nsmap->{$prefix};
          } else {
            ## NOTE: Error should be detected at the DOM layer.
            ($prefix, $ln) = (undef, $token->{tag_name});
          }
        } else {
          $ns = $nsmap->{''} if $prefix ne '' and not defined $ln;
          ($prefix, $ln) = (undef, $token->{tag_name});
        }

        my $nse = defined $ns ? $ns : '';
        my $node = {
          id => $NEXT_ID++,
          token => $token,
          di => $token->{di}, index => $token->{index},
          nsmap => $nsmap,
          ns => $ns, prefix => $prefix, local_name => $ln,
          attr_list => $token->{attr_list},
          et => %s->{$token->{tag_name}} || %s->{'*'} || 0,
          aet => %s->{$token->{tag_name}} || %s->{'*'} || 0,
        };
        $DTDDefs->{el_ncnames}->{$prefix} ||= $token if defined $prefix;
        $DTDDefs->{el_ncnames}->{$ln} ||= $token if defined $ln;

        my $has_attr;
        for my $attr (@{$node->{attr_list}}) {
          my $ns;
          my ($p, $l) = split /:/, $attr->{name}, 2;

          if ($attr->{name} eq 'xmlns:xmlns') {
            ($p, $l) = (undef, $attr->{name});
          } elsif (defined $l and $p ne '' and $l ne '') { # prefixed
            if (defined $nsmap->{$p}) {
              $ns = $nsmap->{$p};
            } else {
              ## NOTE: Error should be detected at the DOM-layer.
              ($p, $l) = (undef, $attr->{name});
            }
          } else {
            if ($attr->{name} eq 'xmlns') {
              $ns = $nsmap->{xmlns};
            }
            ($p, $l) = (undef, $attr->{name});
          }
          
          if ($has_attr->{defined $ns ? $ns : ''}->{$l}) {
            $ns = undef;
            ($p, $l) = (undef, $attr->{name});
          } else {
            $has_attr->{defined $ns ? $ns : ''}->{$l} = 1;
          }

          $attr->{name_args} = [$ns, [$p, $l]];
          $DTDDefs->{el_ncnames}->{$p} ||= $attr if defined $p;
          $DTDDefs->{el_ncnames}->{$l} ||= $attr if defined $l;
          if (defined $attr->{declared_type}) {
            #
          } elsif ($DTDDefs->{AllDeclsProcessed}) {
            $attr->{declared_type} = 0; # no value
          } else {
            $attr->{declared_type} = 11; # unknown
          }
        }
      }, E2Tns '$nse', E2Tns '$nse', E2Tns '$nse', E2Tns '$nse';
    } elsif ($act->{type} eq 'insert a DOCTYPE') { # XML
      push @code, q{
        push @$OP, ['doctype', $token => 0];

        ## Public identifier normalization is intentionally not done
        ## (Chrome behavior).
        if (defined $token->{public_identifier} and
            $Web::HTML::_SyntaxDefs->{charrefs_pubids}->{$token->{public_identifier}}) {
          $DTDDefs->{has_charref_decls} = 1;
          $DTDDefs->{is_charref_declarations_entity} = 1;
        } else {
          $DTDDefs->{need_predefined_decls} = 1;
        }
      };
    } elsif ($act->{type} eq 'append-to-document') {
      if (defined $act->{item}) {
        if ($act->{item} eq 'DocumentType') {
          push @code, q{push @$OP, ['doctype', $token => 0]; $NEXT_ID++;}; # HTML
        } else {
          die "Unknown item |$act->{item}|";
        }
      } else {
        push @code, q{push @$OP, ['insert', $node => 0];};
      }
    } elsif ($act->{type} eq 'append-to-current') { # XML
      push @code, q{push @$OP, ['insert', $node => $OE->[-1]->{id}];};

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
    } elsif ($act->{type} eq 'insert a comment' or
             $act->{type} eq 'insert a processing instruction') {
      my $type = $act->{type} eq 'insert a comment' ? 'comment' : 'pi';
      if (defined $act->{position}) {
        if ($act->{position} eq 'document') {
          push @code, sprintf q{
            push @$OP, ['%s', $token => 0];
          }, $type;
        } elsif ($act->{position} eq 'doctype') { # XML
          push @code, sprintf q{
            push @$OP, ['%s', $token => 1];
            push @$Errors, {level => 'w',
                            type => 'xml:dtd:pi',
                            di => $token->{di}, index => $token->{index}};
          }, $type;
        } elsif ($act->{position} eq 'oe[0]') {
          push @code, sprintf q{
            push @$OP, ['%s', $token => $OE->[0]->{id}];
          }, $type;
        } else {
          die "Unknown insertion position |$act->{position}|";
        }
      } else {
        push @code, sprintf q{
          push @$OP, ['%s', $token => $OE->[-1]->{id}];
        }, $type;
      }
      if ($type eq 'pi') {
        push @code, sprintf q{
          $SC->check_pi_target
              (name => $token->{target},
               onerror => sub {
                 push @$Errors, {@_, di => $token->{di}, index => $token->{index}};
               });
        };
      }
    } elsif ($act->{type} eq 'insert-chars') {
      my $value_code;
      if (defined $act->{value}) {
        if (ref $act->{value}) {
          if ($act->{value}->[0] eq 'pending table character tokens list') {
            $value_code = q{[map { [$_->{value}, $_->{di}, $_->{index}] } @$TABLE_CHARS]}; # IndexedString
          } else {
            die "Unknown value |$act->{value}->[0]|";
          }
        } else {
          $value_code = sprintf q{[[q@%s@, $token->{di}, $token->{index}]]},
              $act->{value}; # IndexedString
        }
      } else {
        $value_code = sprintf q{[[%s, $token->{di}, $token->{index}]]},
            $args{chars} // q{$token->{value}}; # IndexedString
      }
      push @code, foster_code $act => 'text', $value_code;
    } elsif ($act->{type} eq 'insert a character' and
             defined $act->{value} and
             2 == keys %$act) {
      my $value_code = sprintf q{[[q@%s@, $token->{di}, $token->{index}]]},
          $act->{value}; # IndexedString
      push @code, foster_code $act => 'text', $value_code;
    } elsif ($act->{type} eq 'pop-template-ims') {
      push @code, q{pop @$TEMPLATE_IMS;};
    } elsif ($act->{type} eq 'push-template-ims') {
      push @code, sprintf q{
        push @$TEMPLATE_IMS, %s;
      }, im_const $act->{im};
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
            if @{$token->{attr_list} or []};
      }, $1;
    } elsif ($act->{type} eq 'fixup-svg-tag-name') {
      push @code, q{
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      };
      ## $token->{tn} don't have to be updated
    } elsif ($act->{type} eq 'doctype-switch') {
      push @code, q{
        if (not defined $token->{name} or not $token->{name} eq 'html') {
          push @$Errors, {level => 'm',
                          type => 'bad DOCTYPE name',
                          value => $token->{name},
                          di => $token->{di}, index => $token->{index}};
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        } elsif (defined $token->{public_identifier}) {
          if (defined $OPPublicIDToSystemID->{$token->{public_identifier}}) {
            if (defined $token->{system_identifier}) {
              if ($OPPublicIDToSystemID->{$token->{public_identifier}} eq $token->{system_identifier}) {
                push @$Errors, {type => 'obsolete permitted DOCTYPE',
                                level => 's',
                                di => $token->{di}, index => $token->{index}};
              } else {
                push @$Errors, {type => 'obsolete DOCTYPE', level => 'm',
                                di => $token->{di}, index => $token->{index}};
                unless ($IframeSrcdoc) {
                  my $sysid = $token->{system_identifier};
                  $sysid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
                  if ($QSystemIDs->{$sysid}) {
                    push @$OP, ['set-compat-mode', 'quirks'];
                    $QUIRKS = 1;
                  }
                }
              }
            } else {
              if ($OPPublicIDOnly->{$token->{public_identifier}}) {
                push @$Errors, {type => 'obsolete permitted DOCTYPE',
                                level => 's',
                                di => $token->{di}, index => $token->{index}};
              } else {
                push @$Errors, {type => 'obsolete DOCTYPE', level => 'm',
                                di => $token->{di}, index => $token->{index}};
              }
            }
          } else {
            push @$Errors, {type => 'obsolete DOCTYPE', level => 'm',
                            di => $token->{di}, index => $token->{index}};
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
            push @$Errors, {type => 'legacy DOCTYPE', level => 's',
                            di => $token->{di}, index => $token->{index}};
          } else {
            push @$Errors, {type => 'obsolete DOCTYPE', level => 'm',
                            di => $token->{di}, index => $token->{index}};
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
          push @$OP, ['change-the-encoding',
                      (join '', map { $_->[0] } @{$token->{attrs}->{charset}->{value}}), # IndexedString
                      $token->{attrs}->{charset}];
        } elsif (defined $token->{attrs}->{'http-equiv'} and
                 defined $token->{attrs}->{content}) {
          # IndexedString
          if ((join '', map { $_->[0] } @{$token->{attrs}->{'http-equiv'}->{value}})
                  =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
              (join '', map { $_->[0] } @{$token->{attrs}->{content}->{value}})
                  =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                        [\x09\x0A\x0C\x0D\x20]*=
                        [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                        ([^"'\x09\x0A\x0C\x0D\x20]
                         [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            push @$OP, ['change-the-encoding',
                        defined $1 ? $1 : defined $2 ? $2 : $3,
                        $token->{attrs}->{content}];
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
      my $index_code;
      if ($act->{name} eq 'in-table-text-else') {
        $index_code = q{di => $TABLE_CHARS->[0]->{di},
                        index => $TABLE_CHARS->[0]->{index}};
      } else {
        $index_code = sprintf q{di => $token->{di},
                                index => $token->{index}%s},
            defined $args{index_delta_code} ? ' + ' . $args{index_delta_code} : '';
      }
      push @code, sprintf q{push @$Errors, {type => '%s',
                                            level => 'm',
                                            %s%s%s};},
          $act->{error_type} // $act->{name},
          (defined $act->{error_text} ?
               sprintf q{text => %s,}, map {
                 if ($_->[0] eq 'token') {
                   my $s = $_->[1];
                   $s =~ tr/ /_/;
                   sprintf q{$token->{%s}}, $s;
                 } elsif ($_->[0] eq 'oe[-1]') {
                   my $s = $_->[1];
                   $s =~ tr/ /_/;
                   sprintf q{$OE->[-1]->{%s}}, $s;
                 } else {
                   die "Unknown type |$_->[0]|";
                 }
               } $act->{error_text} : ''),
          (defined $act->{error_value} ?
               sprintf q{value => %s,}, map {
                 if ($_->[0] eq 'token') {
                   my $s = $_->[1];
                   $s =~ tr/ /_/;
                   sprintf q{$token->{%s}}, $s;
                 } elsif ($_->[0] eq 'oe[-1]') {
                   my $s = $_->[1];
                   $s =~ tr/ /_/;
                   sprintf q{$OE->[-1]->{%s}}, $s;
                 } else {
                   die "Unknown type |$_->[0]|";
                 }
               } $act->{error_value} : ''),
          $index_code;
    } elsif ($act->{type} eq 'switch the tokenizer') {
      push @code, switch_state_code $act->{state};
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
              # IndexedString
              next AFE unless (join '', map { $_->[0] } @{$attr->{value}}) eq
                              (join '', map { $_->[0] } @{$node->{token}->{attrs}->{$_}->{value}});
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
            push @$Errors, {type => 'nestc', level => 'w',
                            text => $token->{tag_name},
                            di => $token->{di}, index => $token->{index}};
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

    } elsif ($act->{type} eq 'text-with-optional-ws-prefix') {
      die if $act->{pending_table_character_tokens};
      push @code, sprintf q{
        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          %s
          $token->{index} += length $1;
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
          $codes->{$key} = sprintf q{
            my $value = $1;
            while ($value =~ /(.)/gs) {
              %s
            }
            %s
          },
              (actions_to_code $act->{$char_key} || [], chars => '$1', index_delta_code => '$-[1]'),
              (actions_to_code $act->{$seq_key} || [], chars => '$value');
        }
      }

      my $code;
      if (defined $codes->{ws} and defined $codes->{null}) {
        if ($codes->{else} =~ /^\s*\Q$codes->{ws}\E\s*\$\QFRAMESET_OK = 0;\E\s*$/) {
          my $ws2 = $codes->{ws};
          $ws2 =~ s/\$1\b/\$token->{value}/g;
          $code = sprintf q{
            if (index ($token->{value}, "\x00") > -1) {
              pos ($token->{value}) = 0;
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  %s
                  $token->{index} += length $1;
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  %s
                  $token->{index} += length $1;
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  %s
                  $token->{index} += length $1;
                }
              }
            } else {
              %s
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          }, $codes->{else}, $codes->{ws}, $codes->{null}, $ws2;
        } else {
          $code = sprintf q{
            pos ($token->{value}) = 0;
            while (pos $token->{value} < length $token->{value}) {
              if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                %s
                $token->{index} += length $1;
              }
              if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                %s
                $token->{index} += length $1;
              }
              if ($token->{value} =~ /\G([\x00]+)/gc) {
                %s
                $token->{index} += length $1;
              }
            }
          }, $codes->{else}, $codes->{ws}, $codes->{null};
        }
      } elsif (defined $codes->{ws}) {
        $code = sprintf q{
          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              %s
              $token->{index} += length $1;
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              %s
              $token->{index} += length $1;
            }
          }
        }, $codes->{else}, $codes->{ws};
      } elsif (defined $codes->{null}) {
        $code = sprintf q{
          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              %s
              $token->{index} += length $1;
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              %s
              $token->{index} += length $1;
            }
          }
        }, $codes->{else}, $codes->{null};
      } else {
        if (defined $act->{char_actions}) {
          die if $LANG eq 'HTML';
          $code = sprintf q{
            while ($token->{value} =~ /(.)/gs) {
              %s
              $token->{index}++;
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
      push @code, q{@$TABLE_CHARS = ();};
    } elsif ($act->{type} eq 'append-to-pending-table-character-tokens-list') {
      push @code, q{push @$TABLE_CHARS, {%$token, value => $1};};

    } elsif ($act->{type} eq 'ignore the token') {
      push @code, q{return;};
    } elsif ($act->{type} eq 'abort these steps') {
      push @code, q{return;};
    } elsif ($act->{type} eq 'ignore-next-lf') {
      $ignore_newline = 1;

    } elsif ($act->{type} eq 'set-DOCTYPE-system-identifier') {
      push @code, q{
        $DTDDefs->{system_identifier} = $token->{system_identifier};
        $DTDDefs->{di} = $token->{di};
        $DTDDefs->{index} = $token->{index};
      };
    } elsif ($act->{type} eq 'set the stop processing flag') {
      push @code, q{$DTDDefs->{StopProcessing} = 1;};
    } elsif ($act->{type} eq 'set-end-tag-name') {
      push @code, q{my $tag_name = length $token->{tag_name} ? $token->{tag_name} : $OE->[-1]->{token}->{tag_name};};
    } elsif ($act->{type} eq 'the XML declaration is missing') {
      push @code, q{
        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => 0};
      };
    } elsif ($act->{type} eq 'process an XML declaration') {
      push @code, q{_process_xml_decl $token;};

    } elsif ($act->{type} eq 'process an ELEMENT token') {
      push @code, q{
        if (not defined $token->{name}) {
          #
        } elsif (not $DTDDefs->{elements}->{$token->{name}}->{has_element_decl}) {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:ext decl',
                          di => $token->{di}, index => $token->{index}}
              unless $token->{DTDMode} eq 'internal subset'; # not in parameter entity
          $SC->check_hidden_name
              (name => $token->{name},
               onerror => sub {
                 push @$Errors, {@_, di => $token->{di}, index => $token->{index}};
               });
          my $def = $DTDDefs->{elements}->{$token->{name}};
          for (qw(name di index cmgroup)) {
            $def->{$_} = $token->{$_};
          }
          if (defined $token->{content_keyword}) {
            if ({EMPTY => 1, ANY => 1}->{$token->{content_keyword}}) {
              $def->{content_keyword} = $token->{content_keyword};
            } else {
              push @$Errors, {level => 'm',
                              type => 'xml:dtd:unknown content keyword',
                              value => $token->{content_keyword},
                              di => $token->{di}, index => $token->{index}};
            }
          }
          ## XXX $self->{t}->{content} syntax check.
          $DTDDefs->{elements}->{$token->{name}}->{has_element_decl} = 1;
        } else {
          push @$Errors, {level => 'm',
                          type => 'duplicate element decl',
                          value => $token->{name},
                          di => $token->{di}, index => $token->{index}};
        }
      };
    } elsif ($act->{type} eq 'process an ATTLIST token') {
      push @code, q{
        if (defined $token->{name}) {
          $SC->check_hidden_name
              (name => $token->{name},
               onerror => sub {
                 push @$Errors, {@_, di => $token->{di}, index => $token->{index}};
               });
          if ($token->{StopProcessing}) {
            push @$Errors, {level => 'w',
                            type => 'xml:dtd:attlist ignored',
                            di => $token->{di}, index => $token->{index}};
          } else { # not $StopProcessing
            push @$Errors, {level => 'w',
                            type => 'xml:dtd:ext decl',
                            di => $token->{di}, index => $token->{index}}
                unless $token->{DTDMode} eq 'internal subset'; # not in parameter entity

            if (not defined $DTDDefs->{elements}->{$token->{name}}) {
              $DTDDefs->{elements}->{$token->{name}}->{name} = $token->{name};
              $DTDDefs->{elements}->{$token->{name}}->{di} = $token->{di};
              $DTDDefs->{elements}->{$token->{name}}->{index} = $token->{index};
            } elsif ($DTDDefs->{elements}->{$token->{name}}->{has_attlist}) {
              push @$Errors, {level => 'w',
                              type => 'duplicate attlist decl',
                              value => $token->{name},
                              di => $token->{di}, index => $token->{index}};
            }
            $DTDDefs->{elements}->{$token->{name}}->{has_attlist} = 1;

            unless (@{$token->{attr_list} or []}) {
              push @$Errors, {level => 'w',
                              type => 'empty attlist decl',
                              value => $token->{name},
                              di => $token->{di}, index => $token->{index}};
            }
          } # not $StopProcessing
          
          for my $at (@{$token->{attr_list} or []}) {
            my $type = defined $at->{declared_type} ? {
              CDATA => 1, ID => 2, IDREF => 3, IDREFS => 4, ENTITY => 5,
              ENTITIES => 6, NMTOKEN => 7, NMTOKENS => 8, NOTATION => 9,
            }->{$at->{declared_type}} : 10;
            if (defined $type) {
              $at->{declared_type} = $type;
            } else {
              push @$Errors, {level => 'm',
                              type => 'unknown declared type',
                              value => $at->{declared_type},
                              di => $at->{di}, index => $at->{index}};
              $at->{declared_type} = $type = 0;
            }
            
            my $default = defined $at->{default_type} ? {
              FIXED => 1, REQUIRED => 2, IMPLIED => 3,
            }->{$at->{default_type}} : 4;
            if (defined $default) {
              $at->{default_type} = $default;
              if (defined $at->{value}) {
                if ($default == 1 or $default == 4) {
                  #
                } elsif (length $at->{value}) {
                  push @$Errors, {level => 'm',
                                  type => 'default value not allowed',
                                  di => $at->{di}, index => $at->{index}};
                }
              } else {
                if ($default == 1 or $default == 4) {
                  push @$Errors, {level => 'm',
                                  type => 'default value not provided',
                                  di => $at->{di}, index => $at->{index}};
                }
              }
            } else {
              push @$Errors, {level => 'm',
                              type => 'unknown default type',
                              value => $at->{default_type},
                              di => $at->{di}, index => $at->{index}};
              $at->{default_type} = 0;
            }
            $at->{value} = ($at->{default_type} and ($at->{default_type} == 1 or $at->{default_type} == 4))
                ? defined $at->{value} ? $at->{value} : [['', $at->{di}, $at->{index}]] : undef;

            $at->{tokenize} = (2 <= $type and $type <= 10);

            if (defined $at->{value}) {
              _tokenize_attr_value $at if $at->{tokenize};
            }

            if (not $token->{StopProcessing}) {
              if (not defined $DTDDefs->{attrdef_by_name}->{$token->{name}}->{$at->{name}}) {
                $DTDDefs->{attrdef_by_name}->{$token->{name}}->{$at->{name}} = $at;
                push @{$DTDDefs->{attrdefs}->{$token->{name}} ||= []}, $at;
                $at->{external} = {} unless $token->{DTDMode} eq 'internal subset'; # not in parameter entity
              } else {
                push @$Errors, {level => 'w',
                                type => 'duplicate attrdef',
                                value => $at->{name},
                                di => $at->{di}, index => $at->{index}};
                if ($at->{declared_type} == 10) { # ENUMERATION
                  for (@{$at->{allowed_tokens} or []}) {
                    $SC->check_hidden_nmtoken
                        (name => $_,
                         onerror => sub {
                           push @$Errors, {@_,
                                           di => $at->{di}, index => $at->{index}};
                         });
                  }
                } elsif ($at->{declared_type} == 9) { # NOTATION
                  for (@{$at->{allowed_tokens} or []}) {
                    $SC->check_hidden_name
                        (name => $_,
                         onerror => sub {
                           push @$Errors, {@_,
                                           di => $at->{di}, index => $at->{index}};
                         });
                  }
                }
              }
            } # not $StopProcessing
          } # attr_list
        }
      };
    } elsif ($act->{type} eq 'process an ENTITY token') {
      push @code, q{
        if ($token->{StopProcessing}) {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:entity ignored',
                          di => $token->{di}, index => $token->{index}};
          $SC->check_hidden_name
              (name => $token->{name},
               onerror => sub {
                 push @$Errors, {@_, di => $token->{di}, index => $token->{index}};
               })
              if defined $token->{name};
        } elsif (not defined $token->{name}) {
          #
        } else { # not stop processing
          if ($token->{is_parameter_entity_flag}) {
            if (not $DTDDefs->{pe}->{'%'.$token->{name} . ';'}) {
              push @$Errors, {level => 'w',
                              type => 'xml:dtd:ext decl',
                              di => $token->{di}, index => $token->{index}}
                  unless $token->{DTDMode} eq 'internal subset'; # and not in param entity
              $SC->check_hidden_name
                  (name => $token->{name},
                   onerror => sub {
                     push @$Errors, {@_,
                                     di => $token->{di}, index => $token->{index}};
                   });
              $DTDDefs->{pe}->{'%'.$token->{name} . ';'} = $token;
            } else {
              push @$Errors, {level => 'w',
                              type => 'duplicate entity decl',
                              value => '%'.$token->{name}.';',
                              di => $token->{di}, index => $token->{index}};
            }
          } else { # general entity
            if ({
              amp => 1, apos => 1, quot => 1, lt => 1, gt => 1,
            }->{$token->{name}}) {
              if (not defined $token->{value} or # external entity
                  not join ('', map { $_->[0] } @{$token->{value}}) =~ { # IndexedString
                    amp => qr/\A&#(?:x0*26|0*38);\z/,
                    lt => qr/\A&#(?:x0*3[Cc]|0*60);\z/,
                    gt => qr/\A(?>&#(?:x0*3[Ee]|0*62);|>)\z/,
                    quot => qr/\A(?>&#(?:x0*22|0*34);|")\z/,
                    apos => qr/\A(?>&#(?:x0*27|0*39);|')\z/,
                  }->{$token->{name}}) {
                push @$Errors, {level => 'm',
                                type => 'bad predefined entity decl',
                                value => $token->{name},
                                di => $token->{di}, index => $token->{index}};
              }

              $DTDDefs->{ge}->{'&'.$token->{name}.';'} = {
                name => $token->{name},
                value => [[{
                  amp => '&',
                  lt => '<',
                  gt => '>',
                  quot => '"',
                  apos => "'",
                }->{$token->{name}}, -1, 0]],
                only_text => 1,
              };
            } elsif (not $DTDDefs->{ge}->{'&'.$token->{name}.';'}) {
              my $is_external = not $token->{DTDMode} eq 'internal subset'; # not in param entity
              push @$Errors, {level => 'w',
                              type => 'xml:dtd:ext decl',
                              di => $token->{di}, index => $token->{index}}
                  if $is_external;
              $SC->check_hidden_name
                  (name => $token->{name},
                   onerror => sub {
                     push @$Errors, {@_,
                                     di => $token->{di}, index => $token->{index}};
                   });

              $DTDDefs->{ge}->{'&'.$token->{name}.';'} = $token;
              if (defined $token->{value} and # IndexedString
                  not join ('', map { $_->[0] } @{$token->{value}}) =~ /[&<]/) {
                $token->{only_text} = 1;
              }
              $token->{external} = {} if $is_external;
            } else {
              push @$Errors, {level => 'w',
                              type => 'duplicate entity decl',
                              value => '&'.$token->{name}.';',
                              di => $token->{di}, index => $token->{index}};
            }
          }

          if (defined $token->{public_identifier}) {
            $SC->check_hidden_pubid
                (name => $token->{public_identifier},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
          }
          if (defined $token->{system_identifier}) {
            $SC->check_hidden_sysid
                (name => $token->{system_identifier},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
          }
          if (defined $token->{notation_name}) {
            $SC->check_hidden_name
                (name => $token->{notation_name},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
            if ($token->{is_parameter_entity_flag}) {
              push @$Errors, {level => 'm',
                              type => 'xml:dtd:param entity with ndata',
                              value => '%'.$token->{name}.';',
                              di => $token->{di}, index => $token->{index}};
              delete $token->{notation_name};
            }
          }
        } # not stop processing
      };
    } elsif ($act->{type} eq 'process a NOTATION token') {
      push @code, q{
        if (defined $token->{name}) {
          if (defined $DTDDefs->{notations}->{$token->{name}}) {
            push @$Errors, {level => 'm',
                            type => 'duplicate notation decl',
                            value => $token->{name},
                            di => $token->{di}, index => $token->{index}};
          } else {
            push @$Errors, {level => 'w',
                            type => 'xml:dtd:ext decl',
                            di => $token->{di}, index => $token->{index}}
                unless $token->{DTDMode} eq 'internal subset'; # not in param entity
            $SC->check_hidden_name
                (name => $token->{name},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
            # XXX $token->{base_url}
            $DTDDefs->{notations}->{$token->{name}} = $token;
          }
          if (defined $token->{public_identifier}) {
            $SC->check_hidden_pubid
                (name => $token->{public_identifier},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
          }
          if (defined $token->{system_identifier}) {
            $SC->check_hidden_sysid
                (name => $token->{system_identifier},
                 onerror => sub {
                   push @$Errors, {@_,
                                   di => $token->{di}, index => $token->{index}};
                 });
          }
        }
      };

    } elsif ($act->{type} eq 'process the external subset') { # XML
      push @code, q{
        push @$Callbacks, [$OnDTDEntityReference,
                           {entity => {system_identifier => $DTDDefs->{system_identifier}},
                            ref => {di => $DTDDefs->{di},
                                    index => $DTDDefs->{index}}}]
            unless $DTDDefs->{is_charref_declarations_entity};
      };
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
  if ($LANG eq 'HTML') {
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
    $_->{index}++ if $_->{value} =~ s/^\x0A//;
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  };
  $defs->{actions}->{'before ignored newline;ELSE'} = q{
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  };
  if (defined $defs->{ims}->{text}) {
    $defs->{actions}->{'before ignored newline and text;TEXT'} = sprintf q{
      $_->{index}++ if $_->{value} =~ s/^\x0A//;
      $IM = %s;
      goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
    }, im_const 'text';
    $defs->{actions}->{'before ignored newline and text;ELSE'} = sprintf q{
      $IM = %s;
      goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
    }, im_const 'text';
  }
  for my $im ('before ignored newline', 'before ignored newline and text') {
    next if not defined $defs->{ims}->{text} and $im =~ /and text/;
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
              sprintf q{sub %s () { %s } %s->{q@%s@} = %s;},
                  $const_name, $et_codes->{$ns}->{$ln},
                  E2Tns (ns_const $ns), $ln, $const_name;
          $GroupNameToElementTypeConst->{"$ns:$ln"} ||= $const_name;
          $ElementToElementGroupExpr->{$ns}->{$ln} = $const_name;
        } else {
          push @group_code,
              sprintf q{%s->{q@%s@} = %s;},
                  E2Tns (ns_const $ns), $ln, $et_codes->{$ns}->{$ln};
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
    } if $LANG eq 'HTML';

    for (
      $LANG eq 'HTML' ? (
        ['aaa', (foster_code {}, 'append', q{$last_node->{id}}, q{$common_ancestor})],
        ['aaa_foster', (foster_code {foster_parenting => 1}, 'append', q{$last_node->{id}}, q{$common_ancestor})],
      ) : (),
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
              push @$Errors, {type => 'AAA:in afe but not in open elements',
                              value => $token->{tag_name},
                              level => 'm',
                              di => $token->{di}, index => $token->{index}};
              splice @$AFE, $formatting_element_afe_i, 1, ();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
            if ($beyond_scope) {
              push @$Errors, {type => 'AAA:formatting element not in scope',
                              level => 'm', value => $token->{tag_name},
                              di => $token->{di}, index => $token->{index}};
              if ($args{remove_from_afe_and_oe}) {
                splice @$AFE, $formatting_element_afe_i, 1, ();
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            unless ($formatting_element eq $OE->[-1]) {
              push @$Errors, {type => 'AAA:formatting element not current',
                              level => 'm', value => $token->{tag_name},
                              di => $token->{di}, index => $token->{index}};
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
            $formatting_element_afe_i-- if $node_afe_i < $formatting_element_afe_i;
            $bookmark-- if $node_afe_i < $bookmark;
            splice @$AFE, $node_afe_i, 1, ();
            undef $node_afe_i;
          }
          if (not defined $node_afe_i) {
            $furthest_block_i-- if $node_i < $furthest_block_i;
            push @popped, splice @$OE, $node_i, 1, ();
            redo INNER_LOOP;
          }

          ## Create an HTML element
          $node = {id => $NEXT_ID++,
                   token => $node->{token},
                   di => $node->{token}->{di}, index => $node->{token}->{index},
                   ns => HTMLNS,
                   local_name => $node->{token}->{tag_name},
                   attr_list => $node->{token}->{attr_list},
                   et => %s->{$node->{token}->{tag_name}} || %s->{'*'}};
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
                               di => $formatting_element->{token}->{di},
                               index => $formatting_element->{token}->{index},
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

            if ($bookmark <= $formatting_element_afe_i) {
              splice @$AFE, $formatting_element_afe_i, 1, ();
              splice @$AFE, $bookmark, 0, $new_element;
            } else {
              splice @$AFE, $bookmark, 0, $new_element;
              splice @$AFE, $formatting_element_afe_i, 1, ();
              $bookmark--;
            }

            if ($formatting_element_i < $furthest_block_i) {
              splice @$OE, $furthest_block_i + 1, 0, ($new_element);
              #push @popped,
              splice @$OE, $formatting_element_i, 1, ();
              $furthest_block_i--;
            } else {
              #push @popped,
              splice @$OE, $formatting_element_i, 1, ();
              splice @$OE, $furthest_block_i + 1, 0, ($new_element);
            }

            redo OUTER_LOOP;
          } # OUTER_LOOP
        }
      },
          $_->[0],
          im_const 'in body',
          E2Tns 'HTMLNS', E2Tns 'HTMLNS',
          $_->[1];
      push @substep_code, $aaa_code;
    }

    for (
      $LANG eq 'HTML' ? (
        ['reconstruct_afe', (foster_code {}, 'insert', '$node')],
        ['reconstruct_afe_foster', (foster_code {foster_parenting => 1}, 'insert', '$node')],
      ) : (),
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
          E: {
            last E if $entry_i == 0;
            $entry_i--;
            $entry = $AFE->[$entry_i];
            ($entry_i++, last E) if not ref $entry;
            for (reverse @$OE) {
              ($entry_i++, last E) if $_ eq $entry;
            }
            redo E;
          } # E

          for my $entry_i ($entry_i..$#$AFE) {
            $entry = $AFE->[$entry_i];

            ## Insert an HTML element
            my $node = {id => $NEXT_ID++,
                        token => $entry->{token},
                        di => $entry->{token}->{di},
                        index => $entry->{token}->{index},
                        ns => HTMLNS,
                        local_name => $entry->{token}->{tag_name},
                        attr_list => $entry->{token}->{attr_list},
                        et => %s->{$entry->{token}->{tag_name}} || %s->{'*'}};
            $node->{aet} = $node->{et};
            %s
            push @$OE, $node;

            $AFE->[$entry_i] = $node;
          }
        }
      }, $_->[0], E2Tns 'HTMLNS', E2Tns 'HTMLNS', $_->[1];
      push @substep_code, $reconstruct_code;
    }

    for (@substep_code) {
      s{\bIM\s*\("([^"]+)"\)}{im_const $1}ge;
      s{\bET_IS\s*\(\s*([^()"',\s]+)\s*,\s*'([^']+)'\s*\)}{
        pattern_to_code $2, $1;
      }ge;
      s{\bET_CATEGORY_IS\s*\(\s*([^()"',\s]+)\s*,\s*'([^']+)'\s*\)}{
        my $var = $1;
        my $p = $Defs->{tree_patterns}->{$2}
            or die "No definition for |$2|";
        pattern_to_code $p, $var;
      }ge;
      push @def_code, $_;
    }
  }

  my $def_code = join "\n",
      ($LANG eq 'HTML' ? q{my $Element2Type = [];} : q{my $Element2Type = {};}),
      q{my $ProcessIM = [];},
      (join "\n", @group_code),
      (join "\n", @im_code),
      (join "\n", @def_code);

  my $code;
  $code = sprintf q{
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
      im_const 'in foreign content'
      if $LANG eq 'HTML';

  $code = sprintf q{
    sub _construct_tree ($$) {
      my $self = shift;

      for my $token (@$Tokens) {
        local $_ = $token;
        &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      }

      $self->dom_tree ($OP);
      @$OP = ();
      @$Tokens = ();
    } # _construct_tree
  } if $LANG eq 'XML';

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
          (%s, [$data->{prefix}, $data->{local_name}]);
      $el->manakai_set_source_location (['', $data->{di}, $data->{index}]);
      ## Note that $data->{ns} can be 0.
      for my $attr (@{$data->{attr_list} or []}) {
        $el->manakai_set_attribute_indexed_string_ns
            (@{$attr->{name_args}} => $attr->{value}); # IndexedString
      }
      if (%s) {
        $nodes->[$data->{id}] = $el->content;
        $el->content->manakai_set_source_location
            (['', $data->{di}, $data->{index}]);
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
      $nodes->[$op->[2]]->manakai_append_indexed_string ($op->[1]); # IndexedString
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
            $prev_sibling->manakai_append_indexed_string ($op->[1]);
          } else {
            $prev_sibling = $doc->create_text_node ('');
            $prev_sibling->manakai_append_indexed_string ($op->[1]);
            $parent->insert_before ($prev_sibling, $next_sibling);
          }
        }
      } else {
        $nodes->[$op->[3]]->manakai_append_text ($op->[1]);
      }

    } elsif ($op->[0] eq 'append') {
      $nodes->[$op->[2]]->append_child ($nodes->[$op->[1]]);
    } elsif ($op->[0] eq 'append-by-list') {
      my @node = $op->[1]->to_list;
      if (@node and $node[0]->node_type == $node[0]->TEXT_NODE) {
        my $node = shift @node;
        $nodes->[$op->[2]]->manakai_append_indexed_string
            ($node->manakai_get_indexed_string);
      }
      $nodes->[$op->[2]]->append_child ($_) for @node;
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
      my $comment = $doc->create_comment (join '', map { $_->[0] } @{$op->[1]->{data}}); # IndexedString
      $comment->manakai_set_source_location
          (['', $op->[1]->{di}, $op->[1]->{index}]);
      $nodes->[$op->[2]]->append_child ($comment);
    } elsif ($op->[0] eq 'pi') {
      my $pi = $doc->create_processing_instruction ($op->[1]->{target}, '');
      $pi->manakai_append_indexed_string ($op->[1]->{data});
      $pi->manakai_set_source_location
          (['', $op->[1]->{di}, $op->[1]->{index}]);
      if ($op->[2] == 1) { # DOCTYPE
        local $nodes->[$op->[2]]->owner_document->dom_config->{manakai_allow_doctype_children} = 1;
        $nodes->[$op->[2]]->append_child ($pi);
      } else {
        $nodes->[$op->[2]]->append_child ($pi);
      }
    } elsif ($op->[0] eq 'doctype') {
      my $data = $op->[1];
      my $dt = $doc->implementation->create_document_type
          (defined $data->{name} ? $data->{name} : '',
           defined $data->{public_identifier} ? $data->{public_identifier} : '',
           defined $data->{system_identifier} ? $data->{system_identifier} : '');
      $dt->manakai_set_source_location (['', $data->{di}, $data->{index}]);
      $nodes->[1] = $dt;
      $nodes->[$op->[2]]->append_child ($dt);

    } elsif ($op->[0] eq 'set-if-missing') {
      my $el = $nodes->[$op->[2]];
      for my $attr (@{$op->[1]}) {
        $el->manakai_set_attribute_indexed_string_ns
            (@{$attr->{name_args}} => $attr->{value}) # IndexedString
            unless $el->has_attribute_ns ($attr->{name_args}->[0], $attr->{name_args}->[1]->[1]);
      }

    } elsif ($op->[0] eq 'change-the-encoding') {
      unless ($Confident) {
        my $changed = $self->_change_the_encoding ($op->[1], $op->[2]);
        push @$Callbacks, [$self->onrestartwithencoding, $changed]
            if defined $changed;
      }
      if ($op->[2]->{has_ref}) {
        push @$Errors, {type => 'charref in charset', level => 'm',
                        di => $op->[2]->{di}, index => $op->[2]->{index}};
      }

    } elsif ($op->[0] eq 'script') {
      # XXX insertion point setup
      push @$Callbacks, [$self->onscript, $nodes->[$op->[1]]];
    } elsif ($op->[0] eq 'ignore-script') {
      #warn "XXX set already started flag of $nodes->[$op->[1]]";
    } elsif ($op->[0] eq 'appcache') {
      if (defined $op->[1]) {
        my $value = join '', map { $_->[0] } @{$op->[1]->{value}}; # IndexedString
        push @$Callbacks, [$self->onappcacheselection, length $value ? $value : undef];
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
    } elsif ($op->[0] eq 'xml-version') {
      $doc->xml_version ($op->[1]);
    } elsif ($op->[0] eq 'xml-encoding') {
      $doc->xml_encoding ($op->[1]);
    } elsif ($op->[0] eq 'xml-standalone') {
      $doc->xml_standalone ($op->[1]);

    } elsif ($op->[0] eq 'construct-doctype') {
      my $doctype = $nodes->[1];
      my $serialize_cmgroup; $serialize_cmgroup = sub {
        return '(' . (join {'|' => ' | ', ',' => ', '}->{$_[0]->{separators}->[0]->{type} || ''} || '', map {
          if ($_->{items}) {
            $serialize_cmgroup->($_);
          } else {
            $_->{name} . ($_->{repetition} || '');
          }
        } @{$_[0]->{items}}) . ')' . ($_[0]->{repetition} || '');
      };
      for my $data (values %%{$DTDDefs->{elements} or {}}) {
        my $node = $doc->create_element_type_definition ($data->{name});
        if (defined $data->{content_keyword}) {
          $node->content_model_text ($data->{content_keyword});
        } elsif (defined $data->{cmgroup}) {
          $node->content_model_text ($serialize_cmgroup->($data->{cmgroup}));
        }
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}])
            if defined $data->{index};
        $doctype->set_element_type_definition_node ($node);
      }
      for my $elname (keys %%{$DTDDefs->{attrdefs} or {}}) {
        my $et = $doctype->get_element_type_definition_node ($elname);
        for my $data (@{$DTDDefs->{attrdefs}->{$elname}}) {
          my $node = $doc->create_attribute_definition ($data->{name});
          $node->declared_type ($data->{declared_type} || 0);
          push @{$node->allowed_tokens}, @{$data->{allowed_tokens} or []};
          $node->default_type ($data->{default_type} || 0);
          $node->manakai_append_indexed_string ($data->{value})
              if defined $data->{value};
          $et->set_attribute_definition_node ($node);
          $node->manakai_set_source_location
              (['', $data->{di}, $data->{index}]);
        }
      }
      for my $data (values %%{$DTDDefs->{notations} or {}}) {
        my $node = $doc->create_notation ($data->{name});
        $node->public_id ($data->{public_identifier}); # or undef
        $node->system_id ($data->{system_identifier}); # or undef
        # XXX base URL
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}]);
        $doctype->set_notation_node ($node);
      }
      for my $data (values %%{$DTDDefs->{ge} or {}}) {

        next unless defined $data->{notation_name};
        my $node = $doc->create_general_entity ($data->{name});
        $node->public_id ($data->{public_identifier}); # or undef
        $node->system_id ($data->{system_identifier}); # or undef
        $node->notation_name ($data->{notation_name}); # or undef
        # XXX base URL
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}]);
        $doctype->set_general_entity_node ($node);
      }

    } else {
      die "Unknown operation |$op->[0]|";
    }
  }

  $doc->strict_error_checking ($strict);
} # dom_tree

  },
      ($LANG eq 'HTML' ? q{$NSToURL->[$data->{ns}]} : q{$data->{ns}}),
      (pattern_to_code 'HTML:template', '$data'),
      $grep_popped_code, $grep_popped_code, $grep_popped_code;
  return $code;
} # generate_dom_glue

sub generate_api ($) {
  my $self = $_[0];
  my @def_code;
  my @code;

  {
    my $defs = $self->_expanded_tokenizer_defs->{tokenizer};
    my @c;
    for my $el_name (sort { $a cmp $b } keys %{$defs->{initial_state_by_html_element}->{always}}) {
      my $state = $defs->{initial_state_by_html_element}->{always}->{$el_name};
      push @c, sprintf q{'%s' => %s, }, $el_name, state_const $state;
    }
    push @def_code, sprintf q{my $StateByElementName = {%s};}, join '', @c;
  }

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
      ($Vars->{$_}->{type} eq 'index' or $Vars->{$_}->{type} eq 'integer') and
      defined $Vars->{$_}->{default};
    } keys %$Vars;
    push @init_code, map {
      sprintf q{$%s = q{%s};}, $_, $Vars->{$_}->{default};
    } sort { $a cmp $b } grep {
      $Vars->{$_}->{type} eq 'enum' and
      defined $Vars->{$_}->{default};
    } keys %$Vars;
    my @list_var = sort { $a cmp $b } grep { $Vars->{$_}->{type} eq 'list' } keys %$Vars;
    push @init_code, q[$self->{saved_lists} = {] . (join ', ', map {
      sprintf q{%s => ($%s = [])}, $_, $_;
    } @list_var) . q[};];
    my @map_var = sort { $a cmp $b } grep { $Vars->{$_}->{type} eq 'map' } keys %$Vars;
    push @init_code, q[$self->{saved_maps} = {] . (join ', ', map {
      sprintf q{%s => ($%s = {})}, $_, $_;
    } @map_var) . q[};];
    $vars_codes->{INIT} = join "\n", @init_code;

    $vars_codes->{RESET} = join "\n", map {
      if (defined $Vars->{$_}->{default}) {
        sprintf q{$%s = defined $self->{%s} ? $self->{%s} : %s;},
            $_, $_, $_, $Vars->{$_}->{default};
      } elsif ($Vars->{$_}->{from_method}) {
        sprintf q{$%s = $self->%s;}, $_, '_' . lc $_;
      } else {
        sprintf q{$%s = $self->{%s};}, $_, $_;
      }
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
    push @restore_code, sprintf q{(%s) = @{$self->{saved_maps}}{qw(%s)};},
        (join ', ', map { sprintf q{$%s}, $_ } @map_var),
        (join ' ', @map_var);
    $vars_codes->{RESTORE} = join "\n", @restore_code;
  }

  my @sub_code;
  push @sub_code, sprintf q{
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
            VARS::SAVE;
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
                return 1;
              }
            }
            VARS::RESTORE;
          }

          redo unless pos $Input == length $Input; # XXX parser pause flag
        }
        $Offset += $len;
        $in_offset += $len;
        redo unless $EOF;
      }
      if ($EOF) {
        unless ($self->{is_sub_parser}) {
          for my $en (keys %{$DTDDefs->{entity_names_in_entity_values} || {}}) {
            my $vt = $DTDDefs->{entity_names_in_entity_values}->{$en};
            $SC->check_hidden_name (name => (substr $en, 1, -2+length $en), onerror => sub {
              $self->onerrors->($self, [{%{$DTDDefs->{entity_names_in_entity_values}->{$en}}, @_}]);
            });
            my $def = $DTDDefs->{ge}->{$en};
            if (defined $def->{notation_name}) {
              push @$Errors, {%{$DTDDefs->{entity_names_in_entity_values}->{$en}},
                              level => 'w',
                              type => 'xml:dtd:entity value:unparsed entref',
                              value => $en};
            }
          } # $en
          $SC->check_ncnames (names => $DTDDefs->{el_ncnames} || {},
                              onerror => sub { $self->onerrors->($self, [{@_}]) });
          for my $en (keys %{$DTDDefs->{entity_names} || {}}) {
            $SC->check_hidden_name (name => (substr $en, 1, -2+length $en), onerror => sub {
              $self->onerrors->($self, [{%{$DTDDefs->{entity_names}->{$en}}, @_}]);
            });
          }
        }
        $self->onerrors->($self, $Errors) if @$Errors;
        @$Errors = ();
        $self->onparsed->($self);
        $self->_cleanup_states;
      }
      return 1;
    } # _run
  };

  push @sub_code, sprintf q{
    sub _feed_chars ($$) {
      my ($self, $input) = @_;
      pos ($input->[0]) = 0;
      while ($input->[0] =~ /[\x{0001}-\x{0008}\x{000B}\x{000E}-\x{001F}\x{007F}-\x{009F}\x{D800}-\x{DFFF}\x{FDD0}-\x{FDEF}\x{FFFE}-\x{FFFF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gc) {
        my $index = $-[0];
        my $char = ord substr $input->[0], $index, 1;
        if ($char < 0x100) {
          push @$Errors, {type => 'control char', level => 'm',
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        } elsif ($char < 0xE000) {
          push @$Errors, {type => 'char:surrogate', level => 'm',
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        } else {
          push @$Errors, {type => 'nonchar', level => 'm',
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        }
      }
      push @{$self->{input_stream}}, $input;

      return $self->_run;
    } # _feed_chars
  } if $LANG eq 'HTML';

  push @sub_code, sprintf q{
    sub _feed_chars ($$) {
      my ($self, $input) = @_;
      pos ($input->[0]) = 0;
      while ($input->[0] =~ /[\x{0001}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001F}\x{D800}-\x{DFFF}\x{FFFE}\x{FFFF}\x{007F}-\x{009F}\x{FDD0}-\x{FDEF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gcx) {
        my $index = $-[0];
        my $char = ord substr $input->[0], $index, 1;
        my $level = (substr $input->[0], $index, 1) =~ /[\x{0001}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001F}\x{D800}-\x{DFFF}\x{FFFE}\x{FFFF}]/ ? 'm' : 'w';
        if ($char < 0x100) {
          push @$Errors, {type => 'control char', level => $level,
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        } elsif ($char < 0xE000) {
          push @$Errors, {type => 'char:surrogate', level => $level,
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        } else {
          push @$Errors, {type => 'nonchar', level => $level,
                          text => (sprintf 'U+%%04X', $char),
                          di => $DI, index => $index};
        }
      }
      push @{$self->{input_stream}}, $input;

      return $self->_run;
    } # _feed_chars
  } if $LANG eq 'XML';

  push @sub_code, sprintf q{
    sub _feed_eof ($) {
      my $self = $_[0];
      push @{$self->{input_stream}}, [undef];
      return $self->_run;
    } # _feed_eof
  };

  push @sub_code, sprintf q{
    sub parse_char_string ($$$) {
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      $self->{document} = my $doc = $_[2];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (%d);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];
      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      $Confident = 1; # irrelevant
      SWITCH_STATE ("data state");
      $IM = IM (HTML => "initial", XML => "before XML declaration");

      $self->{input_stream} = [];
      my $dids = $self->di_data_set;
      $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
      $dids->[$DI] ||= {} if $DI >= 0;
      $doc->manakai_set_source_location (['', $DI, 0]);

      local $self->{onextentref};
      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      return;
    } # parse_char_string
  }, $LANG eq 'HTML';

  push @sub_code, sprintf q{
    sub parse_char_string_with_context ($$$$) {
      my $self = $_[0];
      my $context = $_[2]; # an Element or undef

      ## HTML fragment parsing algorithm
      ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-html-fragments>.

      ## XML fragment parsing algorithm
      ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-xhtml-fragments>

      ## 1.
      $self->{document} = my $doc = $_[3]; # an empty Document
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      my $nodes = $self->{nodes} = [$doc];
      ## <HTML>
      $doc->manakai_is_html (1);

      ## HTML 2.
      if (defined $context) {
        $doc->manakai_compat_mode ($context->owner_document->manakai_compat_mode);
      } else {
        ## Not in spec
        $doc->manakai_compat_mode ('no quirks');
      }
      ## </HTML>

      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      SWITCH_STATE ("data state");

      ## 3.
      my $input = [$_[1]]; # string copy
      $self->{input_stream} = [];
      my $dids = $self->di_data_set;
      $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
      $dids->[$DI] ||= {} if $DI >= 0;

      ## HTML 4. / XML 3. (cnt.)
      my $root;
      if (defined $context) {
        $IM = IM (HTML => "initial", XML => "in element");

        ## HTML 4.1. / XML 2., 4., 6.
        my $node_ns = $context->namespace_uri || '';
        my $node_ln = $context->local_name;
        if ($node_ns eq 'http://www.w3.org/1999/xhtml') {
          ## <HTML>
          if ($Scripting and $node_ln eq 'noscript') {
            SWITCH_STATE ("RAWTEXT state");
          } else {
            $State = $StateByElementName->{$node_ln} || $State;
          }
          ## </HTML>
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      #di => $token->{di}, index => $token->{index},
                      ns => HTMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => %s->{$node_ln} || %s->{'*'},
                      aet => %s->{$node_ln} || %s->{'*'}};
        ## <HTML>
        } elsif ($node_ns eq 'http://www.w3.org/2000/svg') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      #di => $token->{di}, index => $token->{index},
                      ns => SVGNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => %s->{$node_ln} || %s->{'*'},
                      aet => %s->{$node_ln} || %s->{'*'}};
        } elsif ($node_ns eq 'http://www.w3.org/1998/Math/MathML') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      #di => $token->{di}, index => $token->{index},
                      ns => MATHMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => %s->{$node_ln} || %s->{'*'},
                      aet => %s->{$node_ln} || %s->{'*'}};
          if ($node_ln eq 'annotation-xml') {
            my $encoding = $context->get_attribute_ns (undef, 'encoding');
            if (defined $encoding) {
              $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
              if ($encoding eq 'text/html' or
                  $encoding eq 'application/xhtml+xml') {
                $CONTEXT->{et} |= M_ANN_M_ANN_ELS;
                $CONTEXT->{aet} |= M_ANN_M_ANN_ELS;
              }
            }
          }
        ## </HTML>
        } else {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      #di => $token->{di}, index => $token->{index},
                      ns => 0,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => 0,
                      aet => 0};
        }
        ## <XML>
        my $nsmap = {};
        {
          my $prefixes = {};
          my $p = $context;
          while ($p and $p->node_type == 1) { # ELEMENT_NODE
            $prefixes->{$_->local_name} = 1 for grep {
              ($_->namespace_uri || '') eq q<http://www.w3.org/2000/xmlns/>;
            } @{$p->attributes or []};
            my $prefix = $p->prefix;
            $prefixes->{$prefix} = 1 if defined $prefix;
            $p = $p->parent_node;
          }
          for ('', keys %$prefixes) {
            $nsmap->{$_} = $context->lookup_namespace_uri ($_);
          }
          $nsmap->{xml} = q<http://www.w3.org/XML/1998/namespace>;
          $nsmap->{xmlns} = q<http://www.w3.org/2000/xmlns/>;
        }
        $CONTEXT->{nsmap} = $nsmap;
        ## </XML>
        $nodes->[$CONTEXT->{id}] = $context;

        ## <HTML>
        ## HTML 4.2.
        $root = $doc->create_element ('html');
        ## </HTML>
        ## <XML>
        $root = $doc->create_element_ns
            ($context->namespace_uri, [$context->prefix, $context->local_name]);
        ## </XML>

        ## HTML 4.3.
        $doc->append_child ($root);

        ## <HTML>
        ## HTML 4.4.
        @$OE = ({id => $NEXT_ID++,
                 #token => undef,
                 #di => $token->{di}, index => $token->{index},
                 ns => HTMLNS,
                 local_name => 'html',
                 attr_list => {},
                 et => %s,
                 aet => $CONTEXT->{aet}});
        ## </HTML>
        ## <XML>
        @$OE = ({id => $NEXT_ID++,
                 #token => undef,
                 #di => $token->{di}, index => $token->{index},
                 ns => $CONTEXT->{ns},
                 local_name => $CONTEXT->{local_name},
                 nsmap => $CONTEXT->{nsmap},
                 attr_list => {},
                 et => $CONTEXT->{et},
                 aet => $CONTEXT->{aet}});
        ## </XML>

        ## HTML 4.5.
        if ($node_ns eq 'http://www.w3.org/1999/xhtml' and
            $node_ln eq 'template') {
          ## <HTML>
          push @$TEMPLATE_IMS, IM ("in template");
          ## </HTML>
          ## <XML>
          $root = $root->content;
          ## </XML>
        }
        $nodes->[$OE->[-1]->{id}] = $root;

        ## <HTML>
        ## HTML 4.6.
        &reset_im;

        ## HTML 4.7.
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
                               #di => $token->{di}, index => $token->{index},
                               ns => HTMLNS,
                               local_name => 'form',
                               attr_list => {}, # not relevant
                               et => %s->{form},
                               aet => %s->{form}};
            }
            last;
          }
          $anode = $anode->parent_node;
        }
        ## </HTML>
      } else { # $context
        $IM = IM (HTML => "initial", XML => "before XML declaration");
      } # $context

      ## HTML 5.
      $Confident = 1; # irrelevant

      ## HTML 6. / XML 3. (cnt.)
      local $self->{onextentref};
      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      ## XML 5. If not well-formed, throw SyntaxError - should be
      ## handled by callee using $self->onerror.

      ## XXX and well-formedness errors not detected by this parser

      ## 7.
      return defined $context ? $root->child_nodes : $doc->child_nodes;
    } # parse_char_string_with_context
  },
    E2Tns 'HTMLNS', E2Tns 'HTMLNS', E2Tns 'HTMLNS', E2Tns 'HTMLNS',
    E2Tns 'SVGNS', E2Tns 'SVGNS', E2Tns 'SVGNS', E2Tns 'SVGNS',
    E2Tns 'MATHMLNS', E2Tns 'MATHMLNS', E2Tns 'MATHMLNS', E2Tns 'MATHMLNS',
    E2Tns 'HTMLNS', E2Tns 'HTMLNS', E2Tns 'HTMLNS';
  $sub_code[-1] =~ s{<XML>.*?</XML>}{}gs unless $LANG eq 'XML';
  $sub_code[-1] =~ s{<HTML>.*?</HTML>}{}gs unless $LANG eq 'HTML';

  push @sub_code, sprintf q{
    sub parse_chars_start ($$) {
      my ($self, $doc) = @_;

      $self->{input_stream} = [];
      $self->{document} = $doc;
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (%d);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      VARS::LOCAL;
      VARS::INIT;
      VARS::RESET;
      $Confident = 1; # irrelevant
      SWITCH_STATE ("data state");
      $IM = IM (HTML => "initial", XML => "before XML declaration");

      my $dids = $self->di_data_set;
      $DI = @$dids || 1;
      $self->{di} = my $source_di = defined $self->{di} ? $self->{di} : $DI+1;
      $dids->[$source_di] ||= {} if $source_di >= 0; # the main data source of the input stream
      $dids->[$DI]->{map} = [[0, $source_di, 0]]; # the input stream
      $doc->manakai_set_source_location (['', $DI, 0]);
      ## Note that $DI != $source_di to support document.write()'s
      ## insertion.

      VARS::SAVE;
      return;
    } # parse_chars_start
  }, $LANG eq 'HTML';

  push @sub_code, sprintf q{
    sub parse_chars_feed ($$) {
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

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
      
      return;
    } # parse_chars_end

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

  };

  push @sub_code, sprintf q{
    sub parse_byte_string ($$$$) {
      my $self = $_[0];

      $self->{document} = my $doc = $_[3];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (%d);
      $doc->manakai_compat_mode ('no quirks');
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
        my $dids = $self->di_data_set;
        $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
        $dids->[$DI] ||= {} if $DI >= 0;
        $doc->manakai_set_source_location (['', $DI, 0]);

        SWITCH_STATE ("data state");
        $IM = IM (HTML => "initial", XML => "before XML declaration");

        local $self->{onextentref};
        $self->_feed_chars ($input) or redo PARSER;
        $self->_feed_eof or redo PARSER;
      } # PARSER

      return;
    } # parse_byte_string
  }, $LANG eq 'HTML';

  push @sub_code, sprintf q{
    sub _parse_bytes_init ($) {
      my $self = $_[0];

      my $doc = $self->{document};
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      delete $self->{parse_bytes_started};
      $self->{input_stream} = [];
      VARS::INIT;
      VARS::RESET;
      SWITCH_STATE ("data state");
      $IM = IM (HTML => "initial", XML => "before XML declaration");

      my $dids = $self->di_data_set;
      $DI = @$dids || 1;
      $self->{di} = my $source_di = defined $self->{di} ? $self->{di} : $DI+1;
      $dids->[$DI]->{map} = [[0, $source_di, 0]]; # the input stream
      $dids->[$source_di] ||= {} if $source_di >= 0; # the main data source of the input stream
      $doc->manakai_set_source_location (['', $DI, 0]);
      ## Note that $DI != $source_di to support document.write()'s
      ## insertion.
    } # _parse_bytes_init
  };

  push @sub_code, sprintf q{
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

      my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding

      $self->_feed_chars ($input) or return 0;

      return 1;
    } # _parse_bytes_start_parsing
  };

  push @sub_code, sprintf q{
    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{document} = my $doc = $_[2];
      $doc->manakai_is_html (%d);
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
  }, $LANG eq 'HTML';

  push @sub_code, sprintf q{
    ## The $args{start_parsing} flag should be set true if it has
    ## taken more than 500ms from the start of overall parsing
    ## process. XXX should this be a separate method?
    sub parse_bytes_feed ($$;%%) {
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
      
      return;
    } # parse_bytes_end
  };

  push @sub_code, q{

{
  package XXX::AttrEntityParser;
  push our @ISA, qw(Web::XML::Parser);

  sub parse ($$$) {
    my ($self, $main, $in) = @_;

    VARS::LOCAL;
    VARS::INIT;
    VARS::RESET;
    $Confident = 1; # irrelevant
    {
      package Web::XML::Parser;
      if ($in->{in_default_attr}) {
        SWITCH_STATE ("default attribute value in entity state");
      } else {
        SWITCH_STATE ("attribute value in entity state");
      }
      $IM = IM (HTML => "initial", XML => "before XML declaration");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [@{$in->{entity}->{value}}];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    require Web::HTML::SourceMap;
    $dids->[$DI] ||= {
      name => '&'.$in->{entity}->{name}.';',
      map => Web::HTML::SourceMap::indexed_string_to_mapping ($self->{input_stream}),
    } if $DI >= 0;

    $Attr = $main->{saved_states}->{Attr};
    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;

    $self->_run or die "Can't restart";
    $self->_feed_eof or die "Can't restart";
  } # parse

  sub _construct_tree ($) {
    #
  } # _construct_tree
}

{
  package XXX::ContentEntityParser;
  push our @ISA, qw(Web::XML::Parser);

  sub parse ($$$) {
    my ($self, $main, $in) = @_;

    VARS::LOCAL;
    VARS::INIT;
    VARS::RESET;
    $Confident = 1; # irrelevant
    {
      package Web::XML::Parser;
      SWITCH_STATE ("data state");
      $IM = IM ("in element");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [@{$in->{entity}->{value}}];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    require Web::HTML::SourceMap;
    $dids->[$DI] ||= {
      name => '&'.$in->{entity}->{name}.';',
      map => Web::HTML::SourceMap::indexed_string_to_mapping ($self->{input_stream}),
    } if $DI >= 0;

    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;

    my $root = $doc->create_element_ns (undef, 'dummy');
    @$OE = ({id => $NEXT_ID++,
             #token => undef,
             #di => $token->{di}, index => $token->{index},
             ns => undef,
             local_name => 'dummy',
             attr_list => {},
             nsmap => $main->{saved_lists}->{OE}->[-1]->{nsmap},
             et => 0,
             aet => 0});
    $self->{nodes}->[$CONTEXT = $OE->[-1]->{id}] = $root;

    $self->_run or die "Can't restart";
    $self->_feed_eof or die "Can't restart";
  } # parse

    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{main_parser} = $_[2];
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

  sub _parse_bytes_init ($$) {
    my $self = $_[0];
    my $main = $self->{main_parser};

    delete $self->{parse_bytes_started};

    VARS::INIT;
    VARS::RESET;
    {
      package Web::XML::Parser;
      SWITCH_STATE ("data state");
      $IM = IM ("before content text declaration");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    $dids->[$DI] ||= {} if $DI >= 0;

    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;

    my $root = $doc->create_element_ns (undef, 'dummy');
    @$OE = ({id => $NEXT_ID++,
             #token => undef,
             #di => $token->{di}, index => $token->{index},
             ns => undef,
             local_name => 'dummy',
             attr_list => {},
             nsmap => $main->{saved_lists}->{OE}->[-1]->{nsmap},
             et => 0,
             aet => 0});
    $self->{nodes}->[$CONTEXT = $OE->[-1]->{id}] = $root;
  } # _parse_bytes_init
}

{
  package XXX::DTDEntityParser;
  push our @ISA, qw(Web::XML::Parser);

  sub parse ($$$) {
    my ($self, $main, $in) = @_;

    VARS::LOCAL;
    VARS::INIT;
    VARS::RESET;
    $Confident = 1; # irrelevant
    {
      package Web::XML::Parser;
      SWITCH_STATE ("DTD state");
      $IM = IM ("in subset");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [@{$in->{entity}->{value}}];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    require Web::HTML::SourceMap;
    $dids->[$DI] ||= {
      name => '%'.$in->{entity}->{name}.';',
      map => Web::HTML::SourceMap::indexed_string_to_mapping ($self->{input_stream}),
    } if $DI >= 0;

    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    if ($main->{saved_states}->{DTDMode} eq 'internal subset' or
        $main->{saved_states}->{DTDMode} eq 'parameter entity in internal subset') {
      $DTDMode = 'parameter entity in internal subset';
    } else {
      $DTDMode = 'parameter entity';
    }

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE

    $self->_run or die "Can't restart";
    $self->_feed_eof or die "Can't restart";
  } # parse

    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{main_parser} = $_[2];
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

  sub _parse_bytes_init ($$) {
    my $self = $_[0];
    my $main = $self->{main_parser};

    delete $self->{parse_bytes_started};

    VARS::INIT;
    VARS::RESET;
    {
      package Web::XML::Parser;
      SWITCH_STATE ("DTD state");
      $IM = IM ("before DTD text declaration");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    $dids->[$DI] ||= {} if $DI >= 0;

    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    $DTDMode = 'parameter entity';

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE
  } # _parse_bytes_init
}

{
  package XXX::EntityValueEntityParser;
  push our @ISA, qw(Web::XML::Parser);

  sub parse ($$$) {
    my ($self, $main, $in) = @_;

    VARS::LOCAL;
    VARS::INIT;
    VARS::RESET;
    $Confident = 1; # irrelevant
    {
      package Web::XML::Parser;
      SWITCH_STATE ("ENTITY value in entity state");
      $IM = IM ("in subset");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [@{$in->{entity}->{value}}];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    require Web::HTML::SourceMap;
    $dids->[$DI] ||= {
      name => '%'.$in->{entity}->{name}.';',
      map => Web::HTML::SourceMap::indexed_string_to_mapping ($self->{input_stream}),
    } if $DI >= 0;

    $Token = $main->{saved_states}->{Token};
    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    if ($main->{saved_states}->{DTDMode} eq 'internal subset' or
        $main->{saved_states}->{DTDMode} eq 'parameter entity in internal subset') {
      $DTDMode = 'parameter entity in internal subset';
    } else {
      $DTDMode = 'parameter entity';
    }

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE

    $self->_run or die "Can't restart";
    $self->_feed_eof or die "Can't restart";
  } # parse

    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{main_parser} = $_[2];
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

  sub _parse_bytes_init ($$) {
    my $self = $_[0];
    my $main = $self->{main_parser};

    delete $self->{parse_bytes_started};

    VARS::INIT;
    VARS::RESET;
    {
      package Web::XML::Parser;
      SWITCH_STATE ("before ENTITY value in entity state");
      $IM = IM ("in subset");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    $self->{onerrors} = $main->onerrors;
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    $dids->[$DI] ||= {} if $DI >= 0;

    $Token = $main->{saved_states}->{Token};
    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    $DTDMode = 'parameter entity';

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE
  } # _parse_bytes_init
}

{
  package XXX::MDEntityParser;
  push our @ISA, qw(Web::XML::Parser);

  sub parse ($$$) {
    my ($self, $main, $in) = @_;

    $self->{InMDEntity} = 1;
    VARS::LOCAL;
    VARS::INIT;
    VARS::RESET;
    $Confident = 1; # irrelevant
    {
      package Web::XML::Parser;
      $State = $main->{saved_states}->{OriginalState}->[0];
      $IM = IM ("in subset");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    my $onerrors = $main->onerrors;
    $self->{onerrors} = sub {
      my ($self, $errors) = @_;
      $onerrors->($self, [grep { $_->{type} ne 'parser:EOF' } @$errors]);
    };
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [@{$in->{entity}->{value}}];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    require Web::HTML::SourceMap;
    $dids->[$DI] ||= {
      name => '%'.$in->{entity}->{name}.';',
      map => Web::HTML::SourceMap::indexed_string_to_mapping ($self->{input_stream}),
    } if $DI >= 0;

    $Token = $main->{saved_states}->{Token};
    $Attr = $main->{saved_states}->{Attr};
    $OpenCMGroups = $main->{saved_lists}->{OpenCMGroups};
    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    if ($main->{saved_states}->{DTDMode} eq 'internal subset' or
        $main->{saved_states}->{DTDMode} eq 'parameter entity in internal subset') {
      $DTDMode = 'parameter entity in internal subset';
    } else {
      $DTDMode = 'parameter entity';
    }

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE

    $self->_run or die "Can't restart";
    $self->_feed_eof or die "Can't restart";
  } # parse

    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{main_parser} = $_[2];
      $self->{can_restart} = 1;

      $self->{InMDEntity} = 1;

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

  sub _parse_bytes_init ($$) {
    my $self = $_[0];
    my $main = $self->{main_parser};

    delete $self->{parse_bytes_started};

    VARS::INIT;
    VARS::RESET;
    {
      package Web::XML::Parser;
      $State = $main->{saved_states}->{OriginalState}->[1];
      $IM = IM ("in subset");
    }

    my $doc = $self->{document} = $main->{document}->implementation->create_document;
    $doc->manakai_is_html ($main->{document}->manakai_is_html);
    $doc->manakai_compat_mode ($main->{document}->manakai_compat_mode);
    for (qw(onextentref entity_expansion_count
            max_entity_depth max_entity_expansions)) {
      $self->{$_} = $main->{$_};
    }
    $self->{onerror} = $main->onerror;
    my $onerrors = $main->onerrors;
    $self->{onerrors} = sub {
      my ($self, $errors) = @_;
      $onerrors->($self, [grep { $_->{type} ne 'parser:EOF' } @$errors]);
    };
    $self->{nodes} = [$doc];

    $self->{entity_depth} = ($main->{entity_depth} || 0) + 1;
    ${$self->{entity_expansion_count} = $main->{entity_expansion_count} ||= \(my $v = 0)}++;

    $self->{input_stream} = [];
    $self->{di_data_set} = my $dids = $main->di_data_set;
    $DI = $self->{di} = defined $self->{di} ? $self->{di} : @$dids;
    $dids->[$DI] ||= {} if $DI >= 0;

    $Token = $main->{saved_states}->{Token};
    $Attr = $main->{saved_states}->{Attr};
    $OpenCMGroups = $main->{saved_lists}->{OpenCMGroups};
    $self->{saved_maps}->{DTDDefs} = $DTDDefs = $main->{saved_maps}->{DTDDefs};
    $self->{is_sub_parser} = 1;
    $DTDMode = 'parameter entity';

    $NEXT_ID++;
    $self->{nodes}->[$CONTEXT = 1] = $main->{nodes}->[1]; # DOCTYPE
  } # _parse_bytes_init

}

    sub _parse_sub_done ($) {
      my $self = $_[0];
      VARS::LOCAL;
      VARS::RESET;
      VARS::RESTORE;

      $self->_run or die "Can't restart";
    } # _parse_sub_done
  } if $LANG eq 'XML';

  for (@sub_code) {
    s/\bSWITCH_STATE\s*\("([^"]+)"\)/switch_state_code $1/ge;
    s{\bIM\s*\(HTML\s*=>\s*"([^"]+)"\s*,\s*XML\s*=>\s*"([^"]+)"\)}{
      im_const ($LANG eq 'HTML' ? $1 : $2);
    }ge;
    s/\bIM\s*\("([^"]+)"\)/im_const $1/ge;
    s/\bVARS::(\w+);/$vars_codes->{$1}/ge;
  }
  push @code, @sub_code;

  return join ("\n", @def_code), join "\n", @code;
} # generate_api

sub generate ($) {
  my $self = shift;

  my $var_decls = join '', map { sprintf q{our $%s;}, $_ } sort { $a cmp $b } keys %$Vars;
  my ($tokenizer_defs_code, $tokenizer_code) = $self->generate_tokenizer;
  my ($tree_defs_code, $tree_code) = $self->generate_tree_constructor;
  my ($api_defs_code, $api_code) = $self->generate_api;

  return sprintf q{
    package %s;
    use strict;
    use warnings;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    use warnings FATAL => 'redefine';
    use warnings FATAL => 'uninitialized';
    use utf8;
    our $VERSION = '7.0';
    use Carp qw(croak);
    %s
    use Encode qw(decode); # XXX
    use Web::Encoding;
    use Web::HTML::ParserData;
    use Web::HTML::_SyntaxDefs;

    %s
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

sub onextentref ($;$) {
  if (@_ > 1) {
    $_[0]->{onextentref} = $_[1];
  }
  return $_[0]->{onextentref} || sub {
    my ($self, $data, $sub) = @_;
#XXX
    $self->onerrors->($self, [{level => 'i',
                               type => 'external entref',
                               value => (defined $data->{entity}->{name} ? ($data->{entity}->{is_parameter_entity_flag} ? '%' : '&').$data->{entity}->{name}.';' : undef),
                               di => $data->{ref}->{di},
                               index => $data->{ref}->{index}}]);
    if (not $self->{saved_states}->{DTDDefs}->{StopProcessing} and
        not $self->{saved_states}->{DTDDefs}->{XMLStandalone}) {
      $self->onerrors->($self, [{level => 'i',
                                 type => 'stop processing',
                                 di => $data->{ref}->{di},
                               index => $data->{ref}->{index}}])
          if defined $data->{entity}->{name} and
             $data->{entity}->{is_parameter_entity_flag};
      $self->{saved_maps}->{DTDDefs}->{StopProcessing} = 1;
    }

    $sub->parse_bytes_start (undef, $self);
    $sub->parse_bytes_feed ('<?xml encoding="utf-8"?>');
    $sub->parse_bytes_end;
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

my $OnAttrEntityReference = sub {
  my ($main, $data) = @_;
  if (($main->{entity_depth} || 0) > $main->max_entity_depth) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too deep',
                               text => $main->max_entity_depth,
                               value => '&'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } elsif ((${$main->{entity_expansion_count} || \0}) > $main->max_entity_expansions + 1) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too many refs',
                               text => $main->max_entity_expansions,
                               value => '&'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } else {
    my $sub = XXX::AttrEntityParser->new;
    local $data->{entity}->{open} = 1;
    $sub->parse ($main, $data);
  }
}; # $OnAttrEntityReference

my $OnContentEntityReference = sub {
  my ($main, $data) = @_;
  if (($main->{entity_depth} || 0) > $main->max_entity_depth) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too deep',
                               text => $main->max_entity_depth,
                               value => '&'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } elsif ((${$main->{entity_expansion_count} || \0}) > $main->max_entity_expansions + 1) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too many refs',
                               text => $main->max_entity_expansions,
                               value => '&'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } else {
    my $sub = XXX::ContentEntityParser->new;
    my $ops = $data->{ops};
    my $parent_id = $main->{saved_lists}->{OE}->[-1]->{id};
    my $main2 = $main;
    $sub->onparsed (sub {
      my $sub = $_[0];
      my $nodes = $sub->{nodes}->[$sub->{saved_lists}->{OE}->[0]->{id}]->child_nodes;
      push @$ops, ['append-by-list', $nodes => $parent_id];
      $data->{entity}->{open}--;
      $main2->{pause}--;
      $main2->_parse_sub_done;
      undef $main2;
    });
    $data->{entity}->{open}++;
    $main->{pause}++;
    $main->{pause}++;
    if (defined $data->{entity}->{value}) { # internal
      $sub->parse ($main, $data);
    } else { # external
      $main->onextentref->($main, $data, $sub);
    }
    $main->{pause}--;
  }
}; # $OnContentEntityReference

my $OnDTDEntityReference = sub {
  my ($main, $data) = @_;
  if (defined $data->{entity}->{name} and
      ($main->{entity_depth} || 0) > $main->max_entity_depth) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too deep',
                               text => $main->max_entity_depth,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } elsif (defined $data->{entity}->{name} and
           (${$main->{entity_expansion_count} || \0}) > $main->max_entity_expansions + 1) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too many refs',
                               text => $main->max_entity_expansions,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } else {
    my $sub = XXX::DTDEntityParser->new;
    my $main2 = $main;
    $sub->onparsed (sub {
      my $sub = $_[0];
      $data->{entity}->{open}--;
      $main2->{pause}--;
      $main2->_parse_sub_done;
      undef $main2;
    });
    $data->{entity}->{open}++;
    $main->{pause}++;
    $main->{pause}++;
    if (defined $data->{entity}->{value}) { # internal
      $sub->parse ($main, $data);
    } else { # external
      $main->onextentref->($main, $data, $sub);
    }
    $main->{pause}--;
  }
}; # $OnDTDEntityReference

my $OnEntityValueEntityReference = sub {
  my ($main, $data) = @_;
  if (($main->{entity_depth} || 0) > $main->max_entity_depth) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too deep',
                               text => $main->max_entity_depth,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } elsif ((${$main->{entity_expansion_count} || \0}) > $main->max_entity_expansions + 1) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too many refs',
                               text => $main->max_entity_expansions,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } else {
    my $sub = XXX::EntityValueEntityParser->new;
    my $main2 = $main;
    $sub->onparsed (sub {
      my $sub = $_[0];
      $data->{entity}->{open}--;
      $main2->{pause}--;
      $main2->_parse_sub_done;
      undef $main2;
    });
    $data->{entity}->{open}++;
    $main->{pause}++;
    $main->{pause}++;
    if (defined $data->{entity}->{value}) { # internal
      $sub->parse ($main, $data);
    } else { # external
      $main->onextentref->($main, $data, $sub);
    }
    $main->{pause}--;
  }
}; # $OnEntityValueEntityReference

my $OnMDEntityReference = sub {
  my ($main, $data) = @_;
  if (($main->{entity_depth} || 0) > $main->max_entity_depth) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too deep',
                               text => $main->max_entity_depth,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } elsif ((${$main->{entity_expansion_count} || \0}) > $main->max_entity_expansions + 1) {
    $main->onerrors->($main, [{level => 'm',
                               type => 'entity:too many refs',
                               text => $main->max_entity_expansions,
                               value => '%%'.$data->{entity}->{name}.';',
                               di => $data->{entity}->{di},
                               index => $data->{entity}->{index}}]);
  } else {
    my $sub = XXX::MDEntityParser->new;
    my $main2 = $main;
    $sub->onparsed (sub {
      my $sub = $_[0];
      package Web::XML::Parser;
      if ($sub->{saved_states}->{InLiteral}) {
        $main2->{saved_states}->{State} = %s ();
        $main2->onerrors->($main2, [{level => 'm',
                                     type => 'unclosed literal',
                                     di => $sub->{saved_states}->{Token}->{di},
                                     index => $sub->{saved_states}->{Token}->{index}}]);
      } else {
        $main2->{saved_states}->{State} = $sub->{saved_states}->{State};
      }
      if ($sub->{saved_states}->{InitialCMGroupDepth} < @{$sub->{saved_lists}->{OpenCMGroups}}) {
        $main2->onerrors->($main2, [{level => 'm',
                                     type => 'unclosed cmgroup',
                                     di => $sub->{saved_states}->{Token}->{di},
                                     index => $sub->{saved_states}->{Token}->{index}}]);
        $#{$sub->{saved_lists}->{OpenCMGroups}} = $sub->{saved_states}->{InitialCMGroupDepth}-1;
      }
      $main2->{saved_states}->{Attr} = $sub->{saved_states}->{Attr};

      my $sub2 = XXX::MDEntityParser->new;
      $sub2->onparsed (sub {
        $main2->{saved_states}->{State} = $_[0]->{saved_states}->{State};
        $main2->{saved_states}->{Attr} = $_[0]->{saved_states}->{Attr};
      });
      {
        local $main2->{saved_states}->{OriginalState} = [$main2->{saved_states}->{State}];
        $sub2->parse ($main2, {entity => {value => [[' ', -1, 0]], name => ''}});
      }

      $data->{entity}->{open}--;
      $main2->{pause}--;
      $main2->_parse_sub_done;
      undef $main2;
    });
    $data->{entity}->{open}++;
    $main->{pause}++;
    $main->{pause}++;
    $sub->{saved_states}->{InitialCMGroupDepth} = $main->{saved_lists}->{OpenCMGroups};
    if (defined $data->{entity}->{value}) { # internal
      $sub->parse ($main, $data);
    } else { # external
      $main->onextentref->($main, $data, $sub);
    }
    $main->{pause}--;
  }
}; # $OnMDEntityReference

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
    %s
    ## ------ Tokenizer defs ------
    %s
    ## ------ Tree constructor defs ------
    %s%s

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

Copyright 2007-2015 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

  },
      $self->package_name,
      $UseLibCode,
      ($LANG eq 'HTML' ? q{
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
      } : q{
        sub HTMLNS () { q<http://www.w3.org/1999/xhtml> }
      }),
      state_const 'bogus markup declaration state',
      $var_decls,
      $tokenizer_defs_code,
      $tree_defs_code, $api_defs_code,
      $self->generate_input_bytes_handler,
      $tokenizer_code,
      $tree_code,
      $self->generate_dom_glue,
      $api_code;
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
