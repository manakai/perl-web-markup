package Web::XML::Parser::ForValidatorChecker;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::XML::Parser::MinimumChecker;
push our @ISA, qw(Web::XML::Parser::MinimumChecker);
use Char::Class::XML qw(InXMLNCNameChar InXMLNCNameStartChar);

sub check_hidden_name ($%) {
  my $class = shift;
  return $class->check_name (@_);
} # check_hidden_name

sub check_hidden_nmtoken ($%) {
  my $class = shift;
  return $class->check_nmtoken (@_);
} # check_hidden_nmtoken

sub check_hidden_pi_target ($%) {
  my $class = shift;
  my %args = @_;
  if ($args{name} =~ /\A[Xx][Mm][Ll]\z/) {
    $args{onerror}->(type => 'xml:pi:target:xml',
                     level => 'm',
                     value => $args{name});
  } else {
    return $class->check_name (@_);
  }
} # check_hidden_pi_target

sub check_hidden_pubid ($%) {
  my ($class, %args) = @_;
  unless ($args{name} =~ m{\A[\x20\x0D\x0Aa-zA-Z0-9'()+,./:=?;!*#\@\$_%-]*\z}) {
    $args{onerror}->(type => 'xml:pubid:bad char',
                     level => 'm',
                     value => $args{name});
  }
  # XXX normalization warning
} # check_hidden_pubid

# XXX validate system ID
# XXX suggested name rules
# XXX Name MUST be NCName

sub check_ncnames ($%) {
  my ($class, %args) = @_;
  for (keys %{$args{names}}) {
    if (not /\A\p{InXMLNCNameStartChar}\p{InXMLNCNameChar}*\z/) {
      $args{onerror}->(type => 'xml:not ncname',
                       di => $args{names}->{$_}->{di},
                       index => $args{names}->{$_}->{index},
                       value => $_,
                       level => 'm');
    }
  }
} # check_ncnames

1;
