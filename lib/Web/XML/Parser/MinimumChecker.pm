package Web::XML::Parser::MinimumChecker;
use strict;
use warnings;
our $VERSION = '1.0';
use Char::Class::XML qw(InXMLNameChar InXMLNameStartChar);

sub check_name ($%) {
  my ($class, %args) = @_;
  unless ($args{name} =~ /\A\p{InXMLNameStartChar}\p{InXMLNameChar}*\z/) {
    $args{onerror}->(type => 'xml:not name',
                     value => $args{name},
                     level => 'm');
  }
} # check_name

sub check_nmtoken ($%) {
  my ($class, %args) = @_;
  unless ($args{name} =~ /\A\p{InXMLNameChar}+\z/) {
    $args{onerror}->(type => 'xml:not nmtoken',
                     value => $args{name},
                     level => 'm');
  }
} # check_nmtoken

sub check_hidden_name ($%) {
  # skip
} # check_hidden_name

sub check_hidden_nmtoken ($%) {
  # skip
} # check_hidden_nmtoken

sub check_pi_target ($%) {
  # skip
} # check_pi_target

sub check_hidden_pi_target ($%) {
  return shift->check_pi_target (@_);
} # check_hidden_pi_target

sub check_hidden_pubid ($%) {
  # skip
} # check_hidden_pubid

sub check_hidden_sysid ($%) {
  # skip
} # check_hidden_sysid

sub check_version ($%) {
  my ($class, %args) = @_;
  if ($args{name} eq '1.0') {
    #
  } elsif ($args{name} =~ /\A1\.[0-9]+\z/) {
    # (deferred to validator)
  } else {
    $args{onerror}->(level => 'm',
                     type => 'XML version:syntax error',
                     value => $args{name});
  }
} # check_version

sub check_hidden_version ($%) {
  my ($class, %args) = @_;
  if ($args{name} eq '1.0') {
    #
  } elsif ($args{name} =~ /\A1\.[0-9]+\z/) {
    $args{onerror}->(level => 's',
                     type => 'xml:version:not 1.0',
                     value => $args{name});
  } else {
    $args{onerror}->(level => 'm',
                     type => 'XML version:syntax error',
                     value => $args{name});
  }
} # check_hidden_version

sub check_encoding ($%) {
  my ($class, %args) = @_;
  $args{onerror}->(level => 'm',
                   type => 'XML encoding:syntax error',
                   value => $args{name})
      unless $args{name} =~ /\A[A-Za-z][A-Za-z0-9._-]*\z/;
} # check_encoding

sub check_hidden_encoding ($%) {
  return shift->check_encoding (@_);
  # XXX Encoding Standard
} # check_hidden_encoding

1;
