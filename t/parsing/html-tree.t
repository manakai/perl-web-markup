package test::Web::HTML::Parser::tree;
use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::X1;
use Test::Differences;
use Test::HTCT::Parser;
use Encode;
sub bytes ($) { encode 'utf8', $_[0] }
my $DEBUG = $ENV{DEBUG};

my $test_dir_name = file (__FILE__)->dir->parent->parent->
    subdir ('t_deps/tests/html/parsing/manakai') . '/';
my $dir_name = file (__FILE__)->dir->parent->parent->
    subdir ('t_deps/tests/html/parsing/html5lib/html-tree') . '/';

use Data::Dumper;
$Data::Dumper::Useqq = 1;
{
  no warnings 'redefine';
  sub Data::Dumper::qquote {
    my $s = shift;
    return undef unless defined $s;
    eval {
      ## Perl 5.8.8/5.10.1 in some environment does not handle utf8
      ## string with surrogate code points well (it breaks the string
      ## when it is passed to another subroutine even when it can be
      ## accessible only via traversing reference chain, very
      ## strange...), so |eval| this statement.  It would not change
      ## the test result as long as our parser implementation passes
      ## the tests.
      $s =~ s/([^\x20\x21-\x26\x28-\x5B\x5D-\x7E])/sprintf '\x{%02X}', ord $1/ge;
      1;
    } or warn $@;
    return q<qq'> . $s . q<'>;
  } # Data::Dumper::qquote
}

sub compare_errors ($$;$) {
  my ($actual, $expected, $name) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 1;

  if (@$actual == @$expected) {
    ok 1, $name;
  } else {
    eq_or_diff $actual, $expected, $name;
  }
} # compare_errors

if ($DEBUG) {
  no warnings 'once';
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

use Web::HTML::Parser;
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
      my @def = split /\x0D?\x0A/, $test->{'document-fragment'}->[0];
      $test->{element} = shift @def;
      for (@def) {
        if (/^  ([^=]+)="([^"]+)"$/) {
          push @{$test->{element_attrs} ||= []}, [$1, $2];
        } else {
          die "Broken data: |$_|";
        }
      }
    }
  }

  my $doc = $dom->create_document;
  my @errors;
  my @shoulds;
  
  local $SIG{INT} = sub {
    print scalar dumptree ($doc);
    exit;
  };

  if ($test->{issrcdoc}->[1]) {
    $doc->manakai_is_srcdoc (1);
  }

  my $parser = new Web::HTML::Parser;
  $parser->onerror (sub {
    my %opt = @_;
    if ($opt{level} eq 's') {
      push @shoulds, join ':', grep { defined } $opt{line}, $opt{column}, $opt{value} // '', $opt{type}, $opt{text};
    } else {
      push @errors, join ':', grep { defined } $opt{line}, $opt{column}, $opt{value} // '', $opt{type}, $opt{text};
    }
  }); # onerror

  my $result;
  unless (defined $test->{element}) {
    $parser->parse_char_string ($test->{data}->[0] => $doc);
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
    for (@{$test->{element_attrs} or []}) {
      $el->set_attribute ($_->[0] => $_->[1]);
    }
    my $children = $parser->parse_char_string_with_context
        ($test->{data}->[0], $el, $dom->create_document);
    $el->append_child ($_) for $children->to_list;
    $result = dumptree ($el);
  }
  
#line 69 "HTML-tree.t test () skip"
  warn "No #errors section ($test->{data}->[0])" unless $test->{errors};
    
#line 1 "HTML-tree.t test () ok"
  compare_errors \@errors, $test->{errors}->[0] || [], 'Parse error';
  compare_errors \@shoulds, $test->{shoulds}->[0] || [], 'SHOULD-level error';

  $test->{document}->[0] .= "\x0A" if defined $test->{document}->[0] and length $test->{document}->[0];
  eq_or_diff $result, $test->{document}->[0], 'Document tree';
} # _test

my @FILES = (
  (glob dir ($test_dir_name)->file ('*.dat')),
  (glob dir ($dir_name)->file ('*.dat')),
);

for (@FILES) {
  my $file_name = $_;
  $file_name = $1 if $file_name =~ m{([^/]+)$};
  for_each_test ($_, {
    data => {is_prefixed => 1},
    errors => {is_list => 1},
    shoulds => {is_list => 1},
    document => {is_prefixed => 1},
    'document-fragment' => {is_prefixed => 1},
  }, sub {
    my $test = $_[0];
    test {
      _test ($test);
      $_[0]->done;
    } n => 3, name => [$file_name, Data::Dumper::qquote $test->{data}->[0]];
  });
}

run_tests;

undef $dom;
## License: Public Domain.
