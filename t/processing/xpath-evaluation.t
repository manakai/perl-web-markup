use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::HTCT::Parser;
use Test::Differences;
use Web::XPath::Parser;
use Web::XPath::Evaluator;
use Web::DOM::Document;
use Web::HTML::Parser;
use Web::XML::Parser;

my $documents = {};

sub get_node_path ($) {
  my $node = shift;
  my $r = '';
  if ($node->node_type == $node->DOCUMENT_NODE) {
    return '/';
  }
  if ($node->node_type == $node->ATTRIBUTE_NODE) {
    $r = '/@' . $node->node_name;
    $node = $node->owner_element or return $r;
  }
  my $parent = $node->parent_node;
  while ($parent) {
    my $i = 0;
    for (@{$parent->child_nodes}) {
      $i++;
      if ($_ eq $node) {
        $r = '/' . $i . $r;
      }
    }
    ($parent, $node) = ($parent->parent_node, $parent);
  }
  return $r;
} # get_node_path

sub get_node_by_path ($$) {
  my ($doc, $path) = @_;
  if ($path eq '/') {
    return $doc;
  } else {
    for (grep {$_} split m#/#, $path) {
      if ($_ =~ /^\@(.+)$/) {
        $doc = $doc->get_attribute_node ($1) or die "No $_";
      } else {
        $doc = $doc->child_nodes->[$_ - 1] or die "No $_";
      }
    }
    return $doc;
  }
} # get_node_by_path

for my $f (grep { -f and /\.dat$/ } file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'xpath', 'evaluation')->children) {
  $documents->{$f, ''} = new Web::DOM::Document;

  for_each_test ($f->stringify, {
    data => {is_prefixed => 1},
    errors => {is_list => 1, multiple => 1},
    result => {is_prefixed => 1, multiple => 1},
    ns => {is_list => 1},
    html => {is_prefixed => 1},
    xml => {is_prefixed => 1},
  }, sub {
    my $test = shift;

    if ($test->{html}) {
      my $doc = new Web::DOM::Document;
      my $doc_name = $test->{html}->[1]->[0];
      if (exists $documents->{$f, $doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }

      $doc->manakai_is_html (1);
      my $parser = Web::HTML::Parser->new;
      $parser->parse_char_string ($test->{html}->[0] => $doc);
      $documents->{$f, $doc_name} = $doc;
      return;
    } elsif ($test->{xml}) {
      my $doc = new Web::DOM::Document;
      my $doc_name = $test->{xml}->[1]->[0];
      if (exists $documents->{$f, $doc_name}) {
        warn "# Document |$doc_name| is already defined\n";
      }

      my $parser = Web::XML::Parser->new;
      $parser->parse_char_string ($test->{xml}->[0] => $doc);
      $documents->{$f, $doc_name} = $doc;
      return;
    }

    test {
      my $c = shift;

      my %ns;
      for (@{$test->{ns}->[0] or []}) {
        if (/^(\S+)\s+(\S+)$/) {
          $ns{$1} = $2 eq '<null>' ? undef : $2 eq '<empty>' ? '' : $2;
        } elsif (/^(\S+)$/) {
          $ns{''} = $1 eq '<null>' ? undef : $1 eq '<empty>' ? '' : $1;
        }
      }

      my $lookup_ns = sub {
        return $ns{defined $_[0] ? $_[0] : ''};
      }; # lookup_namespace_uri

      my $parser = Web::XPath::Parser->new;
      $parser->ns_resolver ($lookup_ns);
      my $parsed = $parser->parse_char_string_as_expression
          ($test->{data}->[0]);

      my $evaluator = Web::XPath::Evaluator->new;
      my @error;
      $evaluator->onerror (sub {
        my %args = @_;
        push @error, join ';', $args{level}, $args{type}, defined $args{value} ? $args{value} : '';
      });

      my $xerrors = {};
      for (@{$test->{errors} or []}) {
        my $label = $_->[1]->[0];
        $label = '' unless defined $label;
        my $root = $_->[1]->[1];
        $root = '/' unless defined $root;
        $xerrors->{$label, $root} = $_;
      }

      for my $result (@{$test->{result} or []}) {
        my $label = $result->[1]->[0];
        $label = '' unless defined $label;
        my $root = $result->[1]->[1];
        $root = '/' unless defined $root;
        my $doc = $documents->{$f, $label} or die "Test |$label| not found\n";
        my $root_node = get_node_by_path ($doc, $root);
        @error = ();

        test {
          my $r = $evaluator->evaluate ($parsed, $root_node);

          my $actual;
          if (not defined $r) {
            $actual = 'null';
          } elsif ($r->{type} eq 'number') {
            $actual = {
              '-0' => '0',
              'inf' => 'Infinity',
              'Inf' => 'Infinity',
              '-inf' => '-Infinity',
              '-Inf' => '-Infinity',
              'nan' => 'NaN',
              '-nan' => 'NaN',
              'NaN' => 'NaN',
            }->{$r->{value}} // $r->{value};
          } elsif ($r->{type} eq 'boolean') {
            $actual = $r->{value} ? 'true' : 'false';
          } elsif ($r->{type} eq 'string') {
            $actual = '"' . $r->{value} . '"';
          } elsif ($r->{type} eq 'node-set') {
            $evaluator->sort_node_set ($r);
            $actual = join "\n", map { get_node_path $_ } @{$r->{value}};
          } else {
            die "Unknown result value type |$r->{type}|";
          }

          eq_or_diff $actual, $result->[0];
          eq_or_diff \@error, $xerrors->{$label, $root}->[0] || [];
        } $c, name => [$label, $root];
      }

      done $c;
    } n => 2 * @{$test->{result}}, name => [$f->basename, $test->{data}->[0]];
  });
} # $f

run_tests;

=head1 LICENSE

Copyright 2013-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
