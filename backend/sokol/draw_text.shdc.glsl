@module draw_text

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

uniform texture2D draw_text_src_texture;
uniform sampler   draw_text_src_sampler;

uniform draw_text_fs_params {
	int  down_sample;
	vec4 colour;
};

void main()
{
	float alpha = texture(sampler2D( draw_text_src_texture, draw_text_src_sampler ), uv ).x;
	if ( down_sample == 1 )
	{
		// TODO(Ed): The original author made these consts, I want to instead expose as uniforms...
		const vec2 texture_size = 1.0f / vec2( 2048.0f, 512.0f ); // VEFontCache.Context.buffer_width/buffer_height
		alpha =
			(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2( -0.5f, -0.5f) * texture_size ).x * 0.25f)
		+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2( -0.5f,  0.5f) * texture_size ).x * 0.25f)
		+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2(  0.5f, -0.5f) * texture_size ).x * 0.25f)
		+	(texture(sampler2D( draw_text_src_texture, draw_text_src_sampler), uv + vec2(  0.5f,  0.5f) * texture_size ).x * 0.25f);
	}
	frag_color = vec4( colour.xyz, colour.a * alpha );
}
@end

@program draw_text draw_text_vs draw_text_fs
