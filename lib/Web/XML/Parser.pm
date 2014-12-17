
    package Web::XML::Parser;
    use strict;
    use warnings;
    no warnings 'utf8';
    use warnings FATAL => 'recursion';
    use warnings FATAL => 'redefine';
    use warnings FATAL => 'uninitialized';
    use utf8;
    our $VERSION = '7.0';
    use Carp qw(croak);
    
    use Encode qw(decode); # XXX
    use Web::Encoding;
    use Web::HTML::ParserData;

    
        sub HTMLNS () { q<http://www.w3.org/1999/xhtml> }
      
    my $TagName2Group = {};

    ## ------ Common handlers ------

    sub new ($) {
      return bless {
        ## Input parameters
        # Scripting IframeSrcdoc DI known_definite_encoding locale_tag

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
  my $level = {
    m => 'Parse error',
    s => 'SHOULD-level error',
    w => 'Warning',
  }->{$error->{level} || ''} || $error->{level};
  warn "$level ($error->{type}$text) at index $index$value\n";
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
    our $AFE;our $AllDeclsProcessed;our $AnchoredIndex;our $Attr;our $CONTEXT;our $Callbacks;our $Confident;our $DI;our $DTDDefs;our $DTDMode;our $EOF;our $Errors;our $FORM_ELEMENT;our $FRAMESET_OK;our $HEAD_ELEMENT;our $IM;our $IframeSrcdoc;our $InForeign;our $Input;our $LastStartTagName;our $NEXT_ID;our $OE;our $OP;our $ORIGINAL_IM;our $Offset;our $OpenCMGroups;our $OpenMarkedSections;our $QUIRKS;our $Scripting;our $State;our $StopProcessing;our $TABLE_CHARS;our $TEMPLATE_IMS;our $Temp;our $TempIndex;our $Token;our $Tokens;our $XMLStandalone;
    ## ------ Tokenizer defs ------
    sub ATTLIST_TOKEN () { 1 }
sub DOCTYPE_TOKEN () { 2 }
sub ELEMENT_TOKEN () { 3 }
sub ENTITY_TOKEN () { 4 }
sub NOTATION_TOKEN () { 5 }
sub COMMENT_TOKEN () { 6 }
sub END_TAG_TOKEN () { 7 }
sub END_OF_DOCTYPE_TOKEN () { 8 }
sub END_OF_FILE_TOKEN () { 9 }
sub PROCESSING_INSTRUCTION_TOKEN () { 10 }
sub START_TAG_TOKEN () { 11 }
sub TEXT_TOKEN () { 12 }
sub ATTLIST_ATTR_DEFAULT_STATE () { 1 }
sub ATTLIST_ATTR_NAME_STATE () { 2 }
sub ATTLIST_ATTR_TYPE_STATE () { 3 }
sub ATTLIST_NAME_STATE () { 4 }
sub ATTLIST_STATE () { 5 }
sub CDATA_SECTION_STATE () { 6 }
sub CDATA_SECTION_STATE__5D () { 7 }
sub CDATA_SECTION_STATE__5D_5D () { 8 }
sub CDATA_SECTION_STATE_CR () { 9 }
sub DOCTYPE_MDO_STATE () { 10 }
sub DOCTYPE_MDO_STATE__ () { 11 }
sub DOCTYPE_MDO_STATE_A () { 12 }
sub DOCTYPE_MDO_STATE_AT () { 13 }
sub DOCTYPE_MDO_STATE_ATT () { 14 }
sub DOCTYPE_MDO_STATE_ATTL () { 15 }
sub DOCTYPE_MDO_STATE_ATTLI () { 16 }
sub DOCTYPE_MDO_STATE_ATTLIS () { 17 }
sub DOCTYPE_MDO_STATE_E () { 18 }
sub DOCTYPE_MDO_STATE_EL () { 19 }
sub DOCTYPE_MDO_STATE_ELE () { 20 }
sub DOCTYPE_MDO_STATE_ELEM () { 21 }
sub DOCTYPE_MDO_STATE_ELEME () { 22 }
sub DOCTYPE_MDO_STATE_ELEMEN () { 23 }
sub DOCTYPE_MDO_STATE_EN () { 24 }
sub DOCTYPE_MDO_STATE_ENT () { 25 }
sub DOCTYPE_MDO_STATE_ENTI () { 26 }
sub DOCTYPE_MDO_STATE_ENTIT () { 27 }
sub DOCTYPE_MDO_STATE_N () { 28 }
sub DOCTYPE_MDO_STATE_NO () { 29 }
sub DOCTYPE_MDO_STATE_NOT () { 30 }
sub DOCTYPE_MDO_STATE_NOTA () { 31 }
sub DOCTYPE_MDO_STATE_NOTAT () { 32 }
sub DOCTYPE_MDO_STATE_NOTATI () { 33 }
sub DOCTYPE_MDO_STATE_NOTATIO () { 34 }
sub DOCTYPE_NAME_STATE () { 35 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE () { 36 }
sub DOCTYPE_PUBLIC_ID__DQ__STATE_CR () { 37 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE () { 38 }
sub DOCTYPE_PUBLIC_ID__SQ__STATE_CR () { 39 }
sub DOCTYPE_STATE () { 40 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE () { 41 }
sub DOCTYPE_SYSTEM_ID__DQ__STATE_CR () { 42 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE () { 43 }
sub DOCTYPE_SYSTEM_ID__SQ__STATE_CR () { 44 }
sub DOCTYPE_TAG_STATE () { 45 }
sub DTD_STATE () { 46 }
sub ELEMENT_CONTENT_KEYWORD_STATE () { 47 }
sub ELEMENT_NAME_STATE () { 48 }
sub ELEMENT_STATE () { 49 }
sub ENTITY_NAME_STATE () { 50 }
sub ENTITY_PUBLIC_ID__DQ__STATE () { 51 }
sub ENTITY_PUBLIC_ID__DQ__STATE_CR () { 52 }
sub ENTITY_PUBLIC_ID__SQ__STATE () { 53 }
sub ENTITY_PUBLIC_ID__SQ__STATE_CR () { 54 }
sub ENTITY_STATE () { 55 }
sub ENTITY_SYSTEM_ID__DQ__STATE () { 56 }
sub ENTITY_SYSTEM_ID__DQ__STATE_CR () { 57 }
sub ENTITY_SYSTEM_ID__SQ__STATE () { 58 }
sub ENTITY_SYSTEM_ID__SQ__STATE_CR () { 59 }
sub ENTITY_VALUE__DQ__STATE () { 60 }
sub ENTITY_VALUE__DQ__STATE_CR () { 61 }
sub ENTITY_VALUE__SQ__STATE () { 62 }
sub ENTITY_VALUE__SQ__STATE_CR () { 63 }
sub ENTITY_VALUE_CHARREF_STATE () { 64 }
sub NDATA_ID_STATE () { 65 }
sub NOTATION_NAME_STATE () { 66 }
sub NOTATION_PUBLIC_ID__DQ__STATE () { 67 }
sub NOTATION_PUBLIC_ID__DQ__STATE_CR () { 68 }
sub NOTATION_PUBLIC_ID__SQ__STATE () { 69 }
sub NOTATION_PUBLIC_ID__SQ__STATE_CR () { 70 }
sub NOTATION_STATE () { 71 }
sub NOTATION_SYSTEM_ID__DQ__STATE () { 72 }
sub NOTATION_SYSTEM_ID__DQ__STATE_CR () { 73 }
sub NOTATION_SYSTEM_ID__SQ__STATE () { 74 }
sub NOTATION_SYSTEM_ID__SQ__STATE_CR () { 75 }
sub PI_DATA_STATE () { 76 }
sub PI_DATA_STATE_CR () { 77 }
sub PI_STATE () { 78 }
sub PI_TARGET_QUESTION_STATE () { 79 }
sub PI_TARGET_STATE () { 80 }
sub AFTER_ATTLIST_ATTR_DEFAULT_STATE () { 81 }
sub AFTER_ATTLIST_ATTR_NAME_STATE () { 82 }
sub AFTER_ATTLIST_ATTR_TYPE_STATE () { 83 }
sub AFTER_DOCTYPE_INTERNAL_SUBSET_STATE () { 84 }
sub AFTER_DOCTYPE_NAME_STATE () { 85 }
sub AFTER_DOCTYPE_NAME_STATE_P () { 86 }
sub AFTER_DOCTYPE_NAME_STATE_PU () { 87 }
sub AFTER_DOCTYPE_NAME_STATE_PUB () { 88 }
sub AFTER_DOCTYPE_NAME_STATE_PUBL () { 89 }
sub AFTER_DOCTYPE_NAME_STATE_PUBLI () { 90 }
sub AFTER_DOCTYPE_NAME_STATE_S () { 91 }
sub AFTER_DOCTYPE_NAME_STATE_SY () { 92 }
sub AFTER_DOCTYPE_NAME_STATE_SYS () { 93 }
sub AFTER_DOCTYPE_NAME_STATE_SYST () { 94 }
sub AFTER_DOCTYPE_NAME_STATE_SYSTE () { 95 }
sub AFTER_DOCTYPE_PUBLIC_ID_STATE () { 96 }
sub AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE () { 97 }
sub AFTER_DOCTYPE_SYSTEM_ID_STATE () { 98 }
sub AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE () { 99 }
sub AFTER_DTD_MSC_STATE () { 100 }
sub AFTER_ELEMENT_CONTENT_STATE () { 101 }
sub AFTER_ENTITY_NAME_STATE () { 102 }
sub AFTER_ENTITY_NAME_STATE_P () { 103 }
sub AFTER_ENTITY_NAME_STATE_PU () { 104 }
sub AFTER_ENTITY_NAME_STATE_PUB () { 105 }
sub AFTER_ENTITY_NAME_STATE_PUBL () { 106 }
sub AFTER_ENTITY_NAME_STATE_PUBLI () { 107 }
sub AFTER_ENTITY_NAME_STATE_S () { 108 }
sub AFTER_ENTITY_NAME_STATE_SY () { 109 }
sub AFTER_ENTITY_NAME_STATE_SYS () { 110 }
sub AFTER_ENTITY_NAME_STATE_SYST () { 111 }
sub AFTER_ENTITY_NAME_STATE_SYSTE () { 112 }
sub AFTER_ENTITY_PARAMETER_STATE () { 113 }
sub AFTER_ENTITY_PUBLIC_ID_STATE () { 114 }
sub AFTER_ENTITY_PUBLIC_KEYWORD_STATE () { 115 }
sub AFTER_ENTITY_SYSTEM_ID_STATE () { 116 }
sub AFTER_ENTITY_SYSTEM_KEYWORD_STATE () { 117 }
sub AFTER_IGNORE_KEYWORD_STATE () { 118 }
sub AFTER_INCLUDE_KEYWORD_STATE () { 119 }
sub AFTER_NDATA_KEYWORD_STATE () { 120 }
sub AFTER_NOTATION_NAME_STATE () { 121 }
sub AFTER_NOTATION_NAME_STATE_P () { 122 }
sub AFTER_NOTATION_NAME_STATE_PU () { 123 }
sub AFTER_NOTATION_NAME_STATE_PUB () { 124 }
sub AFTER_NOTATION_NAME_STATE_PUBL () { 125 }
sub AFTER_NOTATION_NAME_STATE_PUBLI () { 126 }
sub AFTER_NOTATION_NAME_STATE_S () { 127 }
sub AFTER_NOTATION_NAME_STATE_SY () { 128 }
sub AFTER_NOTATION_NAME_STATE_SYS () { 129 }
sub AFTER_NOTATION_NAME_STATE_SYST () { 130 }
sub AFTER_NOTATION_NAME_STATE_SYSTE () { 131 }
sub AFTER_NOTATION_PUBLIC_ID_STATE () { 132 }
sub AFTER_NOTATION_PUBLIC_KEYWORD_STATE () { 133 }
sub AFTER_NOTATION_SYSTEM_ID_STATE () { 134 }
sub AFTER_NOTATION_SYSTEM_KEYWORD_STATE () { 135 }
sub AFTER_PI_TARGET_STATE () { 136 }
sub AFTER_PI_TARGET_STATE_CR () { 137 }
sub AFTER_AFTER_ALLOWED_TOKEN_LIST_STATE () { 138 }
sub AFTER_ALLOWED_TOKEN_LIST_STATE () { 139 }
sub AFTER_ALLOWED_TOKEN_STATE () { 140 }
sub AFTER_ATTR_NAME_STATE () { 141 }
sub AFTER_ATTR_VALUE__QUOTED__STATE () { 142 }
sub AFTER_CONTENT_MODEL_GROUP_STATE () { 143 }
sub AFTER_CONTENT_MODEL_ITEM_STATE () { 144 }
sub AFTER_IGNORED_SECTION_MSC_STATE () { 145 }
sub AFTER_MSC_STATE () { 146 }
sub AFTER_MSS_STATE () { 147 }
sub AFTER_MSS_STATE_I () { 148 }
sub AFTER_MSS_STATE_IG () { 149 }
sub AFTER_MSS_STATE_IGN () { 150 }
sub AFTER_MSS_STATE_IGNO () { 151 }
sub AFTER_MSS_STATE_IGNOR () { 152 }
sub AFTER_MSS_STATE_IN () { 153 }
sub AFTER_MSS_STATE_INC () { 154 }
sub AFTER_MSS_STATE_INCL () { 155 }
sub AFTER_MSS_STATE_INCLU () { 156 }
sub AFTER_MSS_STATE_INCLUD () { 157 }
sub ALLOWED_TOKEN_STATE () { 158 }
sub ATTR_NAME_STATE () { 159 }
sub ATTR_VALUE__DQ__STATE () { 160 }
sub ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 161 }
sub ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 162 }
sub ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE () { 163 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE () { 164 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE () { 165 }
sub ATTR_VALUE__DQ__STATE___CHARREF_STATE () { 166 }
sub ATTR_VALUE__DQ__STATE_CR () { 167 }
sub ATTR_VALUE__SQ__STATE () { 168 }
sub ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 169 }
sub ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 170 }
sub ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE () { 171 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE () { 172 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE () { 173 }
sub ATTR_VALUE__SQ__STATE___CHARREF_STATE () { 174 }
sub ATTR_VALUE__SQ__STATE_CR () { 175 }
sub ATTR_VALUE__UNQUOTED__STATE () { 176 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 177 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 178 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE () { 179 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE () { 180 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE () { 181 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE () { 182 }
sub ATTR_VALUE__UNQUOTED__STATE_CR () { 183 }
sub BEFORE_ATTLIST_ATTR_DEFAULT_STATE () { 184 }
sub BEFORE_ATTLIST_ATTR_NAME_STATE () { 185 }
sub BEFORE_ATTLIST_NAME_STATE () { 186 }
sub BEFORE_DOCTYPE_NAME_STATE () { 187 }
sub BEFORE_DOCTYPE_PUBLIC_ID_STATE () { 188 }
sub BEFORE_DOCTYPE_SYSTEM_ID_STATE () { 189 }
sub BEFORE_ELEMENT_CONTENT_STATE () { 190 }
sub BEFORE_ELEMENT_NAME_STATE () { 191 }
sub BEFORE_ENTITY_NAME_STATE () { 192 }
sub BEFORE_ENTITY_PUBLIC_ID_STATE () { 193 }
sub BEFORE_ENTITY_SYSTEM_ID_STATE () { 194 }
sub BEFORE_ENTITY_TYPE_STATE () { 195 }
sub BEFORE_NDATA_ID_STATE () { 196 }
sub BEFORE_NDATA_KEYWORD_STATE () { 197 }
sub BEFORE_NDATA_KEYWORD_STATE_N () { 198 }
sub BEFORE_NDATA_KEYWORD_STATE_ND () { 199 }
sub BEFORE_NDATA_KEYWORD_STATE_NDA () { 200 }
sub BEFORE_NDATA_KEYWORD_STATE_NDAT () { 201 }
sub BEFORE_NOTATION_NAME_STATE () { 202 }
sub BEFORE_NOTATION_PUBLIC_ID_STATE () { 203 }
sub BEFORE_NOTATION_SYSTEM_ID_STATE () { 204 }
sub BEFORE_ALLOWED_TOKEN_STATE () { 205 }
sub BEFORE_ATTR_NAME_STATE () { 206 }
sub BEFORE_ATTR_VALUE_STATE () { 207 }
sub BEFORE_CONTENT_MODEL_ITEM_STATE () { 208 }
sub BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE () { 209 }
sub BETWEEN_ENTITY_PUBLIC_AND_SYSTEM_IDS_STATE () { 210 }
sub BETWEEN_NOTATION_PUBLIC_AND_SYSTEM_IDS_STATE () { 211 }
sub BOGUS_DOCTYPE_STATE () { 212 }
sub BOGUS_AFTER_DOCTYPE_INTERNAL_SUBSET_STATE () { 213 }
sub BOGUS_COMMENT_STATE () { 214 }
sub BOGUS_COMMENT_STATE_CR () { 215 }
sub BOGUS_MARKUP_DECLARATION_STATE () { 216 }
sub CHARREF_IN_DATA_STATE () { 217 }
sub COMMENT_END_BANG_STATE () { 218 }
sub COMMENT_END_DASH_STATE () { 219 }
sub COMMENT_END_STATE () { 220 }
sub COMMENT_START_DASH_STATE () { 221 }
sub COMMENT_START_STATE () { 222 }
sub COMMENT_STATE () { 223 }
sub COMMENT_STATE_CR () { 224 }
sub CONTENT_MODEL_ELEMENT_STATE () { 225 }
sub DATA_STATE () { 226 }
sub DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 227 }
sub DATA_STATE___CHARREF_DECIMAL_NUMBER_STATE () { 228 }
sub DATA_STATE___CHARREF_HEX_NUMBER_STATE () { 229 }
sub DATA_STATE___CHARREF_NAME_STATE () { 230 }
sub DATA_STATE___CHARREF_NUMBER_STATE () { 231 }
sub DATA_STATE___CHARREF_STATE () { 232 }
sub DATA_STATE___CHARREF_STATE_CR () { 233 }
sub DATA_STATE_CR () { 234 }
sub DEFAULT_ATTR_VALUE__DQ__STATE () { 235 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 236 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 237 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE () { 238 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE () { 239 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE () { 240 }
sub DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE () { 241 }
sub DEFAULT_ATTR_VALUE__DQ__STATE_CR () { 242 }
sub DEFAULT_ATTR_VALUE__SQ__STATE () { 243 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 244 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 245 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE () { 246 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE () { 247 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE () { 248 }
sub DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE () { 249 }
sub DEFAULT_ATTR_VALUE__SQ__STATE_CR () { 250 }
sub END_TAG_OPEN_STATE () { 251 }
sub IGNORED_SECTION_STATE () { 252 }
sub IN_DTD_MSC_STATE () { 253 }
sub IN_IGNORED_SECTION_MSC_STATE () { 254 }
sub IN_MSC_STATE () { 255 }
sub IN_PIC_STATE () { 256 }
sub MDO_STATE () { 257 }
sub MDO_STATE__ () { 258 }
sub MDO_STATE_D () { 259 }
sub MDO_STATE_DO () { 260 }
sub MDO_STATE_DOC () { 261 }
sub MDO_STATE_DOCT () { 262 }
sub MDO_STATE_DOCTY () { 263 }
sub MDO_STATE_DOCTYP () { 264 }
sub MDO_STATE__5B () { 265 }
sub MDO_STATE__5BC () { 266 }
sub MDO_STATE__5BCD () { 267 }
sub MDO_STATE__5BCDA () { 268 }
sub MDO_STATE__5BCDAT () { 269 }
sub MDO_STATE__5BCDATA () { 270 }
sub PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_AFTER_SPACE_STATE () { 271 }
sub PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_STATE () { 272 }
sub PARAMETER_ENTITY_NAME_IN_DTD_STATE () { 273 }
sub PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE () { 274 }
sub PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE () { 275 }
sub SELF_CLOSING_START_TAG_STATE () { 276 }
sub TAG_NAME_STATE () { 277 }
sub TAG_OPEN_STATE () { 278 }

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
  


sub _tokenize_attr_value ($) {
  my $token = $_[0];
  return 0 unless $token->{value} =~ / /;
  my @value;
  my @pos;
  my $old_pos = 0;
  my $new_pos = 0;
  my @v = grep { length } split /( +)/, $token->{value}, -1;
  for (@v) {
    unless (/ /) {
      push @value, $_;
      push @pos, [$old_pos, $new_pos, 1 + length $_];
      $new_pos += 1 + length $_;
    }
    $old_pos += length $_;
  }
  pop @value, pop @pos if @value and $value[-1] eq '';
  shift @value, shift @pos if @value and $value[-1] eq '';
  $pos[-1]->[2]-- if @pos;

  my $old_value = $token->{value};
  $token->{value} = join ' ', @value;
} # _tokenize_attr_value

  
    ## ------ Tree constructor defs ------
    my $Element2Type = {};
my $ProcessIM = [];
sub TAG_NAME_BUTTON_FIELDSET_IMG_INPUT_KEYGEN_LABEL_OBJECT_OUTPUT_SELECT_TEXTAREA () { 1 }
$TagName2Group->{q@button@} = 1;
$TagName2Group->{q@fieldset@} = 1;
$TagName2Group->{q@img@} = 1;
$TagName2Group->{q@input@} = 1;
$TagName2Group->{q@keygen@} = 1;
$TagName2Group->{q@label@} = 1;
$TagName2Group->{q@object@} = 1;
$TagName2Group->{q@output@} = 1;
$TagName2Group->{q@select@} = 1;
$TagName2Group->{q@textarea@} = 1;

        ## HTML:*
        sub HTML_NS_ELS () { 1 }
      

        ## HTML:applet,HTML:audio,HTML:style,HTML:video
        sub APP_AUD_STY_VID_ELS () { 2 }
      

        ## HTML:button,HTML:fieldset,HTML:input,HTML:keygen,HTML:label,HTML:output,HTML:select,HTML:textarea
        sub BFIKLOST_ELS () { 4 }
      

        ## HTML:img
        sub IMG_ELS () { 8 }
      

        ## HTML:object
        sub OBJ_ELS () { 16 }
      
$Element2Type->{(HTMLNS)}->{q@*@} = HTML_NS_ELS;
$Element2Type->{(HTMLNS)}->{q@applet@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
$Element2Type->{(HTMLNS)}->{q@audio@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
$Element2Type->{(HTMLNS)}->{q@button@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->{(HTMLNS)}->{q@fieldset@} = HTML_NS_ELS | BFIKLOST_ELS;
sub HEAD_EL () { HTML_NS_ELS | 32 } $Element2Type->{(HTMLNS)}->{q@head@} = HEAD_EL;
sub HTML_EL () { HTML_NS_ELS | 64 } $Element2Type->{(HTMLNS)}->{q@html@} = HTML_EL;
$Element2Type->{(HTMLNS)}->{q@img@} = HTML_NS_ELS | IMG_ELS;
$Element2Type->{(HTMLNS)}->{q@input@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->{(HTMLNS)}->{q@keygen@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->{(HTMLNS)}->{q@label@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->{(HTMLNS)}->{q@object@} = HTML_NS_ELS | OBJ_ELS;
$Element2Type->{(HTMLNS)}->{q@output@} = HTML_NS_ELS | BFIKLOST_ELS;
sub SELECT_EL () { HTML_NS_ELS | BFIKLOST_ELS } $Element2Type->{(HTMLNS)}->{q@select@} = SELECT_EL;
$Element2Type->{(HTMLNS)}->{q@style@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
sub TABLE_EL () { HTML_NS_ELS | 96 } $Element2Type->{(HTMLNS)}->{q@table@} = TABLE_EL;
sub TEMPLATE_EL () { HTML_NS_ELS | 128 } $Element2Type->{(HTMLNS)}->{q@template@} = TEMPLATE_EL;
$Element2Type->{(HTMLNS)}->{q@textarea@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->{(HTMLNS)}->{q@video@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
sub AFTER_ROOT_ELEMENT_IM () { 1 }
sub BEFORE_DOCTYPE_IM () { 2 }
sub BEFORE_IGNORED_NEWLINE_IM () { 3 }
sub BEFORE_ROOT_ELEMENT_IM () { 4 }
sub IN_ELEMENT_IM () { 5 }
sub IN_SUBSET_IM () { 6 }
sub IN_SUBSET_AFTER_ROOT_ELEMENT_IM () { 7 }
sub IN_SUBSET_BEFORE_ROOT_ELEMENT_IM () { 8 }
sub IN_SUBSET_IN_ELEMENT_IM () { 9 }
sub INITIAL_IM () { 10 }

      my $TCA = [undef,
        ## [1] after root element;ATTLIST
        sub {
          
        },
      ,
        ## [2] after root element;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token => 0];
          
        },
      ,
        ## [3] after root element;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-root-element-doctype',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};

          if ($token->{has_internal_subset_flag}) {
            $StopProcessing = 1;

          $IM = IN_SUBSET_AFTER_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |in subset after root element| ($IM)";
        
          }
        
        },
      ,
        ## [4] after root element;ELEMENT
        sub {
          
        },
      ,
        ## [5] after root element;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-root-element-end-else',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
return;
        },
      ,
        ## [6] after root element;ENTITY
        sub {
          
        },
      ,
        ## [7] after root element;EOD
        sub {
          
        },
      ,
        ## [8] after root element;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [9] after root element;NOTATION
        sub {
          
        },
      ,
        ## [10] after root element;PI
        sub {
          my $token = $_;

            push @$OP, ['pi', $token => 0];
          
        },
      ,
        ## [11] after root element;START-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-root-element-start-else',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
return;
        },
      ,
        ## [12] after root element;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
          $token->{index} += length $1;
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'after-root-element-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
        }
      
        },
      ,
        ## [13] before DOCTYPE;ATTLIST
        sub {
          
        },
      ,
        ## [14] before DOCTYPE;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token => 0];
          
        },
      ,
        ## [15] before DOCTYPE;DOCTYPE
        sub {
          my $token = $_;

        push @$OP, ['doctype', $token => 0];

        if (not length $token->{system_identifier}) {
          push @$OP, ['construct-doctype'];
        }
      
$DTDDefs->{system_id} = $token->{system_identifier};

          if ($token->{has_internal_subset_flag}) {
            
          $IM = IN_SUBSET_IM;
          #warn "Insertion mode changed to |in subset| ($IM)";
        
          } else {
            
          if (length $DTDDefs->{system_id}) {
            
        warn "XXX external subset not implemented yet";
        push @$OP, ['construct-doctype'];
      
          } else {
            
          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        
          }
        
          }
        
        },
      ,
        ## [16] before DOCTYPE;ELEMENT
        sub {
          
        },
      ,
        ## [17] before DOCTYPE;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-doctype-end-else',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
return;
        },
      ,
        ## [18] before DOCTYPE;ENTITY
        sub {
          
        },
      ,
        ## [19] before DOCTYPE;EOD
        sub {
          
        },
      ,
        ## [20] before DOCTYPE;EOF
        sub {
          my $token = $_;

          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [21] before DOCTYPE;NOTATION
        sub {
          
        },
      ,
        ## [22] before DOCTYPE;PI
        sub {
          my $token = $_;

            push @$OP, ['pi', $token => 0];
          
        },
      ,
        ## [23] before DOCTYPE;START-ELSE
        sub {
          my $token = $_;

          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [24] before DOCTYPE;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
          $token->{index} += length $1;
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'before-doctype-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
        }
      
        },
      ,
        ## [25] before ignored newline;ELSE
        sub {
          
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[$_->{tn}]};
  
        },
      ,
        ## [26] before ignored newline;TEXT
        sub {
          
    $_->{index}++ if $_->{value} =~ s/^\x0A//;
    $IM = $ORIGINAL_IM;
    goto &{$ProcessIM->[$IM]->[$_->{type}]->[0]} if length $_->{value};
  
        },
      ,
        ## [27] before root element;ATTLIST
        sub {
          
        },
      ,
        ## [28] before root element;COMMENT
        sub {
          my $token = $_;

            push @$OP, ['comment', $token => 0];
          
        },
      ,
        ## [29] before root element;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-root-element-doctype',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};

          if ($token->{has_internal_subset_flag}) {
            $StopProcessing = 1;

          $IM = IN_SUBSET_BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |in subset before root element| ($IM)";
        
          }
        
        },
      ,
        ## [30] before root element;ELEMENT
        sub {
          
        },
      ,
        ## [31] before root element;END-ELSE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-root-element-end-else',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
return;
        },
      ,
        ## [32] before root element;ENTITY
        sub {
          
        },
      ,
        ## [33] before root element;EOD
        sub {
          
        },
      ,
        ## [34] before root element;EOF
        sub {
          my $token = $_;
push @$Errors, {type => 'before-root-element-eof',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
push @$OP, ['stop-parsing'];
        },
      ,
        ## [35] before root element;NOTATION
        sub {
          
        },
      ,
        ## [36] before root element;PI
        sub {
          my $token = $_;

            push @$OP, ['pi', $token => 0];
          
        },
      ,
        ## [37] before root element;START-ELSE
        sub {
          my $token = $_;

        my $nsmap = @$OE ? {%{$OE->[-1]->{nsmap}}} : {
          xml => q<http://www.w3.org/XML/1998/namespace>,
          xmlns => q<http://www.w3.org/2000/xmlns/>,
        };

        my $attrs = $token->{attrs};
        my $attrdefs = $DTDDefs->{attrdefs}->{$token->{tag_name}};
        for my $def (@{$attrdefs or []}) {
          my $attr_name = $def->{name};
          if (defined $attrs->{$attr_name}) {
            $attrs->{$attr_name}->{declared_type} = $def->{declared_type} || 0;
            if ($def->{tokenize}) {
              if (_tokenize_attr_value $attrs->{$attr_name} and
                  $def->{external} and
                  not $def->{external}->{vc_error_reported} and
                  $XMLStandalone) {
                push @$Errors, {level => 'm',
                                type => 'VC:Standalone Document Declaration:attr',
                                di => $def->{di}, index => $def->{index},
                                value => $attr_name};
                $def->{external}->{vc_error_reported} = 1;
              }
            }
          } elsif (defined $def->{value}) {
            push @{$token->{attr_list}},
            $attrs->{$attr_name} = {
              name => $attr_name,
              value => $def->{value},
              declared_type => $def->{declared_type} || 0,
              not_specified => 1,
              di => $def->{di}, index => $def->{index},
            };

            if ($def->{external} and
                not $def->{external}->{vc_error_reported} and
                $XMLStandalone) {
              push @$Errors, {level => 'm',
                              type => 'VC:Standalone Document Declaration:attr',
                                di => $def->{di}, index => $def->{index},
                                value => $attr_name};
              $def->{external}->{vc_error_reported} = 1;
            }
          }
        }
        
        for (keys %$attrs) {
          if (/^xmlns:./s) {
            my $prefix = substr $_, 6;
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
            if ($prefix eq 'xml' or $prefix eq 'xmlns' or
                $value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{$prefix} = $value;
            } else {
              delete $nsmap->{$prefix};
            }
          } elsif ($_ eq 'xmlns') {
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
            if ($value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{''} = $value;
            } else {
              delete $nsmap->{''};
            }
          }
        }
        
        my $ns;
        my ($prefix, $ln) = split /:/, $token->{tag_name}, 2;
        
        if (defined $ln and $prefix ne '' and $ln ne '') { # prefixed
          if (defined $nsmap->{$prefix}) {
            $ns = $nsmap->{$prefix};
          } else {
            ## NOTE: Error should be detected at the DOM layer.
            ($prefix, $ln) = (undef, $token->{tag_name});
          }
        } else {
          $ns = $nsmap->{''} if $prefix ne '' and not defined $ln;
          ($prefix, $ln) = (undef, $token->{tag_name});
        }

        my $nse = defined $ns ? $ns : '';
        my $node = {
          id => $NEXT_ID++,
          token => $token,
          di => $token->{di}, index => $token->{index},
          nsmap => $nsmap,
          ns => $ns, prefix => $prefix, local_name => $ln,
          attr_list => $token->{attr_list},
          et => $Element2Type->{($nse)}->{$token->{tag_name}} || $Element2Type->{($nse)}->{'*'} || 0,
          aet => $Element2Type->{($nse)}->{$token->{tag_name}} || $Element2Type->{($nse)}->{'*'} || 0,
        };
        #XXX
        #$self->{el_ncnames}->{$prefix} ||= $self->{t} if defined $prefix;
        #$self->{el_ncnames}->{$ln} ||= $self->{t} if defined $ln;

        my $has_attr;
        for my $attr (@{$node->{attr_list}}) {
          my $ns;
          my ($p, $l) = split /:/, $attr->{name}, 2;

          if ($attr->{name} eq 'xmlns:xmlns') {
            ($p, $l) = (undef, $attr->{name});
          } elsif (defined $l and $p ne '' and $l ne '') { # prefixed
            if (defined $nsmap->{$p}) {
              $ns = $nsmap->{$p};
            } else {
              ## NOTE: Error should be detected at the DOM-layer.
              ($p, $l) = (undef, $attr->{name});
            }
          } else {
            if ($attr->{name} eq 'xmlns') {
              $ns = $nsmap->{xmlns};
            }
            ($p, $l) = (undef, $attr->{name});
          }
          
          if ($has_attr->{defined $ns ? $ns : ''}->{$l}) {
            $ns = undef;
            ($p, $l) = (undef, $attr->{name});
          } else {
            $has_attr->{defined $ns ? $ns : ''}->{$l} = 1;
          }

          $attr->{name_args} = [$ns, [$p, $l]];
          #XXX
          #$self->{el_ncnames}->{$p} ||= $attr_t if defined $p;
          #$self->{el_ncnames}->{$l} ||= $attr_t if defined $l;
          if (defined $attr->{declared_type}) {
            #
          } elsif ($AllDeclsProcessed) {
            $attr->{declared_type} = 0; # no value
          } else {
            $attr->{declared_type} = 11; # unknown
          }
        }
      
push @$OP, ['insert', $node => 0];
push @$OE, $node;
push @$OP, ['appcache'];

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];
delete $token->{self_closing_flag};

          $IM = AFTER_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |after root element| ($IM)";
        
          } else {
            
          $IM = IN_ELEMENT_IM;
          #warn "Insertion mode changed to |in element| ($IM)";
        
          }
        
        },
      ,
        ## [38] before root element;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
          $token->{index} += length $1;
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'before-root-element-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
        }
      
        },
      ,
        ## [39] in element;ATTLIST
        sub {
          
        },
      ,
        ## [40] in element;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token => $OE->[-1]->{id}];
        
        },
      ,
        ## [41] in element;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'in-element-doctype',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};

          if ($token->{has_internal_subset_flag}) {
            $StopProcessing = 1;

          $IM = IN_SUBSET_IN_ELEMENT_IM;
          #warn "Insertion mode changed to |in subset in element| ($IM)";
        
          }
        
        },
      ,
        ## [42] in element;ELEMENT
        sub {
          
        },
      ,
        ## [43] in element;END-ELSE
        sub {
          my $token = $_;
my $tag_name = length $token->{tag_name} ? $token->{tag_name} : $OE->[-1]->{token}->{tag_name};

          for my $i (reverse 0..$#$OE) {
            my $_node = $OE->[$i];
            
          if ((defined $CONTEXT) and 
($_node eq $OE->[0])) {
            push @$Errors, {type => 'in-element-end-else',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
return;
return;
          }
        

          if ($tag_name eq $_node->{token}->{tag_name}) {
            
          if (not ($OE->[-1] eq $_node)) {
            push @$Errors, {type => 'in-element-end-else-2',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
          }
        

          if ($_node eq $OE->[0]) {
            
          $IM = AFTER_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |after root element| ($IM)";
        
          }
        
{
          my @popped;
          push @popped, pop @$OE while not ($OE->[-1] eq $_node);
          push @popped, pop @$OE;
          push @$OP, ['popped', \@popped];
        }
return;
          }
        
          }
        
        },
      ,
        ## [44] in element;ENTITY
        sub {
          
        },
      ,
        ## [45] in element;EOD
        sub {
          
        },
      ,
        ## [46] in element;EOF
        sub {
          my $token = $_;

          if (defined $CONTEXT) {
            
          if (@$OE > 1) {
            push @$Errors, {type => 'in-element-eof',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
          }
        
push @$OP, ['stop-parsing'];
          } else {
            push @$Errors, {type => 'in-element-eof-2',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
push @$OP, ['stop-parsing'];
          }
        
        },
      ,
        ## [47] in element;NOTATION
        sub {
          
        },
      ,
        ## [48] in element;PI
        sub {
          my $token = $_;

          push @$OP, ['pi', $token => $OE->[-1]->{id}];
        
        },
      ,
        ## [49] in element;START-ELSE
        sub {
          my $token = $_;

        my $nsmap = @$OE ? {%{$OE->[-1]->{nsmap}}} : {
          xml => q<http://www.w3.org/XML/1998/namespace>,
          xmlns => q<http://www.w3.org/2000/xmlns/>,
        };

        my $attrs = $token->{attrs};
        my $attrdefs = $DTDDefs->{attrdefs}->{$token->{tag_name}};
        for my $def (@{$attrdefs or []}) {
          my $attr_name = $def->{name};
          if (defined $attrs->{$attr_name}) {
            $attrs->{$attr_name}->{declared_type} = $def->{declared_type} || 0;
            if ($def->{tokenize}) {
              if (_tokenize_attr_value $attrs->{$attr_name} and
                  $def->{external} and
                  not $def->{external}->{vc_error_reported} and
                  $XMLStandalone) {
                push @$Errors, {level => 'm',
                                type => 'VC:Standalone Document Declaration:attr',
                                di => $def->{di}, index => $def->{index},
                                value => $attr_name};
                $def->{external}->{vc_error_reported} = 1;
              }
            }
          } elsif (defined $def->{value}) {
            push @{$token->{attr_list}},
            $attrs->{$attr_name} = {
              name => $attr_name,
              value => $def->{value},
              declared_type => $def->{declared_type} || 0,
              not_specified => 1,
              di => $def->{di}, index => $def->{index},
            };

            if ($def->{external} and
                not $def->{external}->{vc_error_reported} and
                $XMLStandalone) {
              push @$Errors, {level => 'm',
                              type => 'VC:Standalone Document Declaration:attr',
                                di => $def->{di}, index => $def->{index},
                                value => $attr_name};
              $def->{external}->{vc_error_reported} = 1;
            }
          }
        }
        
        for (keys %$attrs) {
          if (/^xmlns:./s) {
            my $prefix = substr $_, 6;
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
            if ($prefix eq 'xml' or $prefix eq 'xmlns' or
                $value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{$prefix} = $value;
            } else {
              delete $nsmap->{$prefix};
            }
          } elsif ($_ eq 'xmlns') {
            my $value = join '', map { $_->[0] } @{$attrs->{$_}->{value}};
            if ($value eq q<http://www.w3.org/XML/1998/namespace> or
                $value eq q<http://www.w3.org/2000/xmlns/>) {
              ## NOTE: Error should be detected at the DOM layer.
              #
            } elsif (length $value) {
              $nsmap->{''} = $value;
            } else {
              delete $nsmap->{''};
            }
          }
        }
        
        my $ns;
        my ($prefix, $ln) = split /:/, $token->{tag_name}, 2;
        
        if (defined $ln and $prefix ne '' and $ln ne '') { # prefixed
          if (defined $nsmap->{$prefix}) {
            $ns = $nsmap->{$prefix};
          } else {
            ## NOTE: Error should be detected at the DOM layer.
            ($prefix, $ln) = (undef, $token->{tag_name});
          }
        } else {
          $ns = $nsmap->{''} if $prefix ne '' and not defined $ln;
          ($prefix, $ln) = (undef, $token->{tag_name});
        }

        my $nse = defined $ns ? $ns : '';
        my $node = {
          id => $NEXT_ID++,
          token => $token,
          di => $token->{di}, index => $token->{index},
          nsmap => $nsmap,
          ns => $ns, prefix => $prefix, local_name => $ln,
          attr_list => $token->{attr_list},
          et => $Element2Type->{($nse)}->{$token->{tag_name}} || $Element2Type->{($nse)}->{'*'} || 0,
          aet => $Element2Type->{($nse)}->{$token->{tag_name}} || $Element2Type->{($nse)}->{'*'} || 0,
        };
        #XXX
        #$self->{el_ncnames}->{$prefix} ||= $self->{t} if defined $prefix;
        #$self->{el_ncnames}->{$ln} ||= $self->{t} if defined $ln;

        my $has_attr;
        for my $attr (@{$node->{attr_list}}) {
          my $ns;
          my ($p, $l) = split /:/, $attr->{name}, 2;

          if ($attr->{name} eq 'xmlns:xmlns') {
            ($p, $l) = (undef, $attr->{name});
          } elsif (defined $l and $p ne '' and $l ne '') { # prefixed
            if (defined $nsmap->{$p}) {
              $ns = $nsmap->{$p};
            } else {
              ## NOTE: Error should be detected at the DOM-layer.
              ($p, $l) = (undef, $attr->{name});
            }
          } else {
            if ($attr->{name} eq 'xmlns') {
              $ns = $nsmap->{xmlns};
            }
            ($p, $l) = (undef, $attr->{name});
          }
          
          if ($has_attr->{defined $ns ? $ns : ''}->{$l}) {
            $ns = undef;
            ($p, $l) = (undef, $attr->{name});
          } else {
            $has_attr->{defined $ns ? $ns : ''}->{$l} = 1;
          }

          $attr->{name_args} = [$ns, [$p, $l]];
          #XXX
          #$self->{el_ncnames}->{$p} ||= $attr_t if defined $p;
          #$self->{el_ncnames}->{$l} ||= $attr_t if defined $l;
          if (defined $attr->{declared_type}) {
            #
          } elsif ($AllDeclsProcessed) {
            $attr->{declared_type} = 0; # no value
          } else {
            $attr->{declared_type} = 11; # unknown
          }
        }
      
push @$OP, ['insert', $node => $OE->[-1]->{id}];
push @$OE, $node;

          if ($token->{self_closing_flag}) {
            push @$OP, ['popped', [pop @$OE]];
delete $token->{self_closing_flag};
          }
        
        },
      ,
        ## [50] in element;TEXT
        sub {
          my $token = $_;

          while (length $token->{value}) {
            if ($token->{value} =~ s/^([^\x00]+)//) {
              
      push @$OP, ['text', [[$1, $token->{di}, $token->{index}]] => $OE->[-1]->{id}];
    
              $token->{index} += length $1;
            }
            if ($token->{value} =~ s/^([\x00]+)//) {
              
            my $value = $1;
            while ($value =~ /(.)/gs) {
              push @$Errors, {type => 'in-element-null',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index} + $-[1]};
            }
            
          
              $token->{index} += length $1;
            }
          }
        
        },
      ,
        ## [51] in subset after root element;ATTLIST
        sub {
          return;
        },
      ,
        ## [52] in subset after root element;COMMENT
        sub {
          return;
        },
      ,
        ## [53] in subset after root element;DOCTYPE
        sub {
          return;
        },
      ,
        ## [54] in subset after root element;ELEMENT
        sub {
          return;
        },
      ,
        ## [55] in subset after root element;END-ELSE
        sub {
          return;
        },
      ,
        ## [56] in subset after root element;ENTITY
        sub {
          return;
        },
      ,
        ## [57] in subset after root element;EOD
        sub {
          
          $IM = AFTER_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |after root element| ($IM)";
        
        },
      ,
        ## [58] in subset after root element;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [59] in subset after root element;NOTATION
        sub {
          return;
        },
      ,
        ## [60] in subset after root element;PI
        sub {
          return;
        },
      ,
        ## [61] in subset after root element;START-ELSE
        sub {
          my $token = $_;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
return;
        },
      ,
        ## [62] in subset after root element;TEXT
        sub {
          
        },
      ,
        ## [63] in subset before root element;ATTLIST
        sub {
          return;
        },
      ,
        ## [64] in subset before root element;COMMENT
        sub {
          return;
        },
      ,
        ## [65] in subset before root element;DOCTYPE
        sub {
          return;
        },
      ,
        ## [66] in subset before root element;ELEMENT
        sub {
          return;
        },
      ,
        ## [67] in subset before root element;END-ELSE
        sub {
          return;
        },
      ,
        ## [68] in subset before root element;ENTITY
        sub {
          return;
        },
      ,
        ## [69] in subset before root element;EOD
        sub {
          
          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        
        },
      ,
        ## [70] in subset before root element;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [71] in subset before root element;NOTATION
        sub {
          return;
        },
      ,
        ## [72] in subset before root element;PI
        sub {
          return;
        },
      ,
        ## [73] in subset before root element;START-ELSE
        sub {
          my $token = $_;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
return;
        },
      ,
        ## [74] in subset before root element;TEXT
        sub {
          
        },
      ,
        ## [75] in subset in element;ATTLIST
        sub {
          return;
        },
      ,
        ## [76] in subset in element;COMMENT
        sub {
          return;
        },
      ,
        ## [77] in subset in element;DOCTYPE
        sub {
          return;
        },
      ,
        ## [78] in subset in element;ELEMENT
        sub {
          return;
        },
      ,
        ## [79] in subset in element;END-ELSE
        sub {
          return;
        },
      ,
        ## [80] in subset in element;ENTITY
        sub {
          return;
        },
      ,
        ## [81] in subset in element;EOD
        sub {
          
          $IM = IN_ELEMENT_IM;
          #warn "Insertion mode changed to |in element| ($IM)";
        
        },
      ,
        ## [82] in subset in element;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [83] in subset in element;NOTATION
        sub {
          return;
        },
      ,
        ## [84] in subset in element;PI
        sub {
          return;
        },
      ,
        ## [85] in subset in element;START-ELSE
        sub {
          my $token = $_;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
return;
        },
      ,
        ## [86] in subset in element;TEXT
        sub {
          
        },
      ,
        ## [87] in subset;ATTLIST
        sub {
          my $token = $_;

        #XXX$self->_sc->check_hidden_name
        #    (name => $self->{t}->{name},
        #     onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        if ($StopProcessing) {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:attlist ignored',
                          di => $DI, index => $Offset + pos $Input};
        } else { # not $StopProcessing
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:ext decl',
                          di => $DI, index => $Offset + pos $Input}
              unless $DTDMode eq 'internal subset'; # not in parameter entity

          if (not defined $DTDDefs->{elements}->{$token->{name}}) {
            $DTDDefs->{elements}->{$token->{name}}->{name} = $token->{name};
            $DTDDefs->{elements}->{$token->{name}}->{di} = $token->{di};
            $DTDDefs->{elements}->{$token->{name}}->{index} = $token->{index};
          } elsif ($DTDDefs->{elements}->{$token->{name}}->{has_attlist}) {
            push @$Errors, {level => 'w',
                            type => 'duplicate attlist decl', ## TODO: type
                            value => $token->{name},
                            di => $DI, index => $Offset + pos $Input};
          }
          $DTDDefs->{elements}->{$token->{name}}->{has_attlist} = 1;

          unless (@{$token->{attr_list} or []}) {
            push @$Errors, {level => 'w',
                            type => 'empty attlist decl', ## TODO: type
                            value => $token->{name},
                            di => $DI, index => $Offset + pos $Input};
          }
        } # not $StopProcessing
        
        for my $at (@{$token->{attr_list} or []}) {
          my $type = defined $at->{declared_type} ? {
            CDATA => 1, ID => 2, IDREF => 3, IDREFS => 4, ENTITY => 5,
            ENTITIES => 6, NMTOKEN => 7, NMTOKENS => 8, NOTATION => 9,
          }->{$at->{declared_type}} : 10;
          if (defined $type) {
            $at->{declared_type} = $type;
          } else {
            $at->{declared_type} = $type = 0;
            push @$Errors, {level => 'm',
                            type => 'unknown declared type', ## TODO: type
                            value => $at->{declared_type},
                            di => $DI, index => $Offset + pos $Input};
          }
          
          my $default = defined $at->{default_type} ? {
            FIXED => 1, REQUIRED => 2, IMPLIED => 3,
          }->{$at->{default_type}} : 4;
          if (defined $default) {
            $at->{default_type} = $default;
            if (defined $at->{value}) { # XXX IndexedString
              if ($default == 1 or $default == 4) {
                #
              } elsif (length $at->{value}) {
                push @$Errors, {level => 'm',
                                type => 'default value not allowed',
                                di => $DI, index => $Offset + pos $Input};
              }
            } else {
              if ($default == 1 or $default == 4) {
                push @$Errors, {level => 'm',
                                type => 'default value not provided',
                                di => $DI, index => $Offset + pos $Input};
              }
            }
          } else {
            $at->{default_type} = 0;
            push @$Errors, {level => 'm',
                            type => 'unknown default type', ## TODO: type
                            value => $at->{default_type},
                            di => $DI, index => $Offset + pos $Input};
          }
          $at->{value} = ($at->{default_type} and ($at->{default_type} == 1 or $at->{default_type} == 4))
              ? defined $at->{value} ? $at->{value} : '' : undef;

          $at->{tokenize} = (2 <= $type and $type <= 10);

          if (defined $at->{value}) { # XXX IndexedString
            _tokenize_attr_value $at if $at->{tokenize};
          }

          if (not $StopProcessing) {
            if (not defined $DTDDefs->{attrdef_by_name}->{$token->{name}}->{$at->{name}}) {
              $DTDDefs->{attrdef_by_name}->{$token->{name}}->{$at->{name}} = $at;
              push @{$DTDDefs->{attrdefs}->{$token->{name}} ||= []}, $at;
              $at->{external} = {} unless $DTDMode eq 'internal subset'; # not in parameter entity
            } else {
              push @$Errors, {level => 'w',
                              type => 'duplicate attrdef', ## TODO: type
                              value => $at->{name},
                              di => $DI, index => $Offset + pos $Input};
              if ($at->{declared_type} == 10) { # ENUMERATION
                #XXXfor (@{$at->{tokens} or []}) {
                #  $self->_sc->check_hidden_nmtoken
                #      (name => $_, onerror => $onerror);
                #}
              } elsif ($at->{declared_type} == 9) { # NOTATION
                #XXXfor (@{$at->{tokens} or []}) {
                #  $self->_sc->check_hidden_name
                #      (name => $_, onerror => $onerror);
                #}
              }
            }
          } # not $StopProcessing
        } # attr_list
      
        },
      ,
        ## [88] in subset;COMMENT
        sub {
          return;
        },
      ,
        ## [89] in subset;DOCTYPE
        sub {
          
        },
      ,
        ## [90] in subset;ELEMENT
        sub {
          my $token = $_;

        unless ($DTDDefs->{elements}->{$token->{name}}->{has_element_decl}) {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:ext decl',
                          di => $DI, index => $Offset + pos $Input}
              unless $DTDMode eq 'internal subset'; # not in parameter entity
          #XXX$self->_sc->check_hidden_name
          #    (name => $self->{t}->{name},
          #    onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

          my $def = $DTDDefs->{elements}->{$token->{name}};
          for (qw(name di index content_keyword cmgroup)) {
            $def->{$_} = $token->{$_};
          }
        } else {
          push @$Errors, {level => 'm',
                          type => 'duplicate element decl', ## TODO: type
                          value => $token->{name},
                          di => $DI, index => $Offset + pos $Input};
          $DTDDefs->{elements}->{$token->{name}}->{has_element_decl} = 1;
        }
        ## TODO: $self->{t}->{content} syntax check.
      
        },
      ,
        ## [91] in subset;END-ELSE
        sub {
          
        },
      ,
        ## [92] in subset;ENTITY
        sub {
          my $token = $_;

        if ($StopProcessing) {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:entity ignored',
                          di => $DI, index => $Offset + pos $Input};
          #XXX$self->_sc->check_hidden_name
          #    (name => $self->{t}->{name},
          #    onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        } else { # not stop processing
          if ($token->{is_parameter_entity}) {
            if (not $DTDDefs->{pe}->{$token->{name} . ';'}) {
              push @$Errors, {level => 'w',
                              type => 'xml:dtd:ext decl',
                              di => $DI, index => $Offset + pos $Input}
                unless $DTDMode eq 'internal subset'; # and not in param entity
              #XXX$self->_sc->check_hidden_name
              #  (name => $self->{t}->{name},
              #onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

              $DTDDefs->{pe}->{$token->{name} . ';'} = $token;
            } else {
              push @$Errors, {level => 'w',
                              type => 'duplicate para entity decl', ## TODO: type
                              value => $token->{name},
                              di => $DI, index => $Offset + pos $Input};
            }
          } else { # general entity
            if ({
              amp => 1, apos => 1, quot => 1, lt => 1, gt => 1,
            }->{$token->{name}}) {
              if (not defined $token->{value} or # external entity
                  not $token->{value} =~ { # XXX IndexedString
                    amp => qr/\A&#(?:x0*26|0*38);\z/,
                    lt => qr/\A&#(?:x0*3[Cc]|0*60);\z/,
                    gt => qr/\A(?>&#(?:x0*3[Ee]|0*62);|>)\z/,
                    quot => qr/\A(?>&#(?:x0*22|0*34);|")\z/,
                    apos => qr/\A(?>&#(?:x0*27|0*39);|')\z/,
                  }->{$token->{name}}) {
                push @$Errors, {level => 'm',
                                type => 'bad predefined entity decl', ## TODO: type
                                value => $token->{name},
                                di => $DI, index => $Offset + pos $Input};
              }

              $DTDDefs->{ge}->{$token->{name}.';'} = {
                name => $token->{name},
                value => {
                  amp => '&',
                  lt => '<',
                  gt => '>',
                  quot => '"',
                  apos => "'",
                }->{$token->{name}},
                only_text => 1,
              };
            } elsif (not $DTDDefs->{ge}->{$token->{name}.';'}) {
              my $is_external = not $DTDMode eq 'internal subset';
                           #XXXnot ($self->{in_subset}->{internal_subset} and
                              #not $self->{in_subset}->{param_entity});
              push @$Errors, {level => 'w',
                              type => 'xml:dtd:ext decl',
                              di => $DI, index => $Offset + pos $Input}
                  if $is_external;
              #XXX$self->_sc->check_hidden_name
              #(name => $self->{t}->{name},
              #onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });

              $DTDDefs->{ge}->{$token->{name}.';'} = $token;
              if (defined $token->{value} and # XXX IndexedString
                  $token->{value} !~ /[&<]/) {
                $token->{only_text} = 1;
              }
              $token->{external} = {} if $is_external;
            } else {
              push @$Errors, {level => 'w',
                              type => 'duplicate general entity decl', ## TODO: type
                              value => $token->{name},
                              di => $DI, index => $Offset + pos $Input};
            }
          }

          #XXXif (defined $self->{t}->{pubid}) {
          #  $self->_sc->check_hidden_pubid
          #      (name => $self->{t}->{pubid},
          #     onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
          #}
          #if (defined $self->{t}->{sysid}) {
          #    $self->_sc->check_hidden_sysid
          #    (name => $self->{t}->{sysid},
          #     onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
          #}
          #if (defined $self->{t}->{notation}) {
          #  $self->_sc->check_hidden_name
          #    (name => $self->{t}->{notation},
          #     onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
          #}
        } # not stop processing
      
        },
      ,
        ## [93] in subset;EOD
        sub {
          
          if (length $DTDDefs->{system_id}) {
            
        warn "XXX external subset not implemented yet";
        push @$OP, ['construct-doctype'];
      
          }
        

          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        
        },
      ,
        ## [94] in subset;EOF
        sub {
          my $token = $_;
push @$Errors, {type => 'in-subset-eof',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};

          if (length $DTDDefs->{system_id}) {
            
        warn "XXX external subset not implemented yet";
        push @$OP, ['construct-doctype'];
      
          }
        
push @$OP, ['stop-parsing'];
        },
      ,
        ## [95] in subset;NOTATION
        sub {
          my $token = $_;

        if (defined $DTDDefs->{notations}->{$token->{name}}) {
          push @$Errors, {level => 'm',
                          type => 'duplicate notation decl', ## TODO: type
                          value => $token->{name},
                          di => $DI, index => $Offset + pos $Input};
        } else {
          push @$Errors, {level => 'w',
                          type => 'xml:dtd:ext decl',
                          di => $DI, index => $Offset + pos $Input}
              unless $DTDMode eq 'internal subset'; # not in param entity
          #XXX$self->_sc->check_hidden_name
          #    (name => $self->{t}->{name},
          #     onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
          # XXX $token->{base_url}
          $DTDDefs->{notations}->{$token->{name}} = $token;
        }
        #XXX
        #if (defined $self->{t}->{pubid}) {
        #  $self->_sc->check_hidden_pubid
        #      (name => $self->{t}->{pubid},
        #       onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        #}
        #if (defined $self->{t}->{sysid}) {
        #  $self->_sc->check_hidden_sysid
        #      (name => $self->{t}->{sysid},
        #       onerror => sub { $self->{onerror}->(token => $self->{t}, @_) });
        #}
      
        },
      ,
        ## [96] in subset;PI
        sub {
          my $token = $_;

            push @$OP, ['pi', $token => 1];
          
        },
      ,
        ## [97] in subset;START-ELSE
        sub {
          my $token = $_;

          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
        },
      ,
        ## [98] in subset;TEXT
        sub {
          my $token = $_;

        if ($token->{value} =~ s/^([\x09\x0A\x0C\x20]+)//) {
          
          $token->{index} += length $1;
        }
        if (length $token->{value}) {
          push @$Errors, {type => 'in-subset-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
        }
      
        },
      ,
        ## [99] initial;ATTLIST
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [100] initial;COMMENT
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [101] initial;DOCTYPE
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [102] initial;ELEMENT
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [103] initial;END-ELSE
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [104] initial;ENTITY
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [105] initial;EOD
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [106] initial;EOF
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [107] initial;NOTATION
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [108] initial;PI
        sub {
          my $token = $_;

          if ($token->{target} eq q@xml@) {
            
        my $pos = $token->{index};
        my $req_sp = 0;

        if ($token->{data} =~ s/\Aversion[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                  (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
          my $v = defined $1 ? $1 : $2;
          my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
          $pos += $+[0] - $-[0];
          $req_sp = not length $3;
          push @$OP, ['xml-version', $v];
          # XXX if text declaration
          #unless ($v eq '1.0') {
          #  push @$Errors, {type => 'bad XML version', # XXX
          #                  level => 'm',
          #                  di => $DI, index => $p};
          #}
        } else { # XXXif XML declaration (not text declaration)
          push @$Errors, {level => 'm',
                          type => 'attribute missing:version',
                          di => $DI, index => $pos};
        }

        if ($token->{data} =~ s/\Aencoding[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                  (?>"([^"]*)"|'([^']*)')([\x09\x0A\x20]*)//x) {
          my $v = defined $1 ? $1 : $2;
          my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
          if ($req_sp) {
            push @$Errors, {level => 'm',
                            type => 'no space before attr name',
                            di => $DI, index => $p};
          }
          $pos += $+[0] - $-[0];
          $req_sp = not length $3;
          #XXX$self->_sc->check_hidden_encoding
          #      (name => $v, onerror => sub {
          #         $onerror->(token => $self->{t}, %$p, @_);
          #       });
          if (1) { # XXX XML declaration (not text declaration)
            push @$OP, ['xml-encoding', $v];
          }
        } elsif (0) { # XXX text declaration
          ## A text declaration
          push @$Errors, {level => 'm',
                          type => 'attribute missing:encoding',
                          di => $DI, index => $pos};
        }

        if ($token->{data} =~ s/\Astandalone[\x09\x0A\x20]*=[\x09\x0A\x20]*
                                  (?>"([^"]*)"|'([^']*)')[\x09\x0A\x20]*//x) {
          my $v = defined $1 ? $1 : $2;
          if ($req_sp) {
            push @$Errors, {level => 'm',
                            type => 'no space before attr name',
                            di => $DI, index => $pos};
          }
          if ($v eq 'yes' or $v eq 'no') {
            if (1) { # XXX XML declaration (not text declaration)
              push @$OP, ['xml-standalone', $XMLStandalone = ($v ne 'no')];
            } else {
              push @$Errors, {level => 'm',
                              type => 'attribute not allowed:standalone',
                              di => $DI, index => $pos};
            }
          } else {
            my $p = $pos + (defined $-[1] ? $-[1] : $-[2]);
            push @$Errors, {level => 'm',
                            type => 'XML standalone:syntax error',
                            di => $DI, index => $p, value => $v};
          }
          $pos += $+[0] - $-[0];
        }

        if (length $token->{data}) {
          push @$Errors, {level => 'm',
                          type => 'bogus XML declaration',
                          di => $DI, index => $pos};
        }
      

          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        
          } else {
            
        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
          }
        
        },
      ,
        ## [109] initial;START-ELSE
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [110] initial;TEXT
        sub {
          my $token = $_;

        push @$Errors, {level => 's',
                        type => 'no XML decl',
                        di => $token->{di}, index => $token->{index}};
      

          $IM = BEFORE_DOCTYPE_IM;
          #warn "Insertion mode changed to |before DOCTYPE| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ];
    
$ProcessIM = [undef,
[undef, [$TCA->[1]], [$TCA->[3]], [$TCA->[4]], [$TCA->[6]], [$TCA->[9]], [$TCA->[2]], [$TCA->[5], $TCA->[5]], [$TCA->[7]], [$TCA->[8]], [$TCA->[10]], [$TCA->[11], $TCA->[11]], [$TCA->[12]]],
[undef, [$TCA->[13]], [$TCA->[15]], [$TCA->[16]], [$TCA->[18]], [$TCA->[21]], [$TCA->[14]], [$TCA->[17], $TCA->[17]], [$TCA->[19]], [$TCA->[20]], [$TCA->[22]], [$TCA->[23], $TCA->[23]], [$TCA->[24]]],
[undef, [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25], $TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25], $TCA->[25]], [$TCA->[26]]],
[undef, [$TCA->[27]], [$TCA->[29]], [$TCA->[30]], [$TCA->[32]], [$TCA->[35]], [$TCA->[28]], [$TCA->[31], $TCA->[31]], [$TCA->[33]], [$TCA->[34]], [$TCA->[36]], [$TCA->[37], $TCA->[37]], [$TCA->[38]]],
[undef, [$TCA->[39]], [$TCA->[41]], [$TCA->[42]], [$TCA->[44]], [$TCA->[47]], [$TCA->[40]], [$TCA->[43], $TCA->[43]], [$TCA->[45]], [$TCA->[46]], [$TCA->[48]], [$TCA->[49], $TCA->[49]], [$TCA->[50]]],
[undef, [$TCA->[87]], [$TCA->[89]], [$TCA->[90]], [$TCA->[92]], [$TCA->[95]], [$TCA->[88]], [$TCA->[91], $TCA->[91]], [$TCA->[93]], [$TCA->[94]], [$TCA->[96]], [$TCA->[97], $TCA->[97]], [$TCA->[98]]],
[undef, [$TCA->[51]], [$TCA->[53]], [$TCA->[54]], [$TCA->[56]], [$TCA->[59]], [$TCA->[52]], [$TCA->[55], $TCA->[55]], [$TCA->[57]], [$TCA->[58]], [$TCA->[60]], [$TCA->[61], $TCA->[61]], [$TCA->[62]]],
[undef, [$TCA->[63]], [$TCA->[65]], [$TCA->[66]], [$TCA->[68]], [$TCA->[71]], [$TCA->[64]], [$TCA->[67], $TCA->[67]], [$TCA->[69]], [$TCA->[70]], [$TCA->[72]], [$TCA->[73], $TCA->[73]], [$TCA->[74]]],
[undef, [$TCA->[75]], [$TCA->[77]], [$TCA->[78]], [$TCA->[80]], [$TCA->[83]], [$TCA->[76]], [$TCA->[79], $TCA->[79]], [$TCA->[81]], [$TCA->[82]], [$TCA->[84]], [$TCA->[85], $TCA->[85]], [$TCA->[86]]],
[undef, [$TCA->[99]], [$TCA->[101]], [$TCA->[102]], [$TCA->[104]], [$TCA->[107]], [$TCA->[100]], [$TCA->[103], $TCA->[103]], [$TCA->[105]], [$TCA->[106]], [$TCA->[108]], [$TCA->[109], $TCA->[109]], [$TCA->[110]]]];
my $ResetIMByET = {};
my $ResetIMByETUnlessLast = {};my $StateByElementName = {};

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
                  di => $attr->{di}, index => $attr->{index}};

  ## Step 5. Change the encoding on the fly
  ## Not implemented.

  ## Step 6. Navigate with replace.
  return $name; # change!

#XXX move this to somewhere else (when callback can't handle restart)
  ## Step 6. If can't restart
  $Confident = 1; # certain
  return undef;
} # _change_the_encoding

    sub di_data_set ($;$) {
      if (@_ > 1) {
        $_[0]->{di_data_set} = 0+$_[1];
      }
      return $_[0]->{di_data_set} ||= [];
    } # di_data_set

    sub di ($;$) {
      if (@_ > 1) {
        $_[0]->{di} = $_[1];
      }
      return $_[0]->{di}; # or undef
    } # di

  
    ## ------ Tokenizer ------
    
    my $StateActions = [];
    $StateActions->[ATTLIST_ATTR_DEFAULT_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\>\"\']+)/gcs) {
$Attr->{q<default_type>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'attlist-attribute-default-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'attlist-attribute-default-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTLIST_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\ \(\>]+)/gcs) {
$Attr->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\(])/gcs) {

            push @$Errors, {type => 'attlist-attribute-name-0028', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'attlist-attribute-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTLIST_ATTR_TYPE_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\(\#\>]+)/gcs) {
$Attr->{q<declared_type>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ATTLIST_ATTR_TYPE_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\#])/gcs) {

            push @$Errors, {type => 'attlist-attribute-type-0023', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = AFTER_ATTLIST_ATTR_TYPE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'attlist-attribute-type-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTLIST_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\ \>]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'attlist-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTLIST_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTLIST_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'attlist-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ATTLIST_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = ATTLIST_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'attlist-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'before-attlist-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'attlist-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ATTLIST_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = ATTLIST_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'attlist-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CDATA_SECTION_STATE] = sub {
if ($Input =~ /\G([^\\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp .= $1;
$State = CDATA_SECTION_STATE__5D_5D;
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
} elsif ($Input =~ /\G([\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
} elsif ($Input =~ /\G(.)/gcs) {
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE] = sub {
if ($Input =~ /\G([\-])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE__;
} elsif ($Input =~ /\G([A])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_A;
} elsif ($Input =~ /\G([E])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_E;
} elsif ($Input =~ /\G([N])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_N;
} elsif ($Input =~ /\G([a])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_A;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_E;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = DOCTYPE_MDO_STATE_N;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {

          unless ($DTDMode eq 'internal subset') {
            $State = AFTER_MSS_STATE;
            return 1;
          }
        

            push @$Errors, {type => 'doctype-markup-declaration-open-005b', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE__] = sub {
if ($Input =~ /\G([\-])/gcs) {

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_A] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_AT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_AT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_AT] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ATT] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTL;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ATTL] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTLI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTLI;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ATTLI] = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTLIS;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ATTLIS;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ATTLIS] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([T])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ATTLIST}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ATTLIST_STATE;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ATTLIST}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ATTLIST_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_E] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_EL;
} elsif ($Input =~ /\G([N])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_EN;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_EL;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_EN;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_EL] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ELE] = sub {
if ($Input =~ /\G([M])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEM;
} elsif ($Input =~ /\G([m])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEM;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ELEM] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEME;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEME;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ELEME] = sub {
if ($Input =~ /\G([N])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEMEN;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ELEMEN;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ELEMEN] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([T])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ELEMENT}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ELEMENT_STATE;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ELEMENT}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ELEMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_EN] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ENT] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENTI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENTI;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ENTI] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENTIT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_ENTIT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_ENTIT] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ENTITY}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ENTITY_STATE;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{ENTITY}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = ENTITY_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_N] = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NO;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NO;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NO] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NOT] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTA;
} elsif ($Input =~ /\G([a])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTA;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NOTA] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTAT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTAT;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NOTAT] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTATI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTATI;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NOTATI] = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTATIO;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = DOCTYPE_MDO_STATE_NOTATIO;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_MDO_STATE_NOTATIO] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([N])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{NOTATION}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = NOTATION_STATE;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{NOTATION}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = NOTATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'doctype-markup-declaration-open-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\\ \
\\>\[]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:literal not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'no DOCTYPE name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\>\ ]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_SYSTEM_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\\'\>\ ]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = DOCTYPE_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_DOCTYPE_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\>]+)/gcs) {
$Token->{q<system_identifier>} .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DOCTYPE_TAG_STATE] = sub {
if ($Input =~ /\G([\!])/gcs) {
$State = DOCTYPE_MDO_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = PI_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'doctype-tag-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'doctype-tag-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'doctype-tag-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'doctype-tag-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DTD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = DOCTYPE_TAG_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

          if ($DTDMode eq 'internal subset') {
            $State = AFTER_DOCTYPE_INTERNAL_SUBSET_STATE;
            return 1;
          }
        
$State = IN_DTD_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ELEMENT_CONTENT_KEYWORD_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\>]+)/gcs) {
$Token->{q<content_keyword>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ELEMENT_CONTENT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ELEMENT_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\\ \
\\%\(\>]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ELEMENT_CONTENT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {

            push @$Errors, {type => 'element-name-0028', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
my $cmgroup = {items => [], separators => [], di => $DI, index => $Offset + pos $Input};
$Token->{cmgroup} = $cmgroup;
@$OpenCMGroups = ($cmgroup);
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'element-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ELEMENT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ELEMENT_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'element-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ELEMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = ELEMENT_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'element-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'before-element-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'element-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ELEMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = ELEMENT_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'element-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\\ \
\\%\"\'\>]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'entity-name-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'entity-name-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_PUBLIC_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\ \\"\>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = ENTITY_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-public-identifier-double-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_PUBLIC_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = ENTITY_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-public-identifier-double-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_PUBLIC_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\ \\'\>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = ENTITY_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-public-identifier-single-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_PUBLIC_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = ENTITY_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-public-identifier-single-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$State = BEFORE_ENTITY_TYPE_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$State = PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'entity-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'entity-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      

            push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'entity-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'entity-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => ENTITY_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_SYSTEM_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\ \\"]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = ENTITY_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_SYSTEM_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_SYSTEM_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = ENTITY_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_SYSTEM_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\ \\']+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = ENTITY_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_SYSTEM_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_SYSTEM_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = ENTITY_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_VALUE__DQ__STATE] = sub {
if ($Input =~ /\G([^\ \\"\%\&]+)/gcs) {
$Token->{q<value>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<value>} .= q@
@;
$State = ENTITY_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = ENTITY_VALUE_CHARREF_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_VALUE__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_VALUE__DQ__STATE;
$Token->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<value>} .= q@
@;
$State = ENTITY_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = ENTITY_VALUE_CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_VALUE__DQ__STATE;
$Token->{q<value>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_VALUE__SQ__STATE] = sub {
if ($Input =~ /\G([^\ \\%\&\']+)/gcs) {
$Token->{q<value>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<value>} .= q@
@;
$State = ENTITY_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = ENTITY_VALUE_CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_PARAMETER_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_VALUE__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = ENTITY_VALUE__SQ__STATE;
$Token->{q<value>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = ENTITY_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<value>} .= q@
@;
$State = ENTITY_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = ENTITY_VALUE_CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ENTITY_VALUE__SQ__STATE;
$Token->{q<value>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_VALUE_CHARREF_STATE] = sub {
if ($Input =~ /\G([^\"\%\&\']+)/gcs) {

} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'entity-value-character-reference-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'entity-value-character-reference-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'entity-value-character-reference-0026', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE_CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'entity-value-character-reference-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE__DQ__STATE;
$Token->{q<value>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NDATA_ID_STATE] = sub {
if ($Input =~ /\G([^\ \	\\ \
\\%\>]+)/gcs) {
$Token->{q<notation_name>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<notation_name>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_NAME_STATE] = sub {
if ($Input =~ /\G([^\ \	\\ \
\\%\>]+)/gcs) {
$Token->{q<name>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_NOTATION_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_PUBLIC_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\ \\"\>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = NOTATION_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-public-identifier-double-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_PUBLIC_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = NOTATION_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = NOTATION_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = NOTATION_PUBLIC_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-public-identifier-double-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = NOTATION_PUBLIC_ID__DQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_PUBLIC_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\ \\'\>]+)/gcs) {
$Token->{q<public_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = NOTATION_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-public-identifier-single-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_PUBLIC_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = NOTATION_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = NOTATION_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<public_identifier>} .= q@
@;
$State = NOTATION_PUBLIC_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-public-identifier-single-quoted-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = NOTATION_PUBLIC_ID__SQ__STATE;
$Token->{q<public_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_NOTATION_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'notation-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => NOTATION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = NOTATION_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'notation-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'before-notation-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'notation-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => NOTATION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = NOTATION_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'notation-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_SYSTEM_ID__DQ__STATE] = sub {
if ($Input =~ /\G([^\ \\"]+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = NOTATION_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_NOTATION_SYSTEM_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_SYSTEM_ID__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = NOTATION_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = NOTATION_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = NOTATION_SYSTEM_ID__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_NOTATION_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = NOTATION_SYSTEM_ID__DQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_SYSTEM_ID__SQ__STATE] = sub {
if ($Input =~ /\G([^\ \\']+)/gcs) {
$Token->{q<system_identifier>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = NOTATION_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_NOTATION_SYSTEM_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[NOTATION_SYSTEM_ID__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = NOTATION_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = NOTATION_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<system_identifier>} .= q@
@;
$State = NOTATION_SYSTEM_ID__SQ__STATE_CR;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_NOTATION_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = NOTATION_SYSTEM_ID__SQ__STATE;
$Token->{q<system_identifier>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PI_DATA_STATE] = sub {
if ($Input =~ /\G([^\ \\?]+)/gcs) {
$Token->{q<data>} .= $1;

} elsif ($Input =~ /\G([\ ])/gcs) {
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = PI_DATA_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = IN_PIC_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PI_DATA_STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = PI_DATA_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@
@;
$State = PI_DATA_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PI_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = q@�@;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'pi-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'pi-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'pi-003f', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PI_TARGET_QUESTION_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'pi-target-question-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} = q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'pi-target-question-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} = q@?@;
$Token->{q<data>} .= q@
@;
$State = PI_DATA_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'pi-target-question-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} = q@?@;
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'pi-target-question-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} = q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'pi-target-question-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<data>} = q@?@;

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PI_TARGET_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\?\ ]+)/gcs) {
$Token->{q<target>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
])/gcs) {
$State = AFTER_PI_TARGET_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@
@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = AFTER_PI_TARGET_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = PI_TARGET_QUESTION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<target>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ATTLIST_ATTR_DEFAULT_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {

        $Attr = {di => $DI, index => $Offset + pos $Input};
        push @{$Token->{attr_list} ||= []}, $Attr;
      
$State = ATTLIST_ATTR_NAME_STATE;
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        $Attr = {di => $DI, index => $Offset + pos $Input};
        push @{$Token->{attr_list} ||= []}, $Attr;
      
$State = ATTLIST_ATTR_NAME_STATE;
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ATTLIST_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-attlist-attribute-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTLIST_ATTR_TYPE_STATE;
$Attr->{q<declared_type>} = $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ATTLIST_ATTR_TYPE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\(])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-attlist-attribute-type-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-attlist-attribute-type-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_INTERNAL_SUBSET_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-doctype-internal-subset-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_AFTER_DOCTYPE_INTERNAL_SUBSET_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_DOCTYPE_NAME_STATE_P;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_DOCTYPE_NAME_STATE_S;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-doctype-public-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<public_identifier>} = '';
$State = DOCTYPE_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<system_identifier>} = '';
$State = DOCTYPE_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DTD_MSC_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
pop @$OpenMarkedSections;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-dtd-msc-005d', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ELEMENT_CONTENT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-element-content-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ENTITY_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ENTITY_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([P])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_ENTITY_NAME_STATE_P;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_ENTITY_NAME_STATE_S;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_ENTITY_NAME_STATE_P;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_ENTITY_NAME_STATE_S;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_P] = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PU;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PU;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_PU] = sub {
if ($Input =~ /\G([B])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUB;
} elsif ($Input =~ /\G([b])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUB;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_PUB] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUBL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUBL;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_PUBL] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_PUBLI] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_ENTITY_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_ENTITY_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_S] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SY;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_SY] = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYS;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYS;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_SYS] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYST;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYST;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_SYST] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = AFTER_ENTITY_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_NAME_STATE_SYSTE] = sub {
if ($Input =~ /\G([M])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_ENTITY_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_ENTITY_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_PARAMETER_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-parameter-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BETWEEN_ENTITY_PUBLIC_AND_SYSTEM_IDS_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-entity-public-identifier-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-entity-public-identifier-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-entity-public-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-public-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_PUBLIC_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-entity-public-keyword-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-entity-public-keyword-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ENTITY_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-entity-public-keyword-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-public-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_NDATA_KEYWORD_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-system-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NDATA_KEYWORD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ENTITY_SYSTEM_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ENTITY_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-entity-system-keyword-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ENTITY_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-entity-system-keyword-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ENTITY_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-entity-system-keyword-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-entity-system-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_IGNORE_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-ignore-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-ignore-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_INCLUDE_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {
push @$OpenMarkedSections, 'INCLUDE';
$State = DTD_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-include-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-include-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NDATA_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_NDATA_ID_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-ndata-keyword-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NDATA_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([P])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_NOTATION_NAME_STATE_P;
} elsif ($Input =~ /\G([S])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_NOTATION_NAME_STATE_S;
} elsif ($Input =~ /\G([p])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_NOTATION_NAME_STATE_P;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_NOTATION_NAME_STATE_S;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-notation-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_P] = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PU;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PU;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_PU] = sub {
if ($Input =~ /\G([B])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUB;
} elsif ($Input =~ /\G([b])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUB;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_PUB] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUBL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUBL;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_PUBL] = sub {
if ($Input =~ /\G([I])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_PUBLI;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_PUBLI] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NOTATION_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{PUBLIC}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NOTATION_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_S] = sub {
if ($Input =~ /\G([Y])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SY;
} elsif ($Input =~ /\G([y])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SY;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_SY] = sub {
if ($Input =~ /\G([S])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYS;
} elsif ($Input =~ /\G([s])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYS;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_SYS] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYST;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYST;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_SYST] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;
$State = AFTER_NOTATION_NAME_STATE_SYSTE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_NAME_STATE_SYSTE] = sub {
if ($Input =~ /\G([M])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NOTATION_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{SYSTEM}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NOTATION_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-name-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BETWEEN_NOTATION_PUBLIC_AND_SYSTEM_IDS_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-notation-public-identifier-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = NOTATION_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-notation-public-identifier-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = NOTATION_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-public-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_PUBLIC_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-notation-public-keyword-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-notation-public-keyword-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NOTATION_PUBLIC_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-notation-public-keyword-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-public-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-system-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_NOTATION_SYSTEM_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_NOTATION_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-notation-system-keyword-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NOTATION_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-notation-system-keyword-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_NOTATION_SYSTEM_ID_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-notation-system-keyword-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-notation-system-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_PI_TARGET_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ \
]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\])/gcs) {
$Temp .= q@
@;
$State = AFTER_PI_TARGET_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_PI_TARGET_STATE_CR] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\	\\ ])/gcs) {
$State = AFTER_PI_TARGET_STATE;
$Temp .= $1;
} elsif ($Input =~ /\G([\
])/gcs) {
$State = AFTER_PI_TARGET_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
$Temp .= q@
@;
$State = AFTER_PI_TARGET_STATE_CR;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = PI_DATA_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_AFTER_ALLOWED_TOKEN_LIST_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-after-allowed-token-list-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ALLOWED_TOKEN_LIST_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_AFTER_ALLOWED_TOKEN_LIST_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {

            push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-allowed-token-list-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'after-after-allowed-token-list-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_ALLOWED_TOKEN_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
$State = AFTER_ALLOWED_TOKEN_LIST_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-allowed-token-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-allowed-token-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'attr:no =', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'attr:no =', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no space before attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_CONTENT_MODEL_GROUP_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          $State = AFTER_CONTENT_MODEL_GROUP_STATE;

        }
      
} elsif ($Input =~ /\G([\*])/gcs) {
$OpenCMGroups->[-1]->{q<repetition>} = $1;
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {
$OpenCMGroups->[-1]->{q<repetition>} = $1;
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\>])/gcs) {
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          $State = DTD_STATE;
push @$Tokens, $Token;

        } else {
          
            push @$Errors, {type => 'after-content-model-item-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

        }
      
} elsif ($Input =~ /\G([\?])/gcs) {
$OpenCMGroups->[-1]->{q<repetition>} = $1;
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
pop @$OpenCMGroups;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\(])/gcs) {

            push @$Errors, {type => 'after-content-model-group-0028', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-content-model-group-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_CONTENT_MODEL_ITEM_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          $State = AFTER_CONTENT_MODEL_GROUP_STATE;

        }
      
} elsif ($Input =~ /\G([\,])/gcs) {

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\>])/gcs) {

        if (@$OpenCMGroups) {
          $State = DTD_STATE;
push @$Tokens, $Token;

        } else {
          
            push @$Errors, {type => 'after-content-model-item-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

        }
      
} elsif ($Input =~ /\G([\|])/gcs) {

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\(])/gcs) {

            push @$Errors, {type => 'after-content-model-item-0028', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\*])/gcs) {

            push @$Errors, {type => 'after-content-model-item-002a', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {

            push @$Errors, {type => 'after-content-model-item-002b', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'after-content-model-item-003f', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-content-model-item-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_IGNORED_SECTION_MSC_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
pop @$OpenMarkedSections;
} elsif ($Input =~ /\G([\]]+)/gcs) {
} elsif ($Input =~ /\G(.)/gcs) {
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSC_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'after-msc-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([I])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_MSS_STATE_I;
} elsif ($Input =~ /\G([i])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = AFTER_MSS_STATE_I;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_I] = sub {
if ($Input =~ /\G([G])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IG;
} elsif ($Input =~ /\G([N])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IN;
} elsif ($Input =~ /\G([g])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IG;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IN;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_IG] = sub {
if ($Input =~ /\G([N])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGN;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGN;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_IGN] = sub {
if ($Input =~ /\G([O])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGNO;
} elsif ($Input =~ /\G([o])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGNO;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_IGNO] = sub {
if ($Input =~ /\G([R])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGNOR;
} elsif ($Input =~ /\G([r])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_IGNOR;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_IGNOR] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{IGNORE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_IGNORE_KEYWORD_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{IGNORE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_IGNORE_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_IN] = sub {
if ($Input =~ /\G([C])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INC;
} elsif ($Input =~ /\G([c])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INC;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_INC] = sub {
if ($Input =~ /\G([L])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCL;
} elsif ($Input =~ /\G([l])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCL;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_INCL] = sub {
if ($Input =~ /\G([U])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCLU;
} elsif ($Input =~ /\G([u])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCLU;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_INCLU] = sub {
if ($Input =~ /\G([D])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCLUD;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp .= $1;
$State = AFTER_MSS_STATE_INCLUD;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_MSS_STATE_INCLUD] = sub {
if ($Input =~ /\G([E])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{INCLUDE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_INCLUDE_KEYWORD_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IN_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{INCLUDE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_INCLUDE_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'after-mss-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @$OpenMarkedSections, 'IGNORE';
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ALLOWED_TOKEN_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
$State = AFTER_ALLOWED_TOKEN_LIST_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{allowed_tokens}->[-1] .= q@�@;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'allowed-token-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{allowed_tokens}->[-1] .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
\\/\=\>ABCDEFGHJKQVWZILMNOPRSTUXY\ \"\'\<]+)/gcs) {
$Attr->{q<name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Attr->{q<name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= q@�@;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{q<name>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\<])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\=])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\`])/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTLIST_ATTR_DEFAULT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {

            push @$Errors, {type => 'before-attlist-attribute-default-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'before-attlist-attribute-default-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'before-attlist-attribute-default-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'before-attlist-attribute-default-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-attlist-attribute-default-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<default_type>} .= $1;
$State = ATTLIST_ATTR_DEFAULT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTLIST_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {

        $Attr = {di => $DI, index => $Offset + pos $Input};
        push @{$Token->{attr_list} ||= []}, $Attr;
      
$State = ATTLIST_ATTR_NAME_STATE;
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        $Attr = {di => $DI, index => $Offset + pos $Input};
        push @{$Token->{attr_list} ||= []}, $Attr;
      
$State = ATTLIST_ATTR_NAME_STATE;
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTLIST_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ATTLIST_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = ATTLIST_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-attlist-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => ATTLIST_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = ATTLIST_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = chr ((ord $1) + 32);
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = DOCTYPE_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = DOCTYPE_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        $Token = {type => DOCTYPE_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'no DOCTYPE literal', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ELEMENT_CONTENT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {
my $cmgroup = {items => [], separators => [], di => $DI, index => $Offset + pos $Input};
$Token->{cmgroup} = $cmgroup;
@$OpenCMGroups = ($cmgroup);
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {

            push @$Errors, {type => 'before-element-content-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\*])/gcs) {

            push @$Errors, {type => 'before-element-content-002a', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {

            push @$Errors, {type => 'before-element-content-002b', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {

            push @$Errors, {type => 'before-element-content-002c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-element-content-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'before-element-content-003f', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {

            push @$Errors, {type => 'before-element-content-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<content_keyword>} = $1;
$State = ELEMENT_CONTENT_KEYWORD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ELEMENT_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => ELEMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = ELEMENT_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-element-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => ELEMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = ELEMENT_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ENTITY_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} = q@�@;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ENTITY_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ENTITY_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ENTITY_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-entity-public-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-entity-public-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ENTITY_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ENTITY_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ENTITY_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-entity-system-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-entity-system-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ENTITY_TYPE_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} = q@�@;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_AFTER_SPACE_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_ID_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$Token->{q<notation_name>} = q@�@;
$State = NDATA_ID_STATE;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-ndata-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<notation_name>} = $1;
$State = NDATA_ID_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([N])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = BEFORE_NDATA_KEYWORD_STATE_N;
} elsif ($Input =~ /\G([n])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = BEFORE_NDATA_KEYWORD_STATE_N;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_KEYWORD_STATE_N] = sub {
if ($Input =~ /\G([D])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_ND;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_ND;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_KEYWORD_STATE_ND] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_NDA;
} elsif ($Input =~ /\G([a])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_NDA;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_KEYWORD_STATE_NDA] = sub {
if ($Input =~ /\G([T])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_NDAT;
} elsif ($Input =~ /\G([t])/gcs) {
$Temp .= $1;
$State = BEFORE_NDATA_KEYWORD_STATE_NDAT;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NDATA_KEYWORD_STATE_NDAT] = sub {
if ($Input =~ /\G([A])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{NDATA}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NDATA_KEYWORD_STATE;
} elsif ($Input =~ /\G([a])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{NDATA}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = AFTER_NDATA_KEYWORD_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-ndata-keyword-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NOTATION_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {

        $Token = {type => NOTATION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = q@�@;
$State = NOTATION_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-notation-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => NOTATION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<name>} = $1;
$State = NOTATION_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NOTATION_PUBLIC_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = NOTATION_PUBLIC_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = NOTATION_PUBLIC_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-notation-public-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-notation-public-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NOTATION_SYSTEM_ID_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = NOTATION_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = NOTATION_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-notation-system-identifier-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'before-notation-system-identifier-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ALLOWED_TOKEN_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr->{allowed_tokens}->[-1] = q@�@;
$State = ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {

            push @$Errors, {type => 'before-allowed-token-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = AFTER_ALLOWED_TOKEN_LIST_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-allowed-token-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {

            push @$Errors, {type => 'before-allowed-token-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{allowed_tokens} ||= []}, '';
$Attr->{allowed_tokens}->[-1] = $1;
$State = ALLOWED_TOKEN_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = $3;
$Attr->{index} = $Offset + $-[3];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{index} = $Offset + $-[3];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = $3;
$Attr->{index} = $Offset + $-[3];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*([^\ \	\
\\\ \"\&\'\<\=\>\`])([^\ \	\
\\\ \"\&\'\<\=\>\`]*)\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = ATTR_VALUE__UNQUOTED__STATE;
push @{$Attr->{q<value>}}, [$4, $DI, $Offset + $-[4]];
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $3) + 32);
$Attr->{index} = $Offset + $-[3];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $4;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\=[\	\
\\\ ]*\'([^\ \\&\']*)\'\/\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)\=[\	\
\\\ ]*\"([^\ \\"\&]*)\"[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([^\ \	\
\\\ \"\'\/\<\=\>A-Z])([^\ \	\
\\\ \"\'\/\<\=\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*\/\>/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = BEFORE_ATTR_VALUE_STATE;
$State = ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$3, $DI, $Offset + $-[3]];
$State = AFTER_ATTR_VALUE__QUOTED__STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = AFTER_ATTR_NAME_STATE;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + $-[1];
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
$Attr->{q<name>} .= $2;

        if (defined $Token->{attrs}->{$Attr->{name}}) {
          push @$Errors, {type => 'duplicate attribute',
                          text => $Attr->{name},
                          level => 'm',
                          di => $Attr->{di},
                          index => $Attr->{index}};
        } else {
          $Token->{attrs}->{$Attr->{name}} = $Attr;
          push @{$Token->{attr_list} ||= []}, $Attr;
          $Attr->{name_args} = [undef, [undef, $Attr->{name}]];
        }
      
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$TempIndex = $Offset + (pos $Input) - (length $1) - 0;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'bad attribute value', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__UNQUOTED__STATE;
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
$State = ATTR_VALUE__UNQUOTED__STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_CONTENT_MODEL_ITEM_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {
my $cmgroup = {items => [], separators => [], di => $DI, index => $Offset + pos $Input};
push @{$OpenCMGroups->[-1]->{items}}, $cmgroup;
push @$OpenCMGroups, $cmgroup;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @{$OpenCMGroups->[-1]->{items}},
            {di => $DI, index => $Offset + pos $Input};
      
$OpenCMGroups->[-1]->{items}->[-1]->{q<name>} = q@�@;
$State = CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {

            push @$Errors, {type => 'before-content-model-item-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\*])/gcs) {

            push @$Errors, {type => 'before-content-model-item-002a', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {

            push @$Errors, {type => 'before-content-model-item-002b', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {

            push @$Errors, {type => 'before-content-model-item-002c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'before-content-model-item-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {

            push @$Errors, {type => 'before-content-model-item-003f', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {

            push @$Errors, {type => 'before-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

        push @{$OpenCMGroups->[-1]->{items}},
            {di => $DI, index => $Offset + pos $Input};
      
$OpenCMGroups->[-1]->{items}->[-1]->{q<name>} = $1;
$State = CONTENT_MODEL_ELEMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'between-doctype-public-and-system-identifiers-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus DOCTYPE', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<force_quirks_flag>} = 1;
$State = BOGUS_DOCTYPE_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
$Token->{q<force_quirks_flag>} = 1;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BETWEEN_ENTITY_PUBLIC_AND_SYSTEM_IDS_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ENTITY_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ENTITY_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'between-entity-public-and-system-identifiers-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'between-entity-public-and-system-identifiers-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BETWEEN_NOTATION_PUBLIC_AND_SYSTEM_IDS_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = NOTATION_SYSTEM_ID__DQ__STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = NOTATION_SYSTEM_ID__SQ__STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'between-notation-public-and-system-identifiers-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_DOCTYPE_STATE] = sub {
if ($Input =~ /\G([^\>\[]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
$DTDMode = q{internal subset};
push @$Tokens, $Token;
} else {
if ($EOF) {
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_AFTER_DOCTYPE_INTERNAL_SUBSET_STATE] = sub {
if ($Input =~ /\G([^\>]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                        di => $DI,
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
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[BOGUS_MARKUP_DECLARATION_STATE] = sub {
if ($Input =~ /\G([^\>]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - (length $1) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$Temp = q@&@;
$TempIndex = $Offset + (pos $Input) - 1;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@--!�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@--!@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@-�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@--�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= q@
@;
$State = COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\!])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = COMMENT_END_BANG_STATE;
} elsif ($Input =~ /\G([\-])/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@-@;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'parser:comment not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@--@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@-�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:comment closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@-@;
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@�@;
$State = COMMENT_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parser:comment closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= $1;
$State = COMMENT_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G(.)/gcs) {
$State = COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;
push @$Tokens, $Token;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[CONTENT_MODEL_ELEMENT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-0029', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          $State = AFTER_CONTENT_MODEL_GROUP_STATE;

        }
      
} elsif ($Input =~ /\G([\*])/gcs) {
$OpenCMGroups->[-1]->{items}->[-1]->{q<repetition>} = $1;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {
$OpenCMGroups->[-1]->{items}->[-1]->{q<repetition>} = $1;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\>])/gcs) {
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          $State = DTD_STATE;
push @$Tokens, $Token;

        } else {
          
            push @$Errors, {type => 'after-content-model-item-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

        }
      
} elsif ($Input =~ /\G([\?])/gcs) {
$OpenCMGroups->[-1]->{items}->[-1]->{q<repetition>} = $1;
$State = AFTER_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
$State = AFTER_CONTENT_MODEL_ITEM_STATE;

        if (@$OpenCMGroups) {
          
            push @$Errors, {type => 'after-content-model-item-007c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;

        } else {
          
        push @{$OpenCMGroups->[-1]->{separators}},
            {di => $DI, index => $Offset + pos $Input, type => $1};
      
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;

        }
      
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\(])/gcs) {

            push @$Errors, {type => 'content-model-element-0028', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE] = sub {
if ($Input =~ /\G([^\\&\<\]\ ]+)/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

} elsif ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DATA_STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
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
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\]])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\ ])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  push @$Errors, {type => 'no refc',
                                  level => 'm',
                                  di => $DI,
                                  index => $TempIndex + $_};

                  ## A variant of |emit-temp|
                  push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                                  value => $value,
                                  di => $DI, index => $TempIndex};
                  $TempIndex += $_;
                  $value = '';
                }
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared', value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\
])/gcs) {
$State = DATA_STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = DATA_STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = IN_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE] = sub {
if ($Input =~ /\G([^\\"\&\ ]+)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__DQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__DQ__STATE_CR;
} elsif ($Input =~ /\G([\"])/gcs) {
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = DEFAULT_ATTR_VALUE__DQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE] = sub {
if ($Input =~ /\G([^\\&\'\ ]+)/gcs) {
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];

} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare hcro', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#0*([0-9]{1,10})\z/ ? 0+$1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789ABCDEFabcdef]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([\;])/gcs) {

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'no refc', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        my $code = do { $Temp =~ /\A&#[Xx]0*([0-9A-Fa-f]{1,8})\z/ ? hex $1 : 0xFFFFFFFF };
        if (my $replace = $Web::HTML::ParserData::InvalidCharRefs->{$code}) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U+%04X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = $replace;
        } elsif ($code > 0x10FFFF) {
          push @$Errors, {type => 'invalid character reference',
                          text => (sprintf 'U-%08X', $code),
                          level => 'm',
                          di => $DI, index => $TempIndex};
          $code = 0xFFFD;
        }
        $Temp = chr $code;
      
$Attr->{has_ref} = 1;
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (1) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy]+)/gcs) {
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {

          REF: {
            for (reverse (2 .. length $Temp)) {
              my $value = $Web::HTML::EntityChar->{substr $Temp, 1, $_-1};
              if (defined $value) {
                unless (';' eq substr $Temp, $_-1, 1) {
                  if ((substr $Temp, $_, 1) =~ /^[A-Za-z0-9]/) {
                    last REF;
                  } elsif (0) { # before_equals
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
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
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                    last REF;
                  } else {
                    push @$Errors, {type => 'no refc',
                                    level => 'm',
                                    di => $DI,
                                    index => $TempIndex + $_};
                  }

                  ## A variant of |append-to-attr|
                  push @{$Attr->{value}},
                      [$value, $DI, $TempIndex]; # IndexedString
                  $TempIndex += $_;
                  $value = '';
                }
                $Attr->{has_ref} = 1;
                substr ($Temp, 0, $_) = $value;
                last REF;
              }
            }
            push @$Errors, {type => 'entity not declared',
                            value => $Temp,
                            level => 'm',
                            di => $DI, index => $TempIndex}
                if $Temp =~ /;\z/;
          } # REF
        
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE] = sub {
if ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE;
} elsif ($Input =~ /\G([X])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([x])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'bare nero', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE] = sub {
if ($Input =~ /\G([\	\\ \
])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\#])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([0123456789])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqvwzilmnoprstuxy])/gcs) {
$Temp .= $1;
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {
push @{$Attr->{q<value>}}, [$Temp, $DI, $TempIndex];

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[DEFAULT_ATTR_VALUE__SQ__STATE_CR] = sub {
if ($Input =~ /\G([\
])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
} elsif ($Input =~ /\G([\])/gcs) {
push @{$Attr->{q<value>}}, [q@
@, $DI, $Offset + (pos $Input) - length $1];
$State = DEFAULT_ATTR_VALUE__SQ__STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE___CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = BEFORE_ATTLIST_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
push @{$Attr->{q<value>}}, [q@�@, $DI, $Offset + (pos $Input) - length $1];
} elsif ($Input =~ /\G(.)/gcs) {
$State = DEFAULT_ATTR_VALUE__SQ__STATE;
push @{$Attr->{q<value>}}, [$1, $DI, $Offset + (pos $Input) - length $1];
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[END_TAG_OPEN_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = q@�@;
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'end-tag-open-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'end-tag-open-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'empty end tag', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = '';

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@</@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[IGNORED_SECTION_STATE] = sub {
if ($Input =~ /\G([^\]]+)/gcs) {

} elsif ($Input =~ /\G([\]])/gcs) {
$State = IN_IGNORED_SECTION_MSC_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[IN_DTD_MSC_STATE] = sub {
if ($Input =~ /\G([\]])/gcs) {
$State = AFTER_DTD_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[IN_IGNORED_SECTION_MSC_STATE] = sub {
if ($Input =~ /\G([\]])/gcs) {
$State = AFTER_IGNORED_SECTION_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[IN_MSC_STATE] = sub {
if ($Input =~ /\G([\])/gcs) {

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\&])/gcs) {
$State = CHARREF_IN_DATA_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$State = TAG_OPEN_STATE;
$AnchoredIndex = $Offset + (pos $Input) - 1;
} elsif ($Input =~ /\G([\]])/gcs) {
$State = AFTER_MSC_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\ ])/gcs) {
$State = DATA_STATE;

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G(.)/gcs) {
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} else {
if ($EOF) {
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[IN_PIC_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {
$Token->{q<data>} .= q@?@;
$Token->{q<data>} .= q@
@;
$State = PI_DATA_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\?])/gcs) {
$Token->{q<data>} .= q@?@;
} elsif ($Input =~ /\G(.)/gcs) {
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {
$Token->{q<data>} .= q@?@;

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;
} elsif ($Input =~ /\G([D])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\[])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
} elsif ($Input =~ /\G([d])/gcs) {
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE_D;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE_DOCTYP] = sub {
if ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G([E])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{DOCTYPE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([e])/gcs) {
$Temp .= $1;

            unless ($Temp eq q{DOCTYPE}) {
              push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                              value => $Temp,
                              di => $DI, index => $Offset + (pos $Input) - 1};
            }
          
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[MDO_STATE__5BCDATA] = sub {
if ($Input =~ /\G([\[])/gcs) {
$State = CDATA_SECTION_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= q@�@;
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'bogus comment', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$Token->{q<data>} .= $Temp;
push @$Tokens, $Token;
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_AFTER_SPACE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$State = BEFORE_ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\`])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;

            push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G(.)/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {
$Token->{q<is_parameter_entity_flag>} = 1;

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$State = BEFORE_ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-0026', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-003c', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-003d', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;

            push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\`])/gcs) {

            push @$Errors, {type => 'parameter-entity-declaration-or-reference-0060', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<is_parameter_entity_flag>} = 1;
$Token->{q<name>} = $1;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$Token->{q<is_parameter_entity_flag>} = 1;

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PARAMETER_ENTITY_NAME_IN_DTD_STATE] = sub {
if ($Input =~ /\G([^\"\%\&\']+)/gcs) {

} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-dtd-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-dtd-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-dtd-0026', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-dtd-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DTD_STATE;

            push @$Errors, {type => 'dtd-else', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE] = sub {
if ($Input =~ /\G([^\"\%\&\']+)/gcs) {

} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-entity-value-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = AFTER_ENTITY_PARAMETER_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-entity-value-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-entity-value-0026', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE_CHARREF_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-entity-value-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = ENTITY_VALUE__DQ__STATE;
$Token->{q<value>} .= $1;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE] = sub {
if ($Input =~ /\G([^\"\%\&\']+)/gcs) {

} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-markup-declaration-0022', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-markup-declaration-0025', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-markup-declaration-0026', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'parameter-entity-name-in-markup-declaration-0027', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_DOCTYPE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = q@�@;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\"])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'bad attribute name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'tag not closed', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

            push @$Errors, {type => 'parser:no attr name', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = chr ((ord $1) + 32);
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

            push @$Errors, {type => 'nestc has no net', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Attr = {di => $DI};
$Attr->{q<name>} = $1;
$Attr->{index} = $Offset + (pos $Input) - length $1;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
$State = ATTR_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
\\/\>ABCDEFGHJKQVWZILMNOPRSTUXY\ ]+)/gcs) {
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
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQVWZILMNOPRSTUXY])/gcs) {
$Token->{q<tag_name>} .= chr ((ord $1) + 32);
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$Token->{q<tag_name>} .= q@�@;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
                        index => $Offset + pos $Input};
        return 1;
      
} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_OPEN_STATE] = sub {
if ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)([^\ \	\
\\\ \?])([^\ \\?]*)\?([^\ \\>\?])([^\ \\?]*)/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $5;
$Token->{q<data>} .= $6;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $7;
$Token->{q<data>} .= $8;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)([^\ \	\
\\\ \?])([^\ \\?]*)\?\ ([^\ \\?]*)/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $5;
$Token->{q<data>} .= $6;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $7;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\ ([^\ \\?]*)\?([^\ \\>\?])([^\ \\?]*)/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $5;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $6;
$Token->{q<data>} .= $7;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)([^\ \	\
\\\ \?])([^\ \\?]*)\?\>/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $5;
$Token->{q<data>} .= $6;
$State = IN_PIC_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\ ([^\ \\?]*)\?\ ([^\ \\?]*)/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $5;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $6;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\?([^\ \\>\?])([^\ \\?]*)\?/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= $5;
$Token->{q<data>} .= $6;
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\?\ ([^\ \\?]*)\?/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$State = IN_PIC_STATE;
$Token->{q<data>} .= q@?@;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $5;
$State = IN_PIC_STATE;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\ ([^\ \\?]*)\?\>/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$Token->{q<data>} .= q@�@;
$Token->{q<data>} .= $5;
$State = IN_PIC_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([^\ \	\
\\\ \!\/\>\?])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\/([^\ \	\
\\\ \>])([^\ \	\
\\\ \/\>A-Z]*)[\	\
\\\ ][\	\
\\\ ]*/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)([\	\
\\ ])([\	\
\\ ]*)\?\>/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = AFTER_PI_TARGET_STATE;
$Temp = $3;
$TempIndex = $Offset + (pos $Input) - (length $1);
$Temp .= $4;
$State = PI_DATA_STATE;
$State = IN_PIC_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])(\])(\]*)([^\\>\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
$Temp .= $9;
$State = CDATA_SECTION_STATE__5D_5D;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $10,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $11,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $12,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
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
} elsif ($Input =~ /\G\!(\-)\-([^\ \\-\>])([^\ \\-]*)\-([^\ \\-])([^\ \\-]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
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
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])([^\\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $9,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $10,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])(\])(\]*)(\])(\]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
$Temp .= $9;
$State = CDATA_SECTION_STATE__5D_5D;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $10,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $11,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $12,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
} elsif ($Input =~ /\G([^\ \	\
\\\ \!\/\>\?])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
\\\ \!\/\>\?])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)([^\\]])([^\\]]*)/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $8,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $9,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G\/([^\ \	\
\\\ \>])([^\ \	\
\\\ \/\>A-Z]*)\/\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])(\])(\]*)\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
$Temp .= $9;
$State = CDATA_SECTION_STATE__5D_5D;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $10,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])(\])(\]*)\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;
$Temp .= $9;
$State = CDATA_SECTION_STATE__5D_5D;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $10,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 2};
        
$State = DATA_STATE;
} elsif ($Input =~ /\G\/([^\ \	\
\\\ \>])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {
$State = END_TAG_OPEN_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
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
        
} elsif ($Input =~ /\G\?([^\ \	\
\\\ \?])([^\ \	\
\\\ \?]*)\?\>/gcs) {
$State = PI_STATE;

        $Token = {type => PROCESSING_INSTRUCTION_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<target>} = $1;
$Token->{q<data>} = '';
$State = PI_TARGET_STATE;
$Token->{q<target>} .= $2;
$State = PI_TARGET_QUESTION_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\-)\-\-([^\ \\-\>])([^\ \\-]*)\-\-\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
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
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$Token->{q<data>} .= $2;
$State = COMMENT_STATE;
$Token->{q<data>} .= $3;
$State = COMMENT_END_DASH_STATE;
$State = COMMENT_END_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)(\])\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
$Temp = $8;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = CDATA_SECTION_STATE__5D;

        push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                        value => $Temp,
                        di => $DI,
                        index => $TempIndex} if length $Temp;
      

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G\!(\[)(C)(D)(A)(T)(A)\[([^\\]]*)\/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__5B;
$Temp .= $2;
$State = MDO_STATE__5BC;
$Temp .= $3;
$State = MDO_STATE__5BCD;
$Temp .= $4;
$State = MDO_STATE__5BCDA;
$Temp .= $5;
$State = MDO_STATE__5BCDAT;
$Temp .= $6;
$State = MDO_STATE__5BCDATA;
$State = CDATA_SECTION_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $7,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = CDATA_SECTION_STATE_CR;
} elsif ($Input =~ /\G\!(\-)\-\-\-\>/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
$Temp = $1;
$TempIndex = $Offset + (pos $Input) - (length $1);
$State = MDO_STATE__;

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = '';
$State = COMMENT_START_STATE;
$State = COMMENT_START_DASH_STATE;
$State = COMMENT_END_STATE;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\!])/gcs) {

        $Temp = '';
        $TempIndex = $Offset + (pos $Input);
      
$State = MDO_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = END_TAG_OPEN_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {
$State = PI_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

            push @$Errors, {type => 'NULL', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = q@�@;
$State = TAG_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
])/gcs) {

            push @$Errors, {type => 'tag-open-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => $1,
                          di => $DI, index => $Offset + (pos $Input) - (length $1)};
        
} elsif ($Input =~ /\G([\])/gcs) {

            push @$Errors, {type => 'tag-open-ws', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@
@,
                          di => $DI, index => $Offset + (pos $Input) - (length $1) - 0};
        
$State = DATA_STATE_CR;
} elsif ($Input =~ /\G([\>])/gcs) {

            push @$Errors, {type => 'tag-open-003e', level => 'm',
                            di => $DI, index => $Offset + (pos $Input) - 1};
          
$State = DATA_STATE;

        $Token = {type => END_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = '';

          if ($Token->{type} == END_TAG_TOKEN) {
            if (keys %{$Token->{attrs} or {}}) {
              push @$Errors, {type => 'end tag attribute',
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
            if ($Token->{self_closing_flag}) {
              push @$Errors, {type => 'nestc',
                              text => $Token->{tag_name},
                              level => 'm',
                              di => $Token->{di},
                              index => $Token->{index}};
            }
          }
        
push @$Tokens, $Token;

          if ($Token->{type} == END_TAG_TOKEN) {
            undef $InForeign;
            $Token->{tn} = $TagName2Group->{$Token->{tag_name}} || 0;
            return 1 if $TokenizerAbortingTagNames->{$Token->{tag_name}};
          }
        
} elsif ($Input =~ /\G(.)/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
} else {
if ($EOF) {

            push @$Errors, {type => 'parser:EOF', level => 'm',
                            di => $DI, index => $Offset + (pos $Input)};
          

          push @$Tokens, {type => TEXT_TOKEN, tn => 0,
                          value => q@<@,
                          di => $DI, index => $AnchoredIndex};
        
$State = DATA_STATE;

        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
                        di => $DI,
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
        &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      }

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
  my $doctype_children = $doc->dom_config->{manakai_allow_doctype_children};
  $doc->dom_config->{manakai_allow_doctype_children} = 1;

  my $nodes = $self->{nodes};
  for my $op (@$ops) {
    if ($op->[0] eq 'insert' or
        $op->[0] eq 'insert-foster' or
        $op->[0] eq 'create') {
      my $data = $op->[1];
      my $el = $doc->create_element_ns
          ($data->{ns}, [$data->{prefix}, $data->{local_name}]);
      $el->manakai_set_source_location (['', $data->{di}, $data->{index}]);
      ## Note that $data->{ns} can be 0.
      for my $attr (@{$data->{attr_list} or []}) { # XXXxml
        $el->manakai_set_attribute_indexed_string_ns
            (@{$attr->{name_args}} => $attr->{value}); # IndexedString
      }
      if ($data->{et} == TEMPLATE_EL) {
        $nodes->[$data->{id}] = $el->content;
        $el->content->manakai_set_source_location
            (['', $data->{di}, $data->{index}]);
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
      $nodes->[$op->[2]]->manakai_append_indexed_string ($op->[1]); # IndexedString
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
            $prev_sibling->manakai_append_indexed_string ($op->[1]);
          } else {
            $prev_sibling = $doc->create_text_node ('');
            $prev_sibling->manakai_append_indexed_string ($op->[1]);
            $parent->insert_before ($prev_sibling, $next_sibling);
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
      my $comment = $doc->create_comment ($op->[1]->{data});
      $comment->manakai_set_source_location
          (['', $op->[1]->{di}, $op->[1]->{index}]);
      $nodes->[$op->[2]]->append_child ($comment);
    } elsif ($op->[0] eq 'pi') {
      my $pi = $doc->create_processing_instruction
          ($op->[1]->{target}, $op->[1]->{data});
      $pi->manakai_set_source_location
          (['', $op->[1]->{di}, $op->[1]->{index}]);
      $nodes->[$op->[2]]->append_child ($pi);
    } elsif ($op->[0] eq 'doctype') {
      my $data = $op->[1];
      my $dt = $doc->implementation->create_document_type
          (defined $data->{name} ? $data->{name} : '',
           defined $data->{public_identifier} ? $data->{public_identifier} : '',
           defined $data->{system_identifier} ? $data->{system_identifier} : '');
      $dt->manakai_set_source_location (['', $data->{di}, $data->{index}]);
      $nodes->[1] = $dt;
      $nodes->[$op->[2]]->append_child ($dt);

    } elsif ($op->[0] eq 'set-if-missing') {
      my $el = $nodes->[$op->[2]];
      for my $attr (@{$op->[1]}) {
        $el->manakai_set_attribute_indexed_string_ns
            (@{$attr->{name_args}} => $attr->{value}) # IndexedString
            unless $el->has_attribute_ns ($attr->{name_args}->[0], $attr->{name_args}->[1]->[1]);
      }

    } elsif ($op->[0] eq 'change-the-encoding') {
      unless ($Confident) {
        my $changed = $self->_change_the_encoding ($op->[1], $op->[2]);
        push @$Callbacks, [$self->onrestartwithencoding, $changed]
            if defined $changed;
      }
      if ($op->[2]->{has_ref}) {
        push @$Errors, {type => 'charref in charset', level => 'm',
                        di => $op->[2]->{di}, index => $op->[2]->{index}};
      }

    } elsif ($op->[0] eq 'script') {
      # XXX insertion point setup
      push @$Callbacks, [$self->onscript, $nodes->[$op->[1]]];
    } elsif ($op->[0] eq 'ignore-script') {
      #warn "XXX set already started flag of $nodes->[$op->[1]]";
    } elsif ($op->[0] eq 'appcache') {
      if (defined $op->[1]) {
        my $value = join '', map { $_->[0] } @{$op->[1]->{value}}; # IndexedString
        push @$Callbacks, [$self->onappcacheselection, length $value ? $value : undef];
      } else {
        push @$Callbacks, [$self->onappcacheselection, undef];
      }

    } elsif ($op->[0] eq 'popped') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_AUD_STY_VID_ELS | OBJ_ELS) } @{$op->[1]}]];
    } elsif ($op->[0] eq 'stop-parsing') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_AUD_STY_VID_ELS | OBJ_ELS) } @$OE]];
      #@$OE = ();

      # XXX stop parsing
    } elsif ($op->[0] eq 'abort') {
      push @$Callbacks, [$self->onelementspopped, [map { $nodes->[$_->{id}] } grep { $_->{et} & (APP_AUD_STY_VID_ELS | OBJ_ELS) } @$OE]];
      #@$OE = ();

      # XXX abort

    } elsif ($op->[0] eq 'remove') {
      my $parent = $nodes->[$op->[1]]->parent_node;
      $parent->remove_child ($nodes->[$op->[1]]) if defined $parent;

    } elsif ($op->[0] eq 'set-compat-mode') {
      $doc->manakai_compat_mode ($op->[1]);
    } elsif ($op->[0] eq 'xml-version') {
      $doc->xml_version ($op->[1]);
    } elsif ($op->[0] eq 'xml-encoding') {
      $doc->xml_encoding ($op->[1]);
    } elsif ($op->[0] eq 'xml-standalone') {
      $doc->xml_standalone ($op->[1]);

    } elsif ($op->[0] eq 'construct-doctype') {
      for my $data (values %{$DTDDefs->{elements} or {}}) {
        my $node = $doc->create_element_type_definition ($data->{name});
        $node->content_model_text ($data->{content_keyword})
            if defined $data->{content_keyword};
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}])
            if defined $data->{index};
        $doc->doctype->set_element_type_definition_node ($node);
      }
      for my $elname (keys %{$DTDDefs->{attrdefs} or {}}) {
        my $et = $doc->doctype->get_element_type_definition_node ($elname);
        for my $data (@{$DTDDefs->{attrdefs}->{$elname}}) {
          my $node = $doc->create_attribute_definition ($data->{name});
          $node->declared_type ($data->{declared_type} || 0);
          push @{$node->allowed_tokens}, @{$data->{allowed_tokens} or []};
          $node->default_type ($data->{default_type} || 0);
          #XXX$node->manakai_append_indexed_string ($data->{value})
          $node->node_value (join '', map { $_->[0] } @{$data->{value}})
              if defined $data->{value};
          $et->set_attribute_definition_node ($node);
          $node->manakai_set_source_location
              (['', $data->{di}, $data->{index}]);
        }
      }
      for my $data (values %{$DTDDefs->{notations} or {}}) {
        my $node = $doc->create_notation ($data->{name});
        $node->public_id ($data->{public_identifier}); # or undef
        $node->system_id ($data->{system_identifier}); # or undef
        # XXX base URL
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}]);
        $doc->doctype->set_notation_node ($node);
      }
      for my $data (values %{$DTDDefs->{ge} or {}}) {
        next unless defined $data->{notation_name};
        my $node = $doc->create_general_entity ($data->{name});
        $node->public_id ($data->{public_identifier}); # or undef
        $node->system_id ($data->{system_identifier}); # or undef
        $node->notation_name ($data->{notation_name}); # or undef
        # XXX base URL
        $node->manakai_set_source_location (['', $data->{di}, $data->{index}]);
        $doc->doctype->set_general_entity_node ($node);
      }

    } else {
      die "Unknown operation |$op->[0]|";
    }
  }

  $doc->strict_error_checking ($strict);
  $doc->dom_config->{manakai_allow_doctype_children} = $doctype_children;
} # dom_tree

  
    ## ------ API ------
    
    sub _run ($) {
      my ($self) = @_;
      my $is = $self->{input_stream};
      # XXX rewrite loop conditions
      my $length = @$is == 0 ? 0 : defined $is->[0]->[0] ? length $is->[0]->[0] : 0;
      my $in_offset = 0;
      {
        my $len = 10000;
        $len = $length - $in_offset if $in_offset + $len > $length;
        if ($len > 0) {
          $Input = substr $is->[0]->[0], $in_offset, $len;
        } elsif (@$is and not defined $is->[0]->[0]) {
          $Input = '';
          pos ($Input) = 0;
          $EOF = 1;
        } else {
          shift @$is;
          if (@$is) {
            if (defined $is->[0]->[0]) {
              $length = length $is->[0]->[0];
              $in_offset = 0;
              redo;
            } else {
              $Input = '';
              pos ($Input) = 0;
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
            $self->{saved_states} = {AllDeclsProcessed => $AllDeclsProcessed, AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, DTDMode => $DTDMode, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, StopProcessing => $StopProcessing, Temp => $Temp, TempIndex => $TempIndex, Token => $Token, XMLStandalone => $XMLStandalone};

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

            ($AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $DTDMode, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $StopProcessing, $Temp, $TempIndex, $Token, $XMLStandalone) = @{$self->{saved_states}}{qw(AllDeclsProcessed AnchoredIndex Attr CONTEXT Confident DI DTDMode EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State StopProcessing Temp TempIndex Token XMLStandalone)};
($AFE, $Callbacks, $Errors, $OE, $OP, $OpenCMGroups, $OpenMarkedSections, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP OpenCMGroups OpenMarkedSections TABLE_CHARS TEMPLATE_IMS Tokens)};
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
        my $index = $-[0];
        my $char = ord substr $input->[0], $index, 1;
        if ($char < 0x100) {
          push @$Errors, {type => 'control char', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        } elsif ($char < 0xE000) {
          push @$Errors, {type => 'char:surrogate', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        } else {
          push @$Errors, {type => 'nonchar', level => 'm',
                          text => (sprintf 'U+%04X', $char),
                          di => $DI, index => $index};
        }
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
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      $self->{document} = my $doc = $_[2];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (0);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];
      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$DTDMode = q{N/A};
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), OpenCMGroups => ($OpenCMGroups = []), OpenMarkedSections => ($OpenMarkedSections = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
$self->{saved_maps} = {DTDDefs => ($DTDDefs = {})};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $Confident = 1; # irrelevant
      $State = DATA_STATE;;
      $IM = INITIAL_IM;

      $self->{input_stream} = [];
      my $dids = $self->di_data_set;
      $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
      $dids->[$DI] ||= {} if $DI >= 0;
      $doc->manakai_set_source_location (['', $DI, 0]);

      $self->_feed_chars ($input) or die "Can't restart";
      $self->_feed_eof or die "Can't restart";

      $self->_cleanup_states;
      return;
    } # parse_char_string
  

    sub parse_chars_start ($$) {
      my ($self, $doc) = @_;

      $self->{input_stream} = [];
      $self->{document} = $doc;
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (0);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$DTDMode = q{N/A};
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), OpenCMGroups => ($OpenCMGroups = []), OpenMarkedSections => ($OpenMarkedSections = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
$self->{saved_maps} = {DTDDefs => ($DTDDefs = {})};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $Confident = 1; # irrelevant
      $State = DATA_STATE;;
      $IM = INITIAL_IM;

      my $dids = $self->di_data_set;
      $DI = @$dids || 1;
      $self->{di} = my $source_di = defined $self->{di} ? $self->{di} : $DI+1;
      $dids->[$source_di] ||= {} if $source_di >= 0; # the main data source of the input stream
      $dids->[$DI]->{map} = [[0, $source_di, 0]]; # the input stream
      $doc->manakai_set_source_location (['', $DI, 0]);

      $self->{saved_states} = {AllDeclsProcessed => $AllDeclsProcessed, AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, DTDMode => $DTDMode, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, StopProcessing => $StopProcessing, Temp => $Temp, TempIndex => $TempIndex, Token => $Token, XMLStandalone => $XMLStandalone};
      return;
    } # parse_chars_start
  

    sub parse_chars_feed ($$) {
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $DTDMode, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $StopProcessing, $Temp, $TempIndex, $Token, $XMLStandalone) = @{$self->{saved_states}}{qw(AllDeclsProcessed AnchoredIndex Attr CONTEXT Confident DI DTDMode EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State StopProcessing Temp TempIndex Token XMLStandalone)};
($AFE, $Callbacks, $Errors, $OE, $OP, $OpenCMGroups, $OpenMarkedSections, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP OpenCMGroups OpenMarkedSections TABLE_CHARS TEMPLATE_IMS Tokens)};

      $self->_feed_chars ($input) or die "Can't restart";

      $self->{saved_states} = {AllDeclsProcessed => $AllDeclsProcessed, AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, DTDMode => $DTDMode, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, StopProcessing => $StopProcessing, Temp => $Temp, TempIndex => $TempIndex, Token => $Token, XMLStandalone => $XMLStandalone};
      return;
    } # parse_chars_feed

    sub parse_chars_end ($) {
      my $self = $_[0];
      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $DTDMode, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $StopProcessing, $Temp, $TempIndex, $Token, $XMLStandalone) = @{$self->{saved_states}}{qw(AllDeclsProcessed AnchoredIndex Attr CONTEXT Confident DI DTDMode EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State StopProcessing Temp TempIndex Token XMLStandalone)};
($AFE, $Callbacks, $Errors, $OE, $OP, $OpenCMGroups, $OpenMarkedSections, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP OpenCMGroups OpenMarkedSections TABLE_CHARS TEMPLATE_IMS Tokens)};

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
      my $self = $_[0];

      $self->{document} = my $doc = $_[3];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (0);
      $doc->manakai_compat_mode ('no quirks');
      $self->{can_restart} = 1;

      PARSER: {
        $self->{input_stream} = [];
        $self->{nodes} = [$doc];
        $doc->remove_child ($_) for $doc->child_nodes->to_list;

        local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
        $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$DTDMode = q{N/A};
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), OpenCMGroups => ($OpenCMGroups = []), OpenMarkedSections => ($OpenMarkedSections = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
$self->{saved_maps} = {DTDDefs => ($DTDDefs = {})};
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
        my $dids = $self->di_data_set;
        $self->{di} = $DI = defined $self->{di} ? $self->{di} : @$dids || 1;
        $dids->[$DI] ||= {} if $DI >= 0;
        $doc->manakai_set_source_location (['', $DI, 0]);

        $State = DATA_STATE;;
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
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      delete $self->{parse_bytes_started};
      $self->{input_stream} = [];
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$DTDMode = q{N/A};
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), OpenCMGroups => ($OpenCMGroups = []), OpenMarkedSections => ($OpenMarkedSections = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
$self->{saved_maps} = {DTDDefs => ($DTDDefs = {})};
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      $State = DATA_STATE;;
      $IM = INITIAL_IM;

      my $dids = $self->di_data_set;
      $DI = @$dids || 1;
      $self->{di} = my $source_di = defined $self->{di} ? $self->{di} : $DI+1;
      $dids->[$DI]->{map} = [[0, $source_di, 0]]; # the input stream
      $dids->[$source_di] ||= {} if $source_di >= 0; # the main data source of the input stream
      $doc->manakai_set_source_location (['', $DI, 0]);
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

      my $input = [decode $self->{input_encoding}, $self->{byte_buffer}, Encode::FB_QUIET]; # XXXencoding

      $self->_feed_chars ($input) or return 0;

      return 1;
    } # _parse_bytes_start_parsing
  

    sub parse_bytes_start ($$$) {
      my $self = $_[0];

      $self->{byte_buffer} = '';
      $self->{byte_buffer_orig} = '';
      $self->{transport_encoding_label} = $_[1];

      $self->{document} = my $doc = $_[2];
      $doc->manakai_is_html (0);
      $self->{can_restart} = 1;

      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      PARSER: {
        $self->_parse_bytes_init;
        $self->_parse_bytes_start_parsing (no_body_data_yet => 1) or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          redo PARSER;
        };
      } # PARSER

      $self->{saved_states} = {AllDeclsProcessed => $AllDeclsProcessed, AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, DTDMode => $DTDMode, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, StopProcessing => $StopProcessing, Temp => $Temp, TempIndex => $TempIndex, Token => $Token, XMLStandalone => $XMLStandalone};
      return;
    } # parse_bytes_start
  

    ## The $args{start_parsing} flag should be set true if it has
    ## taken more than 500ms from the start of overall parsing
    ## process. XXX should this be a separate method?
    sub parse_bytes_feed ($$;%) {
      my ($self, undef, %args) = @_;

      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $DTDMode, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $StopProcessing, $Temp, $TempIndex, $Token, $XMLStandalone) = @{$self->{saved_states}}{qw(AllDeclsProcessed AnchoredIndex Attr CONTEXT Confident DI DTDMode EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State StopProcessing Temp TempIndex Token XMLStandalone)};
($AFE, $Callbacks, $Errors, $OE, $OP, $OpenCMGroups, $OpenMarkedSections, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP OpenCMGroups OpenMarkedSections TABLE_CHARS TEMPLATE_IMS Tokens)};

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

      $self->{saved_states} = {AllDeclsProcessed => $AllDeclsProcessed, AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, DTDMode => $DTDMode, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, StopProcessing => $StopProcessing, Temp => $Temp, TempIndex => $TempIndex, Token => $Token, XMLStandalone => $XMLStandalone};
      return;
    } # parse_bytes_feed

    sub parse_bytes_end ($) {
      my $self = $_[0];
      local ($AFE, $AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $DTDDefs, $DTDMode, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $OpenCMGroups, $OpenMarkedSections, $QUIRKS, $Scripting, $State, $StopProcessing, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens, $XMLStandalone);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AllDeclsProcessed, $AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $DTDMode, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $StopProcessing, $Temp, $TempIndex, $Token, $XMLStandalone) = @{$self->{saved_states}}{qw(AllDeclsProcessed AnchoredIndex Attr CONTEXT Confident DI DTDMode EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State StopProcessing Temp TempIndex Token XMLStandalone)};
($AFE, $Callbacks, $Errors, $OE, $OP, $OpenCMGroups, $OpenMarkedSections, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP OpenCMGroups OpenMarkedSections TABLE_CHARS TEMPLATE_IMS Tokens)};

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

  