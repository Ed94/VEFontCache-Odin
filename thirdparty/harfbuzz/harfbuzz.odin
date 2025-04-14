/*
NOTE(Ed): These bindings are currently partial for usage in a VE Font Cache port.
*/
package harfbuzz

import "core:c"

when ODIN_OS == .Windows {
	// @(extra_linker_flags="/NODEFAULTLIB:msvcrt")
	// foreign import harfbuzz "./lib/win64/libharfbuzz-0.dll"
	foreign import harfbuzz "./lib/win64/harfbuzz.lib"
	// foreign import harfbuzz "./lib/win64/libharfbuzz.a"
}
else when ODIN_OS == .Linux {
	// foreign import harfbuzz "./lib/linux64/libharfbuzz.so"
	foreign import harfbuzz "system:harfbuzz"
}
else when ODIN_OS == .Darwin {
	// foreign import harfbuzz { "./lib/osx/libharfbuzz.so" }
	foreign import harfbuzz "system:harfbuzz"
}

Buffer        :: distinct rawptr     // hb_buffer_t*
Blob          :: distinct rawptr     // hb_blob_t*
Codepoint     :: distinct c.uint32_t // hb_codepoint_t
Face          :: distinct rawptr     // hb_face_t*
Font          :: distinct rawptr     // hb_font_t*
Language      :: distinct rawptr     // hb_language_t*
Mask          :: distinct c.uint32_t // hb_mask_t
Position      :: distinct c.uint32_t // hb_position_t
Tag           :: distinct c.uint32_t // hb_tag_t
Unicode_Funcs :: distinct rawptr     // hb_unicode_funcs_t*

hb_var_int_t :: struct #raw_union {
	u32 : c.uint32_t,
	i32 : c.int32_t,
	u16 : [2]c.uint16_t,
	i16 : [2]c.int16_t,
	u8  : [4]c.uint8_t,
	i8  : [4]c.int8_t,
}

Feature :: struct {
	tag   : Tag,
	value : c.uint32_t,
	start : c.uint,
	end   : c.uint,
}

Glyph_Info :: struct {
	codepoint : Codepoint,
	 /*< private >*/
	mask      : Mask,
	/*< public >*/
	cluster   : c.uint32_t,

	/*< private >*/
	var1 : hb_var_int_t,
	var2 : hb_var_int_t,
}

Glyph_Position :: struct {
	x_advance : Position,
	y_advance : Position,
	x_offset  : Position,
	y_offset  : Position,

	/*< private >*/
	var : hb_var_int_t,
}

Segment_Properties :: struct {
	direction : Direction,
	script    : Script,
	language  : Language,
	reserved1 : rawptr,
	reserved2 : rawptr,
}

Buffer_Content_Type :: enum c.uint {
	INVALID = 0,
  UNICODE,
  GLYPHS
}

Direction :: enum c.uint {
	INVALID = 0,
	LGR     = 4,
	RTL,
	TTB,
	BTT,
}

Script :: enum u32 {
	// ID = ((hb_tag_t)((((uint32_t)(c1)&0xFF)<<24)|(((uint32_t)(c2)&0xFF)<<16)|(((uint32_t)(c3)&0xFF)<<8)|((uint32_t)(c4)&0xFF))),

	// 1.1
	COMMON    = ( u32('Z') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('y') & 0xFF ) << 8 | ( u32('y') & 0xFF ),
	INHERITED = ( u32('Z') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('h') & 0xFF ),

	// 5.0
	UNKNOWN = ( u32('Z') & 0xFF ) << 24 | ( u32('z') & 0xFF ) << 16 | ( u32('z') & 0xFF ) << 8 | ( u32('z') & 0xFF ),

	// 1.1
	ARABIC     = ( u32('A') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	ARMENIAN   = ( u32('A') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('n') & 0xFF ),
	BENGALI    = ( u32('B') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	CYRILLIC   = ( u32('C') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('l') & 0xFF ),
	DEVANAGARI = ( u32('D') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('v') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	GEORGIAN   = ( u32('G') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	GREEK      = ( u32('G') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('e') & 0xFF ) << 8 | ( u32('k') & 0xFF ),
	GUJARATI   = ( u32('G') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('j') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	GURMUKHI   = ( u32('G') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('u') & 0xFF ),
	HANGUL     = ( u32('H') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	HAN        = ( u32('H') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	HEBREW     = ( u32('H') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('b') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	HIRAGANA   = ( u32('H') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	KANNADA    = ( u32('K') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('d') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	KATAKANA   = ( u32('K') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	LAO        = ( u32('L') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	LATIN      = ( u32('L') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('n') & 0xFF ),
	MALAYALAN  = ( u32('M') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('y') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	ORIYA      = ( u32('O') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('y') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	TAMIL      = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('l') & 0xFF ),
	TELUGU     = ( u32('T') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('u') & 0xFF ),
	THAI       = ( u32('T') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('i') & 0xFF ),

	// 2.0
	TIBETAN = ( u32('T') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('b') & 0xFF ) << 8 | ( u32('t') & 0xFF ),

	// 3.0
	BOPOMOFO           = ( u32('B') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('p') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	BRAILLE            = ( u32('B') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	CANADIAN_SYLLABICS = ( u32('C') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('s') & 0xFF ),
	CHEROKEE           = ( u32('C') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('e') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	ETHIOPIC           = ( u32('E') & 0xFF ) << 24 | ( u32('t') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	KHMER              = ( u32('K') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	MONGOLIAN          = ( u32('M') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	MYANMAR            = ( u32('M') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	OGHAM              = ( u32('O') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('n') & 0xFF ),
	RUNIC              = ( u32('R') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	SINHALA            = ( u32('S') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('h') & 0xFF ),
	SYRIAC             = ( u32('S') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('c') & 0xFF ),
	THAANA             = ( u32('T') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	YI                 = ( u32('Y') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('i') & 0xFF ) << 8 | ( u32('i') & 0xFF ),

	// 3.1
	DESERET    = ( u32('D') & 0xFF ) << 24 | ( u32('s') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	GOTHIC     = ( u32('G') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('h') & 0xFF ),
	OLD_ITALIC = ( u32('I') & 0xFF ) << 24 | ( u32('t') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('l') & 0xFF ),

	// 3.2
	BUHID    = ( u32('B') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	HANUNOO  = ( u32('H') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	TAGALOG  = ( u32('T') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	TAGBANWA = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('b') & 0xFF ),

	// 4.0
	CYPRIOT  = ( u32('C') & 0xFF ) << 24 | ( u32('p') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	LIMBU    = ( u32('L') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	LINEAR_B = ( u32('L') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('i') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	OSMANYA  = ( u32('O') & 0xFF ) << 24 | ( u32('m') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	SHAVIAN  = ( u32('S') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('w') & 0xFF ),
	TAI_LE   = ( u32('T') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('e') & 0xFF ),
	UGARITIC = ( u32('U') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('r') & 0xFF ),

	// 4.1
	BUGINESE     = ( u32('B') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	COPTIC       = ( u32('C') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('p') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	GLAGOLITIC   = ( u32('G') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	KHAROSHTHI   = ( u32('K') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	NEW_TAI_LUE  = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('u') & 0xFF ),
	OLD_PERSIAN  = ( u32('X') & 0xFF ) << 24 | ( u32('p') & 0xFF ) << 16 | ( u32('e') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	SYLOTI_NAGRI = ( u32('S') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	TIFINAGH     = ( u32('T') & 0xFF ) << 24 | ( u32('f') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),

	// 5.0
	BALINESE   = ( u32('B') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	CUNEIFORM  = ( u32('X') & 0xFF ) << 24 | ( u32('s') & 0xFF ) << 16 | ( u32('u') & 0xFF ) << 8 | ( u32('x') & 0xFF ),
	NKO        = ( u32('N') & 0xFF ) << 24 | ( u32('k') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	PHAGS_PA   = ( u32('P') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	PHOENICIAN = ( u32('P') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('x') & 0xFF ),

	// 5.1
	CARIAN     = ( u32('C') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	CHAM       = ( u32('C') & 0xFF ) << 24 | ( u32('j') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	KAYAH_LI   = ( u32('K') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	LEPCHA     = ( u32('L') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('p') & 0xFF ) << 8 | ( u32('c') & 0xFF ),
	LYCIAN     = ( u32('L') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('c') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	LYDIAN     = ( u32('L') & 0xFF ) << 24 | ( u32('y') & 0xFF ) << 16 | ( u32('d') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	OL_CHIKI   = ( u32('O') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('c') & 0xFF ) << 8 | ( u32('k') & 0xFF ),
	REJANG     = ( u32('R') & 0xFF ) << 24 | ( u32('n') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	SAURASHTRA = ( u32('S') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('u') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	SUNDANESE  = ( u32('S') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	VAI        = ( u32('V') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('i') & 0xFF ) << 8 | ( u32('i') & 0xFF ),

	// 5.2
	AVESTAN                 = ( u32('A') & 0xFF ) << 24 | ( u32('v') & 0xFF ) << 16 | ( u32('s') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	BAMUM                   = ( u32('B') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('u') & 0xFF ),
	EGYPTIAN_HIEROGLYPHS    = ( u32('E') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('y') & 0xFF ) << 8 | ( u32('p') & 0xFF ),
	IMPERIAL_ARAMAIC        = ( u32('A') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	INSCRIPTIONAL_PAHLAVI   = ( u32('P') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	INSCRIPTIONAL_PARTHAIAN = ( u32('P') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	JAVANESE                = ( u32('J') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('v') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	KAITHI                  = ( u32('K') & 0xFF ) << 24 | ( u32('t') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	LISU                    = ( u32('L') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('s') & 0xFF ) << 8 | ( u32('u') & 0xFF ),
	MEETEI_MAYEK            = ( u32('M') & 0xFF ) << 24 | ( u32('t') & 0xFF ) << 16 | ( u32('e') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	OLD_SOUTH_ARABIAN       = ( u32('S') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	OLD_TURKIC              = ( u32('O') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('k') & 0xFF ) << 8 | ( u32('h') & 0xFF ),
	SAMARITAN               = ( u32('S') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('m') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	TAI_THAM                = ( u32('L') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	TAI_VIET                = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('v') & 0xFF ) << 8 | ( u32('t') & 0xFF ),

	// 6.0
	BATAK   = ( u32('B') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('k') & 0xFF ),
	BRAHMI  = ( u32('B') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('h') & 0xFF ),
	MANDAIC = ( u32('M') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('d') & 0xFF ),

	// 6.1
	CHAKMA               = ( u32('C') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('k') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	MEROITIC_CURSIVE     = ( u32('M') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('c') & 0xFF ),
	MEROITIC_HIEROGLYPHS = ( u32('M') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	MIAO                 = ( u32('P') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	SHARADA              = ( u32('S') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	SORA_SOMPENG         = ( u32('S') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	TAKRI                = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('k') & 0xFF ) << 8 | ( u32('r') & 0xFF ),

	// 0.9.30
	// 7.0
	BASSA_VAH          = ( u32('B') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('s') & 0xFF ) << 8 | ( u32('s') & 0xFF ),
	CAUCASIAN_ALBANIAN = ( u32('A') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	DUPLOYAN           = ( u32('D') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('p') & 0xFF ) << 8 | ( u32('l') & 0xFF ),
	ELBASAN            = ( u32('E') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('b') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	GRANTHA            = ( u32('G') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('n') & 0xFF ),
	KHOJKI             = ( u32('K') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('j') & 0xFF ),
	KHUDAWADI          = ( u32('S') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	LINEAR_A           = ( u32('L') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	MAHAJANI           = ( u32('M') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('j') & 0xFF ),
	MANICHAEAN         = ( u32('M') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	MENDE_KIKAKUI      = ( u32('M') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	MODI               = ( u32('M') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('d') & 0xFF ) << 8 | ( u32('i') & 0xFF ),
	MRO                = ( u32('M') & 0xFF ) << 24 | ( u32('r') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	NABATAEAN          = ( u32('N') & 0xFF ) << 24 | ( u32('b') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	OLD_NORTH_ARABIAN  = ( u32('N') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('b') & 0xFF ),
	OLD_PERMIC         = ( u32('P') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	PAHAWH_HMONG       = ( u32('H') & 0xFF ) << 24 | ( u32('m') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	PALMYRENE          = ( u32('P') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	PAU_CIN_HAU        = ( u32('P') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('u') & 0xFF ) << 8 | ( u32('c') & 0xFF ),
	PSALTER_PAHLAVI    = ( u32('P') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('p') & 0xFF ),
	SIDDHAM            = ( u32('S') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('d') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	TIRHUNTA           = ( u32('T') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('h') & 0xFF ),
	WARANG_CITI        = ( u32('W') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('a') & 0xFF ),

	// 8.0
	AHOM                  = ( u32('A') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('o') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	ANATOLIAN_HIEROGLYPHS = ( u32('H') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('u') & 0xFF ) << 8 | ( u32('w') & 0xFF ),
	HATRAN                = ( u32('H') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	MULTANI               = ( u32('M') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('t') & 0xFF ),
	OLD_HUNGARIAN         = ( u32('H') & 0xFF ) << 24 | ( u32('u') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	SIGNWRITING           = ( u32('S') & 0xFF ) << 24 | ( u32('g') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('w') & 0xFF ),

	// 1.3.0
	// 9.0
	ADLAM     = ( u32('A') & 0xFF ) << 24 | ( u32('d') & 0xFF ) << 16 | ( u32('l') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	BHAIKSUKI = ( u32('B') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('k') & 0xFF ) << 8 | ( u32('s') & 0xFF ),
	MARCHEN   = ( u32('M') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('c') & 0xFF ),
	OSAGE     = ( u32('O') & 0xFF ) << 24 | ( u32('s') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('e') & 0xFF ),
	TANGUT    = ( u32('T') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	NEWA      = ( u32('N') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('w') & 0xFF ) << 8 | ( u32('a') & 0xFF ),

	// 1.6.0
	// 10.0
	MASARAM_GONDI    = ( u32('D') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	NUSHU            = ( u32('D') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	SOYOMBO          = ( u32('D') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	ZANABAZAR_SQUARE = ( u32('D') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('r') & 0xFF ),

	// 1.8.0
	// 11.0
	DOGRA           = ( u32('D') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('r') & 0xFF ),
	GUNJALA_GONDI   = ( u32('G') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	HANIFI_ROHINGYA = ( u32('R') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('g') & 0xFF ),
	MAKASAR         = ( u32('M') & 0xFF ) << 24 | ( u32('k') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('a') & 0xFF ),
	MEDEFAIDRIN     = ( u32('M') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('d') & 0xFF ) << 8 | ( u32('f') & 0xFF ),
	OLD_SOGDIAN     = ( u32('S') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('o') & 0xFF ),
	SOGDIAN         = ( u32('S') & 0xFF ) << 24 | ( u32('o') & 0xFF ) << 16 | ( u32('g') & 0xFF ) << 8 | ( u32('d') & 0xFF ),

	// 2.4.0
	// 12.0
	ELYMAIC                = ( u32('E') & 0xFF ) << 24 | ( u32('l') & 0xFF ) << 16 | ( u32('y') & 0xFF ) << 8 | ( u32('m') & 0xFF ),
	NANDINAGARI            = ( u32('N') & 0xFF ) << 24 | ( u32('a') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('d') & 0xFF ),
	NYIAKENG_PUACHUE_HMONG = ( u32('H') & 0xFF ) << 24 | ( u32('m') & 0xFF ) << 16 | ( u32('n') & 0xFF ) << 8 | ( u32('p') & 0xFF ),
	WANCHO                 = ( u32('W') & 0xFF ) << 24 | ( u32('c') & 0xFF ) << 16 | ( u32('h') & 0xFF ) << 8 | ( u32('o') & 0xFF ),

	// 2.6.7
	// 13.0
	CHRASMIAN           = ( u32('C') & 0xFF ) << 24 | ( u32('h') & 0xFF ) << 16 | ( u32('r') & 0xFF ) << 8 | ( u32('s') & 0xFF ),
	DIVES_AKURU         = ( u32('D') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('a') & 0xFF ) << 8 | ( u32('k') & 0xFF ),
	KHITAN_SMALL_SCRIPT = ( u32('K') & 0xFF ) << 24 | ( u32('i') & 0xFF ) << 16 | ( u32('t') & 0xFF ) << 8 | ( u32('s') & 0xFF ),
	YEZIDI              = ( u32('Y') & 0xFF ) << 24 | ( u32('e') & 0xFF ) << 16 | ( u32('z') & 0xFF ) << 8 | ( u32('i') & 0xFF ),

	INVALID= 0,
}

Memory_Mode :: enum c.int {
	DUPLICATE,
	READONLY,
	WRITABLE,
	READONLY_MAY_MAKE_WRITABLE,
}

Destroy_Func :: proc "c" ( user_data : rawptr )

@(default_calling_convention="c", link_prefix="hb_")
foreign harfbuzz
{
	blob_create  :: proc( data : [^]u8, length : c.uint, memory_mode : Memory_Mode, user_data : rawptr, destroy : Destroy_Func ) -> Blob ---
	blob_destroy :: proc( blob : Blob ) ---

	buffer_create              :: proc() -> Buffer ---
	buffer_destroy             :: proc( buffer : Buffer ) ---
	buffer_add                 :: proc( buffer : Buffer, codepoint : Codepoint, cluster : c.uint ) ---
	buffer_clear_contents      :: proc( buffer : Buffer ) ---
	buffer_get_glyph_infos     :: proc( buffer : Buffer, length       : ^c.uint ) -> [^]Glyph_Info ---
	buffer_get_glyph_positions :: proc( buffer : Buffer, length       : ^c.uint ) -> [^]Glyph_Position ---
	buffer_set_direction       :: proc( buffer : Buffer, direction    : Direction ) ---
	buffer_set_language        :: proc( buffer : Buffer, language     : Language ) ---
	buffer_set_script          :: proc( buffer : Buffer, script       : Script ) ---
	buffer_set_content_type    :: proc( buffer : Buffer, content_type : Buffer_Content_Type ) ---

	face_create  :: proc( blob : Blob, index : c.uint ) -> Face ---
	face_destroy :: proc( face : Face ) ---

	font_create  :: proc( face : Face ) -> Font ---
	font_destroy :: proc( font : Font ) ---

	language_get_default :: proc() -> Language ---

	script_get_horizontal_direction :: proc( script : Script ) -> Direction ---

	shape :: proc( font : Font, buffer : Buffer, features : [^]Feature, num_features : c.uint ) ---

	unicode_funcs_get_default :: proc() -> Unicode_Funcs ---
	unicode_script            :: proc( ufuncs : Unicode_Funcs, unicode : Codepoint ) -> Script ---
}
