use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Encode;
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

sub _test ($$) {
  my ($test, $c) = @_;
  my $data = $test->{data}->[0];
  warn "No #errors section ($test->{data}->[0])" unless $test->{errors};

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
  my $p = Web::XML::Parser->new;
  my $ges = $p->{ge} ||= {};
  my $pes = $p->{pe} ||= {};

  my @errors;
  $p->onerror (sub {
    my %opt = @_;
    push @errors, join ';',
        ($opt{di} ? "[$opt{di}]" : '') . ($opt{line} || $opt{token}->{line}),
        defined $opt{column} ? $opt{column} : $opt{token}->{column},
        $opt{type},
        defined $opt{text} ? $opt{text} : '',
        defined $opt{value} ? $opt{value} : '',
        $opt{level};
  }); # onerror

  my $result;
  my $code = sub {
    @errors = sort {$a cmp $b} @errors;
    @{$test->{errors}->[0]} = sort {$a cmp $b} @{$test->{errors}->[0] ||= []};
    eq_or_diff \@errors, $test->{errors}->[0] || [], 'Parse error';

    is $doc->xml_version, ($test->{'xml-version'} or ['1.0'])->[0], 'version';

    my $enc = ($test->{'xml-encoding'} or ['null']);
    $enc = $enc->[0] || $enc->[1]->[0] || '';
    is $doc->xml_encoding, $enc eq 'null' ? undef : $enc, 'encoding';

    my $standalone = ($test->{'xml-standalone'} or ['no']);
    $standalone = $standalone->[0] || $standalone->[1]->[0];
    is $doc->xml_standalone ? 1 : 0, $standalone eq 'true' ? 1 : 0, 'standalone';

    if ($test->{entities}) {
      my @e;
      for (sort { $a cmp $b } keys %$ges) {
        my $ent = $ges->{$_};
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
      for (sort { $a cmp $b } keys %$pes) {
        my $ent = $pes->{$_};
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
    } else {
      ok 1;
    }
    
    $test->{document}->[0] .= "\x0A" if length $test->{document}->[0];
    eq_or_diff $result, $test->{document}->[0], 'Document tree';
    done $c;
    undef $c;
  }; # $code

  if (defined $test->{resource}) {
    my %res;
    my $i = 0;
    for (@{$test->{resource}}) {
      $res{defined $_->[1]->[0] ? $_->[1]->[0] : ''} = [++$i, $_->[0]];
    }
    $p->onextentref (sub {
      my ($parser, $ent, $subparser) = @_;
      my $e = $res{$ent->{entdef}->{sysid}}; # XXX
      $subparser->di ($e->[0]) if defined $e;
      $subparser->parse_bytes_start ('utf-8');
      $subparser->parse_bytes_feed (encode 'utf-8', $e->[1]) if defined $e;
      $subparser->parse_bytes_end;
    });
    $p->onparsed (sub {
      test {
        $result = dumptree ($doc);
        $code->();
      } $c;
    });

    $p->parse_bytes_start (undef, $doc);
    $p->parse_bytes_feed (encode 'utf-8', $test->{data}->[0]);
    $p->parse_bytes_end;
  } elsif (not defined $test->{element}) {
    $p->parse_char_string ($test->{data}->[0] => $doc);
    $result = dumptree ($doc);
    $code->();
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
    $code->();
  }
} # _test

for my $file_name (@FILES) {
  for_each_test ($file_name, {
    data => {is_prefixed => 1},
    resource => {multiple => 1, is_prefixed => 1},
    errors => {is_list => 1},
    document => {is_prefixed => 1},
    'document-fragment' => {is_prefixed => 1},
    entities => {is_prefixed => 1},
  }, sub {
    my $test = $_[0];
    test {
      my $c = shift;
      _test ($test, $c);
    } n => 6, name => [$file_name, $test->{data}->[0]];
  });
}

run_tests;

undef $dom;

## License: Public Domain.
