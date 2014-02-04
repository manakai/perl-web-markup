package Web::HTML::InputStream;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '6.0';
use Web::Encoding ();
use Web::HTML::Defs;

## ------ Constructor ------

sub new ($) {
  my $class = shift;
  my $self = bless {
    level => {
      must => 'm',
      should => 's',
      obsconforming => 's',
      warn => 'w',
      info => 'i',
      uncertain => 'u',
    },
  }, $class;
  $self->{application_cache_selection} = sub {
    #
  };
  
  return $self;
} # new

## ------ Parser common operations ------

sub throw ($$) {
  $_[0]->_on_terminate;
  $_[1]->();
} # throw

sub _on_terminate ($) {
  $_[0]->_clear_refs;
} # _on_terminate

sub _clear_refs ($) {
  my $self = $_[0];
  ## Remove self references.
  delete $self->{set_nc};
  delete $self->{read_until};
  delete $self->{parse_error};
  delete $self->{document};
  delete $self->{chars};
  delete $self->{chars_pull_next};
  delete $self->{restart_parser};
  delete $self->{t};
  delete $self->{embedded_encoding_name};
  delete $self->{byte_buffer};
  delete $self->{inner_html_node};
  delete $self->{inner_html_tag_name};
  delete $self->{context_element};
  delete $self->{onerror};
  delete $self->{onextentref};
  delete $self->{onparsed};
  delete $self->{open_tables};
  delete $self->{open_elements};
  delete $self->{head_element};
  delete $self->{form_element};
  delete $self->{active_formatting_elements};
  delete $self->{insert};
  delete $self->{ge};
  delete $self->{pe};
} # _clear_refs

## ------ Error handling ------

our $DefaultErrorHandler = sub {
  my (%opt) = @_;
  my $line = $opt{token} ? $opt{token}->{line} : $opt{line};
  my $column = $opt{token} ? $opt{token}->{column} : $opt{column};
  my $text = defined $opt{text} ? qq{ - $opt{text}} : '';
  my $value = defined $opt{value} ? qq{ "$opt{value}"} : '';
  warn "Parse error ($opt{type}$text) at line $line column $column$value\n";
}; # $DefaultErrorHandler

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || $DefaultErrorHandler;
} # onerror

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

  ## Change the encoding
  ## <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>
  ## Step 5. Encoding from <meta charset>
  if ($args{embedded_encoding_name}) {
    ## $args{embedded_encoding_name}, if specified, must be a
    ## canonicalized encoding name, provided by the "change the
    ## encoding" algorithm.
    my $name = Web::Encoding::encoding_label_to_name $args{embedded_encoding_name};
    if ($name) {
      $self->{input_encoding} = $name;
      $self->{confident} = 1; # certain
      return;
    }
  }

  ## A known definite encoding, or Step 1. User-specified encoding
  for ($self->known_definite_encoding, $args{user_encoding_name}) {
    next unless defined $_;
    ## If specified, it must be an encoding label from the Encoding
    ## Standard.
    my $name = Web::Encoding::encoding_label_to_name $_;
    if ($name) {
      $self->{input_encoding} = $name;
      $self->{confident} = 1; # certain
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
      $self->{confident} = 1; # certain
      return;
    } elsif ($$head =~ /^\xFF\xFE/) {
      $self->{input_encoding} = 'utf-16le';
      $self->{confident} = 1; # certain
      return;
    } elsif ($$head =~ /^\xEF\xBB\xBF/) {
      $self->{input_encoding} = 'utf-8';
      $self->{confident} = 1; # certain
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
      $self->{confident} = 1; # certain
      return;
    }
  }

  ## Step 5. <meta charset>
  if (defined $head) {
    my $name = $self->_prescan_byte_stream ($$head);
    if ($name) {
      $self->{input_encoding} = $name;
      $self->{confident} = 0; # tentative
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
    #   $self->{confident} = 0; # tentative
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
      $self->{confident} = 0; # tentative
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
      $self->{confident} = 0; # tentative
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
      $self->{confident} = 0; # tentative
      return;
    }
  }

  ## Step 8. Default of default
  $self->{input_encoding} = 'windows-1252';
  $self->{confident} = 0; # tentative
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
        # 13.
        $charset = 'utf-8' if $charset eq 'utf-16le' or $charset eq 'utf-16be';

        # 14.-15.
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

sub _change_encoding {
  my ($self, $name, $token) = @_;

  ## "meta" start tag
  ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inhead>.

  ## "meta". Confidence is /tentative/
  return 0 if $self->{confident}; # tentative

  $name = Web::Encoding::encoding_label_to_name $name;
  unless ($name) {
    ## "meta". Supported encoding
    return 0;
  }

  ## "meta". ASCII-compatible or UTF-16
  ## All encodings in Encoding Standard are ASCII-compatible or UTF-16.

  ## Change the encoding
  ## <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>.

  ## Step 1. UTF-16
  if ($self->{input_encoding} eq 'utf-16le' or
      $self->{input_encoding} eq 'utf-16be') {
    $self->{confident} = 1; # certain
    return 0;
  }

  ## Step 2. UTF-16
  $name = 'utf-8' if $name eq 'utf-16le' or $name eq 'utf-16be';
  
  ## Step 3. Same
  if ($name eq $self->{input_encoding}) {
    $self->{confident} = 1; # certain
    return 0;
  }

  $self->{parse_error}->(type => 'charset label detected',
                         text => $self->{input_encoding},
                         value => $name,
                         level => $self->{level}->{warn},
                         token => $token);

  ## Step 4. Change the encoding on the fly
  ## Not implemented.

  ## Step 5. Navigate with replace.
  if ($self->{restart_parser}) {
    return $self->{restart_parser}->($name);
  }

  ## Step 5. Can't restart
  $self->{confident} = 1; # certain
  return 0;

  # XXX expose info for validator
} # _change_encoding

## ------ Feed characters from input stream to tokenizer ------

my $CommonStoppers = {
  ## Newlines
  "\x{000D}" => 1, "\x{000A}" => 1,
  "\x{0085}" => 1, "\x{2028}" => 1,

  ## Parse errors
  "\x{000B}" => 1, "\x{FFFE}" => 1, "\x{FFFF}" => 1,
  "\x{1FFFE}" => 1, "\x{1FFFF}" => 1, "\x{2FFFE}" => 1, "\x{2FFFF}" => 1,
  "\x{3FFFE}" => 1, "\x{3FFFF}" => 1, "\x{4FFFE}" => 1, "\x{4FFFF}" => 1,
  "\x{5FFFE}" => 1, "\x{5FFFF}" => 1, "\x{6FFFE}" => 1, "\x{6FFFF}" => 1,
  "\x{7FFFE}" => 1, "\x{7FFFF}" => 1, "\x{8FFFE}" => 1, "\x{8FFFF}" => 1,
  "\x{9FFFE}" => 1, "\x{9FFFF}" => 1, "\x{AFFFE}" => 1, "\x{AFFFF}" => 1,
  "\x{BFFFE}" => 1, "\x{BFFFF}" => 1, "\x{CFFFE}" => 1, "\x{CFFFF}" => 1,
  "\x{DFFFE}" => 1, "\x{DFFFF}" => 1, "\x{EFFFE}" => 1, "\x{EFFFF}" => 1,
  "\x{FFFFE}" => 1, "\x{FFFFF}" => 1,
  "\x{10FFFE}" => 1, "\x{10FFFF}" => 1,
  "\x{000C}" => 1,
};
$CommonStoppers->{chr $_} = 1
    for 0x0001..0x0008, 0x000E..0x001F, 0x007F..0x009F, 0xFDD0..0xFDEF,
        0xD800..0xDFFF;

## U+0000 error will be detected by tokenizer or tree constructor.
my $ParseErrorControlCodePosition = {
  html => {0x000B => 'must', 0x0085 => 'must'},
  1 => {0x000B => 'must', 0x000C => 'must', 0x0085 => 'warn'},
  1.1 => {0x000B => 'must', 0x000C => 'must'},
};
$ParseErrorControlCodePosition->{html}->{$_} = 'must',
$ParseErrorControlCodePosition->{1}->{$_} = 'must',
$ParseErrorControlCodePosition->{1.1}->{$_} = 'must'
    for 0x0001..0x0008, 0x000E..0x001F;
$ParseErrorControlCodePosition->{html}->{$_} = 'must',
$ParseErrorControlCodePosition->{1}->{$_} = 'warn',
$ParseErrorControlCodePosition->{1.1}->{$_} = 'must'
    for 0x007F..0x0084, 0x0086..0x009F;

my $ParseErrorNoncharCodePosition = {};
$ParseErrorNoncharCodePosition->{html}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1}->{$_} = 'warn',
$ParseErrorNoncharCodePosition->{1.1}->{$_} = 'warn'
    for 0xFDD0..0xFDEF;
$ParseErrorNoncharCodePosition->{html}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1.1}->{$_} = 'must'
    for 0xFFFE, 0xFFFF;
$ParseErrorNoncharCodePosition->{html}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1.1}->{$_} = 'must'
    for 0xD800..0xDFFF;
$ParseErrorNoncharCodePosition->{html}->{$_} = 'must',
$ParseErrorNoncharCodePosition->{1}->{$_} = 'warn',
$ParseErrorNoncharCodePosition->{1.1}->{$_} = 'warn'
    for 0x1FFFE, 0x1FFFF, 0x2FFFE, 0x2FFFF, 0x3FFFE, 0x3FFFF, 0x4FFFE,
        0x4FFFF, 0x5FFFE, 0x5FFFF, 0x6FFFE, 0x6FFFF, 0x7FFFE, 0x7FFFF,
        0x8FFFE, 0x8FFFF, 0x9FFFE, 0x9FFFF, 0xAFFFE, 0xAFFFF, 0xBFFFE,
        0xBFFFF, 0xCFFFE, 0xCFFFF, 0xDFFFE, 0xDFFFF, 0xEFFFE, 0xEFFFF,
        0xFFFFE, 0xFFFFF, 0x10FFFE, 0x10FFFF;

sub _set_nc ($) {
  my $self = $_[0];
  {
    if ($self->{chars_pos} < @{$self->{chars}}) {
      $self->{line_prev} = $self->{line};
      $self->{column_prev} = $self->{column};
      my $lang = $self->{is_xml} || 'html';
      my $c = ord $self->{chars}->[$self->{chars_pos}++];
      if ($c == 0x000A or
          ($c == 0x0085 and $lang eq 1.1)) {
        if ($self->{chars_was_cr}) {
          delete $self->{chars_was_cr};
          redo;
        } else {
          delete $self->{chars_was_cr};
          $self->{line}++;
          $self->{column} = 0;
          $c = 0x000A;
        }
      } elsif ($c == 0x000D) {
        $self->{chars_was_cr} = 1;
        $self->{line}++;
        $self->{column} = 0;
        $c = 0x000A;
      } elsif ($c == 0x2028 and $lang eq 1.1) {
        delete $self->{chars_was_cr};
        $self->{line}++;
        $self->{column} = 0;
        $c = 0x000A;
      } else {
        if (my $level = $ParseErrorControlCodePosition->{$lang}->{$c}) {
          $self->{parse_error}
              ->(type => 'control char', # XXXtype
                 value => (sprintf 'U+%04X', $c),
                 level => $self->{level}->{$level},
                 line => $self->{line},
                 column => $self->{column} + 1);
        } elsif ($level = $ParseErrorNoncharCodePosition->{$lang}->{$c}) {
          $self->{parse_error}
              ->(type => 'nonchar', # XXXtype
                 value => (sprintf 'U+%04X', $c),
                 level => $self->{level}->{$level},
                 line => $self->{line},
                 column => $self->{column} + 1);
        }
        
        delete $self->{chars_was_cr};
        $self->{column}++;
      }
      $self->{nc} = $c;
    } else {
      if ($self->{chars_pull_next}->()) {
        $self->{nc} = ABORT_CHAR;
      } else {
        delete $self->{chars_was_cr};
        if ($self->{nc} != EOF_CHAR) {
          $self->{line_prev} = $self->{line};
          $self->{column_prev} = $self->{column};
        }
        $self->{nc} = EOF_CHAR;
      }
    }
  } # block
} # _set_nc

sub _read_chars ($$) {
  my ($self, $stoppers) = @_;
  
  my $start = $self->{chars_pos};
  {
    my $char = $self->{chars}->[$self->{chars_pos}];
    last if not defined $char;
    if ($stoppers->{$char} or $CommonStoppers->{$char}) {
      last;
    } else {
      $self->{chars_pos}++;
    }
    redo;
  }
  return '' if $start == $self->{chars_pos};

  delete $self->{chars_was_cr};
  $self->{column} += $self->{chars_pos} - $start;
  return join '', @{$self->{chars}}[$start..($self->{chars_pos}-1)];
} # _read_chars

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
