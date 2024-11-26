package ve_sokol

import ve   "../../vefontcache"
import gfx  "thirdparty:sokol/gfx"
import glue "thirdparty:sokol/glue"

Context :: struct {
	draw_list_vbuf : gfx.Buffer,
	draw_list_ibuf : gfx.Buffer,

	glyph_shader  : gfx.Shader,
	atlas_shader  : gfx.Shader,
	screen_shader : gfx.Shader,

	// 2k x 512, R8
	glyph_rt_color   : gfx.Image,
	glyph_rt_depth   : gfx.Image,
	glyph_rt_sampler : gfx.Sampler,

	// 4k x 2k, R8
	atlas_rt_color   : gfx.Image,
	atlas_rt_depth   : gfx.Image,
	atlas_rt_sampler : gfx.Sampler,

	glyph_pipeline  : gfx.Pipeline,
	atlas_pipeline  : gfx.Pipeline,
	screen_pipeline : gfx.Pipeline,

	glyph_pass  : gfx.Pass,
	atlas_pass  : gfx.Pass,
	screen_pass : gfx.Pass,
}

setup_gfx_objects :: proc( ctx : ^Context, ve_ctx : ^ve.Context, vert_cap, index_cap : u64 )
{
	using ctx
	Attachment_Desc            :: gfx.Attachment_Desc
	Blend_Factor               :: gfx.Blend_Factor
	Blend_Op                   :: gfx.Blend_Op
	Blend_State                :: gfx.Blend_State
	Border_Color               :: gfx.Border_Color
	Buffer_Desciption          :: gfx.Buffer_Desc
	Buffer_Usage               :: gfx.Usage
	Buffer_Type                :: gfx.Buffer_Type
	Color_Target_State         :: gfx.Color_Target_State
	Filter                     :: gfx.Filter
	Image_Desc                 :: gfx.Image_Desc
	Pass_Action                :: gfx.Pass_Action
	Range                      :: gfx.Range
	Resource_State             :: gfx.Resource_State
	Sampler_Description        :: gfx.Sampler_Desc
	Wrap                       :: gfx.Wrap
	Vertex_Attribute_State     :: gfx.Vertex_Attr_State
	Vertex_Buffer_Layout_State :: gfx.Vertex_Buffer_Layout_State
	Vertex_Index_Type          :: gfx.Index_Type
	Vertex_Format              :: gfx.Vertex_Format
	Vertex_Layout_State        :: gfx.Vertex_Layout_State
	Vertex_Step                :: gfx.Vertex_Step

	backend := gfx.query_backend()
	app_env := glue.environment()

	glyph_shader  = gfx.make_shader(render_glyph_shader_desc(backend) )
	atlas_shader  = gfx.make_shader(blit_atlas_shader_desc(backend) )
	screen_shader = gfx.make_shader(draw_text_shader_desc(backend) )

	draw_list_vbuf = gfx.make_buffer( Buffer_Desciption {
		size  = cast(uint)(size_of([4]f32) * vert_cap),
		usage = Buffer_Usage.STREAM,
		type  = Buffer_Type.VERTEXBUFFER,
	})
	assert( gfx.query_buffer_state( draw_list_vbuf) < Resource_State.FAILED, "Failed to make draw_list_vbuf" )

	draw_list_ibuf = gfx.make_buffer( Buffer_Desciption {
		size  = cast(uint)(size_of(u32) * index_cap),
		usage = Buffer_Usage.STREAM,
		type  = Buffer_Type.INDEXBUFFER,
	})
	assert( gfx.query_buffer_state( draw_list_ibuf) < Resource_State.FAILED, "Failed to make draw_list_iubuf" )

	Image_Filter := Filter.LINEAR

	// glyph_pipeline
	{
		vs_layout : Vertex_Layout_State
		{
			using vs_layout
			attrs[ATTR_render_glyph_v_position] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = 0,
				buffer_index = 0,
			}
			attrs[ATTR_render_glyph_v_texture] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = size_of(ve.Vec2),
				buffer_index = 0,
			}
			buffers[0] = Vertex_Buffer_Layout_State {
				stride    = size_of([4]f32),
				step_func = Vertex_Step.PER_VERTEX
			}
		}

		color_target := Color_Target_State {
			pixel_format = .R8,
			write_mask   = .RGBA,
			blend = Blend_State {
				enabled          = true,
				src_factor_rgb   = .ONE_MINUS_DST_COLOR,
				dst_factor_rgb   = .ONE_MINUS_SRC_COLOR,
				op_rgb           = Blend_Op.ADD,
				src_factor_alpha = .ONE_MINUS_DST_ALPHA,
				dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
				op_alpha         = Blend_Op.ADD,
			},
		}

		glyph_pipeline = gfx.make_pipeline({
			shader       = glyph_shader,
			layout       = vs_layout,
			index_type   = Vertex_Index_Type.UINT32,
			colors       = {
				0 = color_target,
			},
			color_count  = 1,
			depth = {
				pixel_format  = .DEPTH,
				compare       = .ALWAYS,
				write_enabled = false,
			},
			cull_mode    = .NONE,
			sample_count = 1,
		})
		assert( gfx.query_pipeline_state(glyph_pipeline) < Resource_State.FAILED, "Failed to make glyph_pipeline" )
	}

	// glyph_pass
	{
		glyph_rt_color = gfx.make_image( Image_Desc {
			type          = ._2D,
			render_target = true,
			width         = i32(ve_ctx.glyph_buffer.width),
			height        = i32(ve_ctx.glyph_buffer.height),
			num_slices    = 1,
			num_mipmaps   = 1,
			usage         = .IMMUTABLE,
			pixel_format  = .R8,
			sample_count  = 1,
		})
		assert( gfx.query_image_state(glyph_rt_color) < Resource_State.FAILED, "Failed to make glyph_pipeline" )

		glyph_rt_depth = gfx.make_image( Image_Desc {
			type          = ._2D,
			render_target = true,
			width         = i32(ve_ctx.glyph_buffer.width),
			height        = i32(ve_ctx.glyph_buffer.height),
			num_slices    = 1,
			num_mipmaps   = 1,
			usage         = .IMMUTABLE,
			pixel_format  = .DEPTH,
			sample_count  = 1,
		})

		glyph_rt_sampler = gfx.make_sampler( Sampler_Description {
			min_filter     = Image_Filter,
			mag_filter     = Image_Filter,
			mipmap_filter  = Filter.NEAREST,
			wrap_u         = .CLAMP_TO_EDGE,
			wrap_v         = .CLAMP_TO_EDGE,
			min_lod        = -1000.0,
			max_lod        =  1000.0,
			border_color   = Border_Color.OPAQUE_BLACK,
			compare        = .NEVER,
			max_anisotropy = 1,
		})
		assert( gfx.query_sampler_state( glyph_rt_sampler) < Resource_State.FAILED, "Failed to make atlas_rt_sampler" )

		color_attach := Attachment_Desc {
			image = glyph_rt_color,
		}

		glyph_attachments := gfx.make_attachments({
			colors = {
				0 = color_attach,
			},
			depth_stencil = {
				image = glyph_rt_depth,
			},
		})
		assert( gfx.query_attachments_state(glyph_attachments) < Resource_State.FAILED, "Failed to make glyph_attachments" )

		glyph_action := Pass_Action {
			colors = {
				0 = {
					load_action  = .LOAD,
					store_action = .STORE,
					clear_value  = {0.00, 0.00, 0.00, 1.00},
				}
			},
			depth = {
				load_action  = .DONTCARE,
				store_action = .DONTCARE,
				clear_value  = 0.0,
			},
			stencil = {
				load_action  = .DONTCARE,
				store_action = .DONTCARE,
				clear_value  = 0,
			}
		}

		glyph_pass = gfx.Pass {
			action      = glyph_action,
			attachments = glyph_attachments,
			// label =
		}
	}

	// atlas_pipeline
	{
		vs_layout : Vertex_Layout_State
		{
			using vs_layout
			attrs[ATTR_blit_atlas_v_position] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = 0,
				buffer_index = 0,
			}
			attrs[ATTR_blit_atlas_v_texture] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = size_of(ve.Vec2),
				buffer_index = 0,
			}
			buffers[0] = Vertex_Buffer_Layout_State {
				stride    = size_of([4]f32),
				step_func = Vertex_Step.PER_VERTEX
			}
		}

		color_target := Color_Target_State {
			pixel_format = .R8,
			write_mask   = .RGBA,
			blend = Blend_State {
				enabled          = true,
				src_factor_rgb   = .SRC_ALPHA,
				dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
				op_rgb           = Blend_Op.ADD,
				src_factor_alpha = .SRC_ALPHA,
				dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
				op_alpha         = Blend_Op.ADD,
			},
		}

		atlas_pipeline = gfx.make_pipeline({
			shader     = atlas_shader,
			layout     = vs_layout,
			index_type = Vertex_Index_Type.UINT32,
			colors     = {
				0 = color_target,
			},
			color_count  = 1,
			depth = {
				pixel_format  = .DEPTH,
				compare       = .ALWAYS,
				write_enabled = false,
			},
			cull_mode    = .NONE,
			sample_count = 1,
		})
	}

	// atlas_pass
	{
		atlas_rt_color = gfx.make_image( Image_Desc {
			type          = ._2D,
			render_target = true,
			width         = i32(ve_ctx.atlas.width),
			height        = i32(ve_ctx.atlas.height),
			num_slices    = 1,
			num_mipmaps   = 1,
			usage         = .IMMUTABLE,
			pixel_format  = .R8,
			sample_count  = 1,
			// TODO(Ed): Setup labels for debug tracing/logging
			// label         = 
		})
		assert( gfx.query_image_state(atlas_rt_color) < Resource_State.FAILED, "Failed to make atlas_rt_color")

		atlas_rt_depth = gfx.make_image( Image_Desc {
			type          = ._2D,
			render_target = true,
			width         = i32(ve_ctx.atlas.width),
			height        = i32(ve_ctx.atlas.height),
			num_slices    = 1,
			num_mipmaps   = 1,
			usage         = .IMMUTABLE,
			pixel_format  = .DEPTH,
			sample_count  = 1,
		})
		assert( gfx.query_image_state(atlas_rt_depth) < Resource_State.FAILED, "Failed to make atlas_rt_depth")

		atlas_rt_sampler = gfx.make_sampler( Sampler_Description {
			min_filter     = Image_Filter,
			mag_filter     = Image_Filter,
			mipmap_filter  = Filter.NEAREST,
			wrap_u         = .CLAMP_TO_EDGE,
			wrap_v         = .CLAMP_TO_EDGE,
			min_lod        = -1000.0,
			max_lod        =  1000.0,
			border_color   = Border_Color.OPAQUE_BLACK,
			compare        = .NEVER,
			max_anisotropy = 1,
		})
		assert( gfx.query_sampler_state( atlas_rt_sampler) < Resource_State.FAILED, "Failed to make atlas_rt_sampler" )

		color_attach := Attachment_Desc {
			image     = atlas_rt_color,
		}

		atlas_attachments := gfx.make_attachments({
			colors = {
				0 = color_attach,
			},
			depth_stencil = {
				image = atlas_rt_depth,
			},
		})
		assert( gfx.query_attachments_state(atlas_attachments) < Resource_State.FAILED, "Failed to make atlas_attachments")

		atlas_action := Pass_Action {
			colors = {
				0 = {
					load_action  = .LOAD,
					store_action = .STORE,
					clear_value  = {0.00, 0.00, 0.00, 1.0},
				}
			},
			depth = {
				load_action = .DONTCARE,
				store_action = .DONTCARE,
				clear_value = 0.0,
			},
			stencil = {
				load_action = .DONTCARE,
				store_action = .DONTCARE,
				clear_value = 0,
			}
		}

		atlas_pass = gfx.Pass {
			action      = atlas_action,
			attachments = atlas_attachments,
		}
	}

	// screen pipeline
	{
		vs_layout : Vertex_Layout_State
		{
			using vs_layout
			attrs[ATTR_draw_text_v_position] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = 0,
				buffer_index = 0,
			}
			attrs[ATTR_draw_text_v_texture] = Vertex_Attribute_State {
				format       = Vertex_Format.FLOAT2,
				offset       = size_of(ve.Vec2),
				buffer_index = 0,
			}
			buffers[0] = Vertex_Buffer_Layout_State {
				stride    = size_of([4]f32),
				step_func = Vertex_Step.PER_VERTEX
			}
		}

		color_target := Color_Target_State {
			pixel_format = app_env.defaults.color_format,
			write_mask   = .RGBA,
			blend = Blend_State {
				enabled = true,
				src_factor_rgb   = .SRC_ALPHA,
				dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
				op_rgb           = Blend_Op.ADD,
				src_factor_alpha = .SRC_ALPHA,
				dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
				op_alpha         = Blend_Op.ADD,
			},
		}

		screen_pipeline = gfx.make_pipeline({
			shader     = screen_shader,
			layout     = vs_layout,
			index_type = Vertex_Index_Type.UINT32,
			colors     = {
				0 = color_target,
			},
			color_count  = 1,
			sample_count = 1,
			depth = {
				pixel_format  = app_env.defaults.depth_format,
				compare       = .ALWAYS,
				write_enabled = false,
			},
			cull_mode = .NONE,
		})
		assert( gfx.query_pipeline_state(screen_pipeline) < Resource_State.FAILED, "Failed to make screen_pipeline" )
	}

	// screen_pass
	{
		screen_action := Pass_Action {
			colors = {
				0 = {
					load_action  = .LOAD,
					store_action = .STORE,
					clear_value  = {0.00, 0.00, 0.00, 0.0},
				},
				1 = {
					load_action  = .LOAD,
					store_action = .STORE,
					clear_value  = {0.00, 0.00, 0.00, 0.0},
				},
				2 = {
					load_action  = .LOAD,
					store_action = .STORE,
					clear_value  = {0.00, 0.00, 0.00, 0.0},
				}
			},
			depth = {
				load_action  = .DONTCARE,
				store_action = .DONTCARE,
				clear_value  = 0.0,
			},
			stencil = {
				load_action  = .DONTCARE,
				store_action = .DONTCARE,
				clear_value  = 0,
			}
		}

		screen_pass = gfx.Pass {
			action = screen_action,
		}
	}
}

render_text_layer :: proc( screen_extent : ve.Vec2, ve_ctx : ^ve.Context, ctx : Context )
{
	// profile("VEFontCache: render text layer")
	using ctx

	Bindings     :: gfx.Bindings
	Range        :: gfx.Range
	Shader_Stage :: gfx.Shader_Stage

	vbuf_layer_slice, ibuf_layer_slice, calls_layer_slice := ve.get_draw_list_layer( ve_ctx, optimize_before_returning = true )

	vbuf_ve_range := Range{ raw_data(vbuf_layer_slice), cast(uint) len(vbuf_layer_slice) * size_of(ve.Vertex) }
	ibuf_ve_range := Range{ raw_data(ibuf_layer_slice), cast(uint) len(ibuf_layer_slice) * size_of(u32)       }

	gfx.append_buffer( draw_list_vbuf, vbuf_ve_range )
	gfx.append_buffer( draw_list_ibuf, ibuf_ve_range )

	ve.flush_draw_list_layer( ve_ctx )

	screen_width  := u32(screen_extent.x * 2)
	screen_height := u32(screen_extent.y * 2)

	for & draw_call in calls_layer_slice
	{
		watch := draw_call
		// profile("VEFontCache: draw call")

		num_indices := draw_call.end_index - draw_call.start_index

		switch draw_call.pass
		{
			// 1. Do the glyph rendering pass
			// Glyphs are first rendered to an intermediate 2k x 512px R8 texture
			case .Glyph:
				// profile("VEFontCache: draw call: glyph")
				if num_indices == 0 && ! draw_call.clear_before_draw {
					continue
				}

				width  := ve_ctx.glyph_buffer.width
				height := ve_ctx.glyph_buffer.height

				pass := glyph_pass
				if draw_call.clear_before_draw {
					pass.action.colors[0].load_action   = .CLEAR
					pass.action.colors[0].clear_value.a = 1.0
				}
				gfx.begin_pass( pass )

				gfx.apply_viewport( 0,0, width, height, origin_top_left = true )
				gfx.apply_scissor_rect( 0,0, width, height, origin_top_left = true )

				gfx.apply_pipeline( glyph_pipeline )

				bindings := Bindings {
					vertex_buffers = {
						0 = draw_list_vbuf,
					},
					vertex_buffer_offsets = {
						0 = 0,
					},
					index_buffer        = draw_list_ibuf,
					index_buffer_offset = 0,
				}
				gfx.apply_bindings( bindings )

			// 2. Do the atlas rendering pass
			// A simple 16-tap box downsample shader is then used to blit from this intermediate texture to the final atlas location
			case .Atlas:
				// profile("VEFontCache: draw call: atlas")
				if num_indices == 0 && ! draw_call.clear_before_draw {
					continue
				}

				width  := ve_ctx.atlas.width
				height := ve_ctx.atlas.height

				pass := atlas_pass
				if draw_call.clear_before_draw {
					pass.action.colors[0].load_action   = .CLEAR
					pass.action.colors[0].clear_value.a = 1.0
				}
				gfx.begin_pass( pass )

				gfx.apply_viewport( 0, 0, width, height, origin_top_left = true )
				gfx.apply_scissor_rect( 0, 0, width, height, origin_top_left = true )

				gfx.apply_pipeline( atlas_pipeline )

				fs_uniform := Blit_Atlas_Fs_Params { region = cast(i32) draw_call.region }
				gfx.apply_uniforms( UB_blit_atlas_fs_params, Range { & fs_uniform, size_of(Blit_Atlas_Fs_Params) })

				gfx.apply_bindings(Bindings {
					vertex_buffers = {
						0 = draw_list_vbuf,
					},
					vertex_buffer_offsets = {
						0 = 0,
					},
					index_buffer        = draw_list_ibuf,
					index_buffer_offset = 0,
					images   = { IMG_blit_atlas_src_texture = glyph_rt_color, },
					samplers = { SMP_blit_atlas_src_sampler = glyph_rt_sampler, },
				})

			// 3. Use the atlas to then render the text.
			case .None, .Target, .Target_Uncached:
				if num_indices == 0 && ! draw_call.clear_before_draw {
					continue
				}

				// profile("VEFontCache: draw call: target")

				pass := screen_pass
				pass.swapchain = glue.swapchain()
				gfx.begin_pass( pass )

				gfx.apply_viewport( 0, 0, screen_width, screen_height, origin_top_left = true )
				gfx.apply_scissor_rect( 0, 0, screen_width, screen_height, origin_top_left = true )

				gfx.apply_pipeline( screen_pipeline )

				src_rt      := atlas_rt_color
				src_sampler := atlas_rt_sampler

				fs_target_uniform := Draw_Text_Fs_Params {
					down_sample = 0,
					colour      = draw_call.colour,
				}

				if draw_call.pass == .Target_Uncached {
					fs_target_uniform.down_sample = 1
					src_rt      = glyph_rt_color
					src_sampler = glyph_rt_sampler
				}
				gfx.apply_uniforms( UB_draw_text_fs_params, Range { & fs_target_uniform, size_of(Draw_Text_Fs_Params) })

				gfx.apply_bindings(Bindings {
					vertex_buffers = {
						0 = draw_list_vbuf,
					},
					vertex_buffer_offsets = {
						0 = 0,
					},
					index_buffer        = draw_list_ibuf,
					index_buffer_offset = 0,
					images   = { IMG_draw_text_src_texture = src_rt, },
					samplers = { SMP_draw_text_src_sampler = src_sampler, },
				})
		}

		if num_indices != 0 {
			gfx.draw( draw_call.start_index, num_indices, 1 )
		}

		gfx.end_pass()
	}
}
