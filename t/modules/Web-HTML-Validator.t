use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use Web::DOM::Document;
use Web::HTML::Validator;
use Web::HTML::SourceMap;

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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'unknown namespace element',
          value => '',
          node => $el,
          level => 'w'},
         #{type => 'attribute not defined',
         # node => $el->attributes->[0],
         # level => 'm'}
        ];
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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'unknown namespace element',
          value => '',
          node => $el,
          level => 'w'},
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
    $validator->check_node ($el);
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
  $validator->check_node ($el);
  eq_or_diff \@error,
      [{type => 'unknown namespace element',
        value => '',
        node => $el,
        level => 'w'},
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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'unknown namespace element',
          value => '',
          node => $el,
          level => 'w'},
         (map { {%{$_}, node => $el->attributes->[0]} } @{$test->[1]}),
         (($el->attributes->[0]->namespace_uri || '') eq 'http://www.w3.org/XML/1998/namespace' ?
          {type => 'attribute not defined',
           node => $el->attributes->[0],
           level => 'm'} : ()),
        ];
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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'unknown namespace element',
          value => '',
          node => $el,
          level => 'w'}];
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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'unknown namespace element',
          value => '',
          node => $el,
          level => 'w'},
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
    {type => 'unknown namespace element', level => 'w',
     value => 'http://foo/'}]],
  [sub {
     return $_[0]->create_element_ns ('http://foo/', ['xmlns', 'space']);
   },
   [{type => 'Reserved Prefixes and Namespace Names:<xmlns:>',
     level => 'm'},
    {type => 'unknown namespace element', level => 'w',
     value => 'http://foo/'}]],
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
    $validator->check_node ($el);
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
  $validator->check_node ($el);
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
  ["\x{FDE0}", [[0, 0xFDE0]]],
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
    $validator->check_node ($el);
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
    $validator->check_node ($el);
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

for my $test (
  ["\x{000C}", [[0, 0x000C]], []],
  ["\x{000D}", [[0, 0x000D]], [[0, 0x000D]]],
  ["ab\x{000D}", [[2, 0x000D]], [[2, 0x000D]]],
  ["ab\x{000C}\x{000D}", [[2, 0x000C], [3, 0x000D]], [[3, 0x000D]]],
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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         {type => 'attribute not defined',
          node => $el->attributes->[0],
          level => 'm'},
         map {
           +{type => $_->[1] == 0x000C ? 'U+000C not serializable' : 'U+000D not serializable',
             index => $_->[0],
             node => $el->attributes->[0],
             level => 'w'};
         } @{$test->[1]}];
    done $c;
  } n => 1, name => 'attr bad char warning';

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->manakai_is_html (1);
    my $el = $doc->create_element ('hoge');
    $el->set_attribute_ns (undef, hoge => $test->[0]);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         {type => 'attribute not defined',
          node => $el->attributes->[0],
          level => 'm'},
         map {
           +{type => $_->[1] == 0x000C ? 'U+000C not serializable' : 'U+000D not serializable',
             index => $_->[0],
             node => $el->attributes->[0],
             level => 'w'};
         } @{$test->[2]}];
    done $c;
  } n => 1, name => 'HTML attr bad char warning';

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
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         map {
           +{type => $_->[1] == 0x000C ? 'U+000C not serializable' : 'U+000D not serializable',
             index => $_->[0],
             node => $el->first_child,
             level => 'w'};
         } @{$test->[1]}];
    done $c;
  } n => 1, name => 'text bad char warnings';

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->strict_error_checking (0);
    $doc->manakai_is_html (1);
    my $el = $doc->create_element ('hoge');
    $el->text_content ($test->[0]);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($el);
    eq_or_diff \@error,
        [{type => 'element not defined',
          node => $el,
          level => 'm'},
         map {
           +{type => $_->[1] == 0x000C ? 'U+000C not serializable' : 'U+000D not serializable',
             index => $_->[0],
             node => $el->first_child,
             level => 'w'};
         } @{$test->[2]}];
    done $c;
  } n => 1, name => 'HTML text bad char warnings';
}

for my $test (
  ['shift_jis', 'x-sjis', 'Shift_JIS'],
  ['utf-8', 'UTF8', 'UTF-8'],
  ['windows-1252', 'US-ASCII', 'windows-1252'],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->input_encoding ($test->[0]);
    $doc->manakai_is_html (1);
    my $el = $doc->create_element ('meta');
    $el->set_attribute (charset => $test->[1]);
    $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
    $doc->manakai_head->append_child ($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($doc);
    eq_or_diff \@error,
        $test->[0] eq 'utf-8' ? [] :
            [{type => 'non-utf-8 character encoding',
              value => $test->[2],
              node => $doc, level => 's'}];
    done $c;
  } n => 1, name => ['charset', @$test];

  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->input_encoding ($test->[0]);
    $doc->manakai_is_html (1);
    my $el = $doc->create_element ('meta');
    $el->http_equiv ('Content-type');
    $el->content ('text/html;charset=' . $test->[1]);
    $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
    $doc->manakai_head->append_child ($el);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($doc);
    eq_or_diff \@error,
        $test->[0] eq 'utf-8' ? [] :
            [{type => 'non-utf-8 character encoding',
              value => $test->[2],
              node => $doc, level => 's'}];
    done $c;
  } n => 1, name => ['charset', @$test];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->input_encoding ('utf-16be');
  $doc->manakai_is_html (1);
  $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
  $doc->manakai_has_bom (1);
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'non-utf-8 character encoding',
                        value => 'UTF-16BE',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['UTF-16 BOM'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->input_encoding ('utf-16be');
  $doc->manakai_is_html (1);
  $doc->inner_html ('<!DOCTYPE html><html lang=en><meta http-equiv=Content-Type content="text/html; charset=UTF-16"><title>a</title><body>a');
  $doc->manakai_has_bom (1);
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'mismatched charset name',
                        node => $doc->get_elements_by_tag_name ('meta')
                            ->[0]->get_attribute_node_ns (undef, 'content'),
                        text => 'utf-16be',
                        value => 'utf-16le',
                        level => 'm'},
                       {type => 'charset:not ascii compat',
                        value => 'UTF-16BE',
                        node => $doc, level => 'm'},
                       {type => 'non-utf-8 character encoding',
                        value => 'UTF-16BE',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['UTF-16 BOM'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->input_encoding ('utf-16be');
  $doc->manakai_is_html (1);
  $doc->manakai_charset ('hogehoge');
  $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'non-utf-8 character encoding',
                        value => 'UTF-16BE',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['Content-Type charset=""'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->input_encoding ('utf-16be');
  $doc->manakai_is_html (1);
  $doc->manakai_is_srcdoc (1);
  $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'non-utf-8 character encoding',
                        value => 'UTF-16BE',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['iframe srcdoc'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->input_encoding ('windows-1251');
  $doc->manakai_is_html (1);
  $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'no character encoding declaration',
                        node => $doc, level => 'm'},
                       {type => 'non-utf-8 character encoding',
                        value => 'windows-1251',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['not labelled'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $$doc->[2]->{encoding} = 'ISO-2022-CN-EXT'; # XXX
  #$doc->input_encoding ('ISO-2022-CN-EXT');
  $doc->manakai_is_html (1);
  $doc->inner_html ('<!DOCTYPE html><html lang=en><title>a</title><body>a');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'charset:not ascii compat',
                        #value => 'ISO-2022-CN-EXT',
                        value  => undef,
                        node => $doc, level => 'm'},
                       {type => 'no character encoding declaration',
                        node => $doc, level => 'm'},
                       {type => 'non-utf-8 character encoding',
                        #value => 'ISO-2022-CN-EXT',
                        value => undef,
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['not labelled / replacement'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $$doc->[2]->{encoding} = 'shift_jis'; # XXX
  $doc->xml_encoding ('shift_jis');
  my $el = $doc->create_element ('meta');
  $el->set_attribute (charset => 'x-sjis');
  $doc->append_child ($el);
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args unless $args{type} =~ /^attribute/;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'element not allowed:root',
                        node => $el, level => 'm'},
                       {type => 'in XML:charset',
                        node => $el->attributes->[0], level => 'm'}];
  done $c;
} n => 1, name => ['XML <?xml encoding?> and <meta charset>'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $$doc->[2]->{encoding} = 'shift_jis'; # XXX
  my $el = $doc->create_element ('meta');
  $el->set_attribute (charset => 'x-sjis');
  $doc->append_child ($el);
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args unless $args{type} =~ /^attribute/;
  });
  $validator->check_node ($doc);
  eq_or_diff \@error, [{type => 'element not allowed:root',
                        node => $el, level => 'm'},
                       {type => 'in XML:charset',
                        node => $el->attributes->[0], level => 'm'},
                       {type => 'no xml encoding',
                        node => $doc, level => 's'}];
  done $c;
} n => 1, name => ['no XML <?xml encoding?> but <meta charset>'];

for my $test (
  [sub { }, [{type => 'no document element', level => 'w', node => 'doc'}]],
  [sub {
     my $doc = $_[0];
     my $p = $doc->append_child ($doc->create_element ('p'));
     $p->text_content ('b');
     return {p => $p};
   }, [{type => 'element not allowed:root', level => 'm', node => 'p'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $p = $doc->append_child ($doc->create_element ('p'));
     $p->text_content ('b');
     my $q = $doc->append_child ($doc->create_element ('q'));
     $q->text_content ('b');
     my $s = $doc->append_child ($doc->create_element ('s'));
     $s->text_content ('s');
     return {p => $p, q => $q, s => $s};
   },
   [{type => 'element not allowed:root', level => 'm', node => 'p'},
    {type => 'duplicate document element', level => 'm', node => 'q'},
    {type => 'duplicate document element', level => 'm', node => 's'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $p = $doc->append_child ($doc->create_document_type_definition ('q'));
     my $q = $doc->append_child ($doc->create_element ('q'));
     $q->text_content ('b');
     return {p => $p, q => $q};
   },
   [{type => 'element not allowed:root', level => 'm', node => 'q'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $q = $doc->append_child ($doc->create_element ('q'));
     $q->text_content ('b');
     my $p = $doc->append_child ($doc->create_document_type_definition ('q'));
     return {p => $p, q => $q};
   },
   [{type => 'element not allowed:root', level => 'm', node => 'q'},
    {type => 'doctype after element', level => 'm', node => 'p'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $p = $doc->append_child ($doc->create_document_type_definition ('q'));
     my $r = $doc->append_child ($doc->create_document_type_definition ('q'));
     my $q = $doc->append_child ($doc->create_element ('q'));
     $q->text_content ('b');
     return {p => $p, q => $q, r => $r};
   },
   [{type => 'element not allowed:root', level => 'm', node => 'q'},
    {type => 'duplicate doctype', level => 'm', node => 'r'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $p = $doc->append_child ($doc->create_document_type_definition ('q'));
     my $r = $doc->append_child ($doc->create_document_type_definition ('q'));
     return {p => $p, r => $r};
   },
   [{type => 'duplicate doctype', level => 'm', node => 'r'},
    {type => 'no document element', level => 'w', node => 'doc'}]],
  [sub {
     my $doc = $_[0];
     $doc->dom_config->{manakai_strict_document_children} = 0;
     my $p = $doc->append_child ($doc->create_text_node ('q'));
     return {p => $p};
   },
   [{type => 'root text', level => 'm', node => 'p'},
    {type => 'no document element', level => 'w', node => 'doc'}]],
  [sub {
     my $doc = $_[0];
     my $el = $doc->create_element_ns (undef, 'foo');
     $el->set_attribute_ns ('http://www.w3.org/1999/XSL/Transform', 'xsl:version', '1.0');
     $doc->append_child ($el);
     return {el => $el, attr => $el->attributes->[0]};
   },
   [{type => 'unknown namespace element', level => 'w', node => 'el',
     value => ''},
    {type => 'attribute not defined', level => 'm', node => 'attr'},
    # XXX{type => 'xslt:root literal result element', level => 's', node => 'el'},
   ]],
  [sub {
     my $doc = $_[0];
     my $el = $doc->create_element_ns ('http://www.w3.org/1999/XSL/Transform', 'foo');
     $el->set_attribute_ns ('http://www.w3.org/1999/XSL/Transform', 'xsl:version', '1.0');
     $doc->append_child ($el);
     return {el => $el, attr => $el->attributes->[0]};
   },
   [{type => 'element not defined', level => 'm', node => 'el'},
    {type => 'attribute not defined', level => 'm', node => 'attr'},
    {type => 'element not allowed:root', level => 'm', node => 'el'}]],
   [sub {
      my $doc = $_[0];
      $doc->manakai_is_html (1);
      $doc->manakai_charset ('utf-8');
      my $el = $doc->create_element_ns ('http://www.w3.org/2000/svg', 'svg');
      $doc->append_child ($el);
      return {el => $el};
    },
    [{type => 'unknown element', level => 'u', node => 'el'},
     {type => 'document element not serializable', level => 'w', node => 'el'}]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_html (0);
    my $map = $test->[0]->($doc);
    $map->{doc} = $doc;
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($doc);
    eq_or_diff [sort { $a->{type} cmp $b->{type} } @error],
        [sort { $a->{type} cmp $b->{type} }
         map { {%$_, node => $map->{$_->{node}}} } @{$test->[1]}];
    done $c;
  } n => 1, name => ['check_node', 'document'];
}

for my $test (
  [sub {
     my $doc = $_[0];
     my $text = $doc->create_text_node ("\x{110000}");
     return ($text, {text => $text});
   },
   [{type => 'text:bad char', value => 'U-00110000', index => 0,
     level => 'm', node => 'text'}]],
  [sub {
     my $doc = $_[0];
     my $df = $doc->create_document_fragment;
     my $text = $doc->create_text_node ("\x{110000}");
     $df->append_child ($text);
     my $el = $doc->create_element ('foo');
     $df->append_child ($el);
     return ($df, {df => $df, text => $text, foo => $el});
   },
   [{type => 'text:bad char', value => 'U-00110000', index => 0,
     level => 'm', node => 'text'},
    {type => 'element not defined', level => 'm', node => 'foo'}]],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_html (0);
    my ($node, $map) = $test->[0]->($doc);
    $map->{doc} = $doc;
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->check_node ($node);
    eq_or_diff [sort { $a->{type} cmp $b->{type} } @error],
        [sort { $a->{type} cmp $b->{type} }
         map { {%$_, node => $map->{$_->{node}}} } @{$test->[1]}];
    done $c;
  } n => 1, name => ['check_node', 'node'];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('br');
  $el->set_attribute (style => 'hoge: fuga');
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($el);
  eq_or_diff \@error,
      [{type => 'css:prop:unknown',
        value => 'hoge',
        level => 'm',
        node => $el->attributes->[0]}];
  done $c;
} n => 1, name => ['check_node', 'style="" with no line data'];

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('template');
  my $el2 = $doc->create_element ('p');
  $el->append_child ($el2);
  my $validator = Web::HTML::Validator->new;
  my @error;
  $validator->onerror (sub {
    my %args = @_;
    push @error, \%args;
  });
  $validator->check_node ($el);
  eq_or_diff [grep { $_->{type} !~ /^status:/ } @error],
      [{type => 'element not allowed:empty',
        level => 'm',
        node => $el2},
       {type => 'no significant content',
        level => 's',
        node => $el2}];
  done $c;
} n => 1, name => ['template content'];

for my $test (
  ['<p>abc', 'element not allowed:metadata'],
  ['<base href="http://a/">', 'element not allowed:head noscript'],
  ['<title>abc</title>', 'element not allowed:head noscript'],
  ['<noscript><link href="a" rel=next></noscript>', 'element not allowed:minus'],
  ['<noscript><base href="a"></noscript>', 'element not allowed:minus', 'element not allowed:head noscript'],
) {
  test {
    my $c = shift;
    my $doc = new Web::DOM::Document;
    $doc->manakai_is_html (1);
    my $el1 = $doc->create_element ('head');
    $el1->inner_html (q{<title>aa</title>});
    my $el2 = $doc->create_element ('noscript');
    $el2->text_content ($test->[0]);
    $el1->append_child ($el2);
    my $validator = Web::HTML::Validator->new;
    my @error;
    $validator->onerror (sub {
      my %args = @_;
      push @error, \%args;
    });
    $validator->scripting (1);
    $validator->check_node ($el1);
    eq_or_diff [grep { $_->{type} !~ /^status:/ } @error],
        [{type => $test->[1],
          level => 'm',
          node => $el2,
          di => 1, index => 0},
         ($test->[2] ? ({type => $test->[2],
                         di => 1, index => 0,
                         level => 'm',
                         node => $el2}) : ())];
    done $c;
  } n => 1, name => ['noscript scripting enabled', $test->[0]];
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('dir');
  my $val = new Web::HTML::Validator;
  my $preferred = [];
  $val->onerror (sub {
    my %args = @_;
    push @$preferred, $args{preferred};
  });
  $val->check_node ($el);
  eq_or_diff $preferred, [{type => 'html_element', name => 'ul'}];
  done $c;
} n => 1, name => 'obsolete element preferred';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  my $el = $doc->create_element ('p');
  $el->set_attribute (align => 'left');
  $el->text_content (1);
  my $val = new Web::HTML::Validator;
  my $preferred = [];
  $val->onerror (sub {
    my %args = @_;
    push @$preferred, $args{preferred};
  });
  $val->check_node ($el);
  eq_or_diff $preferred, [{type => 'css_prop', name => 'text-align'}];
  done $c;
} n => 1, name => 'obsolete attribute preferred';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  my $dids = [];
  $doc->inner_html (q{<!DOCTYPE HTML><title>y</title><iframe>x</iframe>});
  $doc->query_selector ('iframe')->set_attribute (srcdoc => "ho&xxy;");
  my $val = new Web::HTML::Validator;
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->di_data_set ($dids);
  $val->check_node ($doc);
  @$errors = grep { $_->{type} =~ /entity not declared/ } @$errors;
  is $errors->[0]->{di}, 0;
  is $errors->[0]->{index}, 2;
  done $c;
} n => 2, name => 'di_data_set no source document data';

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->manakai_is_html (1);
  my $dids = [undef, undef];
  $doc->inner_html (q{<!DOCTYPE HTML><title>y</title><iframe srcdoc="ho&amp;xxy;">x</iframe>});
  my $val = new Web::HTML::Validator;
  my $errors = [];
  $val->onerror (sub {
    my %args = @_;
    push @$errors, \%args;
  });
  $val->di_data_set ($dids);
  $val->check_node ($doc);
  @$errors = grep { $_->{type} =~ /entity not declared/ } @$errors;
  is $errors->[0]->{di}, 2;
  is $errors->[0]->{index}, 2;
  my ($di, $index) = resolve_index_pair ($dids, $errors->[0]->{di}, $errors->[0]->{index});
  is $di, 1;
  is $index, 49;
  done $c;
} n => 4, name => 'di_data_set has source document data';

run_tests;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
