use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('lib')->stringify;
use lib path (__FILE__)->parent->parent->parent->child ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Web::HTML::Parser;
use Web::DOM::Document;
use Test::HTCT::Parser;

my $test_path = path (__FILE__)->parent->parent->parent->child
    ('t_deps', 'tests', 'html', 'doctype');

for_each_test ($test_path->child ($_)->stringify, {
  data => {is_prefixed => 1},
}, sub {
  my $test = shift;
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'CSS1Compat';
    is $doc->manakai_compat_mode, 'no quirks';
    done $c;
  } n => 2, name => ['quirks', $test->{data}->[0]];
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_srcdoc (1);

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'CSS1Compat';
    is $doc->manakai_compat_mode, 'no quirks';
    done $c;
  } n => 2, name => ['no quirks', $test->{data}->[0]];
}) for qw(
  doctype-noquirks.dat
);

for_each_test ($test_path->child ($_)->stringify, {
  data => {is_prefixed => 1},
}, sub {
  my $test = shift;
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'CSS1Compat';
    is $doc->manakai_compat_mode, 'limited quirks';
    done $c;
  } n => 2, name => ['limited quirks', $test->{data}->[0]];
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_srcdoc (1);

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'CSS1Compat';
    is $doc->manakai_compat_mode, 'no quirks';
    done $c;
  } n => 2, name => ['limited quirks', $test->{data}->[0]];
}) for qw(
  doctype-limitedquirks.dat
);

for_each_test ($test_path->child ($_)->stringify, {
  data => {is_prefixed => 1},
}, sub {
  my $test = shift;
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'BackCompat';
    is $doc->manakai_compat_mode, 'quirks';
    done $c;
  } n => 2, name => ['quirks', $test->{data}->[0]];
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_srcdoc (1);

    my $parser = Web::HTML::Parser->new;
    $parser->parse_char_string ($test->{data}->[0] => $doc);

    is $doc->compat_mode, 'CSS1Compat';
    is $doc->manakai_compat_mode, 'no quirks';
    done $c;
  } n => 2, name => ['(srcdoc) quirks', $test->{data}->[0]];
}) for qw(
  doctype-quirks.dat
);

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("abc" => $doc);

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';
  done $c;
} n => 4, name => '-> quirks';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'limited quirks';
  done $c;
} n => 4, name => '-> limited quirks';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';
  done $c;
} n => 4, name => '-> no quirks';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("abc" => $doc);

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';
  done $c;
} n => 4, name => 'quikrs -> quirks';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'limited quirks';
  done $c;
} n => 4, name => 'quirks -> limited quirks';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';
  done $c;
} n => 4, name => 'quirks -> no quirks';

run_tests;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
