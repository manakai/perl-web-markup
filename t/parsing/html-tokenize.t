use strict;
use warnings;
no warnings 'utf8';
use Path::Tiny;
use lib path (__FILE__)->parent->parent->parent->child ('lib')->stringify;
use lib path (__FILE__)->parent->parent->parent->child ('t_deps', 'lib')->stringify;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use JSON 1.07;
$JSON::UnMapping = 1;
$JSON::UTF8 = 1;
use Web::DOM::Document;

my $builder = Test::More->builder;
binmode $builder->output, ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output, ":utf8";

my $DEBUG = $ENV{DEBUG};

my $test_dir_name = path (__FILE__)->parent->parent->parent->
    child ('t_deps/tests/html/parsing/manakai') . '/';
my $dir_name = path (__FILE__)->parent->parent->parent->
    child ('t_deps/tests/html/parsing/html5lib/html-tokenizer') . '/';

use Data::Dumper;
$Data::Dumper::Useqq = 1;
$Data::Dumper::Useperl = 1;
$Data::Dumper::Sortkeys = 1;
{
  no warnings 'redefine';
  sub Data::Dumper::qquote {
    my $s = shift;
    $s =~ s/([^\x20\x21-\x26\x28-\x5B\x5D-\x7E])/sprintf '\x{%02X}', ord $1/ge;
    return q<qq'> . $s . q<'>;
  } # Data::Dumper::qquote
}

if ($DEBUG) {
  no warnings 'once';
  my $not_found = {%{$Web::HTML::Debug::cp or {}}};

  $Web::HTML::Debug::cp_pass = sub {
    my $id = shift;
    delete $not_found->{$id};
  };

  END {
    for my $id (sort {$a <=> $b || $a cmp $b} grep {!/^[ti]/}
                keys %$not_found) {
      print "# checkpoint $id is not reached\n";
    }
  }
}

use Web::HTML::Parser;

{
  package Tokenizer;
  push our @ISA, qw(Web::HTML::Parser);
  sub _construct_tree {
    my $self = shift;
    push @{$self->{tokens} ||= []},
        map { 'ParseError' } @{$self->{saved_lists}->{Errors}};
    push @{$self->{tokens} ||= []},
        @{$self->{saved_lists}->{Tokens}};
    @{$self->{saved_lists}->{Errors}} = ();
    @{$self->{saved_lists}->{Tokens}} = ();
  }
}

for my $file_name (grep {$_} split /\s+/, qq[
      ${dir_name}test1.test
      ${dir_name}test2.test
      ${dir_name}test3.test
      ${dir_name}test4.test
      ${dir_name}contentModelFlags.test
      ${dir_name}escapeFlag.test
      ${dir_name}entities.test
      ${dir_name}xmlViolation.test
      ${dir_name}domjs.test
      ${dir_name}numericEntities.test
      ${dir_name}pendingSpecChanges.test
      ${dir_name}unicodeChars.test
      ${dir_name}unicodeCharsProblematic.test
      ${test_dir_name}tokenizer-test-1.test
]) {
  #${dir_name}namedEntities.test

  open my $file, '<', $file_name or die "$0: $file_name: $!";
  local $/ = undef;
  my $js = <$file>;
  close $file;

  $js =~ s{\\(\\u[0-9A-Fa-f]{4})}{$1}g;
      ## Some characters are double-escaped in the JSON data.
  $js =~ s{\\?\\u[Dd]([89A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
           \\?\\u[Dd]([89A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])}{
    ## NOTE: JSON::Parser does not decode surrogate pair escapes
    ## NOTE: In older version of JSON::Parser, utf8 string will be broken
    ## by parsing.  Use latest version!
    ## NOTE: Encode.pm is broken; it converts e.g. U+10FFFF to U+FFFD.
    my $c = 0x10000;
    $c += ((((hex $1) & 0b1111111111) << 10) | ((hex $2) & 0b1111111111));
    chr $c;
  }gex;
  my $json = jsonToObj ($js);
  my $tests = $json->{tests} || $json->{xmlViolationTests};
  TEST: for my $test (@$tests) {
    {
      @{$test->{output}} = sort {
        (!!ref $a) cmp (!!ref $b);
      } @{$test->{output}};
      my $j = 1;
      while ($j < @{$test->{output}}) {
        if (ref $test->{output}->[$j - 1] and
            $test->{output}->[$j - 1]->[0] eq 'Character' and
            ref $test->{output}->[$j] and 
            $test->{output}->[$j]->[0] eq 'Character') {
          $test->{output}->[$j - 1]->[1] .= $test->{output}->[$j]->[1];
          splice @{$test->{output}}, $j, 1;
        } else {
          $j++;
        }
      }
    }

    test {
      my $c = shift;
      my $s = $test->{input};

      my @cm = @{$test->{initialStates} || $test->{contentModelFlags} || ['']};
      my $last_start_tag = $test->{lastStartTag};
      for my $cm (@cm) {
        my $p = Tokenizer->new;
        my $i = 0;
        my @token;

        if (length $cm or defined $last_start_tag) {
          $p->parse_chars_start (new Web::DOM::Document);
          my $state = {
            CDATA => Web::HTML::Parser::RAWTEXT_STATE,
            'RAWTEXT state' => Web::HTML::Parser::RAWTEXT_STATE,
            RCDATA => Web::HTML::Parser::RCDATA_STATE,
            'RCDATA state' => Web::HTML::Parser::RCDATA_STATE,
            PCDATA => Web::HTML::Parser::DATA_STATE,
            SCRIPT => Web::HTML::Parser::SCRIPT_DATA_STATE,
            PLAINTEXT => Web::HTML::Parser::PLAINTEXT_STATE,
          }->{$cm};
          if (defined $last_start_tag) {
            $state ||= {
              textarea => Web::HTML::Parser::RCDATA_STATE,
              xmp => Web::HTML::Parser::RAWTEXT_STATE,
              plaintext => Web::HTML::Parser::PLAINTEXT_STATE,
            }->{$last_start_tag};
            $p->{saved_states}->{LastStartTagName} = $last_start_tag;
          }
          $p->{saved_states}->{State} = $state if defined $state;
          $p->parse_chars_feed ($s);
          $p->parse_chars_end;
        } else {
          $p->parse_char_string ($s => new Web::DOM::Document);
        }

        while (1) {
          my $token = shift @{$p->{tokens}};

          unless (ref $token) {
            unshift @token, 'ParseError';
            next;
          }

          last if $token->{type} == Web::HTML::Parser::END_OF_FILE_TOKEN ();
          
          my $test_token = [
            {
              Web::HTML::Parser::DOCTYPE_TOKEN () => 'DOCTYPE',
              Web::HTML::Parser::START_TAG_TOKEN () => 'StartTag',
              Web::HTML::Parser::END_TAG_TOKEN () => 'EndTag',
              Web::HTML::Parser::COMMENT_TOKEN () => 'Comment',
              Web::HTML::Parser::TEXT_TOKEN () => 'Character',
            }->{$token->{type}} || $token->{type},
          ];
          $test_token->[1] = $token->{tag_name} if defined $token->{tag_name};
          $test_token->[1] = $token->{value} if defined $token->{value};
          $test_token->[1] = $token->{data} if defined $token->{data};
          if ($token->{type} == Web::HTML::Parser::START_TAG_TOKEN ()) {
            $test_token->[2] = {map {$_->{name} => (join '', map { $_->[0] } @{$_->{value}})} values %{$token->{attrs}}}; # IndexedString
            $test_token->[3] = 1 if $token->{self_closing_flag};
            delete $token->{self_closing_flag};
          } elsif ($token->{type} == Web::HTML::Parser::DOCTYPE_TOKEN ()) {
            $test_token->[1] = $token->{name};
            $test_token->[2] = $token->{public_identifier};
            $test_token->[3] = $token->{system_identifier};
            $test_token->[4] = $token->{force_quirks_flag} ? 0 : 1;
          }

          if (@token and ref $token[-1] and $token[-1]->[0] eq 'Character' and
              $test_token->[0] eq 'Character') {
            $token[-1]->[1] .= $test_token->[1];
          } else {
            push @token, $test_token;
          }
        }

        eq_or_diff \@token, $test->{output};
      } # $cm

      done $c;
    } name => [$file_name, $test->{description}, $test->{input}],
      n => 0+@{$test->{initialStates} || $test->{contentModelFlags} || ['']};
  } # $test
}

run_tests;

## License: Public Domain.
