shader_type canvas_item;
// Hides what's below clip_y (scene units, down the table): a warrior sinking down the
// hole in its arena disappears behind the hole's near rim (Scripts/warriors.gd).

uniform float clip_y = 1000000.0;
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	if (world_y > clip_y) {
		discard;
	}
}
