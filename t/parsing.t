#!/bin/sh
echo "1..3"
basedir=$(dirname $0)
parsing=$basedir/parsing
results=$parsing/results
tmp=$basedir/tmp
perl=$basedir/../perl

$perl $parsing/html-tokenize.t > $tmp/html-tokenize.txt 2>&1
(diff -u $results/html-tokenize.txt $tmp/html-tokenize.txt > /dev/null \
  && echo "ok 1") || echo "not ok 1"

$perl $parsing/html-tree.t > $tmp/html-tree.txt 2>&1
(diff -u $results/html-tree.txt $tmp/html-tree.txt > /dev/null \
  && echo "ok 2") || echo "not ok 2"

$perl $parsing/xml.t > $tmp/xml.txt 2>&1
(diff -u $results/xml.txt $tmp/xml.txt > /dev/null \
  && echo "ok 3") || echo "not ok 3"
