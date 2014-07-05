use strict;
use warnings;
no warnings 'utf8';
use Path::Class;
use lib file (__FILE__)->dir->parent->parent->subdir ('lib')->stringify;
use lib file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'lib')->stringify;
use lib glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'modules', '*', 'lib')->stringify;
use Test::More;
use Test::Differences;
use Test::X1;
use JSON 1.07;
$JSON::UnMapping = 1;
$JSON::UTF8 = 1;

my $builder = Test::More->builder;
binmode $builder->output, ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output, ":utf8";

my $DEBUG = $ENV{DEBUG};

my $test_dir_name = file (__FILE__)->dir->parent->parent->
    subdir ('t_deps/tests/html/parsing/manakai') . '/';
my $dir_name = file (__FILE__)->dir->parent->parent->
    subdir ('t_deps/tests/html/parsing/html5lib/html-tokenizer') . '/';

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
  push our @ISA, qw(Web::HTML::_Tokenizer);
  sub _emit ($$) {
    push @{$_[0]->{tokens} ||= []}, $_[1];
  } # _emit
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
    test {
      my $c = shift;
      my $s = $test->{input};
      my $j = 1;
      while ($j < @{$test->{output}}) {
        if (ref $test->{output}->[$j - 1] and
            $test->{output}->[$j - 1]->[0] eq 'Character' and
            ref $test->{output}->[$j] and 
            $test->{output}->[$j]->[0] eq 'Character') {
          $test->{output}->[$j - 1]->[1] .= $test->{output}->[$j]->[1];
          splice @{$test->{output}}, $j, 1;
        }
        $j++;
      }

      my @cm = @{$test->{initialStates} || $test->{contentModelFlags} || ['']};
      my $last_start_tag = $test->{lastStartTag};
      for my $cm (@cm) {
        my $p = Tokenizer->new;
        my $i = 0;
        my @token;

        $p->{insertion_mode} = Web::HTML::Parser::BEFORE_HEAD_IM (); # dummy

        $p->_initialize_tokenizer;

        $p->{state} = {
          CDATA => 'RAWTEXT state',
          'RAWTEXT state' => 'RAWTEXT state',
          RCDATA => 'RCDATA state',
          'RCDATA state' => 'RCDATA state',
          PCDATA => 'data state',
          SCRIPT => 'script data state',
          PLAINTEXT => 'plaintext state',
        }->{$cm};
        if (defined $last_start_tag) {
          $p->{state} ||= {
            textarea => 'RCDATA state',
            xmp => 'RAWTEXT state',
            plaintext => 'plaintext state',
          }->{$last_start_tag};
          $p->{last_stag_name} = $last_start_tag;
        }
        $p->{state} ||= 'data state';

        $p->parse_char_string ($s);
        while (1) {
          my $token = shift @{$p->{tokens}};

          if ($token->{type} eq 'error') {
            push @token, 'ParseError';
            next;
          }

          last if $token->{type} == Web::HTML::Defs::END_OF_FILE_TOKEN ();
          
          my $test_token = [
            {
              Web::HTML::Defs::DOCTYPE_TOKEN () => 'DOCTYPE',
              Web::HTML::Defs::START_TAG_TOKEN () => 'StartTag',
              Web::HTML::Defs::END_TAG_TOKEN () => 'EndTag',
              Web::HTML::Defs::COMMENT_TOKEN () => 'Comment',
              Web::HTML::Defs::CHARACTER_TOKEN () => 'Character',
            }->{$token->{type}} || $token->{type},
          ];
          $test_token->[1] = $token->{tag_name} if defined $token->{tag_name};
          $test_token->[1] = $token->{value} if defined $token->{value};
          $test_token->[1] = $token->{data} if defined $token->{data};
          if ($token->{type} == Web::HTML::Defs::START_TAG_TOKEN ()) {
            $test_token->[2] = {map {$_->{name} => $_->{value}} values %{$token->{attributes}}};
            $test_token->[3] = 1 if $token->{self_closing_flag};
            delete $token->{self_closing_flag};
          } elsif ($token->{type} == Web::HTML::Defs::DOCTYPE_TOKEN ()) {
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
    } name => [$test->{description}, $test->{input}],
      n => 0+@{$test->{initialStates} || $test->{contentModelFlags} || ['']};
  } # $test
}

run_tests;

## License: Public Domain.
