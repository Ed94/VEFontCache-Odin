package vefontcache

when false {
// TODO(Ed): Freetype support

// TODO(Ed): glyph caching cannot be handled in a 'font parser' abstraction. Just going to have explicit procedures to grab info neatly...
cache_glyph_freetype :: proc(ctx: ^Context, font: Font_ID, glyph_index: Glyph, entry: ^Entry, bounds_0, bounds_1: Vec2, scale, translate: Vec2) -> b32
{
	draw_filled_path_freetype :: proc( draw_list : ^Draw_List, outside_point : Vec2, path : []Vertex,
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

	draw            := Draw_Call_Default
	draw.pass        = Frame_Buffer_Pass.Glyph
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
		end_index   := int(contours[contour_index]) + 1
		prev_point  : Vec2
		first_point : Vec2

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
		draw_filled_path(&ctx.draw_list, bounds_0, path[:], scale, translate)
		// draw_filled_path(&ctx.draw_list, bounds_0, path[:], scale, translate, ctx.debug_print_verbose)
		clear(path)
		start_index = end_index
	}

	if len(path) > 0 {
		// draw_filled_path(&ctx.draw_list, outside, path[:], scale, translate, ctx.debug_print_verbose)
		draw_filled_path(&ctx.draw_list, outside, path[:], scale, translate)
	}

	draw.end_index = cast(u32) len(ctx.draw_list.indices)
	if draw.end_index > draw.start_index {
		append( & ctx.draw_list.calls, draw)
	}

	return true
}

}
