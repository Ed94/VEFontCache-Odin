package sokol_demo

import "base:runtime"
import "core:path/filepath"
	file_name_from_path :: filepath.short_stem
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strings"

import ve       "../../vefontcache"
import ve_sokol "backend:sokol"
import app      "thirdparty:sokol/app"
import gfx      "thirdparty:sokol/gfx"
import glue     "thirdparty:sokol/glue"
import slog     "thirdparty:sokol/log"

Vec2 :: ve.Vec2

RGBA8 :: struct { r, g, b, a : u8 }
RGBAN :: [4]f32

normalize_rgba8 :: #force_inline proc( color : RGBA8 ) -> RGBAN {
	quotient : f32 = 1.0 / 255

	result := RGBAN {
		f32(color.r) * quotient,
		f32(color.g) * quotient,
		f32(color.b) * quotient,
		f32(color.a) * quotient,
	}
	return result
}

Color_Blue  :: RGBA8 {  90,  90, 230, 255 }
Color_Red   :: RGBA8 { 230,  90,  90, 255 }
Color_White :: RGBA8 { 255, 255, 255, 255 }

Font_Provider_Use_Freetype :: false
Font_Largest_Px_Size       :: 154
Font_Size_Interval         :: 2

Font_Default      :: FontID { "" }
Font_Default_Size :: 12.0

Font_Load_Use_Default_Size :: -1
Font_Load_Gen_ID           :: ""

// Working directory assumed to be the build folder
Path_Fonts :: "../fonts/"

Screen_Size : [2]f32 : { 1600, 900 }

FontID  :: struct {
	label : string,
}

FontDef :: struct {
	path_file    : string,
	default_size : i32,
	size_table   : [Font_Largest_Px_Size / Font_Size_Interval] ve.FontID,
}

Demo_Context :: struct {
	ve_ctx     : ve.Context,
	render_ctx : ve_sokol.Context,
	font_ids   : map[string]FontDef,

	font_firacode : FontID,
}

demo_ctx : Demo_Context

font_load :: proc(path_file : string,
	default_size : i32    = Font_Load_Use_Default_Size,
	desired_id   : string = Font_Load_Gen_ID
) -> FontID
{
	msg := fmt.println("Loading font: %v", path_file)

	font_data, read_succeded : = os.read_entire_file( path_file )
	assert( bool(read_succeded), fmt.tprintf("Failed to read font file for: %v", path_file) )
	font_data_size := cast(i32) len(font_data)
font_firacode : FontID


	desired_id := desired_id
	if len(desired_id) == 0 {
		fmt.println("desired_key not provided, using file name. Give it a proper name!")
		desired_id = file_name_from_path(path_file)
	}

	demo_ctx.font_ids[desired_id] = FontDef {}
	def := & demo_ctx.font_ids[desired_id]

	default_size := default_size
	if default_size < 0 {
		default_size = Font_Default_Size
	}

	def.path_file    = path_file
	def.default_size = default_size

	for font_size : i32 = clamp( Font_Size_Interval, 2, Font_Size_Interval ); font_size <= Font_Largest_Px_Size; font_size += Font_Size_Interval
	{
		id    := (font_size / Font_Size_Interval) + (font_size % Font_Size_Interval)
		ve_id := & def.size_table[id - 1]
		ve_ret_id := ve.load_font( & demo_ctx.ve_ctx, desired_id, font_data, f32(font_size) )
		(ve_id^) = ve_ret_id
	}

	fid := FontID { desired_id }
	return fid
}

Font_Use_Default_Size :: f32(0.0)

font_provider_resolve_draw_id :: proc( id : FontID, size := Font_Use_Default_Size ) -> ( ve_id : ve.FontID, resolved_size : i32 )
{
	def           := demo_ctx.font_ids[ id.label ]
	size          := size == 0.0 ? f32(def.default_size) : size
	even_size     := math.round(size * (1.0 / f32(Font_Size_Interval))) * f32(Font_Size_Interval)
	resolved_size  = clamp( i32( even_size), 2, Font_Largest_Px_Size )

	id    := (resolved_size / Font_Size_Interval) + (resolved_size % Font_Size_Interval)
	ve_id  = def.size_table[ id - 1 ]
	return
}

measure_text_size :: proc( text : string, font : FontID, font_size := Font_Use_Default_Size, spacing : f32 ) -> Vec2
{
	ve_id, size := font_provider_resolve_draw_id( font, font_size )
	measured    := ve.measure_text_size( & demo_ctx.ve_ctx, ve_id, text )
	return measured
}

get_font_vertical_metrics :: #force_inline proc ( font : FontID, font_size := Font_Use_Default_Size ) -> ( ascent, descent, line_gap : f32 )
{
	ve_id, size := font_provider_resolve_draw_id( font, font_size )
	ascent, descent, line_gap = ve.get_font_vertical_metrics( & demo_ctx.ve_ctx, ve_id )
	return
}

// Draw text using a string and normalized render coordinates
draw_text_string_pos_norm :: proc( content : string, id : FontID, size : f32, pos : Vec2, color := Color_White, scale : f32 = 1.0 )
{
	width  :: Screen_Size.x
	height :: Screen_Size.y

	ve_id, resolved_size := font_provider_resolve_draw_id( id, size )
	color_norm           := normalize_rgba8(color)

	ve.set_colour( & demo_ctx.ve_ctx, color_norm )
	ve.draw_text( & demo_ctx.ve_ctx, ve_id, content, pos, Vec2{1 / width, 1 / height} * scale )
	return
}

// Draw text using a string and extent-based screen coordinates
draw_text_string_pos_extent :: proc( content : string, id : FontID, size : f32, pos : Vec2, color := Color_White )
{
	render_pos     := pos + Screen_Size * 0.5
	normalized_pos := render_pos * (1.0 / Screen_Size)
	draw_text_string_pos_norm( content, id, size, normalized_pos, color )
}

sokol_app_alloc :: proc "c" ( size : u64, user_data : rawptr ) -> rawptr {
	context = runtime.default_context()
	block, error := mem.alloc( int(size), allocator = context.allocator )
	assert(error == .None, "sokol_app allocation failed")
	return block
}

sokol_app_free :: proc "c" ( data : rawptr, user_data : rawptr ) {
	context = runtime.default_context()
	free(data, allocator = context.allocator)
}

sokol_gfx_alloc :: proc "c" ( size : u64, user_data : rawptr ) -> rawptr {
	context = runtime.default_context()
	block, error := mem.alloc( int(size), allocator = context.allocator )
	assert(error == .None, "sokol_gfx allocation failed")
	return block
}

sokol_gfx_free :: proc "c" ( data : rawptr, user_data : rawptr ) {
	context = runtime.default_context()
	free(data, allocator = context.allocator )
}

init :: proc "c" ()
{
	context = runtime.default_context()
	desc := gfx.Desc {
		buffer_pool_size      = 128,
		image_pool_size       = 128,
		sampler_pool_size     = 64,
		shader_pool_size      = 32,
		pipeline_pool_size    = 64,
		attachments_pool_size = 16,
		uniform_buffer_size   = 4 * mem.Megabyte,
		max_commit_listeners  = 1024,
		allocator             = { sokol_gfx_alloc, sokol_gfx_free, nil },
		logger                = { func = slog.func },
		environment           = glue.environment(),
	}
	gfx.setup(desc)

	// just some debug output what backend we're running on
	switch gfx.query_backend() {
		case .D3D11         : fmt.println(">> using D3D11 backend")
		case .GLCORE, .GLES3: fmt.println(">> using GL backend")

		case .METAL_MACOS, .METAL_IOS, .METAL_SIMULATOR:
			fmt.println(">> using Metal backend")

		case .WGPU : fmt.println(">> using WebGPU backend")
		case .DUMMY: fmt.println(">> using dummy backend")
	}

	ve.startup( & demo_ctx.ve_ctx, .STB_TrueType, allocator = context.allocator )
	ve_sokol.setup_gfx_objects( & demo_ctx.render_ctx, & demo_ctx.ve_ctx, vert_cap = 128 * 1024, index_cap = 64 * 1024 )

	error : mem.Allocator_Error
	demo_ctx.font_ids, error = make( map[string]FontDef, 256 )
	assert( error == .None, "Failed to allocate demo_ctx.font_ids" )

	path_firacode          := strings.concatenate( { Path_Fonts, "FiraCode-Regular.ttf" } )
	demo_ctx.font_firacode  = font_load( path_firacode, 16.0, "FiraCode" )
}

frame :: proc "c" ()
{
	context = runtime.default_context()

	pass_action : gfx.Pass_Action;
	pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.18 * 0.18, 0.204 * 0.204, 0.251 * 0.251, 1.0 } }
	gfx.begin_pass({ action = pass_action, swapchain = glue.swapchain() })
	gfx.end_pass()
	{
		ve.configure_snap( & demo_ctx.ve_ctx, u32(Screen_Size.x), u32(Screen_Size.y) )

		draw_text_string_pos_extent( "Hello VEFontCache!", demo_ctx.font_firacode, 24, {0, 0}, Color_White )

		ve_sokol.render_text_layer( Screen_Size, & demo_ctx.ve_ctx, demo_ctx.render_ctx )
	}
	gfx.commit()
	ve.flush_draw_list( & demo_ctx.ve_ctx )
}

cleanup :: proc "c" ()
{
	context = runtime.default_context()
	ve.shutdown( & demo_ctx.ve_ctx )
	gfx.shutdown()
}

main :: proc() {
	app.run({
		init_cb      = init,
		frame_cb     = frame,
		cleanup_cb   = cleanup,
		width        = i32(Screen_Size.x),
		height       = i32(Screen_Size.y),
		window_title = "VEFonCache: Sokol Backend Demo",
		icon         = { sokol_default = true },
		logger       = { func = slog.func },
		allocator    = { sokol_app_alloc, sokol_app_free, nil },
	})
}
