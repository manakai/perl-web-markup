use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
use Encode;
use Data::Dumper;
use Web::DOM::Document;
use Web::Temma::Tokenizer;

my $doc = new Web::DOM::Document;
my $tokenizer = Web::Temma::Tokenizer->new;

my $input = decode 'utf-8', shift;

my $Tokens = [];
$tokenizer->ontokens (sub {
  my ($tokenizer, $tokens) = @_;
  push @$Tokens, @$tokens;

  if ($tokens->[-1]->{tag_name} eq 'xmp') {
    return 'RAWTEXT';
  } else {
    return undef;
  }
});

$tokenizer->parse_char_string ($input => $doc);

warn Dumper $Tokens;
