use strict;
use warnings;
use warnings FATAL => 'recursion';
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
    $subparser->parse_bytes_start (undef, $parser);
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
      $subparser->parse_bytes_start (undef, $parser);
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
    $subparser->parse_bytes_start (undef, $parser);
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
    $subparser->parse_bytes_start (undef, $parser);
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
    $subparser->parse_bytes_start (undef, $parser);
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
      $subparser->parse_bytes_start (undef, $parser);
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
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="">cX<p>Y</p>ZvX<p>Y</p>Zb</a><!--abc-->};
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
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
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
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
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
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a>};
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'ref outside of root element',
                            di => 1, index => 39, value => '&x;',
                            level => 'm'},
                           {type => 'no root element', di => 1, index => 42,
                            level => 'm'}];
      done $c;
      undef $c;
    } $c;
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"> ]>&x;});
  $parser->parse_bytes_end;
} n => 2, name => 'default namespace, outside of root element';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f<a:p>b;x</a:p>',
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"> ]><a xmlns="http://hoge/." xmlns:a="http://a/">c&x;v</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="http://hoge/." xmlns:a="http://a/">cf<a:p>b;x</a:p>v</a>};
      is $doc->document_element->first_element_child->namespace_uri, q{http://a/};
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'namespace prefix';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f&x;j',
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di (1);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "a"> ]><a xmlns="http://hoge/." xmlns:a="http://a/">c&x;v</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html,
          q{<!DOCTYPE a><a xmlns="http://hoge/." xmlns:a="http://a/">cf&amp;x;jv</a>};
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'WFC:No Recursion',
                            di => 1, index => 1,
                            value => '&x;',
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 1, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'recursive entity ref';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    a => 'f&x;j',
    b => 'd&y;x',
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di ($ent->{entity}->{system_identifier} eq 'a' ? 10 : 2);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a [ <!ENTITY x SYSTEM "b"><!ENTITY y SYSTEM "a"> ]><a xmlns="http://hoge/." xmlns:a="http://a/">c&x;v</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a><a xmlns="http://hoge/." xmlns:a="http://a/">cdf&amp;x;jxv</a>};
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 2, index => 0},
                           {type => 'WFC:No Recursion',
                            di => 10, index => 1,
                            value => '&x;',
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 10, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'recursive entity ref';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    'http://a/' => q{
      <!ENTITY % b SYSTEM "http://b/">
      <!ENTITY % c SYSTEM "http://c/">
      <!ENTITY % d SYSTEM "http://d/">
      <!ENTITY % e SYSTEM "http://e/">
      <!ENTITY % f SYSTEM "http://f/">
      %b;
    },
    'http://b/' => q{%c;}, # di=98
    'http://c/' => q{%d;}, # di=99
    'http://d/' => q{ %e;}, # di=100
    'http://e/' => q{%f;}, # di=101
    'http://f/' => q{%g;}, # di=102
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di (ord substr $ent->{entity}->{system_identifier}, 7, 1);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->max_entity_depth (3);
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a SYSTEM "http://a/"><a/>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a SYSTEM "http://a/"><a xmlns=""></a>};
      @error = grep { not $_->{type} eq 'xml:dtd:ext decl' } @error;
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 97, index => 0},
                           {type => 'entity:too deep',
                            di => 100, index => 1, value => '%e;',
                            text => 3,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 100, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 99, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 98, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'param entity depth';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    'http://a/' => q{
      <!ENTITY a "&b;">
      <!ENTITY b SYSTEM "http://b/">
      <!ENTITY c SYSTEM "http://c/">
      <!ENTITY d SYSTEM "http://d/">
      <!ENTITY e SYSTEM "http://e/">
      <!ENTITY f SYSTEM "http://f/">
    },
    'http://b/' => q{&c;}, # di=98
    'http://c/' => q{&d;}, # di=99
    'http://d/' => q{ &e;y}, # di=100
    'http://e/' => q{&f;}, # di=101
    'http://f/' => q{&g;}, # di=102
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di (ord substr $ent->{entity}->{system_identifier}, 7, 1);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->max_entity_depth (3);
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a SYSTEM "http://a/"><a>&a;x</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a SYSTEM "http://a/"><a xmlns=""> yx</a>};
      @error = grep { not $_->{type} eq 'xml:dtd:ext decl' } @error;
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 97, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 100, index => 0},
                           {type => 'entity:too deep',
                            di => 100, index => 1,
                            text => 3, value => '&e;',
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 99, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 98, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'general entity depth';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    'http://a/' => q{
      <!ENTITY % b SYSTEM "http://b/">
      <!ENTITY % c SYSTEM "http://c/">
      <!ENTITY % d SYSTEM "http://d/">
      <!ENTITY % e SYSTEM "http://e/">
      <!ENTITY % f SYSTEM "http://f/">
      %b;
    },
    'http://b/' => q{%c;%c;}, # di=98
    'http://c/' => q{%d;%d;}, # di=99
    'http://d/' => q{ %e;%e;}, # di=100
    'http://e/' => q{%f;%f;}, # di=101
    'http://f/' => q{x}, # di=102
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di (ord substr $ent->{entity}->{system_identifier}, 7, 1);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->max_entity_expansions (2);
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a SYSTEM "http://a/"><a/>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a SYSTEM "http://a/"><a xmlns=""></a>};
      @error = grep { not $_->{type} eq 'xml:dtd:ext decl' } @error;
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'no XML decl',
                            level => 's', di => 97, index => 0},
                           {type => 'entity:too many refs',
                            di => 100, index => 1, value => '%e;',
                            text => 2,
                            level => 'm'},
                           {type => 'entity:too many refs',
                            di => 100, index => 4, value => '%e;',
                            text => 2,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 100, index => 0},
                           {type => 'entity:too many refs',
                            di => 99, index => 3, value => '%d;',
                            text => 2,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 99, index => 0},
                           {type => 'entity:too many refs',
                            di => 98, index => 3, value => '%c;',
                            text => 2,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 98, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'param entity count';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  my $ents = {
    'http://a/' => q{
      <!ENTITY a "&b;">
      <!ENTITY b SYSTEM "http://b/">
      <!ENTITY c SYSTEM "http://c/">
      <!ENTITY d SYSTEM "http://d/">
      <!ENTITY e SYSTEM "http://e/">
      <!ENTITY f SYSTEM "http://f/">
    },
    'http://b/' => q{&c;&c;}, # di=98
    'http://c/' => q{&d;&d;}, # di=99
    'http://d/' => q{ &e;&e;y}, # di=100
    'http://e/' => q{z&f;&f;}, # di=101
    'http://f/' => q{x}, # di=102
  };
  $parser->onextentref (sub {
    my ($parser, $ent, $subparser) = @_;
    AE::postpone {
      $subparser->di (ord substr $ent->{entity}->{system_identifier}, 7, 1);
      $subparser->parse_bytes_start (undef, $parser);
      $subparser->parse_bytes_feed ($ents->{$ent->{entity}->{system_identifier}});
      $subparser->parse_bytes_end;
    };
  });
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->max_entity_expansions (3);
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (q{<!DOCTYPE a SYSTEM "http://a/"><a>&a;x</a>});
  $parser->parse_bytes_end;
  $parser->onparsed (sub {
    test {
      is $doc->inner_html, q{<!DOCTYPE a SYSTEM "http://a/"><a xmlns=""> yx</a>};
      @error = grep { not $_->{type} eq 'xml:dtd:ext decl' } @error;
      @error = grep { not $_->{type} eq 'external entref' } @error;
      eq_or_diff \@error, [{type => 'no XML decl',
                            level => 's', di => 1, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 97, index => 0},
                           {type => 'no XML decl',
                            level => 's',
                            di => 100, index => 0},
                           {type => 'entity:too many refs',
                            di => 100, index => 1, value => '&e;',
                            text => 3,
                            level => 'm'},
                           {type => 'entity:too many refs',
                            di => 100, index => 4, value => '&e;',
                            text => 3,
                            level => 'm'},
                           {type => 'entity:too many refs',
                            di => 99, index => 3, value => '&d;',
                            text => 3,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 99, index => 0},
                           {type => 'entity:too many refs',
                            di => 98, index => 3, value => '&c;',
                            text => 3,
                            level => 'm'},
                           {type => 'no XML decl',
                            level => 's',
                            di => 98, index => 0}];
      done $c;
      undef $c;
    } $c;
  });
} n => 2, name => 'general entity count';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = new Web::XML::Parser;
  my @error;
  $parser->onerror (sub {
    my %error = @_;
    if ($error{level} eq 'm') {
      push @error, \%error;
    }
  });
  my $sub1;
  my $sub2;
  $parser->onextentref (sub {
    my ($parser, $data, $subparser) = @_;
    if (defined $data->{entity}->{name}) {
      $sub2 = $subparser;
      $sub2->parse_bytes_start (undef, $parser);
    } else {
      $sub1 = $subparser;
      $sub1->parse_bytes_start (undef, $parser);
    }
  });
  $parser->parse_chars_start ($doc);
  $parser->parse_chars_feed ('<?xml version="1.0"?><!DOCTYPE a SYSTEM "x"><a/>');
  $parser->parse_chars_end;

  $sub1->parse_bytes_feed ('
    <!ENTITY % hoge SYSTEM "">
    %hoge;
    &
  ');
  $sub1->parse_bytes_end;

  $sub2->parse_bytes_feed ('<?xml encoding="utf-8"?>');
  $sub2->parse_bytes_end;

  is 0+@error, 1;
  is $error[0]->{di}, 3;
  is $error[0]->{index}, 47;

  done $c;
} n => 3, name => 'error after extentref';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start ('shift_jis', $doc);
  $parser->parse_bytes_feed ("<x>\x81");
  $parser->parse_bytes_feed ("\x40</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{3000}";
  is $doc->charset, 'Shift_JIS';
  done $c;
} n => 2, name => 'bytes transport encoding';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start ('shift_jis', $doc);
  $parser->parse_bytes_feed ("<x>\x81");
  $parser->parse_bytes_feed ("\xFF</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{FFFD}";
  is $doc->charset, 'Shift_JIS';
  done $c;
} n => 2, name => 'bytes transport encoding bad content';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->known_definite_encoding ('shift_jis');
  $parser->parse_bytes_start ('euc-jp', $doc);
  $parser->parse_bytes_feed ("<x>\x81");
  $parser->parse_bytes_feed ("\x40</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{3000}";
  is $doc->charset, 'Shift_JIS';
  done $c;
} n => 2, name => 'bytes transport + override encoding';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (qq{<?xml encoding="shift_jis"?><x>\x81});
  $parser->parse_bytes_feed ("\x40</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{3000}";
  is $doc->charset, 'Shift_JIS';
  done $c;
} n => 2, name => 'bytes no transport encoding / xml-encoding';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (qq{<x>\x81});
  $parser->parse_bytes_feed ("\x40</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{FFFD}\x40";
  is $doc->charset, 'UTF-8';
  done $c;
} n => 2, name => 'bytes no transport encoding / no xml-encoding';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start (undef, $doc);
  $parser->parse_bytes_feed (qq{\xFE\xFF\x00<\x00x\x00>\x81});
  $parser->parse_bytes_feed ("\x40\x00<\x00/\x00x\x00>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{8140}";
  is $doc->charset, 'UTF-16BE';
  done $c;
} n => 2, name => 'bytes no transport encoding / UTF-16BE BOM';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start ('shift_jis', $doc);
  $parser->parse_bytes_feed (qq{\xFE\xFF\x00<\x00x\x00>\x81});
  $parser->parse_bytes_feed ("\x40\x00<\x00/\x00x\x00>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{8140}";
  is $doc->charset, 'UTF-16BE';
  done $c;
} n => 2, name => 'bytes transport encoding / UTF-16BE BOM';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start ('shift_jis', $doc);
  $parser->parse_bytes_feed (qq{\xFF\xFE<\x00x\x00>\x00\x81});
  $parser->parse_bytes_feed ("\x40<\x00/\x00x\x00>\x00");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{4081}";
  is $doc->charset, 'UTF-16LE';
  done $c;
} n => 2, name => 'bytes transport encoding / UTF-16LE BOM';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $parser = Web::XML::Parser->new;
  $parser->parse_bytes_start ('shift_jis', $doc);
  $parser->parse_bytes_feed (qq{\xEF\xBB\xBF<x>\x81});
  $parser->parse_bytes_feed ("\x40</x>");
  $parser->parse_bytes_end;
  is $doc->document_element->text_content, "\x{FFFD}\x40";
  is $doc->charset, 'UTF-8';
  done $c;
} n => 2, name => 'bytes transport encoding / UTF-8 BOM';

run_tests;

=head1 LICENSE

Copyright 2014-2017 Wakaba <wakaba@suikawiki.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
