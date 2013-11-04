use strict;
use warnings;
use Path::Class;
BEGIN {
  require (file (__FILE__)->dir->file ('content-checker.pl')->stringify);
}

test_files (map { file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'atom', 'validation')->file($_)->stringify } qw[
  content-model-atom-1.dat
  content-model-atom-2.dat
  content-model-atom-threading-1.dat
]);

Test::X1::run_tests;

## License: Public Domain.
