
    package Web::HTML::_Tokenizer;
    use strict;
    use warnings;
    use utf8;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    our $VERSION = '7.0';
    use Web::HTML::Defs;
    use Web::HTML::ParserData;
    use Web::HTML::SourceMap;

our $Emit;
my $Input;
our $State;
our $Token;
our $Attr;
our $Temp;
our $LastStartTagName;
my $StateActions = {};
our $EOF;
our $Offset;

sub new {
  return bless {}, $_[0];
}

sub locale_tag {
  if (@_ > 1) {
    $_[0]->{locale_tag} = $_[1];
  }
  return $_[0]->{locale_tag};
}

our $DefaultErrorHandler = sub {
  my (%opt) = @_;
  my $index = $opt{token} ? $opt{token}->{index} : $opt{index};
  $index = -1 if not defined $index;
  my $text = defined $opt{text} ? qq{ - $opt{text}} : '';
  my $value = defined $opt{value} ? qq{ "$opt{value}"} : '';
  warn "Parse error ($opt{type}$text) at index $index$value\n";
}; # $DefaultErrorHandler

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || $DefaultErrorHandler;
} # onerror

sub _initialize_tokenizer {
    my $self = $_[0];
    $self->{application_cache_selection} = sub { };
}
sub _terminate_tokenizer { }
sub _clear_refs { }
sub _token_sps ($) {
  my $token = $_[0];
  return $token->{sps} if defined $token->{sps};
  return [] if not defined $token->{column};
  return [[0,
           length $token->{value},
           $token->{line},
           $token->{column} + ($token->{char_delta} || 0)]];
} # _token_sps

sub _append_token_data_and_sps ($$$) {
  my ($self, $token => $node) = @_;
  my $pos_list = $node->get_user_data ('manakai_sps');
  $pos_list = [] if not defined $pos_list or not ref $pos_list eq 'ARRAY';
  my $delta = length $node->text_content;
  push @$pos_list, @{sps_with_offset _token_sps $token, $delta};
  $node->set_user_data (manakai_sps => $pos_list);
  $node->manakai_append_text ($token->{value});
} # _append_token_data_with_sps

sub _append_text_by_token ($$$) {
  my ($self, $token => $parent) = @_;
  my $text = $parent->last_child;
  if (defined $text and $text->node_type == 3) { # TEXT_NODE
    $self->_append_token_data_and_sps ($token => $text);
  } else {
    $text = $parent->owner_document->create_text_node ($token->{value});
    $text->set_user_data (manakai_sps => _token_sps $token);
    $parent->append_child ($text);
  }
} # _append_text_by_token

my $InvalidCharRefs = {};

for (0x0000, 0xD800..0xDFFF) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [0xFFFD, 'must'];
}
for (0x0001..0x0008, 0x000B, 0x000E..0x001F) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'must'];
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'warn'];
}
$InvalidCharRefs->{1.0}->{0x000C} = [0x000C, 'must'];
$InvalidCharRefs->{1.1}->{0x000C} = [0x000C, 'warn'];
$InvalidCharRefs->{0}->{0x007F} = [0x007F, 'must'];
for (0x007F..0x009F) {
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'warn'];
}
delete $InvalidCharRefs->{1.1}->{0x0085};
for (keys %$Web::HTML::ParserData::NoncharacterCodePoints) {
  $InvalidCharRefs->{0}->{$_} = [$_, 'must'];
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'warn'];
}
for (0xFFFE, 0xFFFF) {
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'must'];
}
for (keys %$Web::HTML::ParserData::CharRefReplacements) {
  $InvalidCharRefs->{0}->{$_}
      = [$Web::HTML::ParserData::CharRefReplacements->{$_}, 'must'];
}

  $StateActions->{q<CDATA section state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Temp = '';
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<CDATA section state after 000D>;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$State = q<CDATA section state -- ]>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<CDATA section state -- ]>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<CDATA section state after 000D>;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp .= $1;
$State = q<CDATA section state -- ]]>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<CDATA section state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<CDATA section state -- ]]>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<CDATA section state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;
} elsif ($Input =~ /\G([\]]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<CDATA section state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<CDATA section state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<CDATA section state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = '';
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<CDATA section state after 000D>;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$State = q<CDATA section state -- ]>;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<CDATA section state>;
$Temp = '';
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE name state>} = sub {
if ($Input =~ /\G([^\	\\ \
\\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<after DOCTYPE name state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<name>} .= q@�@;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE public identifier (double-quoted) state>} = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = q<DOCTYPE public identifier (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after DOCTYPE public identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-public-identifier-double-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE public identifier (double-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<DOCTYPE public identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = q<DOCTYPE public identifier (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after DOCTYPE public identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<DOCTYPE public identifier (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-public-identifier-double-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<DOCTYPE public identifier (double-quoted) state>;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE public identifier (single-quoted) state>} = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = q<DOCTYPE public identifier (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after DOCTYPE public identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-public-identifier-single-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE public identifier (single-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<DOCTYPE public identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = q<DOCTYPE public identifier (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after DOCTYPE public identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<DOCTYPE public identifier (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-public-identifier-single-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<DOCTYPE public identifier (single-quoted) state>;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE state>} = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before DOCTYPE name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = q@�@;
$State = q<DOCTYPE name state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-doctype-name-003e', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = chr ((ord $1) + 32);
$State = q<DOCTYPE name state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = $1;
$State = q<DOCTYPE name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE system identifier (double-quoted) state>} = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = q<DOCTYPE system identifier (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after DOCTYPE system identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-system-identifier-double-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE system identifier (double-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<DOCTYPE system identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = q<DOCTYPE system identifier (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after DOCTYPE system identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<DOCTYPE system identifier (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-system-identifier-double-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<DOCTYPE system identifier (double-quoted) state>;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE system identifier (single-quoted) state>} = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = q<DOCTYPE system identifier (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after DOCTYPE system identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-system-identifier-single-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<DOCTYPE system identifier (single-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<DOCTYPE system identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = q<DOCTYPE system identifier (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after DOCTYPE system identifier state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<DOCTYPE system identifier (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'doctype-system-identifier-single-quoted-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<DOCTYPE system identifier (single-quoted) state>;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<PLAINTEXT state>} = sub {
if ($Input =~ /\G([^\\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<PLAINTEXT state after 000D>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<PLAINTEXT state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<PLAINTEXT state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<PLAINTEXT state after 000D>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<PLAINTEXT state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<PLAINTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<PLAINTEXT state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RAWTEXT end tag name state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RAWTEXT state after 000D>;
} elsif ($Input =~ /\G([\/])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<self-closing start tag state>;
          last if 1;
        }
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RAWTEXT less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<data state>;
          $Emit-> ($Token);
          last if 1;
        }
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RAWTEXT end tag open state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RAWTEXT state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<RAWTEXT less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = q<RAWTEXT end tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = q<RAWTEXT end tag name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RAWTEXT less-than sign state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RAWTEXT state after 000D>;
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = q<RAWTEXT end tag open state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<RAWTEXT less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RAWTEXT state>} = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RAWTEXT state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<RAWTEXT less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RAWTEXT state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<RAWTEXT state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RAWTEXT state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<RAWTEXT less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RAWTEXT state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RAWTEXT state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA end tag name state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\/])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<self-closing start tag state>;
          last if 1;
        }
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<data state>;
          $Emit-> ($Token);
          last if 1;
        }
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA end tag open state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = q<RCDATA end tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = q<RCDATA end tag name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA less-than sign state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = q<RCDATA end tag open state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state>} = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference before hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference decimal number state>} = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference name state>} = sub {
if ($Input =~ /\G([\])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([\=])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference number state>} = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference decimal number state>;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state - character reference state after 000D>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\
])/gcs) {
$State = q<RCDATA state - character reference state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<RCDATA state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<RCDATA state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([P])/gcs) {
$Temp = $1;
$State = q<after DOCTYPE name state -- P>;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$State = q<after DOCTYPE name state -- S>;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$State = q<after DOCTYPE name state -- P>;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$State = q<after DOCTYPE name state -- S>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- P>} = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PU>;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PU>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- PU>} = sub {
if ($Input =~ /\G([B])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUB>;
} elsif ($Input =~ /\G([b])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUB>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- PUB>} = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUBL>;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUBL>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- PUBL>} = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUBLI>;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- PUBLI>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- PUBLI>} = sub {
if ($Input =~ /\G([C])/gcs) {
$State = q<after DOCTYPE public keyword state>;
} elsif ($Input =~ /\G([c])/gcs) {
$State = q<after DOCTYPE public keyword state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- S>} = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SY>;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SY>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- SY>} = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYS>;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYS>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- SYS>} = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYST>;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYST>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- SYST>} = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYSTE>;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = q<after DOCTYPE name state -- SYSTE>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE name state -- SYSTE>} = sub {
if ($Input =~ /\G([M])/gcs) {
$State = q<after DOCTYPE system keyword state>;
} elsif ($Input =~ /\G([m])/gcs) {
$State = q<after DOCTYPE system keyword state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-name-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE public identifier state>} = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<between DOCTYPE public and system identifiers state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-identifier-0022', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-identifier-0027', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (single-quoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-identifier-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE public keyword state>} = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before DOCTYPE public identifier state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-keyword-0022', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} = '';
$State = q<DOCTYPE public identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-keyword-0027', level => 'm', index => $Offset + pos $Input}});
$Token->{q<public_identifier>} = '';
$State = q<DOCTYPE public identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-keyword-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-public-keyword-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE system identifier state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-system-identifier-else', level => 'm', index => $Offset + pos $Input}});
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after DOCTYPE system keyword state>} = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before DOCTYPE system identifier state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-system-keyword-0022', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-system-keyword-0027', level => 'm', index => $Offset + pos $Input}});
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-system-keyword-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-doctype-system-keyword-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after attribute name state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$State = q<before attribute value state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-name-0022', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-name-0027', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-name-003c', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<after attribute value (quoted) state>} = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0022', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0027', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003c', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003d', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'after-attribute-value-quoted-else', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute name state>} = sub {
if ($Input =~ /\G([^\	\\ \
\\/\=\>ABCDEFGHJKNQRVWZILMOPSTUXY\ \"\'\<]+)/gcs) {
$Attr->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-name-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-name-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-name-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<name>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state>} = sub {
if ($Input =~ /\G([^\\"\&\ ]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference before hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference decimal number state>} = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference name state>} = sub {
if ($Input =~ /\G([\])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
} elsif ($Input =~ /\G([\=])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference number state>} = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference decimal number state>;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state - character reference state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<attribute value (double-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (double-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<attribute value (double-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (double-quoted) state after 000D>;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (double-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<attribute value (double-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state>} = sub {
if ($Input =~ /\G([^\\&\'\ ]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference before hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference decimal number state>} = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference name state>} = sub {
if ($Input =~ /\G([\])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
} elsif ($Input =~ /\G([\=])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference number state>} = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference decimal number state>;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state - character reference state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<data>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<attribute value (single-quoted) state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (single-quoted) state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<attribute value (single-quoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = q<attribute value (single-quoted) state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (single-quoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<after attribute value (quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<attribute value (single-quoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state>} = sub {
if ($Input =~ /\G([^\	\\ \
\\&\>\ \"\'\<\=\`]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference before hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference decimal number state>} = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference name state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\&])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference number state>} = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference decimal number state>;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state - character reference state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<data>} .= $Temp;
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference name state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<attribute value (unquoted) state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<data>} .= $Temp;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<data>} .= $Temp;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<attribute value (unquoted) state after 000D>} = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\])/gcs) {
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0022', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0027', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {
$State = q<attribute value (unquoted) state>;
$Emit-> ({type => 'error', error => {type => 'attribute-value-unquoted-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<before DOCTYPE name state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = chr ((ord $1) + 32);
$State = q<DOCTYPE name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = q@�@;
$State = q<DOCTYPE name state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-doctype-name-003e', level => 'm', index => $Offset + pos $Input}});
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<name>} = $1;
$State = q<DOCTYPE name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token = {type => DOCTYPE_TOKEN, index => $Offset + pos $Input};
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<before DOCTYPE public identifier state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<public_identifier>} = '';
$State = q<DOCTYPE public identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<public_identifier>} = '';
$State = q<DOCTYPE public identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-doctype-public-identifier-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-doctype-public-identifier-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<before DOCTYPE system identifier state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-doctype-system-identifier-003e', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-doctype-system-identifier-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<before attribute name state>} = sub {
if ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $3;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $3;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$Attr->{q<value>} .= $3;
$State = q<attribute value (unquoted) state>;
$Attr->{q<value>} .= $4;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (single-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<before attribute value state>;
$State = q<attribute value (double-quoted) state>;
$Attr->{q<value>} .= $3;
$State = q<after attribute value (quoted) state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<after attribute name state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
$Attr->{q<name>} .= $2;
$Token->{attributes}->{$Attr->{name}} = $Attr;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\/\>/gcs) {
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\>/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0022', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0027', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003c', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003d', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<before attribute value state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = q<attribute value (double-quoted) state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = q<attribute value (unquoted) state - character reference state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = q<attribute value (single-quoted) state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= q@�@;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-value-003c', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-value-003d', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-value-003e', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\`])/gcs) {
$Emit-> ({type => 'error', error => {type => 'before-attribute-value-0060', level => 'm', index => $Offset + pos $Input}});
$Attr->{q<value>} .= $1;
$State = q<attribute value (unquoted) state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<value>} .= $1;
$State = q<attribute value (unquoted) state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<between DOCTYPE public and system identifiers state>} = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (double-quoted) state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = q<DOCTYPE system identifier (single-quoted) state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'between-doctype-public-and-system-identifiers-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<force_quirks_flag>} = 1;
$State = q<bogus DOCTYPE state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Token->{q<force_quirks_flag>} = 1;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<bogus DOCTYPE state>} = sub {
if ($Input =~ /\G([^\>]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} else {
if ($EOF) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<bogus comment state>} = sub {
if ($Input =~ /\G([^\\>]+)/gcs) {
$Token->{q<data>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} else {
if ($EOF) {

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<bogus comment state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<bogus comment state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<character reference in RCDATA state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<RCDATA state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<RCDATA state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in RCDATA state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<RCDATA state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<RCDATA state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<character reference in data state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<data state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Temp = q@&@;
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment end bang state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@--!@;
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$Token->{q<data>} .= q@--!@;
$State = q<comment end dash state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@--!�@;
$State = q<comment state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@--!@;
$Token->{q<data>} .= $1;
$State = q<comment state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment end dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<comment end state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@-�@;
$State = q<comment state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = q<comment state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment end state>} = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@--�@;
$State = q<comment state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-end-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\!])/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-end-0021', level => 'm', index => $Offset + pos $Input}});
$State = q<comment end bang state>;
} elsif ($Input =~ /\G([\-])/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-end-002d', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@-@;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-end-else', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= $1;
$State = q<comment state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment start dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<comment end state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@-�@;
$State = q<comment state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-start-dash-003e', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = q<comment state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment start state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<comment start dash state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@�@;
$State = q<comment state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'comment-start-003e', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= $1;
$State = q<comment state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment state>} = sub {
if ($Input =~ /\G([^\\-\ ]+)/gcs) {
$Token->{q<data>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<comment end dash state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@�@;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<comment state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<comment state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = q<comment state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<comment end dash state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<comment state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state>} = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<tag open state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference before hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = q<data state - character reference hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-before-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference decimal number state>} = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-decimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference hexadecimal number state>} = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-hexadecimal-number-else', level => 'm', index => $Offset + pos $Input}});

        my $code = $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF;
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U+%04X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          $Emit->({type => 'error',
                   error => {type => 'invalid character reference',
                             text => (sprintf 'U-%08X', $code),
                             level => 'm',
                             index => pos $Input}}); # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference name state>} = sub {
if ($Input =~ /\G([\])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
} elsif ($Input =~ /\G([\<])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G([\=])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {

        for (reverse (2 .. length $Temp)) {
          my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
          if (defined $value) {
            unless (';' eq substr $Temp, $_-1, 1) {
              $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
            }
            substr ($Temp, 0, $_) = $value;
            last;
          }
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference number state>} = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<data state - character reference decimal number state>;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = q<data state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = q<data state - character reference before hexadecimal number state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'character-reference-number-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<data state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state - character reference state after 000D>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\
])/gcs) {
$State = q<data state - character reference state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = q<data state - character reference number state>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = q<data state - character reference name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<data state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<data state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<tag open state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<end tag open state>} = sub {
if ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'end-tag-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Emit-> ({type => 'error', error => {type => 'end-tag-open-003e', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'end-tag-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state>} = sub {
if ($Input =~ /\G([\-])/gcs) {
$Temp = $1;
$State = q<markup declaration open state -- ->;
} elsif ($Input =~ /\G([D])/gcs) {
$Temp = $1;
$State = q<markup declaration open state -- D>;
} elsif ($Input =~ /\G([\[])/gcs) {
$Temp = $1;
$State = q<markup declaration open state -- [>;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp = $1;
$State = q<markup declaration open state -- D>;
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- ->} = sub {
if ($Input =~ /\G([\-])/gcs) {
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- D>} = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DO>;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DO>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- DO>} = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOC>;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOC>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- DOC>} = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCT>;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCT>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- DOCT>} = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCTY>;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCTY>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- DOCTY>} = sub {
if ($Input =~ /\G([P])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCTYP>;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- DOCTYP>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- DOCTYP>} = sub {
if ($Input =~ /\G([E])/gcs) {
$State = q<DOCTYPE state>;
} elsif ($Input =~ /\G([e])/gcs) {
$State = q<DOCTYPE state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [>} = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- [C>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [C>} = sub {
if ($Input =~ /\G([D])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- [CD>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [CD>} = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- [CDA>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [CDA>} = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- [CDAT>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [CDAT>} = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = q<markup declaration open state -- [CDATA>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<markup declaration open state -- [CDATA>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = q<bogus comment state after 000D>;
} elsif ($Input =~ /\G([\>])/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
} elsif ($Input =~ /\G([\[])/gcs) {
if ('XXX' eq 'in-foreign') {
          $State = q<CDATA section state>;
          last if 1;
        }
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Temp = '';
$Emit-> ({type => 'error', error => {type => 'markup-declaration-open-else', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escape end state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escape end state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escape end state after 000D>} = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = q<script data double escape end state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\
])/gcs) {
$State = q<script data double escape end state>;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escape end state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<script data double escape end state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<script data double escape end state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data escaped state>;
        } else {
          $State = q<script data double escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = q<script data double escape end state>;
$Temp .= chr ((ord $1) + 32);
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = q<script data double escape end state>;
$Temp .= $1;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escape start state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escape start state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escape start state after 000D>} = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = q<script data double escape start state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\
])/gcs) {
$State = q<script data double escape start state>;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escape start state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<script data double escape start state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<script data double escape start state>;

        if ($Temp eq 'script') { # XXX
          $State = q<script data double escaped state>;
        } else {
          $State = q<script data escaped state>;
        }
      
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = q<script data double escape start state>;
$Temp .= chr ((ord $1) + 32);
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = q<script data double escape start state>;
$Temp .= $1;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escaped dash dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escaped state after 000D>;
} elsif ($Input =~ /\G([\-]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@>@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escaped dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escaped less-than sign state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = q<script data double escape end state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@/@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escaped state>} = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data double escaped state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<script data double escaped state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data double escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data double escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data double escaped less-than sign state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data double escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data end tag name state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\/])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<self-closing start tag state>;
          last if 1;
        }
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<data state>;
          $Emit-> ($Token);
          last if 1;
        }
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data end tag open state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = q<script data end tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = q<script data end tag name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escape start dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escape start state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escape start dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped dash dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@>@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped dash state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped end tag name state>} = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<before attribute name state>;
          last if 1;
        }
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<self-closing start tag state>;
          last if 1;
        }
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\>])/gcs) {
if ($Temp eq $LastStartTagName) {
          $State = q<data state>;
          $Emit-> ($Token);
          last if 1;
        }
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped end tag open state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = q<script data escaped end tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = q<script data escaped end tag name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@</@, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped less-than sign state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = q<script data escaped end tag open state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = '';
$Temp .= chr ((ord $1) + 32);
$State = q<script data double escape start state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = '';
$Temp .= $1;
$State = q<script data double escape start state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped state>} = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data escaped state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<script data escaped state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data escaped state after 000D>;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = q<script data escaped dash state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@-@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data escaped less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data escaped state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<data state>;
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data less-than sign state>} = sub {
if ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\!])/gcs) {
$State = q<script data escape start state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<!@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = q<script data end tag open state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data state>} = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});

} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<script data state after 000D>} = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = q<script data state>;
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<script data state after 000D>;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = q<script data less-than sign state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = q<script data state>;
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@�@, index => $Offset + pos $Input});
} elsif ($Input =~ /\G(.)/gcs) {
$State = q<script data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$State = q<script data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<self-closing start tag state>} = sub {
if ($Input =~ /\G([\>])/gcs) {
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\"])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0022', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\'])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-0027', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003c', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([\=])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => 'error', error => {type => 'before-attribute-name-003d', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'self-closing-start-tag-else', level => 'm', index => $Offset + pos $Input}});
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = q<attribute name state>;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<tag name state>} = sub {
if ($Input =~ /\G([^\	\\ \
\\/\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<tag_name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<self-closing start tag state>;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Token->{q<tag_name>} .= q@�@;
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'EOF', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};
$StateActions->{q<tag open state>} = sub {
if ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {
$State = q<markup declaration open state>;
$Temp = $1;
$State = q<markup declaration open state -- ->;
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
$State = q<comment start dash state>;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $2;
$State = q<comment state>;
$Token->{q<data>} .= $3;
$State = q<comment end dash state>;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $4;
$State = q<comment state>;
$Token->{q<data>} .= $5;
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {
$State = q<markup declaration open state>;
$Temp = $1;
$State = q<markup declaration open state -- ->;
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
$Token->{q<data>} .= $2;
$State = q<comment state>;
$Token->{q<data>} .= $3;
$State = q<comment end dash state>;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $4;
$State = q<comment state>;
$Token->{q<data>} .= $5;
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<before attribute name state>;
} elsif ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {
$State = q<markup declaration open state>;
$Temp = $1;
$State = q<markup declaration open state -- ->;
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
$State = q<comment start dash state>;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $2;
$State = q<comment state>;
$Token->{q<data>} .= $3;
$State = q<comment end dash state>;
$State = q<comment end state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {
$State = q<markup declaration open state>;
$Temp = $1;
$State = q<markup declaration open state -- ->;
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
$Token->{q<data>} .= $2;
$State = q<comment state>;
$Token->{q<data>} .= $3;
$State = q<comment end dash state>;
$State = q<comment end state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<self-closing start tag state>;
$Token->{q<self_closing_flag>} = 1;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = q<end tag open state>;
$Token = {type => END_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
$Token->{q<tag_name>} .= $2;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G\!(\-)\-\-\-\>/gcs) {
$State = q<markup declaration open state>;
$Temp = $1;
$State = q<markup declaration open state -- ->;
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<comment start state>;
$State = q<comment start dash state>;
$State = q<comment end state>;
$State = q<data state>;

        if ($Token->{type} == END_TAG_TOKEN and
            keys %{$Token->{attributes} or {}}) {
          $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
        }
        $Emit->($Token);
      
} elsif ($Input =~ /\G([\!])/gcs) {
$State = q<markup declaration open state>;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = q<end tag open state>;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = q<tag name state>;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Token = {type => START_TAG_TOKEN, index => $Offset + pos $Input};
$Token->{q<tag_name>} = $1;
$State = q<tag name state>;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => 'error', error => {type => 'NULL', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} elsif ($Input =~ /\G([\])/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => q@
@, index => $Offset + pos $Input});
$State = q<data state after 000D>;
} elsif ($Input =~ /\G([\&])/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<character reference in data state>;
} elsif ($Input =~ /\G([\<])/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$State = q<tag open state>;
} elsif ($Input =~ /\G([\?])/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-003f', level => 'm', index => $Offset + pos $Input}});
$Token = {type => COMMENT_TOKEN, index => $Offset + pos $Input};
$Token->{q<data>} = '';
$State = q<bogus comment state>;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => CHARACTER_TOKEN, value => $1, index => $Offset + pos $Input});
} else {
if ($EOF) {
$Emit-> ({type => 'error', error => {type => 'tag-open-else', level => 'm', index => $Offset + pos $Input}});
$State = q<data state>;
$Emit-> ({type => CHARACTER_TOKEN, value => q@<@, index => $Offset + pos $Input});
$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;
} else {
return 1;
}
}
return 0;
};

    sub parse_char_string {
      my ($self, $in) = @_;

local $State = $self->{state} || 'data state';
local $Token = $self->{token};
local $Attr = $self->{attr};
local $Temp = $self->{temp};
local $LastStartTagName = $self->{last_start_tag_name};
local $Emit = sub { $self->_emit (@_) };
local $EOF = 0;
local $Offset = 0;

pos ($in) = 0;
      while ($in =~ /[\x{0001}-\x{0008}\x{000B}\x{000E}-\x{001F}\x{007F}-\x{009F}\x{D800}-\x{DFFF}\x{FDD0}-\x{FDEF}\x{FFFE}-\x{FFFF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gc) {
        $Emit-> ({type => 'error'});
      }

pos ($in) = 0;
$Input = '';

my $length = length $in;
my $i = 0;
while ($i < $length) {
my $len = 10000;
$len = $length - $i if $i + $len > $length;
$Offset += $i;
$Input = substr $in, $i, $len;
$self->_parse_segment;
$i += $len;
}

$EOF = 1;

$self->_parse_segment;

$self->{state} = $State;
$self->{token} = $Token;
$self->{attr} = $Attr;
$self->{temp} = $Temp;
$self->{last_start_tag_name} = $LastStartTagName;
$self->{eof} = $EOF;
$self->{offset} = $Offset;
undef $Emit;

    } # parse

    sub _parse_segment {
      TOKENIZER: while (1) {
        my $code = $StateActions->{$State}
            or die "Unknown state |$State|";
        &$code and last TOKENIZER;
      } # TOKENIZER
    } # _parse_segment

    1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

  