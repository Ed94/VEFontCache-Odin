package VEFontCache
/*
Note(Ed): The only reason I didn't directly use harfbuzz is because hamza exists and seems to be under active development as an alternative.
*/

import "core:c"
import "thirdparty:harfbuzz"

ShaperKind :: enum {
	Naive    = 0,
	Harfbuzz = 1,
}

ShaperContext :: struct {
	hb_buffer : harfbuzz.Buffer,
	// infos : HMapChained(ShaperInfo),
}

ShaperInfo :: struct {
	blob : harfbuzz.Blob,
	face : harfbuzz.Face,
	font : harfbuzz.Font,
}

shaper_init :: proc( ctx : ^ShaperContext )
{
	ctx.hb_buffer = harfbuzz.buffer_create()
	assert( ctx.hb_buffer != nil, "VEFontCache.shaper_init: Failed to create harfbuzz buffer")

	// error : AllocatorError
	// ctx.infos, error = make( HMapChained(ShaperInfo), 256 )
	// assert( error == .None, "VEFontCache.shaper_init: Failed to create shaper infos map" )
}

shaper_shutdown :: proc( ctx : ^ShaperContext )
{
	if ctx.hb_buffer != nil {
		harfbuzz.buffer_destory( ctx.hb_buffer )
	}

	// delete(& ctx.infos)
}

shaper_load_font :: proc( ctx : ^ShaperContext, label : string, data : []byte, user_data : rawptr ) -> (info : ShaperInfo)
{
	// key := font_key_from_label( label )
	// info = get( ctx.infos, key )
	// if info != nil do return

	// error : AllocatorError
	// info, error = set( ctx.infos, key, ShaperInfo {} )
	// assert( error == .None, "VEFontCache.parser_load_font: Failed to set a new shaper info" )

	using info
	blob = harfbuzz.blob_create( raw_data(data), cast(c.uint) len(data), harfbuzz.Memory_Mode.READONLY, user_data, nil )
	face = harfbuzz.face_create( blob, 0 )
	font = harfbuzz.font_create( face )
	return
}

shaper_unload_font :: proc( ctx : ^ShaperInfo )
{
	using ctx
	if blob != nil do harfbuzz.font_destroy( font )
	if face != nil do harfbuzz.face_destroy( face )
	if blob != nil do harfbuzz.blob_destroy( blob )
}

shaper_shape_from_text :: proc( ctx : ^ShaperContext, info : ^ShaperInfo, output :^ShapedText, text_utf8 : string,
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

	position, vertical_position : f32
	shape_run :: proc( buffer : harfbuzz.Buffer, script : harfbuzz.Script, font : harfbuzz.Font, output : ^ShapedText,
		position, vertical_position : ^f32,
		ascent, descent, line_gap, size, size_scale : f32 )
	{
		// Set script and direction. We use the system's default langauge.
		// script = HB_SCRIPT_LATIN
		harfbuzz.buffer_set_script( buffer, script )
		harfbuzz.buffer_set_direction( buffer, harfbuzz.script_get_horizontal_direction( script ))
		harfbuzz.buffer_set_language( buffer, harfbuzz.language_get_default() )

		// Perform the actual shaping of this run using HarfBuzz.
		harfbuzz.shape( font, buffer, nil, 0 )

		// Loop over glyphs and append to output buffer.
		glyph_count : u32
		glyph_infos     := harfbuzz.buffer_get_glyph_infos( buffer, & glyph_count )
		glyph_positions := harfbuzz.buffer_get_glyph_positions( buffer, & glyph_count )

		for index : i32; index < i32(glyph_count); index += 1
		{
			hb_glyph     := glyph_infos[ index ]
			hb_gposition := glyph_positions[ index ]
			glyph_id     := cast(Glyph) hb_glyph.codepoint

			if hb_glyph.cluster > 0
			{
				(position^)           = 0.0
				(vertical_position^) -= (ascent - descent + line_gap) * size_scale
				(vertical_position^)  = cast(f32) i32(vertical_position^ + 0.5)
				continue
			}
			if abs( size ) <= Advance_Snap_Smallfont_Size
			{
				(position^) = ceil( position^ )
			}

			append( & output.glyphs, glyph_id )

			pos      := position^
			v_pos    := vertical_position^
			offset_x := f32(hb_gposition.x_offset) * size_scale
			offset_y := f32(hb_gposition.y_offset) * size_scale
			append( & output.positions, Vec2 { cast(f32) i32( pos + offset_x + 0.5 ),
				v_pos + offset_y,
			})

			(position^)          += f32(hb_gposition.x_advance) * size_scale
			(vertical_position^) += f32(hb_gposition.y_advance) * size_scale
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
		script := harfbuzz.unicode_script( hb_ucfunc, cast(harfbuzz.Codepoint) codepoint )

		// Can we continue the current run?
		ScriptKind :: harfbuzz.Script

		special_script : b32 = script == ScriptKind.UNKNOWN || script == ScriptKind.INHERITED || script == ScriptKind.COMMON
		if special_script || script == current_script {
			harfbuzz.buffer_add( ctx.hb_buffer, cast(harfbuzz.Codepoint) codepoint, codepoint == '\n' ? 1 : 0 )
			current_script = special_script ? current_script : script
			continue
		}

		// End current run since we've encountered a script change.
		shape_run( ctx.hb_buffer, current_script, info.font, output, & position, & vertical_position, ascent, descent, line_gap, size, size_scale )
		harfbuzz.buffer_add( ctx.hb_buffer, cast(harfbuzz.Codepoint) codepoint, codepoint == '\n' ? 1 : 0 )
		current_script = script
	}

	// End the last run if needed
	shape_run( ctx.hb_buffer, current_script, info.font, output, & position, & vertical_position, ascent, descent, line_gap, size, size_scale )
	return
}
