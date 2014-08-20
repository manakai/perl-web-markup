use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child
    ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Test::Differences;
use Web::HTML::SourceMap;

for my $test (
  [[], (-1, 0) => (-1, 0)],
  [[], (-1, 120) => (-1, 120)],
  [[], (1, 0) => (1, 0)],
  [[], (432, 10) => (432, 10)],
  [[undef, {map => [[0, 432, 0]]}], (1, 10) => (432, 10)],
  [[undef, {map => [[0, 432, 10]]}], (1, 10) => (432, 20)],
  [[undef, {map => [[0, 432, 10], [8, 12, 5]]}], (1, 10) => (12, 7)],
  [[undef, {map => [[0, 432, 10], [10, 12, 5]]}], (1, 10) => (12, 5)],
  [[undef, {map => [[0, 432, 10], [10, 12, 5], [10, 3, 0]]}], (1, 10) => (3, 0)],
  [[undef, {map => [[0, 432, 10], [10, 12, 5], [11, 3, 0]]}], (1, 10) => (12, 5)],
  [[undef, {map => [[0, 432, 10], [8, 2, 5]]}, {map => [[4, -1, 2]]}], (1, 10) => (-1, 5)],
  [[undef, {map => [[0, 432, 10], [8, 2, 5]]}, {map => [[4, 1, 2]]}], (1, 10) => (432, 15)],
  [[undef, {map => [[0, 432, 10], [8, 2, 5]]}, {map => [[4, 1, 8]]}], (1, 10) => (1, 35)],
  [[undef, {map => [[10, 12, 5]]}], (1, 3) => (-1, 3)],
) {
  test {
    my $c = shift;
    my ($di, $ci) = resolve_index_pair $test->[0], $test->[1], $test->[2];
    is $di, $test->[3];
    is $ci, $test->[4];
    done $c;
  } n => 2;
}

for my $test (
  [[], (-1, 0) => (undef, undef)],
  [[], (1, 4) => (undef, undef)],
  [[], (-1, 4) => (undef, undef)],
  [[undef, {lc_map => [[0, 3, 4]]}], (1, 4) => (3, 8)],
  [[undef, {lc_map => [[4, 3, 4]]}], (1, 4) => (3, 4)],
  [[undef, {lc_map => [[5, 3, 4]]}], (1, 4) => (undef, undef)],
  [[undef, {lc_map => [[0, 1, 2], [4, 3, 4]]}], (1, 4) => (3, 4)],
  [[undef, {lc_map => [[0, 1, 2], [3, 3, 4]]}], (1, 4) => (3, 5)],
  [[undef, {lc_map => [[0, 1, 2], [3, 3, 4], [4, 3, 4]]}], (1, 4) => (3, 4)],
  [[undef, {lc_map => [[0, 1, 2], [4, 1, 2], [4, 3, 4]]}], (1, 4) => (3, 4)],
) {
  test {
    my $c = shift;
    my ($l, $co) = index_pair_to_lc_pair $test->[0], $test->[1], $test->[2];
    is $l, $test->[3];
    is $co, $test->[4];
    done $c;
  } n => 2, name => 'index_pair_to_lc_pair';
}

for my $test (
  ['' => [[0,1,1]]],
  ['abc' => [[0,1,1]]],
  ["abc\x0Ade" => [[0,1,1], [4,2,1]]],
  ["abc\x0D\x0Ade" => [[0,1,1], [4,1,3], [5,2,1]]],
  ["abc\x0D\x0D\x0Ade" => [[0,1,1], [4,2,1], [5,2,1], [6,3,1]]],
  ["\x0Ade" => [[0,1,1], [1,2,1]]],
  ["\x0A" => [[0,1,1], [1,2,1]]],
  ["\x0D\x0A" => [[0,1,1], [1,1,1], [2,2,1]]],
  ["\x0D\x0Ade" => [[0,1,1], [1,1,1], [2,2,1]]],
  ["\x0A\x0Ade" => [[0,1,1], [1,2,1], [2,3,1]]],
  ["\x0D\x0Dde" => [[0,1,1], [1,2,1], [2,3,1]]],
  ["\x0D\x0A\x0D\x0Ade" => [[0,1,1], [1,1,1], [2,2,1], [3,2,1], [4,3,1]]],
) {
  test {
    my $c = shift;
    my $lc_map = create_index_lc_mapping ($test->[0]);
    eq_or_diff $lc_map, $test->[1];
    done $c;
  } n => 1, name => 'create_index_lc_mapping';
}

run_tests;
