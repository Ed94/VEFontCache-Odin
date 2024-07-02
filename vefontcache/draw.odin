package vefontcache

import "thirdparty:freetype"
import "core:slice"

Vertex :: struct {
	pos  : Vec2,
	u, v : f32,
}

DrawCall :: struct {
	pass              : FrameBufferPass,
	start_index       : u32,
	end_index         : u32,
	clear_before_draw : b32,
	region            : AtlasRegionKind,
	colour            : Colour,
}

DrawCall_Default :: DrawCall {
	pass              = .None,
	start_index       = 0,
	end_index         = 0,
	clear_before_draw = false,
	region            = .A,
	colour            = { 1.0, 1.0, 1.0, 1.0 }
}

DrawList :: struct {
	vertices : [dynamic]Vertex,
	indices  : [dynamic]u32,
	calls    : [dynamic]DrawCall,
}

// TODO(Ed): This was a rough translation of the raw values the orignal was using, need to give better names...
FrameBufferPass :: enum u32 {
	None            = 0,
	Glyph           = 1,
	Atlas           = 2,
	Target          = 3,
	Target_Uncached = 4,
}

GlyphDrawBuffer :: struct {
	over_sample   : Vec2,
	batch         : i32,
	width         : i32,
	height        : i32,
	draw_padding  : i32,

	batch_x         : i32,
	clear_draw_list : DrawList,
	draw_list       : DrawList,
}

blit_quad :: proc( draw_list : ^DrawList, p0 : Vec2 = {0, 0}, p1 : Vec2 = {1, 1}, uv0 : Vec2 = {0, 0}, uv1 : Vec2 = {1, 1} )
{
	// profile(#procedure)
	// logf("Blitting: xy0: %0.2f, %0.2f xy1: %0.2f, %0.2f uv0: %0.2f, %0.2f uv1: %0.2f, %0.2f",
		// p0.x, p0.y, p1.x, p1.y, uv0.x, uv0.y, uv1.x, uv1.y);
	v_offset := cast(u32) len(draw_list.vertices)

	quadv : [4]Vertex = {
		{
			{p0.x, p0.y},
			uv0.x, uv0.y
		},
		{
			{p0.x, p1.y},
			uv0.x, uv1.y
		},
		{
			{p1.x, p0.y},
			uv1.x, uv0.y
		},
		{
			{p1.x, p1.y},
			uv1.x, uv1.y
		}
	}
	append( & draw_list.vertices, ..quadv[:] )

	quad_indices : []u32 = {
		0 + v_offset, 1 + v_offset, 2 + v_offset,
		2 + v_offset, 1 + v_offset, 3 + v_offset
	}
	append( & draw_list.indices, ..quad_indices[:] )
	return
}

// TODO(Ed): glyph caching cannot be handled in a 'font parser' abstraction. Just going to have explicit procedures to grab info neatly...
cache_glyph_freetype :: proc(ctx: ^Context, font: FontID, glyph_index: Glyph, entry: ^Entry, bounds_0, bounds_1: Vec2, scale, translate: Vec2) -> b32
{

	draw_filled_path_freetype :: proc( draw_list : ^DrawList, outside_point : Vec2, path : []Vertex,
		scale     := Vec2 { 1, 1 },
		translate := Vec2 { 0, 0 },
		debug_print_verbose : b32 = false
	)
	{
		if debug_print_verbose {
			log("outline_path:")
			for point in path {
				vec := point.pos * scale + translate
				logf(" %0.2f %0.2f", vec.x, vec.y )
			}
		}

		v_offset := cast(u32) len(draw_list.vertices)
		for point in path 
		{
			transformed_point := Vertex {
				pos = point.pos * scale + translate,
				u = 0,
				v = 0
			}
			append( & draw_list.vertices, transformed_point )
		}

		if len(path) > 2
		{
			indices := & draw_list.indices
			for index : u32 = 1; index < cast(u32) len(path) - 1; index += 1 {
				to_add := [3]u32 {
					v_offset,
					v_offset + index,
					v_offset + index + 1
				}
				append( indices, ..to_add[:] )
			}

			// Close the path by connecting the last vertex to the first two
			to_add := [3]u32 {
					v_offset,
					v_offset + cast(u32)(len(path) - 1),
					v_offset + 1
			}
			append( indices, ..to_add[:] )
		}
	}

	if glyph_index == Glyph(0) {
		return false
	}

	face := entry.parser_info.freetype_info
	error := freetype.load_glyph(face, u32(glyph_index), {.No_Bitmap, .No_Scale})
	if error != .Ok {
		return false
	}

	glyph := face.glyph
	if glyph.format != .Outline {
		return false
	}

	outline := &glyph.outline
	if outline.n_points == 0 {
		return false
	}

	draw            := DrawCall_Default
	draw.pass        = FrameBufferPass.Glyph
	draw.start_index = cast(u32) len(ctx.draw_list.indices)

	contours := slice.from_ptr(cast( [^]i16)             outline.contours, int(outline.n_contours))
	points   := slice.from_ptr(cast( [^]freetype.Vector) outline.points,   int(outline.n_points))
	tags     := slice.from_ptr(cast( [^]u8)              outline.tags,     int(outline.n_points))

	path := &ctx.temp_path
	clear(path)

	outside := Vec2{ bounds_0.x - 21, bounds_0.y - 33 }

	start_index: int = 0
	for contour_index in 0 ..< int(outline.n_contours)
	{
		end_index := int(contours[contour_index]) + 1
		prev_point: Vec2
		first_point: Vec2

			for idx := start_index; idx < end_index; idx += 1
			{
				current_pos := Vec2 { f32( points[idx].x ), f32( points[idx].y ) }
				if ( tags[idx] & 1 ) == 0
				{
					// If current point is off-curve
					if (idx == start_index || (tags[ idx - 1 ] & 1) != 0)
					{
							// current is the first or following an on-curve point
							prev_point = current_pos
					}
					else
					{
							// current and previous are off-curve, calculate midpoint
							midpoint := (prev_point + current_pos) * 0.5
							append( path, Vertex { pos = midpoint } )  // Add midpoint as on-curve point
							if idx < end_index - 1
							{
									// perform interp from prev_point to current_pos via midpoint
									step := 1.0 / entry.curve_quality
									for alpha : f32 = 0.0; alpha <= 1.0; alpha += step
									{
											bezier_point := eval_point_on_bezier3( prev_point, midpoint, current_pos, alpha )
											append( path, Vertex{ pos = bezier_point } )
									}
							}

							prev_point = current_pos
					}
				}
				else
				{
					if idx == start_index {
							first_point = current_pos
					}
					if prev_point != (Vec2{}) {
							// there was an off-curve point before this
							append(path, Vertex{ pos = prev_point}) // Ensure previous off-curve is handled
					}
					append(path, Vertex{ pos = current_pos})
					prev_point = {}
				}
			}

			// ensure the contour is closed
			if path[0].pos != path[ len(path) - 1 ].pos {
				append(path, Vertex{pos = path[0].pos})
			}
			draw_filled_path(&ctx.draw_list, bounds_0, path[:], scale, translate, ctx.debug_print_verbose)
			clear(path)
			start_index = end_index
	}

	if len(path) > 0 {
		draw_filled_path(&ctx.draw_list, outside, path[:], scale, translate, ctx.debug_print_verbose)
	}

	draw.end_index = cast(u32) len(ctx.draw_list.indices)
	if draw.end_index > draw.start_index {
		append( & ctx.draw_list.calls, draw)
	}

	return true
}

cache_glyph :: proc(ctx : ^Context, font : FontID, glyph_index : Glyph, entry : ^Entry, bounds_0, bounds_1 : Vec2, scale, translate : Vec2) -> b32
{
	// profile(#procedure)
	if glyph_index == Glyph(0) {
		return false
	}

	// Glyph shape handling are not abstractable between freetype and stb_truetype
	if entry.parser_info.kind == .Freetype {
		result := cache_glyph_freetype( ctx, font, glyph_index, entry, bounds_0, bounds_1, scale, translate )
		return result
	}

	shape, error := parser_get_glyph_shape(&entry.parser_info, glyph_index)
	assert(error == .None)
	if len(shape) == 0 {
		return false
	}

	outside := Vec2{bounds_0.x - 21, bounds_0.y - 33}

	draw            := DrawCall_Default
	draw.pass        = FrameBufferPass.Glyph
	draw.start_index = u32(len(ctx.draw_list.indices))

	path := &ctx.temp_path
	clear(path)

	for edge in shape do #partial switch edge.type
	{
		case .Move:
			if len(path) > 0 {
					draw_filled_path(&ctx.draw_list, outside, path[:], scale, translate, ctx.debug_print_verbose)
					clear(path)
			}
			fallthrough

		case .Line:
			append( path, Vertex { pos = Vec2 { f32(edge.x), f32(edge.y)} } )

		case .Curve:
			assert(len(path) > 0)
			p0 := path[ len(path) - 1].pos
			p1 := Vec2{ f32(edge.contour_x0), f32(edge.contour_y0) }
			p2 := Vec2{ f32(edge.x), f32(edge.y) }

			step := 1.0 / entry.curve_quality
			for index : f32 = 1; index <= entry.curve_quality; index += 1 {
				alpha := index * step
				append( path, Vertex { pos = eval_point_on_bezier3(p0, p1, p2, alpha) } )
			}

		case .Cubic:
			assert( len(path) > 0)
			p0 := path[ len(path) - 1].pos
			p1 := Vec2{ f32(edge.contour_x0), f32(edge.contour_y0) }
			p2 := Vec2{ f32(edge.contour_x1), f32(edge.contour_y1) }
			p3 := Vec2{ f32(edge.x), f32(edge.y) }

			step := 1.0 / entry.curve_quality
			for index : f32 = 1; index <= entry.curve_quality; index += 1 {
				alpha := index * step
				append( path, Vertex { pos = eval_point_on_bezier4(p0, p1, p2, p3, alpha) } )
			}
	}

	if len(path) > 0 {
		draw_filled_path(&ctx.draw_list, outside, path[:], scale, translate, ctx.debug_print_verbose)
	}

	draw.end_index = u32(len(ctx.draw_list.indices))
	if draw.end_index > draw.start_index {
		append( & ctx.draw_list.calls, draw)
	}

	parser_free_shape(&entry.parser_info, shape)
	return true
}

/*
	Called by:
	* can_batch_glyph : If it determines that the glyph was not detected and we haven't reached capacity in the atlas
	* draw_text_shape : Glyph
*/
cache_glyph_to_atlas :: proc( ctx : ^Context,
	font        : FontID,
	glyph_index : Glyph,
	lru_code    : u64,
	atlas_index : i32,
	entry       : ^Entry,
	region_kind : AtlasRegionKind,
	region      : ^AtlasRegion,
	over_sample : Vec2 )
{
	// profile(#procedure)

	// Get hb_font text metrics. These are unscaled!
	bounds_0, bounds_1 := parser_get_glyph_box( & entry.parser_info, glyph_index )
	bounds_size := Vec2 {
		f32(bounds_1.x - bounds_0.x),
		f32(bounds_1.y - bounds_0.y)
	}

	// E region is special case and not cached to atlas.
	if region_kind == .None || region_kind == .E do return

	// Grab an atlas LRU cache slot.
	atlas_index := atlas_index
	if atlas_index == -1
	{
		if region.next_idx < region.state.capacity
		{
			evicted         := LRU_put( & region.state, lru_code, i32(region.next_idx) )
			atlas_index      = i32(region.next_idx)
			region.next_idx += 1
			assert( evicted == lru_code )
		}
		else
		{
			next_evict_codepoint := LRU_get_next_evicted( & region.state )
			assert( next_evict_codepoint != 0xFFFFFFFFFFFFFFFF )

			atlas_index = LRU_peek( & region.state, next_evict_codepoint, must_find = true )
			assert( atlas_index != -1 )

			evicted := LRU_put( & region.state, lru_code, atlas_index )
			assert( evicted == next_evict_codepoint )
		}

		assert( LRU_get( & region.state, lru_code ) != - 1 )
	}

	atlas             := & ctx.atlas
	glyph_buffer      := & ctx.glyph_buffer
	atlas_size        := Vec2 { f32(atlas.width), f32(atlas.height) }
	glyph_buffer_size := Vec2 { f32(glyph_buffer.width), f32(glyph_buffer.height) }
	glyph_padding     := cast(f32) atlas.glyph_padding

	if ctx.debug_print
	{
		@static debug_total_cached : i32 = 0
		logf("glyph %v%v( %v ) caching to atlas region %v at idx %d. %d total glyphs cached.\n",
			i32(glyph_index), rune(glyph_index), cast(rune) region_kind, atlas_index, debug_total_cached)
		debug_total_cached += 1
	}

	// Draw oversized glyph to update FBO
	glyph_draw_scale       := over_sample * entry.size_scale
	glyph_draw_translate   := -1 * vec2(bounds_0) * glyph_draw_scale + vec2( glyph_padding )
	glyph_draw_translate.x  = cast(f32) (i32(glyph_draw_translate.x + 0.9999999))
	glyph_draw_translate.y  = cast(f32) (i32(glyph_draw_translate.y + 0.9999999))

	// Allocate a glyph_update_FBO region
	gwidth_scaled_px := bounds_size.x * glyph_draw_scale.x + 1.0 + over_sample.x * glyph_padding
  if i32(f32(glyph_buffer.batch_x) + gwidth_scaled_px) >= i32(glyph_buffer.width) {
		flush_glyph_buffer_to_atlas( ctx )
	}

	// Calculate the src and destination regions
	slot_position, slot_szie := atlas_bbox( atlas, region_kind, atlas_index )

	dst_glyph_position := slot_position
	dst_glyph_size     := bounds_size * entry.size_scale + glyph_padding
	dst_size           := slot_szie
	screenspace_x_form( & dst_glyph_position, & dst_glyph_size, atlas_size )
	screenspace_x_form( & slot_position,      & dst_size,       atlas_size )

	src_position := Vec2 { f32(glyph_buffer.batch_x), 0 }
	src_size     := bounds_size * glyph_draw_scale + over_sample * glyph_padding
	textspace_x_form( & src_position, & src_size, glyph_buffer_size )

	// Advance glyph_update_batch_x and calculate final glyph drawing transform
	glyph_draw_translate.x += f32(glyph_buffer.batch_x)
	glyph_buffer.batch_x   += i32(gwidth_scaled_px)
	screenspace_x_form( & glyph_draw_translate, & glyph_draw_scale, glyph_buffer_size )

	clear_target_region : DrawCall
	{
		using clear_target_region
		pass        = .Atlas
		region      = .Ignore
		start_index = cast(u32) len(glyph_buffer.clear_draw_list.indices)

		blit_quad( & glyph_buffer.clear_draw_list,
			slot_position, slot_position + dst_size,
			{ 1.0, 1.0 },  { 1.0, 1.0 } )

		end_index = cast(u32) len(glyph_buffer.clear_draw_list.indices)
	}

	blit_to_atlas : DrawCall
	{
		using blit_to_atlas
		pass        = .Atlas
		region      = .None
		start_index = cast(u32) len(glyph_buffer.draw_list.indices)

		blit_quad( & glyph_buffer.draw_list,
			dst_glyph_position, slot_position + dst_glyph_size,
			src_position,       src_position  + src_size )

		end_index = cast(u32) len(glyph_buffer.draw_list.indices)
	}

	append( & glyph_buffer.clear_draw_list.calls, clear_target_region )
	append( & glyph_buffer.draw_list.calls, blit_to_atlas )

	// Render glyph to glyph_update_FBO
	cache_glyph( ctx, font, glyph_index, entry, vec2(bounds_0), vec2(bounds_1), glyph_draw_scale, glyph_draw_translate )
}

// If the glyuph is found in the atlas, nothing occurs, otherwise, the glyph call is setup to catch it to the atlas
check_glyph_in_atlas :: #force_inline proc( ctx : ^Context, font : FontID, entry : ^Entry, glyph_index : Glyph,
	lru_code    : u64,
	atlas_index : i32,
	region_kind : AtlasRegionKind,
	region      : ^AtlasRegion,
	over_sample : Vec2
) -> b32
{
	// profile(#procedure)
	assert( glyph_index != -1 )

	// E region can't batch
	if region_kind == .E || region_kind == .None do return false
	if ctx.temp_codepoint_seen_num > 1024        do return false
	// TODO(Ed): Why 1024?

	if atlas_index == - 1
	{
		if region.next_idx > region.state.capacity {
			// We will evict LRU. We must predict which LRU will get evicted, and if it's something we've seen then we need to take slowpath and flush batch.
			next_evict_codepoint := LRU_get_next_evicted( & region.state )
			seen, success := ctx.temp_codepoint_seen[next_evict_codepoint]
			assert(success != false)

			if (seen) {
				return false
			}
		}

		cache_glyph_to_atlas( ctx, font, glyph_index, lru_code, atlas_index, entry, region_kind, region, over_sample )
	}

	assert( LRU_get( & region.state, lru_code ) != -1 )
	mark_batch_codepoint_seen( ctx, lru_code)
	return true
}

// ve_fontcache_clear_drawlist
clear_draw_list :: #force_inline proc ( draw_list : ^DrawList ) {
	clear( & draw_list.calls )
	clear( & draw_list.indices )
	clear( & draw_list.vertices )
}

directly_draw_massive_glyph :: proc( ctx : ^Context,
	entry : ^Entry,
	glyph : Glyph,
	bounds_0,    bounds_1        : Vec2,
	bounds_size                  : Vec2,
	over_sample, position, scale : Vec2 )
{
	// profile(#procedure)
	flush_glyph_buffer_to_atlas( ctx )

	glyph_padding     := f32(ctx.atlas.glyph_padding)
	glyph_buffer_size := Vec2 { f32(ctx.glyph_buffer.width), f32(ctx.glyph_buffer.height) }

	// Draw un-antialiased glyph to update FBO.
	glyph_draw_scale     := over_sample * entry.size_scale
	glyph_draw_translate := -1 * bounds_0 * glyph_draw_scale + vec2_from_scalar(glyph_padding)
	screenspace_x_form( & glyph_draw_translate, & glyph_draw_scale, glyph_buffer_size )

	cache_glyph( ctx, entry.id, glyph, entry, bounds_0, bounds_1, glyph_draw_scale, glyph_draw_translate )

	glyph_padding_dbl := glyph_padding * 2
	bounds_scaled     := bounds_size * entry.size_scale

	// Figure out the source rect.
	glyph_position := Vec2 {}
	glyph_size     := vec2(glyph_padding_dbl)
	glyph_dst_size := glyph_size    + bounds_scaled
	glyph_size     += bounds_scaled * over_sample

	// Figure out the destination rect.
	bounds_0_scaled := Vec2 {
		cast(f32) i32(bounds_0.x * entry.size_scale - 0.5),
		cast(f32) i32(bounds_0.y * entry.size_scale - 0.5),
	}
	dst        := position + scale * bounds_0_scaled - glyph_padding * scale
	dst_size   := glyph_dst_size * scale
	textspace_x_form( & glyph_position, & glyph_size, glyph_buffer_size )

	// Add the glyph drawcall.
	calls : [2]DrawCall

	draw_to_target := & calls[0]
	{
		using draw_to_target
		pass        = .Target_Uncached
		colour      = ctx.colour
		start_index = u32(len(ctx.draw_list.indices))

		blit_quad( & ctx.draw_list,
				dst,            dst            + dst_size,
				glyph_position, glyph_position + glyph_size )

		end_index = u32(len(ctx.draw_list.indices))
	}

	clear_glyph_update := & calls[1]
	{
		// Clear glyph_update_FBO.
		clear_glyph_update.pass              = .Glyph
		clear_glyph_update.start_index       = 0
		clear_glyph_update.end_index         = 0
		clear_glyph_update.clear_before_draw = true
	}
	append( & ctx.draw_list.calls, ..calls[:] )
}

// Constructs a triangle fan to fill a shape using the provided path
// outside_point represents the center point of the fan.
//
// Note(Original Author):
// WARNING: doesn't actually append drawcall; caller is responsible for actually appending the drawcall.
// ve_fontcache_draw_filled_path
draw_filled_path :: proc( draw_list : ^DrawList, outside_point : Vec2, path : []Vertex,
	scale     := Vec2 { 1, 1 },
	translate := Vec2 { 0, 0 },
	debug_print_verbose : b32 = false
)
{
	if debug_print_verbose
	{
		log("outline_path:")
		for point in path {
			vec := point.pos * scale + translate
			logf(" %0.2f %0.2f", vec.x, vec.y )
		}
	}

	v_offset := cast(u32) len(draw_list.vertices)
	for point in path {
		point := point
		point.pos = point.pos * scale + translate
		append( & draw_list.vertices, point )
	}

	outside_vertex := cast(u32) len(draw_list.vertices)
	{
		vertex := Vertex {
			pos = outside_point * scale + translate,
			u = 0,
			v = 0,
		}
		append( & draw_list.vertices, vertex )
	}

	for index : u32 = 1; index < cast(u32) len(path); index += 1 {
		indices := & draw_list.indices
		to_add := [3]u32 {
			outside_vertex,
			v_offset + index - 1,
			v_offset + index
		}
		append( indices, ..to_add[:] )
	}
}

draw_text_batch :: proc(ctx: ^Context, entry: ^Entry, shaped: ^ShapedText,
	batch_start_idx, batch_end_idx : i32,
	position, scale                : Vec2,
	snap_width, snap_height        : f32 )
{
	flush_glyph_buffer_to_atlas(ctx)

	atlas         := & ctx.atlas
	atlas_size    := Vec2{ f32(atlas.width), f32(atlas.height) }
	glyph_padding := f32(atlas.glyph_padding)

	for index := batch_start_idx; index < batch_end_idx; index += 1
	{
		glyph_index := shaped.glyphs[index]

		if glyph_index == 0 || parser_is_glyph_empty( & entry.parser_info, glyph_index) do continue

		region_kind, region, over_sample := decide_codepoint_region( ctx, entry, glyph_index )
		lru_code                         := font_glyph_lru_code( entry.id, glyph_index )
		atlas_index                      := region_kind != .E ? LRU_get( & region.state, lru_code ) : -1
		bounds_0, bounds_1               := parser_get_glyph_box( & entry.parser_info, glyph_index )
		vbounds_0   := vec2(bounds_0)
		vbounds_1   := vec2(bounds_1)
		bounds_size := Vec2 { vbounds_1.x - vbounds_0.x, vbounds_1.y - vbounds_0.y }

		shaped_position := shaped.positions[index]
		glyph_translate := position + (shaped_position) * scale

		if region_kind == .E
		{
			directly_draw_massive_glyph(ctx, entry, glyph_index,
				vbounds_0, vbounds_1,
				bounds_size,
				over_sample, glyph_translate, scale )
		}
		else if atlas_index != -1
		{
			// Draw cacxhed glyph
			slot_position, _ := atlas_bbox( atlas, region_kind, atlas_index )
			glyph_scale      := bounds_size * entry.size_scale + glyph_padding
			bounds_0_scaled  := ceil(vbounds_0 * entry.size_scale)
			dst              := glyph_translate + bounds_0_scaled * scale
			dst_scale        := glyph_scale * scale
			textspace_x_form( & slot_position, & glyph_scale, atlas_size )

			call             := DrawCall_Default
			call.pass         = .Target
			call.colour       = ctx.colour
			call.start_index  = u32(len(ctx.draw_list.indices))

			blit_quad(&ctx.draw_list,
				dst,           dst           + dst_scale,
				slot_position, slot_position + glyph_scale )

			call.end_index = u32(len(ctx.draw_list.indices))
			append(&ctx.draw_list.calls, call)
		}
	}
}

// Helper for draw_text, all raw text content should be confirmed to be either formatting or visible shapes before getting cached.
draw_text_shape :: proc( ctx : ^Context,
	font                    : FontID,
	entry                   : ^Entry,
	shaped                  : ^ShapedText,
	position,   scale       : Vec2,
	snap_width, snap_height : f32
) -> (cursor_pos : Vec2)
{
	// profile(#procedure)
	batch_start_idx : i32 = 0
	for index : i32 = 0; index < cast(i32) len(shaped.glyphs); index += 1
	{
		glyph_index := shaped.glyphs[ index ]
		if is_empty( ctx, entry, glyph_index ) do continue

		region_kind, region, over_sample := decide_codepoint_region( ctx, entry, glyph_index )
		lru_code                         := font_glyph_lru_code(entry.id, glyph_index)
		atlas_index                      := cast(i32) -1

		if region_kind != .E do atlas_index = LRU_get( & region.state, lru_code )
		if check_glyph_in_atlas( ctx, font, entry, glyph_index, lru_code, atlas_index, region_kind, region, over_sample ) do continue

		// We can no longer directly append the shape as it has missing glyphs in the atlas

		// First batch the other cached glyphs
		// flush_glyph_buffer_to_atlas(ctx)
		draw_text_batch( ctx, entry, shaped, batch_start_idx, index, position, scale, snap_width, snap_height )
		reset_batch_codepoint_state( ctx )

		cache_glyph_to_atlas( ctx, font, glyph_index, lru_code, atlas_index, entry, region_kind, region, over_sample )
		mark_batch_codepoint_seen( ctx, lru_code)
		batch_start_idx = index
	}

	draw_text_batch( ctx, entry, shaped, batch_start_idx, cast(i32) len(shaped.glyphs), position, scale, snap_width , snap_height )
	reset_batch_codepoint_state( ctx )

	cursor_pos = position + shaped.end_cursor_pos * scale
	return
}

flush_glyph_buffer_to_atlas :: proc( ctx : ^Context )
{
	// profile(#procedure)
	// Flush drawcalls to draw list
	merge_draw_list( & ctx.draw_list, & ctx.glyph_buffer.clear_draw_list )
	merge_draw_list( & ctx.draw_list, & ctx.glyph_buffer.draw_list)
	clear_draw_list( & ctx.glyph_buffer.draw_list )
	clear_draw_list( & ctx.glyph_buffer.clear_draw_list )

	// Clear glyph_update_FBO
	if ctx.glyph_buffer.batch_x != 0
	{
		call := DrawCall_Default
		call.pass              = .Glyph
		call.start_index       = 0
		call.end_index         = 0
		call.clear_before_draw = true
		append( & ctx.draw_list.calls, call )
		ctx.glyph_buffer.batch_x = 0
	}
}

// ve_fontcache_merge_drawlist
merge_draw_list :: proc( dst, src : ^DrawList )
{
	// profile(#procedure)
	error : AllocatorError

	v_offset := cast(u32) len( dst.vertices )
	num_appended : int
	num_appended, error = append( & dst.vertices, ..src.vertices[:] )
	assert( error == .None )

	i_offset := cast(u32) len(dst.indices)
	for index : int = 0; index < len(src.indices); index += 1 {
		ignored : int
		ignored, error = append( & dst.indices, src.indices[index] + v_offset )
		assert( error == .None )
	}

	for index : int = 0; index < len(src.calls); index += 1 {
		src_call             := src.calls[ index ]
		src_call.start_index += i_offset
		src_call.end_index   += i_offset
		append( & dst.calls, src_call )
		assert( error == .None )
	}
}

optimize_draw_list :: proc(draw_list: ^DrawList, call_offset: int) {
	// profile(#procedure)
	assert(draw_list != nil)

	can_merge_draw_calls :: #force_inline proc "contextless" ( a, b : ^DrawCall ) -> bool {
		result := \
		a.pass      == b.pass        &&
		a.end_index == b.start_index &&
		a.region    == b.region      &&
		a.colour    == b.colour      &&
		! b.clear_before_draw
		return result
	}

	write_index := call_offset
	for read_index := call_offset + 1; read_index < len(draw_list.calls); read_index += 1
	{
		draw_current := & draw_list.calls[write_index]
		draw_next    := & draw_list.calls[read_index]

		if can_merge_draw_calls(draw_current, draw_next) {
			draw_current.end_index = draw_next.end_index
		}
		else {
			// Move to the next write position and copy the draw call
			write_index += 1
			if write_index != read_index {
				draw_list.calls[write_index] = (draw_next^)
			}
		}
	}

	resize( & draw_list.calls, write_index + 1)
}
