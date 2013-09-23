package Web::XPath::Parser;
use strict;
use warnings;
our $VERSION = '1.0';
use Char::Class::XML qw(InXMLNCNameChar10_1 InXML_NCNameStartChar10_1);

sub new ($) {
  return bless {}, $_[0];
} # new

sub tokenize ($$) {
  my $input = $_[1];
  my $length = length $input;

  my @token;
  while (length $input) {
    if ($input =~ s/^[\x09\x0A\x0D\x20]+//) { # S
      #
    } elsif ($input =~ s/^\.\.//) {
      push @token, ['..'];
    } elsif ($input =~ s/^(\.[0-9]+)//) {
      push @token, ['Number', $1];
    } elsif ($input =~ s/^([0-9]+(?:\.[0-9]*)?)//) {
      push @token, ['Number', $1];
    } elsif ($input =~ s/^:://) {
      push @token, ['::'];
    } elsif ($input =~ s{^//}{}) {
      push @token, ['Operator', '//'];
    } elsif ($input =~ s{^([!<>]=)}{}) {
      push @token, ['Operator', $1];
    } elsif ($input =~ s/^([()\[\].\@,])//) {
      push @token, [$1];
    } elsif ($input =~ s{^([/|+=<>-])}{}) {
      push @token, ['Operator', $1];
    } elsif ($input =~ s/^([:*\$])//) {
      push @token, [$1];
      $token[-1]->[3] = 1 + length $input;
      $token[-1]->[2] = $input =~ s/^[\x09\x0A\x0D\x20]+//;
    } elsif ($input =~ s/^"([^"]*)"//) {
      push @token, ['Literal', $1];
    } elsif ($input =~ s/^'([^']*)'//) {
      push @token, ['Literal', $1];
    } elsif ($input =~ s/^(\p{InXML_NCNameStartChar10_1}\p{InXMLNCNameChar10_1}*)//) {
      push @token, ['NCName', $1];
      $token[-1]->[3] = (length $1) + (length $input);
      $token[-1]->[2] = $input =~ s/^[\x09\x0A\x0D\x20]+//;
    } else {
      return [['error', $length - length $input]];
    }
  }
  unshift @token, ['SOF'];
  push @token, ['EOF'];

  for my $i (0..$#token) {
    if ($token[$i]->[0] eq '*') {
      if (not {SOF => 1, '@' => 1, '::' => 1, '(' => 1,
               '[' => 1, ',' => 1, Operator => 1}->{$token[$i-1]->[0]}) {
        $token[$i] = ['Operator', '*'];
      } else {
        $token[$i] = ['NameTest', undef, undef];
      }
    } elsif ($token[$i]->[0] eq 'NCName') {
      if (not {SOF => 1, '@' => 1, '::' => 1, '(' => 1,
               '[' => 1, ',' => 1, Operator => 1}->{$token[$i-1]->[0]}) {
        if ({and => 1, or => 1, mod => 1, div => 1}->{$token[$i]->[1]}) {
          $token[$i] = ['Operator', $token[$i]->[1]];
          next;
        }
      }
      if ($token[$i+1]->[0] eq '(') {
        if ({comment => 1, text => 1, 'processing-instruction' => 1,
             node => 1}->{$token[$i]->[1]}) {
          $token[$i] = ['NodeType', $token[$i]->[1]];
        } else {
          $token[$i] = ['FunctionName', undef, $token[$i]->[1]];
        }
      } elsif ($token[$i+1]->[0] eq '::') {
        if ({ancestor => 1, 'ancestor-or-self' => 1,
             attribute => 1,
             child => 1,
             descendant => 1, 'descendant-or-self' => 1,
             following => 1, 'following-sibling' => 1,
             namespace => 1,
             parent => 1,
             preceding => 1, 'preceding-sibling' => 1,
             self => 1}->{$token[$i]->[1]}) {
          $token[$i] = ['AxisName', $token[$i]->[1]];
        } else {
          return [['error', $length - $token[$i]->[3]]];
        }
      } elsif ($token[$i]->[2]) { # Followed by S
        if ($token[$i-1]->[0] eq '$' and not $token[$i-1]->[2]) {
          $token[$i] = ['VariableReference', undef, $token[$i]->[1]];
          $token[$i-1]->[0] = '';
        } else {
          $token[$i] = ['NameTest', undef, $token[$i]->[1]];
        }
      } elsif ($token[$i+1]->[0] eq ':' and not $token[$i+1]->[2]) {
        if ($token[$i+2]->[0] eq '*') {
          if ($token[$i-1]->[0] eq '$') {
            return [['error', $length - $token[$i-1]->[3]]];
          }
          $token[$i] = ['NameTest', $token[$i]->[1], undef];
        } elsif ($token[$i+2]->[0] eq 'NCName') {
          if ($token[$i+3]->[0] eq '(') {
            if ({comment => 1, text => 1, 'processing-instruction' => 1,
                 node => 1}->{$token[$i+2]->[1]}) {
              return [['error', $length - $token[$i+2]->[3]]];
            } else {
              $token[$i] = ['FunctionName', $token[$i]->[1], $token[$i+2]->[1]];
            }
          } elsif ($token[$i+3]->[0] eq '::') {
            return [['error', $length - $token[$i+2]->[3]]];
          } elsif ($token[$i-1]->[0] eq '$' and not $token[$i-1]->[2]) {
            $token[$i] = ['VariableReference',
                          $token[$i]->[1], $token[$i+2]->[1]];
            $token[$i-1]->[0] = '';
          } else {
            $token[$i] = ['NameTest', $token[$i]->[1], $token[$i+2]->[1]];
          }
        } else {
          return [['error', $length - $token[$i]->[3]]];
        }
        $token[$i+1]->[0] = '';
        $token[$i+2]->[0] = '';
      } else {
        $token[$i] = ['NameTest', undef, $token[$i]->[1]];
      }
    }
  }

  @token = grep {
    return [['error', $length - $_->[3]]] if $_->[0] eq ':' or $_->[0] eq '$';
    $_->[0] ne '';
  } @token;
  shift @token; # SOF

  return \@token;
} # tokenize

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
