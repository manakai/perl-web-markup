all: generated-pm-files lib/Web/HTML/Validator/_Defs.pm \
    lib/Web/HTML/_SyntaxDefs.pm lib/Web/HTML/_NamedEntityList.pm
clean: clean-json-ps
	rm -fr local/*.json

updatenightly: update-submodules dataautoupdate-commit

update-submodules: local/bin/pmbp.pl
	curl https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	git add modules t_deps/modules t_deps/tests
	perl local/bin/pmbp.pl --update
	git add config

dataautoupdate-commit: clean all
	git add lib

PERL = ./perl
PROVE = ./prove

## ------ Setup ------

WGET = wget
GIT = git

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

GENERATED_PM_FILES = lib/Web/HTML/Tokenizer.pm lib/Web/HTML/Parser.pm

generated-pm-files: $(GENERATED_PM_FILES)

$(GENERATED_PM_FILES):: %: %.src bin/mkhtmlparser.pl local/bin/pmbp.pl
	perl local/bin/pmbp.pl --create-perl-command-shortcut perl
	perl bin/mkhtmlparser.pl $< > $@
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
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/aria.json
local/html-syntax.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/html-syntax.json
local/xml-syntax.json:
	mkdir -p local
	$(WGET) -O $@ https://github.com/manakai/data-web-defs/raw/master/data/xml-syntax.json
local/rdf.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/rdf.json

local/bin/jq:
	mkdir -p local/bin
	$(WGET) -O $@ http://stedolan.github.io/jq/download/linux64/jq
	chmod u+x $@

local/aria-html-map.json: local/aria.json local/bin/jq
	cat local/aria.json | local/bin/jq '.attrs | to_entries | map(select(.value.preferred.type == "html_attr")) | map([.key, .value.preferred.name])' > $@

lib/Web/HTML/_SyntaxDefs.pm: local/elements.json local/isindex-prompt.json \
    local/html-syntax.json local/xml-syntax.json local/bin/pmbp.pl Makefile
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module JSON \
	    --create-perl-command-shortcut perl
	sh -c 'echo "{\"dom\":"; cat local/elements.json; echo ",\"prompt\":"; cat local/isindex-prompt.json; echo ",\"syntax\":"; cat local/html-syntax.json; echo ",\"xml_syntax\":"; cat local/xml-syntax.json; echo "}"' | \
	$(PERL) -MJSON -MEncode -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (decode "utf-8", scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  for $$ns (keys %{$$data->{dom}->{elements}}) { #\
	    for $$ln (keys %{$$data->{dom}->{elements}->{$$ns}}) { #\
	      my $$category = $$data->{dom}->{elements}->{$$ns}->{$$ln}->{syntax_category}; #\
	      if ($$category eq "void" or $$category eq "obsolete void") { #\
	        $$result->{void}->{$$ns}->{$$ln} = 1; #\
	      } #\
	    } #\
	  } #\
	  for $$locale (keys %{$$data->{prompt}}) { #\
	    $$text = $$data->{prompt}->{$$locale}->{chromium} || #\
	             $$data->{prompt}->{$$locale}->{gecko} or next; #\
	    $$text .= " " if $$text =~ /:$$/; #\
	    $$result->{prompt}->{$$locale} = $$text; #\
	  } #\
	  for (qw(adjusted_mathml_attr_names adjusted_ns_attr_names), #\
               qw(adjusted_svg_attr_names adjusted_svg_element_names)) { #\
	    $$result->{$$_} = $$data->{syntax}->{$$_}; #\
          } #\
	  for (qw(charrefs_pubids)) { #\
	    $$result->{$$_} = $$data->{xml_syntax}->{$$_}; #\
          } #\
	  $$pm = Dumper $$result; #\
	  $$pm =~ s/VAR1/Web::HTML::_SyntaxDefs/; #\
	  print "$$pm\n"; #\
	  print "1;\n"; #\
	  $$footer = q{\
=head1 LICENSE\
\
This file contains data from the data-web-defs repository\
<https://github.com/manakai/data-web-defs/>.\
\
This file contains texts from Gecko and Chromium source codes.\
See following documents for full license terms of them:\
\
Gecko:\
\
  This Source Code Form is subject to the terms of the Mozilla Public\
  License, v. 2.0. If a copy of the MPL was not distributed with this\
  file, You can obtain one at http://mozilla.org/MPL/2.0/.\
\
Chromium:\
\
  See following documents:\
  <http://src.chromium.org/viewvc/chrome/trunk/src/webkit/LICENSE>\
  <http://src.chromium.org/viewvc/chrome/trunk/src/webkit/glue/resources/README.txt>\
\
=cut\
	  }; #\
	  $$footer =~ s/\x5C$$//gm; #\
	  print $$footer; #\
	' > $@
	perl -c $@

lib/Web/HTML/Validator/_Defs.pm: local/elements.json local/microdata.json \
    local/aria.json local/aria-html-map.json local/bin/pmbp.pl \
    local/rdf.json \
    bin/generate-validator-defs.pl json-ps
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module Path::Tiny \
	    --create-perl-command-shortcut perl
	$(PERL) bin/generate-validator-defs.pl > $@
	perl -c $@


json-ps: local/perl-latest/pm/lib/perl5/JSON/PS.pm
clean-json-ps:
	rm -fr local/perl-latest/pm/lib/perl5/JSON/PS.pm
local/perl-latest/pm/lib/perl5/JSON/PS.pm:
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

## ------ Tests ------

test: test-deps test-main

test-deps: deps local/elements.json

test-main:
	$(PROVE) t/tests/*.t t/modules/*.t t/parsing/*.t \
	    t/processing/*.t t/validation/*.t

## License: Public Domain.
