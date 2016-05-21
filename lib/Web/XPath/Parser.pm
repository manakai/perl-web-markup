package Web::XPath::Parser;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '2.0';
use Web::XML::_CharClasses;

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my %args = @_;
    warn sprintf "%d: %s (%s)\n",
        $args{index}, $args{type}, $args{level};
  };
} # onerror

sub ns_resolver ($;$) {
  if (@_ > 1) {
    $_[0]->{ns_resolver} = $_[1];
  }
  return $_[0]->{ns_resolver} ||= sub ($) { return undef };
} # ns_resolver

sub function_library ($;$) {
  if (@_ > 1) {
    $_[0]->{function_library} = $_[1];
  }
  return $_[0]->{function_library} || 'Web::XPath::FunctionLibrary';
} # function_library

sub variable_bindings ($;$) {
  if (@_ > 1) {
    $_[0]->{variable_bindings} = $_[1];
  }
  return $_[0]->{variable_bindings} ||= do {
    require Web::XPath::VariableBindings;
    Web::XPath::VariableBindings->new;
  };
} # variable_bindings

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
    } elsif ($input =~ s/^(\p{InNCNameStartChar}\p{InNCNameChar}*)//) {
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
          } elsif ($token[$i+3]->[0] eq '(') {
            return [['error', $token[$i+3]->[1]]];
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
  # step function num str var root
);

sub parse_char_string_as_expression ($$) {
  my ($self) = @_;
  my $tokens = $self->tokenize ($_[1]);
  if ($tokens->[0]->[0] eq 'error') {
    $self->onerror->(type => 'xpath:syntax error', # XXX
                     index => $tokens->[0]->[1],
                     level => 'm');
    return undef;
  }

  my $open = [{type => 'expr', delim => 'EOF',
               predicates => []},
              {type => 'path', steps => []}];
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
        if (defined $t->[2]) {
          $step->{nsurl} = \($self->ns_resolver->($t->[2]));
          if (not defined ${$step->{nsurl}}) {
            $self->onerror->(type => 'namespace prefix:not declared',
                             level => 'm',
                             index => $t->[1],
                             value => $t->[2]);
            return undef;
          }
        }
        $step->{prefix} = $t->[2];
        $step->{local_name} = $t->[3];
        $t = shift @$tokens;
        push @{$open->[-1]->{steps}}, $step;
        $state = 'after NodeTest';
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
            push @{$open->[-1]->{steps}}, $step;
            $state = 'after NodeTest';
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
    } elsif ($state eq 'after NodeTest') {
      if ($t->[0] eq '[') {
        $t = shift @$tokens;
        my $path = {type => 'path', steps => []};
        my $expr = {type => 'expr', value => $path,
                    delim => ']', next => 'after NodeTest',
                    predicates => []};
        push @{$open->[-1]->{steps}->[-1]->{predicates}}, $expr;
        push @$open, $expr, $path;
        $state = 'before UnaryExpr';
      } else {
        $state = 'after Step';
      }
    } elsif ($state eq 'PrimaryExpr') {
      if ($t->[0] eq 'Literal') {
        push @{$open->[-1]->{steps}},
            {type => 'str', value => $t->[2], predicates => []};
        $t = shift @$tokens;
        $state = 'after NodeTest';
      } elsif ($t->[0] eq 'Number') {
        push @{$open->[-1]->{steps}},
            {type => 'num', value => 0+$t->[2], predicates => []};
        $t = shift @$tokens;
        $state = 'after NodeTest';
      } elsif ($t->[0] eq 'VariableReference') {
        my $step = {type => 'var', prefix => $t->[2], local_name => $t->[3],
                    predicates => []};
        if (defined $t->[2]) {
          $step->{nsurl} = \($self->ns_resolver->($t->[2]));
          if (not defined ${$step->{nsurl}}) {
            $self->onerror->(type => 'namespace prefix:not declared',
                             level => 'm',
                             index => $t->[1] + 1,
                             value => $t->[2]);
            return undef;
          }
        }
        unless ($self->variable_bindings->has_variable
                    (defined $step->{nsurl} ? ${$step->{nsurl}} : undef, $step->{local_name})) {
          $self->onerror->(type => 'xpath:variable:unknown', # XXX
                           level => 'm',
                           index => $t->[1],
                           value => (defined $step->{prefix} ? "$step->{prefix}:$step->{local_name}" : $step->{local_name}));
          return undef;
        }
        push @{$open->[-1]->{steps}}, $step;
        $t = shift @$tokens;
        $state = 'after NodeTest';
      } elsif ($t->[0] eq '(') { # ( Expr )
        $t = shift @$tokens;
        my $path = {type => 'path', steps => []};
        my $expr = {type => 'expr', value => $path,
                    delim => ')', next => 'after NodeTest',
                    predicates => []};
        push @{$open->[-1]->{steps}}, $expr;
        push @$open, $expr, $path;
        $state = 'before UnaryExpr';
      } elsif ($t->[0] eq 'FunctionName') { # FunctionCall
        my $nsurl;
        if (defined $t->[2]) {
          $nsurl = \($self->ns_resolver->($t->[2]));
          if (not defined $$nsurl) {
            $self->onerror->(type => 'namespace prefix:not declared',
                             level => 'm',
                             index => $t->[1],
                             value => $t->[2]);
            return undef;
          }
        }
        my $prefix = $t->[2];
        my $ln = $t->[3];
        my $lib = $self->function_library;
        eval qq{ require $lib } or die $@;
        my $chk = $lib->get_argument_number
            (defined $nsurl ? $$nsurl : undef, $ln);
        unless ($chk) {
          $self->onerror->(type => 'xpath:function:unknown', # XXX
                           level => 'm',
                           index => $t->[1],
                           value => (defined $prefix ? "$prefix:$ln" : $ln));
          return undef;
        }
        $t = shift @$tokens;
        if ($t->[0] eq '(') {
          $t = shift @$tokens;
          if ($t->[0] eq ')') {
            unless ($chk->[0] == 0) {
              $self->onerror->(type => 'xpath:function:min', # XXX
                               level => 'm',
                               index => $t->[1]);
              return undef;
            }
            $t = shift @$tokens;
            push @{$open->[-1]->{steps}},
                {type => 'function', prefix => $prefix, local_name => $ln,
                 args => [], predicates => []};
            $open->[-1]->{steps}->[-1]->{nsurl} = $nsurl if defined $nsurl;
            $state = 'after NodeTest';
          } else {
            my $path = {type => 'path', steps => []};
            my $expr = {type => 'expr', value => $path, predicates => [],
                        delim => ')', sep => ',', next => 'after NodeTest'};
            my $func = {type => 'function',
                        prefix => $prefix, local_name => $ln, args => [$expr],
                        args_chk => $chk,
                        predicates => []};
            $func->{nsurl} = $nsurl if defined $nsurl;
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
        $i-- while exists $open->[$i-1] and $Op{$open->[$i-1]->{type}} <= ($Op{$t->[2]} || 0);
        my $child1 = {%{$open->[$i]}};
        my $child2 = {type => 'path', steps => []};
        %{$open->[$i]} = (type => $t->[2], left => $child1, right => $child2);
        push @$open, $child2;
        $t = shift @$tokens;
        $state = 'PathExpr';
      } elsif ($t->[0] eq 'Operator') {
        my $i = -1;
        $i-- while exists $open->[$i-1] and $Op{$open->[$i-1]->{type}} <= ($Op{$t->[2]} || 0);
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
            if ($open->[-1]->{type} eq 'function') {
              if (@{$open->[-1]->{args}} < $open->[-1]->{args_chk}->[0]) {
                $self->onerror->(type => 'xpath:function:min', # XXX
                                 level => 'm',
                                 index => $t->[1]);
                return undef;
              } elsif ($open->[-1]->{args_chk}->[1] < @{$open->[-1]->{args}}) {
                $self->onerror->(type => 'xpath:function:max', # XXX
                                 level => 'm',
                                 index => $t->[1]);
                return undef;
              }
              delete $open->[-1]->{args_chk};
              pop @$open;
            }
          }
        } elsif (defined $open->[-1]->{sep} and
                 $t->[0] eq $open->[-1]->{sep}) {
          delete $open->[-1]->{delim};
          delete $open->[-1]->{sep};
          delete $open->[-1]->{next};
          $t = shift @$tokens;
          my $path = {type => 'path', steps => []};
          my $expr = {type => 'expr', value => $path,
                      delim => ')', sep => ',', next => 'after Step',
                      predicates => []};
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

  $self->onerror->(type => 'xpath:syntax error', # XXX
                   index => $t->[1],
                   level => 'm');
  return undef;
} # parse_char_string_as_expression

1;

=head1 LICENSE

Copyright 2013-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
