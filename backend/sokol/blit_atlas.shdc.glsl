// module naming rules are currently dumb with shdc rn...
// @module ve_blit_atlas 

@header package ve_sokol
@header import sg "thirdparty:sokol/gfx"

@vs blit_atlas_vs
@include ./source_shared.shdc.glsl
@end

@fs blit_atlas_fs
in  vec2 uv;
out vec4 frag_color;

layout(binding = 0) uniform texture2D ve_blit_atlas_src_texture;
layout(binding = 0) uniform sampler   ve_blit_atlas_src_sampler;

layout(binding = 0) uniform ve_blit_atlas_fs_params {
	vec2  glyph_buffer_size;
	float over_sample;
	int   region;
};

float down_sample_to_texture( vec2 uv, vec2 texture_size )
{
	float down_sample = 1.0f / over_sample;

	float value =
		texture(sampler2D( ve_blit_atlas_src_texture, ve_blit_atlas_src_sampler ), uv + vec2( 0.0f, 0.0f ) * texture_size ).x * down_sample
	+	texture(sampler2D( ve_blit_atlas_src_texture, ve_blit_atlas_src_sampler ), uv + vec2( 0.0f, 1.0f ) * texture_size ).x * down_sample
	+	texture(sampler2D( ve_blit_atlas_src_texture, ve_blit_atlas_src_sampler ), uv + vec2( 1.0f, 0.0f ) * texture_size ).x * down_sample
	+	texture(sampler2D( ve_blit_atlas_src_texture, ve_blit_atlas_src_sampler ), uv + vec2( 1.0f, 1.0f ) * texture_size ).x * down_sample;

	return value;
}

void main()
{
	const vec2 texture_size = 1.0f / glyph_buffer_size;
	if ( region == 0 || region == 1 || region == 2 || region == 4 )
	{
		float down_sample = 1.0f / over_sample;

		float alpha =
			down_sample_to_texture( uv + vec2( -1.0f, -1.5f ) * texture_size, texture_size ) * down_sample
		+	down_sample_to_texture( uv + vec2(  0.5f, -1.5f ) * texture_size, texture_size ) * down_sample
		+	down_sample_to_texture( uv + vec2( -1.5f,  0.5f ) * texture_size, texture_size ) * down_sample
		+	down_sample_to_texture( uv + vec2(  0.5f,  0.5f ) * texture_size, texture_size ) * down_sample;
		frag_color = vec4( 1.0f, 1.0f, 1.0f, alpha );
	}
	else
	{
		frag_color = vec4( 0.0f, 0.0f, 0.0f, 1.0 );
	}
}
@end

@program ve_blit_atlas blit_atlas_vs blit_atlas_fs
