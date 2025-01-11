package vefontcache
/*
Note(Ed): The only reason I didn't directly use harfbuzz is:
https://github.com/saidwho12/hamza 
and seems to be under active development as an alternative.
*/

import "core:c"
import "thirdparty:harfbuzz"

Shape_Key :: u32

/*  A text whose codepoints have had their relevant glyphs and 
	associated data resolved for processing in a draw list generation stage.
	Traditionally a shape only refers to resolving which glyph and 
	its position should be used for rendering.

	For this library's case it also resolves any content that does not have to be done 
	on a per-frame basis for draw list generation:
		* atlas lru codes
		* glyph bounds and scale
		* atlas region the glyph is associated with.

	Ideally the user should resolve this shape once and cache/store it on their side.
	They have the best ability to avoid costly lookups.
*/
Shaped_Text :: struct #packed {
	glyph              : [dynamic]Glyph,
	position           : [dynamic]Vec2,
	atlas_lru_code     : [dynamic]Atlas_Key,
	region_kind        : [dynamic]Atlas_Region_Kind,
	bounds             : [dynamic]Range2,
	end_cursor_pos     : Vec2,
	size               : Vec2,
	font_id            : Font_ID, 
	// TODO(Ed): We need to track the font here for usage in user interface when directly drawing the shape.
}

// Ease of use cache, can handle thousands of lookups per frame with ease.
// TODO(Ed) It might perform better with a tailored made hashtable implementation for the LRU_Cache or dedicated array struct/procs for the Shaped_Text.
Shaped_Text_Cache :: struct {
	storage       : [dynamic]Shaped_Text,
	state         : LRU_Cache(Shape_Key),
	next_cache_id : i32,
}

// Used by shaper_shape_text_cached, allows user to specify their own proc at compile-time without having to rewrite the caching implementation.
Shaper_Shape_Text_Uncached_Proc :: #type proc( ctx : ^Shaper_Context,
	atlas             : Atlas, 
	glyph_buffer_size : Vec2,
	entry             : Entry, 
	font_px_Size      : f32, 
	font_scale        : f32, 
	text_utf8         : string, 
	output            : ^Shaped_Text 
)

// Note(Ed): Not used..
Shaper_Kind :: enum {
	Latin    = 0,
	Harfbuzz = 1,
}

//  Not much here other than just keep track of a harfbuzz var and deciding to keep runtime config here used by the shapers.
Shaper_Context :: struct {
	hb_buffer : harfbuzz.Buffer,

	snap_glyph_position           : b32,
	adv_snap_small_font_threshold : f32,
}

// Only used with harbuzz for now. Resolved during load_font for a font Entry.
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

shaper_load_font :: #force_inline proc( ctx : ^Shaper_Context, label : string, data : []byte, user_data : rawptr = nil ) -> (info : Shaper_Info)
{
	info.blob = harfbuzz.blob_create( raw_data(data), cast(c.uint) len(data), harfbuzz.Memory_Mode.READONLY, user_data, nil )
	info.face = harfbuzz.face_create( info.blob, 0 )
	info.font = harfbuzz.font_create( info.face )
	return
}

shaper_unload_font :: #force_inline proc( info : ^Shaper_Info )
{
	if info.blob != nil do harfbuzz.font_destroy( info.font )
	if info.face != nil do harfbuzz.face_destroy( info.face )
	if info.blob != nil do harfbuzz.blob_destroy( info.blob )
}

// Recommended shaper. Very performant.
// TODO(Ed): Would be nice to properly support vertical shaping, right now its strictly just horizontal...
@(optimization_mode="favor_size")
shaper_shape_harfbuzz :: proc( ctx : ^Shaper_Context, 
	atlas             : Atlas, 
	glyph_buffer_size : Vec2,
	entry             : Entry, 
	font_px_size      : f32, 
	font_scale        : f32, 
	text_utf8         : string, 
	output            : ^Shaped_Text
)
{
	profile(#procedure)
	assert( ctx != nil )

	clear( & output.glyph )
	clear( & output.position )

	current_script := harfbuzz.Script.UNKNOWN
	hb_ucfunc      := harfbuzz.unicode_funcs_get_default()
	harfbuzz.buffer_clear_contents( ctx.hb_buffer )

	ascent   := entry.ascent
	descent  := entry.descent
	line_gap := entry.line_gap
	
	max_line_width := f32(0)
	line_count     := 1
	line_height    := ((ascent - descent + line_gap) * font_scale)

	position : Vec2

	@(optimization_mode="favor_size")
	shape_run :: proc( output : ^Shaped_Text,
		entry  : Entry, 
		buffer : harfbuzz.Buffer,
		script : harfbuzz.Script, 
		
		position       : ^Vec2, 
		max_line_width : ^f32, 
		line_count     : ^int,

		font_px_size : f32,
		font_scale   : f32,

		snap_shape_pos                : b32, 
		adv_snap_small_font_threshold : f32 
	)
	{
		profile(#procedure)
		harfbuzz.buffer_set_script   ( buffer, script )
		harfbuzz.buffer_set_direction( buffer, harfbuzz.script_get_horizontal_direction( script ))
		harfbuzz.buffer_set_language ( buffer, harfbuzz.language_get_default() )

		// Perform the actual shaping of this run using HarfBuzz.
		harfbuzz.buffer_set_content_type( buffer, harfbuzz.Buffer_Content_Type.UNICODE )
		harfbuzz.shape( entry.shaper_info.font, buffer, nil, 0 )

		// Loop over glyphs and append to output buffer.
		glyph_count : u32
		glyph_infos     := harfbuzz.buffer_get_glyph_infos( buffer, & glyph_count )
		glyph_positions := harfbuzz.buffer_get_glyph_positions( buffer, & glyph_count )

		line_height := (entry.ascent - entry.descent + entry.line_gap) * font_scale

		last_cluster := u32(0)
		for index : i32; index < i32(glyph_count); index += 1
		{
			hb_glyph     := glyph_infos    [ index ]
			hb_gposition := glyph_positions[ index ]
			glyph        := cast(Glyph) hb_glyph.codepoint

			if hb_glyph.cluster > 0
			{
				(max_line_width^) = max( max_line_width^, position.x )
				position.x        = 0.0
				position.y       -= line_height
				position.y        = floor(position.y)
				(line_count^)    += 1

				last_cluster = hb_glyph.cluster
				continue
			}
			if abs( font_px_size ) <= adv_snap_small_font_threshold {
				(position^) = ceil( position^ )
			}

			glyph_pos := position^
			offset    := Vec2 { f32(hb_gposition.x_offset), f32(hb_gposition.y_offset) } * font_scale
			glyph_pos += offset

			if snap_shape_pos {
				glyph_pos = ceil(glyph_pos)
			}

			advance := Vec2 { 
				f32(hb_gposition.x_advance) * font_scale, 
				f32(hb_gposition.y_advance) * font_scale
			}
			(position^)      += advance
			(max_line_width^) = max(max_line_width^, position.x)

			is_empty := parser_is_glyph_empty(entry.parser_info, glyph)
			if ! is_empty && glyph != 0 {
				append( & output.glyph, glyph )
				append( & output.position, glyph_pos)
			}
		}

		output.end_cursor_pos = position^
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
		if special_script                \
		|| script      == current_script \
		|| byte_offset == 0 
		{
			harfbuzz.buffer_add( ctx.hb_buffer, hb_codepoint, codepoint == '\n' ? 1 : 0 )
			current_script = special_script ? current_script : script
			continue
		}

		// End current run since we've encountered a script change.
		shape_run( output,
			entry, 
			ctx.hb_buffer, 
			current_script, 
			& position, 
			& max_line_width, 
			& line_count, 
			font_px_size, 
			font_scale, 
			ctx.snap_glyph_position, 
			ctx.adv_snap_small_font_threshold
		)	
		harfbuzz.buffer_add( ctx.hb_buffer, hb_codepoint, codepoint == '\n' ? 1 : 0 )
		current_script = script
	}

	// End the last run if needed
	shape_run( output,
		entry, 
		ctx.hb_buffer, 
		current_script, 
		& position, 
		& max_line_width, 
		& line_count, 
		font_px_size, 
		font_scale, 
		ctx.snap_glyph_position, 
		ctx.adv_snap_small_font_threshold
	)	

	// Set the final size
	output.size.x = max_line_width
	output.size.y = f32(line_count) * line_height

	// Resolve each glyphs: bounds, atlas lru, and the atlas region as we have everything we need now.

	resize( & output.atlas_lru_code, len(output.glyph) )
	resize( & output.region_kind,    len(output.glyph) )
	resize( & output.bounds,         len(output.glyph) )

	profile_begin("atlas_lru_code")
	for id, index in output.glyph {
		output.atlas_lru_code[index] = atlas_glyph_lru_code(entry.id, font_px_size, id)
	}
	profile_end()

	profile_begin("bounds & region")
	for id, index in output.glyph {
		bounds                   := & output.bounds[index]
		(bounds ^)                = parser_get_bounds( entry.parser_info, id )
		bounds_size_scaled       := (bounds.p1 - bounds.p0) * font_scale
		output.region_kind[index] = atlas_decide_region( atlas, glyph_buffer_size, bounds_size_scaled )
	}
	profile_end()
	return
}

// Basic western alphabet based shaping. Not that much faster than harfbuzz if at all.
shaper_shape_text_latin :: proc( ctx : ^Shaper_Context,
	atlas             : Atlas, 
	glyph_buffer_size : Vec2,
	entry             : Entry, 
	font_px_size      : f32, 
	font_scale        : f32, 
	text_utf8         : string, 
	output            : ^Shaped_Text
)
{	
	profile(#procedure)
	assert( ctx != nil )

	clear( & output.glyph )
	clear( & output.position )

	line_height := (entry.ascent - entry.descent + entry.line_gap) * font_scale

	line_count     : int = 1
	max_line_width : f32 = 0
	position       : Vec2

	prev_codepoint : rune
	for codepoint, index in text_utf8
	{
		if prev_codepoint > 0 {
			kern       := parser_get_codepoint_kern_advance( entry.parser_info, prev_codepoint, codepoint )
			position.x += f32(kern) * font_scale
		}
		if codepoint == '\n'
		{
			line_count    += 1
			max_line_width = max(max_line_width, position.x)
			position.x     = 0.0
			position.y    -= line_height
			position.y     = position.y
			prev_codepoint = rune(0)
			continue
		}
		if abs( font_px_size ) <= ctx.adv_snap_small_font_threshold {
			position.x = ceil(position.x)
		}

		glyph_index    := parser_find_glyph_index( entry.parser_info, codepoint )
		is_glyph_empty := parser_is_glyph_empty( entry.parser_info, glyph_index )
		if ! is_glyph_empty
		{
			append( & output.glyph, glyph_index)
			append( & output.position, Vec2 {
				ceil(position.x),
				ceil(position.y)
			})
		}

		advance, _ := parser_get_codepoint_horizontal_metrics( entry.parser_info, codepoint )
		position.x += f32(advance) * font_scale
		prev_codepoint = codepoint
	}

	output.end_cursor_pos = position
	max_line_width        = max(max_line_width, position.x)

	output.size.x = max_line_width
	output.size.y = f32(line_count) * line_height

	// Resolve each glyphs: bounds, atlas lru, and the atlas region as we have everything we need now.

	resize( & output.atlas_lru_code, len(output.glyph) )
	resize( & output.region_kind,    len(output.glyph) )
	resize( & output.bounds,         len(output.glyph) )

	profile_begin("atlas_lru_code")
	for id, index in output.glyph {
		output.atlas_lru_code[index] = atlas_glyph_lru_code(entry.id, font_px_size, id)
	}
	profile_end()

	profile_begin("bounds & region")
	for id, index in output.glyph {
		bounds                   := & output.bounds[index]
		(bounds ^)                = parser_get_bounds( entry.parser_info, id )
		bounds_size_scaled       := (bounds.p1 - bounds.p0) * font_scale
		output.region_kind[index] = atlas_decide_region( atlas, glyph_buffer_size, bounds_size_scaled )
	}
	profile_end()
}

// Shapes are tracked by the library's context using the shape cache 
// and the key is resolved using the font, the desired pixel size, and the text bytes to be shaped.
// Thus this procedures cost will be proporitonal to how much text it has to sift through.
// djb8_hash is used as its been pretty good for thousands of hashed lines that around 6-250 charactes long
// (and its very fast).
@(optimization_mode="favor_size")
shaper_shape_text_cached :: proc( text_utf8 : string, 
	ctx                 : ^Shaper_Context,
	shape_cache         : ^Shaped_Text_Cache, 
	atlas               : Atlas,
	glyph_buffer_size   : Vec2,
	font                : Font_ID,
	entry               : Entry, 
	font_px_size        : f32, 
	font_scale          : f32, 
	shape_text_uncached : $Shaper_Shape_Text_Uncached_Proc
) -> (shaped_text : Shaped_Text)
{
	profile(#procedure)
	font         := font
	font_px_size := font_px_size
	font_bytes   := to_bytes( & font )
	size_bytes   := to_bytes( & font_px_size )
	text_bytes   := transmute( []byte) text_utf8

	lru_code : Shape_Key
	djb8_hash( & lru_code, font_bytes )
	djb8_hash( & lru_code, size_bytes )
	djb8_hash( & lru_code, text_bytes )

	state := & shape_cache.state

	shape_cache_idx := lru_get( state, lru_code )
	if shape_cache_idx == -1
	{
		if shape_cache.next_cache_id < i32(state.capacity){
			shape_cache_idx            = shape_cache.next_cache_id
			shape_cache.next_cache_id += 1
			evicted := lru_put( state, lru_code, shape_cache_idx )
		}
		else 
		{
			next_evict_idx := lru_get_next_evicted( state ^ )
			assert( next_evict_idx != LRU_Fail_Mask_32 )

			shape_cache_idx = lru_peek( state ^, next_evict_idx, must_find = true )
			assert( shape_cache_idx != - 1 )

			lru_put( state, lru_code, shape_cache_idx )
		}

		storage_entry := & shape_cache.storage[ shape_cache_idx ]
		shape_text_uncached( ctx, atlas, glyph_buffer_size, entry, font_px_size, font_scale, text_utf8, storage_entry )

		shaped_text = storage_entry ^
		return
	}

	shaped_text = shape_cache.storage[ shape_cache_idx ]
	return
}
