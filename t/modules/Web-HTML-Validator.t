use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::Differences;
use Web::DOM::Document;
use Web::HTML::Validator;

for my $attr (qw(xml:lang xml:space xml:base)) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element_ns (undef, 'br');
    $el->set_attribute_ns (undef, [undef, $attr] => '! ?');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         {type => 'attribute not defined',
          node => $el->attributes->[0],
          level => 'm'}];
    done $c;
  } n => 1, name => [$attr, 'in no namespace'];
} # $attr

for my $test (
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'hoge'],
          'http://www.w3.org/XML/1998/namespace');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'm'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'hoge'],
          'http://www.w3.org/2000/xmlns/');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'm'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'xml'],
          'hoge');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Prefix',
     text => 'xml',
     level => 'm'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['xmlns', 'xmlns'],
          'hoge');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Prefix',
     text => 'xmlns',
     level => 'm'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'xmlns'],
          '');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'xmlns'],
          'http://fuga/');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          ['hoge', 'fpoo'],
          'http://fuga/');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/2000/xmlns/',
          [undef, 'xmlns'],
          'http://www.w3.org/2000/xmlns/');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'm'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/XML/1998/namespace',
          ['hoge', 'lang'], 'en');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/XML/1998/namespace',
          ['hoge', 'space'], 'default');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://www.w3.org/XML/1998/namespace',
                              [undef, 'lang'], 'de');
   },
   [{type => 'nsattr has no prefix',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://www.w3.org/2000/xmlns/',
                              [undef, 'foo'], 'default');
   },
   [{type => 'nsattr has no prefix',
     level => 'w'}]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element_ns (undef, 'foo');
    $test->[0]->($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         map { {%{$_}, node => $el->attributes->[0]} } @{$test->[1]}];
    done $c;
  } n => 1, name => [$test->[1]->[0]->{type}, $test->[1]->[0]->{text}];
}

for my $test (
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/XML/1998/namespace',
          ['xml', 'space'] => 'default');
   },
   {type => 'in HTML:xml:space', level => 'w'}],
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/XML/1998/namespace',
          ['xml', 'lang'] => 'en');
   },
   {type => 'in HTML:xml:lang', level => 'm'}],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->manakai_is_html (1);
    my $el = $doc->create_element ('div');
    $el->text_content ('aaa');
    $test->[0]->($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{%{$test->[1]}, node => $el->attributes->[0]}];
    done $c;
  } n => 1, name => ['html', $test->[1]->{type}, $test->[1]->{text}];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->strict_error_checking (0);
  my $el = $doc->create_element_ns (undef, 'foo');
  $el->set_attribute_ns
      ('http://www.w3.org/2000/xmlns/',
       ['xmlns', 'xmlns'],
       'http://www.w3.org/2000/xmlns/');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_element ($el);
  eq_or_diff \@error,
      [{type => 'element not defined',
        node => $el,
        level => 'm'},
       {type => 'Reserved Prefixes and Namespace Names:Prefix',
        text => 'xmlns',
        node => $el->attributes->[0],
        level => 'm'},
       {type => 'Reserved Prefixes and Namespace Names:Name',
        text => 'http://www.w3.org/2000/xmlns/',
        node => $el->attributes->[0],
        level => 'm'}];
  done $c;
} n => 1, name => ['xmlns:xmlns'];

for my $test (
  [sub {
     $_[0]->set_attribute_ns
         ('http://www.w3.org/XML/1998/namespace',
          ['hoge', 'fuga'], 'en');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://foo/', ['xml', 'space'], 'default');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Prefix',
     text => 'xml',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://foo/', ['xmlns', 'space'], 'default');
   },
   [{type => 'Reserved Prefixes and Namespace Names:Prefix',
     text => 'xmlns',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://foo/', [undef, 'space'], 'default');
   },
   [{type => 'nsattr has no prefix',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://foo/', [undef, 'xmlns'], 'default');
   },
   [{type => 'nsattr has no prefix',
     level => 'w'}]],
  [sub {
     $_[0]->set_attribute_ns ('http://foo/', ['hoge', 'xmlns'], 'default');
   },
   []],
  [sub {
     $_[0]->set_attribute_ns ('http://www.w3.org/XML/1998/namespace',
                              ['xml', 'xmlns'], 'default');
   },
   []],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element_ns (undef, 'foo');
    $test->[0]->($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         (map { {%{$_}, node => $el->attributes->[0]} } @{$test->[1]}),
         {type => 'attribute not defined',
          node => $el->attributes->[0],
          level => 'm'}];
    done $c;
  } n => 1, name => [$test->[1]->[0] ? $test->[1]->[0]->{type} : ()];
}

for my $version (qw(1.0 1.1 1.2 foo)) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->xml_version ($version);
    my $el = $doc->create_element_ns (undef, 'foo');
    $el->set_attribute_ns ('http://www.w3.org/2000/xmlns/', 'xmlns' => '');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'}];
    done $c;
  } n => 1, name => ['xml=""', $version];

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->xml_version ($version);
    my $el = $doc->create_element_ns (undef, 'foo');
    $el->set_attribute_ns ('http://www.w3.org/2000/xmlns/', 'xmlns:abc' => '');
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         {type => 'xmlns:* empty',
          node => $el->attributes->[0],
          level => 'm'}];
    done $c;
  } n => 1, name => ['xmlns:abc=""', $version];
} # $version

for my $test (
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/XML/1998/namespace', [undef, 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'w'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/XML/1998/namespace', ['xml', 'space']);
   },
   [{type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/XML/1998/namespace', ['hoge', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/XML/1998/namespace',
     level => 'w'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/2000/xmlns/', [undef, 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'w'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/2000/xmlns/', ['xmlns', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:<xmlns:>',
     level => 'm'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns
         ('http://www.w3.org/2000/xmlns/', ['hoge', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:Name',
     text => 'http://www.w3.org/2000/xmlns/',
     level => 'w'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns ('http://foo/', ['xml', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:Prefix', text => 'xml',
     level => 'w'},
    {type => 'element not defined', level => 'm'}]],
  [sub {
     return $_[0]->create_element_ns ('http://foo/', ['xmlns', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:<xmlns:>',
     level => 'm'},
    {type => 'element not defined', level => 'm'}]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $test->[0]->($doc);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [map { {%{$_}, node => $el} } @{$test->[1]}];
    done $c;
  } n => 1, name => ['element', $test->[1]->[0]->{type}, $test->[1]->[0]->{text}];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->strict_error_checking (0);
  my $el = $doc->create_element ('hoge');
  $el->set_attribute_ns (undef, [undef, 'xml:lang'] => 'abcd');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_element ($el);
  eq_or_diff \@error,
      [{type => 'element not defined',
        node => $el,
        level => 'm'},
       {type => 'in XML:xml:lang',
        node => $el->attributes->[0],
        level => 'm'},
       {type => 'attribute missing',
        text => 'lang',
        node => $el->attributes->[0],
        level => 'm'}];
  done $c;
} n => 1, name => ['{}xml:lang="" in XML'];

for my $test (
  ["\x{0010}", [[0, 0x0010]]],
  ["ab\x{0010}", [[2, 0x0010]]],
  ["ab\x{0010}\x{FDDF}", [[2, 0x0010], [3, 0xFDDF]]],
  ["\x{10FFFF}\x{110000}ab\x{0010}", [[0, 0x10FFFF], [1, 0x110000], [4, 0x0010]]],
  ["\x{DC00}", [[0, 0xDC00]]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element ('hoge');
    $el->set_attribute_ns (undef, hoge => $test->[0]);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         {type => 'attribute not defined',
          node => $el->attributes->[0],
          level => 'm'},
         map {
           +{type => 'text:bad char',
             index => $_->[0],
             value => ($_->[1] <= 0x10FFFF ? sprintf 'U+%04X', $_->[1]
                                           : sprintf 'U-%08X', $_->[1]),
             node => $el->attributes->[0],
             level => 'm'};
         } @{$test->[1]}];
    done $c;
  } n => 1, name => 'attr bad char';

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    my $el = $doc->create_element ('hoge');
    $el->text_content ($test->[0]);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_element ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         map {
           +{type => 'text:bad char',
             index => $_->[0],
             value => ($_->[1] <= 0x10FFFF ? sprintf 'U+%04X', $_->[1]
                                           : sprintf 'U-%08X', $_->[1]),
             node => $el->first_child,
             level => 'm'};
         } @{$test->[1]}];
    done $c;
  } n => 1, name => 'text bad char';
}

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
