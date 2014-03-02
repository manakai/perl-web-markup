use strict;
use warnings;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Test::HTCT::Parser;
use Web::HTML::Validator;
use Web::HTML::Parser;
use Web::XML::Parser;
use Web::DOM::Document;

sub test_files (@) {
  my @FILES = @_;

  for my $file_name (@FILES) {
    for_each_test ($file_name, {
      data => {is_prefixed => 1},
      errors => {is_list => 1, is_prefixed => 1},
    }, sub { _test ($file_name, $_[0]) });
  }
} # test_files

sub _test ($$) {
  my ($file_name, $test) = @_;
  $file_name = $1 if $file_name =~ m{([^/]+\.dat)};
  test {
    my $c = shift;
    $test->{parse_as} = 'xml';
    $test->{parse_as} = 'html'
        if $test->{data}->[1] and
           $test->{data}->[1]->[0] and
           $test->{data}->[1]->[0] eq 'html';

    unless ($test->{data}) {
      warn "No #data field\n";
    } elsif (not $test->{errors}) {
      warn "No #errors field ($test->{data}->[0])\n";
    }

    my $doc;
    if ($test->{parse_as} eq 'xml') {
      $doc = Web::DOM::Document->new;
      Web::XML::Parser->new->parse_char_string ($test->{data}->[0] => $doc);
      ## NOTE: There should be no well-formedness error; if there is,
      ## then it is an error of the test case itself.
    } else {
      $doc = Web::DOM::Document->new;
      my $parser = Web::HTML::Parser->new;
      $parser->scripting (not $test->{noscript});
      $parser->parse_char_string ($test->{data}->[0] => $doc);
    }
    $doc->document_uri (q<thismessage:/>);

    if ($test->{issrcdoc}->[1] and $test->{issrcdoc}->[1]->[0]) {
      $doc->manakai_is_srcdoc (1);
    }

    if ($test->{titlemetadata}) {
      $doc->set_user_data
          (manakai_title_metadata => $test->{titlemetadata}->[1]->[0]);
    }

    my @error;
    my $val = Web::HTML::Validator->new;
    $val->onerror (sub {
      my %opt = @_;
      if ($opt{type} =~ /^status:/ and $opt{level} eq 'i') {
        #
      } else {
        warn $opt{type} unless ref $opt{node};
        push @error,
          (($opt{di} || 0) == 0 ? (defined $opt{line} ? $opt{line} . ';' .$opt{column} . ';' : '') : '') .
          get_node_path ($opt{node}) . ';' . $opt{type} .
          (defined $opt{text} ? ';' . $opt{text} : '') .
          (defined $opt{level} ? ';'.$opt{level} : '');
      }
    });
    $val->scripting (not $test->{noscript});
    $val->image_viewable ($test->{'image-viewable'});
    $val->check_node ($doc->document_element);

    my $actual = join ("\n", sort {$a cmp $b} @error);
    my $expected = join ("\n", sort {$a cmp $b} @{$test->{errors}->[0]});
    $actual = join "\n", sort { $a cmp $b } split /\n/, join "\n", $actual;
    $expected = join "\n", sort { $a cmp $b } split /\n/, join "\n", $expected;
    if ($actual eq $expected) {
      is $actual, $expected;
    } else {
#line 1 "content-checker-test-ok"
      eq_or_diff $actual, $expected, $test->{data}->[0];
    }
    done $c;
  } n => 1, name => [$file_name, substr $test->{data}->[0], 0, 40];
} # test

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
    } elsif ($node->node_type == 11) {
      $rs = '#df';
      $node = $node->parent_node;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return join '/', @r;
} # get_node_path

1;

=head1 NAME

content-checker.pl - Test engine for document conformance checking

=head1 DESCRIPTION

The C<content-checker.pl> script implements a test engine for the
L<Web::HTML::Validator> markup document validator.

This script is C<require>d by test scripts in the same directory.

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 LICENSE

Public Domain.

=cut
