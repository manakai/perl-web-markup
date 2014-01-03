package test::Web::HTML::Parser::doctype;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Web::HTML::Parser;
use Web::DOM::Document;
use Test::HTCT::Parser;

my $test_d = file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'html', 'doctype');

sub _no_quirks : Tests {
  for_each_test ($test_d->file ($_)->stringify, {
    data => {is_prefixed => 1},
  }, sub {
    my $test = shift;
    {
      my $doc = new Web::DOM::Document;

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'CSS1Compat';
      is $doc->manakai_compat_mode, 'no quirks';
    }
    {
      my $doc = new Web::DOM::Document;
      $doc->manakai_is_srcdoc (1);

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'CSS1Compat';
      is $doc->manakai_compat_mode, 'no quirks';
    }
  }) for qw(
    doctype-noquirks.dat
  );
} # _no_quirks

sub _limited_quirks : Tests {
  for_each_test ($test_d->file ($_)->stringify, {
    data => {is_prefixed => 1},
  }, sub {
    my $test = shift;
    {
      my $doc = new Web::DOM::Document;

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'CSS1Compat';
      is $doc->manakai_compat_mode, 'limited quirks';
    }
    {
      my $doc = new Web::DOM::Document;
      $doc->manakai_is_srcdoc (1);

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'CSS1Compat';
      is $doc->manakai_compat_mode, 'no quirks';
    }
  }) for qw(
    doctype-limitedquirks.dat
  );
} # _limited_quirks

sub _quirks : Tests {
  for_each_test ($test_d->file ($_)->stringify, {
    data => {is_prefixed => 1},
  }, sub {
    my $test = shift;
    {
      my $doc = new Web::DOM::Document;

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'BackCompat';
      is $doc->manakai_compat_mode, 'quirks';
    }
    {
      my $doc = new Web::DOM::Document;
      $doc->manakai_is_srcdoc (1);

      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{data}->[0] => $doc);

      is $doc->compat_mode, 'CSS1Compat';
      is $doc->manakai_compat_mode, 'no quirks';
    }
  }) for qw(
    doctype-quirks.dat
  );
} # _quirks

sub _change_compat_to_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("abc" => $doc);

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';
} # _change_compat_to_quirk

sub _change_compat_to_limited_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'limited quirks';
} # _change_compat_to_limited_quirk

sub _change_compat_to_no_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('no quirks');

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';
} # _change_compat_to_no_quirk

sub _change_compat_q_to_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("abc" => $doc);

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';
} # _change_compat_q_to_quirk

sub _change_compat_q_to_limited_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '-//W3C//DTD HTML 4.01 Frameset//EN' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'limited quirks';
} # _change_compat_q_to_limited_quirk

sub _change_compat_q_to_no_quirk : Test(4) {
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_compat_mode ('quirks');

  is $doc->compat_mode, 'BackCompat';
  is $doc->manakai_compat_mode, 'quirks';

  my $parser = Web::HTML::Parser->new;
  $parser->parse_char_string ("<!DOCTYPE html PUBLIC '' ''>" => $doc);

  is $doc->compat_mode, 'CSS1Compat';
  is $doc->manakai_compat_mode, 'no quirks';
} # _change_compat_q_to_no_quirk

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
