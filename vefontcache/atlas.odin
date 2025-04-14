package vefontcache

// There are only 4 actual regions of the atlas. E represents the atlas_decide_region detecting an oversized glyph.
// Note(Ed): None should never really occur anymore. So its safe to most likely add an assert when its detected.
Atlas_Region_Kind :: enum u8 {
	None   = 0x00,
	A      = 0x01,
	B      = 0x02,
	C      = 0x03,
	D      = 0x04,
	E      = 0x05,
	Ignore = 0xFF, // ve_fontcache_cache_glyph_to_atlas uses a -1 value in clear draw call
}

Atlas_Key :: u32

// TODO(Ed) It might perform better with a tailored made hashtable implementation for the LRU_Cache or dedicated array struct/procs for the Atlas.
/* Essentially a sub-atlas of the atlas. There is a state cache per region that tracks the glyph inventory (what slot they occupy).
	Unlike the shape cache this one's fixed capacity (natrually) and the next avail slot is tracked.
*/
Atlas_Region :: struct {
	state : LRU_Cache(Atlas_Key),

	size     : Vec2i,
	capacity : Vec2i,
	offset   : Vec2i,

	slot_size : Vec2i,

	next_idx : i32,
}

/* There are four regions each succeeding region holds larger sized slots.
	The generator pipeline for draw lists utilizes the regions array for info lookup.

	Note(Ed):
	Padding can techncially be larger than 1, however recently I haven't had any artififact issues...
	size_multiplier usage isn't fully resolved. Intent was to further setup over_sampling or just having 
	a more massive cache for content that used more than the usual common glyphs.
*/
Atlas :: struct {
	region_a : Atlas_Region,
	region_b : Atlas_Region,
	region_c : Atlas_Region,
	region_d : Atlas_Region,

	regions : [5] ^Atlas_Region,

	glyph_padding   : f32, // Padding to add to bounds_<width/height>_scaled for choosing which atlas region.
	size_multiplier : f32, // Grows all text by this multiple.

	size : Vec2i,
}

// Hahser for the atlas.
@(optimization_mode="favor_size")
atlas_glyph_lru_code :: #force_inline proc "contextless" ( font : Font_ID, px_size : f32, glyph_index : Glyph ) -> (lru_code : Atlas_Key) {
	// lru_code = u32(glyph_index) + ( ( 0x10000 * u32(font) ) & 0xFFFF0000 )
	font        := font
	glyph_index := glyph_index
	px_size     := px_size
	djb8_hash( & lru_code, to_bytes( & font) )
	djb8_hash( & lru_code, to_bytes( & glyph_index ) )
	djb8_hash( & lru_code, to_bytes( & px_size ) )
	return
}

@(optimization_mode="favor_size")
atlas_region_bbox :: #force_inline proc( region : Atlas_Region, local_idx : i32 ) -> (position, size: Vec2)
{
	size = vec2(region.slot_size)

	position.x = cast(f32) (( local_idx % region.capacity.x ) * region.slot_size.x)
	position.y = cast(f32) (( local_idx / region.capacity.x ) * region.slot_size.y)

	position.x += f32(region.offset.x)
	position.y += f32(region.offset.y)
	return
}

@(optimization_mode="favor_size")
atlas_decide_region :: #force_inline proc "contextless" (atlas : Atlas, glyph_buffer_size : Vec2, bounds_size_scaled : Vec2 ) -> (region_kind : Atlas_Region_Kind)
{
	// profile(#procedure)
	glyph_padding_dbl  := atlas.glyph_padding * 2
	padded_bounds      := bounds_size_scaled + glyph_padding_dbl

	for kind in 1 ..= 4 do if	
		padded_bounds.x <= f32(atlas.regions[kind].slot_size.x) && 
	  padded_bounds.y <= f32(atlas.regions[kind].slot_size.y) 
	{
		return cast(Atlas_Region_Kind) kind
	}

	if padded_bounds.x <= glyph_buffer_size.x && padded_bounds.y <= glyph_buffer_size.y{
		return .E
	}
	return .None
}

// Grab an atlas LRU cache slot.
@(optimization_mode="favor_size")
atlas_reserve_slot :: #force_inline proc ( region : ^Atlas_Region, lru_code : Atlas_Key ) -> (atlas_index : i32)
{
	if region.next_idx < region.state.capacity
	{
		evicted         := lru_put( & region.state, lru_code, region.next_idx )
		atlas_index      = region.next_idx
		region.next_idx += 1
		assert( evicted == lru_code )
	}
	else
	{
		next_evict_codepoint := lru_get_next_evicted( region.state )
		assert( next_evict_codepoint != LRU_Fail_Mask_16)

		atlas_index = lru_peek( region.state, next_evict_codepoint, must_find = true )
		assert( atlas_index != -1 )

		evicted := lru_put( & region.state, lru_code, atlas_index )
		assert( evicted == next_evict_codepoint )
	}

	assert( lru_get( & region.state, lru_code ) != - 1 )
	return
}
