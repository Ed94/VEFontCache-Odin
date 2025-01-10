package vefontcache

/*
	Didn't want to splinter this into more files..
	Just a bunch of utilities.
*/

import "base:runtime"
import "core:simd"
import "core:math"

import core_log "core:log"

peek_array :: #force_inline proc "contextless" ( self : [dynamic]$Type ) -> Type {
	return self[ len(self) - 1 ]
}

reload_array :: #force_inline proc( self : ^[dynamic]$Type, allocator : Allocator ) {
	raw          := transmute( ^runtime.Raw_Dynamic_Array) self
	raw.allocator = allocator
}

reload_array_soa :: #force_inline proc( self : ^#soa[dynamic]$Type, allocator : Allocator ) {
	raw          := runtime.raw_soa_footer(self)
	raw.allocator = allocator
}

reload_map :: #force_inline proc( self : ^map [$KeyType] $EntryType, allocator : Allocator ) {
	raw          := transmute( ^runtime.Raw_Map) self
	raw.allocator = allocator
}

to_bytes :: #force_inline proc "contextless" ( typed_data : ^$Type ) -> []byte { return slice_ptr( transmute(^byte) typed_data, size_of(Type) ) }

@(optimization_mode="favor_size")
djb8_hash :: #force_inline proc "contextless" ( hash : ^$Type, bytes : []byte ) { for value in bytes do (hash^) = (( (hash^) << 8) + (hash^) ) + Type(value) }

RGBA8   :: [4]u8
RGBAN   :: [4]f32
Vec2    :: [2]f32
Vec2i   :: [2]i32
Vec2_64 :: [2]f64

Transform :: struct {
	pos   : Vec2,
	scale : Vec2,
}

Range2 :: struct {
	p0, p1 : Vec2,
}

mul_range2_vec2 :: #force_inline proc "contextless" ( range : Range2, v : Vec2 ) -> Range2 { return { range.p0 * v, range.p1 * v } }
size_range2     :: #force_inline proc "contextless" ( range : Range2           ) -> Vec2   { return range.p1 - range.p0 }

vec2_from_scalar  :: #force_inline proc "contextless" ( scalar : f32   ) -> Vec2    { return { scalar, scalar }}
vec2_64_from_vec2 :: #force_inline proc "contextless" ( v2     : Vec2  ) -> Vec2_64 { return { f64(v2.x), f64(v2.y) }}
vec2_from_vec2i   :: #force_inline proc "contextless" ( v2i    : Vec2i ) -> Vec2    { return { f32(v2i.x), f32(v2i.y) }}
vec2i_from_vec2   :: #force_inline proc "contextless" ( v2     : Vec2  ) -> Vec2i   { return { i32(v2.x), i32(v2.y) }}

@(require_results) ceil_vec2  :: proc "contextless" ( v : Vec2 ) -> Vec2 { return { ceil_f32(v.x), ceil_f32(v.y) } }
@(require_results) floor_vec2 :: proc "contextless" ( v : Vec2 ) -> Vec2 { return { floor_f32(v.x), floor_f32(v.y) } }

// This buffer is used below excluisvely to prevent any allocator recursion when verbose logging from allocators.
// This means a single line is limited to 4k buffer
// Logger_Allocator_Buffer : [4 * Kilobyte]u8

log :: proc( msg : string, level := core_log.Level.Info, loc := #caller_location ) {
	// temp_arena : Arena; arena_init(& temp_arena, Logger_Allocator_Buffer[:])
	// context.allocator      = arena_allocator(& temp_arena)
	// context.temp_allocator = arena_allocator(& temp_arena)

	core_log.log( level, msg, location = loc )
}

logf :: proc( fmt : string, args : ..any,  level := core_log.Level.Info, loc := #caller_location  ) {
	// temp_arena : Arena; arena_init(& temp_arena, Logger_Allocator_Buffer[:])
	// context.allocator      = arena_allocator(& temp_arena)
	// context.temp_allocator = arena_allocator(& temp_arena)

	core_log.logf( level, fmt, ..args, location = loc )
}

@(optimization_mode="favor_size")
to_glyph_buffer_space :: #force_inline proc "contextless" ( #no_alias position, scale : ^Vec2, size : Vec2 )
{
	pos      := position^
	scale_32 := scale^

	quotient : Vec2 = 1.0 / size
	pos       = pos      * quotient * 2.0 - 1.0
	scale_32  = scale_32 * quotient * 2.0

	(position^) = pos
	(scale^)    = scale_32
}

@(optimization_mode="favor_size")
to_target_space :: #force_inline proc "contextless" ( #no_alias position, scale : ^Vec2, size : Vec2 )
{
	quotient : Vec2 = 1.0 / size
	(position^) *= quotient
	(scale^)    *= quotient
}

USE_MANUAL_SIMD_FOR_BEZIER_OPS :: true

when ! USE_MANUAL_SIMD_FOR_BEZIER_OPS
{
	// For a provided alpha value,
	// allows the function to calculate the position of a point along the curve at any given fraction of its total length
	// ve_fontcache_eval_bezier (quadratic)
	eval_point_on_bezier3 :: #force_inline proc "contextless" ( p0, p1, p2 : Vec2, alpha : f32 ) -> Vec2
	{
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

	@(optimization_mode="favor_size")
	vec2_to_simd :: #force_inline proc "contextless" (v: Vec2) -> Vec2_SIMD {
		return Vec2_SIMD{v.x, v.y, 0, 0}
	}

	@(optimization_mode="favor_size")
	simd_to_vec2 :: #force_inline proc "contextless" (v: Vec2_SIMD) -> Vec2 {
		return Vec2{ simd.extract(v, 0), simd.extract(v, 1) }
	}

	@(optimization_mode="favor_size")
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

	@(optimization_mode="favor_size")
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
