package Web::RDF::Checker;
use strict;
use warnings;
use warnings FATAL => 'recursion';
no warnings 'utf8';
our $VERSION = '1.0';
use Web::HTML::Validator::_Defs;

sub RDF_NS () { q<http://www.w3.org/1999/02/22-rdf-syntax-ns#> }

sub new ($) {
  return bless {}, $_[0];
} # new

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} ||= sub {
    my %args = @_;
    warn $args{type}, "\n";
  };
} # onerror

sub scripting ($;$) {
  if (@_ > 1) {
    $_[0]->{scripting} = $_[1];
  }
  return $_[0]->{scripting};
} # scripting

sub onparentnode ($;$) {
  if (@_ > 1) {
    $_[0]->{onparentnode} = $_[1];
  }
  return $_[0]->{onparentnode} || sub { };
} # onparentnode

sub check_parsed_term ($$) {
  my ($self, $term) = @_;
  
  if (defined $term->{url}) {
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($term->{url});
    $chk->onerror (sub {
      $self->onerror->(value => $term->{url}, node => $term->{node}, @_);
    });
    $chk->check_iri_reference; # XXX absolute URL

    if ($term->{url} =~ m{\A\Qhttp://www.w3.org/1999/02/22-rdf-syntax-ns#\E_[1-9][0-9]*\z}s) {
      #
    } elsif ($term->{url} =~ m{\A\Qhttp://www.w3.org/1999/02/22-rdf-syntax-ns#\E(.+)\z}s) {
      my $type = $Web::HTML::Validator::_Defs->{rdf_vocab}->{$1}->{type} || '';
      if (not {
        class => 1, syntax => 1, property => 1, resource => 1,
      }->{$type}) {
        $self->onerror->(type => 'rdf vocab:not defined',
                         level => 'w',
                         value => $term->{url});
      }
    }
  }

  #$term->{bnodeid}

  my $datatype;
  my $unknown_datatype;
  if (defined $term->{lang}) {
    require Web::LangTag;
    my $lang = Web::LangTag->new;
    $lang->onerror (sub {
      $self->onerror->(value => $term->{lang}, node => $term->{node}, @_);
    });
    my $parsed = $lang->parse_tag ($term->{lang});
    $lang->check_parsed_tag ($parsed);
    $datatype = RDF_NS . 'langString';
    $unknown_datatype = 1;
  }
  if (defined $term->{datatype_url}) {
    require Web::URL::Checker;
    my $chk = Web::URL::Checker->new_from_string ($term->{datatype_url});
    $chk->onerror (sub {
      $self->onerror->(value => $term->{datatype_url}, node => $term->{node}, @_);
    });
    $chk->check_iri_reference; # XXX absolute URL

    my $dt = $Web::HTML::Validator::_Defs->{xml_datatypes}->{$term->{datatype_url}};
    my $dt_rdf = $dt->{rdf} || '';
    if ($dt_rdf eq 'builtin' or $dt_rdf eq '1') {
      #
    } elsif ($dt_rdf eq 'unsuitable') {
      $self->onerror->(type => 'xsd:rdf:unsuitable',
                       value => $term->{datatype_url},
                       level => 's');
      $unknown_datatype = 1;
    } elsif ($term->{datatype_url} eq RDF_NS . 'langString') {
      $self->onerror->(type => 'rdf:langString:no lang',
                       level => 'w')
          unless defined $term->{lang};
      $unknown_datatype = 1;
    } else {
      $self->onerror->(type => 'xsd:rdf:non-standard datatype',
                       value => $term->{datatype_url},
                       level => 'w');
      $unknown_datatype = 1;
    }

    if ($term->{datatype_url} =~ m{\A\Qhttp://www.w3.org/1999/02/22-rdf-syntax-ns#\E_[1-9][0-9]*\z}s) {
      #
    } elsif ($term->{datatype_url} =~ m{\A\Qhttp://www.w3.org/1999/02/22-rdf-syntax-ns#\E(.+)\z}s) {
      my $type = $Web::HTML::Validator::_Defs->{rdf_vocab}->{$1}->{type} || '';
      if (not {
        class => 1, syntax => 1, property => 1, resource => 1,
      }->{$type}) {
        $self->onerror->(type => 'rdf vocab:not defined',
                         level => 'w',
                         value => $term->{datatype_url});
      }
    }

    $datatype = $term->{datatype_url};
  } # datatype

  if (defined $term->{lexical}) {
    # XXX literal form SHOULD be NFC

    if (defined $datatype) {
      # XXX lexical form validation based on XML Schema datatypes

      if ($datatype eq RDF_NS . 'HTML') {
        require Web::DOM::Document;
        my $doc = new Web::DOM::Document;
        $doc->manakai_is_html (1);
        require Web::HTML::Parser;
        my $parser = Web::HTML::Parser->new;
        $parser->onerror (sub {
          $self->onerror->(@_);
        }); # XXX sps
        $parser->scripting ($self->scripting);
        my $container = $doc->create_element ('div');
        my $children = $parser->parse_char_string_with_context
            ($term->{lexical}, $container => $doc);
        my $df = $doc->create_document_fragment;
        $df->append_child ($_) for @$children;
        $self->onparentnode->($df);
      } elsif ($datatype eq RDF_NS . 'XMLLiteral') {
        require Web::DOM::Document;
        my $doc = new Web::DOM::Document;
        require Web::XML::Parser;
        my $parser = Web::XML::Parser->new;
        $parser->onerror (sub {
          $self->onerror->(@_);
        }); # XXX sps
        my $container = $doc->create_element_ns (undef, 'div');
        my $children = $parser->parse_char_string_with_context
            ($term->{lexical}, $container => $doc);
        my $df = $doc->create_document_fragment;
        $df->append_child ($_) for @$children;
        $self->onparentnode->($df);
      } else {
        $self->onerror->(type => 'rdf:unknown datatype',
                         value => $datatype,
                         level => 'u')
            unless $unknown_datatype;
      }
    }
  } # lexical

  if (defined $term->{parent_node}) {
    $self->onparentnode->($term->{parent_node});

    # XXX $term->{parent_node}->inner_html SHOULD be NFC
  }
} # check_parsed_item

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
