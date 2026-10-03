extends Node2D
## The temple's mood: the whole table sits in a cool dusk (TableFeatures' CanvasModulate,
## darker still in Tlaloc's storm), lit by the things that burn and glow in it. Each torch
## throws a warm, flickering pool of light while it burns (none on embers), the
## golden temple glows, Tlaloc's whirl casts violet while his mouth is open, and a lit gold
## button glows. A wide, dim sky light falls over the arena, and the drain glows red.
## The pools are pixel art too: a few flat rings, in texels the size of the table's pixels.

const MOOD := Color(0.56, 0.54, 0.68)   # dusk over the table
const STORM := Color(0.42, 0.45, 0.62)  # darker and bluer while the curse rains
const TORCH_COLOUR := Color(1.0, 0.62, 0.3)
const TORCH_SIZE := 1.3
const TORCH_BLAZE := 1.15
const FLICKER := 0.18            # how much a flame's light wavers
const FLAME_ABOVE := Vector2(0, -22)  # the flame sits above a torch's centre (Scripts/torches.gd)
const TEMPLE_AT := Vector2(588, 170)
# A wide, dim pool of sky light over the arena, the idol's tower and the skull
const SKY_AT := Vector2(390, 450)
const SKY_COLOUR := Color(0.75, 0.82, 1.0)
const SKY := 0.38
const SKY_SIZE := 4.4
# A red glow welling up out of the drain between the flippers, slowly pulsing
const GUTTER_AT := Vector2(339, 1262)
const GUTTER_COLOUR := Color(1.0, 0.18, 0.12)
const GUTTER := 0.9
const GUTTER_SIZE := 2.2
const GUTTER_PULSE_SECONDS := 2.6

var features: Node2D  # TableFeatures

var _pools := {}  # size -> its pixel pool
var _torch_lights: Array[PointLight2D] = []
var _whirl_light: PointLight2D
var _gutter_light: PointLight2D
var _button_lights: Array = []  # [sprite, light]
var _clock := 0.0

func _ready() -> void:
	features._storm_tint.color = MOOD
	for torch: AnimatedSprite2D in features._torches:
		var light := _light(torch.position + FLAME_ABOVE, TORCH_COLOUR, TORCH_BLAZE, TORCH_SIZE)
		_torch_lights.append(light)
	_light(TEMPLE_AT, Color(1.0, 0.8, 0.4), 0.55, 2.6)
	_light(SKY_AT, SKY_COLOUR, SKY, SKY_SIZE)
	_gutter_light = _light(GUTTER_AT, GUTTER_COLOUR, GUTTER, GUTTER_SIZE)
	_whirl_light = _light(features.temple.AT, Color(0.85, 0.45, 1.0), 0.9, 1.4)
	for sprite: AnimatedSprite2D in [features.idol_tower._button, features.journey._button_sprite]:
		_button_lights.append([sprite, _light(sprite.position, Color(1.0, 0.85, 0.4), 0.7, 0.6)])

# A light's pool, drawn in the table's own chunky pixels: a few flat rings, brightest in
# the middle, one texel to an art pixel (so it's built to each light's size)
const BAND_EDGES := [0.3, 0.55, 0.8, 1.0]
const BAND_ALPHA := [1.0, 0.66, 0.38, 0.16]
const POOL_PIXELS := 128.0  # a light of size 1 lights a circle this many scene units across
const ART_PIXEL := 2.9      # scene units to an art pixel (MAP_SCALE, about)
const POOL_BLOCK := 3       # screen texels each art-pixel texel is drawn as

func _pixel_pool(size: float) -> ImageTexture:
	if _pools.has(size):
		return _pools[size]
	var texels := maxi(4, int(roundf(POOL_PIXELS * size / ART_PIXEL)))
	var image := Image.create(texels, texels, false, Image.FORMAT_RGBA8)
	var middle := texels / 2.0
	for y in texels:
		for x in texels:
			var r := Vector2(x + 0.5 - middle, y + 0.5 - middle).length() / middle
			var alpha := 0.0
			for band in BAND_EDGES.size():
				if r < BAND_EDGES[band]:
					alpha = BAND_ALPHA[band]
					break
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	# blown up blockily here, so the renderer's smoothing can't soften a texel's edges
	image.resize(texels * POOL_BLOCK, texels * POOL_BLOCK, Image.INTERPOLATE_NEAREST)
	_pools[size] = ImageTexture.create_from_image(image)
	return _pools[size]

func _light(at: Vector2, colour: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _pixel_pool(size)
	light.texture_scale = ART_PIXEL / POOL_BLOCK
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.color = colour
	light.energy = energy
	light.position = at
	features.add_child(light)
	return light

func _process(delta: float) -> void:
	_clock += delta
	for i in _torch_lights.size():
		var torch: AnimatedSprite2D = features._torches[i]
		# a torch only throws light while it's burning, not smouldering on embers
		var burning := torch.animation == &"blaze"
		_torch_lights[i].visible = burning
		if not burning:
			continue
		var waver := sin(_clock * 11.0 + i * 1.7) * 0.5 + sin(_clock * 23.0 + i * 3.1) * 0.5
		_torch_lights[i].energy = TORCH_BLAZE * (1.0 + FLICKER * waver)
	_whirl_light.visible = features.temple._whirl.visible
	_gutter_light.energy = GUTTER * (0.8 + 0.2 * sin(_clock / GUTTER_PULSE_SECONDS * TAU))
	for pair: Array in _button_lights:
		(pair[1] as PointLight2D).visible = (pair[0] as AnimatedSprite2D).visible
