# -*- Makefile -*-

all: generated-pm-files

## ------ Setup ------

WGET = wget

deps: pmbp-install

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: pmbp-upgrade
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Build ------

GENERATED_PM_FILES = lib/Web/HTML/Tokenizer.pm lib/Web/HTML/Parser.pm \
  lib/Web/XML/Parser.pm

generated-pm-files: $(GENERATED_PM_FILES)

$(GENERATED_PM_FILES):: %: %.src bin/mkhtmlparser.pl
	perl bin/mkhtmlparser.pl $< > $@
	perl -Ilib -c $@

## ------ Tests ------

PERL = ./perl
PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/tests/*.t t/modules/*.t t/parsing.t

## License: Public Domain.
