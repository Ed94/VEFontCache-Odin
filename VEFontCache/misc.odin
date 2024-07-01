package VEFontCache

import "base:runtime"
import "core:simd"
import "core:math"

// import core_log "core:log"

Colour  :: [4]f32
Vec2    :: [2]f32
Vec2i   :: [2]i32
Vec2_64 :: [2]f64

vec2_from_scalar  :: #force_inline proc "contextless" ( scalar : f32   ) -> Vec2    { return { scalar, scalar }}
vec2_64_from_vec2 :: #force_inline proc "contextless" ( v2     : Vec2  ) -> Vec2_64 { return { f64(v2.x), f64(v2.y) }}
vec2_from_vec2i   :: #force_inline proc "contextless" ( v2i    : Vec2i ) -> Vec2    { return { f32(v2i.x), f32(v2i.y) }}
vec2i_from_vec2   :: #force_inline proc "contextless" ( v2     : Vec2  ) -> Vec2i   { return { i32(v2.x), i32(v2.y) }}

@(require_results) ceil_vec2 :: proc "contextless" ( v : Vec2 ) -> Vec2 { return { ceil_f32(v.x), ceil_f32(v.y) } }

// This buffer is used below excluisvely to prevent any allocator recusion when verbose logging from allocators.
// This means a single line is limited to 4k buffer
Logger_Allocator_Buffer : [4 * Kilobyte]u8

log :: proc( msg : string, level := core_log.Level.Info, loc := #caller_location ) {
	temp_arena : Arena; arena_init(& temp_arena, Logger_Allocator_Buffer[:])
	context.allocator      = arena_allocator(& temp_arena)
	context.temp_allocator = arena_allocator(& temp_arena)

	core_log.log( level, msg, location = loc )
}

logf :: proc( fmt : string, args : ..any,  level := core_log.Level.Info, loc := #caller_location  ) {
	temp_arena : Arena; arena_init(& temp_arena, Logger_Allocator_Buffer[:])
	context.allocator      = arena_allocator(& temp_arena)
	context.temp_allocator = arena_allocator(& temp_arena)

	core_log.logf( level, fmt, ..args, location = loc )
}

reload_array :: proc( self : ^[dynamic]$Type, allocator : Allocator ) {
	raw          := transmute( ^runtime.Raw_Dynamic_Array) self
	raw.allocator = allocator
}

reload_map :: proc( self : ^map [$KeyType] $EntryType, allocator : Allocator ) {
	raw          := transmute( ^runtime.Raw_Map) self
	raw.allocator = allocator
}

font_glyph_lru_code :: #force_inline proc "contextless" ( font : FontID, glyph_index : Glyph ) -> (lru_code : u64) {
	lru_code = u64(glyph_index) + ( ( 0x100000000 * u64(font) ) & 0xFFFFFFFF00000000 )
	return
}

is_empty :: #force_inline proc ( ctx : ^Context, entry : ^Entry, glyph_index : Glyph ) -> b32
{
	if glyph_index == 0 do return true
	if parser_is_glyph_empty( & entry.parser_info, glyph_index ) do return true
	return false
}

mark_batch_codepoint_seen :: #force_inline proc ( ctx : ^Context, lru_code : u64 ) {
	ctx.temp_codepoint_seen[lru_code] = true
	ctx.temp_codepoint_seen_num += 1
}

reset_batch_codepoint_state :: #force_inline proc( ctx : ^Context ) {
	clear_map( & ctx.temp_codepoint_seen )
	ctx.temp_codepoint_seen_num = 0
}

screenspace_x_form :: #force_inline proc "contextless" ( position, scale : ^Vec2, size : Vec2 )
{
	if true
	{
		pos_64   := vec2_64_from_vec2(position^)
		scale_64 := vec2_64_from_vec2(scale^)

		quotient : Vec2_64 = 1.0 / vec2_64(size)
		pos_64      = pos_64   * quotient * 2.0 - 1.0
		scale_64    = scale_64 * quotient * 2.0

		(position^) = { f32(pos_64.x), f32(pos_64.y) }
		(scale^)    = { f32(scale_64.x), f32(scale_64.y) }
	}
	else
	{
		pos      := position^
		scale_32 := scale^

		quotient : Vec2 = 1.0 / size
		pos       = pos   * quotient * 2.0 - 1.0
		scale_32  = scale_32 * quotient * 2.0

		(position^) = pos
		(scale^)    = scale_32
	}
}

textspace_x_form :: #force_inline proc "contextless" ( position, scale : ^Vec2, size : Vec2 )
{
	if true
	{
		pos_64   := vec2_64_from_vec2(position^)
		scale_64 := vec2_64_from_vec2(scale^)

		quotient : Vec2_64 = 1.0 / vec2_64(size)
		pos_64   *= quotient
		scale_64 *= quotient

		(position^) = { f32(pos_64.x), f32(pos_64.y) }
		(scale^)    = { f32(scale_64.x), f32(scale_64.y) }
	}
	else
	{
		quotient : Vec2 = 1.0 / size
		(position^) *= quotient
		(scale^)    *= quotient
	}
}

Use_SIMD_For_Bezier_Ops :: true

when ! Use_SIMD_For_Bezier_Ops
{
	// For a provided alpha value,
	// allows the function to calculate the position of a point along the curve at any given fraction of its total length
	// ve_fontcache_eval_bezier (quadratic)
	eval_point_on_bezier3 :: #force_inline proc "contextless" ( p0, p1, p2 : Vec2, alpha : f32 ) -> Vec2
	{
		p0    := vec2_64(p0)
		p1    := vec2_64(p1)
		p2    := vec2_64(p2)
		alpha := f64(alpha)

		weight_start   := (1 - alpha) * (1 - alpha)
		weight_control := 2.0 * (1 - alpha) * alpha
		weight_end     := alpha * alpha

		starting_point := p0 * weight_start
		control_point  := p1 * weight_control
		end_point      := p2 * weight_end

		point := starting_point + control_point + end_point
		return { f32(point.x), f32(point.y) }
	}

	// For a provided alpha value,
	// allows the function to calculate the position of a point along the curve at any given fraction of its total length
	// ve_fontcache_eval_bezier (cubic)
	eval_point_on_bezier4 :: #force_inline proc "contextless" ( p0, p1, p2, p3 : Vec2, alpha : f32 ) -> Vec2
	{
		p0    := vec2_64(p0)
		p1    := vec2_64(p1)
		p2    := vec2_64(p2)
		p3    := vec2_64(p3)
		alpha := f64(alpha)

		weight_start := (1 - alpha) * (1 - alpha) * (1 - alpha)
		weight_c_a   := 3 * (1 - alpha) * (1 - alpha) * alpha
		weight_c_b   := 3 * (1 - alpha) * alpha * alpha
		weight_end   := alpha * alpha * alpha

		start_point := p0 * weight_start
		control_a   := p1 * weight_c_a
		control_b   := p2 * weight_c_b
		end_point   := p3 * weight_end

		point := start_point + control_a + control_b + end_point
		return { f32(point.x), f32(point.y) }
	}
}
else
{
	Vec2_SIMD :: simd.f32x4

	vec2_to_simd :: #force_inline proc "contextless" (v: Vec2) -> Vec2_SIMD {
		return Vec2_SIMD{v.x, v.y, 0, 0}
	}

	simd_to_vec2 :: #force_inline proc "contextless" (v: Vec2_SIMD) -> Vec2 {
		return Vec2{ simd.extract(v, 0), simd.extract(v, 1) }
	}

	vec2_add_simd :: #force_inline proc "contextless" (a, b: Vec2) -> Vec2 {
		simd_a := vec2_to_simd(a)
		simd_b := vec2_to_simd(b)
		result := simd.add(simd_a, simd_b)
		return simd_to_vec2(result)
	}

	vec2_sub_simd :: #force_inline proc "contextless" (a, b: Vec2) -> Vec2 {
		simd_a := vec2_to_simd(a)
		simd_b := vec2_to_simd(b)
		result := simd.sub(simd_a, simd_b)
		return simd_to_vec2(result)
	}

	vec2_mul_simd :: #force_inline proc "contextless" (a: Vec2, s: f32) -> Vec2 {
		simd_a := vec2_to_simd(a)
		simd_s := Vec2_SIMD{s, s, s, s}
		result := simd.mul(simd_a, simd_s)
		return simd_to_vec2(result)
	}

	vec2_div_simd :: #force_inline proc "contextless" (a: Vec2, s: f32) -> Vec2 {
		simd_a := vec2_to_simd(a)
		simd_s := Vec2_SIMD{s, s, s, s}
		result := simd.div(simd_a, simd_s)
		return simd_to_vec2(result)
	}

	vec2_dot_simd :: #force_inline proc "contextless" (a, b: Vec2) -> f32 {
		simd_a := vec2_to_simd(a)
		simd_b := vec2_to_simd(b)
		result := simd.mul(simd_a, simd_b)
		return simd.reduce_add_ordered(result)
	}

	vec2_length_sqr_simd :: #force_inline proc "contextless" (a: Vec2) -> f32 {
		return vec2_dot_simd(a, a)
	}

	vec2_length_simd :: #force_inline proc "contextless" (a: Vec2) -> f32 {
		return math.sqrt(vec2_length_sqr_simd(a))
	}

	vec2_normalize_simd :: #force_inline proc "contextless" (a: Vec2) -> Vec2 {
		len := vec2_length_simd(a)
		if len > 0 {
			inv_len := 1.0 / len
			return vec2_mul_simd(a, inv_len)
		}
		return a
	}

	// SIMD-optimized version of eval_point_on_bezier3
	eval_point_on_bezier3 :: #force_inline proc "contextless" (p0, p1, p2: Vec2, alpha: f32) -> Vec2
	{
		simd_p0 := vec2_to_simd(p0)
		simd_p1 := vec2_to_simd(p1)
		simd_p2 := vec2_to_simd(p2)

		one_minus_alpha := 1.0 - alpha
		weight_start    := one_minus_alpha * one_minus_alpha
		weight_control  := 2.0 * one_minus_alpha * alpha
		weight_end      := alpha * alpha

		simd_weights := Vec2_SIMD{weight_start, weight_control, weight_end, 0}
		result := simd.add(
			simd.add(
				simd.mul( simd_p0, simd.swizzle( simd_weights, 0, 0, 0, 0) ),
				simd.mul( simd_p1, simd.swizzle( simd_weights, 1, 1, 1, 1) )
			),
			simd.mul( simd_p2, simd.swizzle(simd_weights, 2, 2, 2, 2) )
		)

		return simd_to_vec2(result)
	}

	eval_point_on_bezier4 :: #force_inline proc "contextless" (p0, p1, p2, p3: Vec2, alpha: f32) -> Vec2
	{
		simd_p0 := vec2_to_simd(p0)
		simd_p1 := vec2_to_simd(p1)
		simd_p2 := vec2_to_simd(p2)
		simd_p3 := vec2_to_simd(p3)

		one_minus_alpha := 1.0 - alpha
		weight_start    := one_minus_alpha * one_minus_alpha * one_minus_alpha
		weight_c_a      := 3 * one_minus_alpha * one_minus_alpha * alpha
		weight_c_b      := 3 * one_minus_alpha * alpha * alpha
		weight_end      := alpha * alpha * alpha

		simd_weights := Vec2_SIMD { weight_start, weight_c_a, weight_c_b, weight_end }
		result      := simd.add(
			simd.add(
				simd.mul( simd_p0, simd.swizzle(simd_weights, 0, 0, 0, 0) ),
				simd.mul( simd_p1, simd.swizzle(simd_weights, 1, 1, 1, 1) )
			),
			simd.add(
				simd.mul( simd_p2, simd.swizzle(simd_weights, 2, 2, 2, 2) ),
				simd.mul( simd_p3, simd.swizzle(simd_weights, 3, 3, 3, 3) )
			)
		)
		return simd_to_vec2(result)
	}
}
