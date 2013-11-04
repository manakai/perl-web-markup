use strict;
use warnings;
use Path::Class;
BEGIN {
  require (file (__FILE__)->dir->file ('content-checker.pl')->stringify);
}

test_files (map { file (__FILE__)->dir->parent->parent->subdir ('t_deps', 'tests', 'html', 'validation')->file($_)->stringify } qw[
  content-model-1.dat
  content-model-7.dat
  html-1.dat
  html-global-1.dat
  html-dataset.dat
  html-metadata-1.dat
  html-metadata-2.dat
  html-flows-1.dat
  html-flowstructs-1.dat
  html-texts-1.dat
  html-links-1.dat
  html-links-2.dat
  html-objects-1.dat
  html-media-1.dat
  html-media-2.dat
  html-images-1.dat
  html-images-2.dat
  html-tables-1.dat
  html-tables-2.dat
  html-forms-1.dat
  html-form-label.dat
  html-form-input-1.dat
  html-form-button.dat
  html-form-select.dat
  html-form-datalist.dat
  html-form-textarea.dat
  html-form-keygen.dat
  html-interactive-1.dat
  html-scripting-1.dat
  html-scripting-2.dat
  html-repetitions.dat
  html-datatemplate.dat
  html-frames.dat
  html-frames-2.dat
]);

Test::X1::run_tests;

## License: Public Domain.
