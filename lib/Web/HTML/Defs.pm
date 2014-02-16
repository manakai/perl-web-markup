package Web::HTML::Defs;
use strict;
use warnings;
our $VERSION = '3.0';
use Carp;

our @EXPORT;
sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  for (@_ ? @_ : @EXPORT) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    no strict 'refs';
    *{$to_class . '::' . $_} = $code;
  }
} # import

## ------ Special character-like constants ------

push @EXPORT, qw(EOF_CHAR NEVER_CHAR ABORT_CHAR);

## The "EOF" pseudo-character in the HTML parsing algorithm.
sub EOF_CHAR () { -1 }

## A pseudo-character code that can never appear in the input stream.
sub NEVER_CHAR () { -2 }

## Pause tokenization (and parsing) because of the end of the
## currently available characters (that could be different from EOF).
sub ABORT_CHAR () { -3 }

## ------ HTML/XML Tokens ------

push @EXPORT, qw(
  DOCTYPE_TOKEN COMMENT_TOKEN START_TAG_TOKEN END_TAG_TOKEN
  END_OF_FILE_TOKEN CHARACTER_TOKEN PI_TOKEN ABORT_TOKEN
  END_OF_DOCTYPE_TOKEN ATTLIST_TOKEN ELEMENT_TOKEN 
  GENERAL_ENTITY_TOKEN PARAMETER_ENTITY_TOKEN NOTATION_TOKEN
  ENTITY_SUBTREE_TOKEN
);

sub DOCTYPE_TOKEN () { 1 } ## XML5: No DOCTYPE token.
sub COMMENT_TOKEN () { 2 }
sub START_TAG_TOKEN () { 3 }
sub END_TAG_TOKEN () { 4 }
sub END_OF_FILE_TOKEN () { 5 }
sub CHARACTER_TOKEN () { 6 }
sub PI_TOKEN () { 7 } ## NOTE: XML only.
sub ABORT_TOKEN () { 8 } ## NOTE: For internal processing.
sub END_OF_DOCTYPE_TOKEN () { 9 } ## NOTE: XML only.
sub ATTLIST_TOKEN () { 10 } ## NOTE: XML only.
sub ELEMENT_TOKEN () { 11 } ## NOTE: XML only.
sub GENERAL_ENTITY_TOKEN () { 12 } ## NOTE: XML only.
sub PARAMETER_ENTITY_TOKEN () { 13 } ## NOTE: XML only.
sub NOTATION_TOKEN () { 14 } ## NOTE: XML only.
sub ENTITY_SUBTREE_TOKEN () { 15 } ## NOTE: XML only, for internal.

## ------ Tokenizer states ------

sub DATA_STATE () { 0 }
sub RCDATA_STATE () { 107 }
sub RAWTEXT_STATE () { 108 }
sub SCRIPT_DATA_STATE () { 109 }
sub PLAINTEXT_STATE () { 110 }
sub TAG_OPEN_STATE () { 2 }
sub RCDATA_LT_STATE () { 111 }
sub RAWTEXT_LT_STATE () { 112 }
sub SCRIPT_DATA_LT_STATE () { 113 }
sub CLOSE_TAG_OPEN_STATE () { 3 }
sub RCDATA_END_TAG_OPEN_STATE () { 114 }
sub RAWTEXT_END_TAG_OPEN_STATE () { 115 }
sub SCRIPT_DATA_END_TAG_OPEN_STATE () { 116 }
sub SCRIPT_DATA_ESCAPE_START_STATE () { 1 }
sub SCRIPT_DATA_ESCAPE_START_DASH_STATE () { 12 }
sub SCRIPT_DATA_ESCAPED_STATE () { 117 }
sub SCRIPT_DATA_ESCAPED_DASH_STATE () { 118 }
sub SCRIPT_DATA_ESCAPED_DASH_DASH_STATE () { 119 }
sub SCRIPT_DATA_ESCAPED_LT_STATE () { 120 }
sub SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE () { 121 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE () { 122 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_STATE () { 123 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE () { 124 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE () { 125 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_LT_STATE () { 126 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE () { 127 }
sub TAG_NAME_STATE () { 4 }
sub BEFORE_ATTRIBUTE_NAME_STATE () { 5 }
sub ATTRIBUTE_NAME_STATE () { 6 }
sub AFTER_ATTRIBUTE_NAME_STATE () { 7 }
sub BEFORE_ATTRIBUTE_VALUE_STATE () { 8 }
sub ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE () { 9 }
sub ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE () { 10 }
sub ATTRIBUTE_VALUE_UNQUOTED_STATE () { 11 }
sub MARKUP_DECLARATION_OPEN_STATE () { 13 }
sub COMMENT_START_STATE () { 14 }
sub COMMENT_START_DASH_STATE () { 15 }
sub COMMENT_STATE () { 16 }
sub COMMENT_END_STATE () { 17 }
sub COMMENT_END_BANG_STATE () { 102 }
#sub COMMENT_END_SPACE_STATE () { 103 } ## REMOVED
sub COMMENT_END_DASH_STATE () { 18 }
sub BOGUS_COMMENT_STATE () { 19 }
sub DOCTYPE_STATE () { 20 }
sub BEFORE_DOCTYPE_NAME_STATE () { 21 }
sub DOCTYPE_NAME_STATE () { 22 }
sub AFTER_DOCTYPE_NAME_STATE () { 23 }
sub AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE () { 104 }
sub BEFORE_DOCTYPE_PUBLIC_IDENTIFIER_STATE () { 24 }
sub DOCTYPE_PUBLIC_IDENTIFIER_DOUBLE_QUOTED_STATE () { 25 }
sub DOCTYPE_PUBLIC_IDENTIFIER_SINGLE_QUOTED_STATE () { 26 }
sub AFTER_DOCTYPE_PUBLIC_IDENTIFIER_STATE () { 27 }
sub BEFORE_DOCTYPE_SYSTEM_IDENTIFIER_STATE () { 28 }
sub DOCTYPE_SYSTEM_IDENTIFIER_DOUBLE_QUOTED_STATE () { 29 }
sub DOCTYPE_SYSTEM_IDENTIFIER_SINGLE_QUOTED_STATE () { 30 }
sub BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE () { 105 }
sub AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE () { 106 }
sub AFTER_DOCTYPE_SYSTEM_IDENTIFIER_STATE () { 31 }
sub BOGUS_DOCTYPE_STATE () { 32 }
sub AFTER_ATTRIBUTE_VALUE_QUOTED_STATE () { 33 }
sub SELF_CLOSING_START_TAG_STATE () { 34 }
sub CDATA_SECTION_STATE () { 35 }
sub MD_HYPHEN_STATE () { 36 } # "markup declaration open state" in the spec
sub MD_DOCTYPE_STATE () { 37 } # "markup declaration open state" in the spec
sub MD_CDATA_STATE () { 38 } # "markup declaration open state" in the spec
#sub CDATA_RCDATA_CLOSE_TAG_STATE () { 39 } # "close tag open state" in the spec
sub CDATA_SECTION_MSE1_STATE () { 40 } # "CDATA section state" in the spec
sub CDATA_SECTION_MSE2_STATE () { 41 } # "CDATA section state" in the spec
sub PUBLIC_STATE () { 42 } # "after DOCTYPE name state" in the spec
sub SYSTEM_STATE () { 43 } # "after DOCTYPE name state" in the spec
##
## NOTE: "Character reference in data state", "Character reference in
## RCDATA state", "Character reference in attribute value state", and
## the "consume a character referece" algoritm are implemented as the
## following six tokenizer states:
sub ENTITY_STATE () { 44 }
sub ENTITY_HASH_STATE () { 45 }
sub NCR_NUM_STATE () { 46 }
sub HEXREF_X_STATE () { 47 }
sub HEXREF_HEX_STATE () { 48 }
sub ENTITY_NAME_STATE () { 49 }
##
## XML-only states
sub DATA_MSE1_STATE () { 50 }
sub DATA_MSE2_STATE () { 128 }
sub PI_STATE () { 51 }
sub PI_TARGET_STATE () { 52 }
sub PI_TARGET_AFTER_STATE () { 53 }
sub PI_DATA_STATE () { 54 }
sub PI_AFTER_STATE () { 55 }
sub PI_DATA_AFTER_STATE () { 56 }
sub DOCTYPE_INTERNAL_SUBSET_STATE () { 57 }
sub DOCTYPE_INTERNAL_SUBSET_AFTER_STATE () { 58 }
sub BOGUS_DOCTYPE_INTERNAL_SUBSET_AFTER_STATE () { 59 }
sub DOCTYPE_TAG_STATE () { 60 }
sub DOCTYPE_MARKUP_DECLARATION_OPEN_STATE () { 61 }
sub MD_ATTLIST_STATE () { 62 }
sub MD_E_STATE () { 63 }
sub MD_ELEMENT_STATE () { 64 }
sub MD_ENTITY_STATE () { 65 }
sub MD_NOTATION_STATE () { 66 }
sub DOCTYPE_MD_STATE () { 67 }
sub BEFORE_MD_NAME_STATE () { 68 }
sub MD_NAME_STATE () { 69 }
sub DOCTYPE_ENTITY_PARAMETER_BEFORE_STATE () { 70 }
sub DOCTYPE_ATTLIST_NAME_AFTER_STATE () { 71 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_NAME_STATE () { 72 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_NAME_AFTER_STATE () { 73 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_STATE () { 74 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_AFTER_STATE () { 75 }
sub BEFORE_ALLOWED_TOKEN_STATE () { 76 }
sub ALLOWED_TOKEN_STATE () { 77 }
sub AFTER_ALLOWED_TOKEN_STATE () { 78 }
sub AFTER_ALLOWED_TOKENS_STATE () { 79 }
sub BEFORE_ATTR_DEFAULT_STATE () { 80 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_BEFORE_STATE () { 81 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_STATE () { 82 }
sub DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_AFTER_STATE () { 83 }
sub ATTR_VALUE_ENTITY_STATE () { 129 }
sub AFTER_ATTLIST_ATTR_VALUE_QUOTED_STATE () { 84 }
sub BEFORE_NDATA_STATE () { 85 }
sub NDATA_STATE () { 86 }
sub AFTER_NDATA_STATE () { 87 }
sub BEFORE_NOTATION_NAME_STATE () { 88 }
sub NOTATION_NAME_STATE () { 89 }
sub DOCTYPE_ENTITY_VALUE_DOUBLE_QUOTED_STATE () { 90 }
sub DOCTYPE_ENTITY_VALUE_SINGLE_QUOTED_STATE () { 91 }
sub ENTITY_VALUE_ENTITY_STATE () { 92 }
sub AFTER_ELEMENT_NAME_STATE () { 93 }
sub BEFORE_ELEMENT_CONTENT_STATE () { 94 }
sub CONTENT_KEYWORD_STATE () { 95 }
sub AFTER_CM_GROUP_OPEN_STATE () { 96 }
sub CM_ELEMENT_NAME_STATE () { 97 }
sub AFTER_CM_ELEMENT_NAME_STATE () { 98 }
sub AFTER_CM_GROUP_CLOSE_STATE () { 99 }
sub AFTER_MD_DEF_STATE () { 100 }
sub BOGUS_MD_STATE () { 101 }
sub PARAMETER_ENTITY_NAME_STATE () { 130 } # last

push @EXPORT, qw(

  DATA_STATE RCDATA_STATE RAWTEXT_STATE SCRIPT_DATA_STATE
  PLAINTEXT_STATE TAG_OPEN_STATE RCDATA_LT_STATE RAWTEXT_LT_STATE
  SCRIPT_DATA_LT_STATE CLOSE_TAG_OPEN_STATE RCDATA_END_TAG_OPEN_STATE
  RAWTEXT_END_TAG_OPEN_STATE SCRIPT_DATA_END_TAG_OPEN_STATE
  SCRIPT_DATA_ESCAPE_START_STATE SCRIPT_DATA_ESCAPE_START_DASH_STATE
  SCRIPT_DATA_ESCAPED_STATE SCRIPT_DATA_ESCAPED_DASH_STATE
  SCRIPT_DATA_ESCAPED_DASH_DASH_STATE SCRIPT_DATA_ESCAPED_LT_STATE
  SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE
  SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_STATE SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_LT_STATE
  SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE TAG_NAME_STATE
  BEFORE_ATTRIBUTE_NAME_STATE ATTRIBUTE_NAME_STATE
  AFTER_ATTRIBUTE_NAME_STATE BEFORE_ATTRIBUTE_VALUE_STATE
  ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE
  ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE ATTRIBUTE_VALUE_UNQUOTED_STATE
  MARKUP_DECLARATION_OPEN_STATE COMMENT_START_STATE
  COMMENT_START_DASH_STATE COMMENT_STATE COMMENT_END_STATE
  COMMENT_END_BANG_STATE COMMENT_END_DASH_STATE BOGUS_COMMENT_STATE
  DOCTYPE_STATE BEFORE_DOCTYPE_NAME_STATE DOCTYPE_NAME_STATE
  AFTER_DOCTYPE_NAME_STATE AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE
  BEFORE_DOCTYPE_PUBLIC_IDENTIFIER_STATE
  DOCTYPE_PUBLIC_IDENTIFIER_DOUBLE_QUOTED_STATE
  DOCTYPE_PUBLIC_IDENTIFIER_SINGLE_QUOTED_STATE
  AFTER_DOCTYPE_PUBLIC_IDENTIFIER_STATE
  BEFORE_DOCTYPE_SYSTEM_IDENTIFIER_STATE
  DOCTYPE_SYSTEM_IDENTIFIER_DOUBLE_QUOTED_STATE
  DOCTYPE_SYSTEM_IDENTIFIER_SINGLE_QUOTED_STATE
  BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE
  AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE
  AFTER_DOCTYPE_SYSTEM_IDENTIFIER_STATE BOGUS_DOCTYPE_STATE
  AFTER_ATTRIBUTE_VALUE_QUOTED_STATE SELF_CLOSING_START_TAG_STATE
  CDATA_SECTION_STATE MD_HYPHEN_STATE MD_DOCTYPE_STATE MD_CDATA_STATE
  CDATA_SECTION_MSE1_STATE CDATA_SECTION_MSE2_STATE PUBLIC_STATE
  SYSTEM_STATE ENTITY_STATE ENTITY_HASH_STATE NCR_NUM_STATE
  HEXREF_X_STATE HEXREF_HEX_STATE ENTITY_NAME_STATE DATA_MSE1_STATE
  DATA_MSE2_STATE PI_STATE PI_TARGET_STATE PI_TARGET_AFTER_STATE
  PI_DATA_STATE PI_AFTER_STATE PI_DATA_AFTER_STATE
  DOCTYPE_INTERNAL_SUBSET_STATE DOCTYPE_INTERNAL_SUBSET_AFTER_STATE
  BOGUS_DOCTYPE_INTERNAL_SUBSET_AFTER_STATE DOCTYPE_TAG_STATE
  DOCTYPE_MARKUP_DECLARATION_OPEN_STATE MD_ATTLIST_STATE MD_E_STATE
  MD_ELEMENT_STATE MD_ENTITY_STATE MD_NOTATION_STATE DOCTYPE_MD_STATE
  BEFORE_MD_NAME_STATE MD_NAME_STATE
  DOCTYPE_ENTITY_PARAMETER_BEFORE_STATE DOCTYPE_ATTLIST_NAME_AFTER_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_NAME_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_NAME_AFTER_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_TYPE_AFTER_STATE BEFORE_ALLOWED_TOKEN_STATE
  ALLOWED_TOKEN_STATE AFTER_ALLOWED_TOKEN_STATE
  AFTER_ALLOWED_TOKENS_STATE BEFORE_ATTR_DEFAULT_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_BEFORE_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_STATE
  DOCTYPE_ATTLIST_ATTRIBUTE_DECLARATION_AFTER_STATE
  ATTR_VALUE_ENTITY_STATE
  AFTER_ATTLIST_ATTR_VALUE_QUOTED_STATE BEFORE_NDATA_STATE NDATA_STATE
  AFTER_NDATA_STATE BEFORE_NOTATION_NAME_STATE NOTATION_NAME_STATE
  DOCTYPE_ENTITY_VALUE_DOUBLE_QUOTED_STATE
  DOCTYPE_ENTITY_VALUE_SINGLE_QUOTED_STATE ENTITY_VALUE_ENTITY_STATE
  AFTER_ELEMENT_NAME_STATE BEFORE_ELEMENT_CONTENT_STATE
  CONTENT_KEYWORD_STATE AFTER_CM_GROUP_OPEN_STATE CM_ELEMENT_NAME_STATE
  AFTER_CM_ELEMENT_NAME_STATE AFTER_CM_GROUP_CLOSE_STATE
  AFTER_MD_DEF_STATE BOGUS_MD_STATE PARAMETER_ENTITY_NAME_STATE

);

## ------ Tree constructor state constants ------

## Whether the parsed string is in the foreign island or not affect
## how tokenization is done, unfortunately.  These are a copy of some
## of tokenization state constants.  See Web::HTML for the full
## list and the descriptions for constants.

push @EXPORT, qw(FOREIGN_EL);

sub FOREIGN_EL () { 0b1_000000000000 }

1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
