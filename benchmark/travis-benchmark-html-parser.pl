use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Web::HTML::Parser;
use Web::DOM::Document;
use Time::HiRes qw(time);

exit unless $ENV{TRAVIS};

my $api_key = $ENV{BENCHMARKER_HTMLPARSER_API_KEY} or die "No api key";
my $info_url = sprintf q{https://travis-ci.org/%s/jobs/%s},
    $ENV{TRAVIS_REPO_SLUG},
    $ENV{TRAVIS_JOB_ID};

my $parser = Web::HTML::Parser->new;
my $doc = new Web::DOM::Document;
$parser->onerror (sub { });

my $data_path = path (__FILE__)->parent->child ('data/complete.html');

my $start_time = time;
$parser->parse_char_string ($data_path->slurp_utf8 => $doc);
my $time_elapsed = time - $start_time;

system ('curl', '-s', '-S', '-L', qq{https://script.google.com/macros/s/AKfycbyM9NjoSjMy6zi-PzQrLsP75kkWQEFksorgvoHOGZs04OBR9Y5Y/exec?rows=%5B%7B%22value%22:$time_elapsed,%22note%22:%22$info_url%22%7D%5D&api_key=$api_key}) == 0
    or die "Can't post the result";

warn "Time elapsed: $time_elapsed\n";

## License: Public Domain.
