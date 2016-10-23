package Test::XPathParser;
use strict;
use warnings;
use Carp;

our @EXPORT = qw(S Sf STR NUM VAR F ROOT LP OP NEG X);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

sub S ($$$$$) { +{type => 'step', axis => $_[0],
                  prefix => $_[1], (defined $_[2] ? (nsurl => \($_[2])) : ()),
                  local_name => $_[3],
                  predicates => $_[4]} }
sub Sf ($$$$) { +{type => 'step', axis => $_[0],
                  node_type => $_[1],
                  (defined $_[2] ? (target => $_[2]) : ()),
                  predicates => $_[3]} }
sub STR ($$) { {type => 'str', value => $_[0], predicates => $_[1]} }
sub NUM ($$) { {type => 'num', value => $_[0], predicates => $_[1]} }
sub VAR ($$$$) { +{type => 'var',
                   prefix => $_[0], (defined $_[1] ? (nsurl => \($_[1])) : ()),
                   local_name => $_[2],
                   predicates => $_[3]} }
sub F ($$$$$) { +{type => 'function',
                  prefix => $_[0], (defined $_[1] ? (nsurl => \($_[1])) : ()),
                  local_name => $_[2],
                  args => $_[3],
                  predicates => $_[4]} }
sub ROOT () { {type => 'root'} }
sub LP ($) { {type => 'path', steps => $_[0]} }
sub OP ($$$) { {type => $_[0], left => $_[1], right => $_[2]} }
sub NEG ($) { {type => 'negate', right => $_[0]} }
sub X ($;$) { {type => 'expr', value => $_[0], predicates => $_[1] || []} }

1;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
