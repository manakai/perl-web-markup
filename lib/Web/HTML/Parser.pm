
    package Web::HTML::Parser;
    use strict;
    use warnings;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    use warnings FATAL => 'redefine';
    use utf8;
    our $VERSION = '7.0';
    use Carp qw(croak);
    
    use Encode qw(decode); # XXX
    use Web::Encoding;
    use Web::HTML::ParserData;

    sub HTMLNS () { 1 }
    sub SVGNS () { 2 }
    sub MATHMLNS () { 3 }
    my $NSToURL = [
      undef,
      'http://www.w3.org/1999/xhtml',
      'http://www.w3.org/2000/svg',
      'http://www.w3.org/1998/Math/MathML',
    ];
    my $ForeignAttrMap = [
      undef, undef,
      $Web::HTML::ParserData::ForeignAttrNameToArgs->{'http://www.w3.org/2000/svg'},
      $Web::HTML::ParserData::ForeignAttrNameToArgs->{'http://www.w3.org/1998/Math/MathML'},
    ];
    my $TagName2Group = {};

# XXX defs from json
my $InvalidCharRefs = {};

for (0x0000, 0xD800..0xDFFF) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} = [0xFFFD, 'must'];
}
for (0x0001..0x0008, 0x000B, 0x000E..0x001F) {
  $InvalidCharRefs->{0}->{$_} =
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'must'];
}
$InvalidCharRefs->{1.0}->{0x000C} = [0x000C, 'must'];
$InvalidCharRefs->{0}->{0x007F} = [0x007F, 'must'];
for (0x007F..0x009F) {
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'warn'];
}
for (keys %$Web::HTML::ParserData::NoncharacterCodePoints) {
  $InvalidCharRefs->{0}->{$_} = [$_, 'must'];
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'warn'];
}
for (0xFFFE, 0xFFFF) {
  $InvalidCharRefs->{1.0}->{$_} = [$_, 'must'];
}
for (keys %$Web::HTML::ParserData::CharRefReplacements) {
  $InvalidCharRefs->{0}->{$_}
      = [$Web::HTML::ParserData::CharRefReplacements->{$_}, 'must'];
}

    ## ------ Common handlers ------

    sub new ($) {
      return bless {
        ## Input parameters
        # Scripting IframeSrcdoc known_definite_encoding locale_tag

        ## Callbacks
        # onerror onerrors onappcacheselection onscript
        # onelementspopped onrestartwithencoding

        ## Parser internal states
        # input_stream input_encoding saved_stats saved_lists
        # nodes document can_restart restart
        # parse_bytes_started transport_encoding_label
        # byte_bufer byte_buffer_orig
      }, $_[0];
    } # new

our $DefaultErrorHandler = sub {
  my $error = {@_};
  my $index = $error->{token} ? $error->{token}->{index} : $error->{index};
  $index = -1 if not defined $index;
  my $text = defined $error->{text} ? qq{ - $error->{text}} : '';
  my $value = defined $error->{value} ? qq{ "$error->{value}"} : '';
  warn "Parse error ($error->{type}$text) at index $index$value\n";
}; # $DefaultErrorHandler

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || $DefaultErrorHandler;
} # onerror

sub onerrors ($;$) {
  if (@_ > 1) {
    $_[0]->{onerrors} = $_[1];
  }
  return $_[0]->{onerrors} || sub {
    my $onerror = $_[0]->onerror;
    $onerror->(%$_) for @{$_[1]};
  };
} # onerrors

sub onappcacheselection ($;$) {
  if (@_ > 1) {
    $_[0]->{onappcacheselection} = $_[1];
  }
  return $_[0]->{onappcacheselection} || sub { };
} # onappcacheselection

sub onscript ($;$) {
  if (@_ > 1) {
    $_[0]->{onscript} = $_[1];
  }
  return $_[0]->{onscript} || sub { };
} # onscript

sub onelementspopped ($;$) {
  if (@_ > 1) {
    $_[0]->{onelementspopped} = $_[1];
  }
  return $_[0]->{onelementspopped} || sub { };
} # onelementspopped

sub onrestartwithencoding ($;$) {
  if (@_ > 1) {
    $_[0]->{onrestartwithencoding} = $_[1];
  }
  return $_[0]->{onrestartwithencoding} || sub {
    my ($self, $encoding) = @_;
    $self->known_definite_encoding ($encoding);
    $self->restart;
  };
} # onrestartwithencoding

    sub restart ($) {
      unless ($_[0]->{can_restart}) {
        croak "The current parsing method can't restart the parser";
      }
      $_[0]->{restart} = 1;
    } # restart

    sub scripting ($;$) {
      if (@_ > 1) {
        $_[0]->{Scripting} = $_[1];
      }
      return $_[0]->{Scripting};
    } # scripting

    sub _cleanup_states ($) {
      my $self = $_[0];
      delete $self->{input_stream};
      delete $self->{input_encoding};
      delete $self->{saved_states};
      delete $self->{saved_lists};
      delete $self->{nodes};
      delete $self->{document};
      delete $self->{can_restart};
      delete $self->{restart};
    } # _cleanup_states

    ## ------ Common defs ------
    our $AFE;our $Attr;our $CONTEXT;our $Callbacks;our $Confident;our $EOF;our $Errors;our $FORM_ELEMENT;our $FRAMESET_OK;our $HEAD_ELEMENT;our $IM;our $IframeSrcdoc;our $InForeign;our $Input;our $LastStartTagName;our $NEXT_ID;our $OE;our $OP;our $ORIGINAL_IM;our $Offset;our $QUIRKS;our $Scripting;our $State;our $TABLE_CHARS;our $TEMPLATE_IMS;our $Temp;our $Token;our $Tokens;
    ## ------ Tokenizer defs ------
    sub DOCTYPE_TOKEN () { 1 }
sub COMMENT_TOKEN () { 2 }
sub END_TAG_TOKEN () { 3 }
sub END_OF_FILE_TOKEN () { 4 }
sub START_TAG_TOKEN () { 5 }
sub TEXT_TOKEN () { 6 }
sub CDATA_SECTION_STATE () { 1 }
sub CDATA_SECTION_STATE__5D () { 2 }
sub CDATA_SECTION_STATE__5D_5D () { 3 }
sub CDATA_SECTION_STATE_CR () { 4 }
sub DOCTYPE_NAME_STATE () { 5 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE () { 6 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE_CR () { 7 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE () { 8 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE_CR () { 9 }
sub DOCTYPE_STATE () { 10 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE () { 11 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE_CR () { 12 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE () { 13 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE_CR () { 14 }
sub PLAINTEXT_STATE () { 15 }
sub PLAINTEXT_STATE_CR () { 16 }
sub RAWTEXT_END_TAG_NAME_STATE () { 17 }
sub RAWTEXT_END_TAG_OPEN_STATE () { 18 }
sub RAWTEXT_LESS_THAN_SIGN_STATE () { 19 }
sub RAWTEXT_STATE () { 20 }
sub RAWTEXT_STATE_CR () { 21 }
sub RCDATA_END_TAG_NAME_STATE () { 22 }
sub RCDATA_END_TAG_OPEN_STATE () { 23 }
sub RCDATA_LESS_THAN_SIGN_STATE () { 24 }
sub RCDATA_STATE () { 25 }
sub RCDATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 26 }
sub RCDATA_STATE___CHARREF_DECIMAL_NUMBER_STATE () { 27 }
sub RCDATA_STATE___CHARREF_HEX_NUMBER_STATE () { 28 }
sub RCDATA_STATE___CHARREF_NAME_STATE () { 29 }
sub RCDATA_STATE___CHARREF_NUMBER_STATE () { 30 }
sub RCDATA_STATE___CHARREF_STATE () { 31 }
sub RCDATA_STATE___CHARREF_STATE_CR () { 32 }
sub RCDATA_STATE_CR () { 33 }
sub AFTER_DOCTYPE_NAME_STATE () { 34 }
sub AFTER_DOCTYPE_NAME_STATE_P () { 35 }
sub AFTER_DOCTYPE_NAME_STATE_PU () { 36 }
sub AFTER_DOCTYPE_NAME_STATE_PUB () { 37 }
sub AFTER_DOCTYPE_NAME_STATE_PUBL () { 38 }
sub AFTER_DOCTYPE_NAME_STATE_PUBLI () { 39 }
sub AFTER_DOCTYPE_NAME_STATE_S () { 40 }
sub AFTER_DOCTYPE_NAME_STATE_SY () { 41 }
sub AFTER_DOCTYPE_NAME_STATE_SYS () { 42 }
sub AFTER_DOCTYPE_NAME_STATE_SYST () { 43 }
sub AFTER_DOCTYPE_NAME_STATE_SYSTE () { 44 }
sub AFTER_DOCTYPE_PUBLIC_ID_STATE () { 45 }
sub AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE () { 46 }
sub AFTER_DOCTYPE_SYSTEM_ID_STATE () { 47 }
sub AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE () { 48 }
sub AFTER_ATTR_NAME_STATE () { 49 }
sub AFTER_ATTR_VALUE__QUOTED__STATE () { 50 }
sub ATTR_NAME_STATE () { 51 }
sub ATTR_VALUE__DQ__STATE () { 52 }
sub ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 53 }
sub ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 54 }
sub ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE () { 55 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE () { 56 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE () { 57 }
sub ATTR_VALUE__DQ__STATE___CHARREF_STATE () { 58 }
sub ATTR_VALUE__DQ__STATE_CR () { 59 }
sub ATTR_VALUE__SQ__STATE () { 60 }
sub ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 61 }
sub ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 62 }
sub ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE () { 63 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE () { 64 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE () { 65 }
sub ATTR_VALUE__SQ__STATE___CHARREF_STATE () { 66 }
sub ATTR_VALUE__SQ__STATE_CR () { 67 }
sub ATTR_VALUE__UNQUOTED__STATE () { 68 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 69 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 70 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE () { 71 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE () { 72 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE () { 73 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE () { 74 }
sub ATTR_VALUE__UNQUOTED__STATE_CR () { 75 }
sub BEFORE_DOCTYPE_NAME_STATE () { 76 }
sub BEFORE_DOCTYPE_PUBLIC_ID_STATE () { 77 }
sub BEFORE_DOCTYPE_SYSTEM_ID_STATE () { 78 }
sub BEFORE_ATTR_NAME_STATE () { 79 }
sub BEFORE_ATTR_VALUE_STATE () { 80 }
sub BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE () { 81 }
sub BOGUS_DOCTYPE_STATE () { 82 }
sub BOGUS_COMMENT_STATE () { 83 }
sub BOGUS_COMMENT_STATE_CR () { 84 }
sub CHARREF_IN_RCDATA_STATE () { 85 }
sub CHARREF_IN_DATA_STATE () { 86 }
sub COMMENT_END_BANG_STATE () { 87 }
sub COMMENT_END_DASH_STATE () { 88 }
sub COMMENT_END_STATE () { 89 }
sub COMMENT_START_DASH_STATE () { 90 }
sub COMMENT_START_STATE () { 91 }
sub COMMENT_STATE () { 92 }
sub COMMENT_STATE_CR () { 93 }
sub DATA_STATE () { 94 }
sub DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 95 }
sub DATA_STATE___CHARREF_DECIMAL_NUMBER_STATE () { 96 }
sub DATA_STATE___CHARREF_HEX_NUMBER_STATE () { 97 }
sub DATA_STATE___CHARREF_NAME_STATE () { 98 }
sub DATA_STATE___CHARREF_NUMBER_STATE () { 99 }
sub DATA_STATE___CHARREF_STATE () { 100 }
sub DATA_STATE___CHARREF_STATE_CR () { 101 }
sub DATA_STATE_CR () { 102 }
sub END_TAG_OPEN_STATE () { 103 }
sub MDO_STATE () { 104 }
sub MDO_STATE__ () { 105 }
sub MDO_STATE_D () { 106 }
sub MDO_STATE_DO () { 107 }
sub MDO_STATE_DOC () { 108 }
sub MDO_STATE_DOCT () { 109 }
sub MDO_STATE_DOCTY () { 110 }
sub MDO_STATE_DOCTYP () { 111 }
sub MDO_STATE__5B () { 112 }
sub MDO_STATE__5BC () { 113 }
sub MDO_STATE__5BCD () { 114 }
sub MDO_STATE__5BCDA () { 115 }
sub MDO_STATE__5BCDAT () { 116 }
sub MDO_STATE__5BCDATA () { 117 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE () { 118 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR () { 119 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE () { 120 }
sub SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR () { 121 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE () { 122 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE () { 123 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE () { 124 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_STATE () { 125 }
sub SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR () { 126 }
sub SCRIPT_DATA_END_TAG_NAME_STATE () { 127 }
sub SCRIPT_DATA_END_TAG_OPEN_STATE () { 128 }
sub SCRIPT_DATA_ESCAPE_START_DASH_STATE () { 129 }
sub SCRIPT_DATA_ESCAPE_START_STATE () { 130 }
sub SCRIPT_DATA_ESCAPED_DASH_DASH_STATE () { 131 }
sub SCRIPT_DATA_ESCAPED_DASH_STATE () { 132 }
sub SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE () { 133 }
sub SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE () { 134 }
sub SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE () { 135 }
sub SCRIPT_DATA_ESCAPED_STATE () { 136 }
sub SCRIPT_DATA_ESCAPED_STATE_CR () { 137 }
sub SCRIPT_DATA_LESS_THAN_SIGN_STATE () { 138 }
sub SCRIPT_DATA_STATE () { 139 }
sub SCRIPT_DATA_STATE_CR () { 140 }
sub SELF_CLOSING_START_TAG_STATE () { 141 }
sub TAG_NAME_STATE () { 142 }
sub TAG_OPEN_STATE () { 143 }

my $TokenizerAbortingTagNames = {
  title => 1,
  textarea => 1,
  plaintext => 1,
  style => 1,
  script => 1,
  xmp => 1,
  iframe => 1,
  noembed => 1,
  noframes => 1,
  noscript => 1,

  #html => 1, # for <html manifest> -> see the line with "first start tag"
  #meta => 1, # for <meta charset>
};
  
    ## ------ Tree constructor defs ------
    my $Element2Type = [];
my $ProcessIM = [];
sub TAG_NAME_A () { 1 }
$TagName2Group->{q@a@} = 1;
sub TAG_NAME_ADDRESS_ARTICLE_ASIDE_DETAILS_DIALOG_DIR_FIGCAPTION_FIGURE_FOOTER_HEADER_HGROUP_MAIN_NAV_SECTION_SUMMARY () { 2 }
$TagName2Group->{q@address@} = 2;
$TagName2Group->{q@article@} = 2;
$TagName2Group->{q@aside@} = 2;
$TagName2Group->{q@details@} = 2;
$TagName2Group->{q@dialog@} = 2;
$TagName2Group->{q@dir@} = 2;
$TagName2Group->{q@figcaption@} = 2;
$TagName2Group->{q@figure@} = 2;
$TagName2Group->{q@footer@} = 2;
$TagName2Group->{q@header@} = 2;
$TagName2Group->{q@hgroup@} = 2;
$TagName2Group->{q@main@} = 2;
$TagName2Group->{q@nav@} = 2;
$TagName2Group->{q@section@} = 2;
$TagName2Group->{q@summary@} = 2;
sub TAG_NAME_APPLET_MARQUEE () { 3 }
$TagName2Group->{q@applet@} = 3;
$TagName2Group->{q@marquee@} = 3;
sub TAG_NAME_AREA_WBR () { 4 }
$TagName2Group->{q@area@} = 4;
$TagName2Group->{q@wbr@} = 4;
sub TAG_NAME_B_BIG_CODE_EM_I_S_SMALL_STRIKE_STRONG_TT_U () { 5 }
$TagName2Group->{q@b@} = 5;
$TagName2Group->{q@big@} = 5;
$TagName2Group->{q@code@} = 5;
$TagName2Group->{q@em@} = 5;
$TagName2Group->{q@i@} = 5;
$TagName2Group->{q@s@} = 5;
$TagName2Group->{q@small@} = 5;
$TagName2Group->{q@strike@} = 5;
$TagName2Group->{q@strong@} = 5;
$TagName2Group->{q@tt@} = 5;
$TagName2Group->{q@u@} = 5;
sub TAG_NAME_BASE () { 6 }
$TagName2Group->{q@base@} = 6;
sub TAG_NAME_BASEFONT_BGSOUND_LINK () { 7 }
$TagName2Group->{q@basefont@} = 7;
$TagName2Group->{q@bgsound@} = 7;
$TagName2Group->{q@link@} = 7;
sub TAG_NAME_BLOCKQUOTE_CENTER_DIV_DL_MENU_OL_UL () { 8 }
$TagName2Group->{q@blockquote@} = 8;
$TagName2Group->{q@center@} = 8;
$TagName2Group->{q@div@} = 8;
$TagName2Group->{q@dl@} = 8;
$TagName2Group->{q@menu@} = 8;
$TagName2Group->{q@ol@} = 8;
$TagName2Group->{q@ul@} = 8;
sub TAG_NAME_BODY () { 9 }
$TagName2Group->{q@body@} = 9;
sub TAG_NAME_BR () { 10 }
$TagName2Group->{q@br@} = 10;
sub TAG_NAME_BUTTON () { 11 }
$TagName2Group->{q@button@} = 11;
sub TAG_NAME_CAPTION () { 12 }
$TagName2Group->{q@caption@} = 12;
sub TAG_NAME_COL () { 13 }
$TagName2Group->{q@col@} = 13;
sub TAG_NAME_COLGROUP () { 14 }
$TagName2Group->{q@colgroup@} = 14;
sub TAG_NAME_DD_DT () { 15 }
$TagName2Group->{q@dd@} = 15;
$TagName2Group->{q@dt@} = 15;
sub TAG_NAME_EMBED () { 16 }
$TagName2Group->{q@embed@} = 16;
sub TAG_NAME_FIELDSET () { 17 }
$TagName2Group->{q@fieldset@} = 17;
sub TAG_NAME_FONT () { 18 }
$TagName2Group->{q@font@} = 18;
sub TAG_NAME_FORM () { 19 }
$TagName2Group->{q@form@} = 19;
sub TAG_NAME_FRAME () { 20 }
$TagName2Group->{q@frame@} = 20;
sub TAG_NAME_FRAMESET () { 21 }
$TagName2Group->{q@frameset@} = 21;
sub TAG_NAME_H1_H2_H3_H4_H5_H6 () { 22 }
$TagName2Group->{q@h1@} = 22;
$TagName2Group->{q@h2@} = 22;
$TagName2Group->{q@h3@} = 22;
$TagName2Group->{q@h4@} = 22;
$TagName2Group->{q@h5@} = 22;
$TagName2Group->{q@h6@} = 22;
sub TAG_NAME_HEAD () { 23 }
$TagName2Group->{q@head@} = 23;
sub TAG_NAME_HR () { 24 }
$TagName2Group->{q@hr@} = 24;
sub TAG_NAME_HTML () { 25 }
$TagName2Group->{q@html@} = 25;
sub TAG_NAME_IFRAME () { 26 }
$TagName2Group->{q@iframe@} = 26;
sub TAG_NAME_IMAGE () { 27 }
$TagName2Group->{q@image@} = 27;
sub TAG_NAME_IMG () { 28 }
$TagName2Group->{q@img@} = 28;
sub TAG_NAME_INPUT () { 29 }
$TagName2Group->{q@input@} = 29;
sub TAG_NAME_KEYGEN () { 30 }
$TagName2Group->{q@keygen@} = 30;
sub TAG_NAME_LABEL_OUTPUT () { 31 }
$TagName2Group->{q@label@} = 31;
$TagName2Group->{q@output@} = 31;
sub TAG_NAME_LI () { 32 }
$TagName2Group->{q@li@} = 32;
sub TAG_NAME_LISTING_PRE () { 33 }
$TagName2Group->{q@listing@} = 33;
$TagName2Group->{q@pre@} = 33;
sub TAG_NAME_MALIGNMARK_MGLYPH () { 34 }
$TagName2Group->{q@malignmark@} = 34;
$TagName2Group->{q@mglyph@} = 34;
sub TAG_NAME_MATH () { 35 }
$TagName2Group->{q@math@} = 35;
sub TAG_NAME_MENUITEM_PARAM_SOURCE_TRACK () { 36 }
$TagName2Group->{q@menuitem@} = 36;
$TagName2Group->{q@param@} = 36;
$TagName2Group->{q@source@} = 36;
$TagName2Group->{q@track@} = 36;
sub TAG_NAME_META () { 37 }
$TagName2Group->{q@meta@} = 37;
sub TAG_NAME_NOBR () { 38 }
$TagName2Group->{q@nobr@} = 38;
sub TAG_NAME_NOEMBED () { 39 }
$TagName2Group->{q@noembed@} = 39;
sub TAG_NAME_NOFRAMES () { 40 }
$TagName2Group->{q@noframes@} = 40;
sub TAG_NAME_NOSCRIPT () { 41 }
$TagName2Group->{q@noscript@} = 41;
sub TAG_NAME_OBJECT () { 42 }
$TagName2Group->{q@object@} = 42;
sub TAG_NAME_OPTGROUP () { 43 }
$TagName2Group->{q@optgroup@} = 43;
sub TAG_NAME_OPTION () { 44 }
$TagName2Group->{q@option@} = 44;
sub TAG_NAME_P () { 45 }
$TagName2Group->{q@p@} = 45;
sub TAG_NAME_PLAINTEXT () { 46 }
$TagName2Group->{q@plaintext@} = 46;
sub TAG_NAME_RP_RT () { 47 }
$TagName2Group->{q@rp@} = 47;
$TagName2Group->{q@rt@} = 47;
sub TAG_NAME_RUBY_SPAN_SUB_SUP_VAR () { 48 }
$TagName2Group->{q@ruby@} = 48;
$TagName2Group->{q@span@} = 48;
$TagName2Group->{q@sub@} = 48;
$TagName2Group->{q@sup@} = 48;
$TagName2Group->{q@var@} = 48;
sub TAG_NAME_SARCASM () { 49 }
$TagName2Group->{q@sarcasm@} = 49;
sub TAG_NAME_SCRIPT () { 50 }
$TagName2Group->{q@script@} = 50;
sub TAG_NAME_SELECT () { 51 }
$TagName2Group->{q@select@} = 51;
sub TAG_NAME_STYLE () { 52 }
$TagName2Group->{q@style@} = 52;
sub TAG_NAME_SVG () { 53 }
$TagName2Group->{q@svg@} = 53;
sub TAG_NAME_TABLE () { 54 }
$TagName2Group->{q@table@} = 54;
sub TAG_NAME_TBODY_TFOOT_THEAD () { 55 }
$TagName2Group->{q@tbody@} = 55;
$TagName2Group->{q@tfoot@} = 55;
$TagName2Group->{q@thead@} = 55;
sub TAG_NAME_TD_TH () { 56 }
$TagName2Group->{q@td@} = 56;
$TagName2Group->{q@th@} = 56;
sub TAG_NAME_TEMPLATE () { 57 }
$TagName2Group->{q@template@} = 57;
sub TAG_NAME_TEXTAREA () { 58 }
$TagName2Group->{q@textarea@} = 58;
sub TAG_NAME_TITLE () { 59 }
$TagName2Group->{q@title@} = 59;
sub TAG_NAME_TR () { 60 }
$TagName2Group->{q@tr@} = 60;
sub TAG_NAME_XMP () { 61 }
$TagName2Group->{q@xmp@} = 61;

        ## HTML:*
        sub HTML_NS_ELS () { 1 }
      

        ## HTML:a,HTML:b,HTML:big,HTML:code,HTML:em,HTML:font,HTML:i,HTML:nobr,HTML:s,HTML:small,HTML:strike,HTML:strong,HTML:tt,HTML:u
        sub ABBCEFINSSSSTU_ELS () { 2 }
      

        ## HTML:address,HTML:div
        sub ADD_DIV_ELS () { 4 }
      

        ## HTML:applet
        sub APP_ELS () { 8 }
      

        ## HTML:area,HTML:article,HTML:aside,HTML:base,HTML:basefont,HTML:bgsound,HTML:blockquote,HTML:br,HTML:center,HTML:col,HTML:details,HTML:dir,HTML:dl,HTML:embed,HTML:figcaption,HTML:figure,HTML:footer,HTML:form,HTML:frame,HTML:frameset,HTML:head,HTML:header,HTML:hgroup,HTML:hr,HTML:iframe,HTML:link,HTML:listing,HTML:main,HTML:menu,HTML:menuitem,HTML:meta,HTML:nav,HTML:noembed,HTML:noframes,HTML:noscript,HTML:param,HTML:plaintext,HTML:pre,HTML:script,HTML:section,HTML:source,HTML:summary,HTML:title,HTML:track,HTML:wbr,HTML:xmp
        sub AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS () { 16 }
      

        ## HTML:audio,HTML:video
        sub AUD_VID_ELS () { 32 }
      

        ## HTML:body
        sub BOD_ELS () { 64 }
      

        ## HTML:button
        sub BUT_ELS () { 128 }
      

        ## HTML:caption
        sub CAP_ELS () { 256 }
      

        ## HTML:colgroup
        sub COL_ELS () { 512 }
      

        ## HTML:dd
        sub DD_ELS () { 1024 }
      

        ## HTML:dt
        sub DT_ELS () { 2048 }
      

        ## HTML:fieldset,HTML:input,HTML:select,HTML:textarea
        sub FIE_INP_SEL_TEX_ELS () { 4096 }
      

        ## HTML:h1,HTML:h2,HTML:h3,HTML:h4,HTML:h5,HTML:h6
        sub HHHHHH_ELS () { 8192 }
      

        ## HTML:html
        sub HTM_ELS () { 16384 }
      

        ## HTML:img
        sub IMG_ELS () { 32768 }
      

        ## HTML:keygen,HTML:label,HTML:output
        sub KEY_LAB_OUT_ELS () { 65536 }
      

        ## HTML:li
        sub LI_ELS () { 131072 }
      

        ## HTML:marquee,MathML:annotation-xml
        sub MAR_M_ANN_ELS () { 262144 }
      

        ## HTML:object
        sub OBJ_ELS () { 524288 }
      

        ## HTML:ol,HTML:ul
        sub OL_UL_ELS () { 1048576 }
      

        ## HTML:optgroup,HTML:option
        sub OPT_OPT_ELS () { 2097152 }
      

        ## HTML:p
        sub P_ELS () { 4194304 }
      

        ## HTML:rp,HTML:rt
        sub RP_RT_ELS () { 8388608 }
      

        ## HTML:style
        sub STY_ELS () { 16777216 }
      

        ## HTML:table
        sub TAB_ELS () { 33554432 }
      

        ## HTML:tbody,HTML:tfoot,HTML:thead
        sub TBO_TFO_THE_ELS () { 67108864 }
      

        ## HTML:td,HTML:th
        sub TD_TH_ELS () { 134217728 }
      

        ## HTML:template
        sub TEM_ELS () { 268435456 }
      

        ## HTML:tr
        sub TR_ELS () { 536870912 }
      

        ## MathML:*
        sub MATHML_NS_ELS () { 1073741824 }
      

        ## MathML:annotation-xml
        sub M_ANN_ELS () { 2147483648 }
      

        ## MathML:annotation-xml@encoding=application/xhtml+xml,MathML:annotation-xml@encoding=text/html
        sub M_ANN_M_ANN_ELS () { 4294967296 }
      

        ## MathML:mi,MathML:mn,MathML:mo,MathML:ms,MathML:mtext
        sub M_MI_M_MN_M_MO_M_MS_M_MTE_ELS () { 8589934592 }
      

        ## SVG:*
        sub SVG_NS_ELS () { 17179869184 }
      

        ## SVG:desc,SVG:foreignObject,SVG:title
        sub S_DES_S_FOR_S_TIT_ELS () { 34359738368 }
      
$Element2Type->[HTMLNS]->{q@*@} = HTML_NS_ELS;
sub A_EL () { HTML_NS_ELS | ABBCEFINSSSSTU_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@a@} = A_EL;
sub ADDRESS_EL () { HTML_NS_ELS | ADD_DIV_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@address@} = ADDRESS_EL;
sub APPLET_EL () { HTML_NS_ELS | APP_ELS } $Element2Type->[HTMLNS]->{q@applet@} = APPLET_EL;
$Element2Type->[HTMLNS]->{q@area@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub ARTICLE_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@article@} = ARTICLE_EL;
sub ASIDE_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@aside@} = ASIDE_EL;
$Element2Type->[HTMLNS]->{q@audio@} = HTML_NS_ELS | AUD_VID_ELS;
$Element2Type->[HTMLNS]->{q@b@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@base@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@basefont@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@bgsound@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@big@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
sub BLOCKQUOTE_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 206158430208 } $Element2Type->[HTMLNS]->{q@blockquote@} = BLOCKQUOTE_EL;
sub BODY_EL () { HTML_NS_ELS | BOD_ELS } $Element2Type->[HTMLNS]->{q@body@} = BODY_EL;
$Element2Type->[HTMLNS]->{q@br@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub BUTTON_EL () { HTML_NS_ELS | BUT_ELS } $Element2Type->[HTMLNS]->{q@button@} = BUTTON_EL;
sub CAPTION_EL () { HTML_NS_ELS | CAP_ELS } $Element2Type->[HTMLNS]->{q@caption@} = CAPTION_EL;
sub CENTER_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 274877906944 } $Element2Type->[HTMLNS]->{q@center@} = CENTER_EL;
$Element2Type->[HTMLNS]->{q@code@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@col@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub COLGROUP_EL () { HTML_NS_ELS | COL_ELS } $Element2Type->[HTMLNS]->{q@colgroup@} = COLGROUP_EL;
sub DD_EL () { HTML_NS_ELS | DD_ELS } $Element2Type->[HTMLNS]->{q@dd@} = DD_EL;
sub DETAILS_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 343597383680 } $Element2Type->[HTMLNS]->{q@details@} = DETAILS_EL;
sub DIALOG_EL () { HTML_NS_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@dialog@} = DIALOG_EL;
sub DIR_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 412316860416 } $Element2Type->[HTMLNS]->{q@dir@} = DIR_EL;
sub DIV_EL () { HTML_NS_ELS | ADD_DIV_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@div@} = DIV_EL;
sub DL_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 481036337152 } $Element2Type->[HTMLNS]->{q@dl@} = DL_EL;
sub DT_EL () { HTML_NS_ELS | DT_ELS } $Element2Type->[HTMLNS]->{q@dt@} = DT_EL;
$Element2Type->[HTMLNS]->{q@em@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@embed@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub FIELDSET_EL () { HTML_NS_ELS | FIE_INP_SEL_TEX_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@fieldset@} = FIELDSET_EL;
sub FIGCAPTION_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 549755813888 } $Element2Type->[HTMLNS]->{q@figcaption@} = FIGCAPTION_EL;
sub FIGURE_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 618475290624 } $Element2Type->[HTMLNS]->{q@figure@} = FIGURE_EL;
$Element2Type->[HTMLNS]->{q@font@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
sub FOOTER_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 687194767360 } $Element2Type->[HTMLNS]->{q@footer@} = FOOTER_EL;
sub FORM_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 755914244096 } $Element2Type->[HTMLNS]->{q@form@} = FORM_EL;
$Element2Type->[HTMLNS]->{q@frame@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub FRAMESET_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 824633720832 } $Element2Type->[HTMLNS]->{q@frameset@} = FRAMESET_EL;
sub H1_EL () { HTML_NS_ELS | HHHHHH_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@h1@} = H1_EL;
sub H2_EL () { HTML_NS_ELS | HHHHHH_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@h2@} = H2_EL;
sub H3_EL () { HTML_NS_ELS | HHHHHH_ELS | 206158430208 } $Element2Type->[HTMLNS]->{q@h3@} = H3_EL;
sub H4_EL () { HTML_NS_ELS | HHHHHH_ELS | 274877906944 } $Element2Type->[HTMLNS]->{q@h4@} = H4_EL;
sub H5_EL () { HTML_NS_ELS | HHHHHH_ELS | 343597383680 } $Element2Type->[HTMLNS]->{q@h5@} = H5_EL;
sub H6_EL () { HTML_NS_ELS | HHHHHH_ELS | 412316860416 } $Element2Type->[HTMLNS]->{q@h6@} = H6_EL;
sub HEAD_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 893353197568 } $Element2Type->[HTMLNS]->{q@head@} = HEAD_EL;
sub HEADER_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 962072674304 } $Element2Type->[HTMLNS]->{q@header@} = HEADER_EL;
sub HGROUP_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1030792151040 } $Element2Type->[HTMLNS]->{q@hgroup@} = HGROUP_EL;
$Element2Type->[HTMLNS]->{q@hr@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub HTML_EL () { HTML_NS_ELS | HTM_ELS } $Element2Type->[HTMLNS]->{q@html@} = HTML_EL;
$Element2Type->[HTMLNS]->{q@i@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@iframe@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@img@} = HTML_NS_ELS | IMG_ELS;
$Element2Type->[HTMLNS]->{q@input@} = HTML_NS_ELS | FIE_INP_SEL_TEX_ELS;
$Element2Type->[HTMLNS]->{q@keygen@} = HTML_NS_ELS | KEY_LAB_OUT_ELS;
$Element2Type->[HTMLNS]->{q@label@} = HTML_NS_ELS | KEY_LAB_OUT_ELS;
sub LI_EL () { HTML_NS_ELS | LI_ELS } $Element2Type->[HTMLNS]->{q@li@} = LI_EL;
$Element2Type->[HTMLNS]->{q@link@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub LISTING_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1099511627776 } $Element2Type->[HTMLNS]->{q@listing@} = LISTING_EL;
sub MAIN_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1168231104512 } $Element2Type->[HTMLNS]->{q@main@} = MAIN_EL;
sub MARQUEE_EL () { HTML_NS_ELS | MAR_M_ANN_ELS } $Element2Type->[HTMLNS]->{q@marquee@} = MARQUEE_EL;
sub MENU_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1236950581248 } $Element2Type->[HTMLNS]->{q@menu@} = MENU_EL;
$Element2Type->[HTMLNS]->{q@menuitem@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@meta@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub NAV_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1305670057984 } $Element2Type->[HTMLNS]->{q@nav@} = NAV_EL;
sub NOBR_EL () { HTML_NS_ELS | ABBCEFINSSSSTU_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@nobr@} = NOBR_EL;
$Element2Type->[HTMLNS]->{q@noembed@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@noframes@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@noscript@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub OBJECT_EL () { HTML_NS_ELS | OBJ_ELS } $Element2Type->[HTMLNS]->{q@object@} = OBJECT_EL;
sub OL_EL () { HTML_NS_ELS | OL_UL_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@ol@} = OL_EL;
sub OPTGROUP_EL () { HTML_NS_ELS | OPT_OPT_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@optgroup@} = OPTGROUP_EL;
sub OPTION_EL () { HTML_NS_ELS | OPT_OPT_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@option@} = OPTION_EL;
$Element2Type->[HTMLNS]->{q@output@} = HTML_NS_ELS | KEY_LAB_OUT_ELS;
sub P_EL () { HTML_NS_ELS | P_ELS } $Element2Type->[HTMLNS]->{q@p@} = P_EL;
$Element2Type->[HTMLNS]->{q@param@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@plaintext@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub PRE_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1374389534720 } $Element2Type->[HTMLNS]->{q@pre@} = PRE_EL;
$Element2Type->[HTMLNS]->{q@rp@} = HTML_NS_ELS | RP_RT_ELS;
$Element2Type->[HTMLNS]->{q@rt@} = HTML_NS_ELS | RP_RT_ELS;
sub RUBY_EL () { HTML_NS_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@ruby@} = RUBY_EL;
$Element2Type->[HTMLNS]->{q@s@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
sub SARCASM_EL () { HTML_NS_ELS | 206158430208 } $Element2Type->[HTMLNS]->{q@sarcasm@} = SARCASM_EL;
sub SCRIPT_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1443109011456 } $Element2Type->[HTMLNS]->{q@script@} = SCRIPT_EL;
sub SECTION_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1511828488192 } $Element2Type->[HTMLNS]->{q@section@} = SECTION_EL;
sub SELECT_EL () { HTML_NS_ELS | FIE_INP_SEL_TEX_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@select@} = SELECT_EL;
$Element2Type->[HTMLNS]->{q@small@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@source@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@strike@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@strong@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@style@} = HTML_NS_ELS | STY_ELS;
sub SUMMARY_EL () { HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | 1580547964928 } $Element2Type->[HTMLNS]->{q@summary@} = SUMMARY_EL;
sub TABLE_EL () { HTML_NS_ELS | TAB_ELS } $Element2Type->[HTMLNS]->{q@table@} = TABLE_EL;
sub TBODY_EL () { HTML_NS_ELS | TBO_TFO_THE_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@tbody@} = TBODY_EL;
sub TD_EL () { HTML_NS_ELS | TD_TH_ELS | 68719476736 } $Element2Type->[HTMLNS]->{q@td@} = TD_EL;
sub TEMPLATE_EL () { HTML_NS_ELS | TEM_ELS } $Element2Type->[HTMLNS]->{q@template@} = TEMPLATE_EL;
$Element2Type->[HTMLNS]->{q@textarea@} = HTML_NS_ELS | FIE_INP_SEL_TEX_ELS;
sub TFOOT_EL () { HTML_NS_ELS | TBO_TFO_THE_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@tfoot@} = TFOOT_EL;
sub TH_EL () { HTML_NS_ELS | TD_TH_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@th@} = TH_EL;
sub THEAD_EL () { HTML_NS_ELS | TBO_TFO_THE_ELS | 206158430208 } $Element2Type->[HTMLNS]->{q@thead@} = THEAD_EL;
$Element2Type->[HTMLNS]->{q@title@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
sub TR_EL () { HTML_NS_ELS | TR_ELS } $Element2Type->[HTMLNS]->{q@tr@} = TR_EL;
$Element2Type->[HTMLNS]->{q@track@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@tt@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
$Element2Type->[HTMLNS]->{q@u@} = HTML_NS_ELS | ABBCEFINSSSSTU_ELS;
sub UL_EL () { HTML_NS_ELS | OL_UL_ELS | 137438953472 } $Element2Type->[HTMLNS]->{q@ul@} = UL_EL;
$Element2Type->[HTMLNS]->{q@video@} = HTML_NS_ELS | AUD_VID_ELS;
$Element2Type->[HTMLNS]->{q@wbr@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[HTMLNS]->{q@xmp@} = HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS;
$Element2Type->[MATHMLNS]->{q@*@} = MATHML_NS_ELS;
$Element2Type->[MATHMLNS]->{q@annotation-xml@} = MATHML_NS_ELS | MAR_M_ANN_ELS | M_ANN_ELS;
$Element2Type->[MATHMLNS]->{q@mi@} = MATHML_NS_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS;
$Element2Type->[MATHMLNS]->{q@mn@} = MATHML_NS_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS;
$Element2Type->[MATHMLNS]->{q@mo@} = MATHML_NS_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS;
$Element2Type->[MATHMLNS]->{q@ms@} = MATHML_NS_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS;
$Element2Type->[MATHMLNS]->{q@mtext@} = MATHML_NS_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS;
$Element2Type->[SVGNS]->{q@*@} = SVG_NS_ELS;
$Element2Type->[SVGNS]->{q@desc@} = SVG_NS_ELS | S_DES_S_FOR_S_TIT_ELS;
$Element2Type->[SVGNS]->{q@foreignObject@} = SVG_NS_ELS | S_DES_S_FOR_S_TIT_ELS;
sub SVG_SCRIPT_EL () { SVG_NS_ELS | 68719476736 } $Element2Type->[SVGNS]->{q@script@} = SVG_SCRIPT_EL;
$Element2Type->[SVGNS]->{q@title@} = SVG_NS_ELS | S_DES_S_FOR_S_TIT_ELS;
sub AFTER_AFTER_BODY_IM () { 1 }
sub AFTER_AFTER_FRAMESET_IM () { 2 }
sub AFTER_BODY_IM () { 3 }
sub AFTER_FRAMESET_IM () { 4 }
sub AFTER_HEAD_IM () { 5 }
sub BEFORE_HEAD_IM () { 6 }
sub BEFORE_HTML_IM () { 7 }
sub BEFORE_IGNORED_NEWLINE_IM () { 8 }
sub BEFORE_IGNORED_NEWLINE_AND_TEXT_IM () { 9 }
sub IN_BODY_IM () { 10 }
sub IN_CAPTION_IM () { 11 }
sub IN_CELL_IM () { 12 }
sub IN_COLUMN_GROUP_IM () { 13 }
sub IN_FOREIGN_CONTENT_IM () { 14 }
sub IN_FRAMESET_IM () { 15 }
sub IN_HEAD_IM () { 16 }
sub IN_HEAD_NOSCRIPT_IM () { 17 }
sub IN_ROW_IM () { 18 }
sub IN_SELECT_IM () { 19 }
sub IN_SELECT_IN_TABLE_IM () { 20 }
sub IN_TABLE_IM () { 21 }
sub IN_TABLE_BODY_IM () { 22 }
sub IN_TABLE_TEXT_IM () { 23 }
sub IN_TEMPLATE_IM () { 24 }
sub INITIAL_IM () { 25 }
sub TEXT_IM () { 26 }
my $QPublicIDPrefixPattern = qr{(?:(?:-(?://(?:S(?:OFTQUAD(?: SOFTWARE//DTD HOTMETAL PRO 6\.0::19990601|//DTD HOTMETAL PRO 4\.0::19971010)::EXTENSIONS TO HTML 4\.0|UN MICROSYSTEMS CORP\.//DTD HOTJAVA(?: STRICT)? HTML|Q//DTD HTML 2\.0 HOTMETAL \+ EXTENSIONS|PYGLASS//DTD HTML 2\.0 EXTENDED)|W(?:3(?:C//DTD HTML (?:3\.2(?: (?:DRAFT|FINAL)|S DRAFT)?|4\.0 (?:TRANSITIONAL|FRAMESET))|O//DTD W3 HTML 3\.0)|EBTECHS//DTD MOZILLA HTML 2\.0)|IETF//DTD HTML (?:2\.(?:0(?: (?:STRICT(?: LEVEL [12])?|LEVEL [12]))?|1E)|3\.(?:2(?: FINAL)?|0))|MICROSOFT//DTD INTERNET EXPLORER [23]\.0 (?:HTML(?: STRICT)?|TABLES)|O'REILLY AND ASSOCIATES//DTD HTML (?:EXTEND(?:ED RELAX)?ED 1|2)\.0|A(?:DVASOFT LTD|S)//DTD HTML 3\.0 ASWEDIT \+ EXTENSIONS|NETSCAPE COMM\. CORP\.//DTD(?: STRICT)? HTML)//|//(?:W(?:3C//DTD (?:HTML (?:EXPERIMENTAL (?:19960712|970421)|3 1995-03-24)|W3 HTML)|EBTECHS//DTD MOZILLA HTML)|IETF//DTD HTML(?: (?:STRICT(?: LEVEL [0123])?|LEVEL [0123]|3))?|METRIUS//DTD METRIUS PRESENTATIONAL)//)|\+//SILMARIL//DTD HTML PRO V0R11 19970101//))};
my $LQPublicIDPrefixPattern = qr{(?:-//W3C//DTD XHTML 1\.0 (?:TRANSITIONAL|FRAMESET)//)};
my $QorLQPublicIDPrefixPattern = qr{(?:-//W3C//DTD HTML 4\.01 (?:TRANSITIONAL|FRAMESET)//)};
my $QPublicIDs = {q<-//W3O//DTD W3 HTML STRICT 3.0//EN//> => 1, q<-/W3C/DTD HTML 4.0 TRANSITIONAL/EN> => 1, q<HTML> => 1};
my $QSystemIDs = {q<HTTP://WWW.IBM.COM/DATA/DTD/V11/IBMXHTML1-TRANSITIONAL.DTD> => 1};
my $OPPublicIDToSystemID = {q<-//W3C//DTD HTML 4.0//EN> => q<http://www.w3.org/TR/REC-html40/strict.dtd>, q<-//W3C//DTD HTML 4.01//EN> => q<http://www.w3.org/TR/html4/strict.dtd>, q<-//W3C//DTD XHTML 1.0 Strict//EN> => q<http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd>, q<-//W3C//DTD XHTML 1.1//EN> => q<http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd>};
my $OPPublicIDOnly = {q<-//W3C//DTD HTML 4.0//EN> => 1, q<-//W3C//DTD HTML 4.01//EN> => 1};

      my $TCA = [undef,
        ## [1] after after body;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token->{data} => 0];
          
        },
      ,
        ## [2] after after body;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [3] after after body;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [4] after after body;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [5] after after body;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'after-after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [6] after after frameset;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token->{data} => 0];
          
        },
      ,
        ## [7] after after frameset;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-after-frameset-else', index => $token->{index}};
        },
      ,
        ## [8] after after frameset;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [9] after after frameset;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-after-frameset-else', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [10] after after frameset;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'after-after-frameset-else', index => $token->{index}};
            }
            
          
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
          }
        
        },
      ,
        ## [11] after body;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token->{data} => $OE->[0]->{id}];
          
        },
      ,
        ## [12] after body;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-body-doctype', index => $token->{index}};
        },
      ,
        ## [13] after body;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [14] after body;END:html
        sub {
          my $token = $_;

          if (defined $CONTEXT) {
            push @$Errors, {type => 'after-body-end-html', index => $token->{index}};
          } else {
            
          $IM = AFTER_AFTER_BODY_IM;
          #warn "Insertion mode changed to |after after body| ($IM)";
        
          }
        
        },
      ,
        ## [15] after body;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [16] after body;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [17] after body;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'after-body-else', index => $token->{index}};

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [18] after frameset;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [19] after frameset;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-frameset-doctype', index => $token->{index}};
        },
      ,
        ## [20] after frameset;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-frameset-else', index => $token->{index}};
        },
      ,
        ## [21] after frameset;END:html
        sub {
          
          $IM = AFTER_AFTER_FRAMESET_IM;
          #warn "Insertion mode changed to |after after frameset| ($IM)";
        
        },
      ,
        ## [22] after frameset;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [23] after frameset;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-frameset-else', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [24] after frameset;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'after-frameset-else', index => $token->{index}};
            }
            
          
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
          }
        
        },
      ,
        ## [25] after head;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [26] after head;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-doctype', index => $token->{index}};
        },
      ,
        ## [27] after head;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-end-else', index => $token->{index}};
        },
      ,
        ## [28] after head;END:body,br,html
        sub {
          my $token = $_;

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [29] after head;EOF
        sub {
          my $token = $_;

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [30] after head;START-ELSE
        sub {
          my $token = $_;

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [31] after head;START:base,basefont bgsound link
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;
        },
      ,
        ## [32] after head;START:body
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => $token->{attr_list},
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        
        },
      ,
        ## [33] after head;START:frameset
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'frameset',
                 attr_list => $token->{attr_list},
                 et => (FRAMESET_EL), aet => (FRAMESET_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_FRAMESET_IM;
          #warn "Insertion mode changed to |in frameset| ($IM)";
        
        },
      ,
        ## [34] after head;START:head
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-head', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [35] after head;START:meta
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'meta',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        if (defined $token->{attrs}->{charset}) {
          push @$OP, ['change-the-encoding', $token->{attrs}->{charset}->{value}, $token->{attrs}->{charset}];
        } elsif (defined $token->{attrs}->{'http-equiv'} and
                 defined $token->{attrs}->{content}) {
          if ($token->{attrs}->{'http-equiv'}->{value}
                  =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
              $token->{attrs}->{content}->{value}
                  =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                        [\x09\x0A\x0C\x0D\x20]*=
                        [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                        ([^"'\x09\x0A\x0C\x0D\x20]
                         [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            push @$OP, ['change-the-encoding', $1, $token->{attrs}->{content}];
          }
        }
      
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;
        },
      ,
        ## [36] after head;START:noframes,style
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [37] after head;START:script
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'script',
                 attr_list => $token->{attr_list},
                 et => (SCRIPT_EL), aet => (SCRIPT_EL) , script_flags => 1};
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$State = SCRIPT_DATA_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [38] after head;START:template
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'template',
                 attr_list => $token->{attr_list},
                 et => (TEMPLATE_EL), aet => (TEMPLATE_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
push @$AFE, '#marker';

        $FRAMESET_OK = 0;
      

          $IM = IN_TEMPLATE_IM;
          #warn "Insertion mode changed to |in template| ($IM)";
        

        push @$TEMPLATE_IMS, q@in template@;
      
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [39] after head;START:title
        sub {
          my $token = $_;
push @$Errors, {type => 'after-head-start-b3lmnsstt', index => $token->{index}};
push @$OE, $HEAD_ELEMENT;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'title',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$State = RCDATA_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
@$OE = grep { $_ ne $HEAD_ELEMENT } @$OE;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [40] after head;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          
        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [41] before head;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [42] before head;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-head-doctype', index => $token->{index}};
        },
      ,
        ## [43] before head;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-head-end-else', index => $token->{index}};
        },
      ,
        ## [44] before head;END:body,br,head,html
        sub {
          my $token = $_;

        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [45] before head;EOF
        sub {
          my $token = $_;

        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [46] before head;START-ELSE
        sub {
          my $token = $_;

        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [47] before head;START:head
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => $token->{attr_list},
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$HEAD_ELEMENT = $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
        },
      ,
        ## [48] before head;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
        }
        if (length $token->{value}) {
          
        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [49] before html;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token->{data} => 0];
          
        },
      ,
        ## [50] before html;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-html-doctype', index => $token->{index}};
        },
      ,
        ## [51] before html;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-html-end-else', index => $token->{index}};
        },
      ,
        ## [52] before html;END:body,br,head,html
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => [],
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [53] before html;EOF
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => [],
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [54] before html;START-ELSE
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => [],
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [55] before html;START:html
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => $token->{attr_list},
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache', $token->{attrs}->{manifest}];

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        
        },
      ,
        ## [56] before html;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
        }
        if (length $token->{value}) {
          
        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => [],
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        

        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [57] before ignored newline and text;ELSE
        sub {
          
    $IM = TEXT_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  
        },
      ,
        ## [58] before ignored newline and text;TEXT
        sub {
          
    $_->{value} =~ s/^\x0A//; # XXXindex
    $IM = TEXT_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  
        },
      ,
        ## [59] before ignored newline;ELSE
        sub {
          
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  
        },
      ,
        ## [60] before ignored newline;TEXT
        sub {
          
    $_->{value} =~ s/^\x0A//; # XXXindex
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  
        },
      ,
        ## [61] in body;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [62] in body;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-doctype', index => $token->{index}};
        },
      ,
        ## [63] in body;END-ELSE
        sub {
          my $token = $_;

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{ns} == HTMLNS and $_node->{local_name} eq $token->{tag_name}) {
            {
            my @popped;
            push @popped, pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS) and not ($OE->[-1]->{ns} == HTMLNS and $OE->[-1]->{local_name} eq $token->{tag_name});
            push @$OP, ['popped', \@popped];
          }

          if ($OE->[-1] eq $_node) {
            push @$Errors, {type => 'in-body-end-else', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $_node);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
return;
          } else {
            
          if ($_node->{et} & (ADD_DIV_ELS | APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | P_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            push @$Errors, {type => 'in-body-end-else-2', index => $token->{index}};
return;
          }
        
          }
        
          }
        
        },
      ,
        ## [64] in body;END:a,b big code em i s small strike strong tt u,font,nobr
        sub {
          my $token = $_;
aaa ($token, $token->{tag_name});
        },
      ,
        ## [65] in body;END:address article aside details dialog dir figcaption figure footer header hgroup main nav section summary,blockquote center div dl menu ol ul,button,fieldset,listing pre
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-a3bbcd5f4hhlmmnopssu', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name})) {
            push @$Errors, {type => 'in-body-end-a3bbcd5f4hhlmmnopssu-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name});
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
        },
      ,
        ## [66] in body;END:applet marquee,object
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-applet-marquee-object', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name})) {
            push @$Errors, {type => 'in-body-end-applet-marquee-object-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name});
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      
          }
        
        },
      ,
        ## [67] in body;END:body
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (BOD_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-body', index => $token->{index}};
          } else {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          unless ($_->{et} & (BOD_ELS | DD_ELS | DT_ELS | HTM_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TR_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-body-2', index => $token->{index}};
          }
        

          $IM = AFTER_BODY_IM;
          #warn "Insertion mode changed to |after body| ($IM)";
        
          }
        
        },
      ,
        ## [68] in body;END:br
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-end-br', index => $token->{index}};
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node_br = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'br',
                 attr_list => [],
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node_br => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [69] in body;END:dd dt
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-dd-dt', index => $token->{index}};
          } else {
            {
            my @popped;
            push @popped, pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS) and not ($OE->[-1]->{ns} == HTMLNS and $OE->[-1]->{local_name} eq $token->{tag_name});
            push @$OP, ['popped', \@popped];
          }

          if (not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name})) {
            push @$Errors, {type => 'in-body-end-dd-dt-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name});
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
        },
      ,
        ## [70] in body;END:form
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    ) {
            my $_node = $FORM_ELEMENT;
$FORM_ELEMENT = undef;

          if ((not defined $_node) or 
(
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_ eq $_node) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    )) {
            push @$Errors, {type => 'in-body-end-form', index => $token->{index}};
return;
          }
        
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if ($OE->[-1] eq $_node) {
            push @$Errors, {type => 'in-body-end-form-2', index => $token->{index}};
          }
        
@$OE = grep { $_ ne $_node } @$OE;
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == FORM_EL) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-form-3', index => $token->{index}};
return;
          }
        
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} == FORM_EL)) {
            push @$Errors, {type => 'in-body-end-form-4', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == FORM_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
        },
      ,
        ## [71] in body;END:h1 h2 h3 h4 h5 h6
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (HHHHHH_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-h6', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name})) {
            push @$Errors, {type => 'in-body-end-h6-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HHHHHH_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
        },
      ,
        ## [72] in body;END:html
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (BOD_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-html', index => $token->{index}};
          } else {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          unless ($_->{et} & (BOD_ELS | DD_ELS | DT_ELS | HTM_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TR_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-html-2', index => $token->{index}};
          }
        

          $IM = AFTER_BODY_IM;
          #warn "Insertion mode changed to |after body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [73] in body;END:li
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (LI_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-li', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (LI_ELS))) {
            push @$Errors, {type => 'in-body-end-li-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (LI_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
        },
      ,
        ## [74] in body;END:p
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-p', index => $token->{index}};

        my $node_p = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'p',
                 attr_list => [],
                 et => (P_EL), aet => (P_EL) };
      

      push @$OP, ['insert', $node_p => $OE->[-1]->{id}];
    

push @$OE, $node_p;
          }
        
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
        },
      ,
        ## [75] in body;END:sarcasm
        sub {
          my $token = $_;

        ## Take a deep breath!
      

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{et} & HTML_NS_ELS and $_node->{local_name} eq $token->{tag_name}) {
            {
            my @popped;
            push @popped, pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS) and not ($OE->[-1]->{ns} == HTMLNS and $OE->[-1]->{local_name} eq $token->{tag_name});
            push @$OP, ['popped', \@popped];
          }

          if ($OE->[-1] eq $_node) {
            push @$Errors, {type => 'in-body-end-else', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $_node);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
return;
          } else {
            
          if ($_node->{et} & (ADD_DIV_ELS | APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | P_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            push @$Errors, {type => 'in-body-end-else-2', index => $token->{index}};
return;
          }
        
          }
        
          }
        
        },
      ,
        ## [76] in body;EOF
        sub {
          my $token = $_;

          if (@$TEMPLATE_IMS) {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    ) {
            push @$OP, ['stop-parsing'];
          } else {
            push @$Errors, {type => 'in-template-eof', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TEM_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      
pop @$TEMPLATE_IMS;
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          } else {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          unless ($_->{et} & (BOD_ELS | DD_ELS | DT_ELS | HTM_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TR_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-eof', index => $token->{index}};
          }
        
push @$OP, ['stop-parsing'];
          }
        
        },
      ,
        ## [77] in body;START-ELSE
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [78] in body;START:a
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$AFE) {
          last if not ref $_;
          if ($_->{et} == A_EL) {
            $result = 1;
            last;
          }
        }
        $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-a', index => $token->{index}};
aaa ($token, 'a', remove_from_afe_and_oe => 1);
          }
        
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'a',
                 attr_list => $token->{attr_list},
                 et => (A_EL), aet => (A_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [79] in body;START:address article aside details dialog dir figcaption figure footer header hgroup main nav section summary,blockquote center div dl menu ol ul,fieldset,p
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [80] in body;START:applet marquee,object
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;
push @$AFE, '#marker';

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [81] in body;START:area wbr,br,embed,img,keygen
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [82] in body;START:b big code em i s small strike strong tt u,font
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [83] in body;START:body
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-start-body', index => $token->{index}};

          if ((not ($OE->[1]->{et} & (BOD_ELS))) or 
($OE->[-1]->{et} & (HTM_ELS)) or 
(
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    )) {
            
          } else {
            
        $FRAMESET_OK = 0;
      

        push @$OP, ['set-if-missing', $token->{attr_list} => $OE->[1]->{id}]
            if @{$token->{attr_list}};
      
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [84] in body;START:button
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (BUT_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-button', index => $token->{index}};
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (BUT_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'button',
                 attr_list => $token->{attr_list},
                 et => (BUTTON_EL), aet => (BUTTON_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [85] in body;START:caption,col,colgroup,frame,head,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-start-c3fht6', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [86] in body;START:dd dt
        sub {
          my $token = $_;

        $FRAMESET_OK = 0;
      

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{et} & (DD_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (DD_ELS))) {
            push @$Errors, {type => 'in-body-start-dd-dt', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (DD_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (DT_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (DT_ELS))) {
            push @$Errors, {type => 'in-body-start-dd-dt-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (DT_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            last;
          } else {
            
          }
        
          }
        
          }
        
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [87] in body;START:form
        sub {
          my $token = $_;

          if ((defined $FORM_ELEMENT) and 
(
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    )) {
            push @$Errors, {type => 'in-body-start-form', index => $token->{index}};
          } else {
            
          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'form',
                 attr_list => $token->{attr_list},
                 et => (FORM_EL), aet => (FORM_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    ) {
            $FORM_ELEMENT = $node;
          }
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [88] in body;START:frameset
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-start-frameset', index => $token->{index}};

          if (($OE->[-1]->{et} & (HTM_ELS)) or 
(not ($OE->[1]->{et} & (BOD_ELS)))) {
            
          }
        

          if (not $FRAMESET_OK) {
            
          } else {
            
        push @$OP, ['remove', $OE->[1]->{id}];
      
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $OE->[1]);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'frameset',
                 attr_list => $token->{attr_list},
                 et => (FRAMESET_EL), aet => (FRAMESET_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          $IM = IN_FRAMESET_IM;
          #warn "Insertion mode changed to |in frameset| ($IM)";
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [89] in body;START:h1 h2 h3 h4 h5 h6
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

          if ($OE->[-1]->{et} & (HHHHHH_ELS)) {
            push @$Errors, {type => 'in-body-start-h6', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [90] in body;START:hr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'hr',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [91] in body;START:html
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-start-html', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            
          }
        

        push @$OP, ['set-if-missing', $token->{attr_list} => $OE->[0]->{id}]
            if @{$token->{attr_list}};
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [92] in body;START:iframe
        sub {
          my $token = $_;

        $FRAMESET_OK = 0;
      

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'iframe',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [93] in body;START:image
        sub {
          my $token = $_;
push @$Errors, {type => 'in-body-start-image', index => $token->{index}};
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node_img = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'img',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | IMG_ELS), aet => (HTML_NS_ELS | IMG_ELS) };
      

      push @$OP, ['insert', $node_img => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [94] in body;START:input
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'input',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS), aet => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

          if (
      defined $token->{attrs}->{type} and
      do {
        my $value = $token->{attrs}->{type}->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        $value eq q@hidden@;
      }
    ) {
            
        $FRAMESET_OK = 0;
      
          }
        
        },
      ,
        ## [95] in body;START:li
        sub {
          my $token = $_;

        $FRAMESET_OK = 0;
      

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{et} & (LI_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (LI_ELS))) {
            push @$Errors, {type => 'in-body-start-li', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (LI_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            last;
          } else {
            
          }
        
          }
        
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'li',
                 attr_list => $token->{attr_list},
                 et => (LI_EL), aet => (LI_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [96] in body;START:listing pre
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      

        $ORIGINAL_IM = $IM;
        $IM = BEFORE_IGNORED_NEWLINE_IM;
      
        },
      ,
        ## [97] in body;START:math
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];
my $ns = MATHMLNS;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
        },
      ,
        ## [98] in body;START:menuitem param source track
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [99] in body;START:nobr
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == NOBR_EL) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-nobr', index => $token->{index}};
aaa ($token, 'nobr');
&reconstruct_afe if @$AFE and ref $AFE->[-1];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'nobr',
                 attr_list => $token->{attr_list},
                 et => (NOBR_EL), aet => (NOBR_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [100] in body;START:noembed
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noembed',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [101] in body;START:noscript
        sub {
          my $token = $_;

          if ($Scripting) {
            
        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
          } else {
            &reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [102] in body;START:optgroup,option
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} == OPTION_EL) {
            push @$OP, ['popped', [pop @$OE]];
          }
        
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [103] in body;START:plaintext
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'plaintext',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = PLAINTEXT_STATE;
        },
      ,
        ## [104] in body;START:rp rt
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == RUBY_EL) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);
          }
        

          if (not ($OE->[-1]->{et} == RUBY_EL)) {
            push @$Errors, {type => 'in-body-start-rp-rt', index => $token->{index}};
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [105] in body;START:select
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'select',
                 attr_list => $token->{attr_list},
                 et => (SELECT_EL), aet => (SELECT_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

        $FRAMESET_OK = 0;
      

          if ($IM == IN_TABLE_IM or $IM == IN_CAPTION_IM or $IM == IN_TABLE_BODY_IM or $IM == IN_ROW_IM or $IM == IN_CELL_IM) {
            
          $IM = IN_SELECT_IN_TABLE_IM;
          #warn "Insertion mode changed to |in select in table| ($IM)";
        
          } else {
            
          $IM = IN_SELECT_IM;
          #warn "Insertion mode changed to |in select| ($IM)";
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [106] in body;START:svg
        sub {
          my $token = $_;
&reconstruct_afe if @$AFE and ref $AFE->[-1];
my $ns = SVGNS;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
        },
      ,
        ## [107] in body;START:table
        sub {
          my $token = $_;

          if ((not $QUIRKS) and 
(
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    )) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'table',
                 attr_list => $token->{attr_list},
                 et => (TABLE_EL), aet => (TABLE_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        
        },
      ,
        ## [108] in body;START:textarea
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'textarea',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS), aet => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RCDATA_STATE;
$ORIGINAL_IM = $IM;

        $FRAMESET_OK = 0;
      

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        

        $IM = BEFORE_IGNORED_NEWLINE_AND_TEXT_IM;
      
        },
      ,
        ## [109] in body;START:xmp
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
&reconstruct_afe if @$AFE and ref $AFE->[-1];

        $FRAMESET_OK = 0;
      

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'xmp',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [110] in body;TEXT
        sub {
          my $token = $_;

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
        },
      ,
        ## [111] in caption;END:body,col,colgroup,html,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-caption-end-bccht6', index => $token->{index}};
        },
      ,
        ## [112] in caption;END:caption
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (CAP_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-caption-end-caption', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (CAP_ELS))) {
            push @$Errors, {type => 'in-caption-end-caption-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (CAP_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        
          }
        
        },
      ,
        ## [113] in caption;END:table
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (CAP_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-caption-end-table', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (CAP_ELS))) {
            push @$Errors, {type => 'in-caption-end-table-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (CAP_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [114] in caption;START:caption,col,colgroup,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (CAP_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-caption-start-c3t6', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (CAP_ELS))) {
            push @$Errors, {type => 'in-caption-start-c3t6-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (CAP_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [115] in caption;TEXT
        sub {
          my $token = $_;

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
        },
      ,
        ## [116] in cell;END:body,caption,col,colgroup,html
        sub {
          my $token = $_;
push @$Errors, {type => 'in-cell-end-bc3h', index => $token->{index}};
        },
      ,
        ## [117] in cell;END:table,tbody tfoot thead,tr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-cell-end-t5', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (TD_TH_ELS))) {
            push @$Errors, {type => '-steps-close-the-cell', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TD_TH_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [118] in cell;END:td th
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-cell-end-td-th', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name})) {
            push @$Errors, {type => 'in-cell-end-td-th-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & HTML_NS_ELS and $OE->[-1]->{local_name} eq $token->{tag_name});
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        
          }
        
        },
      ,
        ## [119] in cell;START:caption,col,colgroup,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TD_TH_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-cell-start-c3t6', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (TD_TH_ELS))) {
            push @$Errors, {type => '-steps-close-the-cell', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TD_TH_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [120] in cell;TEXT
        sub {
          my $token = $_;

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
        },
      ,
        ## [121] in column group;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [122] in column group;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-column-group-doctype', index => $token->{index}};
        },
      ,
        ## [123] in column group;END-ELSE
        sub {
          my $token = $_;

          if (not ($OE->[-1]->{et} & (COL_ELS))) {
            push @$Errors, {type => 'in-column-group-else', index => $token->{index}};
          } else {
            push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [124] in column group;END:col
        sub {
          my $token = $_;
push @$Errors, {type => 'in-column-group-end-col', index => $token->{index}};
        },
      ,
        ## [125] in column group;END:colgroup
        sub {
          my $token = $_;

          if (not ($OE->[-1]->{et} & (COL_ELS))) {
            push @$Errors, {type => 'in-column-group-end-colgroup', index => $token->{index}};
          } else {
            push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        
          }
        
        },
      ,
        ## [126] in column group;START-ELSE
        sub {
          my $token = $_;

          if (not ($OE->[-1]->{et} & (COL_ELS))) {
            push @$Errors, {type => 'in-column-group-else', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [127] in column group;START:col
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'col',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [128] in column group;TEXT
        sub {
          my $token = $_;

          if (not ($OE->[-1]->{et} & (COL_ELS))) {
            
          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-column-group-else', index => $token->{index}};
            }
            
          
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
          }
        
          } else {
            
        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
          }
        
        },
      ,
        ## [129] in foreign content;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [130] in foreign content;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-foreign-content-doctype', index => $token->{index}};
        },
      ,
        ## [131] in foreign content;END-ELSE
        sub {
          my $token = $_;

          if (not ((
        $OE->[-1]->{local_name} eq $token->{tag_name} or
        do {
          my $ln = $OE->[-1]->{local_name};
          $ln =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $ln eq $token->{tag_name};
        }
      ))) {
            push @$Errors, {type => 'in-foreign-content-end-else', index => $token->{index}};
          }
        

          my $_node_i = $#$OE;
          my $_node = $OE->[$_node_i];
          {
            
          if ($_node->{et} & (HTM_ELS)) {
            return;
          }
        

          if ((
        $_node->{local_name} eq $token->{tag_name} or
        do {
          my $ln = $_node->{local_name};
          $ln =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $ln eq $token->{tag_name};
        }
      )) {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $_node);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
return;
          }
        
            $_node_i--;
            $_node = $OE->[$_node_i];
            
          if (not ($_node->{et} & (HTML_NS_ELS))) {
            
          } else {
            
        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
last;
          }
        
            redo;
          }
        
        },
      ,
        ## [132] in foreign content;END:script
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} == SVG_SCRIPT_EL) {
            my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];
push @$OP, ['script', $script->{id}];
          } else {
            
          if (not ((
        $OE->[-1]->{local_name} eq $token->{tag_name} or
        do {
          my $ln = $OE->[-1]->{local_name};
          $ln =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $ln eq $token->{tag_name};
        }
      ))) {
            push @$Errors, {type => 'in-foreign-content-end-script', index => $token->{index}};
          }
        

          my $_node_i = $#$OE;
          my $_node = $OE->[$_node_i];
          {
            
          if ($_node->{et} & (HTM_ELS)) {
            return;
          }
        

          if ((
        $_node->{local_name} eq $token->{tag_name} or
        do {
          my $ln = $_node->{local_name};
          $ln =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
          $ln eq $token->{tag_name};
        }
      )) {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $_node);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
return;
          }
        
            $_node_i--;
            $_node = $OE->[$_node_i];
            
          if (not ($_node->{et} & (HTML_NS_ELS))) {
            
          } else {
            
        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
last;
          }
        
            redo;
          }
        
          }
        
        },
      ,
        ## [133] in foreign content;EOF
        sub {
          
        },
      ,
        ## [134] in foreign content;START-ELSE
        sub {
          my $token = $_;

          if ($OE->[-1]->{aet} & (SVG_NS_ELS)) {
            
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      
          }
        

          ## Adjusted current node
          my $ns = ((defined $CONTEXT and @$OE == 1) ? $CONTEXT : $OE->[-1])->{ns};
        

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = $token->{attrs}->{encoding}->{value};
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} = $node->{et} = M_ANN_M_ANN_ELS;
            }
          }
        

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            
          if (($token->{tag_name} eq q@script@) and 
($OE->[-1]->{et} & (SVG_NS_ELS))) {
            
          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];
push @$OP, ['script', $script->{id}];
          } else {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
          }
        
        },
      ,
        ## [135] in foreign content;START:b big code em i s small strike strong tt u,blockquote center div dl menu ol ul,body,br,dd dt,embed,h1 h2 h3 h4 h5 h6,head,hr,img,li,listing pre,meta,nobr,p,ruby span sub sup var,table
        sub {
          my $token = $_;
push @$Errors, {type => 'in-foreign-content-start-b5ccd4eeh8iillmmnopprs7ttuuv', index => $token->{index}};

          if (defined $CONTEXT) {
            
          if ($OE->[-1]->{aet} & (SVG_NS_ELS)) {
            
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      
          }
        

          ## Adjusted current node
          my $ns = ((defined $CONTEXT and @$OE == 1) ? $CONTEXT : $OE->[-1])->{ns};
        

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = $token->{attrs}->{encoding}->{value};
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} = $node->{et} = M_ANN_M_ANN_ELS;
            }
          }
        

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            
          if (($token->{tag_name} eq q@script@) and 
($OE->[-1]->{et} & (SVG_NS_ELS))) {
            
          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];
push @$OP, ['script', $script->{id}];
          } else {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
          }
        
          } else {
            push @$OP, ['popped', [pop @$OE]];
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTML_NS_ELS | M_ANN_M_ANN_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS));
          push @$OP, ['popped', \@popped];
        }

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [136] in foreign content;START:font
        sub {
          my $token = $_;

          if ($token->{attrs}->{q@color@} or 
$token->{attrs}->{q@face@} or 
$token->{attrs}->{q@size@}) {
            push @$Errors, {type => 'in-foreign-content-start-font', index => $token->{index}};

          if (defined $CONTEXT) {
            
          if ($OE->[-1]->{aet} & (SVG_NS_ELS)) {
            
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      
          }
        

          ## Adjusted current node
          my $ns = ((defined $CONTEXT and @$OE == 1) ? $CONTEXT : $OE->[-1])->{ns};
        

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = $token->{attrs}->{encoding}->{value};
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} = $node->{et} = M_ANN_M_ANN_ELS;
            }
          }
        

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            
          if (($token->{tag_name} eq q@script@) and 
($OE->[-1]->{et} & (SVG_NS_ELS))) {
            
          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];
push @$OP, ['script', $script->{id}];
          } else {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
          }
        
          } else {
            push @$OP, ['popped', [pop @$OE]];
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTML_NS_ELS | M_ANN_M_ANN_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS));
          push @$OP, ['popped', \@popped];
        }

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
          } else {
            
          if ($OE->[-1]->{aet} & (SVG_NS_ELS)) {
            
        $token->{tag_name} = $Web::HTML::ParserData::SVGElementNameFixup->{$token->{tag_name}} || $token->{tag_name};
      
          }
        

          ## Adjusted current node
          my $ns = ((defined $CONTEXT and @$OE == 1) ? $CONTEXT : $OE->[-1])->{ns};
        

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

          if ($ns == MATHMLNS and $node->{local_name} eq 'annotation-xml' and
              defined $token->{attrs}->{encoding}) {
            my $encoding = $token->{attrs}->{encoding}->{value};
            $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
            if ($encoding eq 'text/html' or
                $encoding eq 'application/xhtml+xml') {
              $node->{aet} = $node->{et} = M_ANN_M_ANN_ELS;
            }
          }
        

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            
          if (($token->{tag_name} eq q@script@) and 
($OE->[-1]->{et} & (SVG_NS_ELS))) {
            
          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];
push @$OP, ['script', $script->{id}];
          } else {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
          }
        
          }
        
        },
      ,
        ## [137] in foreign content;TEXT
        sub {
          my $token = $_;

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-foreign-content-null', index => $token->{index}};
            }
            
      push @$OP, ['text', $value => $OE->[-1]->{id}];
    
          
                }
              }
            } else {
              
      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
        },
      ,
        ## [138] in frameset;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [139] in frameset;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-frameset-doctype', index => $token->{index}};
        },
      ,
        ## [140] in frameset;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-frameset-else', index => $token->{index}};
        },
      ,
        ## [141] in frameset;END:frameset
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} & (HTM_ELS)) {
            push @$Errors, {type => 'in-frameset-end-frameset', index => $token->{index}};
          } else {
            push @$OP, ['popped', [pop @$OE]];

          if ((defined $CONTEXT) and 
(not ($OE->[-1]->{et} == FRAMESET_EL))) {
            
          $IM = AFTER_FRAMESET_IM;
          #warn "Insertion mode changed to |after frameset| ($IM)";
        
          }
        
          }
        
        },
      ,
        ## [142] in frameset;EOF
        sub {
          my $token = $_;

          if (not ($OE->[-1]->{et} & (HTM_ELS))) {
            push @$Errors, {type => 'in-frameset-eof', index => $token->{index}};
          }
        
push @$OP, ['stop-parsing'];
        },
      ,
        ## [143] in frameset;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-frameset-else', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [144] in frameset;START:frame
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'frame',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [145] in frameset;START:frameset
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'frameset',
                 attr_list => $token->{attr_list},
                 et => (FRAMESET_EL), aet => (FRAMESET_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [146] in frameset;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x09\x0A\x0C\x20]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-frameset-else', index => $token->{index}};
            }
            
          
            }
            if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
              
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
          }
        
        },
      ,
        ## [147] in head noscript;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-doctype', index => $token->{index}};
        },
      ,
        ## [148] in head noscript;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-end-else', index => $token->{index}};
        },
      ,
        ## [149] in head noscript;END:br
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-else', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [150] in head noscript;END:noscript
        sub {
          push @$OP, ['popped', [pop @$OE]];

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
        },
      ,
        ## [151] in head noscript;EOF
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-else', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [152] in head noscript;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-else', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [153] in head noscript;START:head,noscript
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-noscript-start-head-noscript', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [154] in head noscript;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'in-head-noscript-else', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [155] in head;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [156] in head;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-doctype', index => $token->{index}};
        },
      ,
        ## [157] in head;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-end-else', index => $token->{index}};
        },
      ,
        ## [158] in head;END:body,br,html
        sub {
          my $token = $_;
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [159] in head;END:head
        sub {
          push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        
        },
      ,
        ## [160] in head;END:template
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-head-end-template', index => $token->{index}};
          } else {
            pop @$OE while $OE->[-1]->{et} & (CAP_ELS | COL_ELS | DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TR_ELS);

          if (not ($OE->[-1]->{et} & (TEM_ELS))) {
            push @$Errors, {type => 'in-head-end-template-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TEM_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      
pop @$TEMPLATE_IMS;
&reset_im;
          }
        
        },
      ,
        ## [161] in head;EOF
        sub {
          my $token = $_;
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [162] in head;START-ELSE
        sub {
          my $token = $_;
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [163] in head;START:base,basefont bgsound link
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [164] in head;START:head
        sub {
          my $token = $_;
push @$Errors, {type => 'in-head-start-head', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [165] in head;START:meta
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'meta',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        if (defined $token->{attrs}->{charset}) {
          push @$OP, ['change-the-encoding', $token->{attrs}->{charset}->{value}, $token->{attrs}->{charset}];
        } elsif (defined $token->{attrs}->{'http-equiv'} and
                 defined $token->{attrs}->{content}) {
          if ($token->{attrs}->{'http-equiv'}->{value}
                  =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
              $token->{attrs}->{content}->{value}
                  =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                        [\x09\x0A\x0C\x0D\x20]*=
                        [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                        ([^"'\x09\x0A\x0C\x0D\x20]
                         [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            push @$OP, ['change-the-encoding', $1, $token->{attrs}->{content}];
          }
        }
      
        },
      ,
        ## [166] in head;START:noframes,style
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [167] in head;START:noscript
        sub {
          my $token = $_;

          if ($Scripting) {
            
        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
          } else {
            
        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          $IM = IN_HEAD_NOSCRIPT_IM;
          #warn "Insertion mode changed to |in head noscript| ($IM)";
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [168] in head;START:script
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'script',
                 attr_list => $token->{attr_list},
                 et => (SCRIPT_EL), aet => (SCRIPT_EL) , script_flags => 1};
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = SCRIPT_DATA_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [169] in head;START:template
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'template',
                 attr_list => $token->{attr_list},
                 et => (TEMPLATE_EL), aet => (TEMPLATE_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
push @$AFE, '#marker';

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      

          $IM = IN_TEMPLATE_IM;
          #warn "Insertion mode changed to |in template| ($IM)";
        

        push @$TEMPLATE_IMS, q@in template@;
      
        },
      ,
        ## [170] in head;START:title
        sub {
          my $token = $_;

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'title',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RCDATA_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [171] in head;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
        }
        if (length $token->{value}) {
          push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [172] in row;END:body,caption,col,colgroup,html,td th
        sub {
          my $token = $_;
push @$Errors, {type => 'in-row-end-bc3htt', index => $token->{index}};
        },
      ,
        ## [173] in row;END:table
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TR_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-row-end-table', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TEM_ELS | TR_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [174] in row;END:tbody tfoot thead
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-row-end-tbody-tfoot-thead', index => $token->{index}};
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TR_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TEM_ELS | TR_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [175] in row;END:tr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TR_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-row-end-tr', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TEM_ELS | TR_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        
          }
        
        },
      ,
        ## [176] in row;START:caption,col,colgroup,tbody tfoot thead,tr
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TR_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-row-start-c3t4', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TEM_ELS | TR_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [177] in row;START:td th
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TEM_ELS | TR_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          $IM = IN_CELL_IM;
          #warn "Insertion mode changed to |in cell| ($IM)";
        
push @$AFE, '#marker';

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [178] in row;TEXT
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) {
            $TABLE_CHARS = [];
$ORIGINAL_IM = $IM;

          $IM = IN_TABLE_TEXT_IM;
          #warn "Insertion mode changed to |in table text| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          } else {
            push @$Errors, {type => 'in-table-char', index => $token->{index}};

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
        },
      ,
        ## [179] in select in table;END:caption,table,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-in-table-end-ct7', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == SELECT_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [180] in select in table;START:caption,table,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-in-table-start-ct7', index => $token->{index}};
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == SELECT_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [181] in select in table;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-select-null', index => $token->{index}};
            }
            
          
            }
          }
        
        },
      ,
        ## [182] in select;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [183] in select;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-doctype', index => $token->{index}};
        },
      ,
        ## [184] in select;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-else', index => $token->{index}};
        },
      ,
        ## [185] in select;END:optgroup
        sub {
          my $token = $_;

          if (($OE->[-1]->{et} == OPTION_EL) and 
($OE->[-2]->{et} == OPTGROUP_EL)) {
            push @$OP, ['popped', [pop @$OE]];
          }
        

          if ($OE->[-1]->{et} == OPTGROUP_EL) {
            push @$OP, ['popped', [pop @$OE]];
          } else {
            push @$Errors, {type => 'in-select-end-optgroup', index => $token->{index}};
          }
        
        },
      ,
        ## [186] in select;END:option
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} == OPTION_EL) {
            push @$OP, ['popped', [pop @$OE]];
          } else {
            push @$Errors, {type => 'in-select-end-option', index => $token->{index}};
          }
        
        },
      ,
        ## [187] in select;END:select
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == SELECT_EL) {
            $result = 1;
            last;
          } elsif (not ($_->{et} & (OPT_OPT_ELS))) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-select-end-select', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == SELECT_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;
          }
        
        },
      ,
        ## [188] in select;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-else', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [189] in select;START:input,keygen,textarea
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-start-input-keygen-textarea', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == SELECT_EL) {
            $result = 1;
            last;
          } elsif (not ($_->{et} & (OPT_OPT_ELS))) { last; 
          }
        }
        not $result;
      }
    ) {
            
          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == SELECT_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [190] in select;START:optgroup
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} == OPTION_EL) {
            push @$OP, ['popped', [pop @$OE]];
          }
        

          if ($OE->[-1]->{et} == OPTGROUP_EL) {
            push @$OP, ['popped', [pop @$OE]];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'optgroup',
                 attr_list => $token->{attr_list},
                 et => (OPTGROUP_EL), aet => (OPTGROUP_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [191] in select;START:option
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} == OPTION_EL) {
            push @$OP, ['popped', [pop @$OE]];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'option',
                 attr_list => $token->{attr_list},
                 et => (OPTION_EL), aet => (OPTION_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [192] in select;START:select
        sub {
          my $token = $_;
push @$Errors, {type => 'in-select-start-select', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == SELECT_EL) {
            $result = 1;
            last;
          } elsif (not ($_->{et} & (OPT_OPT_ELS))) { last; 
          }
        }
        not $result;
      }
    ) {
            
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} == SELECT_EL);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [193] in select;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              
      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-select-null', index => $token->{index}};
            }
            
          
            }
          }
        
        },
      ,
        ## [194] in table body;END:body,caption,col,colgroup,html,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-body-end-bc3ht3', index => $token->{index}};
        },
      ,
        ## [195] in table body;END:table
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TBO_TFO_THE_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-table-body-end-table', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TBO_TFO_THE_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [196] in table body;END:tbody tfoot thead
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & HTML_NS_ELS and $_->{local_name} eq $token->{tag_name}) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-table-body-end-tbody-tfoot-thead', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TBO_TFO_THE_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        
          }
        
        },
      ,
        ## [197] in table body;START:caption,col,colgroup,tbody tfoot thead
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TBO_TFO_THE_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-table-body-start-c3t3', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TBO_TFO_THE_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$OP, ['popped', [pop @$OE]];

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [198] in table body;START:td th
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-body-start-td-th', index => $token->{index}};
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TBO_TFO_THE_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node_tr = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'tr',
                 attr_list => [],
                 et => (TR_EL), aet => (TR_EL) };
      

      push @$OP, ['insert', $node_tr => $OE->[-1]->{id}];
    

push @$OE, $node_tr;

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [199] in table body;START:tr
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TBO_TFO_THE_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'tr',
                 attr_list => $token->{attr_list},
                 et => (TR_EL), aet => (TR_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        
        },
      ,
        ## [200] in table body;TEXT
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) {
            $TABLE_CHARS = [];
$ORIGINAL_IM = $IM;

          $IM = IN_TABLE_TEXT_IM;
          #warn "Insertion mode changed to |in table text| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          } else {
            push @$Errors, {type => 'in-table-char', index => $token->{index}};

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
        },
      ,
        ## [201] in table text;COMMENT
        sub {
          my $token = $_;

          if (grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS) {
            push @$Errors, {type => 'in-table-text-else', index => $token->{index}};

          for my $token (@$TABLE_CHARS) {
            
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
          } else {
            
      push @$OP, ['text', (join '', map { $_->{value} } @$TABLE_CHARS) => $OE->[-1]->{id}];
    
          }
        

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [202] in table text;DOCTYPE
        sub {
          my $token = $_;

          if (grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS) {
            push @$Errors, {type => 'in-table-text-else', index => $token->{index}};

          for my $token (@$TABLE_CHARS) {
            
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
          } else {
            
      push @$OP, ['text', (join '', map { $_->{value} } @$TABLE_CHARS) => $OE->[-1]->{id}];
    
          }
        

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [203] in table text;END-ELSE
        sub {
          my $token = $_;

          if (grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS) {
            push @$Errors, {type => 'in-table-text-else', index => $token->{index}};

          for my $token (@$TABLE_CHARS) {
            
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
          } else {
            
      push @$OP, ['text', (join '', map { $_->{value} } @$TABLE_CHARS) => $OE->[-1]->{id}];
    
          }
        

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [204] in table text;EOF
        sub {
          my $token = $_;

          if (grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS) {
            push @$Errors, {type => 'in-table-text-else', index => $token->{index}};

          for my $token (@$TABLE_CHARS) {
            
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
          } else {
            
      push @$OP, ['text', (join '', map { $_->{value} } @$TABLE_CHARS) => $OE->[-1]->{id}];
    
          }
        

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [205] in table text;START-ELSE
        sub {
          my $token = $_;

          if (grep { $_->{value} =~ /[^\x09\x0A\x0C\x20]/ } @$TABLE_CHARS) {
            push @$Errors, {type => 'in-table-text-else', index => $token->{index}};

          for my $token (@$TABLE_CHARS) {
            
            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
          } else {
            
      push @$OP, ['text', (join '', map { $_->{value} } @$TABLE_CHARS) => $OE->[-1]->{id}];
    
          }
        

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [206] in table text;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              push @$TABLE_CHARS, {%$token, value => $1};
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-table-text-null', index => $token->{index}};
            }
            
          
            }
          }
        
        },
      ,
        ## [207] in table;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token->{data} => $OE->[-1]->{id}];
        
        },
      ,
        ## [208] in table;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-doctype', index => $token->{index}};
        },
      ,
        ## [209] in table;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        goto &{$ProcessIM->[IN_BODY_IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [210] in table;END:a,b big code em i s small strike strong tt u,font,nobr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
aaa_foster ($token, $token->{tag_name});
        },
      ,
        ## [211] in table;END:body,caption,col,colgroup,html,tbody tfoot thead,td th,tr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-end-bc3ht6', index => $token->{index}};
        },
      ,
        ## [212] in table;END:br
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-end-br', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node_br = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'br',
                 attr_list => [],
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node_br => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node_br => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node_br => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node_br => $OE->[-1]->{id}];
      }
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [213] in table;END:p
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-body-end-p', index => $token->{index}};

        my $node_p = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'p',
                 attr_list => [],
                 et => (P_EL), aet => (P_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node_p => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node_p => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node_p => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node_p => $OE->[-1]->{id}];
      }
    

push @$OE, $node_p;
          }
        
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
        },
      ,
        ## [214] in table;END:table
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TAB_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            push @$Errors, {type => 'in-table-end-table', index => $token->{index}};
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TAB_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;
          }
        
        },
      ,
        ## [215] in table;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [216] in table;START:a
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$AFE) {
          last if not ref $_;
          if ($_->{et} == A_EL) {
            $result = 1;
            last;
          }
        }
        $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-a', index => $token->{index}};
aaa_foster ($token, 'a', remove_from_afe_and_oe => 1);
          }
        
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'a',
                 attr_list => $token->{attr_list},
                 et => (A_EL), aet => (A_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [217] in table;START:address article aside details dialog dir figcaption figure footer header hgroup main nav section summary,blockquote center div dl menu ol ul,fieldset,p
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [218] in table;START:applet marquee,object
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          
push @$OE, $node;
push @$AFE, '#marker';

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [219] in table;START:area wbr,br,embed,img,keygen
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

            if ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | IMG_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)) {
              
          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
            }
          

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [220] in table;START:b big code em i s small strike strong tt u,font
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [221] in table;START:base,basefont bgsound link
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [222] in table;START:body
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-start-body', index => $token->{index}};

          if ((not ($OE->[1]->{et} & (BOD_ELS))) or 
($OE->[-1]->{et} & (HTM_ELS)) or 
(
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    )) {
            
          } else {
            
        $FRAMESET_OK = 0;
      

        push @$OP, ['set-if-missing', $token->{attr_list} => $OE->[1]->{id}]
            if @{$token->{attr_list}};
      
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [223] in table;START:button
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (BUT_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-button', index => $token->{index}};
pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (BUT_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'button',
                 attr_list => $token->{attr_list},
                 et => (BUTTON_EL), aet => (BUTTON_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [224] in table;START:caption
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TAB_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }
push @$AFE, '#marker';

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'caption',
                 attr_list => $token->{attr_list},
                 et => (CAPTION_EL), aet => (CAPTION_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_CAPTION_IM;
          #warn "Insertion mode changed to |in caption| ($IM)";
        
        },
      ,
        ## [225] in table;START:col
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TAB_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node_colgroup = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'colgroup',
                 attr_list => [],
                 et => (COLGROUP_EL), aet => (COLGROUP_EL) };
      

      push @$OP, ['insert', $node_colgroup => $OE->[-1]->{id}];
    

push @$OE, $node_colgroup;

          $IM = IN_COLUMN_GROUP_IM;
          #warn "Insertion mode changed to |in column group| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [226] in table;START:colgroup
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TAB_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'colgroup',
                 attr_list => $token->{attr_list},
                 et => (COLGROUP_EL), aet => (COLGROUP_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_COLUMN_GROUP_IM;
          #warn "Insertion mode changed to |in column group| ($IM)";
        
        },
      ,
        ## [227] in table;START:dd dt
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        $FRAMESET_OK = 0;
      

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{et} & (DD_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (DD_ELS))) {
            push @$Errors, {type => 'in-body-start-dd-dt', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (DD_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (DT_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (DT_ELS))) {
            push @$Errors, {type => 'in-body-start-dd-dt-2', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (DT_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            last;
          } else {
            
          }
        
          }
        
          }
        
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [228] in table;START:form
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-start-form', index => $token->{index}};

          if ((
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) or 
(defined $FORM_ELEMENT)) {
            
          } else {
            
        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'form',
                 attr_list => $token->{attr_list},
                 et => (FORM_EL), aet => (FORM_EL) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;
$FORM_ELEMENT = $node;
push @$OP, ['popped', [pop @$OE]];
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [229] in table;START:frame,head
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-start-c3fht6', index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [230] in table;START:frameset
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-start-frameset', index => $token->{index}};

          if (($OE->[-1]->{et} & (HTM_ELS)) or 
(not ($OE->[1]->{et} & (BOD_ELS)))) {
            
          }
        

          if (not $FRAMESET_OK) {
            
          } else {
            
        push @$OP, ['remove', $OE->[1]->{id}];
      
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $OE->[1]);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'frameset',
                 attr_list => $token->{attr_list},
                 et => (FRAMESET_EL), aet => (FRAMESET_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          $IM = IN_FRAMESET_IM;
          #warn "Insertion mode changed to |in frameset| ($IM)";
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [231] in table;START:h1 h2 h3 h4 h5 h6
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

          if ($OE->[-1]->{et} & (HHHHHH_ELS)) {
            push @$Errors, {type => 'in-body-start-h6', index => $token->{index}};
push @$OP, ['popped', [pop @$OE]];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [232] in table;START:hr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'hr',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [233] in table;START:html
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-start-html', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
         $result;
      }
    ) {
            
          }
        

        push @$OP, ['set-if-missing', $token->{attr_list} => $OE->[0]->{id}]
            if @{$token->{attr_list}};
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [234] in table;START:iframe
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        $FRAMESET_OK = 0;
      

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'iframe',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [235] in table;START:image
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
push @$Errors, {type => 'in-body-start-image', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node_img = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'img',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | IMG_ELS), aet => (HTML_NS_ELS | IMG_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node_img => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node_img => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node_img => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node_img => $OE->[-1]->{id}];
      }
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        $FRAMESET_OK = 0;
      
        },
      ,
        ## [236] in table;START:input
        sub {
          my $token = $_;

          if (
      defined $token->{attrs}->{type} and
      do {
        my $value = $token->{attrs}->{type}->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        $value eq q@hidden@;
      }
    ) {
            push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'input',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS), aet => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

          if (
      defined $token->{attrs}->{type} and
      do {
        my $value = $token->{attrs}->{type}->{value};
        $value =~ tr/A-Z/a-z/; ## ASCII case-insensitive
        $value eq q@hidden@;
      }
    ) {
            
        $FRAMESET_OK = 0;
      
          }
        
          } else {
            push @$Errors, {type => 'in-table-start-input', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'input',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS), aet => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
        },
      ,
        ## [237] in table;START:li
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        $FRAMESET_OK = 0;
      

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ($_node->{et} & (LI_ELS)) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (LI_ELS))) {
            push @$Errors, {type => 'in-body-start-li', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (LI_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
last;
          } else {
            
          if ($_node->{et} & (APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
            last;
          } else {
            
          }
        
          }
        
          }
        

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'li',
                 attr_list => $token->{attr_list},
                 et => (LI_EL), aet => (LI_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [238] in table;START:listing pre
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

        $FRAMESET_OK = 0;
      

        $ORIGINAL_IM = $IM;
        $IM = BEFORE_IGNORED_NEWLINE_IM;
      
        },
      ,
        ## [239] in table;START:math
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];
my $ns = MATHMLNS;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
        },
      ,
        ## [240] in table;START:menuitem param source track
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
        },
      ,
        ## [241] in table;START:meta
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'meta',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    


          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        

        if (defined $token->{attrs}->{charset}) {
          push @$OP, ['change-the-encoding', $token->{attrs}->{charset}->{value}, $token->{attrs}->{charset}];
        } elsif (defined $token->{attrs}->{'http-equiv'} and
                 defined $token->{attrs}->{content}) {
          if ($token->{attrs}->{'http-equiv'}->{value}
                  =~ /\A[Cc][Oo][Nn][Tt][Ee][Nn][Tt]-[Tt][Yy][Pp][Ee]\z/ and
              $token->{attrs}->{content}->{value}
                  =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                        [\x09\x0A\x0C\x0D\x20]*=
                        [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                        ([^"'\x09\x0A\x0C\x0D\x20]
                         [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            push @$OP, ['change-the-encoding', $1, $token->{attrs}->{content}];
          }
        }
      
        },
      ,
        ## [242] in table;START:nobr
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == NOBR_EL) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            push @$Errors, {type => 'in-body-start-nobr', index => $token->{index}};
aaa_foster ($token, 'nobr');
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'nobr',
                 attr_list => $token->{attr_list},
                 et => (NOBR_EL), aet => (NOBR_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

        ## Noah's Ark
        my $found = 0;
        AFE: for my $i (reverse 0..$#$AFE) {
          if (not ref $AFE->[$i]) { # marker
            last;
          } elsif ($node->{local_name} eq $AFE->[$i]->{local_name}
                   #and $node->{ns} == $AFE->[$i]->{ns}
          ) {
            ## Note that elements in $AFE are always HTML elements.
            for (keys %{$node->{token}->{attrs} or {}}) {
              my $attr = $AFE->[$i]->{token}->{attrs}->{$_};
              next AFE unless defined $attr;
              #next AFE unless $attr->{ns} == $node->{token}->{attrs}->{$_}->{ns};
              next AFE unless $attr->{value} eq $node->{token}->{attrs}->{$_}->{value};
            }
            next AFE unless (keys %{$node->{token}->{attrs} or {}}) == (keys %{$AFE->[$i]->{token}->{attrs} or {}});

            $found++;
            if ($found == 3) {
              splice @$AFE, $i, 1, ();
              last AFE;
            }
          }
        } # AFE

        push @$AFE, $node;
      

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [243] in table;START:noembed
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noembed',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [244] in table;START:noframes
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noframes',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [245] in table;START:noscript
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if ($Scripting) {
            
        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
          } else {
            &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'noscript',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [246] in table;START:optgroup,option
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if ($OE->[-1]->{et} == OPTION_EL) {
            push @$OP, ['popped', [pop @$OE]];
          }
        
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [247] in table;START:plaintext
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'plaintext',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = PLAINTEXT_STATE;
        },
      ,
        ## [248] in table;START:rp rt
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} == RUBY_EL) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | P_ELS | RP_RT_ELS);
          }
        

          if (not ($OE->[-1]->{et} == RUBY_EL)) {
            push @$Errors, {type => 'in-body-start-rp-rt', index => $token->{index}};
          }
        

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [249] in table;START:select
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'select',
                 attr_list => $token->{attr_list},
                 et => (SELECT_EL), aet => (SELECT_EL) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

        $FRAMESET_OK = 0;
      

          if ($IM == IN_TABLE_IM or $IM == IN_CAPTION_IM or $IM == IN_TABLE_BODY_IM or $IM == IN_ROW_IM or $IM == IN_CELL_IM) {
            
          $IM = IN_SELECT_IN_TABLE_IM;
          #warn "Insertion mode changed to |in select in table| ($IM)";
        
          } else {
            
          $IM = IN_SELECT_IM;
          #warn "Insertion mode changed to |in select| ($IM)";
        
          }
        

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [250] in table;START:svg
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];
my $ns = SVGNS;

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => $ns,
                    local_name => $token->{tag_name},
                    attr_list => $token->{attr_list},
                    et => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'},
                    aet => $Element2Type->[$ns]->{$token->{tag_name}} || $Element2Type->[$ns]->{'*'}};
      

        if (defined $token->{attrs}->{xmlns}) {
          if ($ns == SVGNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/2000/svg') {
            #
          } elsif ($ns == MATHMLNS and $token->{attrs}->{xmlns}->{value} eq 'http://www.w3.org/1998/Math/MathML') {
            #
          } else {
            push @$Errors, {type => 'XXX', index => $token->{attrs}->{xmlns}->{index}}; # XXXindex
          }
        }
        if (defined $token->{attrs}->{'xmlns:xlink'}) {
          unless ($token->{attrs}->{'xmlns:xlink'}->{value} eq 'http://www.w3.org/1999/xlink') {
            push @$Errors, {type => 'XXX'}; # XXXindex
          }
        }

        ## Adjust foreign attributes
        ## Adjust SVG attributes
        ## Adjust MathML attributes
        my $map = $ForeignAttrMap->[$ns];
        for my $attr (@{$token->{attr_list} or []}) {
          $attr->{name_args} = $map->{$attr->{name}} || [undef, [undef, $attr->{name}]];
        }
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];

          if (delete $token->{self_closing_flag}) {
            push @$Errors, {type => 'XXX self-closing void', level => 'w',
                            index => $token->{index},
                            text => $token->{tag_name}};
          }
        
          }
        
        },
      ,
        ## [251] in table;START:table
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-start-table', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TAB_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (HTM_ELS | TAB_ELS | TEM_ELS)) { last; 
          }
        }
        not $result;
      }
    ) {
            
          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
          } else {
            {
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TAB_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [252] in table;START:tbody tfoot thead
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TAB_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => $token->{tag_name},
                 attr_list => $token->{attr_list},
                 et => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}, aet => $Element2Type->[HTMLNS]->{$token->{tag_name}} || $Element2Type->[HTMLNS]->{'*'} };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        
        },
      ,
        ## [253] in table;START:td th,tr
        sub {
          my $token = $_;
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (HTM_ELS | TAB_ELS | TEM_ELS));
          push @$OP, ['popped', \@popped];
        }

        my $node_tbody = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'tbody',
                 attr_list => [],
                 et => (TBODY_EL), aet => (TBODY_EL) };
      

      push @$OP, ['insert', $node_tbody => $OE->[-1]->{id}];
    

push @$OE, $node_tbody;

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [254] in table;START:textarea
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'textarea',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS), aet => (HTML_NS_ELS | FIE_INP_SEL_TEX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

          if (defined $FORM_ELEMENT) {
            FORM: {
              last FORM if defined $token->{attrs}->{form} and
                           ($node->{et} & (BUT_ELS | FIE_INP_SEL_TEX_ELS | KEY_LAB_OUT_ELS | OBJ_ELS)); # reassociateable
              for my $oe (@$OE) {
                if ($oe->{et} & (TEM_ELS)) { # template
                  last FORM;
                }
              }
              #last FORM unless $FORM_ELEMENT and $OE->[-1] (intended parent) same home subtree - should be checked later
              $node->{form} = $FORM_ELEMENT->{id};
            } # FORM
          }
        
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RCDATA_STATE;
$ORIGINAL_IM = $IM;

        $FRAMESET_OK = 0;
      

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        

        $IM = BEFORE_IGNORED_NEWLINE_AND_TEXT_IM;
      
        },
      ,
        ## [255] in table;START:title
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'title',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RCDATA_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [256] in table;START:xmp
        sub {
          my $token = $_;
push @$Errors, {type => 'in-table-else', index => $token->{index}};

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (P_ELS)) {
            $result = 1;
            last;
          } elsif ($_->{et} & (APP_ELS | BUT_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) { last; 
          }
        }
         $result;
      }
    ) {
            pop @$OE while $OE->[-1]->{et} & (DD_ELS | DT_ELS | LI_ELS | OPT_OPT_ELS | RP_RT_ELS);

          if (not ($OE->[-1]->{et} & (P_ELS))) {
            push @$Errors, {type => '-steps-close-a-p-element', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (P_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
          }
        
&reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

        $FRAMESET_OK = 0;
      

        my $node = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'xmp',
                 attr_list => $token->{attr_list},
                 et => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS), aet => (HTML_NS_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS) };
      

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    

push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
$State = RAWTEXT_STATE;
$ORIGINAL_IM = $IM;

          $IM = TEXT_IM;
          #warn "Insertion mode changed to |text| ($IM)";
        
        },
      ,
        ## [257] in table;TEXT
        sub {
          my $token = $_;

          if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) {
            $TABLE_CHARS = [];
$ORIGINAL_IM = $IM;

          $IM = IN_TABLE_TEXT_IM;
          #warn "Insertion mode changed to |in table text| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          } else {
            push @$Errors, {type => 'in-table-char', index => $token->{index}};

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $1 => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $1 => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $1 => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $1 => $OE->[-1]->{id}];
      }
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe_foster if @$AFE and ref $AFE->[-1];

      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['text-foster', $token->{value} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['text', $token->{value} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['text', $token->{value} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
      }
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
          }
        
        },
      ,
        ## [258] in template;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-template-end-else', index => $token->{index}};
        },
      ,
        ## [259] in template;EOF
        sub {
          my $token = $_;

          if (
      do {
        my $result = 0;
        for (reverse @$OE) {
          if ($_->{et} & (TEM_ELS)) {
            $result = 1;
            last;
          
          }
        }
        not $result;
      }
    ) {
            push @$OP, ['stop-parsing'];
          } else {
            push @$Errors, {type => 'in-template-eof', index => $token->{index}};
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1]->{et} & (TEM_ELS));
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }

        pop @$AFE while ref $AFE->[-1];
        pop @$AFE; # #marker
      
pop @$TEMPLATE_IMS;
&reset_im;

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [260] in template;START-ELSE
        sub {
          my $token = $_;
pop @$TEMPLATE_IMS;

        push @$TEMPLATE_IMS, q@in body@;
      

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [261] in template;START:caption,colgroup,tbody tfoot thead
        sub {
          my $token = $_;
pop @$TEMPLATE_IMS;

        push @$TEMPLATE_IMS, q@in table@;
      

          $IM = IN_TABLE_IM;
          #warn "Insertion mode changed to |in table| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [262] in template;START:col
        sub {
          my $token = $_;
pop @$TEMPLATE_IMS;

        push @$TEMPLATE_IMS, q@in column group@;
      

          $IM = IN_COLUMN_GROUP_IM;
          #warn "Insertion mode changed to |in column group| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [263] in template;START:td th
        sub {
          my $token = $_;
pop @$TEMPLATE_IMS;

        push @$TEMPLATE_IMS, q@in row@;
      

          $IM = IN_ROW_IM;
          #warn "Insertion mode changed to |in row| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [264] in template;START:tr
        sub {
          my $token = $_;
pop @$TEMPLATE_IMS;

        push @$TEMPLATE_IMS, q@in table body@;
      

          $IM = IN_TABLE_BODY_IM;
          #warn "Insertion mode changed to |in table body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [265] in template;TEXT
        sub {
          my $token = $_;

            if (index ($token->{value}, "\x00") > -1) {
              while (pos $token->{value} < length $token->{value}) {
                if ($token->{value} =~ /\G([^\x00\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    

        $FRAMESET_OK = 0;
      
                }
                if ($token->{value} =~ /\G([\x09\x0A\x0C\x20]+)/gc) {
                  &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $1 => $OE->[-1]->{id}];
    
                }
                if ($token->{value} =~ /\G([\x00]+)/gc) {
                  
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-body-null', index => $token->{index}};
            }
            
          
                }
              }
            } else {
              &reconstruct_afe if @$AFE and ref $AFE->[-1];

      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
              $FRAMESET_OK = 0 if $FRAMESET_OK and $token->{value} =~ /[^\x09\x0A\x0C\x20]/;
            }
          
        },
      ,
        ## [266] initial;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token->{data} => 0];
          
        },
      ,
        ## [267] initial;DOCTYPE
        sub {
          my $token = $_;
push @$OP, ['doctype', $token => 0];

        if (not $token->{name} eq 'html') {
          push @$Errors, {type => 'XXX', token => $token};
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        } elsif (defined $token->{public_identifier}) {
          if (defined $OPPublicIDToSystemID->{$token->{public_identifier}}) {
            if (defined $token->{system_identifier}) {
              if ($OPPublicIDToSystemID->{$token->{public_identifier}} eq $token->{system_identifier}) {
                push @$Errors, {type => 'XXXobsolete permitted DOCTYPE', level => 's', token => $token};
              } else {
                push @$Errors, {type => 'XXX', token => $token};
              }
            } else {
              if ($OPPublicIDOnly->{$token->{public_identifier}}) {
                push @$Errors, {type => 'XXXobsolete permitted DOCTYPE', level => 's', token => $token};
              } else {
                push @$Errors, {type => 'XXX', token => $token};
              }
            }
          } else {
            push @$Errors, {type => 'XXX', token => $token};
            unless ($IframeSrcdoc) {
              my $pubid = $token->{public_identifier};
              $pubid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
              if ($QPublicIDs->{$pubid}) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif ($pubid =~ /^$QPublicIDPrefixPattern/o) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif (defined $token->{system_identifier} and
                       do {
                         my $sysid = $token->{system_identifier};
                         $sysid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
                         $QSystemIDs->{$sysid};
                       }) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              } elsif ($pubid =~ /^$LQPublicIDPrefixPattern/o) {
                push @$OP, ['set-compat-mode', 'limited quirks'];
              } elsif ($pubid =~ /^$QorLQPublicIDPrefixPattern/o) {
                if (defined $token->{system_identifier}) {
                  push @$OP, ['set-compat-mode', 'limited quirks'];
                } else {
                  push @$OP, ['set-compat-mode', 'quirks'];
                  $QUIRKS = 1;
                }
              }
            }
          }
        } elsif (defined $token->{system_identifier}) {
          if ($token->{system_identifier} eq 'about:legacy-compat') {
            push @$Errors, {type => 'XXXlegacy DOCTYPE', level => 's', token => $token};
          } else {
            push @$Errors, {type => 'XXX', token => $token};
            unless ($IframeSrcdoc) {
              my $sysid = $token->{system_identifier};
              $sysid =~ tr/a-z/A-Z/; ## ASCII case-insensitive.
              if ($QSystemIDs->{$sysid}) {
                push @$OP, ['set-compat-mode', 'quirks'];
                $QUIRKS = 1;
              }
            }
          }
        }
        if ($token->{force_quirks_flag}) {
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        }
      

          $IM = BEFORE_HTML_IM;
          #warn "Insertion mode changed to |before html| ($IM)";
        
        },
      ,
        ## [268] initial;END-ELSE
        sub {
          my $token = $_;

          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        

          $IM = BEFORE_HTML_IM;
          #warn "Insertion mode changed to |before html| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [269] initial;EOF
        sub {
          my $token = $_;

          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        

          $IM = BEFORE_HTML_IM;
          #warn "Insertion mode changed to |before html| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [270] initial;START-ELSE
        sub {
          my $token = $_;

          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        

          $IM = BEFORE_HTML_IM;
          #warn "Insertion mode changed to |before html| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [271] initial;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
        }
        if (length $token->{value}) {
          
          unless ($IframeSrcdoc) {
            push @$OP, ['set-compat-mode', 'quirks'];
            $QUIRKS = 1;
          }
        

          $IM = BEFORE_HTML_IM;
          #warn "Insertion mode changed to |before html| ($IM)";
        

        my $node = {id => $NEXT_ID++,
                    token => $token,
                    ns => HTMLNS,
                    local_name => 'html',
                    attr_list => [],
                    et => (HTML_EL), aet => (HTML_EL)};
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          $IM = BEFORE_HEAD_IM;
          #warn "Insertion mode changed to |before head| ($IM)";
        

        my $node_head = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'head',
                 attr_list => [],
                 et => (HEAD_EL), aet => (HEAD_EL) };
      

      push @$OP, ['insert', $node_head => $OE->[-1]->{id}];
    

push @$OE, $node_head;
$HEAD_ELEMENT = $node_head;

          $IM = IN_HEAD_IM;
          #warn "Insertion mode changed to |in head| ($IM)";
        
push @$OP, ['popped', [pop @$OE]];

          $IM = AFTER_HEAD_IM;
          #warn "Insertion mode changed to |after head| ($IM)";
        

        my $node_body = {id => $NEXT_ID++,
                 token => $token,
                 ns => HTMLNS,
                 local_name => 'body',
                 attr_list => [],
                 et => (BODY_EL), aet => (BODY_EL) };
      

      push @$OP, ['insert', $node_body => $OE->[-1]->{id}];
    

push @$OE, $node_body;

          $IM = IN_BODY_IM;
          #warn "Insertion mode changed to |in body| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        }
      
        },
      ,
        ## [272] text;COMMENT
        sub {
          
        },
      ,
        ## [273] text;DOCTYPE
        sub {
          
        },
      ,
        ## [274] text;END-ELSE
        sub {
          push @$OP, ['popped', [pop @$OE]];

            $IM = $ORIGINAL_IM;
          
        },
      ,
        ## [275] text;END:script
        sub {
          my $script = $OE->[-1];
push @$OP, ['popped', [pop @$OE]];

            $IM = $ORIGINAL_IM;
          
push @$OP, ['script', $script->{id}];
        },
      ,
        ## [276] text;EOF
        sub {
          my $token = $_;
push @$Errors, {type => 'text-eof', index => $token->{index}};

          if ($OE->[-1]->{et} == SCRIPT_EL) {
            push @$OP, ['ignore-script', $OE->[-1]->{id}];
          }
        
push @$OP, ['popped', [pop @$OE]];

            $IM = $ORIGINAL_IM;
          

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [277] text;START-ELSE
        sub {
          my $token = $_;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => '-start-tag-self-closing-flag', index => $token->{index}};
          }
        
        },
      ,
        ## [278] text;TEXT
        sub {
          my $token = $_;

      push @$OP, ['text', $token->{value} => $OE->[-1]->{id}];
    
        },
      ];
    
$ProcessIM = [undef,
[undef, [$TCA->[62]], [$TCA->[1]], [$TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2], $TCA->[2]], [$TCA->[3]], [$TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[91], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4], $TCA->[4]], [$TCA->[5]]],
[undef, [$TCA->[62]], [$TCA->[6]], [$TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7], $TCA->[7]], [$TCA->[8]], [$TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[91], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[166], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9], $TCA->[9]], [$TCA->[10]]],
[undef, [$TCA->[12]], [$TCA->[11]], [$TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[14], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13], $TCA->[13]], [$TCA->[15]], [$TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[91], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16], $TCA->[16]], [$TCA->[17]]],
[undef, [$TCA->[19]], [$TCA->[18]], [$TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[21], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20], $TCA->[20]], [$TCA->[22]], [$TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[91], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[166], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23], $TCA->[23]], [$TCA->[24]]],
[undef, [$TCA->[26]], [$TCA->[25]], [$TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[28], $TCA->[28], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[28], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[160], $TCA->[27], $TCA->[27], $TCA->[27], $TCA->[27]], [$TCA->[29]], [$TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[31], $TCA->[31], $TCA->[30], $TCA->[32], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[33], $TCA->[30], $TCA->[34], $TCA->[30], $TCA->[91], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[35], $TCA->[30], $TCA->[30], $TCA->[36], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[37], $TCA->[30], $TCA->[36], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[30], $TCA->[38], $TCA->[30], $TCA->[39], $TCA->[30], $TCA->[30]], [$TCA->[40]]],
[undef, [$TCA->[42]], [$TCA->[41]], [$TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[44], $TCA->[44], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[44], $TCA->[43], $TCA->[44], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43], $TCA->[43]], [$TCA->[45]], [$TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[47], $TCA->[46], $TCA->[91], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46], $TCA->[46]], [$TCA->[48]]],
[undef, [$TCA->[50]], [$TCA->[49]], [$TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[52], $TCA->[52], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[52], $TCA->[51], $TCA->[52], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51], $TCA->[51]], [$TCA->[53]], [$TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[55], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54], $TCA->[54]], [$TCA->[56]]],
[undef, [$TCA->[59]], [$TCA->[59]], [$TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59]], [$TCA->[59]], [$TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59], $TCA->[59]], [$TCA->[60]]],
[undef, [$TCA->[57]], [$TCA->[57]], [$TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57]], [$TCA->[57]], [$TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57], $TCA->[57]], [$TCA->[58]]],
[undef, [$TCA->[62]], [$TCA->[61]], [$TCA->[63], $TCA->[64], $TCA->[65], $TCA->[66], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[65], $TCA->[67], $TCA->[68], $TCA->[65], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[69], $TCA->[63], $TCA->[65], $TCA->[64], $TCA->[70], $TCA->[63], $TCA->[63], $TCA->[71], $TCA->[63], $TCA->[63], $TCA->[72], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[73], $TCA->[65], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[66], $TCA->[63], $TCA->[63], $TCA->[74], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[75], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[160], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63]], [$TCA->[76]], [$TCA->[77], $TCA->[78], $TCA->[79], $TCA->[80], $TCA->[81], $TCA->[82], $TCA->[163], $TCA->[163], $TCA->[79], $TCA->[83], $TCA->[81], $TCA->[84], $TCA->[85], $TCA->[85], $TCA->[85], $TCA->[86], $TCA->[81], $TCA->[79], $TCA->[82], $TCA->[87], $TCA->[85], $TCA->[88], $TCA->[89], $TCA->[85], $TCA->[90], $TCA->[91], $TCA->[92], $TCA->[93], $TCA->[81], $TCA->[94], $TCA->[81], $TCA->[77], $TCA->[95], $TCA->[96], $TCA->[77], $TCA->[97], $TCA->[98], $TCA->[165], $TCA->[99], $TCA->[100], $TCA->[166], $TCA->[101], $TCA->[80], $TCA->[102], $TCA->[102], $TCA->[79], $TCA->[103], $TCA->[104], $TCA->[77], $TCA->[77], $TCA->[168], $TCA->[105], $TCA->[166], $TCA->[106], $TCA->[107], $TCA->[85], $TCA->[85], $TCA->[169], $TCA->[108], $TCA->[170], $TCA->[85], $TCA->[109]], [$TCA->[110]]],
[undef, [$TCA->[62]], [$TCA->[61]], [$TCA->[63], $TCA->[64], $TCA->[65], $TCA->[66], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[65], $TCA->[111], $TCA->[68], $TCA->[65], $TCA->[112], $TCA->[111], $TCA->[111], $TCA->[69], $TCA->[63], $TCA->[65], $TCA->[64], $TCA->[70], $TCA->[63], $TCA->[63], $TCA->[71], $TCA->[63], $TCA->[63], $TCA->[111], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[73], $TCA->[65], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[66], $TCA->[63], $TCA->[63], $TCA->[74], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[75], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[113], $TCA->[111], $TCA->[111], $TCA->[160], $TCA->[63], $TCA->[63], $TCA->[111], $TCA->[63]], [$TCA->[76]], [$TCA->[77], $TCA->[78], $TCA->[79], $TCA->[80], $TCA->[81], $TCA->[82], $TCA->[163], $TCA->[163], $TCA->[79], $TCA->[83], $TCA->[81], $TCA->[84], $TCA->[114], $TCA->[114], $TCA->[114], $TCA->[86], $TCA->[81], $TCA->[79], $TCA->[82], $TCA->[87], $TCA->[85], $TCA->[88], $TCA->[89], $TCA->[85], $TCA->[90], $TCA->[91], $TCA->[92], $TCA->[93], $TCA->[81], $TCA->[94], $TCA->[81], $TCA->[77], $TCA->[95], $TCA->[96], $TCA->[77], $TCA->[97], $TCA->[98], $TCA->[165], $TCA->[99], $TCA->[100], $TCA->[166], $TCA->[101], $TCA->[80], $TCA->[102], $TCA->[102], $TCA->[79], $TCA->[103], $TCA->[104], $TCA->[77], $TCA->[77], $TCA->[168], $TCA->[105], $TCA->[166], $TCA->[106], $TCA->[107], $TCA->[114], $TCA->[114], $TCA->[169], $TCA->[108], $TCA->[170], $TCA->[114], $TCA->[109]], [$TCA->[115]]],
[undef, [$TCA->[62]], [$TCA->[61]], [$TCA->[63], $TCA->[64], $TCA->[65], $TCA->[66], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[65], $TCA->[116], $TCA->[68], $TCA->[65], $TCA->[116], $TCA->[116], $TCA->[116], $TCA->[69], $TCA->[63], $TCA->[65], $TCA->[64], $TCA->[70], $TCA->[63], $TCA->[63], $TCA->[71], $TCA->[63], $TCA->[63], $TCA->[116], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[73], $TCA->[65], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[64], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[66], $TCA->[63], $TCA->[63], $TCA->[74], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[75], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[63], $TCA->[117], $TCA->[117], $TCA->[118], $TCA->[160], $TCA->[63], $TCA->[63], $TCA->[117], $TCA->[63]], [$TCA->[76]], [$TCA->[77], $TCA->[78], $TCA->[79], $TCA->[80], $TCA->[81], $TCA->[82], $TCA->[163], $TCA->[163], $TCA->[79], $TCA->[83], $TCA->[81], $TCA->[84], $TCA->[119], $TCA->[119], $TCA->[119], $TCA->[86], $TCA->[81], $TCA->[79], $TCA->[82], $TCA->[87], $TCA->[85], $TCA->[88], $TCA->[89], $TCA->[85], $TCA->[90], $TCA->[91], $TCA->[92], $TCA->[93], $TCA->[81], $TCA->[94], $TCA->[81], $TCA->[77], $TCA->[95], $TCA->[96], $TCA->[77], $TCA->[97], $TCA->[98], $TCA->[165], $TCA->[99], $TCA->[100], $TCA->[166], $TCA->[101], $TCA->[80], $TCA->[102], $TCA->[102], $TCA->[79], $TCA->[103], $TCA->[104], $TCA->[77], $TCA->[77], $TCA->[168], $TCA->[105], $TCA->[166], $TCA->[106], $TCA->[107], $TCA->[119], $TCA->[119], $TCA->[169], $TCA->[108], $TCA->[170], $TCA->[119], $TCA->[109]], [$TCA->[120]]],
[undef, [$TCA->[122]], [$TCA->[121]], [$TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[124], $TCA->[125], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[160], $TCA->[123], $TCA->[123], $TCA->[123], $TCA->[123]], [$TCA->[76]], [$TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[127], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[91], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[169], $TCA->[126], $TCA->[126], $TCA->[126], $TCA->[126]], [$TCA->[128]]],
[undef, [$TCA->[130]], [$TCA->[129]], [$TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[132], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131], $TCA->[131]], [$TCA->[133]], [$TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[135], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[135], $TCA->[134], $TCA->[136], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[135], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[135], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134], $TCA->[134]], [$TCA->[137]]],
[undef, [$TCA->[139]], [$TCA->[138]], [$TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[141], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140], $TCA->[140]], [$TCA->[142]], [$TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[144], $TCA->[145], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[91], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[166], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143], $TCA->[143]], [$TCA->[146]]],
[undef, [$TCA->[156]], [$TCA->[155]], [$TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[158], $TCA->[158], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[159], $TCA->[157], $TCA->[158], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[160], $TCA->[157], $TCA->[157], $TCA->[157], $TCA->[157]], [$TCA->[161]], [$TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[163], $TCA->[163], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[164], $TCA->[162], $TCA->[91], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[165], $TCA->[162], $TCA->[162], $TCA->[166], $TCA->[167], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[168], $TCA->[162], $TCA->[166], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[162], $TCA->[169], $TCA->[162], $TCA->[170], $TCA->[162], $TCA->[162]], [$TCA->[171]]],
[undef, [$TCA->[147]], [$TCA->[155]], [$TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[149], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[150], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148], $TCA->[148]], [$TCA->[151]], [$TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[163], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[153], $TCA->[152], $TCA->[91], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[165], $TCA->[152], $TCA->[152], $TCA->[166], $TCA->[153], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[166], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152], $TCA->[152]], [$TCA->[154]]],
[undef, [$TCA->[208]], [$TCA->[207]], [$TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[172], $TCA->[212], $TCA->[209], $TCA->[172], $TCA->[172], $TCA->[172], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[172], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[213], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[173], $TCA->[174], $TCA->[172], $TCA->[160], $TCA->[209], $TCA->[209], $TCA->[175], $TCA->[209]], [$TCA->[76]], [$TCA->[215], $TCA->[216], $TCA->[217], $TCA->[218], $TCA->[219], $TCA->[220], $TCA->[221], $TCA->[221], $TCA->[217], $TCA->[222], $TCA->[219], $TCA->[223], $TCA->[176], $TCA->[176], $TCA->[176], $TCA->[227], $TCA->[219], $TCA->[217], $TCA->[220], $TCA->[228], $TCA->[229], $TCA->[230], $TCA->[231], $TCA->[229], $TCA->[232], $TCA->[233], $TCA->[234], $TCA->[235], $TCA->[219], $TCA->[236], $TCA->[219], $TCA->[215], $TCA->[237], $TCA->[238], $TCA->[215], $TCA->[239], $TCA->[240], $TCA->[241], $TCA->[242], $TCA->[243], $TCA->[244], $TCA->[245], $TCA->[218], $TCA->[246], $TCA->[246], $TCA->[217], $TCA->[247], $TCA->[248], $TCA->[215], $TCA->[215], $TCA->[168], $TCA->[249], $TCA->[166], $TCA->[250], $TCA->[251], $TCA->[176], $TCA->[177], $TCA->[169], $TCA->[254], $TCA->[255], $TCA->[176], $TCA->[256]], [$TCA->[178]]],
[undef, [$TCA->[183]], [$TCA->[182]], [$TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[185], $TCA->[186], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[187], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[160], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184]], [$TCA->[76]], [$TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[91], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[189], $TCA->[189], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[190], $TCA->[191], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[168], $TCA->[192], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[169], $TCA->[189], $TCA->[188], $TCA->[188], $TCA->[188]], [$TCA->[193]]],
[undef, [$TCA->[183]], [$TCA->[182]], [$TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[179], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[185], $TCA->[186], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[184], $TCA->[187], $TCA->[184], $TCA->[184], $TCA->[179], $TCA->[179], $TCA->[179], $TCA->[160], $TCA->[184], $TCA->[184], $TCA->[179], $TCA->[184]], [$TCA->[76]], [$TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[180], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[91], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[189], $TCA->[189], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[190], $TCA->[191], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[188], $TCA->[168], $TCA->[192], $TCA->[188], $TCA->[188], $TCA->[180], $TCA->[180], $TCA->[180], $TCA->[169], $TCA->[189], $TCA->[188], $TCA->[180], $TCA->[188]], [$TCA->[181]]],
[undef, [$TCA->[208]], [$TCA->[207]], [$TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[211], $TCA->[212], $TCA->[209], $TCA->[211], $TCA->[211], $TCA->[211], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[211], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[213], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[214], $TCA->[211], $TCA->[211], $TCA->[160], $TCA->[209], $TCA->[209], $TCA->[211], $TCA->[209]], [$TCA->[76]], [$TCA->[215], $TCA->[216], $TCA->[217], $TCA->[218], $TCA->[219], $TCA->[220], $TCA->[221], $TCA->[221], $TCA->[217], $TCA->[222], $TCA->[219], $TCA->[223], $TCA->[224], $TCA->[225], $TCA->[226], $TCA->[227], $TCA->[219], $TCA->[217], $TCA->[220], $TCA->[228], $TCA->[229], $TCA->[230], $TCA->[231], $TCA->[229], $TCA->[232], $TCA->[233], $TCA->[234], $TCA->[235], $TCA->[219], $TCA->[236], $TCA->[219], $TCA->[215], $TCA->[237], $TCA->[238], $TCA->[215], $TCA->[239], $TCA->[240], $TCA->[241], $TCA->[242], $TCA->[243], $TCA->[244], $TCA->[245], $TCA->[218], $TCA->[246], $TCA->[246], $TCA->[217], $TCA->[247], $TCA->[248], $TCA->[215], $TCA->[215], $TCA->[168], $TCA->[249], $TCA->[166], $TCA->[250], $TCA->[251], $TCA->[252], $TCA->[253], $TCA->[169], $TCA->[254], $TCA->[255], $TCA->[253], $TCA->[256]], [$TCA->[257]]],
[undef, [$TCA->[208]], [$TCA->[207]], [$TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[194], $TCA->[212], $TCA->[209], $TCA->[194], $TCA->[194], $TCA->[194], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[194], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[210], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[213], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[209], $TCA->[195], $TCA->[196], $TCA->[194], $TCA->[160], $TCA->[209], $TCA->[209], $TCA->[194], $TCA->[209]], [$TCA->[76]], [$TCA->[215], $TCA->[216], $TCA->[217], $TCA->[218], $TCA->[219], $TCA->[220], $TCA->[221], $TCA->[221], $TCA->[217], $TCA->[222], $TCA->[219], $TCA->[223], $TCA->[197], $TCA->[197], $TCA->[197], $TCA->[227], $TCA->[219], $TCA->[217], $TCA->[220], $TCA->[228], $TCA->[229], $TCA->[230], $TCA->[231], $TCA->[229], $TCA->[232], $TCA->[233], $TCA->[234], $TCA->[235], $TCA->[219], $TCA->[236], $TCA->[219], $TCA->[215], $TCA->[237], $TCA->[238], $TCA->[215], $TCA->[239], $TCA->[240], $TCA->[241], $TCA->[242], $TCA->[243], $TCA->[244], $TCA->[245], $TCA->[218], $TCA->[246], $TCA->[246], $TCA->[217], $TCA->[247], $TCA->[248], $TCA->[215], $TCA->[215], $TCA->[168], $TCA->[249], $TCA->[166], $TCA->[250], $TCA->[251], $TCA->[197], $TCA->[198], $TCA->[169], $TCA->[254], $TCA->[255], $TCA->[199], $TCA->[256]], [$TCA->[200]]],
[undef, [$TCA->[202]], [$TCA->[201]], [$TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203], $TCA->[203]], [$TCA->[204]], [$TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205], $TCA->[205]], [$TCA->[206]]],
[undef, [$TCA->[62]], [$TCA->[61]], [$TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[160], $TCA->[258], $TCA->[258], $TCA->[258], $TCA->[258]], [$TCA->[259]], [$TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[163], $TCA->[163], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[261], $TCA->[262], $TCA->[261], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[165], $TCA->[260], $TCA->[260], $TCA->[166], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[260], $TCA->[168], $TCA->[260], $TCA->[166], $TCA->[260], $TCA->[260], $TCA->[261], $TCA->[263], $TCA->[169], $TCA->[260], $TCA->[170], $TCA->[264], $TCA->[260]], [$TCA->[265]]],
[undef, [$TCA->[267]], [$TCA->[266]], [$TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268], $TCA->[268]], [$TCA->[269]], [$TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270], $TCA->[270]], [$TCA->[271]]],
[undef, [$TCA->[273]], [$TCA->[272]], [$TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[275], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274], $TCA->[274]], [$TCA->[276]], [$TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277], $TCA->[277]], [$TCA->[278]]]];
my $ResetIMByET = {  (BODY_EL) => IN_BODY_IM,
  (CAPTION_EL) => IN_CAPTION_IM,
  (COLGROUP_EL) => IN_COLUMN_GROUP_IM,
  (FRAMESET_EL) => IN_FRAMESET_IM,
  (TABLE_EL) => IN_TABLE_IM,
  (TBODY_EL) => IN_TABLE_BODY_IM,
  (TFOOT_EL) => IN_TABLE_BODY_IM,
  (THEAD_EL) => IN_TABLE_BODY_IM,
  (TR_EL) => IN_ROW_IM,};
my $ResetIMByETUnlessLast = {  (HEAD_EL) => IN_HEAD_IM,
  (TD_EL) => IN_CELL_IM,
  (TH_EL) => IN_CELL_IM,};

      sub reset_im () {
        my $last = 0;
        my $node_i = $#$OE;
        my $node = $OE->[$node_i];
        LOOP: {
          if ($node_i == 0) {
            $last = 1;
            $node = $CONTEXT if defined $CONTEXT;
          }

          if ($node->{et} == SELECT_EL) {
            SELECT: {
              last SELECT if $last;
              my $ancestor_i = $node_i;
              INNERLOOP: {
                if ($ancestor_i == 0) {
                  last SELECT;
                }
                $ancestor_i--;
                my $ancestor = $OE->[$ancestor_i];
                if ($ancestor->{et} & (TEM_ELS)) {
                  last SELECT;
                }
                if ($ancestor->{et} & (TAB_ELS)) {
                  $IM = IN_SELECT_IN_TABLE_IM;
                  return;
                }
                redo INNERLOOP;
              } # INNERLOOP
            } # SELECT
            $IM = IN_SELECT_IM;
            return;
          }

          $IM = $ResetIMByET->{$node->{et}};
          return if defined $IM;

          unless ($last) {
            $IM = $ResetIMByETUnlessLast->{$node->{et}};
            return if defined $IM;
          }

          if ($node->{et} & (TEM_ELS)) {
            $IM = $TEMPLATE_IMS->[-1];
            return;
          }
          if ($node->{et} & (HTM_ELS)) {
            if (not defined $HEAD_ELEMENT) {
              $IM = BEFORE_HEAD_IM;
              return;
            } else {
              $IM = AFTER_HEAD_IM;
              return;
            }
          }
          if ($last) {
            $IM = IN_BODY_IM;
            return;
          }
          $node_i--;
          $node = $OE->[$node_i];
          redo LOOP;
        } # LOOP
      } # reset_im
    

        sub aaa ($$;%) {
          my ($token, $tag_name, %args) = @_;
          my @popped;
          if ($OE->[-1]->{ns} == HTMLNS and
              $OE->[-1]->{local_name} eq $tag_name) {
            my $found;
            for (reverse @$AFE) {
              if ($_ eq $OE->[-1]) {
                $found = 1;
                last;
              }
            }
            unless ($found) {
              #push @popped,
              pop @$OE;
              ## $args{remove_from_afe_and_oe} - nop
              #push @$OP, ['popped', \@popped];
              return;
            }
          }

          my $outer_loop_counter = 0;
          OUTER_LOOP: {
            if ($outer_loop_counter >= 8) {
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
            $outer_loop_counter++;
            my $formatting_element;
            my $formatting_element_afe_i;
            for (reverse 0..$#$AFE) {
              if (not ref $AFE->[$_]) {
                last;
              } elsif ($AFE->[$_]->{local_name} eq $tag_name) { # ->{ns} == HTMLNS
                $formatting_element = $AFE->[$_];
                $formatting_element_afe_i = $_;
                last;
              }
            }
            unless (defined $formatting_element) {
              ## The "in body" insertion mode, END_TAG_TOKEN, ELSE
              local $_ = $token;
              $ProcessIM->[IN_BODY_IM]->[END_TAG_TOKEN]->[0]->();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
        my $beyond_scope;
        my $formatting_element_i;
        my $furthest_block;
        my $furthest_block_i;
        for (reverse 0..$#$OE) {
          if ($OE->[$_] eq $formatting_element) {
            $formatting_element_i = $_;
            last;
          } else {
            if ($OE->[$_]->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
              $beyond_scope = 1;
            }
            if ($OE->[$_]->{et} & (ADD_DIV_ELS | APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | P_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
              $furthest_block = $OE->[$_];
              $furthest_block_i = $_;
            }
          }
        }
            unless (defined $formatting_element_i) {
              push @$Errors, {type => 'XXX', token => $token};
              splice @$AFE, $formatting_element_afe_i, 1, ();
              if ($args{remove_from_afe_and_oe}) {
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            if ($beyond_scope) {
              push @$Errors, {type => 'XXX', token => $token};
              if ($args{remove_from_afe_and_oe}) {
                splice @$AFE, $formatting_element_afe_i, 1, ();
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            unless ($formatting_element eq $OE->[-1]) {
              push @$Errors, {type => 'XXX', token => $token};
            }
            unless (defined $furthest_block) {
              #push @popped,
              splice @$OE, $formatting_element_i;
              splice @$AFE, $formatting_element_afe_i, 1, ();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }

        my $common_ancestor = $OE->[$formatting_element_i-1];
        my $bookmark = $formatting_element_afe_i;
        my $node = $furthest_block;
        my $node_i = $furthest_block_i;
        my $last_node = $furthest_block;
        my $inner_loop_counter = 0;
        INNER_LOOP: {
          $inner_loop_counter++;
          $node_i--;
          $node = $OE->[$node_i];
          last INNER_LOOP if $node eq $formatting_element;
          my $node_afe_i;
          for (reverse 0..$#$AFE) {
            if ($AFE->[$_] eq $node) {
              $node_afe_i = $_;
              last;
            }
          }
          if ($inner_loop_counter > 3 and defined $node_afe_i) {
            splice @$AFE, $node_afe_i, 1, ();
          }
          if (not defined $node_afe_i) {
            push @popped, splice @$OE, $node_i, 1, ();
            redo INNER_LOOP;
          }

          ## Create an HTML element
          $node = {id => $NEXT_ID++,
                   token => $node->{token},
                   ns => HTMLNS,
                   local_name => $node->{token}->{tag_name},
                   attr_list => $node->{token}->{attr_list},
                   et => $Element2Type->[HTMLNS]->{$node->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
          $node->{aet} = $node->{et};
          $AFE->[$node_afe_i] = $node;
          $OE->[$node_i] = $node;
          ## As $node seems never to be a form-assosicated element,
          ## and it will be appended (not inserted) to another node
          ## later anyway, we don't have to associate the form owner
          ## here.  Note that /intended parent/ is $common_ancestor.

          if ($last_node eq $furthest_block) {
            $bookmark = $node_afe_i + 1;
          }

          push @$OP,
              ['create', $node],
              ['append', $last_node->{id} => $node->{id}];
          $last_node = $node;
          redo INNER_LOOP;
        } # INNER_LOOP

            
      push @$OP, ['append', $last_node->{id} => $common_ancestor->{id}];
    

            ## Create an HTML element
            my $new_element = {id => $NEXT_ID++,
                               token => $formatting_element->{token},
                               ns => HTMLNS,
                               local_name => $formatting_element->{token}->{tag_name},
                               attr_list => $formatting_element->{token}->{attr_list},
                               et => $Element2Type->[HTMLNS]->{$formatting_element->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $new_element->{aet} = $new_element->{et};
            push @$OP,
                ['create', $new_element],
                ['move-children', $furthest_block->{id} => $new_element->{id}],
                ['append', $new_element->{id} => $furthest_block->{id}];
            ## As $formatting_element is always a formatting element,
            ## it can't be a form-associated element.  Note that
            ## /intended parent/ is $furthest_block.

            splice @$AFE, $formatting_element_afe_i, 1, ();
            splice @$AFE, $bookmark, 0, $new_element;

            splice @$OE, $furthest_block_i + 1, 0, ($new_element);
            #push @popped,
            splice @$OE, $formatting_element_i, 1, ();

            redo OUTER_LOOP;
          } # OUTER_LOOP
        }
      

        sub aaa_foster ($$;%) {
          my ($token, $tag_name, %args) = @_;
          my @popped;
          if ($OE->[-1]->{ns} == HTMLNS and
              $OE->[-1]->{local_name} eq $tag_name) {
            my $found;
            for (reverse @$AFE) {
              if ($_ eq $OE->[-1]) {
                $found = 1;
                last;
              }
            }
            unless ($found) {
              #push @popped,
              pop @$OE;
              ## $args{remove_from_afe_and_oe} - nop
              #push @$OP, ['popped', \@popped];
              return;
            }
          }

          my $outer_loop_counter = 0;
          OUTER_LOOP: {
            if ($outer_loop_counter >= 8) {
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
            $outer_loop_counter++;
            my $formatting_element;
            my $formatting_element_afe_i;
            for (reverse 0..$#$AFE) {
              if (not ref $AFE->[$_]) {
                last;
              } elsif ($AFE->[$_]->{local_name} eq $tag_name) { # ->{ns} == HTMLNS
                $formatting_element = $AFE->[$_];
                $formatting_element_afe_i = $_;
                last;
              }
            }
            unless (defined $formatting_element) {
              ## The "in body" insertion mode, END_TAG_TOKEN, ELSE
              local $_ = $token;
              $ProcessIM->[IN_BODY_IM]->[END_TAG_TOKEN]->[0]->();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }
        my $beyond_scope;
        my $formatting_element_i;
        my $furthest_block;
        my $furthest_block_i;
        for (reverse 0..$#$OE) {
          if ($OE->[$_] eq $formatting_element) {
            $formatting_element_i = $_;
            last;
          } else {
            if ($OE->[$_]->{et} & (APP_ELS | CAP_ELS | HTM_ELS | MAR_M_ANN_ELS | OBJ_ELS | TAB_ELS | TD_TH_ELS | TEM_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
              $beyond_scope = 1;
            }
            if ($OE->[$_]->{et} & (ADD_DIV_ELS | APP_ELS | AAABBBBBCCDDDEFFFFFFHHHHILLMMMMNNNNPPPSSSSTTWX_ELS | BOD_ELS | BUT_ELS | CAP_ELS | COL_ELS | DD_ELS | DT_ELS | FIE_INP_SEL_TEX_ELS | HHHHHH_ELS | HTM_ELS | IMG_ELS | LI_ELS | MAR_M_ANN_ELS | OBJ_ELS | OL_UL_ELS | P_ELS | STY_ELS | TAB_ELS | TBO_TFO_THE_ELS | TD_TH_ELS | TEM_ELS | TR_ELS | M_MI_M_MN_M_MO_M_MS_M_MTE_ELS | S_DES_S_FOR_S_TIT_ELS)) {
              $furthest_block = $OE->[$_];
              $furthest_block_i = $_;
            }
          }
        }
            unless (defined $formatting_element_i) {
              push @$Errors, {type => 'XXX', token => $token};
              splice @$AFE, $formatting_element_afe_i, 1, ();
              if ($args{remove_from_afe_and_oe}) {
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            if ($beyond_scope) {
              push @$Errors, {type => 'XXX', token => $token};
              if ($args{remove_from_afe_and_oe}) {
                splice @$AFE, $formatting_element_afe_i, 1, ();
                #push @popped,
                splice @$OE, $formatting_element_i, 1, ();
              }
              push @$OP, ['popped', \@popped];
              return;
            }
            unless ($formatting_element eq $OE->[-1]) {
              push @$Errors, {type => 'XXX', token => $token};
            }
            unless (defined $furthest_block) {
              #push @popped,
              splice @$OE, $formatting_element_i;
              splice @$AFE, $formatting_element_afe_i, 1, ();
              ## $args{remove_from_afe_and_oe} - nop
              push @$OP, ['popped', \@popped];
              return;
            }

        my $common_ancestor = $OE->[$formatting_element_i-1];
        my $bookmark = $formatting_element_afe_i;
        my $node = $furthest_block;
        my $node_i = $furthest_block_i;
        my $last_node = $furthest_block;
        my $inner_loop_counter = 0;
        INNER_LOOP: {
          $inner_loop_counter++;
          $node_i--;
          $node = $OE->[$node_i];
          last INNER_LOOP if $node eq $formatting_element;
          my $node_afe_i;
          for (reverse 0..$#$AFE) {
            if ($AFE->[$_] eq $node) {
              $node_afe_i = $_;
              last;
            }
          }
          if ($inner_loop_counter > 3 and defined $node_afe_i) {
            splice @$AFE, $node_afe_i, 1, ();
          }
          if (not defined $node_afe_i) {
            push @popped, splice @$OE, $node_i, 1, ();
            redo INNER_LOOP;
          }

          ## Create an HTML element
          $node = {id => $NEXT_ID++,
                   token => $node->{token},
                   ns => HTMLNS,
                   local_name => $node->{token}->{tag_name},
                   attr_list => $node->{token}->{attr_list},
                   et => $Element2Type->[HTMLNS]->{$node->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
          $node->{aet} = $node->{et};
          $AFE->[$node_afe_i] = $node;
          $OE->[$node_i] = $node;
          ## As $node seems never to be a form-assosicated element,
          ## and it will be appended (not inserted) to another node
          ## later anyway, we don't have to associate the form owner
          ## here.  Note that /intended parent/ is $common_ancestor.

          if ($last_node eq $furthest_block) {
            $bookmark = $node_afe_i + 1;
          }

          push @$OP,
              ['create', $node],
              ['append', $last_node->{id} => $node->{id}];
          $last_node = $node;
          redo INNER_LOOP;
        } # INNER_LOOP

            
      if ($common_ancestor->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['append-foster', $last_node->{id} => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['append', $last_node->{id} => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['append', $last_node->{id} => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['append', $last_node->{id} => $common_ancestor->{id}];
      }
    

            ## Create an HTML element
            my $new_element = {id => $NEXT_ID++,
                               token => $formatting_element->{token},
                               ns => HTMLNS,
                               local_name => $formatting_element->{token}->{tag_name},
                               attr_list => $formatting_element->{token}->{attr_list},
                               et => $Element2Type->[HTMLNS]->{$formatting_element->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $new_element->{aet} = $new_element->{et};
            push @$OP,
                ['create', $new_element],
                ['move-children', $furthest_block->{id} => $new_element->{id}],
                ['append', $new_element->{id} => $furthest_block->{id}];
            ## As $formatting_element is always a formatting element,
            ## it can't be a form-associated element.  Note that
            ## /intended parent/ is $furthest_block.

            splice @$AFE, $formatting_element_afe_i, 1, ();
            splice @$AFE, $bookmark, 0, $new_element;

            splice @$OE, $furthest_block_i + 1, 0, ($new_element);
            #push @popped,
            splice @$OE, $formatting_element_i, 1, ();

            redo OUTER_LOOP;
          } # OUTER_LOOP
        }
      

        sub reconstruct_afe () {
          #return unless @$AFE;
          #return if not ref $AFE->[-1];
          for (reverse @$OE) {
            return if $_ eq $AFE->[-1];
          }
          my $entry_i = $#$AFE;
          my $entry = $AFE->[$entry_i];
          while (not $entry_i == 0) {
            $entry_i--;
            $entry = $AFE->[$entry_i];
            last if not ref $entry;
            for (reverse @$OE) {
              last if $_ eq $entry;
            }
          }

          for my $entry_i ($entry_i..$#$AFE) {
            $entry = $AFE->[$entry_i];

            ## Insert an HTML element
            my $node = {id => $NEXT_ID++,
                        token => $entry->{token},
                        ns => HTMLNS,
                        local_name => $entry->{token}->{tag_name},
                        attr_list => $entry->{token}->{attr_list},
                        et => $Element2Type->[HTMLNS]->{$entry->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $node->{aet} = $node->{et};
            
      push @$OP, ['insert', $node => $OE->[-1]->{id}];
    
            push @$OE, $node;

            $AFE->[$entry_i] = $node;
          }
        }
      

        sub reconstruct_afe_foster () {
          #return unless @$AFE;
          #return if not ref $AFE->[-1];
          for (reverse @$OE) {
            return if $_ eq $AFE->[-1];
          }
          my $entry_i = $#$AFE;
          my $entry = $AFE->[$entry_i];
          while (not $entry_i == 0) {
            $entry_i--;
            $entry = $AFE->[$entry_i];
            last if not ref $entry;
            for (reverse @$OE) {
              last if $_ eq $entry;
            }
          }

          for my $entry_i ($entry_i..$#$AFE) {
            $entry = $AFE->[$entry_i];

            ## Insert an HTML element
            my $node = {id => $NEXT_ID++,
                        token => $entry->{token},
                        ns => HTMLNS,
                        local_name => $entry->{token}->{tag_name},
                        attr_list => $entry->{token}->{attr_list},
                        et => $Element2Type->[HTMLNS]->{$entry->{token}->{tag_name}} || $Element2Type->[HTMLNS]->{'*'}};
            $node->{aet} = $node->{et};
            
      if ($OE->[-1]->{et} & (TAB_ELS | TBO_TFO_THE_ELS | TR_ELS)) { # table* context
        FOSTER: {
          for my $i (reverse 1..$#$OE) {
            if ($OE->[$i]->{et} & (TAB_ELS)) { # table
              push @$OP, ['insert-foster', $node => $OE->[$i]->{id}, $OE->[$i-1]->{id}];
              last FOSTER;
            } elsif ($OE->[$i]->{et} & (TEM_ELS)) { # template
              push @$OP, ['insert', $node => $OE->[$i]->{id}];
              last FOSTER;
            }
          }
          push @$OP, ['insert', $node => $OE->[0]->{id}];
        } # FOSTER
      } else {
        push @$OP, ['insert', $node => $OE->[-1]->{id}];
      }
    
            push @$OE, $node;

            $AFE->[$entry_i] = $node;
          }
        }
      

    ## ------ Input byte stream ------
    

## ------ Character encoding processing ------

sub locale_tag ($;$) {
  if (@_ > 1) {
    $_[0]->{locale_tag} = $_[1];
    $_[0]->{locale_tag} =~ tr/A-Z/a-z/ if defined $_[0]->{locale_tag};
  }
  return $_[0]->{locale_tag};
} # locale_tag

sub known_definite_encoding ($;$) {
  if (@_ > 1) {
    $_[0]->{known_definite_encoding} = $_[1];
  }
  return $_[0]->{known_definite_encoding};
} # known_definite_encoding

## Encoding sniffing algorithm
## <http://www.whatwg.org/specs/web-apps/current-work/#determining-the-character-encoding>.
sub _encoding_sniffing ($;%) {
  my ($self, %args) = @_;

  ## One of followings:
  ##   - Step 1. User-specified encoding
  ##   - The new character encoding by change the encoding
  ##     <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>
  ##     step 5. Encoding from <meta charset>
  ##   - A known definite encoding
  my $kde = $self->known_definite_encoding;
  if (defined $kde) {
    ## If specified, it must be an encoding label from the Encoding
    ## Standard.
    my $name = Web::Encoding::encoding_label_to_name $kde;
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 1; # certain
      return;
    }
  }

  return if $args{no_body_data_yet};
  ## $args{no_body_data_yet} flag must be set to true if the body of
  ## the resource is not available to the parser such that
  ## $args{read_head} callback ought not be invoked yet.

  ## Step 2. Wait 500ms or 1024 bytes, whichever came first (See
  ## Web::HTML::Parser for how and when to use this callback).
  my $head = $args{read_head} ? $args{read_head}->() : undef;
  ## $args{read_head} must be a callback which, when invoked, returns
  ## a byte string used to sniff the character encoding of the input
  ## stream.  As described in the HTML Standard, it should be at most
  ## 1024 bytes.  The callback should not invoke sync I/O.  This
  ## method should be invoked with $args{no_body_data_yet} flag unset
  ## only after 500ms has past or 1024 bytes has been received.  The
  ## callback should not invoke any exception.

  ## Step 3. BOM
  if (defined $head) {
    if ($$head =~ /^\xFE\xFF/) {
      $self->{input_encoding} = 'utf-16be';
      $Confident = 1; # certain
      return;
    } elsif ($$head =~ /^\xFF\xFE/) {
      $self->{input_encoding} = 'utf-16le';
      $Confident = 1; # certain
      return;
    } elsif ($$head =~ /^\xEF\xBB\xBF/) {
      $self->{input_encoding} = 'utf-8';
      $Confident = 1; # certain
      return;
    }
  }

  ## Step 4. Transport-layer encoding
  if ($args{transport_encoding_name}) {
    ## $args{transport_encoding_name} must be specified iff the
    ## underlying protocol provides the character encoding for the
    ## input stream.  For HTTP, the |charset=""| parameter in the
    ## |Content-Type:| header specifies the character encoding.  The
    ## value is interpreted as an encoding name or alias defined in
    ## the Encoding Standard.  (Invalid encoding name will be
    ## ignored.)
    my $name = Web::Encoding::encoding_label_to_name $args{transport_encoding_name};
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 1; # certain
      return;
    }
  }

  ## Step 5. <meta charset>
  if (defined $head) {
    my $name = $self->_prescan_byte_stream ($$head);
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 6. Parent browsing context
  if ($args{parent_document}) {
    ## $args{parent_document}, if specified, must be the |Document|
    ## through which the new (to be parsed) document is nested, or the
    ## active document of the parent browsing context of the new
    ## document.

    # XXX
    # if $args{parent_document}->origin equals $self->document->origin and
    #    $args{parent_document}->charset is ASCII compatible {
    #   $self->{input_encoding} = $args{parent_document}->charset;
    #   $Confident = 0; # tentative
    #   return;
    # }
  }

  ## Step 7. History
  if ($args{get_history_encoding_name}) {
    ## EXPERIMENTAL: $args{get_history_encoding_name}, if specified,
    ## must be a callback which returns the canonical character
    ## encoding name for the input stream, guessed by e.g. last visit
    ## to this page.
    # XXX how to handle async access to history DB?
    my $name = Web::Encoding::encoding_label_to_name $args{get_history_encoding_name}->();
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. UniversalCharDet
  if (defined $head) {
    require Web::Encoding::UnivCharDet;
    my $det = Web::Encoding::UnivCharDet->new;
    # XXX locale-dependent configuration
    my $name = Web::Encoding::encoding_label_to_name $det->detect_byte_string ($$head);
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. Locale-dependent default
  my $locale = $self->locale_tag;
  if ($locale) {
    my $name = Web::Encoding::encoding_label_to_name (
        Web::Encoding::locale_default_encoding_name $locale ||
        Web::Encoding::locale_default_encoding_name [split /-/, $locale, 2]->[0]
    );
    if ($name) {
      $self->{input_encoding} = $name;
      $Confident = 0; # tentative
      return;
    }
  }

  ## Step 8. Default of default
  $self->{input_encoding} = 'windows-1252';
  $Confident = 0; # tentative
  return;

  # XXX expose sniffing info for validator
} # _encoding_sniffing

# prescan a byte stream to determine its encoding
# <http://www.whatwg.org/specs/web-apps/current-work/#prescan-a-byte-stream-to-determine-its-encoding>
sub _prescan_byte_stream ($$) {
  # 1.
  (pos $_[1]) = 0;

  # 2.
  LOOP: {
    $_[1] =~ /\G<!--+>/gc;
    $_[1] =~ /\G<!--.*?-->/gcs;
    if ($_[1] =~ /\G<[Mm][Ee][Tt][Aa](?=[\x09\x0A\x0C\x0D\x20\x2F])/gc) {
      # 1.
      #

      # 2.-5.
      my $attr_list = {};
      my $got_pragma = 0;
      my $need_pragma = undef;
      my $charset;

      # 6.
      ATTRS: {
        my $attr = $_[0]->_get_attr ($_[1]) or last ATTRS;

        # 7.
        redo ATTRS if $attr_list->{$attr->{name}};
        
        # 8.
        $attr_list->{$attr->{name}} = $attr;

        # 9.
        if ($attr->{name} eq 'http-equiv') {
          $got_pragma = 1 if $attr->{value} eq 'content-type';
        } elsif ($attr->{name} eq 'content') {
          # algorithm for extracting a character encoding from a
          # |meta| element
          # <http://www.whatwg.org/specs/web-apps/current-work/#algorithm-for-extracting-a-character-encoding-from-a-meta-element>
          if (not defined $charset and
              $attr->{value} =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                                 [\x09\x0A\x0C\x0D\x20]*=
                                 [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                                 ([^"'\x09\x0A\x0C\x0D\x20]
                                  [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            $charset = Web::Encoding::encoding_label_to_name
                (defined $1 ? $1 : defined $2 ? $2 : $3);
            $need_pragma = 1;
          }
        } elsif ($attr->{name} eq 'charset') {
          $charset = Web::Encoding::encoding_label_to_name $attr->{value};
          $need_pragma = 0;
        }

        # 10.
        return undef if pos $_[1] >= length $_[1];
        redo ATTRS;
      } # ATTRS

      # 11. Processing, 12.
      if (not defined $need_pragma or
          ($need_pragma and not $got_pragma)) {
        #
      } elsif (defined $charset) {
        # 13.-14.
        $charset = Web::Encoding::fixup_html_meta_encoding_name $charset;

        # 15.-16.
        return $charset if defined $charset;
      }
    } elsif ($_[1] =~ m{\G</?[A-Za-z][^\x09\x0A\x0C\x0D\x20>]*}gc) {
      {
        $_[0]->_get_attr ($_[1]) and redo;
      }
    } elsif ($_[1] =~ m{\G<[!/?][^>]*}gc) {
      #
    }

    # 3. Next byte
    $_[1] =~ /\G[^<]+/gc || $_[1] =~ /\G</gc;
    return undef if pos $_[1] >= length $_[1];
    redo LOOP;
  } # LOOP
} # _prescan_byte_stream

# get an attribute
# <http://www.whatwg.org/specs/web-apps/current-work/#concept-get-attributes-when-sniffing>
sub _get_attr ($$) {
  # 1.
  $_[1] =~ /\G[\x09\x0A\x0C\x0D\x20\x2F]+/gc;

  # 2.
  if ($_[1] =~ /\G>/gc) {
    pos ($_[1])--;
    return undef;
  }
  
  # 3.
  my $attr = {name => '', value => ''};

  # 4.-5.
  if ($_[1] =~ m{\G([^\x09\x0A\x0C\x0D\x20/>][^\x09\x0A\x0C\x0D\x20/>=]*)}gc) {
    $attr->{name} .= $1;
    $attr->{name} =~ tr/A-Z/a-z/;
  }
  return undef if $_[1] =~ m{\G\z}gc;
  return $attr if $_[1] =~ m{\G(?=[/>])}gc;

  # 6.
  $_[1] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 7.-8.
  return $attr unless $_[1] =~ m{\G=}gc;

  # 9.
  $_[1] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 10.-12.
  if ($_[1] =~ m{\G\x22([^\x22]*)\x22}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[1] =~ m{\G\x27([^\x27]*)\x27}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[1] =~ m{\G([^\x09\x0A\x0C\x0D\x20>]+)}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  }
  return undef if $_[1] =~ m{\G\z}gc;
  return $attr;
} # _get_attr

sub _change_the_encoding ($$$) {
  my ($self, $name, $attr) = @_;

  ## "meta" start tag
  ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-main-inhead>.

  ## "meta". Confidence is /tentative/
  #return undef if $Confident; # certain or irrelevant

  $name = Web::Encoding::encoding_label_to_name $name;
  unless (defined $name) {
    ## "meta". Supported encoding
    return undef;
  }

  ## "meta". ASCII-compatible or UTF-16
  ## All encodings in Encoding Standard are ASCII-compatible or UTF-16.

  ## Change the encoding
  ## <http://www.whatwg.org/specs/web-apps/current-work/#change-the-encoding>.

  ## Step 1. UTF-16
  if ($self->{input_encoding} eq 'utf-16le' or
      $self->{input_encoding} eq 'utf-16be') {
    $Confident = 1; # certain
    return undef;
  }

  ## Step 2.-3.
  $name = Web::Encoding::fixup_html_meta_encoding_name $name;
  
  ## Step 4. Same
  if ($name eq $self->{input_encoding}) {
    $Confident = 1; # certain
    return undef;
  }

  push @$Errors, {type => 'charset label detected',
                  text => $self->{input_encoding},
                  value => $name,
                  level => 'i',
                  token => $attr};

  ## Step 5. Change the encoding on the fly
  ## Not implemented.

  ## Step 6. Navigate with replace.
  return $name; # change!

#XXX move this to somewhere else (when callback can't handle restart)
  ## Step 6. If can't restart
  $Confident = 1; # certain
  return undef;
} # _change_the_encoding

  
    ## ------ Tokenizer ------
    
    my $StateActions = [];
    $StateActions->[CDATA_SECTION_STATE] = sub {
if ($Input =~ /\G([^\\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$State = CDATA_SECTION_STATE__5D;
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE__5D] = sub {
if ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp .= $1;
$State = CDATA_SECTION_STATE__5D_5D;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE__5D_5D] = sub {
if ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
} elsif ($Input =~ /\G([\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = CDATA_SECTION_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$State = CDATA_SECTION_STATE__5D;
} elsif ($Input =~ /\G(.)/gcs) {
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<name>} .= q@�@;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-public-identifier-double-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-public-identifier-double-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-public-identifier-single-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_PUBLIC_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = DOCTYPE_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-public-identifier-single-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'doctype-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-doctype-name-003e', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        push @$Errors, {type => 'doctype-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'doctype-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-system-identifier-double-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-system-identifier-double-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\\'\ \>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-system-identifier-single-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'doctype-system-identifier-single-quoted-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PLAINTEXT_STATE] = sub {
if ($Input =~ /\G([^\\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = PLAINTEXT_STATE_CR;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PLAINTEXT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = PLAINTEXT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = PLAINTEXT_STATE_CR;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = PLAINTEXT_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = PLAINTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = PLAINTEXT_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = RAWTEXT_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = RAWTEXT_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = RAWTEXT_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_STATE] = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RAWTEXT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = RAWTEXT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RAWTEXT_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RAWTEXT_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RAWTEXT_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RAWTEXT_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RAWTEXT_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = RCDATA_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = RCDATA_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = RCDATA_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE] = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE___CHARREF_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = RCDATA_STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[RCDATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = RCDATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([P])/gcs) {
$Temp = $1;
$State = AFTER_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$State = AFTER_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$State = AFTER_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$State = AFTER_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_P] = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PU;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PU;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_PU] = sub {
if ($Input =~ /\G([B])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUB;
} elsif ($Input =~ /\G([b])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUB;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_PUB] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUBL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUBL;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_PUBL] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_PUBLI] = sub {
if ($Input =~ /\G([C])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {
$State = AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_S] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SY;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_SY] = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYS;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYS;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_SYS] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYST;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYST;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_SYST] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = AFTER_DOCTYPE_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_NAME_STATE_SYSTE] = sub {
if ($Input =~ /\G([M])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-name-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'after-doctype-public-identifier-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'after-doctype-public-identifier-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-public-identifier-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_DOCTYPE_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'after-doctype-public-keyword-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'after-doctype-public-keyword-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'after-doctype-public-keyword-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-public-keyword-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-system-identifier-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'after-doctype-system-keyword-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'after-doctype-system-keyword-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'after-doctype-system-keyword-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-doctype-system-keyword-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {
$State = BEFORE_ATTR_VALUE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'after-attribute-name-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'after-attribute-name-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'after-attribute-name-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ATTR_VALUE__QUOTED__STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'after-attribute-value-quoted-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\=\>ABCDEFGHJKNQRVWZILMOPSTUXY\ \"\'\<]+)/gcs) {
$Attr->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'attribute-name-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'attribute-name-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'attribute-name-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<name>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\&\ ]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__DQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE] = sub {
if ($Input =~ /\G([^\\&\'\ ]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= $Temp;
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= q@
@;
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__SQ__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\&\>\ \"\'\<\=\`]+)/gcs) {
$Attr->{q<value>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                  }
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Attr->{q<value>} .= $Temp;
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<value>} .= $Temp;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {
$Attr->{q<value>} .= $Temp;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\=])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G([\`])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

        push @$Errors, {type => 'attribute-value-unquoted-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'before-doctype-name-003e', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        $Token = {type => DOCTYPE_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_DOCTYPE_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'before-doctype-public-identifier-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'before-doctype-public-identifier-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_DOCTYPE_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'before-doctype-system-identifier-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'before-doctype-system-identifier-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $3;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $3;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$Attr->{q<value>} .= $3;
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} .= $4;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} .= $3;
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\/\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\>/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute', text => $Attr->{name}, index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\/\>/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\>/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'before-attribute-name-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'before-attribute-name-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'before-attribute-name-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'before-attribute-name-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTR_VALUE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= q@�@;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'before-attribute-value-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'before-attribute-value-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'before-attribute-value-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\`])/gcs) {

        push @$Errors, {type => 'before-attribute-value-0060', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr->{q<value>} .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<value>} .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'between-doctype-public-and-system-identifiers-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_DOCTYPE_STATE] = sub {
if ($Input =~ /\G([^\>]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_COMMENT_STATE] = sub {
if ($Input =~ /\G([^\ \\>]+)/gcs) {
$Token->{q<data>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
push @$Tokens, $Token;
$State = DATA_STATE;
} else {
if ($EOF) {
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_COMMENT_STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = BOGUS_COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CHARREF_IN_RCDATA_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = RCDATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_RCDATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = RCDATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = RCDATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CHARREF_IN_DATA_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = q@&@;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$Temp = q@&@;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_BANG_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@--!@;
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$Token->{q<data>} .= q@--!@;
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@--!�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@--!@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@-�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_END_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@--�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'comment-end-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\!])/gcs) {

        push @$Errors, {type => 'comment-end-0021', level => 'm',
                        index => $Offset + pos $Input};
      
$State = COMMENT_END_BANG_STATE;
} elsif ($Input =~ /\G([\-])/gcs) {

        push @$Errors, {type => 'comment-end-002d', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@-@;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'comment-end-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_START_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@-�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'comment-start-dash-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_START_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_START_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'comment-start-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_STATE] = sub {
if ($Input =~ /\G([^\\-\ ]+)/gcs) {
$Token->{q<data>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@�@;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[COMMENT_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = COMMENT_END_DASH_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = COMMENT_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE] = sub {
if ($Input =~ /\G([^\\&\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-before-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-decimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFafbcde]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-hexadecimal-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $InvalidCharRefs->{0}->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = $replace->[0];
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          index => pos $Input}; # XXXindex
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {
$Temp .= $1;

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc', index => pos $Input}; # XXXindex
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'not charref', text => $Temp, index => pos $Input} # XXXindex
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'character-reference-number-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = DATA_STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'end-tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'end-tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'end-tag-open-003e', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'end-tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE] = sub {
if ($Input =~ /\G([\-])/gcs) {
$Temp = $1;
$State = MDO_STATE__;
} elsif ($Input =~ /\G([D])/gcs) {
$Temp = $1;
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\[])/gcs) {
$Temp = $1;
$State = MDO_STATE__5B;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp = $1;
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__] = sub {
if ($Input =~ /\G([\-])/gcs) {

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_D] = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DO;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DO;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DO] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOC;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOC;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOC] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCT;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCT] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTY;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCTY] = sub {
if ($Input =~ /\G([P])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTYP;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp .= $1;
$State = MDO_STATE_DOCTYP;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCTYP] = sub {
if ($Input =~ /\G([E])/gcs) {
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([e])/gcs) {
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5B] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BC;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BC] = sub {
if ($Input =~ /\G([D])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCD;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCD] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDA;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDA] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDAT;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDAT] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = MDO_STATE__5BCDATA;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDATA] = sub {
if ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {

          if (not defined $InForeign) {
            pos ($Input) -= length $1;
            return 1;
          } else {
            if ($InForeign) {
              $State = CDATA_SECTION_STATE;
              return 0;
            }
          }
        

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

        push @$Errors, {type => 'markup-declaration-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR] = sub {
if ($Input =~ /\G([\	\\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

        if ($Temp eq 'script') {
          $State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
        } else {
          $State = SCRIPT_DATA_ESCAPED_STATE;
        }
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= chr ((ord $1) + 32);

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;
$Temp .= $1;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@>@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@/@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_STATE] = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_DOUBLE_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\/])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = SCRIPT_DATA_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = SCRIPT_DATA_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPE_START_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPE_START_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPE_START_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_DASH_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@>@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_DASH_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = BEFORE_ATTR_NAME_STATE;
            return 1;
          }
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {

          if ($Token->{tag_name} eq $LastStartTagName) {
            $State = SELF_CLOSING_START_TAG_STATE;
            return 1;
          }
        
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if ($Token->{tag_name} eq $LastStartTagName) {
          $State = DATA_STATE;
          $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
          push @$Tokens, $Token;
          return 1;
        }
      
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
$Temp .= $1;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy]+)/gcs) {
$Token->{q<tag_name>} .= $1;
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$Temp .= $1;
$State = SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$Temp .= $1;
$State = SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Temp = '';
$Temp .= chr ((ord $1) + 32);
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {
$Temp = '';
$Temp .= $1;
$State = SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_STATE] = sub {
if ($Input =~ /\G([^\\-\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_ESCAPED_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_ESCAPED_STATE_CR;
} elsif ($Input =~ /\G([\-])/gcs) {
$State = SCRIPT_DATA_ESCAPED_DASH_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@-@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_ESCAPED_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_LESS_THAN_SIGN_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\!])/gcs) {
$State = SCRIPT_DATA_ESCAPE_START_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<!@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\/])/gcs) {
$Temp = '';
$State = SCRIPT_DATA_END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_STATE] = sub {
if ($Input =~ /\G([^\\<\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SCRIPT_DATA_STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = SCRIPT_DATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = SCRIPT_DATA_STATE_CR;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = SCRIPT_DATA_LESS_THAN_SIGN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = SCRIPT_DATA_STATE;

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@�@,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = SCRIPT_DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {
$State = SCRIPT_DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[SELF_CLOSING_START_TAG_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = q@�@;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-0022', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-0027', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-003c', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      

        push @$Errors, {type => 'before-attribute-name-003d', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'self-closing-start-tag-else', level => 'm',
                        index => $Offset + pos $Input};
      
$Attr = {index => $Offset + pos $Input};
$Attr->{q<name>} = $1;
$Attr->{q<value>} = '';
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\>ABCDEFGHJKNQRVWZILMOPSTUXY\ ]+)/gcs) {
$Token->{q<tag_name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      
$Token->{q<tag_name>} .= q@�@;
} else {
if ($EOF) {

        push @$Errors, {type => 'EOF', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_OPEN_STATE] = sub {
if ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {
$Temp = '';
$State = MDO_STATE;
$Temp = $1;
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$State = COMMENT_START_DASH_STATE;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $2;
$State = COMMENT_STATE;
$Token->{q<data>} .= $3;
$State = COMMENT_END_DASH_STATE;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $4;
$State = COMMENT_STATE;
$Token->{q<data>} .= $5;
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {
$Temp = '';
$State = MDO_STATE;
$Temp = $1;
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$Token->{q<data>} .= $2;
$State = COMMENT_STATE;
$Token->{q<data>} .= $3;
$State = COMMENT_END_DASH_STATE;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $4;
$State = COMMENT_STATE;
$Token->{q<data>} .= $5;
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {
$Temp = '';
$State = MDO_STATE;
$Temp = $1;
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$State = COMMENT_START_DASH_STATE;
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $2;
$State = COMMENT_STATE;
$Token->{q<data>} .= $3;
$State = COMMENT_END_DASH_STATE;
$State = COMMENT_END_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {
$Temp = '';
$State = MDO_STATE;
$Temp = $1;
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$Token->{q<data>} .= $2;
$State = COMMENT_STATE;
$Token->{q<data>} .= $3;
$State = COMMENT_END_DASH_STATE;
$State = COMMENT_END_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\/([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\/([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([a-z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute', index => pos $Input}; # XXX index
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc', index => pos $Input}; # XXX index
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == START_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            if (not defined $LastStartTagName) { # "first start tag"
              $LastStartTagName = $Token->{tag_name};
              return 1;
            } else {
              $LastStartTagName = $Token->{tag_name};
            }
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
            return 1 if $Token->{tag_name} eq 'meta' and not $Confident;
          }
        

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G\!(\-)\-\-\-\>/gcs) {
$Temp = '';
$State = MDO_STATE;
$Temp = $1;
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$State = COMMENT_START_DASH_STATE;
$State = COMMENT_END_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\!])/gcs) {
$Temp = '';
$State = MDO_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKNQRVWZILMOPSTUXY])/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = chr ((ord $1) + 32);
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([afbcdeghjknqrvwzilmopstuxy])/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Errors, {type => 'NULL', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          index => $Offset + pos $Input};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        
$State = TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {

        push @$Errors, {type => 'tag-open-003f', level => 'm',
                        index => $Offset + pos $Input};
      

        $Token = {type => COMMENT_TOKEN, tn => 0, index => $Offset + pos $Input};
      
$Token->{q<data>} = '';
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          index => $Offset + pos $Input};
        
} else {
if ($EOF) {

        push @$Errors, {type => 'tag-open-else', level => 'm',
                        index => $Offset + pos $Input};
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          index => $Offset + pos $Input};
        

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};

    sub _tokenize ($) {
      TOKENIZER: while (1) {
        my $code = $StateActions->[$State]
            or die "Unknown state |$State|";
        &$code and last TOKENIZER;
      } # TOKENIZER
    } # _tokenize
  
    ## ------ Tree constructor ------
    
    sub _construct_tree ($$) {
      my $self = shift;

      for my $token (@$Tokens) {
        local $_ = $token;
        if ((not @$OE) or 
($OE->[-1]->{aet} & (HTML_NS_ELS)) or 
(($OE->[-1]->{aet} & (M_MI_M_MN_M_MO_M_MS_M_MTE_ELS)) and 
($token->{type} == START_TAG_TOKEN and not ($token->{tn} == TAG_NAME_MALIGNMARK_MGLYPH))) or 
(($OE->[-1]->{aet} & (M_MI_M_MN_M_MO_M_MS_M_MTE_ELS)) and 
($token->{type} == 6)) or 
(($OE->[-1]->{aet} & (M_ANN_ELS)) and 
($token->{type} == START_TAG_TOKEN and $token->{tn} == TAG_NAME_SVG)) or 
(($OE->[-1]->{aet} & (M_ANN_M_ANN_ELS | S_DES_S_FOR_S_TIT_ELS)) and 
($token->{type} == 5)) or 
(($OE->[-1]->{aet} & (M_ANN_M_ANN_ELS | S_DES_S_FOR_S_TIT_ELS)) and 
($token->{type} == 6)) or 
($token->{type} == 4)) {
          &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
        } else {
          &{$ProcessIM->[IN_FOREIGN_CONTENT_IM]->[$token->{type}]->[$token->{tn}]};
        }
      }

      ## Adjusted current node
      $InForeign = !!(
        @$OE and $OE->[-1]->{aet} & (MATHML_NS_ELS | SVG_NS_ELS)
      );

      $self->dom_tree ($OP);
      @$OP = ();
      @$Tokens = ();
    } # _construct_tree
  
    ## ------ DOM integration ------
    
sub dom_tree ($$) {
  my ($self, $ops) = @_;

  my $doc = $self->{document};
  my $strict = $doc->strict_error_checking;
  $doc->strict_error_checking (0);

  my $nodes = $self->{nodes};
  for my $op (@$ops) {
    if ($op->[0] eq 'insert' or
        $op->[0] eq 'insert-foster' or
        $op->[0] eq 'create') {
      my $data = $op->[1];
      my $el = $doc->create_element_ns
          ($NSToURL->[$data->{ns}], [undef, $data->{local_name}]);
      for my $attr (@{$data->{attr_list} or []}) {
        $el->set_attribute_ns (@{$attr->{name_args}} => $attr->{value});
      }
      # XXX index
      if ($data->{ns} == HTMLNS and $data->{local_name} eq 'template') {
        $nodes->[$data->{id}] = $el->content;
      } else {
        $nodes->[$data->{id}] = $el;
      }
      # XXX $data->{script_flags}

      if (defined $data->{form}) {
        my $form = $nodes->[$data->{form}];
        #warn "XXX set form owner of $el to $form if $nodes->[$op->[2]] and $form are in the same home subtree";
      }

      if ($op->[0] eq 'insert') {
        $nodes->[$op->[2]]->append_child ($el);
      } elsif ($op->[0] eq 'insert-foster') {
        my $next_sibling = $nodes->[$op->[2]];
        my $parent = $next_sibling->parent_node;
        if (defined $parent) {
          if ($parent->node_type == $parent->DOCUMENT_NODE) {
            #
          } else {
            $parent->insert_before ($el, $next_sibling);
          }
        } else {
          $nodes->[$op->[3]]->append_child ($el);
        }
      }
    } elsif ($op->[0] eq 'text') {
      $nodes->[$op->[2]]->manakai_append_text ($op->[1]);
    } elsif ($op->[0] eq 'text-foster') {
      my $next_sibling = $nodes->[$op->[2]];
      my $parent = $next_sibling->parent_node;
      if (defined $parent) {
        if ($parent->node_type == $parent->DOCUMENT_NODE) {
          #
        } else {
          my $prev_sibling = $next_sibling->previous_sibling;
          if (defined $prev_sibling and
              $prev_sibling->node_type == $prev_sibling->TEXT_NODE) {
            $prev_sibling->manakai_append_text ($op->[1]);
          } else {
            $parent->insert_before
              ($doc->create_text_node ($op->[1]), $next_sibling);
          }
        }
      } else {
        $nodes->[$op->[3]]->manakai_append_text ($op->[1]);
      }

    } elsif ($op->[0] eq 'append') {
      $nodes->[$op->[2]]->append_child ($nodes->[$op->[1]]);
    } elsif ($op->[0] eq 'append-foster') {
      my $next_sibling = $nodes->[$op->[2]];
      my $parent = $next_sibling->parent_node;
      if (defined $parent) {
        if ($parent->node_type == $parent->DOCUMENT_NODE) {
          #
        } else {
          $parent->insert_before ($nodes->[$op->[1]], $next_sibling);
        }
      } else {
        $nodes->[$op->[3]]->append_child ($nodes->[$op->[1]]);
      }
    } elsif ($op->[0] eq 'move-children') {
      my $new_parent = $nodes->[$op->[2]];
      # XXX mutation observer?
      for ($nodes->[$op->[1]]->child_nodes->to_list) {
        $new_parent->append_child ($_);
      }

    } elsif ($op->[0] eq 'comment') {
      $nodes->[$op->[2]]->append_child ($doc->create_comment ($op->[1]));
    } elsif ($op->[0] eq 'doctype') {
      my $data = $op->[1];
      my $dt = $doc->implementation->create_document_type
          ($data->{name},
           defined $data->{public_identifier} ? $data->{public_identifier} : '',
           defined $data->{system_identifier} ? $data->{system_identifier} : '');
      $nodes->[$op->[2]]->append_child ($dt);

    } elsif ($op->[0] eq 'set-if-missing') {
      my $el = $nodes->[$op->[2]];
      for my $attr (@{$op->[1]}) {
        $el->set_attribute_ns (@{$attr->{name_args}} => $attr->{value})
            unless $el->has_attribute_ns ($attr->{name_args}->[0], $attr->{name_args}->[1]->[1]);
      }
      # XXX index

    } elsif ($op->[0] eq 'change-the-encoding') {
      unless ($Confident) {
        my $changed = $self->_change_the_encoding ($op->[1], $op->[2]);
        push @$Callbacks, [$self->onrestartwithencoding, $changed]
            if defined $changed;
      }
      # XXX conformance error if bad index (has reference)
    } elsif ($op->[0] eq 'script') {
      # XXX insertion point setup
      push @$Callbacks, [$self->onscript, $nodes->[$op->[1]]];
    } elsif ($op->[0] eq 'ignore-script') {
      warn "XXX set already started flag of $nodes->[$op->[1]]";
    } elsif ($op->[0] eq 'appcache') {
      if (defined $op->[1] and length $op->[1]->{value}) {
        push @$Callbacks, [$self->onappcacheselection, $op->[1]->{value}];
      } else {
        push @$Callbacks, [$self->onappcacheselection, undef];
      }

    } elsif ($op->[0] eq 'popped') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_ELS | AUD_VID_ELS | OBJ_ELS | STY_ELS) } @{$op->[1]}]];
    } elsif ($op->[0] eq 'stop-parsing') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_ELS | AUD_VID_ELS | OBJ_ELS | STY_ELS) } @$OE]];
      #@$OE = ();

      # XXX stop parsing
    } elsif ($op->[0] eq 'abort') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_ELS | AUD_VID_ELS | OBJ_ELS | STY_ELS) } @$OE]];
      #@$OE = ();

      # XXX abort

    } elsif ($op->[0] eq 'remove') {
      my $parent = $nodes->[$op->[1]]->parent_node;
      $parent->remove_child ($nodes->[$op->[1]]) if defined $parent;
    } elsif ($op->[0] eq 'set-compat-mode') {
      $doc->manakai_compat_mode ($op->[1]);
    } else {
      die "Unknown operation |$op->[0]|";
    }
  }

  $doc->strict_error_checking ($strict);
} # dom_tree

  
    ## ------ API ------
    
    sub _run ($) {
      my ($self) = @_;
      my $is = $self->{input_stream};
      my $length = @$is == 0 ? 0 : defined $is->[0]->[0] ? length $is->[0]->[0] : 0;
      my $in_offset = 0;
      {
        my $len = 10000;
        $len = $length - $in_offset if $in_offset + $len > $length;
        if ($len > 0) {
          $Input = substr $is->[0]->[0], $in_offset, $len;
        } else {
          shift @$is;
          if (@$is) {
            if (defined $is->[0]->[0]) {
              $length = length $is->[0]->[0];
              $in_offset = 0;
              redo;
            } else {
              $EOF = 1;
            }
          } else {
            last;
          }
        }
        {
          $self->_tokenize;
          $self->_construct_tree;

          if (@$Callbacks or @$Errors) {
            $self->{saved_states} = {Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, Token => $Token};

            $self->onerrors->($self, $Errors) if @$Errors;
            for my $cb (@$Callbacks) {
              $cb->[0]->($self, $cb->[1]);
            }
            @$Errors = ();
            @$Callbacks = ();

            if ($self->{restart}) {
              delete $self->{restart};
              return 0;
            }

            ($Attr, $CONTEXT, $Confident, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $Token) = @{$self->{saved_states}}{qw(Attr CONTEXT Confident EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};
          }

          redo unless pos $Input == length $Input; # XXX parser pause flag
        }
        $Offset += $len;
        $in_offset += $len;
        redo unless $EOF;
      }
      return 1;
    } # _run

    sub _feed_chars ($$) {
      my ($self, $input) = @_;
      pos ($input->[0]) = 0;
      while ($input->[0] =~ /[\x{0001}-\x{0008}\x{000B}\x{000E}-\x{001F}\x{007F}-\x{009F}\x{D800}-\x{DFFF}\x{FDD0}-\x{FDEF}\x{FFFE}-\x{FFFF}\x{1FFFE}-\x{1FFFF}\x{2FFFE}-\x{2FFFF}\x{3FFFE}-\x{3FFFF}\x{4FFFE}-\x{4FFFF}\x{5FFFE}-\x{5FFFF}\x{6FFFE}-\x{6FFFF}\x{7FFFE}-\x{7FFFF}\x{8FFFE}-\x{8FFFF}\x{9FFFE}-\x{9FFFF}\x{AFFFE}-\x{AFFFF}\x{BFFFE}-\x{BFFFF}\x{CFFFE}-\x{CFFFF}\x{DFFFE}-\x{DFFFF}\x{EFFFE}-\x{EFFFF}\x{FFFFE}-\x{FFFFF}\x{10FFFE}-\x{10FFFF}]/gc) {
        push @$Errors, {type => 'XXX', index => $-[0], level => 'm'};
      }
      push @{$self->{input_stream}}, $input;

      return $self->_run;
    } # _feed_chars

    sub _feed_eof ($) {
      my $self = $_[0];
      push @{$self->{input_stream}}, [undef];
      return $self->_run;
    } # _feed_eof

    sub parse_char_string ($$$) {
      #my ($self, $string, $document) = @_;
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      $self->{input_stream} = [];
      my $doc = $self->{document} = $_[2];
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $Confident = 1; # irrelevant
      $State = DATA_STATE;
      $IM = INITIAL_IM;

      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      $self->_cleanup_states;
      return;
    } # parse_char_string

    sub parse_char_string_with_context ($$$$) {
      #my ($self, $string, $context, $document) = @_;
      my $self = $_[0];
      my $context = $_[2];
      ## $context MUST be an Element or undef.
      ## $document MUST be an empty Document.

      ## HTML fragment parsing algorithm
      ## <http://www.whatwg.org/specs/web-apps/current-work/#parsing-html-fragments>.

      ## 1.
      my $doc = $self->{document} = $_[3];
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      my $nodes = $self->{nodes} = [$doc];

      ## 2.
      $doc->manakai_compat_mode ($context->owner_document->manakai_compat_mode)
          if defined $context;

      ## 3.
      my $input = [$_[1]]; # string copy
      $self->{input_stream} = [];
      # XXX index

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $State = DATA_STATE;
      $IM = INITIAL_IM;

      ## 4.
      my $root;
      if (defined $context) {
        ## 4.1.
        my $node_ns = $context->namespace_uri || '';
        my $node_ln = $context->local_name;
        if ($node_ns eq 'http://www.w3.org/1999/xhtml') {
          # XXX JSON
          if ($node_ln eq 'title' or $node_ln eq 'textarea') {
            $State = RCDATA_STATE;
          } elsif ($node_ln eq 'script') {
            $State = SCRIPT_DATA_STATE;
          } elsif ({
            style => 1,
            xmp => 1,
            iframe => 1,
            noembed => 1,
            noframes => 1,
            noscript => $Scripting,
          }->{$node_ln}) {
            $State = RAWTEXT_STATE;
          } elsif ($node_ln eq 'plaintext') {
            $State = PLAINTEXT_STATE;
          }
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => HTMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[HTMLNS]->{$node_ln} || $Element2Type->[HTMLNS]->{'*'},
                      aet => $Element2Type->[HTMLNS]->{$node_ln} || $Element2Type->[HTMLNS]->{'*'}};
        } elsif ($node_ns eq 'http://www.w3.org/2000/svg') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => SVGNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[SVGNS]->{$node_ln} || $Element2Type->[SVGNS]->{'*'},
                      aet => $Element2Type->[SVGNS]->{$node_ln} || $Element2Type->[SVGNS]->{'*'}};
        } elsif ($node_ns eq 'http://www.w3.org/1998/Math/MathML') {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => MATHMLNS,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => $Element2Type->[MATHMLNS]->{$node_ln} || $Element2Type->[MATHMLNS]->{'*'},
                      aet => $Element2Type->[MATHMLNS]->{$node_ln} || $Element2Type->[MATHMLNS]->{'*'}};
          if ($node_ln eq 'annotation-xml') {
            my $encoding = $context->get_attribute_ns (undef, 'encoding');
            if (defined $encoding) {
              $encoding =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
              if ($encoding eq 'text/html' or
                  $encoding eq 'application/xhtml+xml') {
                $CONTEXT->{et} = $CONTEXT->{aet} = M_ANN_M_ANN_ELS;
              }
            }
          }
        } else {
          $CONTEXT = {id => $NEXT_ID++,
                      #token => undef,
                      ns => 0,
                      local_name => $node_ln,
                      attr_list => {}, # not relevant
                      et => 0,
                      aet => 0};
        }
        $nodes->[$CONTEXT->{id}] = $context;

        ## 4.2.
        $root = $doc->create_element ('html');

        ## 4.3.
        $doc->append_child ($root);

        ## 4.4.
        @$OE = ({id => $NEXT_ID++,
                 #token => undef,
                 ns => HTMLNS,
                 local_name => 'html',
                 attr_list => {},
                 et => $Element2Type->[HTMLNS]->{html},
                 aet => $CONTEXT->{aet}});

        ## 4.5.
        if ($node_ns eq 'http://www.w3.org/1999/xhtml' and
            $node_ln eq 'template') {
          push @$TEMPLATE_IMS, IN_TEMPLATE_IM;
          $nodes->[$OE->[-1]->{id}] = $root->content;
        } else {
          $nodes->[$OE->[-1]->{id}] = $root;
        }

        ## 4.6.
        &reset_im;

        ## 4.7.
        my $anode = $context;
        while (defined $anode) {
          if ($anode->node_type == 1 and
              ($anode->namespace_uri || '') eq 'http://www.w3.org/1999/xhtml' and
              $anode->local_name eq 'form') {
            if ($anode eq $context) {
              $FORM_ELEMENT = $CONTEXT;
            } else {
              $FORM_ELEMENT = {id => $NEXT_ID++,
                               #token => undef,
                               ns => HTMLNS,
                               local_name => 'form',
                               attr_list => {}, # not relevant
                               et => $Element2Type->[HTMLNS]->{form},
                               aet => $Element2Type->[HTMLNS]->{form}};
            }
            last;
          }
          $anode = $anode->parent_node;
        }
      } # $context

      ## 5.
      $Confident = 1; # irrelevant

      ## 6.
      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      $self->_cleanup_states;

      ## 7.
      return defined $context ? $root->child_nodes : $doc->child_nodes;
    } # parse_char_string_with_context

    sub parse_chars_start ($$) {
      my ($self, $doc) = @_;

      $self->{input_stream} = [];
      $self->{document} = $doc;
      $doc->manakai_is_html (1);
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $Confident = 1; # irrelevant
      $State = DATA_STATE;
      $IM = INITIAL_IM;

      $self->{saved_states} = {Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, Token => $Token};
      return;
    } # parse_chars_start

    sub parse_chars_feed ($$) {
      my $self = $_[0];
      my $input = [$_[1]];

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($Attr, $CONTEXT, $Confident, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $Token) = @{$self->{saved_states}}{qw(Attr CONTEXT Confident EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};

      $self->_feed_chars ($input) or die "Can't restart";

      $self->{saved_states} = {Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, Token => $Token};
      return;
    } # parse_chars_feed

    sub parse_chars_end ($) {
      my $self = $_[0];
      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($Attr, $CONTEXT, $Confident, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $Token) = @{$self->{saved_states}}{qw(Attr CONTEXT Confident EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};

      $self->_feed_eof or die "Can't restart";
      
      $self->_cleanup_states;
      return;
    } # parse_chars_end

## NOTE: HTML5 spec says that the encoding layer MUST NOT strip BOM
## and the HTML layer MUST ignore it.  However, we does strip BOM in
## the encoding layer and the HTML layer does not ignore any U+FEFF,
## because the core part of our HTML parser expects a string of
## character, not a string of bytes or code units or anything which
## might contain a BOM.  Therefore, any parser interface that accepts
## a string of bytes, such as |parse_byte_string| in this module, must
## ensure that it does strip the BOM and never strip any ZWNBSP.

## XXX The policy mentioned above might change when we implement
## Encoding Standard spec.

    sub parse_byte_string ($$$$) {
      #my ($self, $charset_name, $string, $doc) = @_;
      my $self = $_[0];

      my $doc = $self->{document} = $_[3];
      $doc->manakai_is_html (1);
      $self->{can_restart} = 1;

      PARSER: {
        $self->{input_stream} = [];
        $self->{nodes} = [$doc];
        $doc->remove_child ($_) for $doc->child_nodes->to_list;

        local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
        $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
        $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};

        my $inputref = \($_[2]);
        $self->_encoding_sniffing
            (transport_encoding_name => $_[1],
             read_head => sub {
          return \substr $$inputref, 0, 1024;
        }); # $Confident is set within this method.
        $doc->input_encoding ($self->{input_encoding});

        my $input = [decode $self->{input_encoding}, $$inputref]; # XXXencoding

        # XXX index

        $State = DATA_STATE;
        $IM = INITIAL_IM;

        $self->_feed_chars ($input) or redo PARSER;
        $self->_feed_eof or redo PARSER;
      } # PARSER

      $self->_cleanup_states;
      return;
    } # parse_byte_string

    sub _parse_bytes_init ($) {
      my $self = $_[0];

      my $doc = $self->{document};
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      # XXX index

      delete $self->{parse_bytes_started};
      $self->{input_stream} = [];
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $State = DATA_STATE;
      $IM = INITIAL_IM;
    } # _parse_bytes_init

    sub _parse_bytes_start_parsing ($;%) {
      my ($self, %args) = @_;
      
      $self->_encoding_sniffing
          (transport_encoding_name => $self->{transport_encoding_label},
           no_body_data_yet => $args{no_body_data_yet},
           read_head => sub {
             return \(substr $self->{byte_buffer}, 0, 1024);
           }); # $Confident is set within this method.
      if (not defined $self->{input_encoding} and $args{no_body_data_yet}) {
        return 1;
      }
      $self->{document}->input_encoding ($self->{input_encoding});

      $self->{parse_bytes_started} = 1;
      #XXXxml $self->{is_xml} = 1;

      my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding

      $self->_feed_chars ($input) or return 0;
      $self->_feed_eof or return 0;

      return 1;
    } # _parse_bytes_start_parsing

    sub parse_bytes_start ($$$) {
      my ($self, $charset_name, $doc) = @_;

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $charset_name;

      $self->{document} = $doc;
      $doc->manakai_is_html (1);
      $self->{can_restart} = 1;

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      PARSER: {
        $self->_parse_bytes_init;
        $self->_parse_bytes_start_parsing (no_body_data_yet => 1) or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          redo PARSER;
        };
      } # PARSER

      $self->{saved_states} = {Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, Token => $Token};
      return;
    } # parse_bytes_start

    ## The $args{start_parsing} flag should be set true if it has
    ## taken more than 500ms from the start of overall parsing
    ## process.
    sub parse_bytes_feed ($$) {
      my ($self, undef, %args) = @_;

      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($Attr, $CONTEXT, $Confident, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $Token) = @{$self->{saved_states}}{qw(Attr CONTEXT Confident EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};

      $self->{byte_buffer} .= $_[1];
      $self->{byte_buffer_orig} .= $_[1];
      PARSER: {
        if ($self->{parse_bytes_started}) {
          my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding
          if (length $self->{byte_buffer} and 0 == length $input->[0]) {
            substr ($self->{byte_buffer}, 0, 1) = '';
            $input->[0] .= "\x{FFFD}" . decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET; # XXX Encoding Standard
          }

          $self->_feed_chars ($input) or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        } else {
          if ($args{start_parsing} or 1024 <= length $self->{byte_buffer}) {
            $self->_parse_bytes_start_parsing or do {
              $self->{byte_buffer} = $self->{byte_buffer_orig};
              $self->_parse_bytes_init;
              redo PARSER;
            };
          }
        }
      } # PARSER

      $self->{saved_states} = {Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, Token => $Token};
      return;
    } # parse_bytes_feed

    sub parse_bytes_end ($) {
      my $self = $_[0];
      local ($AFE, $Attr, $CONTEXT, $Callbacks, $Confident, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($Attr, $CONTEXT, $Confident, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $Token) = @{$self->{saved_states}}{qw(Attr CONTEXT Confident EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};

      PARSER: {
        unless ($self->{parse_bytes_started}) {
          $self->_parse_bytes_start_parsing or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        }

        if (length $self->{byte_buffer}) {
          my $input = [decode $self->{input_encoding}, $self->{byte_buffer}]; # XXX encoding
          $self->_feed_chars ($input) or do {
            $self->{byte_buffer} = $self->{byte_buffer_orig};
            $self->_parse_bytes_init;
            redo PARSER;
          };
        }

        $self->_feed_eof or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          $self->_parse_bytes_init;
          redo PARSER;
        };
      } # PARSER
      
      $self->_cleanup_states;
      return;
    } # parse_bytes_end
  

    1;

=head1 LICENSE

Copyright 2007-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

  