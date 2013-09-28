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
      push @token, ['..', $length-($+[0]-$-[0])-length $input];
    } elsif ($input =~ s/^(\.[0-9]+)//) {
      push @token, ['Number', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^([0-9]+(?:\.[0-9]*)?)//) {
      push @token, ['Number', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^:://) {
      push @token, ['::', $length-($+[0]-$-[0])-length $input];
    } elsif ($input =~ s{^//}{}) {
      push @token, ['Operator', $length-($+[0]-$-[0])-length $input, '//'];
    } elsif ($input =~ s{^([!<>]=)}{}) {
      push @token, ['Operator', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^([()\[\].\@,])//) {
      push @token, [$1, $length-($+[0]-$-[0])-length $input];
    } elsif ($input =~ s{^([/|+=<>-])}{}) {
      push @token, ['Operator', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^([:*\$])//) {
      push @token, [$1, $length-($+[0]-$-[0])-length $input];
      $token[-1]->[3] = $input =~ s/^[\x09\x0A\x0D\x20]+//;
    } elsif ($input =~ s/^"([^"]*)"//) {
      push @token, ['Literal', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^'([^']*)'//) {
      push @token, ['Literal', $length-($+[0]-$-[0])-length $input, $1];
    } elsif ($input =~ s/^(\p{InXML_NCNameStartChar10_1}\p{InXMLNCNameChar10_1}*)//) {
      push @token, ['NCName', $length-($+[0]-$-[0])-length $input, $1];
      $token[-1]->[3] = $input =~ s/^[\x09\x0A\x0D\x20]+//;
    } else {
      return [['error', $length - length $input]];
    }
  }
  unshift @token, ['SOF', 0];
  push @token, ['EOF', $length];

  for my $i (0..$#token) {
    if ($token[$i]->[0] eq '*') {
      if (not {SOF => 1, '@' => 1, '::' => 1, '(' => 1,
               '[' => 1, ',' => 1, Operator => 1}->{$token[$i-1]->[0]}) {
        $token[$i] = ['Operator', $token[$i]->[1], '*'];
      } else {
        $token[$i] = ['NameTest', $token[$i]->[1], undef, undef];
      }
    } elsif ($token[$i]->[0] eq 'NCName') {
      if (not {SOF => 1, '@' => 1, '::' => 1, '(' => 1,
               '[' => 1, ',' => 1, Operator => 1}->{$token[$i-1]->[0]}) {
        if ({and => 1, or => 1, mod => 1, div => 1}->{$token[$i]->[2]}) {
          $token[$i] = ['Operator', $token[$i]->[1], $token[$i]->[2]];
          next;
        }
      }
      if ($token[$i+1]->[0] eq '(') {
        if ({comment => 1, text => 1, 'processing-instruction' => 1,
             node => 1}->{$token[$i]->[2]}) {
          $token[$i] = ['NodeType', $token[$i]->[1], $token[$i]->[2]];
        } else {
          $token[$i] = ['FunctionName', $token[$i]->[1],
                        undef, $token[$i]->[2]];
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
             self => 1}->{$token[$i]->[2]}) {
          $token[$i] = ['AxisName', $token[$i]->[1], $token[$i]->[2]];
        } else {
          return [['error', $token[$i]->[1]]];
        }
      } elsif ($token[$i]->[3]) { # Followed by S
        if ($token[$i-1]->[0] eq '$' and not $token[$i-1]->[3]) {
          $token[$i] = ['VariableReference', $token[$i-1]->[1],
                        undef, $token[$i]->[2]];
          $token[$i-1]->[0] = '';
        } else {
          $token[$i] = ['NameTest', $token[$i]->[1], undef, $token[$i]->[2]];
        }
      } elsif ($token[$i+1]->[0] eq ':' and not $token[$i+1]->[3]) {
        if ($token[$i+2]->[0] eq '*') {
          if ($token[$i-1]->[0] eq '$') {
            return [['error', $token[$i-1]->[1]]];
          }
          $token[$i] = ['NameTest', $token[$i]->[1], $token[$i]->[2], undef];
        } elsif ($token[$i+2]->[0] eq 'NCName') {
          if ($token[$i+3]->[0] eq '(') {
            if ({comment => 1, text => 1, 'processing-instruction' => 1,
                 node => 1}->{$token[$i+2]->[2]}) {
              return [['error', $token[$i+2]->[1]]];
            } else {
              $token[$i] = ['FunctionName', $token[$i]->[1],
                            $token[$i]->[2], $token[$i+2]->[2]];
            }
          } elsif ($token[$i+3]->[0] eq '::') {
            return [['error', $token[$i+2]->[1]]];
          } elsif ($token[$i-1]->[0] eq '$' and not $token[$i-1]->[3]) {
            $token[$i] = ['VariableReference', $token[$i-1]->[1],
                          $token[$i]->[2], $token[$i+2]->[2]];
            $token[$i-1]->[0] = '';
          } else {
            $token[$i] = ['NameTest', $token[$i]->[1],
                          $token[$i]->[2], $token[$i+2]->[2]];
          }
        } else {
          return [['error', $token[$i]->[1]]];
        }
        $token[$i+1]->[0] = '';
        $token[$i+2]->[0] = '';
      } elsif ($token[$i-1]->[0] eq '$') {
        $token[$i] = ['VariableReference', $token[$i-1]->[1],
                      undef, $token[$i]->[2]];
        $token[$i-1]->[0] = '';
      } else {
        $token[$i] = ['NameTest', $token[$i]->[1], undef, $token[$i]->[2]];
      }
    }
  }

  @token = grep {
    return [['error', $_->[1]]] if $_->[0] eq ':' or $_->[0] eq '$';
    $_->[0] ne '';
  } @token;
  shift @token; # SOF

  return \@token;
} # tokenize

my %Op = (
  expr => 100,
  or => 8,
  and => 7,
  '=' => 6, '!=' => 6,
  '<' => 5, '>' => 5, '<=' => 5, '>=' => 5,
  '+' => 4, '-' => 4,
  '*' => 3, div => 3, mod => 3,
  negate => 2,
  '|' => 1,
  path => 0,
  # step function Number Literal VariableReference root
);

sub parse_expression ($$) {
  my ($self) = @_;
  my $tokens = $self->tokenize ($_[1]);
  if ($tokens->[0]->[0] eq 'error') {
    # XXX
    return undef;
  }

  my $open = [{type => 'expr', delim => 'EOF'}, {type => 'path', steps => []}];
  $open->[0]->{value} = $open->[1];
  my $state = 'before UnaryExpr';
  my $t = shift @$tokens;
  W: while (1) {
    if ($state eq 'before UnaryExpr') {
      if ($t->[0] eq 'Operator' and $t->[2] eq '-') {
        my $right = {%{$open->[-1]}};
        %{$open->[-1]} = (type => 'negate', right => $right);
        push @$open, $right;
        $t = shift @$tokens;
      } else {
        $state = 'PathExpr';
      }
    } elsif ($state eq 'PathExpr') {
      if ($t->[0] eq 'VariableReference' or
          $t->[0] eq 'Literal' or
          $t->[0] eq 'Number' or
          $t->[0] eq '(' or
          $t->[0] eq 'FunctionName') {
        $state = 'PrimaryExpr';
      } else {
        $state = 'LocationPath';
      }
    } elsif ($state eq 'LocationPath') {
      if ($t->[0] eq 'Operator') {
        if ($t->[2] eq '/') {
          push @{$open->[-1]->{steps}}, {type => 'root'};
          $t = shift @$tokens;
          $state = 'before Step?';
        } elsif ($t->[2] eq '//') {
          push @{$open->[-1]->{steps}},
              {type => 'root'},
              {type => 'step',
               axis => 'descendant-or-self', node_type => 'node',
               predicates => []};
          $t = shift @$tokens;
          $state = 'before Step?';
        } else {
          last W;
        }
      } elsif ($t->[0] eq '.') {
        push @{$open->[-1]->{steps}},
            {type => 'step', axis => 'self', node_type => 'node',
             predicates => []};
        $t = shift @$tokens;
        $state = 'after Step';
      } elsif ($t->[0] eq '..') {
        push @{$open->[-1]->{steps}},
            {type => 'step', axis => 'parent', node_type => 'node',
             predicates => []};
        $t = shift @$tokens;
        $state = 'after Step';
      } else {
        $state = 'NodeTest';
      }
    } elsif ($state eq 'before Step' or $state eq 'before Step?') {
      if ($t->[0] eq '.') {
        push @{$open->[-1]->{steps}},
            {type => 'step', axis => 'self', node_type => 'node',
             predicates => []};
        $t = shift @$tokens;
        $state = 'after Step';
      } elsif ($t->[0] eq '..') {
        push @{$open->[-1]->{steps}},
            {type => 'step', axis => 'parent', node_type => 'node',
             predicates => []};
        $t = shift @$tokens;
        $state = 'after Step';
      } else {
        if ($state eq 'before Step?') {
          $state = 'NodeTest?';
        } else {
          $state = 'NodeTest';
        }
      }
    } elsif ($state eq 'NodeTest' or $state eq 'NodeTest?') {
      my $step = {type => 'step', predicates => []};

      # AxisSpecifier
      if ($t->[0] eq 'AxisName') {
        $step->{axis} = $t->[2];
        $t = shift @$tokens;
        if ($t->[0] eq '::') {
          $t = shift @$tokens;
        } else {
          last W;
        }
      } elsif ($t->[0] eq '@') {
        $step->{axis} = 'attribute';
        $t = shift @$tokens;
      } else {
        $step->{axis} = 'child';
      }

      # NodeTest
      if ($t->[0] eq 'NameTest') {
        # XXX NSResolver
        $step->{prefix} = $t->[2];
        $step->{local_name} = $t->[3];
        $t = shift @$tokens;
      } elsif ($t->[0] eq 'NodeType') {
        $step->{node_type} = $t->[2];
        $t = shift @$tokens;
        if ($t->[0] eq '(') {
          $t = shift @$tokens;
          if ($step->{node_type} eq 'processing-instruction' and
              $t->[0] eq 'Literal') {
            $step->{target} = $t->[2];
            $t = shift @$tokens;
          }
          if ($t->[0] eq ')') {
            $t = shift @$tokens;
          } else {
            last W;
          }
        } else {
          last W;
        }
      } else {
        if ($state eq 'NodeTest?') {
          $state = 'after PathExpr';
        } else {
          last W;
        }
      }

      push @{$open->[-1]->{steps}}, $step;
      $state = 'after NodeTest';
    } elsif ($state eq 'after NodeTest') {
      if ($t->[0] eq '[') {
        $t = shift @$tokens;
        my $path = {type => 'path', steps => []};
        my $expr = {type => 'expr', value => $path,
                    delim => ']', next => 'after NodeTest'};
        push @{$open->[-1]->{steps}->[-1]->{predicates}}, $expr;
        push @$open, $expr, $path;
        $state = 'before UnaryExpr';
      } else {
        $state = 'after Step';
      }
    } elsif ($state eq 'PrimaryExpr') {
      if ($t->[0] eq 'VariableReference' or
          $t->[0] eq 'Literal' or
          $t->[0] eq 'Number') {
        push @{$open->[-1]->{steps}}, {type => $t->[0], value => $t->[2]};
        $t = shift @$tokens;
        $state = 'after Step';
      } elsif ($t->[0] eq '(') { # ( Expr )
        $t = shift @$tokens;
        my $path = {type => 'path', steps => []};
        my $expr = {type => 'expr', value => $path,
                    delim => ')', next => 'after Step'};
        push @{$open->[-1]->{steps}}, $expr;
        push @$open, $expr, $path;
        $state = 'before UnaryExpr';
      } elsif ($t->[0] eq 'FunctionName') { # FunctionCall
        my $prefix = $t->[2];
        my $ln = $t->[3];
        $t = shift @$tokens;
        if ($t->[0] eq '(') {
          $t = shift @$tokens;
          if ($t->[0] eq ')') {
            push @{$open->[-1]->{steps}},
                {type => 'function', prefix => $prefix, local_name => $ln,
                 args => []};
            $state = 'after Step';
          } else {
            my $path = {type => 'path', steps => []};
            my $expr = {type => 'expr', value => $path,
                        delim => ')', sep => ',', next => 'after Step'};
            my $func = {type => 'function',
                        prefix => $prefix, local_name => $ln, args => [$expr]};
            push @{$open->[-1]->{steps}}, $func;
            push @$open, $func, $expr, $path;
            $state = 'before UnaryExpr';
          }
        } else {
          last M;
        }
      } else {
        last W;
      }
    } elsif ($state eq 'after Step') {
      if ($t->[0] eq 'Operator') {
        if ($t->[2] eq '/') {
          $t = shift @$tokens;
          $state = 'before Step';
        } elsif ($t->[2] eq '//') {
          push @{$open->[-1]->{steps}},
              {type => 'step',
               axis => 'descendant-or-self', node_type => 'node',
               predicates => []};
          $t = shift @$tokens;
          $state = 'before Step';
        } else {
          $state = 'after PathExpr';
        }
      } else {
        $state = 'after PathExpr';
      }
    } elsif ($state eq 'after PathExpr') {
      if ($t->[0] eq 'Operator' and $t->[2] eq '|') {
        my $i = -1;
        $i-- while exists $open->[$i-1] and $Op{$open->[$i-1]->{type}} <= $Op{$t->[2]};
        my $child1 = {%{$open->[$i]}};
        my $child2 = {type => 'path', steps => []};
        %{$open->[$i]} = (type => $t->[2], left => $child1, right => $child2);
        push @$open, $child2;
        $t = shift @$tokens;
        $state = 'PathExpr';
      } elsif ($t->[0] eq 'Operator') {
        my $i = -1;
        $i-- while exists $open->[$i-1] and $Op{$open->[$i-1]->{type}} <= $Op{$t->[2]};
        my $child1 = {%{$open->[$i]}};
        my $child2 = {type => 'path', steps => []};
        %{$open->[$i]} = (type => $t->[2], left => $child1, right => $child2);
        splice @$open, $i+1 if $i < -1;
        push @$open, $child2;
        $t = shift @$tokens;
        $state = 'before UnaryExpr';
      } else {
        pop @$open while $open->[-1]->{type} ne 'expr';
        if ($t->[0] eq $open->[-1]->{delim}) {
          delete $open->[-1]->{delim};
          delete $open->[-1]->{sep};
          if ($t->[0] eq 'EOF') {
            return $open->[0];
          } else {
            $t = shift @$tokens;
            $state = delete $open->[-1]->{next};
            pop @$open;
            pop @$open if $open->[-1]->{type} eq 'function';
          }
        } elsif (defined $open->[-1]->{sep} and
                 $t->[0] eq $open->[-1]->{sep}) {
          delete $open->[-1]->{delim};
          delete $open->[-1]->{sep};
          delete $open->[-1]->{next};
          $t = shift @$tokens;
          my $path = {type => 'path', steps => []};
          my $expr = {type => 'expr', value => $path,
                      delim => ')', sep => ',', next => 'after Step'};
          pop @$open;
          push @{$open->[-1]->{args}}, $expr;
          push @$open, $expr, $path;
          $state = 'before UnaryExpr';
        } else {
          last W;
        }
      }
    } else {
      last W;
    } # $state
  } # W

  # XXX
  use Data::Dumper;
  warn Dumper $open;
  die;
} # parse_expression

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
