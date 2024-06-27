package VEFontCache

import "core:math"

ShapedText :: struct {
	glyphs         : [dynamic]Glyph,
	positions      : [dynamic]Vec2,
	end_cursor_pos : Vec2,
}

ShapedTextCache :: struct {
	storage       : [dynamic]ShapedText,
	state         : LRU_Cache,
	next_cache_id : i32,
}

shape_text_cached :: proc( ctx : ^Context, font : FontID, text_utf8 : string, entry : ^Entry ) -> ^ShapedText
{
	// profile(#procedure)
	@static buffer : [64 * Kilobyte]byte

	font            := font
	text_size       := len(text_utf8)
	sice_end_offset := size_of(FontID) + len(text_utf8)

	buffer_slice := buffer[:]
	font_bytes   := slice_ptr( transmute(^byte) & font, size_of(FontID) )
	copy( buffer_slice, font_bytes )

	text_bytes             := transmute( []byte) text_utf8
	buffer_slice_post_font := buffer[ size_of(FontID) : sice_end_offset ]
	copy( buffer_slice_post_font, text_bytes )

	hash := shape_lru_hash( transmute(string) buffer[: sice_end_offset ] )

	shape_cache := & ctx.shape_cache
	state       := & ctx.shape_cache.state

	shape_cache_idx := LRU_get( state, hash )
	if shape_cache_idx == -1
	{
		if shape_cache.next_cache_id < i32(state.capacity) {
			shape_cache_idx            = shape_cache.next_cache_id
			shape_cache.next_cache_id += 1
			evicted := LRU_put( state, hash, shape_cache_idx )
			assert( evicted == hash )
		}
		else
		{
			next_evict_idx := LRU_get_next_evicted( state )
			assert( next_evict_idx != 0xFFFFFFFFFFFFFFFF )

			shape_cache_idx = LRU_peek( state, next_evict_idx, must_find = true )
			assert( shape_cache_idx != - 1 )

			LRU_put( state, hash, shape_cache_idx )
		}

		shape_text_uncached( ctx, font, text_utf8, entry, & shape_cache.storage[ shape_cache_idx ] )
	}

	return & shape_cache.storage[ shape_cache_idx ]
}

// TODO(Ed): Make position rounding an option
shape_text_uncached :: proc( ctx : ^Context, font : FontID, text_utf8 : string, entry : ^Entry, output : ^ShapedText )
{
	// profile(#procedure)
	assert( ctx != nil )
	assert( font >= 0 && int(font) < len(ctx.entries) )

	use_full_text_shape := ctx.text_shape_adv

	clear( & output.glyphs )
	clear( & output.positions )

	ascent, descent, line_gap := parser_get_font_vertical_metrics( & entry.parser_info )

	if use_full_text_shape
	{
		// assert( entry.shaper_info != nil )
		shaper_shape_from_text( & ctx.shaper_ctx, & entry.shaper_info, output, text_utf8, ascent, descent, line_gap, entry.size, entry.size_scale )
		return
	}
	else
	{
		// Note(Original Author):
		// We use our own fallback dumbass text shaping.
		// WARNING: PLEASE USE HARFBUZZ. GOOD TEXT SHAPING IS IMPORTANT FOR INTERNATIONALISATION.
		ascent   := f32(ascent)
		descent  := f32(descent)
		line_gap := f32(line_gap)

		position           : Vec2
		advance            : i32 = 0
		to_left_side_glyph : i32 = 0

		prev_codepoint : rune
		for codepoint in text_utf8
		{
			if prev_codepoint > 0 {
				kern       := parser_get_codepoint_kern_advance( & entry.parser_info, prev_codepoint, codepoint )
				position.x += f32(kern) * entry.size_scale
			}
			if codepoint == '\n'
			{
				position.x  = 0.0
				position.y -= (ascent - descent + line_gap) * entry.size_scale
				position.y  = ceil(position.y)
				prev_codepoint = rune(0)
				continue
			}
			if abs( entry.size ) <= Advance_Snap_Smallfont_Size {
				position.x = math.ceil( position.x )
			}

			append( & output.glyphs, parser_find_glyph_index( & entry.parser_info, codepoint ))
			advance, to_left_side_glyph = parser_get_codepoint_horizontal_metrics( & entry.parser_info, codepoint )

			append( & output.positions, Vec2 {
				ceil(position.x),
				position.y
			})
			// append( & output.positions, position )

			position.x    += f32(advance) * entry.size_scale
			prev_codepoint = codepoint
		}

		output.end_cursor_pos = position
	}
}
