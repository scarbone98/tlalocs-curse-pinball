extends Node2D
## The temple's mood: the whole table sits in a cool dusk (TableFeatures' CanvasModulate,
## darker still in Tlaloc's storm), lit by the things that burn and glow in it. Each torch
## throws a warm, flickering pool of light while it burns (none on embers), the
## golden temple glows, Tlaloc's whirl casts violet while his mouth is open, and a lit gold
## button glows. A wide, dim sky light falls over the arena, lamps set in the floor glow
## while they're lit, Tlaloc's eyes glow (red in his storm), and the drain glows red with
## lava sparks spitting up out of it. The pools are pixel art too: two flat rings, in
## texels the size of the table's pixels, and a flame's pool swells and shrinks as it flickers.

const MOOD := Color(0.56, 0.54, 0.68)   # dusk over the table
const STORM := Color(0.42, 0.45, 0.62)  # darker and bluer while the curse rains
const TORCH_COLOUR := Color(1.0, 0.62, 0.3)
const TORCH_SIZE := 1.3
const TORCH_BLAZE := 0.7
const FLICKER_RATES := Vector2(3.2, 6.9)  # the two slow waves a flame's light wavers on (radians/s)
const FLICKER := 0.18            # how much a flame's light wavers
const FLICKER_SIZE := 0.06       # ...and how much its pool swells and shrinks
const FLAME_ABOVE := Vector2(0, -22)  # the flame sits above a torch's centre (Scripts/torches.gd)
const TEMPLE_AT := Vector2(588, 170)
# A wide, dim pool of sky light, drifting after the ball (it starts over the arena)
const SKY_AT := Vector2(390, 450)
const SKY_COLOUR := Color(0.75, 0.82, 1.0)
const SKY := 0.38
const SKY_SIZE := 4.4
const SKY_FOLLOW := 9.0  # how quickly it drifts after the ball: just a little lag
# A red glow welling up out of the drain between the flippers, slowly pulsing: a low,
# flat band of light along the drain rather than a round pool
const GUTTER_AT := Vector2(339, 1250)
const GUTTER_COLOUR := Color(1.0, 0.25, 0.1)
const GUTTER := 1.4
const GUTTER_SIZE := Vector2(170, 56)  # scene units: the band's width and height
const GUTTER_PULSE_SECONDS := 2.6
const GUTTER_SWELL := 0.08  # the lava's pool swells and shrinks with its pulse
const GUTTER_GLOW := Color(0.85, 0.18, 0.06, 0.55)  # the glow drawn on the gutter, added to what's there
const GUTTER_WIDTH := 130.0  # the sparks spit up across this much of the drain
const LAMP_SIZE := 0.45
const EYE_SIZE := 0.3
const EYE_YELLOW := Color(1.0, 0.9, 0.3)
const EYE_RED := Color(1.0, 0.15, 0.1)

var features: Node2D  # TableFeatures

var _pools := {}  # size -> its pixel pool
var _torch_lights: Array[PointLight2D] = []
var _whirl_light: PointLight2D
var _gutter_light: PointLight2D
var _sky_light: PointLight2D
var _gutter_size := 1.0
var _gutter_glow: Sprite2D
var _button_lights: Array = []  # [sprite, light]
var _lamp_lights: Array = []  # [sprite, light, the first frame that counts as lit]
var _eye_lights: Array[PointLight2D] = []
var _torch_sizes: Array[float] = []
var _clock := 0.0

# Godot lights a canvas item with at most 16 lights, and the table's art is two big
# pictures under all of them, so each is cut into tiles that only see the lights near them
const TILE := Vector2(32, 53)  # art pixels: an 8 by 8 grid over the 256x424 table

func _tile_map() -> void:
	var map := features.get_node_or_null(^"../Map")
	if map == null:
		return
	for layer: TextureRect in [map.get_node(^"base"), map.get_node(^"top")]:
		var art := layer.texture
		var size := Vector2(art.get_width(), art.get_height())
		for ty in ceili(size.y / TILE.y):
			for tx in ceili(size.x / TILE.x):
				var tile := Sprite2D.new()
				tile.texture = art
				tile.centered = false
				tile.region_enabled = true
				tile.region_rect = Rect2(Vector2(tx, ty) * TILE, TILE).intersection(Rect2(Vector2.ZERO, size))
				tile.scale = features.MAP_SCALE
				tile.position = tile.region_rect.position * features.MAP_SCALE
				tile.z_index = layer.z_index
				tile.z_as_relative = layer.z_as_relative
				map.add_child(tile)
		layer.hide()

func _ready() -> void:
	_tile_map()
	features._storm_tint.color = MOOD
	for torch: AnimatedSprite2D in features._torches:
		var light := _light(torch.position + FLAME_ABOVE, TORCH_COLOUR, TORCH_BLAZE, TORCH_SIZE)
		_torch_lights.append(light)
		_torch_sizes.append(light.texture_scale)
	_light(TEMPLE_AT, Color(1.0, 0.8, 0.4), 0.55, 2.6)
	_sky_light = _light(SKY_AT, SKY_COLOUR, SKY, SKY_SIZE)
	_gutter_light = _light(GUTTER_AT, GUTTER_COLOUR, GUTTER, 1.0)
	_gutter_light.texture = _pixel_band(GUTTER_SIZE)
	_gutter_size = _gutter_light.texture_scale
	# the lava's own glow, drawn on (a light only tints the dark green floor down there)
	_gutter_glow = Sprite2D.new()
	_gutter_glow.texture = _gutter_light.texture
	_gutter_glow.scale = Vector2.ONE * _gutter_light.texture_scale
	_gutter_glow.position = GUTTER_AT
	_gutter_glow.modulate = GUTTER_GLOW
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_gutter_glow.material = add
	_gutter_glow.z_index = 1
	_gutter_glow.z_as_relative = false
	features.add_child(_gutter_glow)
	_whirl_light = _light(features.temple.AT, Color(0.85, 0.45, 1.0), 0.9, 1.4)
	for sprite: AnimatedSprite2D in [features.idol_tower._button, features.journey._button_sprite]:
		_button_lights.append([sprite, _light(sprite.position, Color(1.0, 0.85, 0.4), 0.7, 0.6)])
	# the lamps set in the floor: the lanes', the bonus bars, the relics over Tlaloc, the spirit lane's
	for lamp: AnimatedSprite2D in features._top_lamps + features._bottom_lamps + features._bars:
		_lamp(lamp, Color(1.0, 0.85, 0.35), 1)
	for lamp: AnimatedSprite2D in features.journey._relic_lamps:
		_lamp(lamp, Color(1.0, 0.8, 0.3), 4)
	for lamp: AnimatedSprite2D in features.spirit_lane._lamps:
		_lamp(lamp, Color(0.4, 0.9, 1.0), 1)
	for frog: AnimatedSprite2D in features.kickback.frogs:
		_lamp(frog, Color(0.4, 1.0, 0.6), 1)  # awake (or leaping): its jade glows
	for eye: Sprite2D in features._face_eyes:
		_eye_lights.append(_light(eye.global_position, EYE_YELLOW, 0.8, EYE_SIZE))
	_gutter_sparks()

func _lamp(sprite: AnimatedSprite2D, colour: Color, lit_from: int) -> void:
	_lamp_lights.append([sprite, _light(sprite.global_position, colour, 0.75, LAMP_SIZE), lit_from])

# Lava down in the drain: sparks spit up out of it and wink out
func _gutter_sparks() -> void:
	var spark := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	spark.fill(Color.WHITE)
	var sparks := CPUParticles2D.new()
	sparks.texture = ImageTexture.create_from_image(spark)
	sparks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sparks.amount = 16
	sparks.lifetime = 1.0
	sparks.position = GUTTER_AT
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(GUTTER_WIDTH * 0.5, 4)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 25.0
	sparks.initial_velocity_min = 25.0
	sparks.initial_velocity_max = 65.0
	sparks.gravity = Vector2(0, 90)
	sparks.scale_amount_min = ART_PIXEL
	sparks.scale_amount_max = ART_PIXEL
	var heat := Gradient.new()
	heat.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	heat.colors = PackedColorArray([Color(1.0, 0.95, 0.5), Color(1.0, 0.55, 0.1), Color(0.9, 0.15, 0.05), Color(0.6, 0.05, 0.0, 0.0)])
	sparks.color_ramp = heat
	sparks.z_index = 2
	sparks.z_as_relative = false
	features.add_child(sparks)

# A light's pool, drawn in the table's own chunky pixels: a few flat rings, brightest in
# the middle, one texel to an art pixel (so it's built to each light's size)
const BAND_EDGES := [0.5, 1.0]
const BAND_ALPHA := [1.0, 0.42]
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

# A flat band of light in the same chunky pixels: two nested rectangles, the inner brighter
func _pixel_band(size: Vector2) -> ImageTexture:
	var texels := Vector2i((size / ART_PIXEL).round())
	var image := Image.create(texels.x, texels.y, false, Image.FORMAT_RGBA8)
	for y in texels.y:
		for x in texels.x:
			var edge := minf(minf(x + 0.5, texels.x - x - 0.5) / (texels.x * 0.5), minf(y + 0.5, texels.y - y - 0.5) / (texels.y * 0.5))
			image.set_pixel(x, y, Color(1, 1, 1, BAND_ALPHA[0] if edge > 0.5 else BAND_ALPHA[1]))
	image.resize(texels.x * POOL_BLOCK, texels.y * POOL_BLOCK, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

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
		var waver := sin(_clock * FLICKER_RATES.x + i * 1.7) * 0.5 + sin(_clock * FLICKER_RATES.y + i * 3.1) * 0.5
		_torch_lights[i].energy = TORCH_BLAZE * (1.0 + FLICKER * waver)
		_torch_lights[i].texture_scale = _torch_sizes[i] * (1.0 + FLICKER_SIZE * waver)
	_whirl_light.visible = features.temple._whirl.visible
	# the sky light drifts after the ball, a dim spot following it about the table
	var camera := get_viewport().get_camera_2d()
	var followed: Variant = camera.get("_followed") if camera else null
	if is_instance_valid(followed):
		_sky_light.global_position = _sky_light.global_position.lerp((followed as Node2D).global_position, minf(SKY_FOLLOW * delta, 1.0))
	var pulse := sin(_clock / GUTTER_PULSE_SECONDS * TAU)
	_gutter_light.energy = GUTTER * (0.8 + 0.2 * pulse)
	_gutter_light.texture_scale = _gutter_size * (1.0 + GUTTER_SWELL * pulse)
	_gutter_glow.scale = Vector2.ONE * _gutter_light.texture_scale
	_gutter_glow.modulate.a = GUTTER_GLOW.a * (0.75 + 0.25 * pulse)
	for pair: Array in _lamp_lights:
		var lamp: AnimatedSprite2D = pair[0]
		(pair[1] as PointLight2D).visible = lamp.is_visible_in_tree() and lamp.frame >= pair[2]
	for i in _eye_lights.size():
		var eye: Sprite2D = features._face_eyes[i]
		_eye_lights[i].global_position = eye.global_position
		_eye_lights[i].color = EYE_RED if eye.frame == 1 else EYE_YELLOW
		_eye_lights[i].energy = 0.8 + 0.15 * sin(_clock * 3.0)
	for pair: Array in _button_lights:
		(pair[1] as PointLight2D).visible = (pair[0] as AnimatedSprite2D).visible
