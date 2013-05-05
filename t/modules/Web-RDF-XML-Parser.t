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
    {subject => {uri => q<http://abc/>},
     predicate => {uri => q<http://www.example.org/foo>},
     object => {uri => q<http://xyz/>}},
  ]],
  [q{
    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
      <rdf:Description xmlns="http://www.example.org/" rdf:about="http://abc/">
        <foo rdf:resource="fuga/" xml:base="http://hoge.TEST"/>
      </rdf:Description>
    </rdf:RDF>
  } => [
    {subject => {uri => q<http://abc/>},
     predicate => {uri => q<http://www.example.org/foo>},
     object => {uri => q<http://hoge.test/fuga/>}},
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
    {subject => {uri => q<http://abc/>},
     predicate => {uri => q<http://www.example.org/foo>},
     object => {uri => q<http://hoge.test/fuga/>}},
    {subject => {bnodeid => 'g0'},
     predicate => {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>},
     object => {uri => q<http://abc/bar>}},
    {subject => {bnodeid => 'g0'},
     predicate => {uri => q<http://abc/xxy>},
     object => {value => 'ab', language => 'en'}},
  ]],
  [q{
    <Fuga xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:about="" xml:base="about:blank" xmlns="http://www.example.org/">
      <abc rdf:datatype="http://www.example.org/hogehoge">ddd</abc>
    </Fuga>
  } => [
    {subject => {uri => q<about:blank>},
     predicate => {uri => q<http://www.w3.org/1999/02/22-rdf-syntax-ns#type>},
     object => {uri => q<http://www.example.org/Fuga>}},
    {subject => {uri => q<about:blank>},
     predicate => {uri => q<http://www.example.org/abc>},
     object => {value => 'ddd', datatype => 'http://www.example.org/hogehoge'}},
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

run_tests;

=head1 LICENSE

Copyright 2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
