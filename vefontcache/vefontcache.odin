/*
See: https://github.com/Ed94/VEFontCache-Odin
*/
package vefontcache

// See: mappings.odin for profiling hookup
DISABLE_PROFILING              :: true
ENABLE_OVERSIZED_GLYPHS        :: true
// White: Cached Hit, Red: Cache Miss, Yellow: Oversized (Will override user's colors enabled)
ENABLE_DRAW_TYPE_VISUALIZATION :: false

Font_ID :: distinct i16
Glyph   :: distinct i32

Load_Font_Error :: enum(i32) {
	None,
	Parser_Failed,
}

Entry :: struct {
	parser_info   : Parser_Font_Info,
	shaper_info   : Shaper_Info,
	id            : Font_ID,
	used          : b32,
	curve_quality : f32,

	ascent   : f32,
	descent  : f32,
	line_gap : f32,
}

Entry_Default :: Entry {
	id            = 0,
	used          = false,
	curve_quality = 3,
}

// Ease of use encapsulation of common fields for a canvas space
VPZ_Transform :: struct {
	view     : Vec2,
	position : Vec2,
	zoom     : f32,
}

Scope_Stack :: struct {
	font      : [dynamic]Font_ID,
	font_size : [dynamic]f32,
	colour    : [dynamic]RGBAN,
	view      : [dynamic]Vec2,
	position  : [dynamic]Vec2,
	scale     : [dynamic]Vec2,
	zoom      : [dynamic]f32,
}

Context :: struct {
	backing : Allocator,

	parser_ctx  : Parser_Context, // Glyph parser state
	shaper_ctx  : Shaper_Context, // Text shaper state

	// The managed font instances
	entries : [dynamic]Entry,

	// TODO(Ed): Review these when preparing to handle lifting of working context to a thread context.
	glyph_buffer : Glyph_Draw_Buffer, // -> draw.odin
	atlas        : Atlas,             // -> atlas.odin
	shape_cache  : Shaped_Text_Cache, // -> shaper.doin
	draw_list    : Draw_List,         // -> draw.odin

	batch_shapes_buffer : [dynamic]Shaped_Text, // Used for the procs that batch a layer of text.

	// Tracks the offsets for the current layer in a draw_list
	draw_layer : struct { 
		vertices_offset : int,
		indices_offset  : int,
		calls_offset    : int,
	},
	// See: get_draw_list_layer & flush_draw_list_layer

	// Note(Ed): Not really used anymore.
	// debug_print         : b32,
	// debug_print_verbose : b32,

	// Will enforce even px_size when drawing.
	even_size_only : f32,

	// Whether or not to snap positioning to the pixel of the view
	// Helps with hinting
	snap_to_view_extent : b32,

	stack : Scope_Stack,

	cursor_pos : Vec2,
	// Will apply a boost scalar (1.0 + alpha sharpen) to the colour's alpha which provides some sharpening of the edges.
	// Has a boldening side-effect. If overblown will look smeared.
	alpha_sharpen : f32,
	// Used by draw interface to super-scale the text by 
	// upscaling px_size with px_scalar and then down-scaling
	// the draw_list result by the same amount.
	px_scalar        : f32,   // Improves hinting, positioning, etc. Can make zoomed out text too jagged.
	zoom_px_interval : f32,   // When using zoom, the size can be locked to to this interval (fixes text width jitter)

	default_curve_quality : i32,
}

//#region("Init Params")

Init_Atlas_Params :: struct {
	size_multiplier : u32, // How much to scale the the atlas size to. (Affects everything, the base is 4096 x 2048 and everything follows from there)
	glyph_padding   : u32, // Padding to add to bounds_<width/height>_scaled for choosing which atlas region.
}

Init_Atlas_Params_Default :: Init_Atlas_Params {
	size_multiplier = 1,
	glyph_padding   = 1,
}

Init_Glyph_Draw_Params :: struct {
	// During the draw list generation stage when blitting to atlas, the quad wil be ceil()'d to the closest pixel.
	snap_glyph_height         : b32,
	// Intended to be x16 (4x4) super-sampling from the glyph buffer to the atlas.
	// Oversized glyphs don't use this and instead do 2x or 1x depending on how massive they are.
	over_sample               : u32,
	// Best to just keep this the same as glyph_padding for the atlas..
	draw_padding              : u32,
	shape_gen_scratch_reserve : u32,
	// How many region.D glyphs can be drawn to the glyph render target buffer at once (worst case scenario)
	buffer_glyph_limit        : u32,
	// How many glyphs can at maximimum be proccessed at once by batch_generate_glyphs_draw_list
	batch_glyph_limit         : u32,
}

Init_Glyph_Draw_Params_Default :: Init_Glyph_Draw_Params {
	snap_glyph_height               = true,
	over_sample                     = 4,
	draw_padding                    = Init_Atlas_Params_Default.glyph_padding,
	shape_gen_scratch_reserve       = 512,
	buffer_glyph_limit              = 16,
	batch_glyph_limit               = 256,
}

Init_Shaper_Params :: struct {
	// Forces a glyph position to align to a pixel (make sure to use snap_to_view_extent with this or else it won't be preserveds)
	snap_glyph_position           : b32,
	// Will use more signficant advance during shaping for fonts 
	// Note(Ed): Thinking of removing, doesn't look good often and its an extra condition in the hot-loop.
	adv_snap_small_font_threshold : u32,
}

Init_Shaper_Params_Default :: Init_Shaper_Params {
	snap_glyph_position           = true,
	adv_snap_small_font_threshold = 0,
}

Init_Shape_Cache_Params :: struct {
	// Note(Ed): This should mostly just be given the worst-case capacity and reserve at the same time.
	// If memory is a concern it can easily be 256 - 2k if not much text is going to be rendered often.
	// Shapes should really not exceed 1024 glyphs..
	capacity : u32,
	reserve  : u32,
}

Init_Shape_Cache_Params_Default :: Init_Shape_Cache_Params {
	capacity = 10 * 1024,
	reserve  = 128,
}

//#endregion("Init Params")

//#region("lifetime")

// ve_fontcache_init
startup :: proc( ctx : ^Context, parser_kind : Parser_Kind = .STB_TrueType, // Note(Ed): Only sbt_truetype supported for now.
	allocator                   := context.allocator,
	atlas_params                := Init_Atlas_Params_Default,
	glyph_draw_params           := Init_Glyph_Draw_Params_Default,
	shape_cache_params          := Init_Shape_Cache_Params_Default,
	shaper_params               := Init_Shaper_Params_Default,
	alpha_sharpen               : f32 = 0.35,
	px_scalar                   : f32 = 1.6,
	zoom_px_interval            : i32 = 2,
	
	// Curve quality to use for a font when unspecified,
	// Affects step size for bezier curve passes in generate_glyph_pass_draw_list
	default_curve_quality       : u32 = 3,
	entires_reserve             : u32 = 256,
	scope_stack_reserve         : u32 = 32,
)
{
	assert( ctx != nil, "Must provide a valid context" )

	ctx.backing       = allocator
	context.allocator = ctx.backing

	ctx.alpha_sharpen    = alpha_sharpen
	ctx.px_scalar        = px_scalar
	ctx.zoom_px_interval = f32(zoom_px_interval)

	shaper_ctx := & ctx.shaper_ctx
	shaper_ctx.adv_snap_small_font_threshold = f32(shaper_params.adv_snap_small_font_threshold)
	shaper_ctx.snap_glyph_position           = shaper_params.snap_glyph_position

	ctx.default_curve_quality = default_curve_quality == 0 ? 3 : i32(default_curve_quality)

	error : Allocator_Error
	ctx.entries, error = make( [dynamic]Entry, len = 0, cap = entires_reserve )
	assert(error == .None, "VEFontCache.init : Failed to allocate entries")

	ctx.draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = 8 * Kilobyte )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.vertices")

	ctx.draw_list.indices, error = make( [dynamic]u32, len = 0, cap = 16 * Kilobyte )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.indices")

	ctx.draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = Kilobyte )
	assert(error == .None, "VEFontCache.init : Failed to allocate draw_list.calls")
	
	atlas := & ctx.atlas
	Atlas_Setup:
	{
		atlas.size_multiplier = f32(atlas_params.size_multiplier)

		atlas_size    := Vec2i { 4096, 2048 } * i32(atlas.size_multiplier)
		slot_region_a := Vec2i {  32,  32 }   * i32(atlas.size_multiplier)
		slot_region_b := Vec2i {  32,  64 }   * i32(atlas.size_multiplier)
		slot_region_c := Vec2i {  64,  64 }   * i32(atlas.size_multiplier)
		slot_region_d := Vec2i { 128, 128 }   * i32(atlas.size_multiplier)
		
		init_atlas_region :: proc( region : ^Atlas_Region, atlas_size, slot_size : Vec2i, factor : Vec2i )
		{
			region.next_idx  = 0;
			region.slot_size = slot_size
			region.size      =  atlas_size / factor
			region.capacity  = region.size / region.slot_size

			error : Allocator_Error
			lru_init( & region.state, region.capacity.x * region.capacity.y )
		}
		init_atlas_region( & atlas.region_a, atlas_size, slot_region_a, { 4, 2})
		init_atlas_region( & atlas.region_b, atlas_size, slot_region_b, { 4, 2})
		init_atlas_region( & atlas.region_c, atlas_size, slot_region_c, { 4, 1})
		init_atlas_region( & atlas.region_d, atlas_size, slot_region_d, { 2, 1})

		atlas.size          = atlas_size
		atlas.glyph_padding = f32(atlas_params.glyph_padding)

		atlas.region_a.offset   = {0, 0}
		atlas.region_b.offset.x = 0
		atlas.region_b.offset.y = atlas.region_a.size.y
		atlas.region_c.offset.x = atlas.region_a.size.x
		atlas.region_c.offset.y = 0
		atlas.region_d.offset.x = atlas.size.x / 2
		atlas.region_d.offset.y = 0

		atlas.regions = {
			nil,
			& atlas.region_a,
			& atlas.region_b,
			& atlas.region_c,
			& atlas.region_d,
		}
	}

	Shape_Cache_Setup:
	{
		shape_cache := & ctx.shape_cache
		lru_init( & shape_cache.state, i32(shape_cache_params.capacity) )

		shape_cache.storage, error = make( [dynamic]Shaped_Text, shape_cache_params.capacity )
		assert(error == .None, "VEFontCache.init : Failed to allocate shape_cache.storage")

		for idx : u32 = 0; idx < shape_cache_params.capacity; idx += 1
		{
			stroage_entry := & shape_cache.storage[idx]

			stroage_entry.glyph, error = make( [dynamic]Glyph, len = 0, cap = shape_cache_params.reserve )
			assert( error == .None, "VEFontCache.init : Failed to allocate glyphs array for shape cache storage" )

			stroage_entry.position, error = make( [dynamic]Vec2, len = 0, cap = shape_cache_params.reserve )
			assert( error == .None, "VEFontCache.init : Failed to allocate positions array for shape cache storage" )

			stroage_entry.atlas_lru_code, error = make( [dynamic]Atlas_Key, len = 0, cap = shape_cache_params.reserve )
			assert( error == .None, "VEFontCache.init : Failed to allocate atlas_lru_code array for shape cache storage" )

			stroage_entry.region_kind, error = make( [dynamic]Atlas_Region_Kind, len = 0, cap = shape_cache_params.reserve )
			assert( error == .None, "VEFontCache.init : Failed to allocate region_kind array for shape cache storage" )

			stroage_entry.bounds, error = make( [dynamic]Range2, len = 0, cap = shape_cache_params.reserve )
			assert( error == .None, "VEFontCache.init : Failed to allocate bounds array for shape cache storage" )

			// stroage_entry.bounds_scaled, error = make( [dynamic]Range2, len = 0, cap = shape_cache_params.reserve )
			// assert( error == .None, "VEFontCache.init : Failed to allocate bounds_scaled array for shape cache storage" )
		}
	}

	Glyph_Buffer_Setup:
	{
		glyph_buffer := & ctx.glyph_buffer
		glyph_buffer.snap_glyph_height = cast(f32) i32(glyph_draw_params.snap_glyph_height)
		glyph_buffer.over_sample       = { f32(glyph_draw_params.over_sample), f32(glyph_draw_params.over_sample) }
		glyph_buffer.size.x            = atlas.region_d.slot_size.x * i32(glyph_buffer.over_sample.x) * i32(glyph_draw_params.buffer_glyph_limit)
		glyph_buffer.size.y            = atlas.region_d.slot_size.y * i32(glyph_buffer.over_sample.y)
		glyph_buffer.draw_padding      = cast(f32) glyph_draw_params.draw_padding

		glyph_buffer.draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = 8 * Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for glyph_buffer.draw_list" )

		glyph_buffer.draw_list.indices, error = make( [dynamic]u32, len = 0, cap = 16 * Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate indices for glyph_buffer.draw_list" )

		glyph_buffer.draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for glyph_buffer.draw_list" )

		glyph_buffer.clear_draw_list.vertices, error = make( [dynamic]Vertex, len = 0, cap = 2 * Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate vertices array for clear_draw_list" )

		glyph_buffer.clear_draw_list.indices, error = make( [dynamic]u32, len = 0, cap = 4 * Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for indices array for clear_draw_list" )

		glyph_buffer.clear_draw_list.calls, error = make( [dynamic]Draw_Call, len = 0, cap = Kilobyte )
		assert( error == .None, "VEFontCache.init : Failed to allocate calls for calls for clear_draw_list" )

		glyph_buffer.shape_gen_scratch, error = make( [dynamic]Vertex, len = 0, cap = glyph_draw_params.shape_gen_scratch_reserve )
		assert(error == .None, "VEFontCache.init : Failed to allocate shape_gen_scratch")

		batch_cache    := & glyph_buffer.batch_cache
		batch_cache.cap = i32(glyph_draw_params.batch_glyph_limit)
		batch_cache.num = 0
		batch_cache.table, error = make( map[Atlas_Key]b8, uint(glyph_draw_params.batch_glyph_limit) )
		assert(error == .None, "VEFontCache.init : Failed to allocate batch_cache")

		glyph_buffer.glyph_pack,error = make_soa( #soa[dynamic]Glyph_Pack_Entry, length = 0, capacity = uint(shape_cache_params.reserve) )
		glyph_buffer.oversized, error = make( [dynamic]i32, len = 0, cap = uint(shape_cache_params.reserve) )
		glyph_buffer.to_cache,  error = make( [dynamic]i32, len = 0, cap = uint(shape_cache_params.reserve) )
		glyph_buffer.cached,    error = make( [dynamic]i32, len = 0, cap = uint(shape_cache_params.reserve) )
	}

	parser_init( & ctx.parser_ctx, parser_kind )
	shaper_init( & ctx.shaper_ctx )

	// Scoping Stack
	{
		stack := &  ctx.stack

		error : Allocator_Error
		stack.font, error = make([dynamic]Font_ID, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.font")

		stack.font_size, error = make([dynamic]f32, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.font_size")

		stack.font_size, error = make([dynamic]f32, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.font_size")

		stack.colour, error = make([dynamic]RGBAN, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.colour")

		stack.view, error = make([dynamic]Vec2, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.view")

		stack.position, error = make([dynamic]Vec2, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.position")

		stack.scale, error = make([dynamic]Vec2, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.scale")

		stack.zoom, error = make([dynamic]f32, len = 0, cap = scope_stack_reserve)
		assert(error == .None, "VEFontCache.init : Failed to allocate stack.zoom")
	}

	// Set the default stack values
	// Will be popped on shutdown
	push_colour(ctx, {1, 1, 1, 1})
	push_font_size(ctx, 36)
	push_view(ctx, { 0, 0 })
	push_position(ctx, {0, 0})
	push_scale(ctx, 1.0)
	push_zoom(ctx, 1.0)
}

hot_reload :: proc( ctx : ^Context, allocator : Allocator )
{
	assert( ctx != nil )
	ctx.backing       = allocator
	context.allocator = ctx.backing

	atlas        := & ctx.atlas
	glyph_buffer := & ctx.glyph_buffer
	shape_cache  := & ctx.shape_cache
	draw_list    := & ctx.draw_list

	reload_array( & ctx.entries, allocator )

	reload_array( & glyph_buffer.draw_list.calls,    allocator )
	reload_array( & glyph_buffer.draw_list.indices,  allocator )
	reload_array( & glyph_buffer.draw_list.vertices, allocator )

	reload_array( & glyph_buffer.clear_draw_list.calls,    allocator )
	reload_array( & glyph_buffer.clear_draw_list.indices,  allocator )
	reload_array( & glyph_buffer.clear_draw_list.vertices, allocator )

	reload_map(   & glyph_buffer.batch_cache.table, allocator )
	reload_array( & glyph_buffer.shape_gen_scratch, allocator )

	reload_array_soa( & glyph_buffer.glyph_pack, allocator )
	reload_array(     & glyph_buffer.oversized,  allocator )
	reload_array(     & glyph_buffer.to_cache,   allocator )
	reload_array(     & glyph_buffer.cached,     allocator )

	lru_reload( & atlas.region_a.state, allocator)
	lru_reload( & atlas.region_b.state, allocator)
	lru_reload( & atlas.region_c.state, allocator)
	lru_reload( & atlas.region_d.state, allocator)

	lru_reload( & shape_cache.state, allocator )
	for idx : i32 = 0; idx < i32(len(shape_cache.storage)); idx += 1 {
		storage_entry := & shape_cache.storage[idx]
		reload_array( & storage_entry.glyph,       allocator)
		reload_array( & storage_entry.position,       allocator)
		reload_array( & storage_entry.atlas_lru_code, allocator)
		reload_array( & storage_entry.region_kind,    allocator)
		reload_array( & storage_entry.bounds,         allocator)
		// reload_array( & storage_entry.bounds_scaled,  allocator)
	}
	reload_array( & shape_cache.storage, allocator )
	
	reload_array( & draw_list.vertices, allocator)
	reload_array( & draw_list.indices,  allocator)
	reload_array( & draw_list.calls,    allocator)

	parser_reload(& ctx.parser_ctx, allocator)

	// Scope Stack
	{
		stack := & ctx.stack
		reload_array(& stack.font,      allocator)
		reload_array(& stack.font_size, allocator)
		reload_array(& stack.colour,    allocator)
		reload_array(& stack.view,      allocator)
		reload_array(& stack.position,  allocator)
		reload_array(& stack.scale,     allocator)
		reload_array(& stack.zoom,      allocator)
	}
}

shutdown :: proc( ctx : ^Context )
{
	assert( ctx != nil )
	context.allocator = ctx.backing

	atlas        := & ctx.atlas
	glyph_buffer := & ctx.glyph_buffer
	shape_cache  := & ctx.shape_cache
	draw_list    := & ctx.draw_list

	pop_colour(ctx)
	pop_font_size(ctx)
	pop_view(ctx)
	pop_position(ctx)
	pop_scale(ctx)
	pop_zoom(ctx)

	for & entry in ctx.entries {
		unload_font( ctx, entry.id )
	}
	delete( ctx.entries )
	
	delete( glyph_buffer.draw_list.vertices )
	delete( glyph_buffer.draw_list.indices )
	delete( glyph_buffer.draw_list.calls )

	delete( glyph_buffer.clear_draw_list.vertices )
	delete( glyph_buffer.clear_draw_list.indices )
	delete( glyph_buffer.clear_draw_list.calls )

	delete( glyph_buffer.batch_cache.table )
	delete( glyph_buffer.shape_gen_scratch )

	delete_soa( glyph_buffer.glyph_pack)
	delete(     glyph_buffer.oversized)
	delete(     glyph_buffer.to_cache)
	delete(     glyph_buffer.cached)

	lru_free( & atlas.region_a.state )
	lru_free( & atlas.region_b.state )
	lru_free( & atlas.region_c.state )
	lru_free( & atlas.region_d.state )

	for idx : i32 = 0; idx < i32(len(shape_cache.storage)); idx += 1 {
		storage_entry := & shape_cache.storage[idx]
		delete( storage_entry.glyph )
		delete( storage_entry.position )
		delete( storage_entry.atlas_lru_code)
		delete( storage_entry.region_kind)
		delete( storage_entry.bounds)
		// delete( storage_entry.bounds_scaled)
	}
	lru_free( & shape_cache.state )
	
	delete( draw_list.vertices )
	delete( draw_list.indices )
	delete( draw_list.calls )

	shaper_shutdown( & ctx.shaper_ctx )
	parser_shutdown( & ctx.parser_ctx )

	// Scope Stack
	{
		stack := & ctx.stack
		delete(stack.font)
		delete(stack.font_size)
		delete(stack.colour)
		delete(stack.view)
		delete(stack.position)
		delete(stack.scale)
		delete(stack.zoom)
	}
}

load_font :: proc( ctx : ^Context, label : string, data : []byte, glyph_curve_quality : u32 = 0 ) -> (font_id : Font_ID, error : Load_Font_Error)
{
	profile(#procedure)
	assert( ctx != nil )
	assert( len(data) > 0 )
	context.allocator = ctx.backing

	entries := & ctx.entries

	id : Font_ID = -1

	for index : i32 = 0; index < i32(len(entries)); index += 1 {
		if entries[index].used do continue
		id = Font_ID(index)
		break
	}
	if id == -1 {
		append_elem( entries, Entry {})
		id = cast(Font_ID) len(entries) - 1
	}
	assert( id >= 0 && id < Font_ID(len(entries)) )

	entry := & entries[ id ]
	{
		entry.used = true

		profile_begin("calling loaders")
		parser_error : b32
		entry.parser_info, parser_error = parser_load_font( & ctx.parser_ctx, label, data )
		if parser_error {
			error = .Parser_Failed
			return
		}
		entry.shaper_info = shaper_load_font( & ctx.shaper_ctx, label, data )
		profile_end()

		ascent, descent, line_gap := parser_get_font_vertical_metrics(entry.parser_info)
		entry.ascent   = f32(ascent)
		entry.descent  = f32(descent)
		entry.line_gap = f32(line_gap)

		if glyph_curve_quality == 0 {
			entry.curve_quality = f32(ctx.default_curve_quality)
		}
		else {
			entry.curve_quality = f32(glyph_curve_quality)
		}
	}
	entry.id = Font_ID(id)
	ctx.entries[ id ].id = Font_ID(id)

	font_id = Font_ID(id)
	return
}

unload_font :: proc( ctx : ^Context, font : Font_ID )
{
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )
	context.allocator = ctx.backing

	entry     := & ctx.entries[ font ]
	entry.used = false

	parser_unload_font( & entry.parser_info )
	shaper_unload_font( & entry.shaper_info )
}

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
	lru_clear(& ctx.shape_cache.state)
	for idx : i32 = 0; idx < cast(i32) cap(ctx.shape_cache.storage); idx += 1 {
		stroage_entry := & ctx.shape_cache.storage[idx]
		stroage_entry.end_cursor_pos = {}
		stroage_entry.size           = {}
		clear(& stroage_entry.glyph)
		clear(& stroage_entry.position)
	}
	ctx.shape_cache.next_cache_id = 0
}

//#endregion("lifetime")

//#region("shaping")

// For high performance, the user should track the shapes and use the draw list interface on shapes. 
// Doing so avoids cache lookups.

shape_text :: #force_inline proc( ctx : ^Context, font : Font_ID, px_size : f32, text_utf8 : string, 
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz
) -> Shaped_Text
{
	profile(#procedure)
	assert( len(text_utf8) > 0 )
	entry := ctx.entries[ font ]

	target_px_size    := px_size * ctx.px_scalar
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	return shaper_shape_text_cached( text_utf8, 
		& ctx.shaper_ctx, 
		& ctx.shape_cache,
		ctx.atlas,
		vec2(ctx.glyph_buffer.size),
		font, 
		entry, 
		target_px_size, 
		target_font_scale, 
		shaper_proc
	)
}

// User handled shaped text. Will not be cached
shape_text_uncached :: #force_inline proc( ctx : ^Context, font : Font_ID, px_size: f32, text_utf8 : string, shape : ^Shaped_Text, 
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz 
)
{
	profile(#procedure)
	assert( len(text_utf8) > 0 )
	entry := ctx.entries[ font ]

	target_px_size    := px_size * ctx.px_scalar
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	shaper_proc(& ctx.shaper_ctx, 
		ctx.atlas, 
		vec2(ctx.glyph_buffer.size), 
		font,
		entry, 
		target_px_size, 
		target_font_scale, 
		text_utf8, 
		shape
	) 
	return
}

//#endregion("shaping")

//#region("draw_list generation")

/* The most basic interface-level draw shape procedure.
	Context's stack is not used. Only modifications for alpha sharpen and px_scalar are applied.
	view, position, and scale are expected to be in unsigned normalized space:
                                                          
|            +----------------------------------+ (1.0, 1.0)
|            |                                  |
|            |                                  |
|            |          Glyph Quad              |
|            |          +--------+ < scale.y    |
|            |          |   **   |  *     |     |
|            |          |  *  *  |  ****  |     |
|            |          |  ****  |  *  *  |     |
|            |          |  *  *  |  ****  |     |
|            |          +--------+--------+.... |
|            | position ^        ^ scale.x      |
|            |                                  |
|            |                                  |
|            |                                  |
| (0.0, 0.0) +----------------------------------+

    •   position: Anchor point in normalized space (where the bottom-right vertex of the first glyph quad will be positioned)
    <-> scale   : Scale the glyph beyond its default scaling from its px_size.
*/
@(optimization_mode="favor_size")
draw_text_shape_normalized_space :: #force_inline proc( ctx : ^Context, colour : RGBAN,  position : Vec2, scale : Vec2,  shape  : Shaped_Text )
{
	profile(#procedure)
	assert( ctx != nil )

	entry := ctx.entries[ shape.font ]

	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	target_px_size    := shape.px_size
	target_scale      := scale         * (1 / ctx.px_scalar)
	target_font_scale := parser_scale( entry.parser_info, shape.px_size )

	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale, 
		position, 
		target_scale, 
	)
}

/* Non-scoping context. The most basic interface-level draw shape procedure (everything else is quality of life warppers).

	Context's stack is not used. Only modifications for alpha sharpen and px_scalar are applied.
	view, position, and scale are expected to be in unsigned normalized space:
                                                          
|            +----------------------------------+ (1.0, 1.0)
|            |                                  |
|            |                                  |
|            |          Glyph Quad              |
|            |          +---------+ < scale.y   |
|            |          |   **   |  *     |     |
|            |          |  *  *  |  ****  |     |
|            |          |  ****  |  *  *  |     |
|            |          |  *  *  |  ****  |     |
|            |          +--------+--------+.... |
|            | position ^        ^ scale.x      |
|            |                                  |
|            |                                  |
|            |                                  |
| (0.0, 0.0) +----------------------------------+

    •   position: Anchor point in normalized space (where the bottom-right vertex of the first glyph quad will be positioned)
    <-> scale   : Scale the glyph beyond its default scaling from its px_size.
*/
@(optimization_mode = "favor_size")
draw_text_normalized_space :: proc( ctx : ^Context, 
	font        : Font_ID,
	px_size     : f32,
	colour      : RGBAN,
	position    : Vec2,
	scale       : Vec2, 
	text_utf8   : string,
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz
)
{
	profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )
	assert( len(text_utf8) > 0 )

	ctx.cursor_pos = {}
	entry := ctx.entries[ font ]

	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	// Does nothing when px_scalar is 1.0
	target_px_size    := px_size * ctx.px_scalar
	target_scale      := scale   * (1 / ctx.px_scalar)
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	shape := shaper_shape_text_cached( text_utf8, & ctx.shaper_ctx, & ctx.shape_cache, ctx.atlas, vec2(ctx.glyph_buffer.size),
		font, 
		entry, 
		target_px_size,
		target_font_scale, 
		shaper_proc
	)
	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale, 
		position,
		target_scale, 
	)
}

/* Equivalent to draw_text_shape_normalized_space, however the coordinate space is expected to be relative to the view.
	view, position, and scale are expected to be in unsigned view space:
                                                          
|            +----------------------------------+ (view.x, view.y)
|            |                                  |
|            |                                  |
|            |          Glyph Quad              |
|            |          +---------+ < scale.y   |
|            |          |   **   |  *     |     |
|            |          |  *  *  |  ****  |     |
|            |          |  ****  |  *  *  |     |
|            |          |  *  *  |  ****  |     |
|            |          +--------+--------+.... |
|            | position ^        ^ scale.x      |
|            |                                  |
|            |                                  |
|            |                                  |
| (0.0, 0.0) +----------------------------------+

	□   view    : The coordinate space is scaled to the view. Positions will be snapped to it.
    •   position: Anchor point in normalized space (where the bottom-right vertex of the first glyph quad will be positioned)
    <-> scale   : Scale the glyph beyond its default scaling from its px_size.
	    zoom    : Will affect the scale similar to how the zoom on a canvas would behave.
*/
// @(optimization_mode="favor_size")
draw_text_shape_view_space :: #force_inline proc( ctx : ^Context,
	colour   : RGBAN, 
	view     : Vec2,
	position : Vec2,
	scale    : Vec2, 
	zoom     : f32,
	shape    : Shaped_Text
)
{
	profile(#procedure)
	assert( ctx != nil )
	// TODO(Ed): This should be taken from the shape instead (you cannot use a different font with a shape)
	assert( ctx.px_scalar > 0.0 )

	entry := ctx.entries[ shape.font ]

	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	px_scalar_quotient := (1 / ctx.px_scalar)
	px_size             := shape.px_size * px_scalar_quotient

	resolved_size,   zoom_scale := resolve_zoom_size_scale( zoom, px_size, scale, ctx.zoom_px_interval, 2, 999.0, view )
	target_position, norm_scale := get_normalized_position_scale( position, zoom_scale, view )

	// Does nothing if px_scalar is 1.0
	target_px_size    := resolved_size * ctx.px_scalar
	target_scale      := norm_scale    * px_scalar_quotient
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale, 
		target_position, 
		target_scale, 
	)
}

/* Equivalent to draw_text_shape_normalized_space, however the coordinate space is expected to be relative to the view.
	view, position, and scale are expected to be in unsigned view space:
                                                          
|            +----------------------------------+ (view.x, view.y)
|            |                                  |
|            |                                  |
|            |          Glyph Quad              |
|            |          +---------+ < scale.y   |
|            |          |   **   |  *     |     |
|            |          |  *  *  |  ****  |     |
|            |          |  ****  |  *  *  |     |
|            |          |  *  *  |  ****  |     |
|            |          +--------+--------+.... |
|            | position ^        ^ scale.x      |
|            |                                  |
|            |                                  |
|            |                                  |
| (0.0, 0.0) +----------------------------------+

	□   view    : The coordinate space is scaled to the view. Positions will be snapped to it.
    •   position: Anchor point in normalized space (where the bottom-right vertex of the first glyph quad will be positioned)
    <-> scale   : Scale the glyph beyond its default scaling from its px_size.
	    zoom    : Will affect the scale similar to how the zoom on a canvas would behave.
*/
// @(optimization_mode = "favor_size")
draw_text_view_space :: proc(ctx : ^Context,
	font        : Font_ID,
	px_size     : f32,
	colour      : RGBAN,
	view        : Vec2,
	position    : Vec2,
	scale       : Vec2, 
	zoom        : f32,
	text_utf8   : string,
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz
)
{
	profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )
	assert( len(text_utf8) > 0 )
	assert( ctx.px_scalar > 0.0 )

	ctx.cursor_pos = {}
	entry := ctx.entries[ font ]

	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	resolved_size,   zoom_scale := resolve_zoom_size_scale( zoom, px_size, scale, ctx.zoom_px_interval, 2, 999.0, view )
	target_position, norm_scale := get_normalized_position_scale( position, zoom_scale, view )

	// Does nothing if px_scalar is 1.0
	target_px_size    := resolved_size * ctx.px_scalar
	target_scale      := norm_scale    * (1 / ctx.px_scalar)
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	shape := shaper_shape_text_cached( text_utf8, & ctx.shaper_ctx, & ctx.shape_cache, ctx.atlas, vec2(ctx.glyph_buffer.size),
		font, 
		entry, 
		target_px_size,
		target_font_scale, 
		shaper_proc
	)
	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale, 
		target_position,
		target_scale, 
	)
}

/* Uses the ctx.stack, position and scale are relative to the position and scale on the stack.

absolute_position := peek(stack.position) + position
absolute_scale    := peek(stack.scale   ) * scale

|            +-----------------------------------+ (view.x, view.y)
|            |                                   |
|            |                                   |
|            |          Glyph Quad    absolute   |
|            |          +---------+ < scale.y    |
|            |          |   **    |  *     |     |
|            |          |  *  *   |  ****  |     |
|            |          |  ****   |  *  *  |     |
|            |          |  *  *   |  ****  |     |
|            |          +---------+--------+.... |
|            | absolute ^         ^ absolute     |
|            | position             scale.x      |
|            |                                   |
|            |                                   |
|            |                                   |
| (0.0, 0.0) +-----------------------------------+
*/
// @(optimization_mode = "favor_size")
draw_shape :: proc( ctx : ^Context, position, scale : Vec2, shape : Shaped_Text )
{
	profile(#procedure)
	assert( ctx != nil )
	assert( ctx.px_scalar > 0.0 )

	stack := & ctx.stack
	assert(len(stack.view)      > 0)
	assert(len(stack.colour)    > 0)
	assert(len(stack.position)  > 0)
	assert(len(stack.scale)     > 0)
	assert(len(stack.zoom)      > 0)

	// TODO(Ed): This should be taken from the shape instead (you cannot use a different font with a shape)
	font := peek(stack.font)
	assert( font >= 0 &&int(font) < len(ctx.entries) )

	view := peek(stack.view);

	ctx.cursor_pos = {}
	entry := ctx.entries[ font ]

	colour               := peek(stack.colour)
	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	px_scalar_quotient := 1 / ctx.px_scalar

	px_size := shape.px_size * px_scalar_quotient
	zoom    := peek(stack.zoom)

	resolved_size, zoom_scale := resolve_zoom_size_scale( zoom, px_size, scale, ctx.zoom_px_interval, 2, 999.0, view )

	absolute_position := peek(stack.position) + position
	absolute_scale    := peek(stack.scale)    * zoom_scale

	target_position, norm_scale := get_normalized_position_scale( absolute_position, absolute_scale, view )

	// Does nothing when px_scalar is 1.0
	target_px_size    := resolved_size * ctx.px_scalar
	target_scale      := norm_scale    * px_scalar_quotient
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale,
		target_position, 
		target_scale, 
	)
}

/* Uses the ctx.stack, position and scale are relative to the position and scale on the stack.

absolute_position := peek(stack.position) + position
absolute_scale    := peek(stack.scale   ) * scale

|            +-----------------------------------+ (view.x, view.y)
|            |                                   |
|            |                                   |
|            |          Glyph Quad    absolute   |
|            |          +---------+ < scale.y    |
|            |          |   **    |  *     |     |
|            |          |  *  *   |  ****  |     |
|            |          |  ****   |  *  *  |     |
|            |          |  *  *   |  ****  |     |
|            |          +---------+--------+.... |
|            | absolute ^         ^ absolute     |
|            | position             scale.x      |
|            |                                   |
|            |                                   |
|            |                                   |
| (0.0, 0.0) +-----------------------------------+
*/
// @(optimization_mode = "favor_size")
draw_text :: proc( ctx : ^Context, position, scale : Vec2, text_utf8 : string, 
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz 
)
{
	profile(#procedure)
	assert( ctx != nil )
	assert( len(text_utf8) > 0 )
	assert( ctx.px_scalar > 0.0 )

	stack := & ctx.stack
	assert(len(stack.font)      > 0)
	assert(len(stack.font_size) > 0)
	assert(len(stack.colour)    > 0)
	assert(len(stack.view)      > 0)
	assert(len(stack.position)  > 0)
	assert(len(stack.scale)     > 0)
	assert(len(stack.zoom)      > 0)

	font := peek(stack.font)
	assert( font >= 0 &&int(font) < len(ctx.entries) )

	view := peek(stack.view);

	ctx.cursor_pos = {}
	entry := ctx.entries[ font ]

	colour               := peek(stack.colour)
	should_alpha_sharpen := cast(f32) cast(i32) (colour.a >= 1.0)
	adjusted_colour      := colour
	adjusted_colour.a    += ctx.alpha_sharpen * should_alpha_sharpen

	px_size := peek(stack.font_size)
	zoom    := peek(stack.zoom)

	resolved_size, zoom_scale := resolve_zoom_size_scale( zoom, px_size, scale, ctx.zoom_px_interval, 2, 999.0, view )

	absolute_position := peek(stack.position) + position
	absolute_scale    := peek(stack.scale)    * scale

	target_position, norm_scale := get_normalized_position_scale( absolute_position, absolute_scale, view )

	// Does nothing when px_scalar is 1.0
	target_px_size    := resolved_size * ctx.px_scalar
	target_scale      := norm_scale    * (1 / ctx.px_scalar)
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	shape := shaper_shape_text_cached( text_utf8, & ctx.shaper_ctx, & ctx.shape_cache, ctx.atlas, vec2(ctx.glyph_buffer.size),
		font, 
		entry, 
		target_px_size,
		target_font_scale, 
		shaper_proc
	)
	ctx.cursor_pos = generate_shape_draw_list( & ctx.draw_list, shape, & ctx.atlas, & ctx.glyph_buffer,
		ctx.px_scalar,
		adjusted_colour, 
		entry, 
		target_px_size,
		target_font_scale, 
		target_position,
		target_scale, 
	)
}

get_draw_list :: #force_inline proc( ctx : ^Context, optimize_before_returning := true ) -> ^Draw_List {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, 0 )
	return & ctx.draw_list
}

get_draw_list_layer :: #force_inline proc( ctx : ^Context, optimize_before_returning := true ) -> (vertices : []Vertex, indices : []u32, calls : []Draw_Call) {
	assert( ctx != nil )
	if optimize_before_returning do optimize_draw_list( & ctx.draw_list, ctx.draw_layer.calls_offset )
	vertices = ctx.draw_list.vertices[ ctx.draw_layer.vertices_offset : ]
	indices  = ctx.draw_list.indices [ ctx.draw_layer.indices_offset  : ]
	calls    = ctx.draw_list.calls   [ ctx.draw_layer.calls_offset    : ]
	return
}

flush_draw_list :: #force_inline proc( ctx : ^Context ) {
	assert( ctx != nil )
	clear_draw_list( & ctx.draw_list )
	ctx.draw_layer.vertices_offset = 0
	ctx.draw_layer.indices_offset  = 0
	ctx.draw_layer.calls_offset    = 0
}

flush_draw_list_layer :: #force_inline proc( ctx : ^Context ) {
	assert( ctx != nil )
	ctx.draw_layer.vertices_offset = len(ctx.draw_list.vertices)
	ctx.draw_layer.indices_offset  = len(ctx.draw_list.indices)
	ctx.draw_layer.calls_offset    = len(ctx.draw_list.calls)
}

//#endregion("draw_list generation")

//#region("metrics")

// The metrics follow the convention for providing their values unscaled from ctx.px_scalar
// Where its assumed when utilizing the draw_list generators or shaping procedures that the shape will be affected by it so it must be handled.
// If px_scalar is 1.0 no effect is done and its just redundant ops.

measure_shape_size :: #force_inline proc( ctx : ^Context, shape : Shaped_Text ) -> (measured : Vec2) {
	measured = shape.size * (1 / ctx.px_scalar)
	return
}

// Don't use this if you already have the shape instead use measure_shape_size
measure_text_size :: #force_inline proc( ctx : ^Context, font : Font_ID, px_size : f32, text_utf8 : string, 
	shaper_proc : $Shaper_Shape_Text_Uncached_Proc = shaper_shape_harfbuzz
) -> (measured : Vec2)
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry := ctx.entries[font]

	target_scale      := 1 / ctx.px_scalar
	target_px_size    := px_size * ctx.px_scalar
	target_font_scale := parser_scale( entry.parser_info, target_px_size )

	shaped := shaper_shape_text_cached( text_utf8, 
		& ctx.shaper_ctx, 
		& ctx.shape_cache, 
		ctx.atlas, 
		vec2(ctx.glyph_buffer.size),
		font, 
		entry, 
		target_px_size, 
		target_font_scale, 
		shaper_proc 
	)
	return shaped.size * target_scale
}

get_font_vertical_metrics :: #force_inline proc ( ctx : ^Context, font : Font_ID, px_size : f32 ) -> ( ascent, descent, line_gap : f32 )
{
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	entry := ctx.entries[ font ]
	
	font_scale := parser_scale( entry.parser_info, px_size )

	ascent   = font_scale * entry.ascent
	descent  = font_scale * entry.descent
	line_gap = font_scale * entry.line_gap
	return
}

//#endregion("metrics")

//#region("miscellaneous")

get_cursor_pos :: #force_inline proc "contextless" ( ctx : Context ) -> Vec2 { return ctx.cursor_pos }

// Will normalize the value of the position and scale based on the provided view.
// Position will also be snapped to the nearest pixel via ceil.
// (Does nothing if view is 1 or 0)
get_normalized_position_scale :: #force_inline proc "contextless" ( position, scale, view : Vec2 ) -> (position_norm, scale_norm : Vec2)
{
	snap_quotient := 1 / Vec2 { max(view.x, 1), max(view.y, 1) }
	should_snap   := view * snap_quotient

	snapped_position  := position 
	snapped_position.x = ceil(position.x * view.x) * snap_quotient.x 
	snapped_position.y = ceil(position.y * view.y) * snap_quotient.y

	snapped_position  *= should_snap
	snapped_position.x = max(snapped_position.x, position.x)
	snapped_position.y = max(snapped_position.y, position.y)

	position_norm = snapped_position
	scale_norm    = scale * snap_quotient
	return
}

// Used to constrain the px_size used in draw calls.
resolve_draw_px_size :: #force_inline proc "contextless" ( px_size, interval, min, max : f32 ) -> (resolved_size : f32) {
	interval_quotient := 1.0 / f32(interval)
	interval_size     := round(px_size * interval_quotient) * interval
	resolved_size      = clamp( interval_size, min, max )
	return
}

// Provides a way to get a "zoom" on the font size and scale, similar conceptually to a canvas UX zoom
// Does nothing when zoom is 1.0
resolve_zoom_size_scale :: #force_inline proc "contextless" ( 
	zoom, px_size : f32, scale : Vec2, interval, min, max : f32, clamp_scale : Vec2 
) -> (resolved_size : f32, zoom_scale : Vec2)
{
	zoom_px_size     := px_size * zoom
	resolved_size     = resolve_draw_px_size( zoom_px_size, interval, min, max )
	zoom_diff_scalar := 1 + (zoom_px_size - resolved_size) * (1 / resolved_size)
	zoom_scale        = zoom_diff_scalar * scale
	zoom_scale.x      = clamp(zoom_scale.x, 0, clamp_scale.x)
	zoom_scale.y      = clamp(zoom_scale.y, 0, clamp_scale.y)
	return
}

set_alpha_scalar     :: #force_inline proc( ctx : ^Context, scalar   : f32 ) { assert(ctx != nil); ctx.alpha_sharpen    = scalar }
set_px_scalar        :: #force_inline proc( ctx : ^Context, scalar   : f32 ) { assert(ctx != nil); ctx.px_scalar        = scalar }
set_zoom_px_interval :: #force_inline proc( ctx : ^Context, interval : i32 ) { assert(ctx != nil); ctx.zoom_px_interval = f32(interval) }

// During a shaping pass on text, will snap each glyph's position via ceil.
set_snap_glyph_shape_position :: #force_inline proc( ctx : ^Context, should_snap : b32 ) {
	assert(ctx != nil)
	ctx.shaper_ctx.snap_glyph_position = should_snap
}

// During to_cache pass within batch_generate_glyphs_draw_list, will snap the quad's size using ceil.
set_snap_glyph_render_height :: #force_inline proc( ctx : ^Context, should_snap : b32 ) { 
	assert(ctx != nil)
	ctx.glyph_buffer.snap_glyph_height = cast(f32) i32(should_snap)
}

//#endregion("misc")

//#region("scope stack")

/* Scope stacking ease of use interface.

View: Extents in 2D for the relative space the the text is being drawn within.
Used with snap_to_view_extent to enforce position snapping.

Position: Used with a draw procedure that uses relative positioning will offset the incoming position by the given amount.
Scale   : Used with a draw procedure that uses relative scaling, will scale the procedures incoming scale by the given amount.
Zoom    : Used with a draw procedure that uses scaling via zoom, will scale the procedure's incoming font size & scale based on an 'canvas' camera's notion of it.
*/

@(deferred_in = auto_pop_font)
scope_font         :: #force_inline proc( ctx : ^Context, font     : Font_ID ) { assert(ctx != nil); append(& ctx.stack.font, font ) }
push_font          :: #force_inline proc( ctx : ^Context, font     : Font_ID ) { assert(ctx != nil); append(& ctx.stack.font, font ) }
pop_font           :: #force_inline proc( ctx : ^Context                     ) { assert(ctx != nil); pop(& ctx.stack.font) }
auto_pop_font      :: #force_inline proc( ctx : ^Context, font     : Font_ID ) { assert(ctx != nil); pop(& ctx.stack.font) }

@(deferred_in = auto_pop_font_size)
scope_font_size    :: #force_inline proc( ctx : ^Context, px_size  : f32     ) { assert(ctx != nil); append(& ctx.stack.font_size, px_size) }
push_font_size     :: #force_inline proc( ctx : ^Context, px_size  : f32     ) { assert(ctx != nil); append(& ctx.stack.font_size, px_size) }
pop_font_size      :: #force_inline proc( ctx : ^Context                     ) { assert(ctx != nil); pop(& ctx.stack.font_size) }
auto_pop_font_size :: #force_inline proc( ctx : ^Context, px_size  : f32     ) { assert(ctx != nil); pop(& ctx.stack.font_size) }

@(deferred_in = auto_pop_colour )
scope_colour       :: #force_inline proc( ctx : ^Context, colour   : RGBAN   ) { assert(ctx != nil); append(& ctx.stack.colour, colour) }
push_colour        :: #force_inline proc( ctx : ^Context, colour   : RGBAN   ) { assert(ctx != nil); append(& ctx.stack.colour, colour) }
pop_colour         :: #force_inline proc( ctx : ^Context                     ) { assert(ctx != nil); pop(& ctx.stack.colour) }
auto_pop_colour    :: #force_inline proc( ctx : ^Context, colour   : RGBAN   ) { assert(ctx != nil); pop(& ctx.stack.colour) }

@(deferred_in = auto_pop_view)
scope_view         :: #force_inline proc( ctx : ^Context, view     : Vec2    ) { assert(ctx != nil); append(& ctx.stack.view, view) }
push_view          :: #force_inline proc( ctx : ^Context, view     : Vec2    ) { assert(ctx != nil); append(& ctx.stack.view, view) }
pop_view           :: #force_inline proc( ctx : ^Context                     ) { assert(ctx != nil); pop(& ctx.stack.view) }
auto_pop_view      :: #force_inline proc( ctx : ^Context, view     : Vec2    ) { assert(ctx != nil); pop(& ctx.stack.view) }

@(deferred_in = auto_pop_position)
scope_position     :: #force_inline proc( ctx : ^Context, position : Vec2    ) { assert(ctx != nil); append(& ctx.stack.position, position ) }
push_position      :: #force_inline proc( ctx : ^Context, position : Vec2    ) { assert(ctx != nil); append(& ctx.stack.position, position ) }
pop_position       :: #force_inline proc( ctx : ^Context                     ) { assert(ctx != nil); pop( & ctx.stack.position) }
auto_pop_position  :: #force_inline proc( ctx : ^Context, view     : Vec2    ) { assert(ctx != nil); pop( & ctx.stack.position) }

@(deferred_in = auto_pop_scale)
scope_scale        :: #force_inline proc( ctx : ^Context, scale    : Vec2    ) { assert(ctx != nil); append(& ctx.stack.scale, scale ) }
push_scale         :: #force_inline proc( ctx : ^Context, scale    : Vec2    ) { assert(ctx != nil); append(& ctx.stack.scale, scale ) }
pop_scale          :: #force_inline proc( ctx : ^Context,                    ) { assert(ctx != nil); pop(& ctx.stack.scale) }
auto_pop_scale     :: #force_inline proc( ctx : ^Context, scale    : Vec2    ) { assert(ctx != nil); pop(& ctx.stack.scale) }

@(deferred_in = auto_pop_zoom )
scope_zoom         :: #force_inline proc( ctx : ^Context, zoom     : f32     ) { append(& ctx.stack.zoom, zoom ) }
push_zoom          :: #force_inline proc( ctx : ^Context, zoom     : f32     ) { append(& ctx.stack.zoom, zoom)  }
pop_zoom           :: #force_inline proc( ctx : ^Context                     ) { pop(& ctx.stack.zoom) }
auto_pop_zoom      :: #force_inline proc( ctx : ^Context, zoom     : f32     ) { pop(& ctx.stack.zoom) }

@(deferred_in = auto_pop_vpz)
scope_vpz    :: #force_inline proc( ctx : ^Context, camera : VPZ_Transform  ) { 
	assert(ctx != nil)
	append(& ctx.stack.view,     camera.view     )
	append(& ctx.stack.position, camera.position )
	append(& ctx.stack.zoom,     camera.zoom     )
}
push_vpz     :: #force_inline proc( ctx : ^Context, camera : VPZ_Transform  ) { 
	assert(ctx != nil)
	append(& ctx.stack.view,     camera.view     )
	append(& ctx.stack.position, camera.position )
	append(& ctx.stack.zoom,     camera.zoom     )
}
pop_vpz      :: #force_inline proc( ctx : ^Context ) {
	assert(ctx != nil)
	pop(& ctx.stack.view    )
	pop(& ctx.stack.position)
	pop(& ctx.stack.zoom    )
}
auto_pop_vpz :: #force_inline proc( ctx : ^Context, camera : VPZ_Transform ) { 
	assert(ctx != nil)
	pop(& ctx.stack.view    )
	pop(& ctx.stack.position)
	pop(& ctx.stack.zoom    )
}

//#endregion("scope stack")
