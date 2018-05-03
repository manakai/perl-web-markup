use strict;
use warnings;
no warnings 'utf8';
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use Test::HTCT::Parser;
use Web::HTML::Validator;
use Web::HTML::Parser;
use Web::XML::Parser;
use Web::DOM::Document;

sub note ($) {
  my $s = '# ' . $_[0];
  $s =~ s/\n/\n# /g;
  print STDERR "$s\n";
} # note

sub is_set_list ($$;$) {
  my ($actual, $expected, $name) = @_;

  my $act = {};
  $act->{$_}++ for @$actual;
  my $exp = {};
  $exp->{$_}++ for @$expected;

  my $act_only = {};
  my $exp_only = {};
  for (keys %$exp) {
    if ($act->{$_}) {
      if ($act->{$_} == $exp->{$_}) {
        #
      } else {
        if ($act->{$_} > $exp->{$_}) {
          $act_only->{$_} = $act->{$_} - $exp->{$_};
        } else {
          $exp_only->{$_} = $exp->{$_} - $act->{$_};
        }
      }
    } else {
      $exp_only->{$_} = $exp->{$_};
    }
  }
  for (keys %$act) {
    $act_only->{$_} = $act->{$_} unless $exp->{$_};
  }

  if (not keys %$exp_only and not keys %$act_only) {
    ok 1, $name;
  } else {
    if (keys %$act != keys %$exp) {
      is 0+keys %$act, 0+keys %$exp, "$name - #";
    } else {
      ok 0, $name;
      note "# of errors: " . (0+keys %$act);
    }
    if (keys %$exp_only) {
      note join "\n", "Expected but not got:",
          map {
            ("- $_",
             ($exp_only->{$_} > 1 ? "    x $exp_only->{$_}" : ()));
          } sort { $a cmp $b } keys %$exp_only;
    }
    if (keys %$act_only) {
      note join "\n", "Got but not expected:",
          map {
            ("- $_",
             ($act_only->{$_} > 1 ? "    x $act_only->{$_}" : ()));
          } sort { $a cmp $b } keys %$act_only;
    }
  }
} # is_set_list

sub test_files (@) {
  my @FILES = @_;

  for my $file_name (@FILES) {
    for_each_test ($file_name, {
      data => {is_prefixed => 1},
      errors => {is_list => 1, is_prefixed => 1},
    }, sub { _test ($file_name, $_[0], $_[1]) });
  }
} # test_files

sub _test ($$$) {
  my ($file_name, $test, $opts) = @_;
  $file_name = $1 if $file_name =~ m{([^/]+\.dat)};
  test {
    my $c = shift;
    $test->{parse_as} = 'xml';
    $test->{parse_as} = 'html'
        if $test->{data}->[1] and
           $test->{data}->[1]->[0] and
           $test->{data}->[1]->[0] eq 'html';
    my $check_as_doc = $test->{'is-document'};

    unless ($test->{data}) {
      die "No #data field\n";
    } elsif (not $test->{errors}) {
      die "No #errors field ($test->{data}->[0])\n";
    }

    my $doc;
    if ($test->{parse_as} eq 'xml') {
      $doc = Web::DOM::Document->new;
      my $parser = Web::XML::Parser->new;
      $parser->onerror (sub { });
      $parser->parse_char_string ($test->{data}->[0] => $doc);
      ## NOTE: There should be no well-formedness error; if there is,
      ## then it is an error of the test case itself.
    } else {
      $doc = Web::DOM::Document->new;
      my $parser = Web::HTML::Parser->new;
      $parser->scripting (not $test->{noscript});
      $parser->parse_char_string ($test->{data}->[0] => $doc);
    }
    $doc->_set_content_type ($1)
        if $test->{mime} and $test->{mime}->[1]->[0] =~ m{^([a-z0-9+_.-]+/[a-z0-9+_.-]+)$};
    my $checked = $check_as_doc ? $doc : $doc->document_element;
    if ($test->{rss2}) {
      $doc->inner_html (q{<rss></rss>});
    }

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
          # XXXindex
          #(($opt{di} || 0) == 0 ? (defined $opt{line} ? $opt{line} . ';' .$opt{column} . ';' : '') : '') .
          get_node_path ($opt{node}) . ';' . $opt{type} .
          (defined $opt{text} ? ';' . $opt{text} : '') .
          (defined $opt{level} ? ';'.$opt{level} : '');
      }
    });
    $val->scripting (not $test->{noscript});
    $val->image_viewable ($test->{'image-viewable'});
    $val->check_node ($checked);

    is_set_list [map {
      s/\x0A/\\n/;
      $_;
    } @error], [map {
      # XXXindex
      s/^\d+;\d+;//;
      $_;
    } @{$test->{errors}->[0]}], "errors";
    done $c;
  } n => 1, name => [$file_name, $opts->{line_number},
                     substr $test->{data}->[0], 0, 40];
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
    } elsif ($node->node_type == 6) {
      $rs = '!ENTITY '.$node->node_name;
      $node = $node->owner_document_type_definition;
    } elsif ($node->node_type == 7) {
      $rs = '?' . $node->target;
      $node = $node->parent_node;
    } elsif ($node->node_type == 9) {
      $rs = '';
      $node = $node->parent_node;
    } elsif ($node->node_type == 10) {
      $rs = '!DOCTYPE';
      $node = $node->parent_node;
    } elsif ($node->node_type == 11) {
      $rs = '#df';
      $node = $node->parent_node;
    } elsif ($node->node_type == 12) {
      $rs = '!NOTATION '.$node->node_name;
      $node = $node->owner_document_type_definition;
    } elsif ($node->node_type == 81001) {
      $rs = '!ELEMENT ' . $node->node_name;
      $node = $node->owner_document_type_definition;
    } elsif ($node->node_type == 81002) {
      $rs = '@' . $node->node_name;
      $node = $node->owner_element_type_definition;
    } else {
      $rs = '#' . $node->node_type;
      $node = $node->parent_node;
    }
    unshift @r, $rs;
  }
  return '/' if @r == 1 and $r[0] eq '';
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
