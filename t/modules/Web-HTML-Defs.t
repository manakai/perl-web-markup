use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Web::HTML::Defs;

test {
  my $c = shift;
  ok EOF_CHAR;
  ok ABORT_CHAR;
  ok NEVER_CHAR;
  done $c;
} n => 3, name => 'chars';

test {
  my $c = shift;
  ok DOCTYPE_TOKEN;
  ok START_TAG_TOKEN;
  ok ABORT_TOKEN;
  ok END_OF_FILE_TOKEN;
  done $c;
} n => 4, name => 'tokens';

test {
  my $c = shift;
  ok FOREIGN_EL;
  done $c;
} n => 1, name => 'elements';

run_tests;

=head1 LICENSE

Copyright 2012-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
