use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib');
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib');
use Test::X1;
use Test::Differences;
use Web::RDF::XML::Parser;
use Web::DOM::Document;

for my $test (
  [q{
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description xmlns="http://www.example.org/" rdf:about="http://abc/">
        <foo rdf:resource="http://xyz/"/>
      </rdf:Description>
    </rdf:RDF>
  } => [
    {subject => {url => q<http://abc/>},
     predicate => {url => q<http://www.example.org/foo>},
     object => {url => q<http://xyz/>}},
  ]],
  [q{
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description xmlns="http://www.example.org/" rdf:about="http://abc/">
        <foo rdf:resource="fuga/" xml:base="http://hoge.TEST"/>
      </rdf:Description>
    </rdf:RDF>
  } => [
    {subject => {url => q<http://abc/>},
     predicate => {url => q<http://www.example.org/foo>},
     object => {url => q<http://hoge.test/fuga/>}},
  ]],
  [q{
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description xmlns="http://www.example.org/" rdf:about="http://abc/">
        <foo rdf:resource="fuga/" xml:base="http://hoge.TEST"/>
      </rdf:Description>
      <bar xmlns="http://abc/" xml:lang="en">
        <xxy>ab</xxy>
      </bar>
    </rdf:RDF>
  } => [
    {subject => {url => q<http://abc/>},
     predicate => {url => q<http://www.example.org/foo>},
     object => {url => q<http://hoge.test/fuga/>}},
    {subject => {bnodeid => 'g0'},
     predicate => {url => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>},
     object => {url => q<http://abc/bar>}},
    {subject => {bnodeid => 'g0'},
     predicate => {url => q<http://abc/xxy>},
     object => {lexical => 'ab', lang => 'en'}},
  ]],
  [q{
    <Fuga xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:about="" xml:base="about:blank" xmlns="http://www.example.org/">
      <abc rdf:datatype="http://www.example.org/hogehoge">ddd</abc>
    </Fuga>
  } => [
    {subject => {url => q<about:blank>},
     predicate => {url => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>},
     object => {url => q<http://www.example.org/Fuga>}},
    {subject => {url => q<about:blank>},
     predicate => {url => q<http://www.example.org/abc>},
     object => {lexical => 'ddd', datatype_url => 'http://www.example.org/hogehoge'}},
  ]],
) {
  test {
    my $c = shift;
    my $rdf = Web::RDF::XML::Parser->new;
    my $doc = new Web::DOM::Document;
    $doc->inner_html ($test->[0]);
    my @result;
    $rdf->ontriple (sub {
      push @result, {@_};
    });
    $rdf->convert_document ($doc);
    for (@result) {
      delete $_->{node};
      delete $_->{id} if not defined $_->{id};
    }
    eq_or_diff \@result, $test->[1];
    done $c;
  } n => 1;
}

test {
  my $c = shift;
  my $doc = new Web::DOM::Document;
  $doc->inner_html (q{
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description>
        <hoge xmlns="http://foo/">
          <rdf:Description rdf:nodeID="foo"/>
        </hoge>
      </rdf:Description>
    </rdf:RDF>
  });
  my $rdf = new Web::RDF::XML::Parser;
  $rdf->onbnodeid (sub { "ID=[$_[0]]" });
  my @node;
  $rdf->ontriple (sub {
    my %args = @_;
    push @node, $args{subject}->{bnodeid};
    push @node, $args{object}->{bnodeid};
  });
  $rdf->convert_document ($doc);
  eq_or_diff \@node, ['ID=[g0]', 'ID=[bfoo]'];
  done $c;
} n => 1;

run_tests;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
