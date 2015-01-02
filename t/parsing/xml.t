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
use Web::HTML::SourceMap;

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

  my $ip = [];
  my $main_di = 0;
  $p->di (0);
  $ip->[$main_di]->{data} = $test->{data}->[0];
  $ip->[$main_di]->{lc_map} = create_index_lc_mapping $ip->[$main_di]->{data};
  my $url_to_di = {};
  for (0..$#{$test->{resource} or []}) {
    my $res = $test->{resource}->[$_];
    $ip->[$_+1]->{data} = $res->[0];
    $ip->[$_+1]->{lc_map} = create_index_lc_mapping $ip->[$_+1]->{data};
    $ip->[$_+1]->{url} = $res->[1]->[0]; # or undef
    $url_to_di->{$res->[1]->[0]} = $_+1 if defined $res->[1]->[0];
  }
  $p->di_data_set ($ip);

  my @errors;
  $p->onerror (sub {
    my %opt = @_;
    my ($di, $index) = resolve_index_pair $ip, $opt{di}, $opt{index};
    my ($l, $c) = index_pair_to_lc_pair $ip, $di, $index;
    push @errors, join ';',
        ($di != $main_di ? "[$di]" : '') . ($l || 0), ($c || 0),
        $opt{type},
        defined $opt{text} ? $opt{text} : '',
        defined $opt{value} ? $opt{value} : '',
        $opt{level};
  }); # onerror

  if ($test->{checker}) {
    $p->strict_checker
        ('Web::XML::Parser::' . $test->{checker}->[1]->[-1] . 'Checker');
  }

  my $result;
  my $ges;
  my $pes;
  my $code = sub {
    my @expected = sort {$a cmp $b} @{$test->{errors}->[0] ||= []};
    @errors = sort {$a cmp $b} @errors;
    eq_or_diff \@errors, \@expected, 'Parse error';

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
        $v .= join '', map { $_->[0] } @{$ent->{value} or []};
        $v .= '" "';
        $v .= $ent->{public_identifier} if defined $ent->{public_identifier};
        $v .= '" "';
        $v .= $ent->{system_identifier} if defined $ent->{system_identifier};
        $v .= '" ';
        $v .= $ent->{notation_name} if defined $ent->{notation_name};
        $v .= '>';
        push @e, $v;
      }
      for (sort { $a cmp $b } keys %$pes) {
        my $ent = $pes->{$_};
        my $v = '<!ENTITY % ' . $ent->{name} . ' "'; 
        $v .= join '', map { $_->[0] } @{$ent->{value} or []};
        $v .= '" "';
        $v .= $ent->{public_identifier} if defined $ent->{public_identifier};
        $v .= '" "';
        $v .= $ent->{system_identifier} if defined $ent->{system_identifier};
        $v .= '" ';
        $v .= $ent->{notation_name} if defined $ent->{notation_name};
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
    $p->onextentref (sub {
      my ($parser, $data, $subparser) = @_;
      my $di = defined $data->{entity}->{system_identifier} ? $url_to_di->{$data->{entity}->{system_identifier}} : undef;
      if (defined $di) {
        $subparser->di ($di);
        $subparser->parse_bytes_start ('utf-8', $parser);
        $subparser->parse_bytes_feed (encode 'utf-8', $ip->[$di]->{data});
        $subparser->parse_bytes_end;
      } else {
        # XXX
        $subparser->parse_bytes_start ('utf-8', $parser);
        $subparser->parse_bytes_feed ('<?xml encoding="utf-8"?>');
        $subparser->parse_bytes_end;
      }
    });
    $p->onparsed (sub {
      my $p = $_[0];
      test {
        $result = dumptree ($doc);
        $ges = $p->{saved_maps}->{DTDDefs}->{ge} ||= {};
        $pes = $p->{saved_maps}->{DTDDefs}->{pe} ||= {};
        $code->();
      } $c;
    });

    $p->parse_bytes_start (undef, $doc);
    $p->parse_bytes_feed (encode 'utf-8', $ip->[$main_di]->{data});
    $p->parse_bytes_end;
  } elsif (not defined $test->{element}) {
    $p->onparsed (sub {
      my $p = $_[0];
      test {
        $result = dumptree ($doc);
        $ges = $p->{saved_maps}->{DTDDefs}->{ge} ||= {};
        $pes = $p->{saved_maps}->{DTDDefs}->{pe} ||= {};
        $code->();
      } $c;
    });
    $p->parse_char_string ($ip->[$main_di]->{data} => $doc);
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
        ($ip->[$main_di]->{data}, $el, $dom->create_document);
    if ($el->manakai_element_type_match ('http://www.w3.org/1999/xhtml', 'template')) {
      $el->content->append_child ($_) for $children->to_list;
    } else {
      $el->append_child ($_) for $children->to_list;
    }
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
