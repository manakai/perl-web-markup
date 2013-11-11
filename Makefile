# -*- Makefile -*-

all: generated-pm-files lib/Web/HTML/Validator/_Defs.pm
clean:
	rm -fr local/elements.json

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

GENERATED_PM_FILES = lib/Web/HTML/Tokenizer.pm lib/Web/HTML/Parser.pm \
  lib/Web/XML/Parser.pm

generated-pm-files: $(GENERATED_PM_FILES)

$(GENERATED_PM_FILES):: %: %.src bin/mkhtmlparser.pl
	perl bin/mkhtmlparser.pl $< > $@
	perl -Ilib -c $@

CURL = curl

update-entities: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --install-module JSON
	$(CURL) http://www.whatwg.org/specs/web-apps/current-work/entities.json | \
	$(PERL) -MJSON -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  $$pm = Dumper {map { (substr $$_, 1) => $$data->{$$_}->{characters} } keys %$$data}; #\
	  $$pm =~ s/VAR1/Web::HTML::EntityChar/; #\
	  print "$$pm\n1;\n# © Copyright 2004-2011 Apple Computer, Inc., Mozilla Foundation, and Opera Software ASA.\n# You are granted a license to use, reproduce and create derivative works of this document."; #\
	' > lib/Web/HTML/_NamedEntityList.pm
	perl -c lib/Web/HTML/_NamedEntityList.pm

local/elements.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/elements.json
lib/Web/HTML/Validator/_Defs.pm: local/elements.json local/bin/pmbp.pl
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module JSON
	$(PERL) -MJSON -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  for $$ns (keys %{$$data->{elements}}) { #\
	    for $$ln (keys %{$$data->{elements}->{$$ns}}) { #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{id}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{desc}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{start_tag}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{end_tag}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{interface}; #\
	      for $$ns2 (keys %{$$data->{elements}->{$$ns}->{$$ln}->{attrs}}) { #\
	        for $$ln2 (keys %{$$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}}) { #\
	          delete $$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}->{$$ln2}->{id}; #\
	          delete $$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}->{$$ln2}->{desc}; #\
	        } #\
	      } #\
	    } #\
	  } #\
	  $$pm = Dumper $$data; #\
	  $$pm =~ s/VAR1/Web::HTML::Validator::_Defs/; #\
	  print "$$pm\n"; #\
	' < local/elements.json > $@
	perl -c $@

## ------ Tests ------

test: test-deps test-main test-main-webdom

test-deps: deps

test-main:
	$(PROVE) t/tests/*.t t/modules/*.t t/parsing.t t/parsing/xml.t \
	    t/processing/*.t t/validation/*.t

test-main-webdom: local/bin/pmbp.pl
	-git clone git://github.com/manakai/perl-web-dom local/submodules/web-dom
	cd local/submodules/web-dom && git pull
	-git clone git://github.com/wakaba/perl-charclass local/submodules/charclass
	cd local/submodules/charclass && git pull
	perl local/bin/pmbp.pl \
	    --install-modules-by-file-name local/submodules/web-dom/config/perl/pmb-install.txt \
	    --install-modules-by-file-name local/submodules/charclass/config/perl/pmb-install.txt \
	    --install
	DOM_IMPL_CLASS=Web::DOM::Implementation $(PROVE) t/parsing.t


## License: Public Domain.
