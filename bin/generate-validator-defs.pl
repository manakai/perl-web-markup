use strict;
use warnings;
use Path::Tiny;
use JSON::PS;
use Data::Dumper;

my $root_path = path (__FILE__)->parent->parent;

sub json ($) {
  return json_bytes2perl $root_path->child ("local/$_[0].json")->slurp;
}

my $elements = json 'elements';
my $microdata = json 'microdata';
my $aria = json 'aria';
my $aria_html = json 'aria-html-map';
my $rdf = json 'rdf';
my $xml_datatypes = json 'xml-datatypes';
my $ogp = json 'ogp';

my $data = {
  %$elements,
  md => $microdata,
  roles => $aria->{roles},
  aria_to_html => $aria_html,
  ogp => $ogp,
};

for my $ns (keys %{$data->{elements}}) {
  for my $ln (keys %{$data->{elements}->{$ns}}) {
    delete $data->{elements}->{$ns}->{$ln}->{spec};
    delete $data->{elements}->{$ns}->{$ln}->{id};
    delete $data->{elements}->{$ns}->{$ln}->{desc};
    delete $data->{elements}->{$ns}->{$ln}->{start_tag};
    delete $data->{elements}->{$ns}->{$ln}->{end_tag};
    delete $data->{elements}->{$ns}->{$ln}->{interface};
    delete $data->{elements}->{$ns}->{$ln}->{auto_br};
    delete $data->{elements}->{$ns}->{$ln}->{parser_category};
    delete $data->{elements}->{$ns}->{$ln}->{parser_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_li_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_button_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_table_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_table_body_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_table_row_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_select_non_scoping};
    delete $data->{elements}->{$ns}->{$ln}->{parser_implied_end_tag};
    delete $data->{elements}->{$ns}->{$ln}->{parser_implied_end_tag_at_eof};
    delete $data->{elements}->{$ns}->{$ln}->{parser_implied_end_tag_at_body};
    delete $data->{elements}->{$ns}->{$ln}->{syntax_category};
    delete $data->{elements}->{$ns}->{$ln}->{first_newline_ignored};
    delete $data->{elements}->{$ns}->{$ln}->{lang_sensitive};
    for my $ns2 (keys %{$data->{elements}->{$ns}->{$ln}->{attrs}}) {
      for my $ln2 (keys %{$data->{elements}->{$ns}->{$ln}->{attrs}->{$ns2}}) {
        delete $data->{elements}->{$ns}->{$ln}->{attrs}->{$ns2}->{$ln2}->{spec};
        delete $data->{elements}->{$ns}->{$ln}->{attrs}->{$ns2}->{$ln2}->{id};
        delete $data->{elements}->{$ns}->{$ln}->{attrs}->{$ns2}->{$ln2}->{desc};
        delete $data->{elements}->{$ns}->{$ln}->{attrs}->{$ns2}->{$ln2}->{lang_sensitive};
      }
    }
  }
}
delete $data->{input}->{idl_attrs};
delete $data->{input}->{methods};
delete $data->{input}->{events};
for my $type (keys %{$data->{md}}) {
  next unless $data->{md}->{$type}->{vocab} eq "http://schema.org/";
  for my $prop (keys %{$data->{md}->{$type}->{props} or {}}) {
    $data->{schemaorg_props}->{$prop} = {};
  }
}
for my $role (keys %{$data->{roles}}) {
  for (keys %{$data->{roles}->{$role}->{scope} or {}}) {
    $data->{roles}->{$_}->{scope_of}->{$role} = 1;
  }
}

$data->{rdf_vocab} = $rdf->{rdf_vocab};
$data->{xml_datatypes} = $xml_datatypes->{datatypes};

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Useqq = 1;
my $pm = Dumper $data;
$pm =~ s/VAR1/Web::HTML::Validator::_Defs/g;
print "$pm\n";
print "# Some of data drived from schema.org Web site, which is licensed under the Creative Commons Attribution-ShareAlike License (version 3.0).  See <http://schema.org/docs/terms.html> for full terms.";

## License: Public Domain.
