package Web::GPX::Parser;
use strict;
use warnings;
our $VERSION = '2.0';
use Web::URL::Canonicalize qw(url_to_canon_url);
use Web::DateTime::Parser;

sub new ($) {
  return bless {}, $_[0];
} # new

sub parse_document ($$) {
  my ($self, $doc) = @_;
  my $root = $doc->document_element;
  if (not defined $root) {
    return undef;
  } elsif ($root->local_name eq 'gpx') {
    return $self->_gpx ($root);
  } else {
    return undef;
  }
} # parse_document

sub ctc ($) {
  return join '', map { $_->node_type == 3 ? $_->data : '' } $_[0]->child_nodes->to_list;
} # ctc

sub lat ($) {
  return undef unless defined $_[0];
  return undef unless $_[0] =~ /^[\x09\x0A\x0C\x0D\x20]*([+-]?[0-9]*(?:\.[0-9]+|)(?:[Ee][+-]?[0-9]+|))/;
  my $v = $1;
  return undef unless $v =~ /[0-9]/;
  return undef if $v > 90 or $v < -90;
  return 0+$v;
} # lat

sub lon ($) {
  return undef unless defined $_[0];
  return undef unless $_[0] =~ /^[\x09\x0A\x0C\x0D\x20]*([+-]?[0-9]*(?:\.[0-9]+|)(?:[Ee][+-]?[0-9]+|))/;
  my $v = $1;
  return undef unless $v =~ /[0-9]/;
  return undef if $v > 180 or $v < -180;
  return 0+$v;
} # lon

sub _gpx ($$) {
  my ($self, $el) = @_;
  my $ds = {waypoints => [], routes => [], tracks => [], links => []};
  my $creator = $el->get_attribute ('creator');
  $ds->{generator} = $creator if defined $creator and length $creator;
  for my $child ($el->children->to_list) {
    my $ln = $child->local_name;
    if ($ln eq 'wpt') {
      push @{$ds->{waypoints}}, $self->_point ($child);
    } elsif ($ln eq 'rte') {
      push @{$ds->{routes}}, $self->_route ($child);
    } elsif ($ln eq 'trk') {
      push @{$ds->{tracks}}, $self->_track ($child);
    } elsif ($ln eq 'metadata') {
      for my $gc ($child->children->to_list) {
        my $ln = $gc->local_name;
        if ($ln eq 'name' or $ln eq 'desc' or $ln eq 'keywords') {
          $ds->{$ln} = $self->_string ($gc) if not defined $ds->{$ln};
        } elsif ($ln eq 'link') {
          $self->_link ($gc => $ds);
        } elsif ($ln eq 'author') {
          if (not defined $ds->{author}) {
            $ds->{author} = my $person = {};
            for my $ggc ($gc->children->to_list) {
              my $ln = $ggc->local_name;
              if ($ln eq 'name') {
                $person->{name} = $self->_string ($ggc) if not defined $person->{name};
              } elsif ($ln eq 'link') {
                $person->{url} = $self->_url ($ggc) if not defined $person->{url};
              } elsif ($ln eq 'email') {
                if (not defined $person->{email}) {
                  my $id = $ggc->get_attribute ('id');
                  my $domain = $ggc->get_attribute ('domain');
                  if (defined $id and defined $domain) {
                    $person->{email} = $id . '@' . $domain;
                  }
                }
              }
            }
          }
        } elsif ($ln eq 'copyright') {
          if (not defined $ds->{license}) {
            $ds->{license} = my $license = {};
            my $s = $gc->get_attribute ('author');
            $license->{holder} = $s if defined $s and length $s;
            for my $ggc ($gc->children->to_list) {
              my $ln = $ggc->local_name;
              if ($ln eq 'year') {
                if (not defined $license->{year}) {
                  my $year = ctc $ggc;
                  if ($year =~ /\A[0-9]{4,}\z/) {
                    $license->{year} = 0+$year if $year > 0;
                  }
                }
              } elsif ($ln eq 'license') {
                if (not defined $license->{url}) {
                  my $text = ctc $ggc;
                  if (length $text) {
                    $license->{url} = url_to_canon_url $text, $ggc->base_uri; # or undef
                  }
                }
              }
            }
          }
        } elsif ($ln eq 'time') {
          my $ns = $gc->namespace_uri || '';
          if ($ns eq q<http://www.topografix.com/GPX/gpx_modified/0/1>) {
            $ds->{updated} = $self->_time ($gc) if not defined $ds->{updated};
          } else {
            $ds->{timestamp} = $self->_time ($gc) if not defined $ds->{timestamp};
          }
        } elsif ($ln eq 'bounds') {
          $ds->{min_lat} = lat ($gc->get_attribute ('minlat'))
              if not defined $ds->{min_lat};
          $ds->{max_lat} = lat ($gc->get_attribute ('maxlat'))
              if not defined $ds->{max_lat};
          $ds->{min_lon} = lon ($gc->get_attribute ('minlon'))
              if not defined $ds->{min_lon};
          $ds->{max_lon} = lon ($gc->get_attribute ('maxlon'))
              if not defined $ds->{max_lon};
        }
      }
    }
  }
  return $ds;
} # _gpx

sub _point ($$) {
  my ($self, $el) = @_;
  my $point = {links => []};
  $point->{lat} = lat ($el->get_attribute ('lat'));
  $point->{lon} = lon ($el->get_attribute ('lon'));
  for my $child ($el->children->to_list) {
    my $ln = $child->local_name;
    if ($ln eq 'name' or
        $ln eq 'desc' or
        $ln eq 'type' or
        $ln eq 'fix') {
      $point->{$ln} = $self->_string ($child)
          if not defined $point->{$ln};
    } elsif ($ln eq 'cmt') {
      $point->{comment} = $self->_string ($child)
          if not defined $point->{comment};
    } elsif ($ln eq 'src') {
      $point->{source} = $self->_string ($child)
          if not defined $point->{source};
    } elsif ($ln eq 'sym') {
      $point->{symbol_name} = $self->_string ($child)
          if not defined $point->{symbol_name};
    } elsif ($ln eq 'link') {
      $self->_link ($child => $point);
    } elsif ($ln eq 'time') {
      $point->{timestamp} = $self->_time ($child)
          if not defined $point->{timestamp};
    } elsif ($ln eq 'ele') {
      $point->{elevation} = $self->_number ($child)
          if not defined $point->{elevation};
    } elsif ($ln eq 'hdop' or $ln eq 'vdop' or $ln eq 'pdop' or
             $ln eq 'speed') {
      $point->{$ln} = $self->_number ($child)
          if not defined $point->{$ln};
    } elsif ($ln eq 'geoidheight') {
      $point->{geoid_height} = $self->_number ($child)
          if not defined $point->{geoid_height};
    } elsif ($ln eq 'ageofdgpsdata') {
      $point->{age_of_dgps_data} = $self->_number ($child)
          if not defined $point->{age_of_dgps_data};
    } elsif ($ln eq 'magvar') {
      if (not defined $point->{magnetic_variation}) {
        my $n = $self->_number ($child);
        if (0 <= $n and $n <= 360) {
          $point->{magnetic_variation} = $n;
        }
      }
    } elsif ($ln eq 'sat') {
      $point->{satelite_count} = $self->_uint ($child)
          if not defined $point->{satelite_count};
    } elsif ($ln eq 'dgpsid') {
      $point->{dgps_id} = $self->_uint ($child)
          if not defined $point->{dgps_id};
    } elsif ($ln eq 'extensions') {
      for my $gc ($child->children->to_list) {
        my $ln = $gc->local_name;
        if ($ln eq 'cadence' or $ln eq 'distance' or $ln eq 'heartrate' or
            $ln eq 'speed' or $ln eq 'accuracy' or $ln eq 'power') {
          $point->{$ln} = $self->_number ($gc)
              if not defined $point->{$ln};
        } elsif ($ln eq 'hr') {
          $point->{heartrate} = $self->_number ($gc)
              if not defined $point->{heartrate};
        } elsif ($ln eq 'temp') {
          $point->{temperature} = $self->_number ($gc)
              if not defined $point->{temperature};
        } elsif ($ln eq 'TrackPointExtension') {
          for my $ggc ($gc->children->to_list) {
            my $ln = $ggc->local_name;
            if ($ln eq 'atemp') {
              $point->{temperature} = $self->_number ($ggc)
                  if not defined $point->{temperature};
            } elsif ($ln eq 'wtemp') {
              $point->{water_temperature} = $self->_number ($ggc)
                  if not defined $point->{water_temperature};
            } elsif ($ln eq 'depth') {
              $point->{depth} = $self->_number ($ggc)
                  if not defined $point->{depth};
            } elsif ($ln eq 'hr') {
              $point->{heartrate} = $self->_number ($ggc)
                  if not defined $point->{heartrate};
            } elsif ($ln eq 'cad') {
              $point->{cadence} = $self->_number ($ggc)
                  if not defined $point->{cadence};
            }
          }
        }
      }
    }
  }
  return $point;
} # _point

sub _route ($$) {
  my ($self, $el) = @_;
  my $route = {points => [], links => []};
  for my $child ($el->children->to_list) {
    my $ln = $child->local_name;
    if ($ln eq 'name' or $ln eq 'desc' or $ln eq 'type') {
      $route->{$ln} = $self->_string ($child)
          if not defined $route->{$ln};
    } elsif ($ln eq 'cmt') {
      $route->{comment} = $self->_string ($child)
          if not defined $route->{comment};
    } elsif ($ln eq 'src') {
      $route->{source} = $self->_string ($child)
          if not defined $route->{source};
    } elsif ($ln eq 'link') {
      $self->_link ($child => $route);
    } elsif ($ln eq 'number') {
      $route->{number} = $self->_uint ($child)
          if not defined $route->{number};
    } elsif ($ln eq 'rtept') {
      push @{$route->{points}}, $self->_point ($child);
    }
  }
  return $route;
} # _route

sub _track ($$) {
  my ($self, $el) = @_;
  my $track = {segments => [], links => []};
  for my $child ($el->children->to_list) {
    my $ln = $child->local_name;
    if ($ln eq 'name' or $ln eq 'desc' or $ln eq 'type') {
      $track->{$ln} = $self->_string ($child)
          if not defined $track->{$ln};
    } elsif ($ln eq 'cmt') {
      $track->{comment} = $self->_string ($child)
          if not defined $track->{comment};
    } elsif ($ln eq 'src') {
      $track->{source} = $self->_string ($child)
          if not defined $track->{source};
    } elsif ($ln eq 'link') {
      $self->_link ($child => $track);
    } elsif ($ln eq 'number') {
      $track->{number} = $self->_uint ($child)
          if not defined $track->{number};
    } elsif ($ln eq 'trkseg') {
      push @{$track->{segments}}, my $seg = {points => []};
      for my $gc ($child->children->to_list) {
        if ($gc->local_name eq 'trkpt') {
          push @{$seg->{points}}, $self->_point ($gc);
        }
      }
    }
  }
  return $track;
} # _track

sub _string ($$) {
  my $ctc = ctc $_[1];
  return $ctc if length $ctc;
  return undef;
} # _string

sub _uint ($$) {
  my $text = ctc $_[1];
  return undef unless $text =~ /^[\x09\x0A\x0C\x0D\x20]*([+-]?[0-9]+)/;
  return 0+$1;
} # _uint

sub _number ($$) {
  return undef unless (ctc $_[1]) =~ /^[\x09\x0A\x0C\x0D\x20]*([+-]?[0-9]*(?:\.[0-9]+|)(?:[Ee][+-]?[0-9]+|))/;
  my $v = $1;
  return undef unless $v =~ /[0-9]/;
  return 0+$v;
} # _number

sub _url ($$) {
  my ($self, $el) = @_;
  my $text = $el->get_attribute ('href');
  return undef if not defined $text;
  return url_to_canon_url $text, $el->base_uri; # or undef
} # _url

sub _link ($$$) {
  my ($self, $el, $dest) = @_;
  my $u = $self->_url ($el);
  return undef if not defined $u;
  my $v = {url => $u};
  for my $c ($el->children->to_list) {
    my $ln = $c->local_name;
    if ($ln eq 'text') {
      $v->{text} = $self->_string ($c) if not defined $v->{text};
    } elsif ($ln eq 'type') {
      $v->{mime_type} = $self->_string ($c) if not defined $v->{mime_type};
    } elsif ($ln eq 'link') {
      $v->{url} = $self->_url ($c) if not defined $v->{url};
    }
  }
  push @{$dest->{links}}, $v;
} # _link

sub _time ($$) {
  my ($self, $el) = @_;
  my $parser = Web::DateTime::Parser->new;
  $parser->onerror (sub { });
  return $parser->parse_global_date_and_time_string (ctc $el); # or undef
} # _time

1;

=head1 LICENSE

Copyright 2016-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
