package vefontcache

/*
Notes:
This is a minimal wrapper I originally did incase a font parser other than stb_truetype is introduced in the future.
Otherwise, its essentially 1:1 with it.

Freetype isn't really supported and its not a high priority.
~~Freetype will do memory allocations and has an interface the user can implement.~~
~~That interface is not exposed from this parser but could be added to parser_init.~~

STB_Truetype:
* Added ability to set the stb_truetype allocator for STBTT_MALLOC and STBTT_FREE.
* Changed procedure signatures to pass the font_info struct by immutable ptr (#by_ptr) 
  when the C equivalent has their parameter as `const*`.
*/

import "core:c"
import stbtt    "thirdparty:stb/truetype"
// import freetype "thirdparty:freetype"

Parser_Kind :: enum u32 {
	STB_TrueType,
	Freetype, // Currently not implemented.
}

Parser_Font_Info :: struct {
	label : string,
	kind  : Parser_Kind,
	using _ : struct #raw_union {
		stbtt_info : stbtt.fontinfo,
		// freetype_info : freetype.Face
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
	lib_backing : Allocator,
	kind        : Parser_Kind,
	// ft_library : freetype.Library,
}

parser_stbtt_allocator_proc :: proc(
	allocator_data : rawptr, 
	type           : stbtt.gbAllocationType, 
	size           : c.ssize_t, 
	alignment      : c.ssize_t, 
	old_memory     : rawptr, 
	old_size       : c.ssize_t, 
	flags          : c.ulonglong
) -> rawptr
{
	allocator := transmute(^Allocator) allocator_data
	result, error := allocator.procedure( allocator.data, cast(Allocator_Mode) type, cast(int) size, cast(int) alignment, old_memory, cast(int) old_size )
	assert(error == .None)

	if type == .Alloc || type == .Resize {
		raw := transmute(Raw_Slice) result
		// assert(raw.len > 0, "Allocation is 0 bytes?")
		return transmute(rawptr) raw.data
	}
	else do return nil
}

parser_init :: proc( ctx : ^Parser_Context, kind : Parser_Kind, allocator := context.allocator )
{
	ctx.kind        = kind
	ctx.lib_backing = allocator

	stbtt_allocator := stbtt.gbAllocator { parser_stbtt_allocator_proc, & ctx.lib_backing }
	stbtt.SetAllocator( stbtt_allocator )
}

parser_reload :: proc( ctx : ^Parser_Context, allocator := context.allocator) {
	ctx.lib_backing = allocator
	stbtt_allocator := stbtt.gbAllocator { parser_stbtt_allocator_proc, & ctx.lib_backing }
	stbtt.SetAllocator( stbtt_allocator )
}

parser_shutdown :: proc( ctx : ^Parser_Context ) {
	// Note: Not necesssary for stb_truetype
}

parser_load_font :: proc( ctx : ^Parser_Context, label : string, data : []byte ) -> (font : Parser_Font_Info, error : b32)
{
	error = ! stbtt.InitFont( & font.stbtt_info, raw_data(data), 0 )

	font.label = label
	font.data  = data
	font.kind  = ctx.kind
	return
}

parser_unload_font :: proc( font : ^Parser_Font_Info )
{
	// case .STB_TrueType:
		// Do Nothing
}

parser_find_glyph_index :: #force_inline proc "contextless" ( font : Parser_Font_Info, codepoint : rune ) -> (glyph_index : Glyph)
{
	glyph_index = transmute(Glyph) stbtt.FindGlyphIndex( font.stbtt_info, codepoint )
	return
}

parser_free_shape :: #force_inline proc( font : Parser_Font_Info, shape : Parser_Glyph_Shape )
{
	shape     := shape
	shape_raw := transmute( ^Raw_Dynamic_Array) & shape
	stbtt.FreeShape( font.stbtt_info, transmute( [^]stbtt.vertex) shape_raw.data )
}

parser_get_codepoint_horizontal_metrics :: #force_inline proc "contextless" ( font : Parser_Font_Info, codepoint : rune ) -> ( advance, to_left_side_glyph : i32 )
{
	stbtt.GetCodepointHMetrics( font.stbtt_info, codepoint, & advance, & to_left_side_glyph )
	return
}

parser_get_codepoint_kern_advance :: #force_inline proc "contextless" ( font : Parser_Font_Info, prev_codepoint, codepoint : rune ) -> i32
{
	kern := stbtt.GetCodepointKernAdvance( font.stbtt_info, prev_codepoint, codepoint )
	return kern
}

parser_get_font_vertical_metrics :: #force_inline proc "contextless" ( font : Parser_Font_Info ) -> (ascent, descent, line_gap : i32 )
{
	stbtt.GetFontVMetrics( font.stbtt_info, & ascent, & descent, & line_gap )
	return
}

parser_get_bounds :: #force_inline proc "contextless" ( font : Parser_Font_Info, glyph_index : Glyph ) -> (bounds : Range2)
{
	// profile(#procedure)
	bounds_0, bounds_1 : Vec2i

	x0, y0, x1, y1 : i32
	success := cast(bool) stbtt.GetGlyphBox( font.stbtt_info, i32(glyph_index), & x0, & y0, & x1, & y1 )

	bounds_0 = { x0, y0 }
	bounds_1 = { x1, y1 }
	bounds = { vec2(bounds_0), vec2(bounds_1) }
	return
}

parser_get_glyph_shape :: #force_inline proc ( font : Parser_Font_Info, glyph_index : Glyph ) -> (shape : Parser_Glyph_Shape, error : Allocator_Error)
{
	stb_shape : [^]stbtt.vertex
	nverts    := stbtt.GetGlyphShape( font.stbtt_info, cast(i32) glyph_index, & stb_shape )

	shape_raw          := transmute( ^Raw_Dynamic_Array) & shape
	shape_raw.data      = stb_shape
	shape_raw.len       = int(nverts)
	shape_raw.cap       = int(nverts)
	shape_raw.allocator = nil_allocator()
	error = Allocator_Error.None
	return
}

parser_is_glyph_empty :: #force_inline proc "contextless" ( font : Parser_Font_Info, glyph_index : Glyph ) -> b32
{
	return stbtt.IsGlyphEmpty( font.stbtt_info, cast(c.int) glyph_index )
}

parser_scale :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	// profile(#procedure)
	size_scale := size > 0.0 ? parser_scale_for_mapping_em_to_pixels( font, size ) :  parser_scale_for_pixel_height( font, -size )
	return size_scale
}

parser_scale_for_pixel_height :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	return stbtt.ScaleForPixelHeight( font.stbtt_info, size )
}

parser_scale_for_mapping_em_to_pixels :: #force_inline proc "contextless" ( font : Parser_Font_Info, size : f32 ) -> f32
{
	return stbtt.ScaleForMappingEmToPixels( font.stbtt_info, size )
}
