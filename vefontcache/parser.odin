package vefontcache

/*
Notes:

Freetype will do memory allocations and has an interface the user can implement.
That interface is not exposed from this parser but could be added to parser_init.

STB_Truetype has macros for its allocation unfortuantely
*/

import "base:runtime"
import "core:c"
import "core:math"
import "core:slice"
import stbtt    "vendor:stb/truetype"
import freetype "thirdparty:freetype"

Parser_Kind :: enum u32 {
	STB_TrueType,
	Freetype,
}

Parser_Font_Info :: struct {
	label : string,
	kind  : Parser_Kind,
	using _ : struct #raw_union {
		stbtt_info    : stbtt.fontinfo,
		freetype_info : freetype.Face
	},
	data : []byte,
}

Glyph_Vert_Type :: enum u8 {
	None,
	Move = 1,
	Line,
	Curve,
	Cubic,
}

// Based directly off of stb_truetype's vertex
Parser_Glyph_Vertex :: struct {
	x,          y          : i16,
	contour_x0, contour_y0 : i16,
	contour_x1, contour_y1 : i16,
	type    : Glyph_Vert_Type,
	padding : u8,
}
// A shape can be a dynamic array free_type or an opaque set of data handled by stb_truetype
Parser_Glyph_Shape :: [dynamic]Parser_Glyph_Vertex

Parser_Context :: struct {
	kind       : Parser_Kind,
	ft_library : freetype.Library,
}

parser_init :: proc( ctx : ^Parser_Context, kind : Parser_Kind )
{
	switch kind
	{
		case .Freetype:
			result := freetype.init_free_type( & ctx.ft_library )
			assert( result == freetype.Error.Ok, "VEFontCache.parser_init: Failed to initialize freetype" )

		case .STB_TrueType:
			// Do nothing intentional
	}

	ctx.kind = kind
}

parser_shutdown :: proc( ctx : ^Parser_Context ) {
	// TODO(Ed): Implement
}

parser_load_font :: proc( ctx : ^Parser_Context, label : string, data : []byte ) -> (font : Parser_Font_Info)
{
	switch ctx.kind
	{
		case .Freetype:
			error := freetype.new_memory_face( ctx.ft_library, raw_data(data), cast(i32) len(data), 0, & font.freetype_info )
			if error != .Ok do return

		case .STB_TrueType:
			success := stbtt.InitFont( & font.stbtt_info, raw_data(data), 0 )
			if ! success do return
	}

	font.label = label
	font.data  = data
	font.kind  = ctx.kind
	return
}

parser_unload_font :: proc( font : ^Parser_Font_Info )
{
	switch font.kind {
		case .Freetype:
			error := freetype.done_face( font.freetype_info )
			assert( error == .Ok, "VEFontCache.parser_unload_font: Failed to unload freetype face" )

		case .STB_TrueType:
			// Do Nothing
	}
}

parser_find_glyph_index :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, codepoint : rune ) -> (glyph_index : Glyph)
{
	switch font.kind
	{
		case .Freetype:
			glyph_index = transmute(Glyph) freetype.get_char_index( font.freetype_info, transmute(u32) codepoint )
			return

		case .STB_TrueType:
			glyph_index = transmute(Glyph) stbtt.FindGlyphIndex( & font.stbtt_info, codepoint )
			return
	}
	return Glyph(-1)
}

parser_free_shape :: proc( font : ^Parser_Font_Info, shape : Parser_Glyph_Shape )
{
	switch font.kind
	{
		case .Freetype:
			delete(shape)

		case .STB_TrueType:
			stbtt.FreeShape( & font.stbtt_info, transmute( [^]stbtt.vertex) raw_data(shape) )
	}
}

parser_get_codepoint_horizontal_metrics :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, codepoint : rune ) -> ( advance, to_left_side_glyph : i32 )
{
	switch font.kind
	{
		case .Freetype:
			glyph_index := transmute(Glyph) freetype.get_char_index( font.freetype_info, transmute(u32) codepoint )
			if glyph_index != 0
			{
				freetype.load_glyph( font.freetype_info, c.uint(codepoint), { .No_Bitmap, .No_Hinting, .No_Scale } )
				advance            = i32(font.freetype_info.glyph.advance.x)              >> 6
				to_left_side_glyph = i32(font.freetype_info.glyph.metrics.hori_bearing_x) >> 6
			}
			else
			{
				advance            = 0
				to_left_side_glyph = 0
			}

		case .STB_TrueType:
			stbtt.GetCodepointHMetrics( & font.stbtt_info, codepoint, & advance, & to_left_side_glyph )
	}
	return
}

parser_get_codepoint_kern_advance :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, prev_codepoint, codepoint : rune ) -> i32
{
	switch font.kind
	{
		case .Freetype:
			prev_glyph_index := transmute(Glyph) freetype.get_char_index( font.freetype_info, transmute(u32) prev_codepoint )
			glyph_index      := transmute(Glyph) freetype.get_char_index( font.freetype_info, transmute(u32) codepoint )
			if prev_glyph_index != 0 && glyph_index != 0
			{
				kerning : freetype.Vector
				font.freetype_info.driver.clazz.get_kerning( font.freetype_info, transmute(u32) prev_codepoint, transmute(u32) codepoint, & kerning )
			}

		case .STB_TrueType:
			kern := stbtt.GetCodepointKernAdvance( & font.stbtt_info, prev_codepoint, codepoint )
			return kern
	}
	return -1
}

parser_get_font_vertical_metrics :: #force_inline proc "contextless" ( font : ^Parser_Font_Info ) -> (ascent, descent, line_gap : i32 )
{
	switch font.kind
	{
		case .Freetype:
			info    := font.freetype_info
			ascent   = i32(info.ascender)
			descent  = i32(info.descender)
			line_gap = i32(info.height) - (ascent - descent)

		case .STB_TrueType:
			stbtt.GetFontVMetrics( & font.stbtt_info, & ascent, & descent, & line_gap )
	}
	return
}

parser_get_glyph_box :: #force_inline proc ( font : ^Parser_Font_Info, glyph_index : Glyph ) -> (bounds_0, bounds_1 : Vec2i)
{
	switch font.kind
	{
		case .Freetype:
			freetype.load_glyph( font.freetype_info, c.uint(glyph_index), { .No_Bitmap, .No_Hinting, .No_Scale } )

			metrics := font.freetype_info.glyph.metrics

			bounds_0 = {i32(metrics.hori_bearing_x), i32(metrics.hori_bearing_y - metrics.height)}
			bounds_1 = {i32(metrics.hori_bearing_x + metrics.width), i32(metrics.hori_bearing_y)}

		case .STB_TrueType:
			x0, y0, x1, y1 : i32
			success := cast(bool) stbtt.GetGlyphBox( & font.stbtt_info, i32(glyph_index), & x0, & y0, & x1, & y1 )
			assert( success )

			bounds_0 = { i32(x0), i32(y0) }
			bounds_1 = { i32(x1), i32(y1) }
	}
	return
}

parser_get_glyph_shape :: proc( font : ^Parser_Font_Info, glyph_index : Glyph ) -> (shape : Parser_Glyph_Shape, error : Allocator_Error)
{
	switch font.kind
	{
		case .Freetype:
			// TODO(Ed): Don't do this, going a completely different route for handling shapes.
			// This abstraction fails to be time-saving or performant.

		case .STB_TrueType:
			stb_shape : [^]stbtt.vertex
			nverts    := stbtt.GetGlyphShape( & font.stbtt_info, cast(i32) glyph_index, & stb_shape )

			shape_raw          := transmute( ^runtime.Raw_Dynamic_Array) & shape
			shape_raw.data      = stb_shape
			shape_raw.len       = int(nverts)
			shape_raw.cap       = int(nverts)
			shape_raw.allocator = runtime.nil_allocator()
			error = Allocator_Error.None
			return
	}

	return
}

parser_is_glyph_empty :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, glyph_index : Glyph ) -> b32
{
	switch font.kind
	{
		case .Freetype:
			error := freetype.load_glyph( font.freetype_info, cast(u32) glyph_index, { .No_Bitmap, .No_Hinting, .No_Scale } )
			if error == .Ok
			{
				if font.freetype_info.glyph.format == .Outline {
					return font.freetype_info.glyph.outline.n_points == 0
				}
				else if font.freetype_info.glyph.format == .Bitmap {
					return font.freetype_info.glyph.bitmap.width == 0 && font.freetype_info.glyph.bitmap.rows == 0;
				}
			}
			return false

		case .STB_TrueType:
			return stbtt.IsGlyphEmpty( & font.stbtt_info, cast(c.int) glyph_index )
	}
	return false
}

parser_scale :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, size : f32 ) -> f32
{
	size_scale := size < 0.0 ?                            \
		parser_scale_for_pixel_height( font, -size )        \
	: parser_scale_for_mapping_em_to_pixels( font, size )
	// size_scale = 1.0
	return size_scale
}

parser_scale_for_pixel_height :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, size : f32 ) -> f32
{
	switch font.kind {
		case .Freetype:
			freetype.set_pixel_sizes( font.freetype_info, 0, cast(u32) size )
			size_scale := size / cast(f32)font.freetype_info.units_per_em
			return size_scale

		case.STB_TrueType:
			return stbtt.ScaleForPixelHeight( & font.stbtt_info, size )
	}
	return 0
}

parser_scale_for_mapping_em_to_pixels :: #force_inline proc "contextless" ( font : ^Parser_Font_Info, size : f32 ) -> f32
{
	switch font.kind {
		case .Freetype:
			Inches_To_CM  :: cast(f32) 2.54
			Points_Per_CM :: cast(f32) 28.3465
			CM_Per_Point  :: cast(f32) 1.0 / DPT_DPCM
			CM_Per_Pixel  :: cast(f32) 1.0 / DPT_PPCM
			DPT_DPCM      :: cast(f32) 72.0 * Inches_To_CM // 182.88 points/dots per cm
			DPT_PPCM      :: cast(f32) 96.0 * Inches_To_CM // 243.84 pixels per cm
			DPT_DPI       :: cast(f32) 72.0

			// TODO(Ed): Don't assume the dots or pixels per inch.
			system_dpi :: DPT_DPI

			FT_Font_Size_Point_Unit :: 1.0 / 64.0
			FT_Point_10             :: 64.0

			points_per_em := (size / system_dpi ) * DPT_DPI
			freetype.set_char_size( font.freetype_info, 0, cast(freetype.F26Dot6) f32(points_per_em * FT_Point_10), cast(u32) DPT_DPI, cast(u32) DPT_DPI )
			size_scale := f32(f64(size) / cast(f64) font.freetype_info.units_per_em)
			return size_scale

		case .STB_TrueType:
			return stbtt.ScaleForMappingEmToPixels( & font.stbtt_info, size )
	}
	return 0
}
