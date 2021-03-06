package Web::XPath::FunctionLibrary;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '1.0';
use POSIX ();

## Core function library <http://www.w3.org/TR/xpath/#corelib>.

sub _round ($) {
  my $v1 = POSIX::ceil ($_[0]);
  my $v2 = POSIX::floor ($_[0]);
  return ((($v1 - $_[0]) <= ($_[0] - $v2)) ? $v1 : $v2);
} # _round

my $Functions = {
  last => {
    args => [0, 0],
    code => sub {
      my ($self, $args, $ctx) = @_;
      return {type => 'number', value => $ctx->{size}};
    },
  }, # last
  position => {
    args => [0, 0],
    code => sub {
      my ($self, $args, $ctx) = @_;
      return {type => 'number', value => $ctx->{position}};
    },
  }, # position
  count => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      if ($args->[0]->{type} ne 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set',
                         level => 'm',
                         value => $args->[0]->{type});
        return undef;
      }
      return {type => 'number', value => scalar @{$args->[0]->{value}}};
    },
  }, # count
  id => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my %id;
      if ($args->[0]->{type} eq 'node-set') {
        for (@{$args->[0]->{value}}) {
          for (split /[\x09\x0A\x0D\x20]+/, $self->to_string_value ($_)->{value}) {
            $id{$_} = 1;
          }
        }
      } else {
        my $value = $self->to_string ($args->[0]) or return undef;
        %id = map { $_ => 1 } split /[\x09\x0A\x0D\x20]+/, $value->{value};
      }
      delete $id{''};

      my $node = $ctx->{node};
      $node = $node->parent_node while $node->parent_node;
      if ($node->node_type == 9) { # DOCUMENT_NODE
        return {type => 'node-set',
                value => [grep { defined $_ } map { $node->get_element_by_id ($_) } keys %id],
                unordered => 1};
      } else {
        # /descendant-or-self()/*[id() = ?][position() = 1]
        my @node;
        my @n = ($node);
        while (@n) {
          my $n = shift @n;
          if ($n->node_type == 1) { # ELEMENT_NODE
            if ($id{$n->id}) {
              push @node, $n;
              delete $id{$n->id};
            }
          } else {
            unshift @n, @{$n->child_nodes};
          }
        }
        return {type => 'node-set', value => \@node, unordered => 1};
      }
    },
  }, # id
  'local-name' => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $node;
      if (not $args->[0]) {
        $node = $ctx->{node};
      } elsif ($args->[0]->{type} ne 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set',
                         level => 'm',
                         value => $args->[0]->{type});
        return undef;
      } else {
        $self->sort_node_set ($args->[0]);
        $node = $args->[0]->{value}->[0]
            or return {type => 'string', value => ''};
      }
      if ($node->node_type == 7) { # PROCESSING_INSTRUCTION_NODE
        return {type => 'string', value => $node->target};
      } else {
        my $n = $node->local_name;
        return {type => 'string', value => defined $n ? $n : ''};
      }
    },
  }, # local-name
  'namespace-uri' => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $node;
      if (not $args->[0]) {
        $node = $ctx->{node};
      } elsif ($args->[0]->{type} ne 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set',
                         level => 'm',
                         value => $args->[0]->{type});
        return undef;
      } else {
        $self->sort_node_set ($args->[0]);
        $node = $args->[0]->{value}->[0]
            or return {type => 'string', value => ''};
      }
      my $n = $node->namespace_uri;
      return {type => 'string', value => defined $n ? $n : ''};
    },
  }, # namespace-uri
  name => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $node;
      if (not $args->[0]) {
        $node = $ctx->{node};
      } elsif ($args->[0]->{type} ne 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set',
                         level => 'm',
                         value => $args->[0]->{type});
        return undef;
      } else {
        $self->sort_node_set ($args->[0]);
        $node = $args->[0]->{value}->[0]
            or return {type => 'string', value => ''};
      }
      my $nt = $node->node_type;
      if ($nt == 1) { # ELEMENT_NODE
        return {type => 'string', value => $node->manakai_tag_name};
      } elsif ($nt == 2) { # ATTRIBUTE_NODE
        return {type => 'string', value => $node->name};
      } elsif ($nt == 7) { # PROCESSING_INSTRUCTION_NODE
        return {type => 'string', value => $node->target};
      } else {
        return {type => 'string', value => ''};
      }
    },
  }, # name

  string => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      if (@$args) {
        return $self->to_string ($args->[0]); # or undef;
      } else {
        return $self->to_string ({type => 'node-set', value => [$ctx->{node}]});
      }
    },
  }, # string
  concat => {
    args => [2, 0+'inf'],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my @s;
      for (@$args) {
        push @s, $self->to_string ($_) or return undef;
      }
      return {type => 'string', value => join '', map { $_->{value} } @s};
    },
  }, # concat
  'starts-with' => {
    args => [2, 2],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $s2 = $self->to_string ($args->[1]) or return undef;
      return {type => 'boolean',
              value => substr ($s1->{value}, 0, length $s2->{value}) eq $s2->{value}};
    },
  }, # starts-with
  contains => {
    args => [2, 2],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $s2 = $self->to_string ($args->[1]) or return undef;
      return {type => 'boolean',
              value => index ($s1->{value}, $s2->{value}) > -1};
    },
  }, # contains
  'substring-before' => {
    args => [2, 2],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $s2 = $self->to_string ($args->[1]) or return undef;
      my $vv = [length $s2->{value}
                    ? split /\Q$s2->{value}\E/, $s1->{value}, 2
                    : ('', '...')];
      return {type => 'string',
              value => @$vv == 2 ? $vv->[0] : ''};
    },
  }, # substring-before
  'substring-after' => {
    args => [2, 2],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $s2 = $self->to_string ($args->[1]) or return undef;
      my $v = [length $s2->{value}
                   ? split /\Q$s2->{value}\E/, $s1->{value}, 2
                   : ('', $s1->{value})]->[1];
      return {type => 'string',
              value => defined $v ? $v : ''};
    },
  }, # substring-after
  substring => {
    args => [2, 3],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $n1 = $self->to_number ($args->[1]) or return undef;
      my $n2 = $args->[2] ? $self->to_number ($args->[2]) || return undef : undef;
      $n1 = -1 + _round $n1->{value};
      return {type => 'string', value => ''} if $n1 eq '-Inf' or $n1 eq '-inf';
      if (defined $n2) {
        $n2 = $n1 + _round $n2->{value};
        $n2 = 1 if $n2 < 1;
        $n1 = 0 if $n1 < 0;
        $n2 = $n2 - $n1;
        $n2 = undef if $n2 eq 'Inf' or $n2 eq 'inf';
      } else {
        $n1 = 0 if $n1 < 0;
      }
      if ($s1->{value} =~ /[\x{10000}-\x{10FFFF}]/) {
        my $text = ($ctx->{node}->owner_document || $ctx->{node})
            ->create_text_node ($s1->{value});
        my $max = $text->length - $n1;
        $n2 = $max if not defined $n2 or $n2 > $max;
        return {type => 'string',
                value => $text->substring_data ($n1, $n2)};
      } else {
        return {type => 'string',
                value => defined $n2 ? substr $s1->{value}, $n1, $n2
                                     : substr $s1->{value}, $n1};
      }
    },
  }, # substring
  'string-length' => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $value;
      if (@$args) {
        $value = $self->to_string ($args->[0]) or return undef;
      } else {
        $value = $self->to_string ({type => 'node-set', value => [$ctx->{node}]});
      }
      if ($value->{value} =~ /[\x{10000}-\x{10FFFF}]/) {
        return {type => 'number',
                value => ($ctx->{node}->owner_document || $ctx->{node})
                    ->create_text_node ($value->{value})->length};
      } else {
        return {type => 'number', value => length $value->{value}};
      }
    },
  }, # string-length
  'normalize-space' => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $value;
      if (@$args) {
        $value = $self->to_string ($args->[0]) or return undef;
      } else {
        $value = $self->to_string ({type => 'node-set', value => [$ctx->{node}]});
      }
      return $value unless $value->{value} =~ /[\x09\x0A\x0D\x20]/;
      my $v = $value->{value};
      $v =~ s/[\x09\x0A\x0D\x20]+/ /g;
      $v =~ s/\A //;
      $v =~ s/ \z//;
      return {type => 'string', value => $v};
    },
  }, # normalize-space
  translate => {
    args => [3, 3],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $s2 = $self->to_string ($args->[1]) or return undef;
      my $s3 = $self->to_string ($args->[2]) or return undef;
      return $s1 unless length $s2->{value};
      my $pattern = qr/[\Q$s2->{value}\E]/;
      return $s1 unless $s1->{value} =~ /$pattern/;
      my @s2 = split //, $s2->{value};
      my @s3 = split //, $s3->{value};
      my %map;
      for (reverse 0..$#s2) {
        $map{$s2[$_]} = defined $s3[$_] ? $s3[$_] : '';
      }
      $s1 = $s1->{value};
      $s1 =~ s/($pattern)/$map{$1}/g;
      return {type => 'string', value => $s1};
    },
  }, # translate

  boolean => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      return $self->to_boolean ($args->[0]); # or undef
    },
  }, # boolean
  not => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $b1 = $self->to_boolean ($args->[0]) or return undef;
      return {type => 'boolean', value => !$b1->{value}};
    },
  }, # not
  true => {
    args => [0, 0],
    code => sub {
      #my ($self, $args, $ctx) = @_;
      return {type => 'boolean', value => 1};
    },
  }, # true
  false => {
    args => [0, 0],
    code => sub {
      #my ($self, $args, $ctx) = @_;
      return {type => 'boolean', value => 0};
    },
  }, # false
  lang => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $s1 = $self->to_string ($args->[0]) or return undef;
      my $lang;
      my $node = $ctx->{node};
      while ($node) {
        if ($node->node_type == 1) { # ELEMENT_NODE
          $lang = $node->get_attribute_ns
              ('http://www.w3.org/XML/1998/namespace', 'lang');
          last if defined $lang;
        }
        $node = $node->parent_node;
      }
      return {type => 'boolean', value => 0} unless defined $lang;
      $lang =~ tr/A-Z/a-z/; ## ASCII case-insensitively.
      my $sv = $s1->{value};
      $sv =~ tr/A-Z/a-z/; ## ASCII case-insensitively.
      return {type => 'boolean',
              value => ($lang eq $sv or
                        substr ($lang, 0, 1 + length $sv) eq ($sv . '-'))};
    },
  }, # lang

  number => {
    args => [0, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      if (@$args) {
        return $self->to_number ($args->[0]); # or undef;
      } else {
        return $self->to_number ({type => 'node-set', value => [$ctx->{node}]});
      }
    },
  }, # number
  sum => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      if ($args->[0]->{type} ne 'node-set') {
        $self->onerror->(type => 'xpath:incompat with node-set',
                         level => 'm',
                         value => $args->[0]->{type});
        return undef;
      }
      my $n = 0;
      for (@{$args->[0]->{value}}) {
        $n += $self->to_number ($self->to_string_value ($_))->{value};
      }
      return $self->to_xpath_number ($n);
    },
  }, # sum
  floor => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $n1 = $self->to_number ($args->[0]) or return undef;
      return $self->to_xpath_number (POSIX::floor ($n1->{value}));
    },
  }, # floor
  ceiling => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $n1 = $self->to_number ($args->[0]) or return undef;
      return $self->to_xpath_number (POSIX::ceil ($n1->{value}));
    },
  }, # ceiling
  round => {
    args => [1, 1],
    code => sub {
      my ($self, $args, $ctx) = @_;
      my $n1 = $self->to_number ($args->[0]) or return undef;
      return $self->to_xpath_number (_round $n1->{value});
    },
  }, # round
}; # $Functions

sub get_argument_number ($$$) {
  my (undef, $nsurl, $ln) = @_;
  return undef if defined $nsurl;
  return undef unless $Functions->{$ln};
  return $Functions->{$ln}->{args};
} # get_argument_number

sub get_code ($$$) {
  my (undef, $nsurl, $ln) = @_;
  return undef if defined $nsurl;
  return undef unless $Functions->{$ln};
  return $Functions->{$ln}->{code};
} # get_code

1;

=head1 LICENSE

Copyright 2013-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
