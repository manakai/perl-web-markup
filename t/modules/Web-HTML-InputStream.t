use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::HTML::InputStream;

for my $test (
  [q{<hoge>} => undef],
  [q{<meta charset=euc-JP>} => 'euc-jp'],
  [q{<!--<meta charset=utf-8>--><meta charset  =  shift-jis>} => 'shift_jis'],
  [q{<!--><meta   Charset = "ISO-8859-1">} => 'windows-1252'],
  [qq{<meta\ncharset=  'tis-620'>} => 'windows-874'],
  [q{<meta content=text/html;charset=us-ascii http-equiv="Content-Type">} => 'windows-1252'],
  [q{<meta http-equiv=Content-type content=;charset=iso-8859-2>} => 'iso-8859-2'],
  [q{<meta http-equiv=content-style-type content="text/html;charset=us-ascii">} => undef],
  [q{<meta charset=us-ascii><meta charset=utf-8>} => 'windows-1252'],
  [q{<meta charset=utf-16LE>} => 'utf-8'],
  [q{<meta charset=utf-16be>} => 'utf-8'],
  [q{<meta charset=utf-16>} => 'utf-8'],
  [q{<meta charset=utf-8 charset=shift_jis>} => 'utf-8'],
  [q{<meta charset=utf-8 http-equiv=content-type content="text/html; charset=us-ascii">} => 'utf-8'],
  [q{<meta http-equiv=content-type charset=us-ascii content="text/html; charset=tis-620">} => 'windows-1252'],
  [q{<meta charset="us-ascii>} => undef],
  [q{<meta charset=us-ascii} => undef],
  [q{</meta charset=us-ascii>} => undef],
  [q{<?<meta charset=us-ascii>} => undef],
  [q{<?<meta charset=us-ascii><meta  charset=utf-8>} => 'utf-8'],
  [q{</hoge></meta charset=utf-8><meta charset=us-ascii>} => 'windows-1252'],
  [q{<meta charset=hoge> <meta charset=utf-16>} => 'utf-8'],
  [q{<meta content="text/html; charset=utf-8">} => undef],
  [q{<meta charset=us-ascii http-equiv=content-script-type>} => 'windows-1252'],
  [q{<meta content="text/html; charset=tis-620" charset=us-ascii http-equiv=content-script-type>} => 'windows-1252'],
) {
  test {
    my $c = shift;

    my $parser = Web::HTML::InputStream->new;
    is $parser->_prescan_byte_stream ($test->[0]), $test->[1];

    done $c;
  } n => 1, name => ['_prescan_byte_stream', $test->[0]];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
