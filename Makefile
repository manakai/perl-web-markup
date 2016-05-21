PERL = ./perl
PROVE = ./prove
CURL = curl
WGET = wget
GIT = git

all: build
clean: clean-json-ps
	rm -fr local/*.json
	rm -fr lib/Web/XML/_CharClasses.pm

data: intermediate/validator-errors.json

updatenightly: update-submodules dataautoupdate-commit

update-submodules: local/bin/pmbp.pl
	curl https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	git add modules t_deps/modules t_deps/tests
	perl local/bin/pmbp.pl --update
	git add config lib

dataautoupdate-commit: clean all
	git add lib

## ------ Setup ------

JSON_PS = local/perl-latest/pm/lib/perl5/JSON/PS.pm

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: pmbp-upgrade git-submodules
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
            --create-perl-command-shortcut perl \
            --create-perl-command-shortcut prove

## ------ Build ------

build: generated-pm-files lib/Web/HTML/Validator/_Defs.pm \
    lib/Web/HTML/_SyntaxDefs.pm lib/Web/HTML/_NamedEntityList.pm \
    lib/Web/HTML/Parser.pm lib/Web/XML/Parser.pm \
    lib/Web/Temma/Tokenizer.pm \
    data \
    lib/Web/Feed/_Defs.pm

## Deprecated
GENERATED_PM_FILES = lib/Web/HTML/Tokenizer.pm
generated-pm-files: $(GENERATED_PM_FILES)
$(GENERATED_PM_FILES):: %: %.src bin/mkhtmlparser.pl local/bin/pmbp.pl
	perl local/bin/pmbp.pl --create-perl-command-shortcut perl
	perl bin/mkhtmlparser.pl $< > $@
	$(PERL) -c $@

lib/Web/HTML/Parser.pm: bin/generate-parser.pl \
    local/html-tokenizer-expanded.json \
    local/html-tree-constructor-expanded-no-isindex.json \
    local/elements.json local/bin/pmbp.pl $(JSON_PS)
	perl local/bin/pmbp.pl --create-perl-command-shortcut perl \
	    --install-module Path::Tiny
	$(PERL) bin/generate-parser.pl > $@
	$(PERL) -c $@
lib/Web/XML/Parser.pm: bin/generate-parser.pl \
    local/xml-tokenizer-expanded.json \
    local/xml-tree-constructor-expanded.json \
    local/elements.json local/bin/pmbp.pl $(JSON_PS)
	#perl local/bin/pmbp.pl --create-perl-command-shortcut perl \
	#    --install-module Path::Tiny
	PARSER_LANG=XML \
	$(PERL) bin/generate-parser.pl > $@
	$(PERL) -c $@
lib/Web/Temma/Tokenizer.pm: bin/generate-parser.pl \
    local/temma-tokenizer-expanded.json \
    local/elements.json local/bin/pmbp.pl $(JSON_PS)
	#perl local/bin/pmbp.pl --create-perl-command-shortcut perl \
	#    --install-module Path::Tiny
	PARSER_LANG=Temma \
	$(PERL) bin/generate-parser.pl > $@
	$(PERL) -c $@

lib/Web/HTML/_NamedEntityList.pm: local/html-charrefs.json local/bin/pmbp.pl \
    Makefile
	perl local/bin/pmbp.pl --install-module JSON \
	    --create-perl-command-shortcut perl
	$(PERL) -MJSON -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  $$pm = Dumper {map { (substr $$_, 1) => $$data->{$$_}->{characters} } keys %$$data}; #\
	  $$pm =~ s/VAR1/Web::HTML::EntityChar/; #\
	  print "$$pm\n1;\n# © Copyright 2004-2011 Apple Computer, Inc., Mozilla Foundation, and Opera Software ASA.\n# You are granted a license to use, reproduce and create derivative works of this document."; #\
	' < local/html-charrefs.json > lib/Web/HTML/_NamedEntityList.pm
	perl -c lib/Web/HTML/_NamedEntityList.pm

lib/Web/XML/_CharClasses.pm:
	echo 'package Web::XML::_CharClasses;use Carp;' > $@;
	echo 'sub import{my $$from_class = shift;my ($$to_class, $$file, $$line) = caller;no strict 'refs';for (@_ ? @_ : qw(InNameStartChar InNameChar InNCNameStartChar InNCNameChar InPCENChar)) {my $$code = $$from_class->can ($$_) or croak qq{"$$_" is not exported by the $$from_class module at $$file line $$line};*{$$to_class . '::' . $$_} = $$code;}}' >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNameStartChar=%24xml10-5e%3ANameStartChar >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNameChar=%24xml10-5e%3ANameChar >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNCNameStartChar=%24xml10-5e%3ANCNameStartChar >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNCNameChar=%24xml10-5e%3ANCNameChar >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InPCENChar=%24html%3APCENChar >> $@
	echo '1;' >> $@
	$(PERL) -c $@

lib/Web/Feed/_Defs.pm: bin/generate-feed-defs.pl local/elements.json
	$(PERL) $< > $@
	$(PERL) -c $@

local/html-charrefs.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/html-charrefs.json
local/elements.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/elements.json
local/isindex-prompt.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/isindex-prompt.json
local/microdata.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/microdata.json
local/aria.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/aria.json
local/html-syntax.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/html-syntax.json
local/xml-syntax.json:
	mkdir -p local
	$(WGET) -O $@ https://github.com/manakai/data-web-defs/raw/master/data/xml-syntax.json
local/rdf.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/rdf.json
local/xml-datatypes.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/xml-datatypes.json
local/ogp.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/ogp.json
local/html-tokenizer-expanded.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/html-tokenizer-expanded.json
local/html-tree-constructor-expanded-no-isindex.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/html-tree-constructor-expanded-no-isindex.json
local/xml-tokenizer-expanded.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/xml-tokenizer-expanded.json
local/xml-tree-constructor-expanded.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/xml-tree-constructor-expanded.json
local/temma-tokenizer-expanded.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/temma-tokenizer-expanded.json
local/html-metadata.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/html-metadata.json
local/headers.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/headers.json

local/maps.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-chars/master/data/maps.json
local/sets.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-chars/master/data/sets.json

local/errors.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-errors/master/data/errors.json

local/bin/jq:
	mkdir -p local/bin
	$(WGET) -O $@ https://stedolan.github.io/jq/download/linux64/jq
	chmod u+x $@

local/aria-html-map.json: local/aria.json local/bin/jq
	cat local/aria.json | local/bin/jq '.attrs | to_entries | map(select(.value.preferred.type == "html_attr")) | map([.key, .value.preferred.name])' > $@

lib/Web/HTML/_SyntaxDefs.pm: local/elements.json local/isindex-prompt.json \
    local/html-syntax.json local/xml-syntax.json local/bin/pmbp.pl Makefile \
    $(JSON_PS) bin/generate-syntax-defs.pl local/maps.json local/sets.json
	mkdir -p lib/Web/HTML
	perl local/bin/pmbp.pl --install-module Path::Tiny \
	    --create-perl-command-shortcut perl
	./perl bin/generate-syntax-defs.pl > $@
	perl -c $@

lib/Web/HTML/Validator/_Defs.pm: local/elements.json local/microdata.json \
    local/aria.json local/aria-html-map.json local/bin/pmbp.pl \
    local/rdf.json local/xml-datatypes.json local/ogp.json \
    local/html-metadata.json local/headers.json \
    bin/generate-validator-defs.pl $(JSON_PS)
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module Path::Tiny \
	    --create-perl-command-shortcut perl
	$(PERL) bin/generate-validator-defs.pl > $@
	perl -c $@

json-ps: $(JSON_PS)
clean-json-ps:
	rm -fr $(JSON_PS)
$(JSON_PS):
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

intermediate/validator-errors.json: bin/generate-errors.pl \
    src/validator-errors.txt $(JSON_PS)
	$(PERL) $< src/validator-errors.txt > $@

## ------ Tests ------

test: test-deps test-main test-benchmark

test-deps: deps local/elements.json local/errors.json $(JSON_PS)

test-main:
	$(PROVE) t/tests/*.t t/modules/*.t t/parsing/*.t \
	    t/processing/*.t t/validation/*.t

test-benchmark:
	$(PERL) benchmark/travis-benchmark-html-parser.pl

## License: Public Domain.
