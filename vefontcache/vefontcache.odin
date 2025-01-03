/*
A port of (https://github.com/hypernewbie/VEFontCache) to Odin.

See: https://github.com/Ed94/VEFontCache-Odin
*/
package vefontcache

import "base:runtime"

Font_ID :: distinct i64
Glyph   :: distinct i32

Entry :: struct {
	parser_info   : Parser_Font_Info,
	shaper_info   : Shaper_Info,
	id            : Font_ID,
	used          : b32,
	curve_quality : f32,
	size          : f32,
	size_scale    : f32,
}

Entry_Default :: Entry {
	id         = 0,
	used       = false,
	size       = 24.0,
	size_scale = 1.0,
}

Context :: struct {
	backing : Allocator,

	parser_ctx  : Parser_Context,
	shaper_ctx  : Shaper_Context,

	entries : [dynamic]Entry,

	temp_path               : [dynamic]Vertex,
	temp_codepoint_seen     : map[u64]bool,
	temp_codepoint_seen_num : int,

	snap_width  : f32,
	snap_height : f32,

	colour     : Colour,
	cursor_pos : Vec2,

	draw_layer : struct {
		vertices_offset : int,
		indices_offset  : int,
		calls_offset    : int,
	},

	draw_list    : Draw_List,
	atlas        : Atlas,
	glyph_buffer : Glyph_Draw_Buffer,
	shape_cache  : Shaped_Text_Cache,

	default_curve_quality : i32,
	use_advanced_shaper   : b32,

	debug_print         : b32,
	debug_print_verbose : b32,
}


Init_Atlas_Region_Params :: struct {
	width  : u32,
	height : u32,
}

Init_Atlas_Params :: struct {
	width             : u32,
	height            : u32,
	glyph_padding     : u32, // Padding to add to bounds_<width/height>_scaled for choosing which atlas region.
	glyph_over_scalar : f32, // Scalar to apply to bounds_<width/height>_scaled for choosing which atlas region.

	region_a : Init_Atlas_Region_Params,
	region_b : Init_Atlas_Region_Params,
	region_c : Init_Atlas_Region_Params,
	region_d : Init_Atlas_Region_Params,
}

Init_Atlas_Params_Default :: Init_Atlas_Params {
	width             = 4096,
	height            = 2048,
	glyph_padding     = 1,
	glyph_over_scalar = 1,

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

Init_Glyph_Draw_Params :: struct {
	over_sample  : Vec2,
	buffer_batch : u32,
	draw_padding : u32,
}

Init_Glyph_Draw_Params_Default :: Init_Glyph_Draw_Params {
	over_sample   = Vec2 { 4, 4 },
	buffer_batch  = 4,
	draw_padding  = Init_Atlas_Params_Default.glyph_padding,
}

Init_Shaper_Params :: struct {
	use_advanced_text_shaper      : b32,
	snap_glyph_position           : b32,
	adv_snap_small_font_threshold : u32,
}

Init_Shaper_Params_Default :: Init_Shaper_Params {
	use_advanced_text_shaper      = true,
	snap_glyph_position           = true,
	adv_snap_small_font_threshold = 0,
}

Init_Shape_Cache_Params :: struct {
	capacity       : u32,
	reserve_length : u32,
}

Init_Shape_Cache_Params_Default :: Init_Shape_Cache_Params {
	capacity       = 8 * 1024,
	reserve_length = 256,
}

//#region("lifetime")

// ve_fontcache_init
startup :: proc( ctx : ^Context, parser_kind : Parser_Kind = .STB_TrueType,
	allocator                   := context.allocator,
	atlas_params                := Init_Atlas_Params_Default,
	glyph_draw_params           := Init_Glyph_Draw_Params_Default,
	shape_cache_params          := Init_Shape_Cache_Params_Default,
	shaper_params               := Init_Shaper_Params_Default,
	default_curve_quality       : u32 = 3,
	entires_reserve             : u32 = 512,
	temp_path_reserve           : u32 = 1024,
	temp_codepoint_seen_reserve : u32 = 2048,
)
{
	assert( ctx != nil, "Must provide a valid context" )
	using ctx

	ctx.backing       = allocator
	context.allocator = ctx.backing

	use_advanced_shaper                      = shaper_params.use_advanced_text_shaper
	shaper_ctx.adv_snap_small_font_threshold = f32(shaper_params.adv_snap_small_font_threshold)
	shaper_ctx.snap_glyph_position           = shaper_params.snap_glyph_position

	if default_curve_quality == 0 {
		default_curve_quality = 3
	}
	ctx.default_curve_quality = default_curve_quality

	error : Allocator_Error
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

	draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = 512 )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.calls")

	init_atlas_region :: proc( region : ^Atlas_Region, params : Init_Atlas_Params, region_params : Init_Atlas_Region_Params, factor : Vec2i, expected_cap : i32 )
	{
		using region

		next_idx = 0;
		width    = i32(region_params.width)
		height   = i32(region_params.height)
		size = {
			i32(params.width)  / factor.x,
			i32(params.height) / factor.y,
		}
		capacity = {
			size.x / i32(width),
			size.y / i32(height),
		}
		assert( capacity.x * capacity.y == expected_cap )

		error : Allocator_Error
		lru_init( & state, capacity.x * capacity.y )
	}
	init_atlas_region( & atlas.region_a, atlas_params, atlas_params.region_a, { 4, 2}, 1024 )
	init_atlas_region( & atlas.region_b, atlas_params, atlas_params.region_b, { 4, 2}, 512 )
	init_atlas_region( & atlas.region_c, atlas_params, atlas_params.region_c, { 4, 1}, 512 )
	init_atlas_region( & atlas.region_d, atlas_params, atlas_params.region_d, { 2, 1}, 256 )

	atlas.width             = i32(atlas_params.width)
	atlas.height            = i32(atlas_params.height)
	atlas.glyph_padding     = i32(atlas_params.glyph_padding)
	atlas.glyph_over_scalar = atlas_params.glyph_over_scalar

	atlas.region_a.offset   = {0, 0}
	atlas.region_b.offset.x = 0
	atlas.region_b.offset.y = atlas.region_a.size.y
	atlas.region_c.offset.x = atlas.region_a.size.x
	atlas.region_c.offset.y = 0
	atlas.region_d.offset.x = atlas.width / 2
	atlas.region_d.offset.y = 0

	lru_init( & shape_cache.state, i32(shape_cache_params.capacity) )

	shape_cache.storage, error = make( [dynamic]Shaped_Text, shape_cache_params.capacity )
	assert(error == .None, "VEFontCache.init : Failed to allocate shape_cache.storage")

	for idx : u32 = 0; idx < shape_cache_params.capacity; idx += 1 {
		stroage_entry := & shape_cache.storage[idx]
		using stroage_entry
		glyphs, error = make( [dynamic]Glyph, len = 0, cap = shape_cache_params.reserve_length )
		assert( error == .None, "VEFontCache.init : Failed to allocate glyphs array for shape cache storage" )

		positions, error = make( [dynamic]Vec2, len = 0, cap = shape_cache_params.reserve_length )
		assert( error == .None, "VEFontCache.init : Failed to allocate positions array for shape cache storage" )

		draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
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
		batch         = cast(i32) glyph_draw_params.buffer_batch
		width         = atlas.region_d.width  * i32(over_sample.x) * batch
		height        = atlas.region_d.height * i32(over_sample.y)
		draw_padding  = cast(i32) glyph_draw_params.draw_padding

		draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for draw_list" )

		draw_list.indices, error = make( [dynamic]u32, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 6 )
		assert( error == .None, "VEFontCache.init : Failed to allocate indices array for draw_list" )

		draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for draw_list" )

		clear_draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = glyph_draw_params.buffer_batch * 2 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for calls for clear_draw_list" )

		clear_draw_list.indices, error = make( [dynamic]u32, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for indices array for clear_draw_list" )

		clear_draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.buffer_batch * 2 * 4 )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for clear_draw_list" )
	}

	parser_init( & parser_ctx, parser_kind )
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

	lru_reload( & atlas.region_a.state, allocator)
	lru_reload( & atlas.region_b.state, allocator)
	lru_reload( & atlas.region_c.state, allocator)
	lru_reload( & atlas.region_d.state, allocator)

	lru_reload( & shape_cache.state, allocator )
	for idx : i32 = 0; idx < i32(len(shape_cache.storage)); idx += 1 {
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

	delete( entries )
	delete( temp_path )
	delete( temp_codepoint_seen )

	delete( draw_list.vertices )
	delete( draw_list.indices )
	delete( draw_list.calls )

	lru_free( & atlas.region_a.state )
	lru_free( & atlas.region_b.state )
	lru_free( & atlas.region_c.state )
	lru_free( & atlas.region_d.state )

	for idx : i32 = 0; idx < i32(len(shape_cache.storage)); idx += 1 {
		stroage_entry := & shape_cache.storage[idx]
		using stroage_entry

		delete( glyphs )
		delete( positions )
	}
	lru_free( & shape_cache.state )

	delete( glyph_buffer.draw_list.vertices )
	delete( glyph_buffer.draw_list.indices )
	delete( glyph_buffer.draw_list.calls )

	delete( glyph_buffer.clear_draw_list.vertices )
	delete( glyph_buffer.clear_draw_list.indices )
	delete( glyph_buffer.clear_draw_list.calls )

	shaper_shutdown( & shaper_ctx )
	parser_shutdown( & parser_ctx )
}

// ve_fontcache_load
load_font :: proc( ctx : ^Context, label : string, data : []byte, size_px : f32, glyph_curve_quality : u32 = 0 ) -> (font_id : Font_ID)
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
		used = true

		parser_info = parser_load_font( & parser_ctx, label, data )
		shaper_info = shaper_load_font( & shaper_ctx, label, data, transmute(rawptr) id )

		size       = size_px
		size_scale = parser_scale( & parser_info, size )

		if glyph_curve_quality == 0 {
			curve_quality = f32(ctx.default_curve_quality)
		}
		else {
			curve_quality = f32(glyph_curve_quality)
		}
	}
	entry.id = Font_ID(id)
	ctx.entries[ id ].id = Font_ID(id)

	font_id = Font_ID(id)
	return
}

// ve_fontcache_unload
unload_font :: proc( ctx : ^Context, font : Font_ID )
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

//#endregion("lifetime")

//#region("drawing")

// ve_fontcache_configure_snap
configure_snap :: #force_inline proc( ctx : ^Context, snap_width, snap_height : u32 ) {
	assert( ctx != nil )
	ctx.snap_width  = f32(snap_width)
	ctx.snap_height = f32(snap_height)
}

get_cursor_pos :: #force_inline proc( ctx : ^Context                  ) -> Vec2 { assert(ctx != nil); return ctx.cursor_pos }
set_colour     :: #force_inline proc( ctx : ^Context, colour : Colour )         { assert(ctx != nil); ctx.colour = colour }

draw_text :: proc( ctx : ^Context, font : Font_ID, text_utf8 : string, position, scale : Vec2 ) -> b32
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	ctx.cursor_pos = {}

	position := position
	if ctx.snap_width  > 0 do position.x = ceil(position.x * ctx.snap_width ) / ctx.snap_width
	if ctx.snap_height > 0 do position.y = ceil(position.y * ctx.snap_height) / ctx.snap_height

	entry := & ctx.entries[ font ]

	ChunkType   :: enum u32 { Visible, Formatting }
	chunk_kind  : ChunkType
	chunk_start : int = 0
	chunk_end   : int = 0

	text_utf8_bytes := transmute([]u8) text_utf8
	text_chunk      : string

	text_chunk = transmute(string) text_utf8_bytes[ : ]
	if len(text_chunk) > 0 {
		shaped        := shape_text_cached( ctx, font, text_chunk, entry )
		ctx.cursor_pos = draw_text_shape( ctx, font, entry, shaped, position, scale, ctx.snap_width, ctx.snap_height )
	}
	return true
}

// ve_fontcache_Draw_List
get_draw_list :: proc( ctx : ^Context, optimize_before_returning := true ) -> ^Draw_List {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, 0 )
	return & ctx.draw_list
}

get_draw_list_layer :: proc( ctx : ^Context, optimize_before_returning := true ) -> (vertices : []Vertex, indices : []u32, calls : []Draw_Call) {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, ctx.draw_layer.calls_offset )
	vertices = ctx.draw_list.vertices[ ctx.draw_layer.vertices_offset : ]
	indices  = ctx.draw_list.indices [ ctx.draw_layer.indices_offset  : ]
	calls    = ctx.draw_list.calls   [ ctx.draw_layer.calls_offset    : ]
	return
}

// ve_fontcache_flush_Draw_List
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

//#endregion("drawing")

//#region("metrics")

measure_text_size :: proc( ctx : ^Context, font : Font_ID, text_utf8 : string ) -> (measured : Vec2)
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry  := &ctx.entries[font]
	shaped := shape_text_cached(ctx, font, text_utf8, entry)
	return shaped.size
}

get_font_vertical_metrics :: #force_inline proc ( ctx : ^Context, font : Font_ID ) -> ( ascent, descent, line_gap : f32 )
{
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry  := & ctx.entries[ font ]
	ascent_i32, descent_i32, line_gap_i32 := parser_get_font_vertical_metrics( & entry.parser_info )

	ascent   = (f32(ascent_i32)   * entry.size_scale)
	descent  = (f32(descent_i32)  * entry.size_scale)
	line_gap = (f32(line_gap_i32) * entry.size_scale)
	return
}

//#endregion("metrics")

// Can be used with hot-reload
clear_atlas_region_caches :: proc(ctx : ^Context)
{
	lru_clear(& ctx.atlas.region_a.state)
	lru_clear(& ctx.atlas.region_b.state)
	lru_clear(& ctx.atlas.region_c.state)
	lru_clear(& ctx.atlas.region_d.state)

	ctx.atlas.region_a.next_idx = 0
	ctx.atlas.region_b.next_idx = 0
	ctx.atlas.region_c.next_idx = 0
	ctx.atlas.region_d.next_idx = 0
}

// Can be used with hot-reload
clear_shape_cache :: proc (ctx : ^Context)
{
	using ctx
	lru_clear(& shape_cache.state)
	for idx : i32 = 0; idx < cast(i32) cap(shape_cache.storage); idx += 1
	{
		stroage_entry := & shape_cache.storage[idx]
		using stroage_entry
		end_cursor_pos = {}
		size           = {}
		clear(& glyphs)
		clear(& positions)
		clear(& draw_list.calls)
		clear(& draw_list.indices)
		clear(& draw_list.vertices)
	}
	ctx.shape_cache.next_cache_id = 0
}
