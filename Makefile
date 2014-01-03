# -*- Makefile -*-

all: generated-pm-files lib/Web/HTML/Validator/_Defs.pm \
    lib/Web/HTML/_SyntaxDefs.pm
clean:
	rm -fr local/elements.json local/input-prompt.json

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

$(GENERATED_PM_FILES):: %: %.src deps bin/mkhtmlparser.pl
	perl bin/mkhtmlparser.pl $< > $@
	$(PERL) -c $@

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
local/isindex-prompt.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/isindex-prompt.json
lib/Web/HTML/_SyntaxDefs.pm: local/elements.json local/isindex-prompt.json \
    pmbp-install Makefile
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module JSON
	sh -c 'echo "{\"dom\":"; cat local/elements.json; echo ",\"prompt\":"; cat local/isindex-prompt.json; echo "}"' | \
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
lib/Web/HTML/Validator/_Defs.pm: local/elements.json pmbp-install Makefile
	mkdir -p lib/Web/HTML/Validator
	perl local/bin/pmbp.pl --install-module JSON
	$(PERL) -MJSON -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  for $$ns (keys %{$$data->{elements}}) { #\
	    for $$ln (keys %{$$data->{elements}->{$$ns}}) { #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{spec}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{id}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{desc}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{start_tag}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{end_tag}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{interface}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{auto_br}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_category}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_li_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_button_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_table_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_table_body_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_table_row_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_select_non_scoping}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_implied_end_tag}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_implied_end_tag_at_eof}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{parser_implied_end_tag_at_body}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{syntax_category}; #\
	      delete $$data->{elements}->{$$ns}->{$$ln}->{first_newline_ignored}; #\
	      for $$ns2 (keys %{$$data->{elements}->{$$ns}->{$$ln}->{attrs}}) { #\
	        for $$ln2 (keys %{$$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}}) { #\
	          delete $$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}->{$$ln2}->{spec}; #\
	          delete $$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}->{$$ln2}->{id}; #\
	          delete $$data->{elements}->{$$ns}->{$$ln}->{attrs}->{$$ns2}->{$$ln2}->{desc}; #\
	        } #\
	      } #\
	    } #\
	  } #\
	  delete $$data->{input}->{idl_attrs}; #\
	  delete $$data->{input}->{methods}; #\
	  delete $$data->{input}->{events}; #\
	  $$pm = Dumper $$data; #\
	  $$pm =~ s/VAR1/Web::HTML::Validator::_Defs/; #\
	  print "$$pm\n"; #\
	' < local/elements.json > $@
	perl -c $@

## ------ Tests ------

test: test-deps test-main

test-deps: deps local/elements.json

test-main:
	$(PROVE) t/tests/*.t t/modules/*.t t/parsing/*.t \
	    t/processing/*.t t/validation/*.t

## License: Public Domain.
