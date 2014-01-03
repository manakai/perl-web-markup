use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Web::DOM::Document;
use Web::HTML::Parser;

for my $test (
  ['en' => 'This is a searchable index. Enter search keywords: '],
  ['ja' => "\x{3053}\x{306e}\x{30a4}\x{30f3}\x{30c7}\x{30c3}\x{30af}\x{30b9}\x{306f}\x{691c}\x{7d22}\x{3067}\x{304d}\x{307e}\x{3059}\x{3002}\x{30ad}\x{30fc}\x{30ef}\x{30fc}\x{30c9}\x{3092}\x{5165}\x{529b}\x{3057}\x{3066}\x{304f}\x{3060}\x{3055}\x{3044}: "],
  ['ja-JP' => "\x{3053}\x{306e}\x{30a4}\x{30f3}\x{30c7}\x{30c3}\x{30af}\x{30b9}\x{306f}\x{691c}\x{7d22}\x{3067}\x{304d}\x{307e}\x{3059}\x{3002}\x{30ad}\x{30fc}\x{30ef}\x{30fc}\x{30c9}\x{3092}\x{5165}\x{529b}\x{3057}\x{3066}\x{304f}\x{3060}\x{3055}\x{3044}: "],
  ['ja-hoge' => "\x{3053}\x{306e}\x{30a4}\x{30f3}\x{30c7}\x{30c3}\x{30af}\x{30b9}\x{306f}\x{691c}\x{7d22}\x{3067}\x{304d}\x{307e}\x{3059}\x{3002}\x{30ad}\x{30fc}\x{30ef}\x{30fc}\x{30c9}\x{3092}\x{5165}\x{529b}\x{3057}\x{3066}\x{304f}\x{3060}\x{3055}\x{3044}: "],
  ['pt' => "Este \x{ed}ndice \x{e9} pesquis\x{e1}vel. Introduza palavras-chave de pesquisa: "],
  ['zh-TW' => "\x{9019}\x{662f}\x{53ef}\x{641c}\x{5c0b}\x{7684}\x{7d22}\x{5f15}\x{ff0c}\x{8f38}\x{5165}\x{641c}\x{5c0b}\x{95dc}\x{9375}\x{5b57}\x{ff1a}"],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = new Web::HTML::Parser;
    $parser->locale_tag ($test->[0]);
    $parser->onerror (sub { });
    $parser->parse_char_string (q{<isindex>} => $doc);
    is $doc->get_elements_by_tag_name ('label')->[0]->text_content, $test->[1];
    done $c;
  } n => 1, name => ['isindex', $test->[0]];
}

for my $locale (
  undef,
  '',
  'C',
  'qaa',
  'hoge',
  '!?-',
  'zh',
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    my $parser = new Web::HTML::Parser;
    $parser->locale_tag ($locale);
    $parser->onerror (sub { });
    $parser->parse_char_string (q{<isindex>} => $doc);
    is $doc->get_elements_by_tag_name ('label')->[0]->text_content,
       'This is a searchable index. Enter search keywords: ';
    done $c;
  } n => 1, name => ['isindex', 'bad or unknown value', $locale];
}

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
