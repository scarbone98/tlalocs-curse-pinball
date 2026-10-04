shader_type canvas_item;
// The ball going under the lava (Scripts/ball.gd): everything below the lava's surface
// line is hidden, and it glows hot just above it.

uniform float surface_y = 0.0;  // the lava's surface, in scene coordinates
uniform vec4 glow : source_color = vec4(1.0, 0.45, 0.1, 1.0);
const float GLOW_BAND = 6.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (world.y > surface_y) {
		discard;
	}
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float hot = clamp(1.0 - (surface_y - world.y) / GLOW_BAND, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, glow.rgb, hot * 0.7), c.a);
}
