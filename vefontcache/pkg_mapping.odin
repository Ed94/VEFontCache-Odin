package vefontcache

import "base:builtin"
	resize_soa_non_zero :: non_zero_resize_soa
import "base:runtime"
import "core:hash"
	ginger16 :: hash.ginger16
import "core:math"
	ceil_f16   :: math.ceil_f16
	ceil_f16le :: math.ceil_f16le
	ceil_f16be :: math.ceil_f16be
	ceil_f32   :: math.ceil_f32
	ceil_f32le :: math.ceil_f32le
	ceil_f32be :: math.ceil_f32be
	ceil_f64   :: math.ceil_f64
	ceil_f64le :: math.ceil_f64le
	ceil_f64be :: math.ceil_f64be

	floor_f16   :: math.floor_f16
	floor_f16le :: math.floor_f16le
	floor_f16be :: math.floor_f16be
	floor_f32   :: math.floor_f32
	floor_f32le :: math.floor_f32le
	floor_f32be :: math.floor_f32be
	floor_f64   :: math.floor_f64
	floor_f64le :: math.floor_f64le
	floor_f64be :: math.floor_f64be
import "core:math/linalg"
import "core:mem"
	Kilobyte  :: mem.Kilobyte
	slice_ptr :: mem.slice_ptr

	Allocator       :: mem.Allocator
	Allocator_Error :: mem.Allocator_Error

	Arena           :: mem.Arena
	arena_allocator :: mem.arena_allocator
	arena_init      :: mem.arena_init
import "core:slice"
import "core:unicode"

//#region("Proc overload mappings")

append :: proc {
	append_elem,
	append_elems,
	append_elem_string,
}

append_soa :: proc {
	append_soa_elem
}

ceil :: proc {
	math.ceil_f16,
	math.ceil_f16le,
	math.ceil_f16be,
	math.ceil_f32,
	math.ceil_f32le,
	math.ceil_f32be,
	math.ceil_f64,
	math.ceil_f64le,
	math.ceil_f64be,

	ceil_vec2,
}

clear :: proc {
	builtin.clear_dynamic_array,
	builtin.clear_map,
}

floor :: proc {
	math.floor_f16,
	math.floor_f16le,
	math.floor_f16be,
	math.floor_f32,
	math.floor_f32le,
	math.floor_f32be,
	math.floor_f64,
	math.floor_f64le,
	math.floor_f64be,

	floor_vec2,
}

fill :: proc {
	slice.fill,
}

max :: proc {
	linalg.max_single,
	linalg.max_double,
}

make :: proc {
	builtin.make_dynamic_array,
	builtin.make_dynamic_array_len,
	builtin.make_dynamic_array_len_cap,
	builtin.make_slice,
	builtin.make_map,
	builtin.make_map_cap,
}

make_soa :: proc {
	builtin.make_soa_dynamic_array_len_cap,
	builtin.make_soa_slice,
}

mul :: proc {
	mul_range2_vec2,
}

peek :: proc {
	peek_array,
}

resize :: proc {
	builtin.resize_dynamic_array,
}

round :: proc {
	math.round_f32,
}

size :: proc {
	size_range2,
}

vec2 :: proc {
	vec2_from_scalar,
	vec2_from_vec2i,
}

vec2i :: proc {
	vec2i_from_vec2,
}

vec2_64 :: proc {
	vec2_64_from_vec2,
}

//#endregion("Proc overload mappings")
