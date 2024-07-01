@module render_glyph

@header package ve_sokol
@header import sg "thirdparty:sokol/gfx"

@vs render_glyph_vs
@include ./ve_source_shared.shdc.glsl
@end

@fs render_glyph_fs
in  vec2 uv;
out vec4 frag_color;

void main()
{
	frag_color = vec4( 1.0, 1.0, 1.0, 1.0 );
}
@end

@program render_glyph render_glyph_vs render_glyph_fs
