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

$data->{elements}->{rss2} = $data->{rss2_elements};

for my $ns (keys %{$data->{elements}}) {
  for my $ln (keys %{$data->{elements}->{$ns}}) {
    my $def = $data->{elements}->{$ns}->{$ln};
    delete $def->{$_} for qw(

      spec id desc start_tag end_tag interface auto_br parser_category
      parser_scoping parser_li_scoping parser_button_scoping
      parser_table_scoping parser_table_body_scoping
      parser_table_row_scoping parser_select_non_scoping
      parser_implied_end_tag parser_implied_end_tag_at_eof
      parser_implied_end_tag_at_body syntax_category
      first_newline_ignored lang_sensitive url atom_extensible

    );
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
    } elsif ($def->{child_elements} and
             not $def->{has_additional_content_constraints} #and
             #not grep { $_->{has_additional_rules} } map { values %$_ } values %{$def->{child_elements}}
    ) {
      $def->{content_model} = 'props';
    }
  }
}
delete $data->{input}->{idl_attrs};
delete $data->{input}->{methods};
delete $data->{input}->{events};

$data->{rss2_elements} = delete $data->{elements}->{rss2};

for my $url (keys %{$data->{namespaces}}) {
  my $def = $data->{namespaces}->{$url};
  delete $def->{label};
  delete $def->{url};
  delete $def->{prefix};
  delete $def->{atom_family};
}
for (keys %{$data->{namespaces}}) {
  delete $data->{namespaces}->{$_} unless keys %{$data->{namespaces}->{$_}};
}
$data->{namespaces}->{q<http://www.w3.org/2000/xmlns/>}->{supported} = 1;

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

{
  my $json = json 'html-metadata';
  $data->{link_types} = $json->{link_types};
  $data->{metadata_names} = $json->{metadata_names};
  for (values %{$data->{link_types}}, values %{$data->{metadata_names}}) {
    delete $_->{name};
    delete $_->{spec};
    delete $_->{id};
    delete $_->{url};
    delete $_->{desc};
    delete $_->{microformats_wiki_synonyms_html};
    delete $_->{microformats_wiki_spec_link_label};
    delete $_->{microformats_wiki_spec_link_html};
    delete $_->{microformats_wiki_desc_html};
    delete $_->{microformats_wiki_url};
    delete $_->{whatwg_wiki_spec_link_label};
    delete $_->{whatwg_wiki_desc_html};
    delete $_->{whatwg_wiki_spec_link_html};
    delete $_->{whatwg_wiki_synonyms_html};
    delete $_->{whatwg_wiki_failure_reason};
  }
}

{
  my $json = json 'headers';
  for my $key (keys %{$json->{headers}}) {
    next unless $json->{headers}->{$key}->{http_equiv};
    my $d = $data->{http_equiv}->{$key} = {%{$json->{headers}->{$key}->{http_equiv}},
                                           %{$json->{headers}->{$key}}};
    delete $d->{$_} for qw(id url name http_equiv http sip rtsp fcast s-http
                           mail netnews icap ssdp mime
                           enumerated_attr_state_name multiple);
  }
}

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Useqq = 1;
my $pm = Dumper $data;
$pm =~ s/VAR1/Web::HTML::Validator::_Defs/g;
print "$pm\n";
print "# Some of data drived from schema.org Web site, which is licensed under the Creative Commons Attribution-ShareAlike License (version 3.0).  See <http://schema.org/docs/terms.html> for full terms.";

## License: Public Domain.
