use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::DOM::Document;
use Web::HTML::Microdata;

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (q{<!DOCTYPE html><p>abc<p>xya});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc), [];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'no items';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->inner_html (q{<!DOCTYPE html><p itemscope>abc<p>xya});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'an item';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope>ab<img src="hoge" itemprop=abc><span itemprop=x>c</span><p>x<br itemprop=aaa>ya});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {abc => [{type => 'url', text => 'http://foo/bar/hoge',
                           node => $doc->query_selector ('p img')}],
                  x => [{type => 'string', text => 'c',
                         node => $doc->query_selector ('p span')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'an item with props';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope itemref=a>ab<area href="hoge" itemprop=abc><span itemprop=x>c</span><p>x<br itemprop=aaa id=a>ya});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {abc => [{type => 'url', text => 'http://foo/bar/hoge',
                           node => $doc->query_selector ('p area')}],
                  x => [{type => 'string', text => 'c',
                         node => $doc->query_selector ('p span')}],
                  aaa => [{type => 'string', text => '',
                           node => $doc->query_selector ('br')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'an item with props, itemref';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope itemref="a b c d">ab<area href="hoge" itemprop=abc><span itemprop=x id=b>c</span><p>x<br itemprop=aaa id=a>ya<video id=d src="" itemprop></video><p id=d itemProp=bba>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {abc => [{type => 'url', text => 'http://foo/bar/hoge',
                           node => $doc->query_selector ('p area')}],
                  x => [{type => 'string', text => 'c',
                         node => $doc->query_selector ('p span')}],
                  aaa => [{type => 'string', text => '',
                           node => $doc->query_selector ('br')}]},
        types => {}}];
  eq_or_diff \@error, [{type => 'microdata:referenced by itemref',
                        node => $doc->query_selector ('#b'),
                        level => 'm'}];

  done $c;
} n => 2, name => 'an item with props, itemrefs';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope itemref=aa><p id=aa><meter value=abc itemprop=abcd>aa</meter>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {abcd => [{type => 'string', text => 'abc',
                            node => $doc->query_selector ('meter')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'itemref referenced element\'s descendant prop';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope><span itemscope><wbr itemprop=aa></span>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {},
        types => {}},
       {type => 'item',
        node => $doc->query_selector ('span'),
        props => {aa => [{type => 'string', text => '',
                          node => $doc->query_selector ('wbr')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'nested itemscope without itemprop';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope><span itemscope itemprop="aa ba"><wbr itemprop=aa></span>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {aa => [{type => 'item',
                          node => $doc->query_selector ('span'),
                          props => {aa => [{type => 'string', text => '',
                                            node => $doc->query_selector ('wbr')}]},
                          types => {}}],
                  ba => [{type => 'item',
                          node => $doc->query_selector ('span'),
                          props => {aa => [{type => 'string', text => '',
                                            node => $doc->query_selector ('wbr')}]},
                          types => {}}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'nested itemscope itemprop';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope><span itemprop="hog aaa  aaa">afe<b> ee</b></span>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {hog => [{type => 'string', text => 'afe ee',
                           node => $doc->query_selector ('span')}],
                  aaa => [{type => 'string', text => 'afe ee',
                           node => $doc->query_selector ('span')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'itemprop multiple values';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><p itemscope id=aa><span itemprop=xx itemscope itemref=aa>afe<b> ee</b></span><time itemprop=y>aa</time>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {xx => [{type => 'item',
                          node => $doc->query_selector ('span'),
                          props => {},
                          types => {}}],
                  y => [{type => 'string', text => 'aa',
                         node => $doc->query_selector ('time')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'itemprop references parent';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html><body id=bb><p itemscope><span itemprop=xx itemscope itemref=aa>afe<b> ee</b></span></p><time itemprop=y dateTime=abc>aa</time><p id=aa><span itemscope itemref=bb></span>});

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('p'),
        props => {xx => [{type => 'item',
                          node => $doc->query_selector ('span'),
                          props => {},
                          types => {}}]},
        types => {}},
       {type => 'item',
        node => $doc->query_selector ('#aa span'),
        props => {y => [{type => 'string', text => 'abc',
                         node => $doc->query_selector ('time')}]},
        types => {}}];
  eq_or_diff \@error, [{type => 'microdata:referenced by itemref',
                        node => $doc->query_selector ('#aa span'),
                        level => 'm'}];

  done $c;
} n => 2, name => 'itemprop references parent';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html>
    <div itemscope>
      <div id=A><p itemscope itemprop=X itemref=B></div>
    </div>
    <div id=B><p itemscope itemprop=Y itemref=A></div>
  });

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('div'),
        props => {X => [{type => 'item',
                         node => $doc->query_selector ('#A p'),
                         props => {Y => [{type => 'item',
                                          node => $doc->query_selector ('#B p'),
                                          props => {X => [{type => 'item',
                                                           node => $doc->query_selector ('#A p'),
                                                           looped => 1}]},
                                          types => {}}]},
                         types => {}}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'itemscope loop';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html>
    <div itemscope itemtype="hoge&#x09;bbb&#x0c;http://foo&#xd;aaaa hoge " itemid=foo/..>
      <object data=foo itemprop=foo></object>
    </div>
  });

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('div'),
        props => {foo => [{type => 'url', text => 'http://foo/bar/foo',
                           node => $doc->query_selector ('object')}]},
        types => {hoge => 1,
                  bbb => 1,
                  'http://foo' => 1,
                  aaaa => 1},
        id => 'http://foo/bar/'}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'itemscope loop';

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  $doc->manakai_set_url ('http://foo/bar/baz');
  $doc->inner_html (q{<!DOCTYPE html>
    <div itemscope>
      <meta itemprop=aaa content=foo>
      <embed itemprop=aaa src=bbb>
      <link itempRop=aaa>
    </div>
  });

  my $md = Web::HTML::Microdata->new;
  my @error;
  $md->onerror (sub { push @error, {@_} });
  eq_or_diff $md->get_top_level_items ($doc),
      [{type => 'item',
        node => $doc->query_selector ('div'),
        props => {aaa => [{type => 'string', text => 'foo',
                           node => $doc->query_selector ('meta')},
                          {type => 'url', text => 'http://foo/bar/bbb',
                           node => $doc->query_selector ('embed')},
                          {type => 'url', text => '',
                           node => $doc->query_selector ('link')}]},
        types => {}}];
  eq_or_diff \@error, [];

  done $c;
} n => 2, name => 'multiple values';

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
