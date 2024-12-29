package vefontcache
/*
Note(Ed): The only reason I didn't directly use harfbuzz is because hamza exists and seems to be under active development as an alternative.
*/

import "core:c"
import "thirdparty:harfbuzz"

Shaper_Kind :: enum {
	Naive    = 0,
	Harfbuzz = 1,
}

Shaper_Context :: struct {
	hb_buffer : harfbuzz.Buffer,

	snap_glyph_position           : b32,
	adv_snap_small_font_threshold : f32,
}

Shaper_Info :: struct {
	blob : harfbuzz.Blob,
	face : harfbuzz.Face,
	font : harfbuzz.Font,
}

shaper_init :: proc( ctx : ^Shaper_Context )
{
	ctx.hb_buffer = harfbuzz.buffer_create()
	assert( ctx.hb_buffer != nil, "VEFontCache.shaper_init: Failed to create harfbuzz buffer")
}

shaper_shutdown :: proc( ctx : ^Shaper_Context )
{
	if ctx.hb_buffer != nil {
		harfbuzz.buffer_destroy( ctx.hb_buffer )
	}
}

shaper_load_font :: proc( ctx : ^Shaper_Context, label : string, data : []byte, user_data : rawptr ) -> (info : Shaper_Info)
{
	using info
	blob = harfbuzz.blob_create( raw_data(data), cast(c.uint) len(data), harfbuzz.Memory_Mode.READONLY, user_data, nil )
	face = harfbuzz.face_create( blob, 0 )
	font = harfbuzz.font_create( face )
	return
}

shaper_unload_font :: proc( ctx : ^Shaper_Info )
{
	using ctx
	if blob != nil do harfbuzz.font_destroy( font )
	if face != nil do harfbuzz.face_destroy( face )
	if blob != nil do harfbuzz.blob_destroy( blob )
}

shaper_shape_from_text :: proc( ctx : ^Shaper_Context, info : ^Shaper_Info, output :^Shaped_Text, text_utf8 : string,
	ascent, descent, line_gap : i32, size, size_scale : f32 )
{
	// profile(#procedure)
	current_script := harfbuzz.Script.UNKNOWN
	hb_ucfunc      := harfbuzz.unicode_funcs_get_default()
	harfbuzz.buffer_clear_contents( ctx.hb_buffer )
	assert( info.font != nil )

	ascent   := f32(ascent)
	descent  := f32(descent)
	line_gap := f32(line_gap)

	max_line_width := f32(0)
	line_count     := 1
	line_height    := ((ascent - descent + line_gap) * size_scale)

	position, vertical_position : f32
	shape_run :: proc( buffer : harfbuzz.Buffer, script : harfbuzz.Script, font : harfbuzz.Font, output : ^Shaped_Text,
		position, vertical_position, max_line_width: ^f32, line_count: ^int,
		ascent, descent, line_gap, size, size_scale: f32,
		snap_shape_pos : b32, adv_snap_small_font_threshold : f32 )
	{
		// Set script and direction. We use the system's default langauge.
		// script = HB_SCRIPT_LATIN
		harfbuzz.buffer_set_script( buffer, script )
		harfbuzz.buffer_set_direction( buffer, harfbuzz.script_get_horizontal_direction( script ))
		harfbuzz.buffer_set_language( buffer, harfbuzz.language_get_default() )

		// Perform the actual shaping of this run using HarfBuzz.
		harfbuzz.buffer_set_content_type( buffer, harfbuzz.Buffer_Content_Type.UNICODE )
		harfbuzz.shape( font, buffer, nil, 0 )

		// Loop over glyphs and append to output buffer.
		glyph_count : u32
		glyph_infos     := harfbuzz.buffer_get_glyph_infos( buffer, & glyph_count )
		glyph_positions := harfbuzz.buffer_get_glyph_positions( buffer, & glyph_count )

		line_height := (ascent - descent + line_gap) * size_scale

		for index : i32; index < i32(glyph_count); index += 1
		{
			hb_glyph     := glyph_infos[ index ]
			hb_gposition := glyph_positions[ index ]
			glyph_id     := cast(Glyph) hb_glyph.codepoint

			if hb_glyph.cluster > 0
			{
				(max_line_width^)     = max( max_line_width^, position^ )
				(position^)           = 0.0
				(vertical_position^) -= line_height
				(vertical_position^)  = floor(vertical_position^ + 0.5)
				(line_count^)         += 1
				continue
			}
			if abs( size ) <= adv_snap_small_font_threshold
			{
				(position^) = ceil( position^ )
			}

			append( & output.glyphs, glyph_id )

			pos      := position^ 
			v_pos    := vertical_position^
			offset_x := f32(hb_gposition.x_offset) * size_scale
			offset_y := f32(hb_gposition.y_offset) * size_scale
			pos   += offset_x
			v_pos += offset_y

			if snap_shape_pos {
				pos   = ceil(pos)
				v_pos = ceil(v_pos)
			}
			append( & output.positions, Vec2 {pos, v_pos})

			(position^)          += f32(hb_gposition.x_advance) * size_scale
			(vertical_position^) += f32(hb_gposition.y_advance) * size_scale
			(max_line_width^)     = max(max_line_width^, position^)
		}

		output.end_cursor_pos.x = position^
		output.end_cursor_pos.y = vertical_position^
		harfbuzz.buffer_clear_contents( buffer )
	}

	// Note(Original Author):
	// We first start with simple bidi and run logic.
	// True CTL is pretty hard and we don't fully support that; patches welcome!

	for codepoint, byte_offset in text_utf8
	{
		hb_codepoint := cast(harfbuzz.Codepoint) codepoint

		script := harfbuzz.unicode_script( hb_ucfunc, hb_codepoint )

		// Can we continue the current run?
		ScriptKind :: harfbuzz.Script

		special_script : b32 = script == ScriptKind.UNKNOWN || script == ScriptKind.INHERITED || script == ScriptKind.COMMON
		if special_script || script == current_script || byte_offset == 0 {
			harfbuzz.buffer_add( ctx.hb_buffer, hb_codepoint, codepoint == '\n' ? 1 : 0 )
			current_script = special_script ? current_script : script
			continue
		}

		// End current run since we've encountered a script change.
		shape_run( 
			ctx.hb_buffer, current_script, info.font, output, 
			& position, & vertical_position, & max_line_width, & line_count, 
			ascent, descent, line_gap, size, size_scale, 
			ctx.snap_glyph_position, ctx.adv_snap_small_font_threshold
		)
		harfbuzz.buffer_add( ctx.hb_buffer, hb_codepoint, codepoint == '\n' ? 1 : 0 )
		current_script = script
	}

	// End the last run if needed
	shape_run( 
		ctx.hb_buffer, current_script, info.font, output, 
		& position, & vertical_position, & max_line_width, & line_count, 
		ascent, descent, line_gap, size, size_scale, 
		ctx.snap_glyph_position, ctx.adv_snap_small_font_threshold
	)

	// Set the final size
	output.size.x = max_line_width
	output.size.y = f32(line_count) * line_height
	return
}
