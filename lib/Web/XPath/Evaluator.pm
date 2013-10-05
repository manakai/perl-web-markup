package Web::XPath::Evaluator;
use strict;
use warnings;
our $VERSION = '1.0';
use POSIX ();

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || sub {
    my %args = @_;
    warn sprintf "%s%s (%s)\n",
        $args{type}, defined $args{value} ? " ($args{value})" : '',
        $args{level};
  };
} # onerror

sub _n ($) {
  return unpack 'd', pack 'd', $_[0];
} # _n

sub _string_value ($) {
  if ($_->node_type == 9) { # DOCUMENT_NODE
    return join '',
        map { defined $_ ? $_ : '' }
        map { $_->text_content } @{$_->child_nodes};
  } else {
    my $value = $_->text_content;
    return defined $value ? $value : '';
  }
} # _string_value

my $compare = sub {
  my ($n_eq, $s_eq) = @_;
  return sub {
    my ($self, $left, $right) = @_;

    if ($left->{type} eq 'node-set' and $right->{type} eq 'node-set') {
      for my $ln (@{$left->{value}}) {
        my $ls = _string_value $ln;
        for my $rn (@{$right->{value}}) {
          my $rs = _string_value $rn;
          if ($s_eq->($ls, $rs)) {
            return {type => 'boolean', value => 1};
          }
        }
      }
      return {type => 'boolean', value => 0};
    } elsif ($left->{type} eq 'node-set' or $right->{type} eq 'node-set') {
      ($left, $right) = ($right, $left) if $right->{type} eq 'node-set';
      if ($right->{type} eq 'number') {
        for my $ln (@{$left->{value}}) {
          if ($n_eq->($self->to_number ({type => 'string',
                                         value => _string_value $ln})->{value},
                      $right->{value})) {
            return {type => 'boolean', value => 1};
          }
        }
        return {type => 'boolean', value => 0};
      } elsif ($right->{type} eq 'string') {
        for my $ln (@{$left->{value}}) {
          if ($s_eq->((_string_value $ln), $right->{value})) {
            return {type => 'boolean', value => 1};
          }
        }
        return {type => 'boolean', value => 0};
      } elsif ($right->{type} eq 'boolean') {
        return {type => 'boolean',
                value => $s_eq->(!!$self->to_boolean ($left)->{value}, !!$right->{value})};
      } else {
        $self->onerror (type => 'xpath:incompat type', # XXX
                        level => 'm',
                        value => $right->{type});
        return undef;
      }
    } elsif ($left->{type} eq 'boolean' or $right->{type} eq 'boolean') {
      $left = $self->to_boolean ($left) or return undef;
      $right = $self->to_boolean ($right) or return undef;
      return {type => 'boolean',
              value => $s_eq->(!!$left->{value}, !!$right->{value})};
    } elsif ($left->{type} eq 'number' or $right->{type} eq 'number') {
      $left = $self->to_number ($left) or return undef;
      $right = $self->to_number ($right) or return undef;
      return {type => 'boolean',
              value => $n_eq->($left->{value}, $right->{value})};
    } elsif ($left->{type} eq 'string' or $right->{type} eq 'string') {
      $left = $self->to_string ($left) or return undef;
      $right = $self->to_string ($right) or return undef;
      return {type => 'boolean',
              value => $s_eq->($left->{value}, $right->{value})};
    } else {
      my $type = $left->{type};
      $type = $right->{type} if $type eq 'string' or
                                $type eq 'number' or
                                $type eq 'boolean';
      $self->onerror (type => 'xpath:incompat type', # XXX
                      level => 'm',
                      value => $type);
      return undef;
    }
  };
}; # $compare

my %Op = (
  '+' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'number',
            value => _n ($left->{value} + $right->{value})};
  },
  '-' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'number',
            value => _n ($left->{value} - $right->{value})};
  },
  '*' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'number',
            value => _n ($left->{value} * $right->{value})};
  },
  'div' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'number',
            value => _n ($left->{value} / $right->{value})};
  },
  'mod' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'number',
            value => _n (POSIX::fmod ($left->{value}, $right->{value}))};
  },

  '<' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'boolean',
            value => $left->{value} < $right->{value}};
  },
  '<=' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'boolean',
            value => $left->{value} <= $right->{value}};
  },
  '>' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'boolean',
            value => $left->{value} > $right->{value}};
  },
  '>=' => sub {
    my $self = $_[0];
    my $left = $self->to_number ($_[1]) or return undef;
    my $right = $self->to_number ($_[2]) or return undef;
    return {type => 'boolean',
            value => $left->{value} >= $right->{value}};
  },

  '=' => $compare->(sub { $_[0] == $_[1] }, sub { $_[0] eq $_[1] }),
  '!=' => $compare->(sub { $_[0] != $_[1] }, sub { $_[0] ne $_[1] }),

  'or' => sub {
    my $self = $_[0];
    my $left = $self->to_boolean ($_[1]) or return undef;
    my $right = $self->to_boolean ($_[2]) or return undef;
    return {type => 'boolean', value => $left->{value} || $right->{value}};
  },
  'and' => sub {
    my $self = $_[0];
    my $left = $self->to_boolean ($_[1]) or return undef;
    my $right = $self->to_boolean ($_[2]) or return undef;
    return {type => 'boolean', value => $left->{value} && $right->{value}};
  },
); # %Op

sub to_boolean ($$) {
  my ($self, $value) = @_;
  return $value if $value->{type} eq 'boolean';

  ## <http://www.w3.org/TR/xpath/#function-boolean>.

  if ($value->{type} eq 'node-set') {
    return {type => 'boolean', value => !!@{$value->{value}}};
  } elsif ($value->{type} eq 'number') {
    return {type => 'boolean',
            value => not ($value->{value} eq 'nan' or not $value->{value})};
  } elsif ($value->{type} eq 'string') {
    return {type => 'boolean', value => !!length $value->{value}};
  } else {
    $self->onerror (type => 'xpath:incompat type', # XXX
                    level => 'm',
                    value => $value->{type});
    return undef;
  }
} # to_boolean

sub to_string ($$) {
  my ($self, $value) = @_;
  return $value if $value->{type} eq 'string';

  ## <http://www.w3.org/TR/xpath/#function-string>.

  if ($value->{type} eq 'node-set') {
    my @node = sort {
      0; # XXX sort by document order
    } @{$value->{value}};
    return {type => 'string',
            value => join '', map {
              _string_value $_;
            } @node};
  } elsif ($value->{type} eq 'number') {
    if ($value->{value} eq 'nan') {
      return {type => 'string', value => 'NaN'};
    } elsif ($value->{value} eq 'inf') {
      return {type => 'string', value => 'Infinity'};
    } elsif ($value->{value} eq '-inf') {
      return {type => 'string', value => '-Infinity'};
    } else {
      my $n = $value->{value};
      for (my $i = 0; ; $i++) {
        my $f = sprintf '%.'.$i.'f', $n;
        if ($f == $n) {
          $f =~ s/0+\z//;
          $f =~ s/\.\z//;
          return {type => 'string', value => $f};
        }
      }
      die "Can't serialize |$n|";
    }
  } elsif ($value->{type} eq 'boolean') {
    return {type => 'string', value => $value->{value} ? 'true' : 'false'};
  } else {
    $self->onerror (type => 'xpath:incompat type', # XXX
                    level => 'm',
                    value => $value->{type});
    return undef;
  }
} # to_string

sub to_number ($$) {
  my ($self, $value) = @_;
  return $value if $value->{type} eq 'number';

  ## <http://www.w3.org/TR/xpath/#function-number>.

  if ($value->{type} eq 'node-set') {
    $value = $self->to_string ($value);
  }

  if ($value->{type} eq 'string') {
    if ($value->{value} =~ /\A[\x09\x0A\x0D\x20]*(-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+))[\x09\x0A\x0D\x20]*\z/) {
      return {type => 'number', value => 0+$1};
    } else {
      return {type => 'number', value => 0+'nan'};
    }
  } elsif ($value->{type} eq 'boolean') {
    return {type => 'number', value => $value->{value} ? 1 : 0};
  } else {
    $self->onerror (type => 'xpath:incompat type', # XXX
                    level => 'm',
                    value => $value->{type});
    return undef;
  }
} # to_number

sub _process_name_test ($$$) {
  my ($self, $v, $step) = @_;
  my $nt = $step->{node_type};
  if (not defined $nt) {
    @$v = grep { $_->node_type == 1 } @$v;
    if (defined $step->{local_name} or defined $step->{prefix}) {
      @$v = grep { $_->local_name eq $step->{local_name} } @$v
          if defined $step->{local_name};

      my $nsurl;
      if (not defined $step->{prefix}) {
        # XXX
      } else {
        $nsurl = $step->{nsurl};
      }
      if (defined $nsurl) {
        @$v = grep { my $ns = $_->namespace_uri;
                     defined $ns && $ns eq $$nsurl } @$v;
      } else {
        @$v = grep { not defined $_->namespace_uri } @$v;
      }
    }
  } elsif ($nt eq 'node') {
    #
  } elsif ($nt eq 'text' or $nt eq 'comment' or
           $nt eq 'processing-instruction') {
    my $t = {text => 3, comment => 8, 'processing-instruction' => 7}->{$nt};
    @$v = grep { $_->node_type == $t } @$v;
    @$v = grep { $_->node_name eq $step->{target} } @$v
        if defined $step->{target};
  } else {
    die "Node type |$nt| is not defined";
  }
  return $v;
} # _process_name_test

sub _process_step ($$$) {
  my ($self, $value, $step) = @_;
  my $v = [];
  if ($step->{axis} eq 'child') {
    for my $n (@{$value->{value}}) {
      push @$v, @{$n->child_nodes};
    }
    $v = $self->_process_name_test ($v, $step);

# XXX
  } else {
    die "Axis |$step->{axis}| is not supported";
  }

  # XXX uniquness

  # XXX predicate
  
  return {type => 'node-set', value => $v};
} # _process_step

sub evaluate ($$$;%) {
  my ($self, $expr, $context_node, %args) = @_;
  return undef unless defined $expr;

  my @op = ([$expr, {node => $context_node,
                     size => $args{context_size} || 1,
                     position => $args{context_position} || 1}]);
  my @value;
  while (@op) {
    my $op = shift @op;
    if ($op->[0]->{type} eq 'expr') {
      unshift @op, [$op->[0]->{value}, $op->[1]];
    } elsif ($op->[0]->{type} eq 'path') {
      my @step = @{$op->[0]->{steps}};
      my $value = {type => 'node-set', value => [$op->[1]->{node}]};
      my $first_step = shift @step;
      if ($first_step->{type} eq 'step') {
        $value = $self->_process_step ($value, $first_step);
      } elsif ($first_step->{type} eq 'root') {
        my $node = $op->[1]->{node};
        $node = $node->owner_document || $node; # XXX
        $value = {type => 'node-set', value => [$node]};
      } elsif ($first_step->{type} eq 'str') {
        $value = {type => 'string', value => $first_step->{value}};
      } elsif ($first_step->{type} eq 'num') {
        $value = {type => 'number', value => _n $first_step->{value}};
      } elsif ($first_step->{type} eq 'var') {
        # XXX
      } elsif ($first_step->{type} eq 'function') {
        # XXX
      } elsif ($first_step->{type} eq 'expr') {
        $value = $self->evaluate ($first_step, $op->[1]->{node},
                                  context_size => $op->[1]->{size},
                                  context_position => $op->[1]->{position});
      } else {
        die "Unknown step type: |$first_step->{type}|";
      }

      if (@step and not $value->{type} eq 'node-set') {
        # XXX
      }

      while (@step) {
        my $step = shift @step;
        if ($step->{type} eq 'step') {
          $value = $self->_process_step ($value, $step);
        } else {
          die "Unknown step type: |$step->{type}|";
        }
      }

      push @value, $value;
    } elsif ($op->[0]->{type} eq 'negate') {
      unshift @op,
          [$op->[0]->{right}, $op->[1]],
          [{type => '1-negate'}];
    } elsif ($op->[0]->{type} eq '2') {
      my $right = pop @value or die "No |right|";
      my $left = pop @value or die "No |left|";

      my $code = $Op{$op->[0]->{operation}}
          or die "Unknown operation |$op->[0]->{operation}|";
      my $value = $code->($self, $left, $right);
      return undef unless defined $value;
      push @value, $value;
    } elsif ($op->[0]->{type} eq '1-negate') {
      my $right = pop @value or die "No |right|";
      $right = $self->to_number ($right) or return undef;
      my $value = {type => 'number', value => _n -$right->{value}};
      push @value, $value;
    } elsif ($op->[0]->{type} eq 'and') {
      unshift @op,
          [$op->[0]->{left}, $op->[1]],
          [{type => 'and-left'}],
          [$op->[0]->{right}, $op->[1]],
          [{type => '2', operation => $op->[0]->{type}}];
    } elsif ($op->[0]->{type} eq 'or') {
      unshift @op,
          [$op->[0]->{left}, $op->[1]],
          [{type => 'or-left'}],
          [$op->[0]->{right}, $op->[1]],
          [{type => '2', operation => $op->[0]->{type}}];
    } elsif ($op->[0]->{type} eq 'and-left') {
      my $value = pop @value;
      $value = $self->to_boolean ($value);
      unless ($value->{value}) { # and's left-hand side is false
        shift @op; # right
        shift @op; # 2
      }
      push @value, $value;
    } elsif ($op->[0]->{type} eq 'or-left') {
      my $value = pop @value;
      $value = $self->to_boolean ($value);
      if ($value->{value}) { # or's left-hand side is true
        shift @op; # right
        shift @op; # 2
      }
      push @value, $value;
    } elsif ($op->[0]->{left} and $op->[0]->{right}) {
      unshift @op,
          [$op->[0]->{left}, $op->[1]],
          [$op->[0]->{right}, $op->[1]],
          [{type => '2', operation => $op->[0]->{type}}];
    } else {
      die "Unknown operation |$op->[0]->{type}|";
    }
  } # @op

  die unless @value == 1;
  return $value[0];
} # evaluate

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
