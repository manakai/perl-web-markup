package Web::XPath::Evaluator;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '2.0';
use POSIX ();
use Scalar::Util qw(refaddr);

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

## Ensure that the number is a double-precision 64-bit IEEE 754
## floating point number.
sub _n ($) {
  return unpack 'd', pack 'd', $_[0];
} # _n

sub _node_set_uniq ($) {
  my $v = $_[0];
  my %found;
  @$v = grep { not $found{refaddr $_}++ } @$v;
  return $v;
} # _node_set_uniq

sub _string_value ($) {
  if ($_[0]->node_type == 9) { # DOCUMENT_NODE
    return join '',
        map { defined $_ ? $_ : '' }
        map { $_->text_content }
        grep { $_->node_type == 1 } @{$_[0]->child_nodes};
  } else {
    my $value = $_[0]->text_content;
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
        $self->onerror->(type => 'xpath:incompat with =', # XXX
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
      $self->onerror->(type => 'xpath:incompat with =', # XXX
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
    return {type => 'number', value => 0+'nan'}
        if $left->{value} eq 'nan';
    my $n = eval { $left->{value} / $right->{value} };
    if (not defined $n) {
      my $neg = $left->{value} < 0;
      if ($left->{value} == 0) {
        return {type => 'number', value => 0+'nan'};
      } elsif ((sprintf '%g', $right->{value}) =~ /^-/) {
        return {type => 'number', value => $neg ? 0+"inf" : 0+"-inf"};
      } else {
        return {type => 'number', value => $neg ? 0+"-inf" : 0+"inf"};
      }
    } else {
      return {type => 'number', value => _n ($n)};
    }
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

  '|' => sub {
    my ($self, $left, $right) = @_;
    if ($left->{type} ne 'node-set') {
      $self->onerror->(type => 'xpath:incompat with node-set', # XXX
                       level => 'm',
                       value => $left->{type});
      return undef;
    }
    if ($right->{type} ne 'node-set') {
      $self->onerror->(type => 'xpath:incompat with node-set', # XXX
                       level => 'm',
                       value => $right->{type});
      return undef;
    }
    return {type => 'node-set',
            value => _node_set_uniq [@{$left->{value}}, @{$right->{value}}],
            unordered => 1};
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
            value => not ($value->{value} eq 'nan' or
                          $value->{value} eq '-0' or ## < Perl 5.14
                          not $value->{value})};
  } elsif ($value->{type} eq 'string') {
    return {type => 'boolean', value => !!length $value->{value}};
  } else {
    $self->onerror->(type => 'xpath:incompat with boolean', # XXX
                     level => 'm',
                     value => $value->{type});
    return undef;
  }
} # to_boolean

sub to_xpath_boolean ($$) {
  return {type => 'boolean', value => !!$_[1]};
} # to_xpath_boolean

sub to_string ($$) {
  my ($self, $value) = @_;
  return $value if $value->{type} eq 'string';

  ## <http://www.w3.org/TR/xpath/#function-string>.

  if ($value->{type} eq 'node-set') {
    $self->sort_node_set ($value);
    my @node = @{$value->{value}};
    return {type => 'string',
            value => join '', map {
              _string_value $_;
            } @node};
  } elsif ($value->{type} eq 'number') {
    if ($value->{value} =~ /\A-?[Nn]a[Nn]\z/) {
      return {type => 'string', value => 'NaN'};
    } elsif ($value->{value} =~ /\A[Ii]nf\z/) {
      return {type => 'string', value => 'Infinity'};
    } elsif ($value->{value} =~ /\A-[Ii]nf\z/) {
      return {type => 'string', value => '-Infinity'};
    } else {
      my $n = $value->{value};
      for (my $i = 0; ; $i++) {
        my $f = sprintf '%.'.$i.'f', $n;
        if ($f == $n) {
          $f =~ s/0+\z//;
          $f =~ s/\.\z//;
          return {type => 'string', value => $f || '0'};
        }
      }
      die "Can't serialize |$n|";
    }
  } elsif ($value->{type} eq 'boolean') {
    return {type => 'string', value => $value->{value} ? 'true' : 'false'};
  } else {
    $self->onerror->(type => 'xpath:incompat with string', # XXX
                     level => 'm',
                     value => $value->{type});
    return undef;
  }
} # to_string

sub to_xpath_string ($$) {
  return {type => 'string', value => ''.$_[1]};
} # to_xpath_string

sub to_number ($$) {
  my ($self, $value) = @_;
  return $value if $value->{type} eq 'number';

  ## <http://www.w3.org/TR/xpath/#function-number>.

  if ($value->{type} eq 'node-set') {
    $value = $self->to_string ($value);
  }

  if ($value->{type} eq 'string') {
    if ($value->{value} =~ /\A[\x09\x0A\x0D\x20]*(-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+))[\x09\x0A\x0D\x20]*\z/) {
      my $v = {type => 'number', value => 0+$1};
      if ($v->{value} == 0 and $value->{value} =~ /\A[\x09\x0A\x0D\x20]*-/) {
        $v->{value} = 1/"-inf";
      }
      return $v;
    } else {
      return {type => 'number', value => 0+'nan'};
    }
  } elsif ($value->{type} eq 'boolean') {
    return {type => 'number', value => $value->{value} ? 1 : 0};
  } else {
    $self->onerror->(type => 'xpath:incompat with number', # XXX
                     level => 'm',
                     value => $value->{type});
    return undef;
  }
} # to_number

sub to_xpath_number ($$) {
  return {type => 'number', value => _n $_[1]};
} # to_xpath_number

sub to_string_value ($$) {
  return {type => 'string', value => _string_value $_[1]};
} # to_string_value

sub sort_node_set ($$) {
  my (undef, $node_set) = @_;
  return unless $node_set->{type} eq 'node-set';
  return unless $node_set->{unordered};
  unless (@{$node_set->{value}}) {
    delete $node_set->{unordered};
    return;
  }

  my $p = $node_set->{value}->[0]->DOCUMENT_POSITION_PRECEDING;
  my $f = $node_set->{value}->[0]->DOCUMENT_POSITION_FOLLOWING;

  $node_set->{value} = [sort {
    my $compare = $a->compare_document_position ($b);
    $compare & $p ? +1 : $compare & $f ? -1 : 0;
  } @{$node_set->{value}}];
  @{$node_set->{value}} = reverse @{$node_set->{value}}
      if $node_set->{reversed};
  delete $node_set->{unordered};
} # sort_node_set

sub to_xpath_node_set ($$) {
  return {type => 'node-set', value => _node_set_uniq [@{$_[1]}],
          unordered => 1};
} # to_xpath_node_set

sub _process_name_test ($$$$;%) {
  my ($self, $v, $step, $ctx, %args) = @_;
  my $nt = $step->{node_type};
  if (not defined $nt) {
    if ($args{attr}) {
      @$v = grep { $_->node_type == 2 } @$v; # ATTRIBUTE_NODE
    } else {
      @$v = grep { $_->node_type == 1 } @$v; # ELEMENT_NODE
    }
    if (@$v and (defined $step->{local_name} or defined $step->{prefix})) {
      @$v = grep { $_->local_name eq $step->{local_name} } @$v
          if defined $step->{local_name};

      my $nsurl;
      if (not defined $step->{prefix}) {
        if (not $args{attr} and
            ($ctx->{node}->owner_document || $ctx->{node})->manakai_is_html) {
          $nsurl = \'http://www.w3.org/1999/xhtml';
        }
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

sub _descendant ($) {
  my @node = ($_[0]);
  my @n;
  while (@node) {
    my $node = shift @node;
    push @n, $node;
    unshift @node, @{$node->child_nodes};
  }
  shift @n;
  return @n;
} # _descendant

sub _process_step ($$$$) {
  my ($self, $value, $step, $ctx) = @_;
  my $v = [];
  if ($step->{axis} eq 'child') {
    for my $n (@{$value->{value}}) {
      push @$v, @{$n->child_nodes};
    }
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'descendant' or
           $step->{axis} eq 'descendant-or-self') {
    for my $n (@{$value->{value}}) {
      push @$v, $n if $step->{axis} =~ /self\z/;
      push @$v, _descendant $n;
    }
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'parent' or
           $step->{axis} eq 'ancestor' or
           $step->{axis} eq 'ancestor-or-self') {
    for my $n (@{$value->{value}}) {
      push @$v, $n if $step->{axis} =~ /self\z/;
      my $node;
      if ($n->node_type == 2) { # ATTRIBUTE_NODE
        $node = $n->owner_element;
        push @$v, $node if defined $node;
      } else {
        $node = $n->parent_node;
        push @$v, $node if defined $node;
      }
      if ($step->{axis} =~ /^ancestor/ and $node) {
        while ($node = $node->parent_node) {
          push @$v, $node;
        }
      }
    } # $n
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'following-sibling') {
    for my $n (@{$value->{value}}) {
      my $parent = $n->parent_node or last;
      my $flag;
      for (@{$parent->child_nodes}) {
        if ($_ eq $n) {
          $flag = 1;
        } elsif ($flag) {
          push @$v, $_;
        }
      }
    } # $n
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'following') {
    for my $n (@{$value->{value}}) {
      my $m = $n;
      while ($m) {
        my $parent = $m->parent_node or last;
        my $flag;
        for (@{$parent->child_nodes}) {
          if ($_ eq $m) {
            $flag = 1;
          } elsif ($flag) {
            push @$v, $_, _descendant $_;
          }
        }
        $m = $parent;
      } # $m
    } # $n
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'preceding-sibling') {
    for my $n (@{$value->{value}}) {
      my @vv;
      my $parent = $n->parent_node or last;
      for (@{$parent->child_nodes}) {
        if ($_ eq $n) {
          last;
        } else {
          unshift @vv, $_;
        }
      }
      push @$v, @vv;
    } # $n
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'preceding') {
    for my $n (@{$value->{value}}) {
      my $m = $n;
      my @vv;
      while ($m) {
        my $parent = $m->parent_node or last;
        my @vvv;
        for (@{$parent->child_nodes}) {
          if ($_ eq $m) {
            last;
          } else {
            push @vvv, $_, _descendant $_;
          }
        }
        unshift @vv, @vvv;
        $m = $parent;
      } # $m
      push @$v, reverse @vv;
    } # $n
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'self') {
    @$v = @{$value->{value}};
    $v = $self->_process_name_test ($v, $step, $ctx);
  } elsif ($step->{axis} eq 'attribute') {
    @$v = grep { ($_->namespace_uri || '') ne q<http://www.w3.org/2000/xmlns/> } map { @{$_->attributes or []} } @{$value->{value}};
    $v = $self->_process_name_test ($v, $step, $ctx, attr => 1);
  } elsif ($step->{axis} eq 'namespace') {
    $v = [];
  } else {
    die "Axis |$step->{axis}| is not supported";
  }

  $v = _node_set_uniq $v if @{$value->{value}} > 1;

  my $node_set = {type => 'node-set', value => $v};
  $node_set->{reversed} = 1 if $step->{axis} =~ /^(?:ancestor|preceding)/;
  $node_set->{unordered} = 1 if @{$value->{value}} > 1;
  return $node_set;
} # _process_step

sub _process_predicates ($$$) {
  my ($self, $value, $step) = @_;
  for my $pred (@{$step->{predicates}}) {
    $self->sort_node_set ($value);
    my $size = @{$value->{value}} or return $value;
    my @value;
    my $pos = 1;
    for my $node (@{$value->{value}}) {
      my $result = $self->evaluate ($pred, $node,
                                    context_size => $size,
                                    context_position => $pos)
          or return undef;
      if ($result->{type} eq 'number') {
        $result = $result->{value} == $pos;
      } else {
        $result = $self->to_boolean ($result) or return undef;
        $result = $result->{value};
      }
      push @value, $node if $result;
      $pos++;
    }
    @{$value->{value}} = @value;
  } # $pred
  return $value;
} # _process_predicates

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
        $value = $self->_process_step ($value, $first_step, $op->[1]);
      } elsif ($first_step->{type} eq 'root') {
        my $node = $op->[1]->{node};
        $node = $node->parent_node while $node->parent_node;
        $value = {type => 'node-set', value => [$node]};
      } elsif ($first_step->{type} eq 'str') {
        $value = {type => 'string', value => $first_step->{value}};
      } elsif ($first_step->{type} eq 'num') {
        $value = {type => 'number', value => _n $first_step->{value}};
      } elsif ($first_step->{type} eq 'var') {
        $value = $self->variable_bindings->get_variable
            (defined $first_step->{nsurl} ? ${$first_step->{nsurl}} : undef,
             $first_step->{local_name});
        unless ($value) {
          $self->onerror->(type => 'xpath:var not defined', # XXX
                           level => 'm',
                           value => (defined $first_step->{prefix} ? $first_step->{prefix} . ':' : '') . $first_step->{local_name});
          return undef;
        }
      } elsif ($first_step->{type} eq 'function') {
        my @args;
        for (@{$first_step->{args}}) {
          my $value = $self->evaluate
              ($_, $op->[1]->{node},
               context_size => $op->[1]->{size},
               context_position => $op->[1]->{position}) or return undef;
          push @args, $value;
        }
        my $lib = $self->function_library;
        eval qq{ require $lib } or die $@;
        $value = $lib->get_code
            (defined $first_step->{nsurl} ? ${$first_step->{nsurl}} : undef,
             $first_step->{local_name})
                ->($self, \@args, $op->[1]) or return undef;
      } elsif ($first_step->{type} eq 'expr') {
        $value = $self->evaluate ($first_step, $op->[1]->{node},
                                  context_size => $op->[1]->{size},
                                  context_position => $op->[1]->{position})
            or return undef;
        if ($value->{type} eq 'node-set' and $value->{reversed}) {
          $self->sort_node_set ($value);
          @{$value->{value}} = reverse @{$value->{value}};
        }
      } else {
        die "Unknown step type: |$first_step->{type}|";
      }

      if ((@step or @{$first_step->{predicates} or []}) and
          not $value->{type} eq 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set', # XXX
                         level => 'm',
                         value => $value->{type});
        return undef;
      }

      if (@{$first_step->{predicates} or []}) {
        $value = $self->_process_predicates ($value, $first_step)
            or return undef;
      }

      while (@step) {
        my $step = shift @step;
        if ($step->{type} eq 'step') {
          my $unordered = $value->{unordered};
          $value = $self->_process_step ($value, $step, $op->[1]);
          $value->{unordered} = 1 if $unordered;
          if (@{$step->{predicates} or []}) {
            $value = $self->_process_predicates ($value, $step)
                or return undef;
          }
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

Copyright 2013-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
