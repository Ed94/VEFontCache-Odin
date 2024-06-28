/*
A port of (https://github.com/hypernewbie/VEFontCache) to Odin.

Status:
This port is heavily tied to the grime package in SectrPrototype.

Changes:
- Font Parser & Glyph Shaper are abstracted to their own interface
- Font Face parser info stored separately from entries
- ve_fontcache_loadfile not ported (just use odin's core:os or os2), then call load_font
- Macro defines have been made into runtime parameters
*/
package VEFontCache

import "base:runtime"

Advance_Snap_Smallfont_Size :: 0

FontID  :: distinct i64
Glyph   :: distinct i32

Entry :: struct {
	parser_info : ParserFontInfo,
	shaper_info : ShaperInfo,
	id          : FontID,
	used        : b32,
	size        : f32,
	size_scale  : f32,
}

Entry_Default :: Entry {
	id         = 0,
	used       = false,
	size       = 24.0,
	size_scale = 1.0,
}

Context :: struct {
	backing : Allocator,

	parser_kind : ParserKind,
	parser_ctx  : ParserContext,
	shaper_ctx  : ShaperContext,

	entries : [dynamic]Entry,

	temp_path               : [dynamic]Vertex,
	temp_codepoint_seen     : map[u64]bool,
	temp_codepoint_seen_num : u32,

	snap_width  : u32,
	snap_height : u32,

	colour     : Colour,
	cursor_pos : Vec2,

	// draw_cursor_pos : Vec2,

	draw_layer : struct {
		vertices_offset : int,
		indices_offset  : int,
		calls_offset    : int,
	},

	draw_list    : DrawList,
	atlas        : Atlas,
	glyph_buffer : GlyphDrawBuffer,
	shape_cache  : ShapedTextCache,

	curve_quality  : u32,
	text_shape_adv : b32,

	debug_print         : b32,
	debug_print_verbose : b32,
}

#region("lifetime")

InitAtlasRegionParams :: struct {
	width  : u32,
	height : u32,
}

InitAtlasParams :: struct {
	width           : u32,
	height          : u32,
	glyph_padding   : u32,

	region_a : InitAtlasRegionParams,
	region_b : InitAtlasRegionParams,
	region_c : InitAtlasRegionParams,
	region_d : InitAtlasRegionParams,
}

InitAtlasParams_Default :: InitAtlasParams {
	width         = 4096,
	height        = 2048,
	glyph_padding = 4,

	region_a = {
		width  = 32,
		height = 32,
	},
	region_b = {
		width  = 32,
		height = 64,
	},
	region_c = {
		width  = 64,
		height = 64,
	},
	region_d = {
		width  = 128,
		height = 128,
	}
}

InitGlyphDrawParams :: struct {
	over_sample   : Vec2,
	buffer_batch  : u32,
	draw_padding  : u32,
}

InitGlyphDrawParams_Default :: InitGlyphDrawParams {
	over_sample   = { 8, 8 },
	buffer_batch  = 4,
	draw_padding  = InitAtlasParams_Default.glyph_padding,
}

InitShapeCacheParams :: struct {
	capacity       : u32,
	reserve_length : u32,
}

InitShapeCacheParams_Default :: InitShapeCacheParams {
	capacity       = 2048,
	reserve_length = 2048,
}

// ve_fontcache_init
startup :: proc( ctx : ^Context, parser_kind : ParserKind,
	allocator                   := context.allocator,
	atlas_params                := InitAtlasParams_Default,
	glyph_draw_params           := InitGlyphDrawParams_Default,
	shape_cache_params          := InitShapeCacheParams_Default,
	curve_quality               : u32 = 3,
	entires_reserve             : u32 = 512,
	temp_path_reserve           : u32 = 1024,
	temp_codepoint_seen_reserve : u32 = 2048,
)
{
	assert( ctx != nil, "Must provide a valid context" )
	using ctx

	ctx.backing       = allocator
	context.allocator = ctx.backing

	if curve_quality == 0 {
		curve_quality = 3
	}
	ctx.curve_quality = curve_quality

	error : AllocatorError
	entries, error = make( [dynamic]Entry, len = 0, cap = entires_reserve )
	assert(error == .None, "VEFontCache.init : Failed to allocate entries")

	temp_path, error = make( [dynamic]Vertex, len = 0, cap = temp_path_reserve )
	assert(error == .None, "VEFontCache.init : Failed to allocate temp_path")

	temp_codepoint_seen, error = make( map[u64]bool, uint(temp_codepoint_seen_reserve) )
	assert(error == .None, "VEFontCache.init : Failed to allocate temp_path")

	draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = 4 * Kilobyte )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.vertices")

	draw_list.indices, error = make( [dynamic]u32, len = 0, cap = 8 * Kilobyte )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.indices")

	draw_list.calls, error = make( [dynamic]DrawCall, len = 0, cap = 512 )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.calls")

	init_atlas_region :: proc( region : ^AtlasRegion, params : InitAtlasParams, region_params : InitAtlasRegionParams, factor : Vec2i, expected_cap : i32 )
	{
		using region

		next_idx = 0;
		width    = region_params.width
		height   = region_params.height
		size = {
			i32(params.width)  / factor.x,
			i32(params.height) / factor.y,
		}
		capacity = {
			size.x / i32(width),
			size.y / i32(height),
		}
		assert( capacity.x * capacity.y == expected_cap )

		error : AllocatorError
		// state.cache, error = make( HMapChained(LRU_Link), uint(capacity.x * capacity.y) )
		// assert( error == .None, "VEFontCache.init_atlas_region : Failed to allocate state.cache")
		LRU_init( & state, u32(capacity.x * capacity.y) )
	}
	init_atlas_region( & atlas.region_a, atlas_params, atlas_params.region_a, { 4, 2}, 1024 )
	init_atlas_region( & atlas.region_b, atlas_params, atlas_params.region_b, { 4, 2}, 512 )
	init_atlas_region( & atlas.region_c, atlas_params, atlas_params.region_c, { 4, 1}, 512 )
	init_atlas_region( & atlas.region_d, atlas_params, atlas_params.region_d, { 2, 1}, 256 )

	atlas.width         = atlas_params.width
	atlas.height        = atlas_params.height
	atlas.glyph_padding = atlas_params.glyph_padding

	atlas.region_a.offset   = {0, 0}
	atlas.region_b.offset.x = 0
	atlas.region_b.offset.y = atlas.region_a.size.y
	atlas.region_c.offset.x = atlas.region_a.size.x
	atlas.region_c.offset.y = 0
	atlas.region_d.offset.x = i32(atlas.width) / 2
	atlas.region_d.offset.y = 0

	LRU_init( & shape_cache.state, shape_cache_params.capacity )

	shape_cache.storage, error = make( [dynamic]ShapedText, shape_cache_params.capacity )
	assert(error == .None, "VEFontCache.init : Failed to allocate shape_cache.storage")

	for idx : u32 = 0; idx < shape_cache_params.capacity; idx += 1 {
		stroage_entry := & shape_cache.storage[idx]
		using stroage_entry
		glyphs, error = make( [dynamic]Glyph, len = 0, cap = shape_cache_params.reserve_length )
		assert( error == .None, "VEFontCache.init : Failed to allocate glyphs array for shape cache storage" )

		positions, error = make( [dynamic]Vec2, len = 0, cap = shape_cache_params.reserve_length )
		assert( error == .None, "VEFontCache.init : Failed to allocate positions array for shape cache storage" )

		draw_list.calls, error = make( [dynamic]DrawCall, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for draw_list" )

		draw_list.indices, error = make( [dynamic]u32, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 6 )
		assert( error == .None, "VEFontCache.init : Failed to allocate indices array for draw_list" )

		draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for draw_list" )
	}

	// Note(From original author): We can actually go over VE_FONTCACHE_GLYPHDRAW_BUFFER_BATCH batches due to smart packing!
	{
		using glyph_buffer
		over_sample   = glyph_draw_params.over_sample
		batch         = glyph_draw_params.buffer_batch
		width         = atlas.region_d.width  * u32(over_sample.x) * batch
		height        = atlas.region_d.height * u32(over_sample.y)
		draw_padding  = glyph_draw_params.draw_padding

		draw_list.calls, error = make( [dynamic]DrawCall, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for draw_list" )

		draw_list.indices, error = make( [dynamic]u32, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 6 )
		assert( error == .None, "VEFontCache.init : Failed to allocate indices array for draw_list" )

		draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for draw_list" )

		clear_draw_list.calls, error = make( [dynamic]DrawCall, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for calls for clear_draw_list" )

		clear_draw_list.indices, error = make( [dynamic]u32, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for indices array for clear_draw_list" )

		clear_draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for clear_draw_list" )
	}

	parser_init( & parser_ctx )
	shaper_init( & shaper_ctx )
}

hot_reload :: proc( ctx : ^Context, allocator : Allocator )
{
	assert( ctx != nil )
	ctx.backing       = allocator
	context.allocator = ctx.backing
	using ctx

	reload_array( & entries, allocator )
	reload_array( & temp_path, allocator )
	reload_map( & ctx.temp_codepoint_seen, allocator )

	reload_array( & draw_list.vertices, allocator)
	reload_array( & draw_list.indices, allocator )
	reload_array( & draw_list.calls, allocator )

	LRU_reload( & atlas.region_a.state, allocator)
	LRU_reload( & atlas.region_b.state, allocator)
	LRU_reload( & atlas.region_c.state, allocator)
	LRU_reload( & atlas.region_d.state, allocator)

	LRU_reload( & shape_cache.state, allocator )
	for idx : u32 = 0; idx < u32(len(shape_cache.storage)); idx += 1 {
		stroage_entry := & shape_cache.storage[idx]
		using stroage_entry

		reload_array( & glyphs, allocator )
		reload_array( & positions, allocator )
	}

	reload_array( & glyph_buffer.draw_list.calls, allocator )
	reload_array( & glyph_buffer.draw_list.indices, allocator )
	reload_array( & glyph_buffer.draw_list.vertices, allocator )

	reload_array( & glyph_buffer.clear_draw_list.calls, allocator )
	reload_array( & glyph_buffer.clear_draw_list.indices, allocator )
	reload_array( & glyph_buffer.clear_draw_list.vertices, allocator )

	reload_array( & shape_cache.storage, allocator )
	LRU_reload( & shape_cache.state, allocator )
}

// ve_foncache_shutdown
shutdown :: proc( ctx : ^Context )
{
	assert( ctx != nil )
	context.allocator = ctx.backing
	using ctx

	for & entry in entries {
		unload_font( ctx, entry.id )
	}

	shaper_shutdown( & shaper_ctx )

	// TODO(Ed): Finish implementing, there is quite a few resource not released here.
}

// ve_fontcache_load
load_font :: proc( ctx : ^Context, label : string, data : []byte, size_px : f32 ) -> (font_id : FontID)
{
	assert( ctx != nil )
	assert( len(data) > 0 )
	using ctx
	context.allocator = backing

	id : i32 = -1

	for index : i32 = 0; index < i32(len(entries)); index += 1 {
		if entries[index].used do continue
		id = index
		break
	}
	if id == -1 {
		append_elem( & entries, Entry {})
		id = cast(i32) len(entries) - 1
	}
	assert( id >= 0 && id < i32(len(entries)) )

	entry := & entries[ id ]
	{
		using entry

		parser_info = parser_load_font( & parser_ctx, label, data )
		// assert( parser_info != nil, "VEFontCache.load_font: Failed to load font info from parser" )

		size = size_px
		size_scale = size_px < 0.0 ?                               \
			parser_scale_for_pixel_height( & parser_info, -size_px ) \
		: parser_scale_for_mapping_em_to_pixels( & parser_info, size_px )

		used = true

		shaper_info = shaper_load_font( & shaper_ctx, label, data, transmute(rawptr) id )
		// assert( shaper_info != nil, "VEFontCache.load_font: Failed to load font from shaper")
	}
	entry.id = FontID(id)
	ctx.entries[ id ].id = FontID(id)

	font_id = FontID(id)
	return
}

// ve_fontcache_unload
unload_font :: proc( ctx : ^Context, font : FontID )
{
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )
	context.allocator = ctx.backing

	using ctx
	entry     := & ctx.entries[ font ]
	entry.used = false

	parser_unload_font( & entry.parser_info )
	shaper_unload_font( & entry.shaper_info )
}

#endregion("lifetime")

#region("drawing")

// ve_fontcache_configure_snap
configure_snap :: #force_inline proc( ctx : ^Context, snap_width, snap_height : u32 ) {
	assert( ctx != nil )
	ctx.snap_width  = snap_width
	ctx.snap_height = snap_height
}

get_cursor_pos :: #force_inline proc "contextless" ( ctx : ^Context                  ) -> Vec2 { return ctx.cursor_pos }
set_colour     :: #force_inline proc "contextless" ( ctx : ^Context, colour : Colour )         { ctx.colour = colour }

draw_text :: proc( ctx : ^Context, font : FontID, text_utf8 : string, position, scale : Vec2 ) -> b32
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	ctx.cursor_pos = {}

	position    := position
	snap_width  := f32(ctx.snap_width)
	snap_height := f32(ctx.snap_height)
	if ctx.snap_width  > 0 do position.x = cast(f32) cast(u32) (position.x * snap_width  + 0.5) / snap_width
	if ctx.snap_height > 0 do position.y = cast(f32) cast(u32) (position.y * snap_height + 0.5) / snap_height

	entry  := & ctx.entries[ font ]

	ChunkType   :: enum u32 { Visible, Formatting }
	chunk_kind  : ChunkType
	chunk_start : int = 0
	chunk_end   : int = 0

	text_utf8_bytes := transmute([]u8) text_utf8
	text_chunk      : string

	text_chunk = transmute(string) text_utf8_bytes[ : ]
	if len(text_chunk) > 0 {
		shaped        := shape_text_cached( ctx, font, text_chunk, entry )
		ctx.cursor_pos = draw_text_shape( ctx, font, entry, shaped, position, scale, snap_width, snap_height )
	}
	return true
}

// ve_fontcache_drawlist
get_draw_list :: proc( ctx : ^Context, optimize_before_returning := true ) -> ^DrawList {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, 0 )
	return & ctx.draw_list
}

get_draw_list_layer :: proc( ctx : ^Context, optimize_before_returning := true ) -> (vertices : []Vertex, indices : []u32, calls : []DrawCall) {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, ctx.draw_layer.calls_offset )
	vertices = ctx.draw_list.vertices[ ctx.draw_layer.vertices_offset : ]
	indices  = ctx.draw_list.indices [ ctx.draw_layer.indices_offset  : ]
	calls    = ctx.draw_list.calls   [ ctx.draw_layer.calls_offset    : ]
	return
}

// ve_fontcache_flush_drawlist
flush_draw_list :: proc( ctx : ^Context ) {
	assert( ctx != nil )
	using ctx
	clear_draw_list( & draw_list )
	draw_layer.vertices_offset = 0
	draw_layer.indices_offset  = 0
	draw_layer.calls_offset    = 0
}

flush_draw_list_layer :: proc( ctx : ^Context ) {
	assert( ctx != nil )
	using ctx
	draw_layer.vertices_offset = len(draw_list.vertices)
	draw_layer.indices_offset  = len(draw_list.indices)
	draw_layer.calls_offset    = len(draw_list.calls)
}

#endregion("drawing")

#region("metrics")

measure_text_size :: proc( ctx : ^Context, font : FontID, text_utf8 : string ) -> (measured : Vec2)
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry  := &ctx.entries[font]
	shaped := shape_text_cached(ctx, font, text_utf8, entry)
	return shaped.size
}

get_font_vertical_metrics :: #force_inline proc ( ctx : ^Context, font : FontID ) -> ( ascent, descent, line_gap : f32 )
{
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry  := & ctx.entries[ font ]
	ascent_i32, descent_i32, line_gap_i32 := parser_get_font_vertical_metrics( & entry.parser_info )

	ascent   = ceil(f32(ascent_i32)   * entry.size_scale)
	descent  = ceil(f32(descent_i32)  * entry.size_scale)
	line_gap = ceil(f32(line_gap_i32) * entry.size_scale)
	return
}

#endregion("metrics")
