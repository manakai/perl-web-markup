use strict;
use warnings;
use Path::Class;
BEGIN {
  require (file (__FILE__)->dir->file ('content-checker.pl')->stringify);
}

test_files (map { file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'xml', 'validation')->file($_)->stringify } qw[
  xml-1.dat
  xml-global.dat
]);

Test::X1::run_tests;

## License: Public Domain.
