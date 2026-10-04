shader_type canvas_item;
// The ball going under the lava (Scripts/ball.gd): everything below the lava's surface
// line (the table's bottom edge) is hidden.

uniform float surface_y = 0.0;  // the lava's surface, in scene coordinates

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (world.y > surface_y) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
