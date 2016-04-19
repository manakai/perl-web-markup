use strict;
use warnings;
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('lib')->stringify;
use lib path (__FILE__)->parent->parent->parent->child ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::X1;
use Test::More;
use Test::Differences;
use JSON::PS;
use Web::XML::Parser;
use Web::HTML::SourceMap;
use Web::DOM::Document;

my $path = path (__FILE__)->parent->parent->parent->child
    ('local/errors.json');
my $error_defs = json_bytes2perl $path->slurp;
$error_defs = $error_defs->{errors} if defined $error_defs->{errors};

test {
  ok @{$error_defs->{'ref outside of root element'}->{parser_tests}};
  shift->done;
} n => 1, name => 'test loaded';

for my $error_type (keys %$error_defs) {
  for my $test (@{$error_defs->{$error_type}->{parser_tests} or []}) {
    next unless $test->{lang} eq 'XML';
    test {
      my $c = shift;
      my $parser = Web::XML::Parser->new;
      my $errors = [];
      $parser->onerrors (sub { push @$errors, @{$_[1]} });
      my $doc = new Web::DOM::Document;
      my $di = 45;
      $parser->di ($di);
      $parser->scripting (!$test->{noscript});
      if (defined $test->{context}) {
        my $el = $doc->create_element_ns ('http://www.w3.org/1999/xhtml', $test->{context});
        $parser->parse_char_string_with_context ($test->{input}, $el => $doc);
      } else {
        $parser->parse_chars_start ($doc);
        $parser->parse_chars_feed ($test->{input});
        $parser->parse_chars_end;
      }

      if (grep { $_->{type} eq $error_type } @$errors) {
        @$errors = grep { $_->{type} eq $error_type } @$errors;
      }
      my $dids = $parser->di_data_set;
      for (@$errors) {
        ($_->{di}, $_->{index}) = resolve_index_pair $dids, $_->{di}, $_->{index}
      }
      eq_or_diff $errors,
          [{type => $error_type,
            di => $di, index => $test->{index},
            (defined $test->{text} ? (text => $test->{text}) : ()),
            (defined $test->{value} ? (value => $test->{value}) : ()),
            level => $test->{level} || $error_defs->{$error_type}->{default_level}}];
      done $c;
    } n => 1, name => [$test->{input}];
  }
}

run_tests;

## License: Public Domain.
