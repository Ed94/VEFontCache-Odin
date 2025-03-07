// module naming rules are currently dumb with shdc rn...
// @module ve_draw_text

@header package ve_sokol
@header import sg "thirdparty:sokol/gfx"

@vs draw_text_vs
in  vec2 v_position;
in  vec2 v_texture;
out vec2 uv;

void main()
{
#if SOKOL_GLSL
	uv          = vec2( v_texture.x, v_texture.y );
#else
	uv          = vec2( v_texture.x, 1.0 - v_texture.y );
#endif
	gl_Position = vec4( v_position * 2.0f - 1.0f, 0.0f, 1.0f );
}
@end

@fs draw_text_fs
in  vec2 uv;
out vec4 frag_color;

layout(binding = 0) uniform texture2D draw_text_src_texture;
layout(binding = 0) uniform sampler   draw_text_src_sampler;

layout(binding = 0) uniform draw_text_fs_params {
	vec2  glyph_buffer_size;
	float over_sample;
	vec4  colour;
};

void main()
{
	float alpha = texture(sampler2D( draw_text_src_texture, draw_text_src_sampler ), uv ).x;

	const vec2  texture_size = glyph_buffer_size;
	const float down_sample  = 1.0f / over_sample;

	alpha =
		(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2( -0.5f, -0.5f) * texture_size ).x * down_sample)
	+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2( -0.5f,  0.5f) * texture_size ).x * down_sample)
	+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2(  0.5f, -0.5f) * texture_size ).x * down_sample)
	+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2(  0.5f,  0.5f) * texture_size ).x * down_sample);
	frag_color = vec4( colour.xyz, colour.a * alpha );
}
@end

@program draw_text draw_text_vs draw_text_fs
