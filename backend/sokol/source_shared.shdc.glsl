in  vec2 v_position;
in  vec2 v_texture;
// in vec4 v_elem;
out vec2 uv;

void main()
{
	uv          = vec2( v_texture.x, 1 - v_texture.y );
	gl_Position = vec4( v_position, 0.0, 1.0 );
}
