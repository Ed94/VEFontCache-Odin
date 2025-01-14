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
	gl_Position = vec4( v_position, 0.0, 1.0 );
}
