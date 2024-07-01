package sokol_demo

import "base:runtime"
import "core:path/filepath"
	file_name_from_path :: filepath.short_stem
import "core:fmt"
import "core:math"
import "core:math/rand"
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

COLOR_BLUE  :: RGBA8 {  90,  90, 230, 255 }
COLOR_RED   :: RGBA8 { 230,  90,  90, 255 }
COLOR_WHITE :: RGBA8 { 255, 255, 255, 255 }

FONT_LARGEST_PIXEL_SIZE       :: 400
FONT_SIZE_INTERVAL         :: 2

FONT_DEFAULT      :: FontID { "" }
FONT_DEFAULT_SIZEZ :: 12.0

FONT_LOAD_USE_DEFAULT_SIZE :: -1
FONT_LOAD_GEN_ID           :: ""

// Working directory assumed to be the build folder
PATH_FONTS :: "../fonts/"

FontID  :: struct {
	label : string,
}

FontDef :: struct {
	path_file    : string,
	default_size : i32,
	size_table   : [FONT_LARGEST_PIXEL_SIZE / FONT_SIZE_INTERVAL] ve.FontID,
}

Demo_Context :: struct {
	ve_ctx     : ve.Context,
	render_ctx : ve_sokol.Context,
	font_ids   : map[string]FontDef,

	// Values between 1, & -1 on Y axis
	mouse_scroll : Vec2,

	font_firacode        : FontID,
	font_logo            : FontID,
	font_title           : FontID,
	font_print           : FontID,
	font_mono            : FontID,
	font_small           : FontID,
	font_demo_sans       : FontID,
	font_demo_serif      : FontID,
	font_demo_script     : FontID,
	font_demo_mono       : FontID,
	font_demo_chinese    : FontID,
	font_demo_japanese   : FontID,
	font_demo_korean     : FontID,
	font_demo_thai       : FontID,
	font_demo_arabic     : FontID,
	font_demo_hebrew     : FontID,
	font_demo_raincode   : FontID,
	font_demo_grid2      : FontID,
	font_demo_grid3      : FontID,

	screen_size : [2]f32,
}

demo_ctx : Demo_Context

font_load :: proc(path_file : string,
	default_size  : i32    = FONT_LOAD_USE_DEFAULT_SIZE,
	desired_id    : string = FONT_LOAD_GEN_ID,
	curve_quality : u32    = 3,
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
		default_size = FONT_DEFAULT_SIZEZ
	}

	def.path_file    = path_file
	def.default_size = default_size

	for font_size : i32 = clamp( FONT_SIZE_INTERVAL, 2, FONT_SIZE_INTERVAL ); font_size <= FONT_LARGEST_PIXEL_SIZE; font_size += FONT_SIZE_INTERVAL
	{
		id    := (font_size / FONT_SIZE_INTERVAL) + (font_size % FONT_SIZE_INTERVAL)
		ve_id := & def.size_table[id - 1]
		ve_ret_id := ve.load_font( & demo_ctx.ve_ctx, desired_id, font_data, f32(font_size), curve_quality )
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
	even_size     := math.round(size * (1.0 / f32(FONT_SIZE_INTERVAL))) * f32(FONT_SIZE_INTERVAL)
	resolved_size  = clamp( i32( even_size), 2, FONT_LARGEST_PIXEL_SIZE )

	id    := (resolved_size / FONT_SIZE_INTERVAL) + (resolved_size % FONT_SIZE_INTERVAL)
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
draw_text_string_pos_norm :: proc( content : string, id : FontID, size : f32, pos : Vec2, color := COLOR_WHITE, scale : f32 = 1.0 )
{
	width  := demo_ctx.screen_size.x
	height := demo_ctx.screen_size.y

	ve_id, resolved_size := font_provider_resolve_draw_id( id, size )
	color_norm           := normalize_rgba8(color)

	ve.set_colour( & demo_ctx.ve_ctx, color_norm )
	ve.draw_text( & demo_ctx.ve_ctx, ve_id, content, pos, Vec2{1 / width, 1 / height} * scale )
	return
}

// Draw text using a string and extent-based screen coordinates
draw_text_string_pos_extent :: proc( content : string, id : FontID, size : f32, pos : Vec2, color := COLOR_WHITE ) {
	render_pos     := pos + demo_ctx.screen_size * 0.5
	normalized_pos := render_pos * (1.0 / demo_ctx.screen_size)
	draw_text_string_pos_norm( content, id, size, normalized_pos, color )
}

OVER_SAMPLE_ZOOM : f32 : 2.0  // Adjust this value as needed

// Adapt the draw_text_string_pos_extent_zoomed procedure
draw_text_zoomed_norm :: proc(content : string, id : FontID, size : f32, pos : Vec2, zoom : f32, color := COLOR_WHITE)
{
	screen_size      := demo_ctx.screen_size
	screen_scale     := Vec2{1.0 / screen_size.x, 1.0 / screen_size.y}
	zoom_adjust_size := size * zoom

	// Over-sample font-size

	zoom_adjust_size *= OVER_SAMPLE_ZOOM

	ve_id, resolved_size := font_provider_resolve_draw_id(id, zoom_adjust_size)

	text_scale := screen_scale
	{
		f32_resolved_size := f32(resolved_size)
		diff_scalar       := 1 + (zoom_adjust_size - f32_resolved_size) / f32_resolved_size
		text_scale         = diff_scalar * screen_scale
		text_scale.x       = clamp(text_scale.x, 0, 1)
		text_scale.y       = clamp(text_scale.y, 0, 1)
	}

	// Down-sample back
	text_scale /= OVER_SAMPLE_ZOOM

	color_norm := normalize_rgba8(color)
	ve.set_colour(&demo_ctx.ve_ctx, color_norm)
	ve.draw_text(&demo_ctx.ve_ctx, ve_id, content, pos, text_scale)
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

	ve.startup( & demo_ctx.ve_ctx, .STB_TrueType, allocator = context.allocator, snap_shape_position = false )
	ve_sokol.setup_gfx_objects( & demo_ctx.render_ctx, & demo_ctx.ve_ctx, vert_cap = 1024 * 1024, index_cap = 1024 * 1024 )

	error : mem.Allocator_Error
	demo_ctx.font_ids, error = make( map[string]FontDef, 256 )
	assert( error == .None, "Failed to allocate demo_ctx.font_ids" )

	path_sawarabi_mincho   := strings.concatenate({ PATH_FONTS, "SawarabiMincho-Regular.ttf" })
	path_open_sans         := strings.concatenate({ PATH_FONTS, "OpenSans-Regular.ttf"       })
	path_noto_sans_jp      := strings.concatenate({ PATH_FONTS, "NotoSansJP-Light.otf"       })
	path_ubuntu_mono       := strings.concatenate({ PATH_FONTS, "UbuntuMono-Regular.ttf"     })
	path_roboto            := strings.concatenate({ PATH_FONTS, "Roboto-Regular.ttf"         })
	path_bitter            := strings.concatenate({ PATH_FONTS, "Bitter-Regular.ttf"         })
	path_dancing_script    := strings.concatenate({ PATH_FONTS, "DancingScript-Regular.ttf"  })
	path_nova_mono         := strings.concatenate({ PATH_FONTS, "NovaMono-Regular.ttf"       })
	path_noto_serif_sc     := strings.concatenate({ PATH_FONTS, "NotoSerifSC-Regular.otf"    })
	path_nanum_pen_script  := strings.concatenate({ PATH_FONTS, "NanumPenScript-Regular.ttf" })
	path_krub              := strings.concatenate({ PATH_FONTS, "Krub-Regular.ttf"           })
	path_tajawal           := strings.concatenate({ PATH_FONTS, "Tajawal-Regular.ttf"        })
	path_david_libre       := strings.concatenate({ PATH_FONTS, "DavidLibre-Regular.ttf"     })
	path_noto_sans_jp_reg  := strings.concatenate({ PATH_FONTS, "NotoSansJP-Regular.otf"     })
	path_firacode          := strings.concatenate({ PATH_FONTS, "FiraCode-Regular.ttf"       })

	using demo_ctx
	font_logo          = font_load(path_sawarabi_mincho,  330.0, "SawarabiMincho", 6 )
	font_title         = font_load(path_open_sans,         92.0, "OpenSans", 12 )
	font_print         = font_load(path_noto_sans_jp,      19.0, "NotoSansJP")
	font_mono          = font_load(path_ubuntu_mono,       21.0, "UbuntuMono")
	font_small         = font_load(path_roboto,            10.0, "Roboto")
	font_demo_sans     = font_load(path_open_sans,         18.0, "OpenSans")
	font_demo_serif    = font_load(path_bitter,            18.0, "Bitter")
	font_demo_script   = font_load(path_dancing_script,    22.0, "DancingScript")
	font_demo_mono     = font_load(path_nova_mono,         18.0, "NovaMono")
	font_demo_chinese  = font_load(path_noto_serif_sc,     24.0, "NotoSerifSC")
	font_demo_japanese = font_load(path_sawarabi_mincho,   24.0, "SawarabiMincho")
	font_demo_korean   = font_load(path_nanum_pen_script,  36.0, "NanumPenScript")
	font_demo_thai     = font_load(path_krub,              24.0, "Krub")
	font_demo_arabic   = font_load(path_tajawal,           24.0, "Tajawal")
	font_demo_hebrew   = font_load(path_david_libre,       22.0, "DavidLibre")
	font_demo_raincode = font_load(path_noto_sans_jp_reg,  20.0, "NotoSansJPRegular")
	font_demo_grid2    = font_load(path_noto_serif_sc,     54.0, "NotoSerifSC")
	font_demo_grid3    = font_load(path_bitter,            44.0, "Bitter")
	font_firacode      = font_load(path_firacode,          16.0, "FiraCode", 12 )
}

event :: proc "c" (sokol_event : ^app.Event)
{
	#partial switch sokol_event.type {
		case .MOUSE_SCROLL:
			demo_ctx.mouse_scroll = clamp(sokol_event.scroll_y, -1, 1) * -1
	}
}

frame :: proc "c" ()
{
	context = runtime.default_context()

	demo_ctx.screen_size = { app.widthf(), app.heightf() }

	pass_action : gfx.Pass_Action;
	pass_action.colors[0] = { load_action = .CLEAR, clear_value = { 0.18, 0.204, 0.251, 1.0 } }
	gfx.begin_pass({ action = pass_action, swapchain = glue.swapchain() })
	gfx.end_pass()
	{
		ve.configure_snap( & demo_ctx.ve_ctx, u32(demo_ctx.screen_size.x), u32(demo_ctx.screen_size.y) )
		ve.set_colour( & demo_ctx.ve_ctx, ve.Colour { 1.0, 1.0, 1.0, 1.0 })

		using demo_ctx

		// Smooth scrolling implementation
		@static demo_autoscroll   := false
		@static current_scroll    : f32 =  0.0
		@static mouse_down_pos    : f32 = -1.0
		@static mouse_down_scroll : f32 = -1.0
		@static mouse_prev_pos    : f32 =  0.0
		@static scroll_velocity   : f32 =  0.0

		frame_duration := cast(f32) app.frame_duration()

		scroll_velocity += mouse_scroll.y * 0.05
		mouse_down_pos   = -1.0
		substep_dt      := frame_duration / 4.0
		for _ in 0 ..< 4 {
			scroll_velocity *= math.exp(-3.0 * substep_dt)
			current_scroll += scroll_velocity * substep_dt * 10.0
		}
		if demo_autoscroll {
			current_scroll += 0.05 * frame_duration
		}
		mouse_scroll = {}  // Reset mouse scroll

		// Clamp scroll value if needed
		current_scroll = clamp(current_scroll, 0, 6.1)  // Adjust max value as needed

		// Frametime display
		frametime_text := fmt.tprintf("Frametime %v", frame_duration)
		draw_text_string_pos_norm(frametime_text, font_title, 0, {0.0, 0.0}, COLOR_WHITE)

		if current_scroll < 1.5 {
			intro := `Ça va! Everything here is rendered using VE Font Cache, a single header-only library designed for game engines.
It aims to:
			•    Be fast and simple to integrate.
			•    Take advantage of modern GPU power.
			•    Be backend agnostic and easy to port to any API such as Vulkan, DirectX, OpenGL.
			•    Load TTF & OTF file formats directly.
			•    Use only runtime cache with no offline calculation.
			•    Render glyphs at reasonable quality at a wide range of hb_font sizes.
			•    Support a good amount of internationalisation. そうですね!
			•    Support cached text shaping with HarfBuzz with simple Latin-style fallback.
			•    Load and unload fonts at any time.`

			draw_text_string_pos_norm("ゑ", font_logo, 330, {0.4, current_scroll}, COLOR_WHITE)
			draw_text_string_pos_norm("VEFontCache Demo", font_title, 92, {0.2, current_scroll - 0.1}, COLOR_WHITE)
			draw_text_string_pos_norm(intro, font_print, 19, {0.2, current_scroll - 0.14}, COLOR_WHITE)
		}

		section_start : f32 = 0.42
		section_end   : f32 = 2.32
		if current_scroll > section_start && current_scroll < section_end {
			how_it_works := `Glyphs are GPU rasterised with 16x supersampling. This method is a simplification of "Easy Scalable Text Rendering on the GPU",
by Evan Wallace, making use of XOR blending. Bézier curves are handled via brute force triangle tessellation; even 6 triangles per
curve only generates < 300 triangles, which is nothing for modern GPUs! This avoids complex frag shader for reasonable quality.

Texture atlas caching uses naïve grid placement; this wastes a lot of space but ensures interchangeable cache slots allowing for
LRU ( Least Recently Used ) caching scheme to be employed.
The hb_font atlas is a single 4k x 2k R8 texture divided into 4 regions:`

				caching_strategy := `                         2k
											--------------------
											|         |        |
											|    A    |        |
											|         |        | 2
											|---------|    C   | k
											|         |        |
								1k |    B    |        |
											|         |        |
											--------------------
											|                  |
											|                  |
											|                  | 2
											|        D         | k
											|                  |
											|                  |
											|                  |
											--------------------

											Region A = 32x32 caches,   1024 glyphs
											Region B = 32x64 caches,   512 glyphs
											Region C = 64x64 caches,   512 glyphs
											Region D = 128x128 caches, 256 glyphs`

			how_it_works2 := `Region A is designed for small glyphs, Region B is for tall glyphs, Region C is for large glyphs, and Region D for huge glyphs.
Glyphs are first rendered to an intermediate 2k x 512px R8 texture. This allows for minimum 4 Region D glyphs supersampled at
4 x 4 = 16x supersampling, and 8 Region C glyphs similarly. A simple 16-tap box downsample shader is then used to blit from this
intermediate texture to the final atlas location.`

			draw_text_string_pos_norm("How it works", font_title, 92, {0.2, current_scroll - (section_start + 0.06)}, COLOR_WHITE)
			draw_text_string_pos_norm(how_it_works, font_print, 19, {0.2, current_scroll - (section_start + 0.1)}, COLOR_WHITE)
			draw_text_string_pos_norm(caching_strategy, demo_ctx.font_mono, 21, {0.28, current_scroll - (section_start + 0.32)}, COLOR_WHITE)
			draw_text_string_pos_norm(how_it_works2, font_print, 19, {0.2, current_scroll - (section_start + 0.82)}, COLOR_WHITE)
		}

		// Showcase section
		section_start, section_end = 1.2, 3.2
		if current_scroll > section_start && current_scroll < section_end
		{
			font_family_test := `Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Est ullamcorper eget nulla facilisi
etiam dignissim diam quis enim. Convallis convallis tellus id interdum.`

			draw_text_string_pos_norm("Showcase", font_title, 92, {0.2, current_scroll - (section_start + 0.2)}, COLOR_WHITE)
			draw_text_string_pos_norm("This is a showcase demonstrating different hb_font categories and languages.", font_print, 19, {0.2, current_scroll - (section_start + 0.24)}, COLOR_WHITE)

			draw_text_string_pos_norm("Sans serif", font_print, 19, {0.2, current_scroll - (section_start + 0.28)}, COLOR_WHITE)
			draw_text_string_pos_norm(font_family_test, font_demo_sans, 18, {0.3, current_scroll - (section_start + 0.28)}, COLOR_WHITE)

			draw_text_string_pos_norm("Serif", font_print, 19, {0.2, current_scroll - (section_start + 0.36)}, COLOR_WHITE)
			draw_text_string_pos_norm(font_family_test, font_demo_serif, 18, {0.3, current_scroll - (section_start + 0.36)}, COLOR_WHITE)

			draw_text_string_pos_norm("Script", font_print, 19, {0.2, current_scroll - (section_start + 0.44)}, COLOR_WHITE)
			draw_text_string_pos_norm(font_family_test, font_demo_script, 22, {0.3, current_scroll - (section_start + 0.44)}, COLOR_WHITE)

			draw_text_string_pos_norm("Monospace", font_print, 19, {0.2, current_scroll - (section_start + 0.52)}, COLOR_WHITE)
			draw_text_string_pos_norm(font_family_test, font_demo_mono, 18, {0.3, current_scroll - (section_start + 0.52)}, COLOR_WHITE)

			draw_text_string_pos_norm("Small", font_print, 19, {0.2, current_scroll - (section_start + 0.60)}, COLOR_WHITE)
			draw_text_string_pos_norm(font_family_test, font_small, 10, {0.3, current_scroll - (section_start + 0.60)}, COLOR_WHITE)

			draw_text_string_pos_norm("Greek", font_print, 19, {0.2, current_scroll - (section_start + 0.72)}, COLOR_WHITE)
			draw_text_string_pos_norm("Ήταν απλώς θέμα χρόνου.", font_demo_sans, 18, {0.3, current_scroll - (section_start + 0.72)}, COLOR_WHITE)

			draw_text_string_pos_norm("Vietnamese", font_print, 19, {0.2, current_scroll - (section_start + 0.76)}, COLOR_WHITE)
			draw_text_string_pos_norm("Bầu trời trong xanh thăm thẳm, không một gợn mây.", font_demo_sans, 18, {0.3, current_scroll - (section_start + 0.76)}, COLOR_WHITE)

			draw_text_string_pos_norm("Thai", font_print, 19, {0.2, current_scroll - (section_start + 0.80)}, COLOR_WHITE)
			draw_text_string_pos_norm("การเดินทางขากลับคงจะเหงา", font_demo_thai, 24, {0.3, current_scroll - (section_start + 0.80)}, COLOR_WHITE)

			draw_text_string_pos_norm("Chinese", font_print, 19, {0.2, current_scroll - (section_start + 0.84)}, COLOR_WHITE)
			draw_text_string_pos_norm("床前明月光 疑是地上霜 举头望明月 低头思故乡", font_demo_chinese, 24, {0.3, current_scroll - (section_start + 0.84)}, COLOR_WHITE)

			draw_text_string_pos_norm("Japanese", font_print, 19, {0.2, current_scroll - (section_start + 0.88)}, COLOR_WHITE)
			draw_text_string_pos_norm("ぎょしょうとナレズシの研究 モンスーン・アジアの食事文化", font_demo_japanese, 24, {0.3, current_scroll - (section_start + 0.88)}, COLOR_WHITE)

			draw_text_string_pos_norm("Korean", font_print, 19, {0.2, current_scroll - (section_start + 0.92)}, COLOR_WHITE)
			draw_text_string_pos_norm("그들의 장비와 기구는 모두 살아 있다.", font_demo_korean, 36, {0.3, current_scroll - (section_start + 0.92)}, COLOR_WHITE)

			draw_text_string_pos_norm("Arabic", font_print, 19, {0.2, current_scroll - (section_start + 0.96)}, COLOR_WHITE)
			draw_text_string_pos_norm("حب السماء لا تمطر غير الأحلام. This one needs HarfBuzz to work!", font_demo_arabic, 24, {0.3, current_scroll - (section_start + 0.96)}, COLOR_WHITE)

			draw_text_string_pos_norm("Hebrew", font_print, 19, {0.2, current_scroll - (section_start + 1.0)}, COLOR_WHITE)
			draw_text_string_pos_norm("אז הגיע הלילה של כוכב השביט הראשון. This one needs HarfBuzz to work!", font_demo_hebrew, 22, {0.3, current_scroll - (section_start + 1.0)}, COLOR_WHITE)
		}

		// Zoom Test
		section_start = 2.3
		section_end   = section_start + 2.23
		if current_scroll > section_start && current_scroll < section_end
		{
			zoom_text := `Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua. Est ullamcorper eget nulla facilisi
etiam dignissim diam quis enim. Convallis convallis tellus id interdum.`

			@static zoom_time: f32 = 0
			zoom_time += frame_duration
			zoom_duration :: 10.0  // Time for one complete zoom cycle in seconds

			modified_linear_zoom :: proc( delta : f32) -> f32
			{
				// Adjust these values to control the time spent at min/max zoom
				min_threshold :: 0.05
				max_threshold :: 0.95

				if      delta < min_threshold do return 0
				else if delta > max_threshold do return 1
				else                          do return (delta - min_threshold) / (max_threshold - min_threshold)
			}

			// Calculate the current zoom
			delta        := (math.sin(2 * math.PI * zoom_time / zoom_duration) + 1) / 2  // Normalize sine wave to 0-1
			zoom_t       := modified_linear_zoom(delta)
			current_zoom := math.lerp(f32(1.0), f32(20.0), zoom_t)  // Zoom range from 0.5x to 50x

			// Calculate positions with reduced gaps
			scroll_offset := current_scroll - section_start
			title_y       := current_scroll - (section_start + 0.05)
			zoom_info_y   := current_scroll - (section_start + 0.10)
			zoomed_text_y := current_scroll - (section_start + 0.30) + math.sin(zoom_time) * 0.02

			draw_text_string_pos_norm("Zoom Test", font_title, 92, {0.2, title_y}, COLOR_WHITE)

			zoomed_text_base_size : f32 = 12.0
			zoom_adjust_size      := zoomed_text_base_size * current_zoom
			ve_id, resolved_size  := font_provider_resolve_draw_id( font_firacode, zoom_adjust_size * OVER_SAMPLE_ZOOM )
			current_zoom_text     := fmt.tprintf("Current Zoom         : %.2f x\nCurrent Resolved Size: %v px", current_zoom, resolved_size )
			draw_text_string_pos_norm(current_zoom_text, font_firacode, 19, {0.2, zoom_info_y}, COLOR_WHITE)

			ve.configure_snap( & demo_ctx.ve_ctx, u32(0), u32(0) )

			size            := measure_text_size( zoom_text, font_firacode, zoomed_text_base_size, 0 ) * current_zoom
			x_offset        := (size.x / demo_ctx.screen_size.x) * 0.5
			zoomed_text_pos := Vec2 { 0.5 - x_offset, zoomed_text_y }
			draw_text_zoomed_norm(zoom_text, font_firacode, zoomed_text_base_size, zoomed_text_pos, current_zoom, COLOR_WHITE)
		}

		// Raincode Demo
		section_start = 3.6
		section_end   = 5.4
		if current_scroll > section_start && current_scroll < section_end
		{
			GRID_W        :: 80
			GRID_H        :: 50
			NUM_RAINDROPS :: GRID_W / 3

			@static init_grid   := false
			@static grid        : [ GRID_W * GRID_H ]int
			@static grid_age    : [ GRID_W * GRID_H ]f32
			@static raindropsX  : [ NUM_RAINDROPS   ]int
			@static raindropsY  : [ NUM_RAINDROPS   ]int
			@static code_colour : RGBA8

			@static codes := [?]string {
				" ", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "Z", "T", "H", "E", "｜", "¦", "日",
				"ﾊ", "ﾐ", "ﾋ", "ｰ", "ｳ", "ｼ", "ﾅ", "ﾓ", "ﾆ", "ｻ", "ﾜ", "ﾂ", "ｵ", "ﾘ", "ｱ", "ﾎ", "ﾃ", "ﾏ",
				"ｹ", "ﾒ", "ｴ", "ｶ", "ｷ", "ﾑ", "ﾕ", "ﾗ", "ｾ", "ﾈ", "ｽ", "ﾂ", "ﾀ", "ﾇ", "ﾍ", ":", "・", ".",
				"\"", "=", "*", "+", "-", "<", ">", "ç", "ﾘ", "ｸ", "ｺ", "ﾁ", "ﾔ", "ﾙ", "ﾝ", "C", "O", "D"
			}

			if !init_grid {
				for idx in 0..<NUM_RAINDROPS do raindropsY[idx] = GRID_H
				init_grid = true
			}

			@static fixed_timestep_passed : f32 = 0.0
			fixed_timestep        : f32 = (1.0 / 30.0)
			fixed_timestep_passed += frame_duration
			for fixed_timestep_passed > fixed_timestep
			{
				for idx in 0 ..< (GRID_W * GRID_H) do grid_age[idx] += frame_duration
				for idx in 0 ..< NUM_RAINDROPS {
					raindropsY[idx] += 1
					if raindropsY[idx] < 0 do continue
					if raindropsY[idx] >= GRID_H {
						raindropsY[idx] = -5 - rand.int_max(40)
						raindropsX[idx] = rand.int_max(GRID_W)
						continue
					}
					grid    [ raindropsY[idx] * GRID_W + raindropsX[idx] ] = rand.int_max(len(codes))
					grid_age[ raindropsY[idx] * GRID_W + raindropsX[idx] ] = 0.0
				}
				fixed_timestep_passed = 0
			}

			// Draw grid
			draw_text_string_pos_norm("Raincode demo", font_title, 92, { 0.2, current_scroll - (section_start + 0.2) }, COLOR_WHITE)
			for y in 0 ..< GRID_H do for x in 0 ..< GRID_W
			{
				pos_x := 0.2 + f32(x) * 0.007
				pos_y := current_scroll - (section_start + 0.24 + f32(y) * 0.018)
				age   := grid_age[y * GRID_W + x]

				code_colour = {255, 255, 255, 255}
				if age > 0.0 {
					code_colour = {
						51 + 30,
						77 + 30,
						102 + 30,
						u8(clamp((1.0 - age) * 255, 0, 255) ) }
					if code_colour.a == 0 do continue
				}

				draw_text_string_pos_norm(codes[grid[y * GRID_W + x]], font_demo_raincode, 20, {pos_x, pos_y}, code_colour)
			}

			ve.set_colour(&ve_ctx, {1.0, 1.0, 1.0, 1.0})
		}

		// Cache pressure test
		section_start = 5.3
		section_end   = 6.2
		if current_scroll > section_start && current_scroll < section_end && true
		{
			GRID_W  :: 30
			GRID_H  :: 15
			GRID2_W :: 8
			GRID2_H :: 2
			GRID3_W :: 16
			GRID3_H :: 4

			@static grid  : [GRID_W  * GRID_H ]int
			@static grid2 : [GRID2_W * GRID2_H]int
			@static grid3 : [GRID3_W * GRID3_H]int

			@static rotate_current        : int = 0
			@static fixed_timestep_passed : f32 = 0.0

			fixed_timestep_passed += frame_duration
			fixed_timestep        := f32(1.0 / 30.0)
			for fixed_timestep_passed > fixed_timestep
			{
				rotate_current = (rotate_current + 1) % 4
				rotate_idx    := 0
				for & g in grid
				{
					if (rotate_idx % 4) != rotate_current {
						rotate_idx += 1
						continue
					}
					g = 0x4E00 + rand.int_max(0x9FFF - 0x4E00)
					rotate_idx += 1
				}
				for & g in grid2 do g = 0x4E00 + rand.int_max(0x9FFF - 0x4E00)
				for & g in grid3 do g = rand.int_max(128)
				fixed_timestep_passed -= fixed_timestep
			}

			codepoint_to_utf8 :: proc(c: []u8, chr: int) {
				if chr == 0 {
					return
				}
				else if (0xffffff80 & chr) == 0 {
					c[0] = u8(chr)
				}
				else if (0xfffff800 & chr) == 0 {
					c[0] = 0xc0 | u8(chr >> 6)
					c[1] = 0x80 | u8(chr & 0x3f)
				}
				else if (0xffff0000 & chr) == 0 {
					c[0] = 0xe0 | u8(chr >> 12)
					c[1] = 0x80 | u8((chr >> 6) & 0x3f)
					c[2] = 0x80 | u8(chr & 0x3f)
				}
				else {
					c[0] = 0xf0 | u8(chr >> 18)
					c[1] = 0x80 | u8((chr >> 12) & 0x3f)
					c[2] = 0x80 | u8((chr >> 6) & 0x3f)
					c[3] = 0x80 | u8(chr & 0x3f)
				}
			}

			// Draw grid
			draw_text_string_pos_norm("Cache pressure test", font_title, 92, {0.2, current_scroll - (section_start + 0.2)}, COLOR_WHITE)
			for y in 0..< GRID_H do for x in 0 ..< GRID_W
			{
				posx := 0.2 + f32(x) * 0.02
				posy := current_scroll - (section_start + 0.24 + f32(y) * 0.025)
				c    := [5]u8{}
				codepoint_to_utf8(c[:], grid[ y * GRID_W + x ])
				draw_text_string_pos_norm(string( c[:] ), font_demo_chinese, 24, {posx, posy}, COLOR_WHITE)
			}
			for y in 0 ..< GRID2_H do for x in 0 ..< GRID2_W {
				posx := 0.2 + f32(x) * 0.03
				posy := current_scroll - (section_start + 0.66 + f32(y) * 0.052)
				c    := [5]u8{}
				codepoint_to_utf8(c[:], grid2[ y * GRID2_W + x ])
				draw_text_string_pos_norm(string( c[:] ), font_demo_grid2, 54, {posx, posy}, COLOR_WHITE)
			}
			for y in 0 ..< GRID3_H do for x in 0 ..< GRID3_W {
				posx := 0.45 + f32(x) * 0.02
				posy := current_scroll - (section_start + 0.64 + f32(y) * 0.034)
				c    := [5]u8{}
				codepoint_to_utf8( c[:], grid3[ y * GRID3_W + x ])
				draw_text_string_pos_norm(string( c[:] ), font_demo_grid3, 44, {posx, posy}, COLOR_WHITE)
			}
		}

		ve_sokol.render_text_layer(demo_ctx.screen_size * 0.5, & demo_ctx.ve_ctx, demo_ctx.render_ctx)
	}

	gfx.commit()
	ve.flush_draw_list( & demo_ctx.ve_ctx )
}

cleanup :: proc "c" () {
	context = runtime.default_context()
	// ve.shutdown( & demo_ctx.ve_ctx )
	gfx.shutdown()
}

main :: proc()
{
	demo_ctx.screen_size = Vec2 { 1920, 1080 }

	app.run({
		init_cb      = init,
		event_cb     = event,
		frame_cb     = frame,
		cleanup_cb   = cleanup,
		width        = i32(demo_ctx.screen_size.x),
		height       = i32(demo_ctx.screen_size.y),
		window_title = "VEFonCache: Sokol Backend Demo",
		icon         = { sokol_default = true },
		logger       = { func = slog.func },
		allocator    = { sokol_app_alloc, sokol_app_free, nil },
	})
}
