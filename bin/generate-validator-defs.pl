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
    my $def = $data->{elements}->{$ns}->{$ln};
    delete $def->{spec};
    delete $def->{id};
    delete $def->{desc};
    delete $def->{start_tag};
    delete $def->{end_tag};
    delete $def->{interface};
    delete $def->{auto_br};
    delete $def->{parser_category};
    delete $def->{parser_scoping};
    delete $def->{parser_li_scoping};
    delete $def->{parser_button_scoping};
    delete $def->{parser_table_scoping};
    delete $def->{parser_table_body_scoping};
    delete $def->{parser_table_row_scoping};
    delete $def->{parser_select_non_scoping};
    delete $def->{parser_implied_end_tag};
    delete $def->{parser_implied_end_tag_at_eof};
    delete $def->{parser_implied_end_tag_at_body};
    delete $def->{syntax_category};
    delete $def->{first_newline_ignored};
    delete $def->{lang_sensitive};
    for my $ns2 (keys %{$def->{attrs}}) {
      for my $ln2 (keys %{$def->{attrs}->{$ns2}}) {
        delete $def->{attrs}->{$ns2}->{$ln2}->{spec};
        delete $def->{attrs}->{$ns2}->{$ln2}->{id};
        delete $def->{attrs}->{$ns2}->{$ln2}->{desc};
        delete $def->{attrs}->{$ns2}->{$ln2}->{lang_sensitive};
      }
    }

    if (defined $def->{content_model}) {
      if ($def->{content_model} eq 'atomDateConstruct' or
          $def->{content_model} eq 'atom03DateConstruct') {
        $def->{text_type} = $def->{content_model};
        $def->{content_model} = 'text';
      }
    }
  }
}
delete $data->{input}->{idl_attrs};
delete $data->{input}->{methods};
delete $data->{input}->{events};

for my $type (keys %{$data->{md}}) {
  delete $data->{md}->{$type}->{spec};
  delete $data->{md}->{$type}->{id};
  delete $data->{md}->{$type}->{desc};
  for my $prop (keys %{$data->{md}->{$type}->{props}}) {
    delete $data->{md}->{$type}->{props}->{$prop}->{spec};
    delete $data->{md}->{$type}->{props}->{$prop}->{id};
    delete $data->{md}->{$type}->{props}->{$prop}->{desc};
  }

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