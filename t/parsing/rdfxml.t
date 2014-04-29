use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Data::Dumper;
use Test::More;
use Test::X1;
use Test::Differences;
use Test::HTCT::Parser;
use Web::DOM::Document;
use Web::XML::Parser;
use Web::RDF::XML::Parser;

sub _rdf_value ($) {
  my $resource = $_[0];
  if (defined $resource->{url}) {
    return '<' . $resource->{url} . '>';
  } elsif (defined $resource->{bnodeid}) {
    return '_:' . $resource->{bnodeid};
  } elsif (defined $resource->{parent_node}) {
    return '"' . $resource->{parent_node}->inner_html .
        '"^^<' . $resource->{datatype_url} . '>';
  } elsif (defined $resource->{lexical}) {
    return '"' . $resource->{lexical} . '"' .
        (defined $resource->{datatype_url}
         ? '^^<' . $resource->{datatype_url} . '>'
         : (defined $resource->{lang} ? '@' . $resource->{lang} : ''));
  } else {
    return '???:' . Dumper $resource;
  }
} # _rdf_value

sub get_node_path ($) {
  my $node = shift;
  my @r;
  while (defined $node) {
    my $rs;
    if ($node->node_type == 1) {
      $rs = $node->manakai_local_name;
      $node = $node->parent_node;
    } elsif ($node->node_type == 2) {
      $rs = '@' . $node->manakai_local_name;
      $node = $node->owner_element;
    } elsif ($node->node_type == 3) {
      $rs = '"' . $node->data . '"';
      $node = $node->parent_node;
    } elsif ($node->node_type == 9) {
      $rs = '';
      $node = $node->parent_node;
    } elsif ($node->node_type == 7) {
      $rs = '<?' . $node->target . '?>';
      $node = $node->parent_node;
    } elsif ($node->node_type == 11) {
      $rs = '#df';
      $node = $node->parent_node;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return join ('/', @r) || '/';
} # get_node_path

my $data_path = path (__FILE__)->parent->parent->parent
    ->child ('t_deps/tests/rdf/xml/parsing');
for my $path (($data_path->children (qr/\.dat$/))) {
  for_each_test ($path, {
    data => {is_prefixed => 1},
    errors => {is_list => 1},
    triples => {is_list => 1},
    nonrdf => {is_list => 1, is_prefixed => 1},
    attrs => {is_list => 1, is_prefixed => 1},
  }, sub {
    my $test = shift;
    test {
      my $c = shift;
      my $doc = new Web::DOM::Document;
      my $el = $doc->create_element ('div');
      $el->prefix ('hoge151251122');
      my $p = new Web::XML::Parser;
      $p->onerror (sub { });
      if ($test->{data}->[0] =~ /<!DOCTYPE/) {
        $p->parse_char_string ($test->{data}->[0] => $doc);
      } else {
        my $nodes = $p->parse_char_string_with_context
            ($test->{data}->[0], $el => $doc);
        $doc = new Web::DOM::Document;
        $doc->dom_config->{manakai_strict_document_children} = 0;
        shift @$nodes while @$nodes and
            $nodes->[0]->node_type == 3 and
            $nodes->[0]->text_content =~ /\A\s+\z/;
        pop @$nodes while @$nodes and
            $nodes->[-1]->node_type == 3 and
            $nodes->[-1]->text_content =~ /\A\s+\z/;
        $doc->append_child ($_) for @$nodes;
      }
      my $parser = new Web::RDF::XML::Parser;
      my @error;
      $parser->onerror (sub {
        my %args = @_;
        push @error, join ';',
            get_node_path $args{node},
            $args{type},
            $args{text} || '',
            $args{value} || '',
            $args{level};
      });
      my @triple;
      $parser->ontriple (sub {
        my %args = @_;
        push @triple, join ' ',
            get_node_path $args{node},
            _rdf_value $args{subject},
            _rdf_value $args{predicate},
            _rdf_value $args{object};
      });
      my @nonrdf;
      $parser->onnonrdfnode (sub {
        push @nonrdf, get_node_path $_[0];
      });
      my @attr;
      $parser->onattr (sub {
        push @attr,
            join " ",
                get_node_path $_[0],
                $_[1];
      });
      $parser->convert_document ($doc);
      @error = sort { $a cmp $b } @error;
      @triple = sort { $a cmp $b } @triple;
      eq_or_diff \@triple, [sort { $a cmp $b } @{$test->{triples}->[0] or []}];
      eq_or_diff \@error, [sort { $a cmp $b } @{$test->{errors}->[0] or []}];
      eq_or_diff \@nonrdf, $test->{nonrdf}->[0] || [], 'nonrdf';
      eq_or_diff \@attr, $test->{attrs}->[0] || [], 'attrs';
      done $c;
    } n => 4, name => [$path->relative ($data_path), $test->{data}->[0]];
  });
}

run_tests;

## License: Public Domain.
