
    package Web::HTML::Parser;
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
    our $AFE;our $AnchoredIndex;our $Attr;our $CONTEXT;our $Callbacks;our $Confident;our $DI;our $EOF;our $Errors;our $FORM_ELEMENT;our $FRAMESET_OK;our $HEAD_ELEMENT;our $IM;our $IframeSrcdoc;our $InForeign;our $Input;our $LastStartTagName;our $NEXT_ID;our $OE;our $OP;our $ORIGINAL_IM;our $Offset;our $QUIRKS;our $Scripting;our $State;our $TABLE_CHARS;our $TEMPLATE_IMS;our $Temp;our $TempIndex;our $Token;our $Tokens;
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
sub ELEMENT_NAME_STATE () { 47 }
sub ELEMENT_STATE () { 48 }
sub ENTITY_NAME_STATE () { 49 }
sub ENTITY_STATE () { 50 }
sub ENTITY_VALUE__DQ__STATE () { 51 }
sub ENTITY_VALUE__DQ__STATE_CR () { 52 }
sub ENTITY_VALUE__SQ__STATE () { 53 }
sub ENTITY_VALUE__SQ__STATE_CR () { 54 }
sub ENTITY_VALUE_CHARREF_STATE () { 55 }
sub NOTATION_NAME_STATE () { 56 }
sub NOTATION_STATE () { 57 }
sub PI_DATA_STATE () { 58 }
sub PI_DATA_STATE_CR () { 59 }
sub PI_STATE () { 60 }
sub PI_TARGET_QUESTION_STATE () { 61 }
sub PI_TARGET_STATE () { 62 }
sub AFTER_ATTLIST_ATTR_DEFAULT_STATE () { 63 }
sub AFTER_ATTLIST_ATTR_NAME_STATE () { 64 }
sub AFTER_ATTLIST_ATTR_TYPE_STATE () { 65 }
sub AFTER_DOCTYPE_INTERNAL_SUBSET_STATE () { 66 }
sub AFTER_DOCTYPE_NAME_STATE () { 67 }
sub AFTER_DOCTYPE_NAME_STATE_P () { 68 }
sub AFTER_DOCTYPE_NAME_STATE_PU () { 69 }
sub AFTER_DOCTYPE_NAME_STATE_PUB () { 70 }
sub AFTER_DOCTYPE_NAME_STATE_PUBL () { 71 }
sub AFTER_DOCTYPE_NAME_STATE_PUBLI () { 72 }
sub AFTER_DOCTYPE_NAME_STATE_S () { 73 }
sub AFTER_DOCTYPE_NAME_STATE_SY () { 74 }
sub AFTER_DOCTYPE_NAME_STATE_SYS () { 75 }
sub AFTER_DOCTYPE_NAME_STATE_SYST () { 76 }
sub AFTER_DOCTYPE_NAME_STATE_SYSTE () { 77 }
sub AFTER_DOCTYPE_PUBLIC_ID_STATE () { 78 }
sub AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE () { 79 }
sub AFTER_DOCTYPE_SYSTEM_ID_STATE () { 80 }
sub AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE () { 81 }
sub AFTER_DTD_MSC_STATE () { 82 }
sub AFTER_ENTITY_NAME_STATE () { 83 }
sub AFTER_ENTITY_PARAMETER_STATE () { 84 }
sub AFTER_NOTATION_NAME_STATE () { 85 }
sub AFTER_PI_TARGET_STATE () { 86 }
sub AFTER_PI_TARGET_STATE_CR () { 87 }
sub AFTER_AFTER_ALLOWED_TOKEN_LIST_STATE () { 88 }
sub AFTER_ALLOWED_TOKEN_LIST_STATE () { 89 }
sub AFTER_ALLOWED_TOKEN_STATE () { 90 }
sub AFTER_ATTR_NAME_STATE () { 91 }
sub AFTER_ATTR_VALUE__QUOTED__STATE () { 92 }
sub AFTER_CONTENT_MODEL_ELEMENT_STATE () { 93 }
sub AFTER_CONTENT_MODEL_GROUP_STATE () { 94 }
sub AFTER_MSC_STATE () { 95 }
sub AFTER_MSS_STATE () { 96 }
sub AFTER_STATUS_KEYWORD_STATE () { 97 }
sub ALLOWED_TOKEN_STATE () { 98 }
sub ATTR_NAME_STATE () { 99 }
sub ATTR_VALUE__DQ__STATE () { 100 }
sub ATTR_VALUE__DQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 101 }
sub ATTR_VALUE__DQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 102 }
sub ATTR_VALUE__DQ__STATE___CHARREF_HEX_NUMBER_STATE () { 103 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE () { 104 }
sub ATTR_VALUE__DQ__STATE___CHARREF_NUMBER_STATE () { 105 }
sub ATTR_VALUE__DQ__STATE___CHARREF_STATE () { 106 }
sub ATTR_VALUE__DQ__STATE_CR () { 107 }
sub ATTR_VALUE__SQ__STATE () { 108 }
sub ATTR_VALUE__SQ__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 109 }
sub ATTR_VALUE__SQ__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 110 }
sub ATTR_VALUE__SQ__STATE___CHARREF_HEX_NUMBER_STATE () { 111 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE () { 112 }
sub ATTR_VALUE__SQ__STATE___CHARREF_NUMBER_STATE () { 113 }
sub ATTR_VALUE__SQ__STATE___CHARREF_STATE () { 114 }
sub ATTR_VALUE__SQ__STATE_CR () { 115 }
sub ATTR_VALUE__UNQUOTED__STATE () { 116 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 117 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_DECIMAL_NUMBER_STATE () { 118 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_HEX_NUMBER_STATE () { 119 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE () { 120 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_NUMBER_STATE () { 121 }
sub ATTR_VALUE__UNQUOTED__STATE___CHARREF_STATE () { 122 }
sub ATTR_VALUE__UNQUOTED__STATE_CR () { 123 }
sub BEFORE_ATTLIST_ATTR_DEFAULT_STATE () { 124 }
sub BEFORE_ATTLIST_ATTR_NAME_STATE () { 125 }
sub BEFORE_ATTLIST_NAME_STATE () { 126 }
sub BEFORE_DOCTYPE_NAME_STATE () { 127 }
sub BEFORE_DOCTYPE_PUBLIC_ID_STATE () { 128 }
sub BEFORE_DOCTYPE_SYSTEM_ID_STATE () { 129 }
sub BEFORE_ELEMENT_NAME_STATE () { 130 }
sub BEFORE_ENTITY_NAME_STATE () { 131 }
sub BEFORE_ENTITY_TYPE_STATE () { 132 }
sub BEFORE_NOTATION_NAME_STATE () { 133 }
sub BEFORE_ALLOWED_TOKEN_STATE () { 134 }
sub BEFORE_ATTR_NAME_STATE () { 135 }
sub BEFORE_ATTR_VALUE_STATE () { 136 }
sub BEFORE_CONTENT_MODEL_ITEM_STATE () { 137 }
sub BEFORE_STATUS_KEYWORD_STATE () { 138 }
sub BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDS_STATE () { 139 }
sub BOGUS_DOCTYPE_STATE () { 140 }
sub BOGUS_AFTER_DOCTYPE_INTERNAL_SUBSET_STATE () { 141 }
sub BOGUS_COMMENT_STATE () { 142 }
sub BOGUS_COMMENT_STATE_CR () { 143 }
sub BOGUS_MARKUP_DECLARATION_STATE () { 144 }
sub CHARREF_IN_DATA_STATE () { 145 }
sub COMMENT_END_BANG_STATE () { 146 }
sub COMMENT_END_DASH_STATE () { 147 }
sub COMMENT_END_STATE () { 148 }
sub COMMENT_START_DASH_STATE () { 149 }
sub COMMENT_START_STATE () { 150 }
sub COMMENT_STATE () { 151 }
sub COMMENT_STATE_CR () { 152 }
sub CONTENT_MODEL_ELEMENT_STATE () { 153 }
sub DATA_STATE () { 154 }
sub DATA_STATE___CHARREF_BEFORE_HEX_NUMBER_STATE () { 155 }
sub DATA_STATE___CHARREF_DECIMAL_NUMBER_STATE () { 156 }
sub DATA_STATE___CHARREF_HEX_NUMBER_STATE () { 157 }
sub DATA_STATE___CHARREF_NAME_STATE () { 158 }
sub DATA_STATE___CHARREF_NUMBER_STATE () { 159 }
sub DATA_STATE___CHARREF_STATE () { 160 }
sub DATA_STATE___CHARREF_STATE_CR () { 161 }
sub DATA_STATE_CR () { 162 }
sub END_TAG_OPEN_STATE () { 163 }
sub IGNORED_SECTION_MARKED_DECLARATION_OPEN_STATE () { 164 }
sub IGNORED_SECTION_STATE () { 165 }
sub IGNORED_SECTION_TAG_STATE () { 166 }
sub IN_DTD_MSC_STATE () { 167 }
sub IN_MSC_STATE () { 168 }
sub IN_PIC_STATE () { 169 }
sub MDO_STATE () { 170 }
sub MDO_STATE__ () { 171 }
sub MDO_STATE_D () { 172 }
sub MDO_STATE_DO () { 173 }
sub MDO_STATE_DOC () { 174 }
sub MDO_STATE_DOCT () { 175 }
sub MDO_STATE_DOCTY () { 176 }
sub MDO_STATE_DOCTYP () { 177 }
sub MDO_STATE__5B () { 178 }
sub MDO_STATE__5BC () { 179 }
sub MDO_STATE__5BCD () { 180 }
sub MDO_STATE__5BCDA () { 181 }
sub MDO_STATE__5BCDAT () { 182 }
sub MDO_STATE__5BCDATA () { 183 }
sub PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_AFTER_SPACE_STATE () { 184 }
sub PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_STATE () { 185 }
sub PARAMETER_ENTITY_NAME_IN_DTD_STATE () { 186 }
sub PARAMETER_ENTITY_NAME_IN_ENTITY_VALUE_STATE () { 187 }
sub PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE () { 188 }
sub SELF_CLOSING_START_TAG_STATE () { 189 }
sub STATUS_KEYWORD_STATE () { 190 }
sub TAG_NAME_STATE () { 191 }
sub TAG_OPEN_STATE () { 192 }

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
      
$Element2Type->[HTMLNS]->{q@*@} = HTML_NS_ELS;
$Element2Type->[HTMLNS]->{q@applet@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
$Element2Type->[HTMLNS]->{q@audio@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
$Element2Type->[HTMLNS]->{q@button@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->[HTMLNS]->{q@fieldset@} = HTML_NS_ELS | BFIKLOST_ELS;
sub HEAD_EL () { HTML_NS_ELS | 32 } $Element2Type->[HTMLNS]->{q@head@} = HEAD_EL;
sub HTML_EL () { HTML_NS_ELS | 64 } $Element2Type->[HTMLNS]->{q@html@} = HTML_EL;
$Element2Type->[HTMLNS]->{q@img@} = HTML_NS_ELS | IMG_ELS;
$Element2Type->[HTMLNS]->{q@input@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->[HTMLNS]->{q@keygen@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->[HTMLNS]->{q@label@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->[HTMLNS]->{q@object@} = HTML_NS_ELS | OBJ_ELS;
$Element2Type->[HTMLNS]->{q@output@} = HTML_NS_ELS | BFIKLOST_ELS;
sub SELECT_EL () { HTML_NS_ELS | BFIKLOST_ELS } $Element2Type->[HTMLNS]->{q@select@} = SELECT_EL;
$Element2Type->[HTMLNS]->{q@style@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
sub TABLE_EL () { HTML_NS_ELS | 96 } $Element2Type->[HTMLNS]->{q@table@} = TABLE_EL;
sub TEMPLATE_EL () { HTML_NS_ELS | 128 } $Element2Type->[HTMLNS]->{q@template@} = TEMPLATE_EL;
$Element2Type->[HTMLNS]->{q@textarea@} = HTML_NS_ELS | BFIKLOST_ELS;
$Element2Type->[HTMLNS]->{q@video@} = HTML_NS_ELS | APP_AUD_STY_VID_ELS;
sub AFTER_ROOT_ELEMENT_IM () { 1 }
sub BEFORE_DOCTYPE_IM () { 2 }
sub BEFORE_IGNORED_NEWLINE_IM () { 3 }
sub BEFORE_ROOT_ELEMENT_IM () { 4 }
sub IN_ELEMENT_IM () { 5 }
sub IN_SUBSET_IM () { 6 }
sub INITIAL_IM () { 7 }
my $QPublicIDPrefixPattern = qr{};
my $LQPublicIDPrefixPattern = qr{};
my $QorLQPublicIDPrefixPattern = qr{};
my $QPublicIDs = {};
my $QSystemIDs = {};
my $OPPublicIDToSystemID = {};
my $OPPublicIDOnly = {};

      my $TCA = [undef,
        ## [1] after root element;ATTLIST
        sub {
          
        },
      ,
        ## [2] after root element;COMMENT
        sub {
          my $token = $_;

          push @$OP, ['comment', $token => $OE->[-1]->{id}];
        
        },
      ,
        ## [3] after root element;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'after-root-element-doctype',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
# XXX IF

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
          # XXX insert a processing instruction

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

            while ($token->{value} =~ /(.)/gs) {
              push @$Errors, {type => 'after-root-element-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
              $token->{index}++;
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

          push @$OP, ['comment', $token => $OE->[-1]->{id}];
        
        },
      ,
        ## [15] before DOCTYPE;DOCTYPE
        sub {
          # XXX insert a DOCTYPE

# XXX IF

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
          # XXX insert a processing instruction

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

            while ($token->{value} =~ /(.)/gs) {
              push @$Errors, {type => 'before-doctype-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
              $token->{index}++;
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

          push @$OP, ['comment', $token => $OE->[-1]->{id}];
        
        },
      ,
        ## [29] before root element;DOCTYPE
        sub {
          my $token = $_;
push @$Errors, {type => 'before-root-element-doctype',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
# XXX IF

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
          # XXX insert a processing instruction

        },
      ,
        ## [37] before root element;START-ELSE
        sub {
          my $token = $_;
# XXX insert an XML element for the token

# XXX IF


          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
        },
      ,
        ## [38] before root element;TEXT
        sub {
          my $token = $_;

            while ($token->{value} =~ /(.)/gs) {
              push @$Errors, {type => 'before-root-element-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
              $token->{index}++;
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
# XXX IF

        },
      ,
        ## [42] in element;ELEMENT
        sub {
          
        },
      ,
        ## [43] in element;END-ELSE
        sub {
          # XXX IF

        },
      ,
        ## [44] in element;END:
        sub {
          # XXX IF

        },
      ,
        ## [45] in element;ENTITY
        sub {
          
        },
      ,
        ## [46] in element;EOD
        sub {
          
        },
      ,
        ## [47] in element;EOF
        sub {
          my $token = $_;

          if ((die 'XXX COND') or 
(die 'XXX COND')) {
            push @$Errors, {type => 'in-element-eof',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
          }
        

          $IM = AFTER_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |after root element| ($IM)";
        
        },
      ,
        ## [48] in element;NOTATION
        sub {
          
        },
      ,
        ## [49] in element;PI
        sub {
          # XXX insert a processing instruction

        },
      ,
        ## [50] in element;START-ELSE
        sub {
          my $token = $_;
# XXX insert an XML element for the token

# XXX IF


          if ($token->{self_closing_flag}) {
            push @$Errors, {type => 'nestc',
                                            level => 'm',
                                            text => $token->{tag_name},di => $token->{di},
                                index => $token->{index}};
          }
        
        },
      ,
        ## [51] in element;TEXT
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
        ## [52] in subset;ATTLIST
        sub {
          # XXX process an ATTLIST token

        },
      ,
        ## [53] in subset;COMMENT
        sub {
          return;
        },
      ,
        ## [54] in subset;DOCTYPE
        sub {
          
        },
      ,
        ## [55] in subset;ELEMENT
        sub {
          # XXX process an ELEMENT token

        },
      ,
        ## [56] in subset;END-ELSE
        sub {
          
        },
      ,
        ## [57] in subset;ENTITY
        sub {
          # XXX process an ENTITY token

        },
      ,
        ## [58] in subset;EOD
        sub {
          # XXX IF

# XXX IF

        },
      ,
        ## [59] in subset;EOF
        sub {
          push @$OP, ['stop-parsing'];
        },
      ,
        ## [60] in subset;NOTATION
        sub {
          # XXX process a NOTATION token

        },
      ,
        ## [61] in subset;PI
        sub {
          # XXX insert a processing instruction

        },
      ,
        ## [62] in subset;START-ELSE
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
        ## [63] in subset;TEXT
        sub {
          my $token = $_;

            while ($token->{value} =~ /(.)/gs) {
              push @$Errors, {type => 'in-subset-char',
                                            level => 'm',
                                            di => $token->{di},
                                index => $token->{index}};
              $token->{index}++;
            }
            
          
        },
      ,
        ## [64] initial;ATTLIST
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [65] initial;COMMENT
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [66] initial;DOCTYPE
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [67] initial;ELEMENT
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [68] initial;END-ELSE
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [69] initial;ENTITY
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [70] initial;EOD
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [71] initial;EOF
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [72] initial;NOTATION
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [73] initial;PI
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [74] initial;PI:xml
        sub {
          # XXX process an XML declaration


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        
        },
      ,
        ## [75] initial;START-ELSE
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ,
        ## [76] initial;TEXT
        sub {
          my $token = $_;
# XXX the XML declaration is missing


          $IM = BEFORE_ROOT_ELEMENT_IM;
          #warn "Insertion mode changed to |before root element| ($IM)";
        

        goto &{$ProcessIM->[$IM]->[$token->{type}]->[$token->{tn}]};
      
        },
      ];
    
$ProcessIM = [undef,
[undef, [$TCA->[1]], [$TCA->[3]], [$TCA->[4]], [$TCA->[6]], [$TCA->[9]], [$TCA->[2]], [$TCA->[5], $TCA->[5]], [$TCA->[7]], [$TCA->[8]], [$TCA->[10]], [$TCA->[11], $TCA->[11]], [$TCA->[12]]],
[undef, [$TCA->[13]], [$TCA->[15]], [$TCA->[16]], [$TCA->[18]], [$TCA->[21]], [$TCA->[14]], [$TCA->[17], $TCA->[17]], [$TCA->[19]], [$TCA->[20]], [$TCA->[22]], [$TCA->[23], $TCA->[23]], [$TCA->[24]]],
[undef, [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25], $TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25]], [$TCA->[25], $TCA->[25]], [$TCA->[26]]],
[undef, [$TCA->[27]], [$TCA->[29]], [$TCA->[30]], [$TCA->[32]], [$TCA->[35]], [$TCA->[28]], [$TCA->[31], $TCA->[31]], [$TCA->[33]], [$TCA->[34]], [$TCA->[36]], [$TCA->[37], $TCA->[37]], [$TCA->[38]]],
[undef, [$TCA->[39]], [$TCA->[41]], [$TCA->[42]], [$TCA->[45]], [$TCA->[48]], [$TCA->[40]], [$TCA->[43], $TCA->[43]], [$TCA->[46]], [$TCA->[47]], [$TCA->[49]], [$TCA->[50], $TCA->[50]], [$TCA->[51]]],
[undef, [$TCA->[52]], [$TCA->[54]], [$TCA->[55]], [$TCA->[57]], [$TCA->[60]], [$TCA->[53]], [$TCA->[56], $TCA->[56]], [$TCA->[58]], [$TCA->[59]], [$TCA->[61]], [$TCA->[62], $TCA->[62]], [$TCA->[63]]],
[undef, [$TCA->[64]], [$TCA->[66]], [$TCA->[67]], [$TCA->[69]], [$TCA->[72]], [$TCA->[65]], [$TCA->[68], $TCA->[68]], [$TCA->[70]], [$TCA->[71]], [$TCA->[73]], [$TCA->[75], $TCA->[75]], [$TCA->[76]]]];
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
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'attlist-attribute-default-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\"])/gcs) {

          push @$Errors, {type => 'attlist-attribute-default-0022', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\'])/gcs) {

          push @$Errors, {type => 'attlist-attribute-default-0027', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'attlist-attribute-default-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to the current input character.

} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<name>} = q@�@;
$State = ATTLIST_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'attlist-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

          push @$Errors, {type => 'before-attlist-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'attlist-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Set the current token's name to the current input character.

$State = ATTLIST_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'attlist-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
# XXX

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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTLIST_STATE;
} elsif ($Input =~ /\G([t])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ELEMENT_STATE;
} elsif ($Input =~ /\G([t])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ENTITY_STATE;
} elsif ($Input =~ /\G([y])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = NOTATION_STATE;
} elsif ($Input =~ /\G([n])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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
# XXX set-DOCTYPE-mode

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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {

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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
# XXX
$State = IN_DTD_MSC_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {

          push @$Errors, {type => 'element-name-0028', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
## XXX Create a content model group and append it to the list of content model groups of the current token.

} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'element-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<name>} = q@�@;
$State = ELEMENT_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'element-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

          push @$Errors, {type => 'before-element-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'element-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Set the current token's name to the current input character.

$State = ELEMENT_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'element-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[ENTITY_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ENTITY_TYPE_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_DECLARATION_OR_REFERENCE_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'entity-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<name>} = q@�@;
$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'entity-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

          push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'entity-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'entity-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'notation-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Set the current token's name to the current input character.

$State = NOTATION_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'notation-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
pos ($Input)--;
} elsif ($Input =~ /\G([\])/gcs) {

          push @$Errors, {type => 'pi-ws', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
$Token->{q<data>} .= q@
@;
$State = BOGUS_COMMENT_STATE_CR;
pos ($Input)--;
} elsif ($Input =~ /\G([\?])/gcs) {

          push @$Errors, {type => 'pi-003f', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

        $Token = {type => COMMENT_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<data>} = q@?@;
$State = BOGUS_COMMENT_STATE;
$Token->{q<data>} .= $1;
pos ($Input)--;
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
      
pos ($Input)--;
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
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\"])/gcs) {
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to the current input character.

} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$State = ATTLIST_ATTR_TYPE_STATE;
$Attr->{q<declared_type>} = $1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\(])/gcs) {
$State = BEFORE_ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'NULL', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
## XXX Set the current attribute definition's value to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-attlist-attribute-type-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-attlist-attribute-type-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} = $1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_DOCTYPE_INTERNAL_SUBSET_STATE] = sub {
if ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
# XXX emit-end-of-DOCTYPE

} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-doctype-internal-subset-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_AFTER_DOCTYPE_INTERNAL_SUBSET_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DATA_STATE;
# XXX emit-end-of-DOCTYPE


        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE;
} elsif ($Input =~ /\G([c])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE;
} elsif ($Input =~ /\G([m])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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
# XXX set-DOCTYPE-mode

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
# XXX set-DOCTYPE-mode

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
# XXX set-DOCTYPE-mode

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
if ($Input =~ /\G([\	\\ \
\])/gcs) {

          push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

          push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DOCTYPE_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-dtd-msc-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX decrement-marked-section-nesting-level

$State = DTD_STATE;
} elsif ($Input =~ /\G([\]])/gcs) {

          push @$Errors, {type => 'after-dtd-msc-005d', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} else {
if ($EOF) {

          push @$Errors, {type => 'after-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-entity-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX If the next several characters are a case-sensitive match for the string "PUBLIC", then consume those characters and switch to the after ENTITY public keyword state.

## XXX Otherwise, if the next several characters are an ASCII case-insensitive match for the word "PUBLIC", then this is a parse error; consume those characters and switch to the after ENTITY public keyword state.

## XXX Otherwise, if the next several characters are a case-sensitive match for the string "SYSTEM", then consume those characters and switch to the after ENTITY system keyword state.

## XXX Otherwise, if the next several characters are an ASCII case-insensitive match for the word "SYSTEM", then this is a parse error; consume those characters and switch to the after ENTITY system keyword state.

## XXX Otherwise:


          push @$Errors, {type => 'after-entity-name-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-notation-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX If the next several characters are a case-sensitive match for the string "PUBLIC", then consume those characters and switch to the after NOTATION public keyword state.

## XXX Otherwise, if the next several characters are an ASCII case-insensitive match for the word "PUBLIC", then this is a parse error; consume those characters and switch to the after NOTATION public keyword state.

## XXX Otherwise, if the next several characters are a case-sensitive match for the string "SYSTEM", then consume those characters and switch to the after NOTATION system keyword state.

## XXX Otherwise, if the next several characters are an ASCII case-insensitive match for the word "SYSTEM", then this is a parse error; consume those characters and switch to the after NOTATION system keyword state.

## XXX Otherwise:


          push @$Errors, {type => 'after-notation-name-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;
push @$Tokens, $Token;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'NULL', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
## XXX Set the current attribute definition's value to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-after-allowed-token-list-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} = $1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

          push @$Errors, {type => 'NULL', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
## XXX Set the current attribute definition's value to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\"])/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__DQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\#])/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BEFORE_ATTLIST_ATTR_DEFAULT_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__SQ__STATE;
$Attr->{q<value>} = [['', $Attr->{di}, $Attr->{index}]];
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        

          push @$Errors, {type => 'after-after-allowed-token-list-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = ATTR_VALUE__UNQUOTED__STATE;
$Attr->{q<value>} = $1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-allowed-token-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
push @$Tokens, $Token;
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {

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
$StateActions->[AFTER_CONTENT_MODEL_ELEMENT_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
$State = AFTER_CONTENT_MODEL_GROUP_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {
## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
## XXX Switch to the no cm group or error, bogus markup declaration state.

$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\|])/gcs) {
## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\(])/gcs) {

          push @$Errors, {type => 'after-content-model-element-0028', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\*])/gcs) {

          push @$Errors, {type => 'after-content-model-element-002a', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {

          push @$Errors, {type => 'after-content-model-element-002b', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\?])/gcs) {

          push @$Errors, {type => 'after-content-model-element-003f', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-content-model-element-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_CONTENT_MODEL_GROUP_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\])/gcs) {
## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

} elsif ($Input =~ /\G([\*])/gcs) {
## XXX If the list of content model groups of the current token is not empty, set the 's repetition to the current input character.

## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {
## XXX If the list of content model groups of the current token is not empty, set the 's repetition to the current input character.

## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {
## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
## XXX Switch to the no cm group or error, bogus markup declaration state.

$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\?])/gcs) {
## XXX If the list of content model groups of the current token is not empty, set the 's repetition to the current input character.

## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
## XXX Switch to the close cm group or error(-1), bogus markup declaration state.

## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
\])/gcs) {
$State = BEFORE_STATUS_KEYWORD_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {

          push @$Errors, {type => 'before-status-keyword-005b', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX increment-marked-section-nesting-level

$State = IGNORED_SECTION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the temporary buffer to the current input character.

$State = STATUS_KEYWORD_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[AFTER_STATUS_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {
## XXX If the temporary buffer is equal to "INCLUDE", increment the marked section nesting level of the parser by one (1) and switch to the DTD state.

## XXX Otherwise:

## XXX If the temporary buffer is not equal to "IGNORE", parse error.

# XXX increment-marked-section-nesting-level

$State = IGNORED_SECTION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'after-status-keyword-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX increment-marked-section-nesting-level

$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
## XXX Append a U+FFFD REPLACEMENT CHARACTER character to the current allowed token's value.

} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'allowed-token-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Append the current input character to the current allowed token's value.

} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\=\>ABCDEFGHJKQRVWZILMNOPSTUXY\ \"\'\<]+)/gcs) {
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy]+)/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__DQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy]+)/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__SQ__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY]+)/gcs) {
$Temp .= $1;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy]+)/gcs) {
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
$Temp .= $1;
$State = ATTR_VALUE__UNQUOTED__STATE___CHARREF_NAME_STATE;
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
$Attr->{q<default_type>} .= $1;
$State = ATTLIST_ATTR_DEFAULT_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_ATTLIST_ATTR_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to a U+FFFD REPLACEMENT CHARACTER character.

} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Create an attribute definition and append it to the list of attribute definitions of the current token.

$State = ATTLIST_ATTR_NAME_STATE;
## XXX Set the current attribute definition's name to the current input character.

} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<name>} = q@�@;
$State = ATTLIST_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'before-attlist-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the current token's name to the current input character.

$State = ATTLIST_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_DOCTYPE_NAME_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {

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
# XXX set-DOCTYPE-mode

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
$StateActions->[BEFORE_ELEMENT_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
$Token->{q<name>} = q@�@;
$State = ELEMENT_NAME_STATE;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'before-element-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the current token's name to the current input character.

$State = ELEMENT_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_NOTATION_NAME_STATE] = sub {
if ($Input =~ /\G([\ ])/gcs) {
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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the current token's name to the current input character.

$State = NOTATION_NAME_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
## XXX Set the current allowed token's value to a U+FFFD REPLACEMENT CHARACTER character.

$State = ALLOWED_TOKEN_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {

          push @$Errors, {type => 'before-allowed-token-0029', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = AFTER_ALLOWED_TOKEN_LIST_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {

          push @$Errors, {type => 'before-allowed-token-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\|])/gcs) {

          push @$Errors, {type => 'before-allowed-token-007c', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Create an allowed token and append it to the list of allowed tokens of the current attribute definition.

## XXX Set the current allowed token's value to the current input character.

$State = ALLOWED_TOKEN_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G\/\>/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
$Token->{q<self_closing_flag>} = 1;
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G\>/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
push @$Tokens, $Token;
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
## XXX Create a content model group and append it to the list of content model groups of the current token.

} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'NULL', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Create a content model element and append it to the current content model container.

## XXX Set the 's name to a U+FFFD REPLACEMENT CHARACTER character.

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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\?])/gcs) {

          push @$Errors, {type => 'before-content-model-item-003f', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {

          push @$Errors, {type => 'before-content-model-item-007c', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Create a content model element and append it to the current content model container.

## XXX Set the 's name to the current input character.

$State = CONTENT_MODEL_ELEMENT_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[BEFORE_STATUS_KEYWORD_STATE] = sub {
if ($Input =~ /\G([\	\\ \
\]+)/gcs) {
} elsif ($Input =~ /\G([\%])/gcs) {
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {

          push @$Errors, {type => 'before-status-keyword-005b', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX increment-marked-section-nesting-level

$State = IGNORED_SECTION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Set the temporary buffer to the current input character.

$State = STATUS_KEYWORD_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
# XXX set-DOCTYPE-mode

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
$StateActions->[BOGUS_DOCTYPE_STATE] = sub {
if ($Input =~ /\G([^\>\[]+)/gcs) {

} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\[])/gcs) {
$State = DTD_STATE;
$Token->{q<has_internal_subset_flag>} = 1;
# XXX set-DOCTYPE-mode

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
# XXX emit-end-of-DOCTYPE

} else {
if ($EOF) {
$State = DATA_STATE;
# XXX emit-end-of-DOCTYPE


        push @$Tokens, {type => END_OF_FILE_TOKEN, tn => 0,
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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
        
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\)])/gcs) {
$State = AFTER_CONTENT_MODEL_GROUP_STATE;
} elsif ($Input =~ /\G([\*])/gcs) {
## XXX Set the 's repetition to the current input character.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\+])/gcs) {
## XXX Set the 's repetition to the current input character.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\,])/gcs) {
## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
## XXX Switch to the no cm group or error, bogus markup declaration state.

$State = DTD_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([\?])/gcs) {
## XXX Set the 's repetition to the current input character.

$State = AFTER_CONTENT_MODEL_ELEMENT_STATE;
} elsif ($Input =~ /\G([\|])/gcs) {
## XXX Append the current input character as a content model separator to the current content model container.

$State = BEFORE_CONTENT_MODEL_ITEM_STATE;
} elsif ($Input =~ /\G([\ ])/gcs) {

          push @$Errors, {type => 'NULL', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
## XXX Append a U+FFFD REPLACEMENT CHARACTER character to the 's name.

} elsif ($Input =~ /\G([\(])/gcs) {

          push @$Errors, {type => 'content-model-element-0028', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = BOGUS_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G(.)/gcs) {
## XXX Append the current input character to the 's name.

} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY]+)/gcs) {
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
        
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy]+)/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
        
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
        
} elsif ($Input =~ /\G([abcdefghjkqrvwzilmnopstuxy])/gcs) {
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
$StateActions->[IGNORED_SECTION_MARKED_DECLARATION_OPEN_STATE] = sub {
if ($Input =~ /\G([^\[]+)/gcs) {

} elsif ($Input =~ /\G([\[])/gcs) {
## XXX Increment the marked section nesting level by one (1).

$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[IGNORED_SECTION_STATE] = sub {
if ($Input =~ /\G([^\<]+)/gcs) {

} elsif ($Input =~ /\G([\<])/gcs) {
$State = IGNORED_SECTION_TAG_STATE;
} else {
if ($EOF) {
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[IGNORED_SECTION_TAG_STATE] = sub {
if ($Input =~ /\G([^\!]+)/gcs) {

} elsif ($Input =~ /\G([\!])/gcs) {
$State = IGNORED_SECTION_MARKED_DECLARATION_OPEN_STATE;
} else {
if ($EOF) {
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[IN_DTD_MSC_STATE] = sub {
if ($Input =~ /\G([\]])/gcs) {
$State = AFTER_DTD_MSC_STATE;
} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {

          push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {

          push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DOCTYPE_TAG_STATE;
} elsif ($Input =~ /\G(.)/gcs) {

          push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} else {
if ($EOF) {

          push @$Errors, {type => 'in-dtd-msc-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DOCTYPE_STATE;
} elsif ($Input =~ /\G([e])/gcs) {

          push @$Errors, {type => 'keyword-wrong-case', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
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
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} elsif ($Input =~ /\G([\&])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\`])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$Token->{q<is_parameter_entity_flag>} = 1;

          push @$Errors, {type => 'before-entity-name-003e', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G(.)/gcs) {
$State = PARAMETER_ENTITY_NAME_IN_MARKUP_DECLARATION_STATE;
} else {
if ($EOF) {
$Token->{q<is_parameter_entity_flag>} = 1;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
## XXX Set the current token's name to the current input character.

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
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\'])/gcs) {

          push @$Errors, {type => 'parameter-entity-declaration-or-reference-0027', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\<])/gcs) {

          push @$Errors, {type => 'parameter-entity-declaration-or-reference-003c', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

$State = ENTITY_NAME_STATE;
} elsif ($Input =~ /\G([\=])/gcs) {

          push @$Errors, {type => 'parameter-entity-declaration-or-reference-003d', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G([\`])/gcs) {

          push @$Errors, {type => 'parameter-entity-declaration-or-reference-0060', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<is_parameter_entity_flag>} = 1;
## XXX Set the current token's name to the current input character.

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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
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
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} elsif ($Input =~ /\G([\'])/gcs) {

          push @$Errors, {type => 'parameter-entity-name-in-dtd-0027', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$State = DTD_STATE;

          push @$Errors, {type => 'dtd-else', level => 'm',
                          di => $DI, index => $Offset + (pos $Input) - 1};
        
$Token->{q<internal_subset_tainted_flag>} = 1;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

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
push @$Tokens, $Token;
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
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {

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
$StateActions->[STATUS_KEYWORD_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\%\[]+)/gcs) {
$Temp .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = AFTER_STATUS_KEYWORD_STATE;
} elsif ($Input =~ /\G([\%])/gcs) {
# XXX set-original-state

$State = PARAMETER_ENTITY_NAME_IN_DTD_STATE;
} elsif ($Input =~ /\G([\[])/gcs) {
## XXX If the temporary buffer is equal to "INCLUDE", increment the marked section nesting level of the parser by one (1) and switch to the DTD state.

## XXX Otherwise:

## XXX If the temporary buffer is not equal to "IGNORE", parse error.

# XXX increment-marked-section-nesting-level

$State = IGNORED_SECTION_STATE;
} else {
if ($EOF) {

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
$State = DTD_STATE;

          push @$Errors, {type => 'parser:EOF', level => 'm',
                          di => $DI, index => $Offset + (pos $Input)};
        
## XXX parse error-and-switch-and-emit-eod-and-reconsume

} else {
return 1;
}
}
return 0;
};
$StateActions->[TAG_NAME_STATE] = sub {
if ($Input =~ /\G([^\	\\ \
\\/\>ABCDEFGHJKQRVWZILMNOPSTUXY\ ]+)/gcs) {
$Token->{q<tag_name>} .= $1;

} elsif ($Input =~ /\G([\	\\ \
\])/gcs) {
$State = BEFORE_ATTR_NAME_STATE;
} elsif ($Input =~ /\G([\/])/gcs) {
$State = SELF_CLOSING_START_TAG_STATE;
} elsif ($Input =~ /\G([\>])/gcs) {
$State = DATA_STATE;
push @$Tokens, $Token;
} elsif ($Input =~ /\G([ABCDEFGHJKQRVWZILMNOPSTUXY])/gcs) {
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
push @$Tokens, $Token;
} elsif ($Input =~ /\G([^\ \	\
\\\ \!\/\>\?])([^\ \	\
\\\ \/\>A-Z]*)\>/gcs) {

        $Token = {type => START_TAG_TOKEN, tn => 0,
                  di => $DI, index => $AnchoredIndex};
      
$Token->{q<tag_name>} = $1;
$State = TAG_NAME_STATE;
$Token->{q<tag_name>} .= $2;
$State = DATA_STATE;
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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
push @$Tokens, $Token;
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

  my $nodes = $self->{nodes};
  for my $op (@$ops) {
    if ($op->[0] eq 'insert' or
        $op->[0] eq 'insert-foster' or
        $op->[0] eq 'create') {
      my $data = $op->[1];
      my $el = $doc->create_element_ns
          ($NSToURL->[$data->{ns}], [undef, $data->{local_name}]);
      $el->manakai_set_source_location (['', $data->{di}, $data->{index}]);
      ## Note that $data->{ns} can be 0.
      for my $attr (@{$data->{attr_list} or []}) {
        $el->manakai_set_attribute_indexed_string_ns
            (@{$attr->{name_args}} => $attr->{value}); # IndexedString
      }
      if ($data->{ns} == HTMLNS and $data->{local_name} eq 'template') {
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
    } elsif ($op->[0] eq 'doctype') {
      my $data = $op->[1];
      my $dt = $doc->implementation->create_document_type
          (defined $data->{name} ? $data->{name} : '',
           defined $data->{public_identifier} ? $data->{public_identifier} : '',
           defined $data->{system_identifier} ? $data->{system_identifier} : '');
      $dt->manakai_set_source_location (['', $data->{di}, $data->{index}]);
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
            $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};

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

            ($AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr CONTEXT Confident DI EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp TempIndex Token)};
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
      $doc->manakai_is_html (1);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];
      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
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
      $doc->manakai_is_html (1);
      $doc->manakai_compat_mode ('no quirks');
      $doc->remove_child ($_) for $doc->child_nodes->to_list;
      $self->{nodes} = [$doc];

      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $FRAMESET_OK = 1;
$NEXT_ID = 1;
$Offset = 0;
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
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

      $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};
      return;
    } # parse_chars_start

    sub parse_chars_feed ($$) {
      my $self = $_[0];
      my $input = [$_[1]]; # string copy

      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr CONTEXT Confident DI EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp TempIndex Token)};
($AFE, $Callbacks, $Errors, $OE, $OP, $TABLE_CHARS, $TEMPLATE_IMS, $Tokens) = @{$self->{saved_lists}}{qw(AFE Callbacks Errors OE OP TABLE_CHARS TEMPLATE_IMS Tokens)};

      $self->_feed_chars ($input) or die "Can't restart";

      $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};
      return;
    } # parse_chars_feed

    sub parse_chars_end ($) {
      my $self = $_[0];
      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr CONTEXT Confident DI EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp TempIndex Token)};
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
      my $self = $_[0];

      $self->{document} = my $doc = $_[3];
      $self->{IframeSrcdoc} = $doc->manakai_is_srcdoc;
      $doc->manakai_is_html (1);
      $doc->manakai_compat_mode ('no quirks');
      $self->{can_restart} = 1;

      PARSER: {
        $self->{input_stream} = [];
        $self->{nodes} = [$doc];
        $doc->remove_child ($_) for $doc->child_nodes->to_list;

        local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
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
$self->{saved_lists} = {AFE => ($AFE = []), Callbacks => ($Callbacks = []), Errors => ($Errors = []), OE => ($OE = []), OP => ($OP = []), TABLE_CHARS => ($TABLE_CHARS = []), TEMPLATE_IMS => ($TEMPLATE_IMS = []), Tokens => ($Tokens = [])};
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
      #XXXxml $self->{is_xml} = 1;

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
      $doc->manakai_is_html (1);
      $self->{can_restart} = 1;

      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      PARSER: {
        $self->_parse_bytes_init;
        $self->_parse_bytes_start_parsing (no_body_data_yet => 1) or do {
          $self->{byte_buffer} = $self->{byte_buffer_orig};
          redo PARSER;
        };
      } # PARSER

      $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};
      return;
    } # parse_bytes_start

    ## The $args{start_parsing} flag should be set true if it has
    ## taken more than 500ms from the start of overall parsing
    ## process. XXX should this be a separate method?
    sub parse_bytes_feed ($$;%) {
      my ($self, undef, %args) = @_;

      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr CONTEXT Confident DI EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp TempIndex Token)};
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

      $self->{saved_states} = {AnchoredIndex => $AnchoredIndex, Attr => $Attr, CONTEXT => $CONTEXT, Confident => $Confident, DI => $DI, EOF => $EOF, FORM_ELEMENT => $FORM_ELEMENT, FRAMESET_OK => $FRAMESET_OK, HEAD_ELEMENT => $HEAD_ELEMENT, IM => $IM, LastStartTagName => $LastStartTagName, NEXT_ID => $NEXT_ID, ORIGINAL_IM => $ORIGINAL_IM, Offset => $Offset, QUIRKS => $QUIRKS, State => $State, Temp => $Temp, TempIndex => $TempIndex, Token => $Token};
      return;
    } # parse_bytes_feed

    sub parse_bytes_end ($) {
      my $self = $_[0];
      local ($AFE, $AnchoredIndex, $Attr, $CONTEXT, $Callbacks, $Confident, $DI, $EOF, $Errors, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $IframeSrcdoc, $InForeign, $Input, $LastStartTagName, $NEXT_ID, $OE, $OP, $ORIGINAL_IM, $Offset, $QUIRKS, $Scripting, $State, $TABLE_CHARS, $TEMPLATE_IMS, $Temp, $TempIndex, $Token, $Tokens);
      $IframeSrcdoc = $self->{IframeSrcdoc};
$Scripting = $self->{Scripting};
      ($AnchoredIndex, $Attr, $CONTEXT, $Confident, $DI, $EOF, $FORM_ELEMENT, $FRAMESET_OK, $HEAD_ELEMENT, $IM, $LastStartTagName, $NEXT_ID, $ORIGINAL_IM, $Offset, $QUIRKS, $State, $Temp, $TempIndex, $Token) = @{$self->{saved_states}}{qw(AnchoredIndex Attr CONTEXT Confident DI EOF FORM_ELEMENT FRAMESET_OK HEAD_ELEMENT IM LastStartTagName NEXT_ID ORIGINAL_IM Offset QUIRKS State Temp TempIndex Token)};
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

  