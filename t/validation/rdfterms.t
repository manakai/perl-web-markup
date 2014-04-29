use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use Test::Differences;
use Test::HTCT::Parser;
use Web::RDF::Checker;
use Web::DOM::Document;

my $data_path = path (__FILE__)->parent->parent->parent
    ->child ('t_deps/tests/rdf/term-validation');
for my $path (($data_path->children (qr/\.dat$/))) {
  for_each_test ($path, {
    data => {is_prefixed => 1},
    errors => {is_list => 1},
  }, sub {
    my $test = shift;
    test {
      my $c = shift;
      my $term = {};
      if ($test->{data}->[0] =~ /^<(.*?)>$/) {
        $term->{url} = $1;
      } elsif ($test->{data}->[0] =~ /^"(.*?)"$/) {
        $term->{lexical} = $1;
      } elsif ($test->{data}->[0] =~ /^"(.*?)"\^\^<(.*?)>$/) {
        $term->{lexical} = $1;
        $term->{datatype_url} = $2;
      } elsif ($test->{data}->[0] =~ /^"(.*?)"\@(.*?)$/) {
        $term->{lexical} = $1;
        $term->{lang} = $2;
      } elsif ($test->{data}->[0] =~ /^_:(.+)$/) {
        $term->{bnodeid} = $1;
      } elsif ($test->{data}->[0] =~ /^XML\^\^(.*?)\^\^$/) {
        my $doc = new Web::DOM::Document;
        my $df = $doc->create_document_fragment;
        $df->inner_html ($1);
        $term->{parent_node} = $df;
        $term->{datatype_url} = q<http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral>;
      } else {
        die "Input data not supported: |$test->{data}->[0]|";
      }
      my $checker = Web::RDF::Checker->new;
      my @error;
      $checker->onerror (sub {
        my %args = @_;
        push @error, join ';',
            $args{index} || 0,
            $args{type},
            $args{text} || '',
            $args{value} || '',
            $args{level};
      });
      $checker->check_parsed_term ($term);
      @error = sort { $a cmp $b } @error;
      eq_or_diff \@error, [sort { $a cmp $b } @{$test->{errors}->[0] or []}];
      done $c;
    } n => 1, name => [$path->relative ($data_path), $test->{data}->[0]];
  });
}

run_tests;

## License: Public Domain.
