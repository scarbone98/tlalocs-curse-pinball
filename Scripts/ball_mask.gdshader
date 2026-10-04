shader_type canvas_item;
// The ball's sprite (Scripts/ball.gd), kept where the table says it can be seen:
//  - behind the front walls along the table's foot (Sprites/table/front_walls.png, from
//    tools/make_table.py): a ball rolling down a gutter under them is hidden by them
//  - above the lava's surface: a drained ball sinking into it goes under

uniform sampler2D front_walls : filter_nearest;
uniform vec2 table_size = vec2(720.0, 1280.0);  // scene units the mask covers
uniform bool occlude = true;   // off while it rides a rail, up over everything
uniform float surface_y = 1.0e6;  // the lava's surface (scene units); far below while it's in play

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (world.y > surface_y) {
		discard;
	}
	if (occlude && texture(front_walls, world / table_size).a > 0.5) {
		discard;
	}
	COLOR = texture(TEXTURE, UV) * COLOR;
}
