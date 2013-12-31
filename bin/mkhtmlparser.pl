#!/usr/bin/perl 
use strict;

my $TokenizerDebug = $ENV{TOKENIZER_DEBUG};
my $ParserDebug = $ENV{PARSER_DEBUG};

while (<>) {
  s{!!!emit\b}{
    ($TokenizerDebug ? q{
      (warn "EMIT " . (join ' ', %$_) . "\n" and
       return $_)
        for
    } : q{return })
  }e;
  s{!!!next-input-character;}{q{
    $self->_set_nc;
  }}ge;
  s{!!!nack\s*\(\s*'([^']+)'\s*\)\s*;}{
    ($TokenizerDebug ? qq{
      if (\$self->{self_closing}) {
        !!!cp ('$1.2');
      } else {
        !!!cp ('$1.3');
      }
    } : '')
  }ge;
  s{!!!ack\s*(?>\([^)]*\)\s*)?;}{q{delete $self->{self_closing};}}ge;
  s{!!!ack-later\s*(?>\([^)]*\)\s*)?;}{}ge;
  s{!!!parse-error\s*\(}{
    q{$self->{parse_error}->(level => $self->{level}->{must}, }
  }ge;
  s{!!!next-token;}{q{$self->{t} = $self->_get_next_token;}}ge;
  s{!!!cp\s*\(\s*(\S+)\s*\)\s*;}{
    $TokenizerDebug ? qq{
      #print STDERR "$1, ";
      \$Web::HTML::Debug::cp_pass->($1) if \$Web::HTML::Debug::cp_pass;
      BEGIN {
        \$Web::HTML::Debug::cp->{$1} = 1;
      }
    } : ''
  }ge;
  s{!!!tdebug\s*(\{.*\})\s*;}{
    $TokenizerDebug ? $1 : ''
  }ge;
  s{!!!pdebug\s*(\{.*\})\s*;}{
    $ParserDebug ? $1 : ''
  }ge;
  print;
}
