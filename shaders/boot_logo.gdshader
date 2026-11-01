shader_type canvas_item;
render_mode unshaded;
// Comp 7's X-axis orientation, around the centre of the flat logo card.
uniform float angle = 0.0;
uniform vec2 logo_size = vec2(348.0, 400.0);
uniform float camera_distance = 5333.3333332;

void vertex() {
	vec2 p = VERTEX - logo_size * 0.5;
	float tilt = radians(angle);
	float depth = p.y * sin(tilt);
	float perspective = camera_distance / (camera_distance + depth);
	VERTEX = vec2(p.x, p.y * cos(tilt)) * perspective + logo_size * 0.5;
}
