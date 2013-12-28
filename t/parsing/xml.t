use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::HTCT::Parser;
use Test::X1;

my $DEBUG = $ENV{DEBUG};

my @FILES = glob (file (__FILE__)->dir->parent->parent->
    subdir ('t_deps/tests/xml/parsing/manakai')->file ('*.dat'));

use Data::Dumper;
$Data::Dumper::Useqq = 1;
sub Data::Dumper::qquote {
  my $s = shift;
  eval {
    ## Perl 5.8.8/5.10.1 in some environment does not handle utf8
    ## string with surrogate code points well (it breaks the string
    ## when it is passed to another subroutine even when it can be
    ## accessible only via traversing reference chain, very
    ## strange...), so |eval| this statement.  It would not change the
    ## test result as long as our parser implementation passes the
    ## tests.
    $s =~ s/([^\x20\x21-\x26\x28-\x5B\x5D-\x7E])/sprintf '\x{%02X}', ord $1/ge;
    1;
  } or warn $@;
  return q<qq'> . $s . q<'>;
} # Data::Dumper::qquote

if ($DEBUG) {
  my $not_found = {%{$Web::HTML::Debug::cp or {}}};
  $Web::HTML::Debug::cp_pass = sub {
    my $id = shift;
    delete $not_found->{$id};
  };

  END {
    for my $id (sort {$a <=> $b || $a cmp $b} keys %$not_found) {
      print "# checkpoint $id is not reached\n";
    }
  }
}

use Web::XML::Parser;
use Web::HTML::Dumper qw/dumptree/;

my $dom_class = $ENV{DOM_IMPL_CLASS} || 'Web::DOM::Implementation';
eval qq{ require $dom_class } or die $@;
my $dom = $dom_class->new;

sub _test ($) {
  my $test = shift;
  my $data = $test->{data}->[0];

  if ($test->{skip}->[1]->[0]) {
#line 1 "HTML-tree.t test () skip"
    SKIP: {
      skip "", 1;
    }
    return;
  }

  if ($test->{'document-fragment'}) {
    if (@{$test->{'document-fragment'}->[1]}) {
      ## NOTE: Old format.
      $test->{element} = $test->{'document-fragment'}->[1]->[0];
      $test->{document} ||= $test->{'document-fragment'};
    } else {
      ## NOTE: New format.
      $test->{element} = $test->{'document-fragment'}->[0];
    }
  }

  my $doc = $dom->create_document;
  my @errors;
  
  local $SIG{INT} = sub {
    print scalar dumptree ($doc);
    exit;
  };

  my $p = Web::XML::Parser->new;
  $p->onerror (sub {
    my %opt = @_;
    push @errors, join ';',
        $opt{token}->{line} || $opt{line},
        $opt{token}->{column} || $opt{column},
        $opt{type},
        defined $opt{text} ? $opt{text} : '',
        defined $opt{value} ? $opt{value} : '',
        $opt{level};
  }); # onerror

  my $result;
  unless (defined $test->{element}) {
    $p->parse_char_string ($test->{data}->[0] => $doc);
    $result = dumptree ($doc);
  } else {
    my $el;
    if ($test->{element} =~ s/^svg\s*//) {
      $el = $doc->create_element_ns
          (q<http://www.w3.org/2000/svg>, [undef, $test->{element}]);
    } elsif ($test->{element} =~ s/^math\s*//) {
      $el = $doc->create_element_ns
          (q<http://www.w3.org/1998/Math/MathML>, [undef, $test->{element}]);
    } elsif ($test->{element} =~ s/^\{([^{}]*)\}\s*//) {
      $el = $doc->create_element_ns ($1, [undef, $test->{element}]);
    } else {
      $el = $doc->create_element_ns
          (q<http://www.w3.org/1999/xhtml>, [undef, $test->{element}]);
    }
    my $children = $p->parse_char_string_with_context
        ($test->{data}->[0], $el, $dom->create_document);
    $el->append_child ($_) for $children->to_list;
    $result = dumptree ($el);
  }
  
  warn "No #errors section ($test->{data}->[0])" unless $test->{errors};

  @errors = sort {$a cmp $b} @errors;
  @{$test->{errors}->[0]} = sort {$a cmp $b} @{$test->{errors}->[0] ||= []};
  
#line 60 "HTML-tree.t test () skip"
  eq_or_diff join ("\n", @errors), join ("\n", @{$test->{errors}->[0] or []}),
      'Parse error';

  if ($test->{'xml-version'}) {
    is $doc->xml_version,
        $test->{'xml-version'}->[0], 'XML version';
  } else {
    is $doc->xml_version, '1.0', 'XML version';
  }

  if ($test->{'xml-encoding'}) {
    if (($test->{'xml-encoding'}->[1]->[0] // '') eq 'null') {
      is $doc->xml_encoding, undef, 'XML encoding';
    } else {
      is $doc->xml_encoding, $test->{'xml-encoding'}->[0], 'XML encoding';
    }
  } else {
    is $doc->xml_encoding, undef, 'XML encoding';
  }

  if ($test->{'xml-standalone'}) {
    is $doc->xml_standalone ? 1 : 0,
        ($test->{'xml-standalone'}->[0] || $test->{'xml-standalone'}->[1]->[0])
            eq 'true' ? 1 : 0, 'XML standalone';
  } else {
    is $doc->xml_standalone ? 1 : 0, 0, 'XML standalone';
  }

  if ($test->{entities}) {
    my @e;
    for (keys %{$p->{ge}}) {
      my $ent = $p->{ge}->{$_};
      my $v = '<!ENTITY ' . $ent->{name} . ' "'; 
      $v .= $ent->{value} if defined $ent->{value};
      $v .= '" "';
      $v .= $ent->{pubid} if defined $ent->{pubid};
      $v .= '" "';
      $v .= $ent->{sysid} if defined $ent->{sysid};
      $v .= '" ';
      $v .= $ent->{notation} if defined $ent->{notation};
      $v .= '>';
      push @e, $v;
    }
    for (keys %{$p->{pe}}) {
      my $ent = $p->{pe}->{$_};
      my $v = '<!ENTITY % ' . $ent->{name} . ' "'; 
      $v .= $ent->{value} if defined $ent->{value};
      $v .= '" "';
      $v .= $ent->{pubid} if defined $ent->{pubid};
      $v .= '" "';
      $v .= $ent->{sysid} if defined $ent->{sysid};
      $v .= '" ';
      $v .= $ent->{notation} if defined $ent->{notation};
      $v .= '>';
      push @e, $v;
    }
    eq_or_diff join ("\x0A", @e), $test->{entities}->[0], 'Entities';
  }
  
  $test->{document}->[0] .= "\x0A" if length $test->{document}->[0];
  eq_or_diff $result, $test->{document}->[0], 'Document tree';
} # _test

for my $file_name (@FILES) {
  for_each_test ($file_name, {
    errors => {is_list => 1},
    document => {is_prefixed => 1},
    'document-fragment' => {is_prefixed => 1},
    entities => {is_prefixed => 1},
  }, sub {
    my $test = $_[0];
    test {
      my $c = shift;
      _test ($test);
      done $c;
    } n => 5, name => [$file_name, $test->{data}->[0]];
  });
}

run_tests;

undef $dom;

## License: Public Domain.
