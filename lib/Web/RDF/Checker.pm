package Web::RDF::Checker;
use strict;
use warnings;
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
  if (defined $term->{lang}) {
    require Web::LangTag;
    my $lang = Web::LangTag->new;
    $lang->onerror (sub {
      $self->onerror->(value => $term->{lang}, node => $term->{node}, @_);
    });
    my $parsed = $lang->parse_tag ($term->{lang});
    $lang->check_parsed_tag ($parsed);
    $datatype = RDF_NS . 'langString';
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
    } elsif ($term->{datatype_url} eq RDF_NS . 'langString') {
      $self->onerror->(type => 'rdf:langString:no lang',
                       level => 'w')
          unless defined $term->{lang};
    } else {
      $self->onerror->(type => 'xsd:rdf:non-standard datatype',
                       value => $term->{datatype_url},
                       level => 'w')
          unless defined $term->{lang};
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
    
    # XXX lexical form validation based on datatype
  }

  if (defined $term->{parent_node}) {
    # XXX validate children
  }
} # check_parsed_item

1;

=head1 LICENSE

Copyright 2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
