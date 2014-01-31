package test::Web::HTML::Parser;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Web::HTML::Parser;
use Web::DOM::Implementation;
use Web::DOM::Document;

sub _html_parser_srcdoc : Test(3) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_srcdoc (1);

  Web::HTML::Parser->parse_char_string (q<<p>abc</p>> => $doc);

  ok $doc->manakai_is_html;
  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';
} # _html_parser_srcdoc

sub _html_parser_change_the_encoding_char_string : Test(4) {
  my $parser = Web::HTML::Parser->new;
  my $called = 0;
  $parser->onerror (sub {
    my %args = @_;
    $called = 1 if $args{type} eq 'charset label detected';
  });
  
  my $doc = new Web::DOM::Document;
  $parser->parse_char_string ('<meta charset=shift_jis>' => $doc);
  ok !$called;
  is $doc->input_encoding, 'utf-8';
  
  my $doc2 = new Web::DOM::Document;
  $parser->parse_char_string ('<meta http-equiv=Content-Type content="text/html; charset=shift_jis">' => $doc2);
  ok !$called;
  is $doc2->input_encoding, 'utf-8';
} # _html_parser_change_the_encoding_char_string

sub _html_parser_change_the_encoding_fragment : Test(2) {
  my $parser = Web::HTML::Parser->new;
  my $called = 0;
  $parser->onerror (sub {
    my %args = @_;
    $called = 1 if $args{type} eq 'charset label detected';
  });
  
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element_ns (undef, [undef, 'div']);

  $parser->parse_char_string_with_context
      ('<meta charset=shift_jis>', $el, Web::DOM::Document->new);
  ok !$called;

  $parser->parse_char_string_with_context
      ('<meta http-equiv=content-type content="text/html; charset=shift_jis">',
       $el, Web::DOM::Document->new);
  ok !$called;
} # _html_parser_change_the_encoding_fragment

sub _html_parser_change_the_encoding_byte_string : Test(64) {
  my $dom = Web::DOM::Implementation->new;

  for my $input (
    '<meta charset=shift_jis>',
    '<meta http-equiv=Content-Type content="text/html; charset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html; charsetcharset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html; charset.charset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html; charset-edition=1997;charset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html; charset=shift_jis;charset=euc-jp">',
    '<meta http-equiv=Content-Type content="text/html; charset  charset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html; charset = shift_jis">',
    '<meta http-equiv="Content-Type" content="text/html; charset=shift_jis">',
    '<meta http-equiv=Content-Type content="text/html;charset=shift_jis">',
    '<meta http-equiv=Content-Type content=text/html; charset=shift_jis>',
    '<meta http-equiv=CONTENT-TYPE content="TEXT/HTML; CHARSET=shift_jis">',
    '<meta content="text/html; charset=shift_jis" http-equiv="content-type">',
    '<body><meta http-equiv="Content-Type" content="text/html; charset=shift_jis">',
    '<meta http-equiv=content-type content="application/xhtml+xml; charset=shift_jis">',
    '<meta http-equiv=content-type content="charset=shift_jis">',
  ) {
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      undef $called;
      $parser->parse_byte_string (undef, (' ' x 1024) . $input => $doc);
      ok $called, $input; # prescan fails but parser detects <meta charset>
      is $doc->input_encoding, 'shift_jis';
    }
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      undef $called;
      $parser->parse_byte_string (undef, $input => $doc);
      ok !$called; # prescan detects <meta charset>
      is $doc->input_encoding, 'shift_jis';
    }
  }
} # _html_parser_change_the_encoding_byte_string

sub _html_parser_change_the_encoding_byte_string_changed : Test(96) {
  my $dom = Web::DOM::Implementation->new;

  for (
    ['<meta charset=shift_jis>' => 'shift_jis'],
    ['<meta charset=euc-jp>' => 'euc-jp'],
    ['<meta charset=iso-2022-jp>' => 'iso-2022-jp'],
    ['<meta charset=utf-8>' => 'utf-8'],
    ['<meta charset=utf-16>' => 'utf-8'],
    ['<meta charset=utf-16be>' => 'utf-8'],
    ['<meta charset=utf-16le>' => 'utf-8'],

    ['<meta http-equiv=content-type content="text/html; charset=euc-jp">' => 'euc-jp'],
    ['<meta http-equiv=content-type content="text/html; charset=utf-8">' => 'utf-8'],
    ['<meta http-equiv=content-type content="text/html; charset=utf-16">' => 'utf-8'],
    ['<meta http-equiv=content-type content="text/html; charset=utf-16be">' => 'utf-8'],
    ['<meta http-equiv=content-type content="text/html; charset=utf-16le">' => 'utf-8'],

    ['<p><meta charset=shift_jis>' => 'shift_jis'],
    ['<p><meta charset=euc-jp>' => 'euc-jp'],
    ['<p><meta charset=iso-2022-jp>' => 'iso-2022-jp'],
    ['<p><meta charset=utf-8>' => 'utf-8'],
    ['<p><meta charset=utf-16>' => 'utf-8'],
    ['<p><meta charset=utf-16be>' => 'utf-8'],
    ['<p><meta charset=utf-16le>' => 'utf-8'],

    ['<p><meta http-equiv=content-type content="text/html; charset=euc-jp">' => 'euc-jp'],
    ['<p><meta http-equiv=content-type content="text/html; charset=utf-8">' => 'utf-8'],
    ['<p><meta http-equiv=content-type content="text/html; charset=utf-16">' => 'utf-8'],
    ['<p><meta http-equiv=content-type content="text/html; charset=utf-16be">' => 'utf-8'],
    ['<p><meta http-equiv=content-type content="text/html; charset=utf-16le">' => 'utf-8'],
  ) {
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string (undef, (' ' x 1024) . $_->[0] => $doc);
      ok $called;
      is $doc->input_encoding, $_->[1];
    }
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string (undef, $_->[0] => $doc);
      ok !$called;
      is $doc->input_encoding, $_->[1];
    }
  }
} # _html_parser_change_the_encoding_byte_string_changed

sub _html_parser_change_the_encoding_byte_string_not_called : Test(56) {
  my $dom = Web::DOM::Implementation->new;

  for my $input (
    '',
    '<meta content=shift_jis>',
    '<meta content="text/html; charset=shift_jis">',
    '<meta name=content-type content="text/html; charset=shift_jis">',
    '<meta http-equiv=content-style-type content="text/html; charset=shift_jis">',
    '<meta http-equiv=content_type content="text/html; charset=shift_jis">',

    '<meta charset=ebcdic>',
    '<meta http-equiv=content-type content="text/html; charset=ebcdic">',
    '<meta charset=utf-7>',
    '<meta http-equiv=content-type content="text/html; charset=utf-7">',
    '<meta charset=utf-1>',
    '<meta http-equiv=content-type content="text/html; charset=utf-1">',
    '<meta charset=unicode>',
    '<meta http-equiv=content-type content="text/html; charset=unicode">',
  ) {
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string (undef, (' ' x 1024) . $input => $doc);
      ok !$called;
      like $doc->input_encoding, qr[windows-1252|us-ascii];
    }
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string (undef, $input => $doc);
      ok !$called;
      like $doc->input_encoding, qr[windows-1252|us-ascii];
    }
  }
} # _html_parser_change_the_encoding_byte_string_not_called

sub _html_parser_change_the_encoding_byte_string_with_charset : Test(4) {
  my $dom = Web::DOM::Implementation->new;

  for my $input (
    '<meta http-equiv=content-type content="text/html; charset=shift_jis">',
  ) {
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string ('euc-jp', (' ' x 1024) . $input => $doc);
      ok !$called;
      is $doc->input_encoding, 'euc-jp';
    }
    {
      my $parser = Web::HTML::Parser->new;
      my $called = 0;
      $parser->onerror (sub {
        my %args = @_;
        $called = 1 if $args{type} eq 'charset label detected';
      });
      my $doc = $dom->create_document;
      $parser->parse_byte_string ('euc-jp', $input => $doc);
      ok !$called;
      is $doc->input_encoding, 'euc-jp';
    }
  }
} # _html_parser_change_the_encoding_byte_string_with_charset

sub _html_parser_bom : Test(20) {
  my $dom = Web::DOM::Implementation->new;
  for my $test (
    ["\xFE\xFFhogefuga", undef, 'utf-16be'],
    ["\xFE\xFFhogefuga", 'utf-16le', 'utf-16be'],
    ["\xFE\xFFhogefuga", 'utf-16', 'utf-16be'],
    ["\xFF\xFEhogefuga", undef, 'utf-16le'],
    ["\xFF\xFEhogefuga", 'utf-16le', 'utf-16le'],
    ["\xFF\xFEhogefuga", 'utf-16be', 'utf-16le'],
    ["\xFF\xFEhogefuga", 'utf-8', 'utf-16le'],
    ["\xEF\xBB\xBF\xFE\xFEhogefuga", undef, 'utf-8'],
    ["\xEF\xBB\xBF\xFE\xFEhogefuga", 'utf-8', 'utf-8'],
    ["\xEF\xBB\xBF\xFE\xFEhogefuga", 'us-ascii', 'utf-8'],
  ) {
    my $parser = Web::HTML::Parser->new;
    my $called = 0;
    $parser->onerror (sub {
      my %args = @_;
      $called = 1 if $args{type} eq 'charset label detected';
    });
    my $doc = $dom->create_document;
    $parser->parse_byte_string ($test->[1], $test->[0] => $doc);
    ok !$called;
    is $doc->input_encoding, $test->[2];
  }
} # _html_parser_bom

sub _parse_char_string : Test(4) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<!DOCTYPE html><html lang=en><title>\x{0500}\x{200}</title>\x{500}};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ($input => $doc);
  is scalar @{$doc->child_nodes}, 2;
  eq_or_diff $doc->inner_html, qq{<!DOCTYPE html><html lang="en"><head><title>\x{0500}\x{0200}</title></head><body>\x{0500}</body></html>};
  is $doc->input_encoding, 'utf-8';
  is $doc->manakai_is_html, 1;
} # _parse_char_string

sub _parse_char_string_onerror_old : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>};
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($input => $doc);
  ok $error[0]->{token};
  delete $error[0]->{token};
  eq_or_diff \@error, [{
    type => 'no DOCTYPE',
    level => 'm',
    line => 1,
    column => 14,
  }];
} # _parse_char_string_onerror_old

sub _parse_char_string_onerror_new : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>};
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($input => $doc);
  ok $error[0]->{token};
  delete $error[0]->{token};
  eq_or_diff \@error, [{
    type => 'no DOCTYPE',
    level => 'm',
    line => 1,
    column => 14,
  }];
} # _parse_char_string_onerror_new

sub _parse_char_string_old_children : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  $doc->inner_html (q{<foo><bar/></foo><!---->});
  is scalar @{$doc->child_nodes}, 2;

  my $input = qq{<html lang=en>};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ($input => $doc);

  is scalar @{$doc->child_nodes}, 1;
  eq_or_diff $doc->inner_html, q{<html lang="en"><head></head><body></body></html>};
} # _parse_char_string_old_children

sub _parse_char_string_encoding_decl : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en><meta charset=euc-jp>};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ($input => $doc);
  eq_or_diff $doc->inner_html, q{<html lang="en"><head><meta charset="euc-jp"></head><body></body></html>};
  is $doc->input_encoding, 'utf-8';
} # _parse_char_string_encoding_decl

sub _parse_byte_string_latin1 : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\xCF\xEF\xEE\x21\x21};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_byte_string ('iso-8859-1', $input => $doc);

  eq_or_diff $doc->inner_html, qq{<html lang="en"><head></head><body>\xCF\xEF\xEE\x21\x21</body></html>};
  is $doc->input_encoding, 'windows-1252';
} # _parse_byte_string_latin1

sub _parse_byte_string_utf8 : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\xCF\xAF\xEE\x21\x21};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_byte_string ('utf-8', $input => $doc);

  eq_or_diff $doc->inner_html, qq{<html lang="en"><head></head><body>\x{03ef}\x{fffd}\x21\x21</body></html>};
  is $doc->input_encoding, 'utf-8';
} # _parse_byte_string_utf8

sub _parse_byte_string_sjis_detected : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\x82\xD9\x82\xB0\x82\xD9\x82\xB0nemui\x82\xC5\x82\xB7};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_byte_string (undef, $input => $doc);

  eq_or_diff $doc->inner_html, qq{<html lang="en"><head></head><body>\x{307b}\x{3052}\x{307b}\x{3052}nemui\x{3067}\x{3059}</body></html>};
  is $doc->input_encoding, 'shift_jis';
} # _parse_byte_string_sjis_detected

sub _parse_byte_string_utf8_detected : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\xCF\xAF\xEE\x21\x21};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_byte_string (undef, $input => $doc);

  eq_or_diff $doc->inner_html, qq{<html lang="en"><head></head><body>\x{03ef}\x{fffd}\x21\x21</body></html>};
  is $doc->input_encoding, 'utf-8';
} # _parse_byte_string_utf8_detected

sub _parse_byte_string_jis_detected : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\x1B\x24B\x24_\x21\x26\x249\x21\x26\x248\x1B\x28B};
  my $parser = Web::HTML::Parser->new;
  $parser->parse_byte_string (undef, $input => $doc);

  eq_or_diff $doc->inner_html, qq{<html lang="en"><head></head><body>\x{307f}\x{30fb}\x{3059}\x{30fb}\x{3058}</body></html>};
  is $doc->input_encoding, 'iso-2022-jp';
} # _parse_byte_string_jis_detected

sub _parse_byte_string_onerror_new : Test(2) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $input = qq{<html lang=en>\xC3\xAC};
  my $parser = Web::HTML::Parser->new;
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_byte_string ('utf-8', $input => $doc);
  ok $error[0]->{token};
  delete $error[0]->{token};
  eq_or_diff \@error, [{
    type => 'no DOCTYPE',
    level => 'm',
    line => 1,
    column => 15,
  }];
} # _parse_byte_string_onerror_new

sub _parse_byte_string_with_a_known_definite_encoding : Test(1) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->known_definite_encoding ('shift_jis');
  $parser->parse_byte_string ('euc-jp', "<!DOCTYPE html><meta charset=iso-8859-1>\x81\x40" => $doc);
  is $doc->input_encoding, 'shift_jis';
} # _parse_byte_string_with_a_known_definite_encoding

sub _parse_char_string_with_context_doc : Test(1) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  $doc->manakai_is_html (1);

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string_with_context
      ('hoge<p>foo<tr>bar', undef, $doc, 'innerHTML');

  is $doc->inner_html, '<html><head></head><body>hoge<p>foobar</p></body></html>';
} # _parse_char_string_with_context_doc

sub _parse_char_string_with_context_template_quirks : Test(2) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');
  my $parser = Web::HTML::Parser->new;
  my $el = $doc->create_element ('template');
  my $el2 = $doc->create_element ('hoge');
  $el->content->append_child ($el2);
  my $children = $parser->parse_char_string_with_context ('<p>aa<table>', $el2 => $doc);
  is $children->length, 2;
  is $children->[1]->local_name, 'table';
} # _parse_char_string_with_context_template_quirks

sub _parse_bytes_stream_incomplete : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<link fu', start_parsing => 1);
  $parser->parse_bytes_feed ('ga="">');
  $parser->parse_bytes_end;
  
  ok $doc->manakai_is_html;
  is $doc->input_encoding, 'windows-1252';
  is $doc->inner_html, q(<html><head><link fuga=""></head><body></body></html>);
} # _parse_bytes_stream_incomplete

sub _parse_bytes_stream_incomplete_2 : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<link fu=', start_parsing => 1);
  $parser->parse_bytes_feed ('"">');
  $parser->parse_bytes_end;
  
  ok $doc->manakai_is_html;
  is $doc->input_encoding, 'windows-1252';
  is $doc->inner_html, q(<html><head><link fu=""></head><body></body></html>);
} # _parse_bytes_stream_incomplete_2

sub _parse_bytes_stream_change_encoding_by_main_parser : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<meta charset=', start_parsing => 1);
  $parser->parse_bytes_feed ('"shift_jis"><link><p>');
  $parser->parse_bytes_feed ("<q>\x81\x40</q>");
  $parser->parse_bytes_end;
  
  ok $doc->manakai_is_html;
  is $doc->input_encoding, 'shift_jis';
  is $doc->inner_html, qq(<html><head><meta charset="shift_jis"><link></head><body><p><q>\x{3000}</q></p></body></html>);
} # _parse_bytes_stream_change_encoding_by_main_parser

sub _parse_bytes_stream_prescan_tag_like : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<%$a<f><*', start_parsing => 1);
  $parser->parse_bytes_feed ('ab<&a<%aa%?><');
  $parser->parse_bytes_feed ('#>');
  $parser->parse_bytes_end;
  
  ok $doc->manakai_is_html;
  is $doc->input_encoding, 'windows-1252';
  is $doc->inner_html, q(<html><head></head><body>&lt;%$a<f>&lt;*ab&lt;&amp;a&lt;%aa%?&gt;&lt;#&gt;</f></body></html>);
} # _parse_bytes_stream_prescan_tag_like

sub _parse_bytes_stream_locale_default : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->locale_tag ('RU');
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<!DOCTYPE html>hoge', start_parsing => 1);
  $parser->parse_bytes_end;
  
  is $doc->input_encoding, 'windows-1251';
  is $doc->inner_html, q(<!DOCTYPE html><html><head></head><body>hoge</body></html>);
} # _parse_bytes_stream_locale_default

sub _parse_bytes_stream_locale_default_2 : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->locale_tag ('ja');
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<!DOCTYPE html>hoge', start_parsing => 1);
  $parser->parse_bytes_end;
  
  is $doc->input_encoding, 'shift_jis';
  is $doc->inner_html, q(<!DOCTYPE html><html><head></head><body>hoge</body></html>);
} # _parse_bytes_stream_locale_default_2

sub _parse_bytes_stream_locale_default_2_long : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->locale_tag ('ja-JP');
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<!DOCTYPE html>hoge', start_parsing => 1);
  $parser->parse_bytes_end;
  
  is $doc->input_encoding, 'shift_jis';
  is $doc->inner_html, q(<!DOCTYPE html><html><head></head><body>hoge</body></html>);
} # _parse_bytes_stream_locale_default_2_long

sub _parse_bytes_stream_locale_default_3 : Test(3) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->locale_tag ('en');
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ('<!DOCTYPE html>hoge', start_parsing => 1);
  $parser->parse_bytes_end;
  
  is $doc->input_encoding, 'windows-1252';
  is $doc->inner_html, q(<!DOCTYPE html><html><head></head><body>hoge</body></html>);
} # _parse_bytes_stream_locale_default_3

sub _parse_bytes_stream_with_a_known_definite_encoding : Test(1) {
  my $dom = Web::DOM::Implementation->new;
  my $doc = $dom->create_document;
  my $parser = Web::HTML::Parser->new;
  $parser->known_definite_encoding ('shift_jis');
  $parser->parse_bytes_start ('euc-jp', $doc);
  $parser->parse_bytes_feed ("<!DOCTYPE html><meta charset=iso-8859-1>\x81\x40");
  $parser->parse_bytes_end;
  is $doc->input_encoding, 'shift_jis';
} # _parse_bytes_stream_with_a_known_definite_encoding

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2009-2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
