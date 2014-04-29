use strict;
use warnings;
use Path::Tiny;
BEGIN {
  require (path (__FILE__)->parent->child ('content-checker.pl')->stringify);
}

test_files (grep { /\.dat$/ } map { $_->stringify } path (__FILE__)->parent->parent->parent->child ('t_deps/tests/rdf/xml/validation')->children);

Test::X1::run_tests;

## License: Public Domain.
