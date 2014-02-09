use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Web::XML::Parser;
use Web::DOM::Document;

test {
  my $c = shift;

  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;

  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed ("<p a=b>ab<f");
  $parser->parse_bytes_feed (">a</f  >b");
  $parser->parse_bytes_feed ("");
  $parser->parse_bytes_feed ("</p> ");
  $parser->parse_bytes_end;

  is $doc->inner_html, q{<p xmlns="" a="b">ab<f>a</f>b</p>};

  done $c;
} n => 1, name => 'stream api';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_feed ('XYZ');
    $subparser->parse_bytes_end;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;b</a>});
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cXYZb</a>};
  done $c;
} n => 1, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_feed ('XYZ');
      $subparser->parse_bytes_end;
    };
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;b</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cXYZb</a>};
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'an external entity async';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $count = 0;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_feed ('XYZ');
    $subparser->parse_bytes_end;
    $count++;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cXYZvXYZb</a>};
  is $count, 2;
  done $c;
} n => 2, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $count = 0;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_feed ('X<p>Y</p>Z');
    $subparser->parse_bytes_end;
    $count++;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cX<p>Y</p>ZvX<p>Y</p>Zb</a>};
  is $count, 2;
  done $c;
} n => 2, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cvb</a>};
  done $c;
} n => 1, name => 'an external entity - not expanded';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $count = 0;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    $subparser->parse_bytes_start (undef);
    $subparser->parse_bytes_feed ('X<p>Y');
    $parser->parse_bytes_feed ('<!--zz-->');
    $subparser->parse_bytes_feed ('</p>Z');
    $subparser->parse_bytes_end;
    $count++;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_feed ('<!--abc-->');
  $parser->parse_bytes_end;
  is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cX<p>Y</p>ZvX<p>Y</p>Zb</a><!--abc--><!--zz--><!--zz-->};
  is $count, 2;
  done $c;
} n => 2, name => 'an external entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $count = 0;
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_feed ('X<p>Y');
      $parser->parse_bytes_feed ('<!--zz-->');
      $subparser->parse_bytes_feed ('</p>Z');
      $subparser->parse_bytes_end;
    };
    $count++;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM ""> ]><a>c&x;v&x;b</a>});
  $parser->parse_bytes_feed ('<!--abc-->');
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cX<p>Y</p>ZvX<p>Y</p>Zb</a><!--abc--><!--zz--><!--zz-->};
      is $count, 2;
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'an external entity async';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f<p>&b;x</p>',
    b => 'ab<q>ss</q>d',
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_feed ($ents->{$ent->{extent}->{sysid}});
      $subparser->parse_bytes_end;
    };
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"><!ENTITY b SYSTEM "b"> ]><a>c&x;v</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cf<p>ab<q>ss</q>dx</p>v</a>};
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'nested entity';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f<p>b;x</p>',
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_feed ($ents->{$ent->{extent}->{sysid}});
      $subparser->parse_bytes_end;
    };
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"> ]><a xmlns="http://hoge/.">c&x;v</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="http://hoge/.">cf<p>b;x</p>v</a>};
      done $c;
      undef $c;
    } $c;
  });
} n => 1, name => 'default namespace';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f<p>b;x</p>',
  };
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef);
      $subparser->parse_bytes_feed ($ents->{$ent->{extent}->{sysid}});
      $subparser->parse_bytes_end;
    };
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"> ]>&x;});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a>};
      eq_or_diff \@error, [{type => 'ref outside of root element',
                            line => 1, column => 40,
                            level => 'm'},
                           {type => 'no root element',
                            token => {type => 5, line => 1, column => 43},
                            level => 'm'}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'default namespace, outside of root element';

# XXX namespaces in external entity
# XXX recursive entref

run_tests;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
