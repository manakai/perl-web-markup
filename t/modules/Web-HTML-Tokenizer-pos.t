use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Test::HTCT::Parser;
use Web::HTML::Parser;
use Web::XML::Parser;
use Web::DOM::Document;
use Test::X1;

for my $test (
  [q{<p hoge="abc"/>} => [[1,1 => 1,10]]],
  [qq{<p hoge="abc\x0A\x00"/>} => [[1,1 => 1,10]]],
  [q{<p hoge="abc&amp;x"/>} => [[1,1 => 1,10], [1,5 => 1,18]]],
  [q{<p hoge="abc&foo;x"/>} => [[1,1 => 1,10], [1,9 => 1,18]]],
  [qq{<p hoge="abc\x0Ax\x0Ab"/>} => [[1,1 => 1,10]]],
  [qq{<p hoge="abc\x0D\x0Ax\x0Ab"/>} => [[1,1 => 1,10]]],
  [qq{<p hoge="\x0Dabc\x0Ax"/>} => [[2,0 => 2,0]]],
  [qq{<p hoge="abc&#xa;x&#xd;b"/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge="abc&#10;x&#13;b"/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],

  [q{<p hoge='abc'/>} => [[1,1 => 1,10]]],
  [qq{<p hoge='abc\x0A\x00'/>} => [[1,1 => 1,10]]],
  [q{<p hoge='abc&amp;x'/>} => [[1,1 => 1,10], [1,5 => 1,18]]],
  [q{<p hoge='abc&foo;x'/>} => [[1,1 => 1,10], [1,9 => 1,18]]],
  [qq{<p hoge='abc\x0Ax\x0Ab'/>} => [[1,1 => 1,10]]],
  [qq{<p hoge='abc\x0D\x0Ax\x0Ab'/>} => [[1,1 => 1,10]]],
  [qq{<p hoge='\x0Dabc\x0Ax'/>} => [[2,0 => 2,0]]],
  [qq{<p hoge='abc&#xa;x&#xd;b'/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge='abc&#10;x&#13;b'/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],

  [q{<p hoge= abc >} => [[1,1 => 1,10], [1,2 => 1,11]]],
  [qq{<p hoge= abc\x00 >} => [[1,1 => 1,10], [1,2 => 1,11], [1,4 => 1,13]]],
  [q{<p hoge= abc&amp;x >} => [[1,1 => 1,10], [1,2 => 1,11], [1,5 => 1,18]]],
  [q{<p hoge= abc&foo;x >} => [[1,1 => 1,10], [1,2 => 1,11], [1,9 => 1,18]]],
  [qq{<p hoge= abc&#xa;x&#xd;b >} => [[1,1 => 1,10], [1,2 => 1,11], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge= abc&#10;x&#13;b >} => [[1,1 => 1,10], [1,2 => 1,11], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->[0] => $doc);
    my $attr = $doc->body->first_element_child->attributes->[0];
    eq_or_diff $attr->get_user_data ('manakai_pos'), $test->[1];
    done $c;
  } n => 1, name => ['manakai_pos', 'html', $test->[0]];
}

for my $test (
  [q{<p hoge="abc"/>} => [[1,1 => 1,10]]],
  [qq{<p hoge="abc\x0A\x00"/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,5 => 2,1]]],
  [q{<p hoge="abc&amp;x"/>} => [[1,1 => 1,10], [1,5 => 1,18]]],
  [q{<p hoge="abc&foo;x"/>} => [[1,1 => 1,10], [1,9 => 1,18]]],
  [qq{<p hoge="abc\x0Ax\x0Ab"/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,6 => 3,0]]],
  [qq{<p hoge="abc\x0D\x0Ax\x0Ab"/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,5 => 2,1], [1,6 => 3,0]]],
  [qq{<p hoge="\x0Dabc\x0Ax"/>} => [[1,1 => 2,0], [1,5 => 3,0]]],
  [qq{<p hoge="abc&#xa;x&#xd;b"/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge="abc&#10;x&#13;b"/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],

  [q{<p hoge='abc'/>} => [[1,1 => 1,10]]],
  [qq{<p hoge='abc\x0A\x00'/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,5 => 2,1]]],
  [q{<p hoge='abc&amp;x'/>} => [[1,1 => 1,10], [1,5 => 1,18]]],
  [q{<p hoge='abc&foo;x'/>} => [[1,1 => 1,10], [1,9 => 1,18]]],
  [qq{<p hoge='abc\x0Ax\x0Ab'/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,6 => 3,0]]],
  [qq{<p hoge='abc\x0D\x0Ax\x0Ab'/>} => [[1,1 => 1,10], [1,4 => 2,0], [1,5 => 2,1], [1,6 => 3,0]]],
  [qq{<p hoge='\x0Dabc\x0Ax'/>} => [[1,1 => 2,0], [1,5 => 3,0]]],
  [qq{<p hoge='abc&#xa;x&#xd;b'/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge='abc&#10;x&#13;b'/>} => [[1,1 => 1,10], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],

  [q{<p hoge= abc />} => [[1,1 => 1,10], [1,2 => 1,11]]],
  [qq{<p hoge= abc\x00 />} => [[1,1 => 1,10], [1,2 => 1,11], [1,4 => 1,13]]],
  [q{<p hoge= abc&amp;x />} => [[1,1 => 1,10], [1,2 => 1,11], [1,5 => 1,18]]],
  [q{<p hoge= abc&foo;x />} => [[1,1 => 1,10], [1,2 => 1,11], [1,9 => 1,18]]],
  [qq{<p hoge= abc&#xa;x&#xd;b />} => [[1,1 => 1,10], [1,2 => 1,11], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
  [qq{<p hoge= abc&#10;x&#13;b />} => [[1,1 => 1,10], [1,2 => 1,11], [2,0 => 1,13], [2,1 => 1,18], [3,0 => 1,19], [3,1 => 1,24]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = Web::XML::Parser->new;
    $parser->parse_char_string ($test->[0] => $doc);
    my $attr = $doc->document_element->attributes->[0];
    eq_or_diff $attr->get_user_data ('manakai_pos'), $test->[1];
    done $c;
  } n => 1, name => ['manakai_pos', 'xml root', $test->[0]];

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = Web::XML::Parser->new;
    $parser->parse_char_string ("<q>\n$test->[0]</q>" => $doc);
    my $attr = $doc->document_element->first_element_child->attributes->[0];
    eq_or_diff $attr->get_user_data ('manakai_pos'), [map { [$_->[0],$_->[1] => 1+$_->[2],$_->[3]] } @{$test->[1]}];
    done $c;
  } n => 1, name => ['manakai_pos', 'xml non-root', $test->[0]];
}

for my $test (
  [q{"abc"} => [[1,1 => 1,2]]],
  [qq{"abc\x0A\x00"} => [[1,1 => 1,2], [1,4 => 2,0], [1,5 => 2,1]]],
  [q{"abc&amp;x"} => [[1,1 => 1,2], [1,5 => 1,10]]],
  [q{"abc&foo;x"} => [[1,1 => 1,2], [1,9 => 1,10]]],
  [qq{"abc\x0Ax\x0Ab"} => [[1,1 => 1,2], [1,4 => 2,0], [1,6 => 3,0]]],
  [qq{"abc\x0D\x0Ax\x0Ab"} => [[1,1 => 1,2], [1,4 => 2,0], [1,5 => 2,1], [1,6 => 3,0]]],
  [qq{"\x0Dabc\x0Ax"} => [[1,1 => 2,0], [1,5 => 3,0]]],
  [qq{"abc&#xa;x&#xd;b"} => [[1,1 => 1,2], [2,0 => 1,5], [2,1 => 1,10], [3,0 => 1,11], [3,1 => 1,16]]],
  [qq{"abc&#10;x&#13;b"} => [[1,1 => 1,2], [2,0 => 1,5], [2,1 => 1,10], [3,0 => 1,11], [3,1 => 1,16]]],

  [q{'abc'} => [[1,1 => 1,2]]],
  [qq{'abc\x0A\x00'} => [[1,1 => 1,2], [1,4 => 2,0], [1,5 => 2,1]]],
  [q{'abc&amp;x'} => [[1,1 => 1,2], [1,5 => 1,10]]],
  [q{'abc&foo;x'} => [[1,1 => 1,2], [1,9 => 1,10]]],
  [qq{'abc\x0Ax\x0Ab'} => [[1,1 => 1,2], [1,4 => 2,0], [1,6 => 3,0]]],
  [qq{'abc\x0D\x0Ax\x0Ab'} => [[1,1 => 1,2], [1,4 => 2,0], [1,5 => 2,1], [1,6 => 3,0]]],
  [qq{'\x0Dabc\x0Ax'} => [[1,1 => 2,0], [1,5 => 3,0]]],
  [qq{'abc&#xa;x&#xd;b'} => [[1,1 => 1,2], [2,0 => 1,5], [2,1 => 1,10], [3,0 => 1,11], [3,1 => 1,16]]],
  [qq{'abc&#10;x&#13;b'} => [[1,1 => 1,2], [2,0 => 1,5], [2,1 => 1,10], [3,0 => 1,11], [3,1 => 1,16]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = Web::XML::Parser->new;
    for my $prefix (
      q{<!DOCTYPE a[<!ATTLIST b c CDATA},
      q{<!DOCTYPE a[<!ATTLIST b c CDATA },
      q{<!DOCTYPE a[<!ATTLIST b c (x)},
      q{<!DOCTYPE a[<!ATTLIST b c (x) },
      q{<!DOCTYPE a[<!ATTLIST b c (x) #FIXED},
      q{<!DOCTYPE a[<!ATTLIST b c (x) #FIXED },
    ) {
      $parser->parse_char_string (qq{$prefix$test->[0]>]><a/>} => $doc);
      my $delta = length $prefix;
      my $attr = $doc->doctype->get_element_type_definition_node ('b')
          ->get_attribute_definition_node ('c');
      eq_or_diff $attr->get_user_data ('manakai_pos'),
          [map { [$_->[0],$_->[1] => $_->[2],($_->[2] == 1 ? $delta : 0)+$_->[3]] } @{$test->[1]}];
    }
    done $c;
  } n => 1 * 6, name => ['manakai_pos', 'attrdef default', $test->[0]];
}

for my $test (
  [q{abc} => [[1,1 => 1,1]]],
  [q{abc&amp;x} => [[1,1 => 1,1], [1,5 => 1,9]]],
  [q{abc&foo;x} => [[1,1 => 1,1], [1,9 => 1,9]]],
  [qq{abc&#xa;x&#xd;b} => [[1,1 => 1,1],
                           [2,0 => 1,4], # &#xa;
                           [2,1 => 1,9],
                           [3,0 => 1,10], # &#xd;
                           [3,1 => 1,15]]],
  [qq{abc&#10;x&#13;b} => [[1,1 => 1,1],
                           [2,0 => 1,4], # &#10;
                           [2,1 => 1,9],
                           [3,0 => 1,10], # &#x13;
                           [3,1 => 1,15]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = Web::XML::Parser->new;
    for my $prefix (
      q{<!DOCTYPE a[<!ATTLIST b c CDATA },
      q{<!DOCTYPE a[<!ATTLIST b c (x)},
      q{<!DOCTYPE a[<!ATTLIST b c (x) },
      q{<!DOCTYPE a[<!ATTLIST b c (x) #FIXED },
    ) {
      $parser->parse_char_string (qq{$prefix$test->[0]>]><a/>} => $doc);
      my $delta = length $prefix;
      my $attr = $doc->doctype->get_element_type_definition_node ('b')
          ->get_attribute_definition_node ('c');
      eq_or_diff $attr->get_user_data ('manakai_pos'),
          [map { [$_->[0],$_->[1] => $_->[2],($_->[2] == 1 ? $delta : 0)+$_->[3]] } @{$test->[1]}];
    }
    done $c;
  } n => 1 * 4, name => ['manakai_pos', 'attrdef default', $test->[0]];
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
