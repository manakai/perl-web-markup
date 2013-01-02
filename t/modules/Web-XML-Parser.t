package test::Web::XML::Parser;
use strict;
use warnings;
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', 'testdataparser', 'lib')->stringify;
use base qw(Test::Class);
use Test::More;
use Test::Differences;
use Web::XML::Parser;
use NanoDOM;

sub _xml_parser_gc : Test(2) {
  my $parser_destroy_called = 0;
  my $doc_destroy_called = 0;

  no warnings 'redefine';
  no warnings 'once';
  local *Web::XML::Parser::DESTROY = sub { $parser_destroy_called++ };
  local *NanoDOM::Document::DESTROY = sub { $doc_destroy_called++ };

  my $doc = NanoDOM::DOMImplementation->new->create_document;
  Web::XML::Parser->new->parse_char_string (q<<p>abc</p>> => $doc);

  is $parser_destroy_called, 1;

  undef $doc;
  is $doc_destroy_called, 1;
} # _xml_parser_gc

sub _parse_char_string : Test(7) { 
  my $s = qq{<foo>\x{4500}<bar xy="zb"/>\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $dom = NanoDOM::DOMImplementation->new;
  my $doc = $dom->create_document;
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html, qq{<foo>\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is $doc->input_encoding, undef;
  is $doc->xml_version, '1.0';
  is $doc->xml_encoding, undef;
  ok not $doc->xml_standalone;
  ok not $doc->manakai_is_html;
  is scalar @{$doc->child_nodes}, 2;
} # _parse_char_string

sub _parse_char_string_old_content : Test(3) { 
  my $s = qq{<foo>\x{4500}<bar xy="zb"/>\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $dom = NanoDOM::DOMImplementation->new;
  my $doc = $dom->create_document;
  $doc->inner_html (q{<foo>abc</foo>});
  is scalar @{$doc->child_nodes}, 1;
  
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html,
      qq{<foo>\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is scalar @{$doc->child_nodes}, 2;
} # _parse_char_string_old_content

sub _parse_char_string_onerror : Test(3) { 
  my $s = qq{<foo>\x{4500}<bar xy=zb />\x{400}abc</foo><!---->};
  my $parser = Web::XML::Parser->new;
  my $dom = NanoDOM::DOMImplementation->new;
  my $doc = $dom->create_document;
  
  my @error;
  $parser->onerror (sub {
    push @error, {@_};
  });
  $parser->parse_char_string ($s => $doc);
  eq_or_diff $doc->inner_html,
      qq{<foo>\x{4500}<bar xy="zb"></bar>\x{0400}abc</foo><!---->};
  is scalar @{$doc->child_nodes}, 2;
  delete $error[0]->{token};
  eq_or_diff \@error, [{type => 'unquoted attr value',
                        level => 'm',
                        line => 1, column => 15}];
} # _parse_char_string_old_content

sub _parse_char_string_with_context : Test(8) {
  my $parser = Web::XML::Parser->new;
  my $doc = new NanoDOM::Document;
  my $el = $doc->create_element_ns (undef, [undef, 'nnn']);
  my $children = $parser->parse_char_string_with_context
      ('<hoge>aaa<!-- bb -->bb<foo/>cc</hoge>aa<bb/>',
       $el, NanoDOM::Document->new);
  
  is scalar @$children, 3;
  is $children->[0]->namespace_uri, undef;
  is $children->[0]->manakai_tag_name, 'hoge';
  is $children->[0]->inner_html, 'aaa<!-- bb -->bb<foo></foo>cc';
  is $children->[1]->data, 'aa';
  is $children->[2]->namespace_uri, undef;
  is $children->[2]->manakai_tag_name, 'bb';
  is $children->[2]->text_content, '';
} # _parse_char_string_with_context

__PACKAGE__->runtests;

1;

=head1 LICENSE

Copyright 2009-2012 Wakaba <w@suika.fam.cx>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
