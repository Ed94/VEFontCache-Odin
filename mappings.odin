package VEFontCache

import "core:hash"
	fnv64a :: hash.fnv64a
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
import "core:math/linalg"
import "core:mem"
	Kilobyte  :: mem.Kilobyte
	slice_ptr :: mem.slice_ptr

	Allocator      :: mem.Allocator
	AllocatorError :: mem.Allocator_Error

	Arena           :: mem.Arena
	arena_allocator :: mem.arena_allocator
	arena_init      :: mem.arena_init
// import "codebase:grime"
// 	log                :: grime.log
// 	logf               :: grime.logf
// 	profile            :: grime.profile

//#region("Proc overload mappings")

append :: proc {
	append_elem,
	append_elems,
	append_elem_string,
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
	clear_dynamic_array,
}

make :: proc {
	make_dynamic_array,
	make_dynamic_array_len,
	make_dynamic_array_len_cap,
	make_map,
}

resize :: proc {
	resize_dynamic_array,
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
