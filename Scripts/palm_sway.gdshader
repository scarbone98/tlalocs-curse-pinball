shader_type canvas_item;
// A shaken palm's fronds twist back and forth round its middle, further out at their tips,
// in whole art pixels so it stays crisp (Scripts/palms.gd)

uniform float sway = 0.0;     // art pixels the frond tips swing round
uniform vec4 region;          // the palm's region of its texture: x, y, w, h (pixels)

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 px = UV * size;
	vec2 centre = region.xy + region.zw * 0.5;
	vec2 d = (px - centre) / (region.zw * 0.5);
	float r = clamp(length(d), 0.0, 1.0);
	vec2 round_way = vec2(-d.y, d.x);
	vec2 from = floor(px - round_way * sway * r) + 0.5;
	from = clamp(from, region.xy + 0.5, region.xy + region.zw - 0.5);
	COLOR = texture(TEXTURE, from / size);
}
