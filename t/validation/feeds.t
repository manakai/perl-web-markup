use strict;
use warnings;
use Path::Class;
BEGIN {
  require (file (__FILE__)->dir->file ('content-checker.pl')->stringify);
}

test_files (glob file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'atom', 'validation')->file('*.dat')->stringify);

Test::X1::run_tests;

## License: Public Domain.
