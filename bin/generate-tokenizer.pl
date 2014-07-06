use strict;
use warnings;
# split10000index
use Path::Tiny;
use JSON::PS;

sub new ($) {
  return bless {}, $_[0];
} # new

sub _expanded_tokenizer_defs ($) {
  my $expanded_json_path = path (__FILE__)->parent->parent->child
      ('local/html-tokenizer-expanded.json');
  return json_bytes2perl $expanded_json_path->slurp;
} # _expanded_tokenizer_defs

sub serialize_actions ($) {
  my @result;
  my $reconsume;
  for (@{$_[0]->{actions}}) {
    my $type = $_->{type};
    if ($type eq 'error') {
      push @result, sprintf q[$Emit-> ({type => 'error', error => {type => '%s', level => 'm', index => $Offset + pos $Input}});],
          $_->{name};
    } elsif ($type eq 'switch') {
      if (not defined $_->{if}) {
        push @result, sprintf q[$State = q<%s>;], $_->{state};
      } elsif ($_->{if} eq 'appropriate end tag') {
        push @result, sprintf q[if ($Temp eq $LastStartTagName) {
          $State = q<%s>;
          return 0 if %d;
        }], $_->{state}, $_->{break};
      } elsif ($_->{if} eq 'in-foreign') {
        push @result, sprintf q[if ('XXX' eq 'in-foreign') {
          $State = q<%s>;
          return 0 if %d;
        }], $_->{state}, $_->{break};
      } else {
        die "Unknown if |$_->{if}|";
      }
    } elsif ($type eq 'switch-and-emit') {
      if ($_->{if} eq 'appropriate end tag') {
        push @result, sprintf q[if ($Token->{tag_name} eq $LastStartTagName) {
          $State = q<%s>;
          $Emit-> ($Token);
          return 0 if %d;
        }], $_->{state}, $_->{break};
      } else {
        die "Unknown if |$_->{if}|";
      }
    } elsif ($type eq 'switch-by-temp') {
      push @result, sprintf q[
        if ($Temp eq 'script') { # XXX
          $State = q<%s>;
        } else {
          $State = q<%s>;
        }
      ], $_->{script_state}, $_->{state};
    } elsif ($type eq 'reconsume') {
      $reconsume = 1;
    } elsif ($type eq 'emit') {
      push @result, q{
        if ($Token->{type} == END_TAG_TOKEN) {
          if (keys %{$Token->{attributes} or {}}) {
            $Emit->({type => 'error', error => {type => 'end tag attribute', index => pos $Input}}); # XXX index
          }
          if ($Token->{self_closing_flag}) {
            $Emit->({type => 'error', error => {type => 'nestc', index => pos $Input}}); # XXX index
          }
        }
        $Emit->($Token);
      };
    } elsif ($type eq 'emit-eof') {
      push @result, q[$Emit-> ({type => END_OF_FILE_TOKEN, index => $Offset + pos $Input}); return 1;];
    } elsif ($type eq 'emit-temp') {
      push @result, q[$Emit-> ({type => CHARACTER_TOKEN, value => $Temp, index => $Offset + pos $Input});];
    } elsif ($type eq 'create') {
      push @result, sprintf q[$Token = {type => %s, index => $Offset + pos $Input};],
          {
            'DOCTYPE token' => 'DOCTYPE_TOKEN',
            'comment token' => 'COMMENT_TOKEN',
            'start tag token' => 'START_TAG_TOKEN',
            'end tag token' => 'END_TAG_TOKEN',
            EOF => 'END_OF_FILE_TOKEN',
            char => 'CHARACTER_TOKEN',
            'pi token' => 'PI_TOKEN',
            'end-of-doctype token' => 'END_OF_DOCTYPE_TOKEN',
            'attlist token' => 'ATTLIST_TOKEN',
            'element token' => 'ELEMENT_TOKEN',
            'general entity token' => 'GENERAL_ENTITY_TOKEN',
            'parameter entity token' => 'PARAMETER_ENTITY_TOKEN',
            'notation token' => 'NOTATION_TOKEN',
          }->{$_->{token}} || die "Unknown token type |$_->{token}|";
    } elsif ($type eq 'create-attr') {
      push @result, q[$Attr = {index => $Offset + pos $Input};];
    } elsif ($type eq 'set-attr') {
      push @result, q{
        if (defined $Token->{attributes}->{$Attr->{name}}) {
          $Emit->({type => 'error', error => {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}}});
        } else {
          $Token->{attributes}->{$Attr->{name}} = $Attr;
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
        push @result, sprintf q[$Emit-> ({type => CHARACTER_TOKEN, value => %s, index => $Offset + pos $Input});], $value;
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
      };
    } elsif ($type eq 'process-temp-as-hexadecimal') {
      push @result, q{
        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
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
                    $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
                    last REF;
                  } else {
                    $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            $Emit->({type => 'error', error => {type => 'not charref', text => $Temp, index => pos $Input}}) # XXXindex
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
                  $Emit->({type => 'error', error => {type => 'no refc', index => pos $Input}}); # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            $Emit->({type => 'error', error => {type => 'not charref', text => $Temp, index => pos $Input}}) # XXXindex
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

sub generate {
  my $self = shift;
  
  my $defs = $self->_expanded_tokenizer_defs->{tokenizer};

  my $generated = sprintf q[
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
  my (%%opt) = @_;
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
for (keys %%$Web::HTML::ParserData::NoncharacterCodePoints) {
  $InvalidCharRefs->{0}->{$_} = [$_, 'must'];
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'warn'];
}
for (0xFFFE, 0xFFFF) {
  $InvalidCharRefs->{1.0}->{$_} =
  $InvalidCharRefs->{1.1}->{$_} = [$_, 'must'];
}
for (keys %%$Web::HTML::ParserData::CharRefReplacements) {
  $InvalidCharRefs->{0}->{$_}
      = [$Web::HTML::ParserData::CharRefReplacements->{$_}, 'must'];
}

  ];
  for my $state (sort { $a cmp $b } keys %{$defs->{states}}) {
    $generated .= sprintf q[$StateActions->{q<%s>} = sub {]."\n", $state;
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
        if ($_->{type} eq 'error') {
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
    $generated .= join '', @case;
    $generated .= "return 0;\n";
    $generated .= q[};]."\n";
  }
  $generated .= q[
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

  ];

  return $generated;
}

my $obj = __PACKAGE__->new;
print $obj->generate;
