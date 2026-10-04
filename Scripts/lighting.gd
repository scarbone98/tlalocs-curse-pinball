extends Node2D
## The temple's mood: the whole table sits in a cool dusk (TableFeatures' CanvasModulate,
## darker still in Tlaloc's storm), lit by the things that burn and glow in it. Each torch
## throws a warm, flickering pool of light while it burns (none on embers), the
## golden temple glows, Tlaloc's whirl casts violet while his mouth is open, and a lit gold
## button glows. A wide, dim sky light falls over the arena, lamps set in the floor glow
## while they're lit, Tlaloc's eyes glow (red in his storm), and the lava in the drain
## (the hand-drawn lava layer) glows and flickers. The pools are pixel art too: two flat rings, in
## texels the size of the table's pixels, and a flame's pool swells and shrinks as it flickers.

const MOOD := Color(0.56, 0.54, 0.68)   # dusk over the table
const STORM := Color(0.42, 0.45, 0.62)  # darker and bluer while the curse rains
const TORCH_COLOUR := Color(1.0, 0.62, 0.3)
const TORCH_SIZE := 1.3
const TORCH_BLAZE := 0.7
const FLICKER_RATES := Vector2(3.2, 6.9)  # the two slow waves a flame's light wavers on (radians/s)
const FLICKER := 0.18            # how much a flame's light wavers
const FLICKER_SIZE := 0.06       # ...and how much its pool swells and shrinks
const BUTTON_GLOW := 0.7
const BUTTON_FLICKER := 0.08       # the gold buttons' glow breathes like a torch's, more subtly
const BUTTON_FLICKER_SIZE := 0.03
const FLAME_ABOVE := Vector2(0, -22)  # the flame sits above a torch's centre (Scripts/torches.gd)
const TEMPLE_AT := Vector2(588, 170)
# A wide, dim pool of sky light, drifting after the ball (it starts over the arena)
const SKY_AT := Vector2(390, 450)
const SKY_COLOUR := Color(0.75, 0.82, 1.0)
const SKY := 0.38
const SKY_SIZE := 4.4
const SKY_FOLLOW := 9.0  # how quickly it drifts after the ball: just a little lag
# The lava in the drain (tools/make_table.py, from the hand-drawn lava.png): its glow
# breathing slowly, its embers and edge flickering
const LAVA_GLOW := preload("res://Sprites/table/lava_glow.png")
const LAVA_EMBERS := preload("res://Sprites/table/lava_embers.png")
const LAVA_EMBERS_AT := Vector2(121, 406.5)  # the middle of the embers' box (art pixels)
const LAVA_BREATH_SECONDS := 2.6
# The crystal skull gleams as the spotlight passes over it, its glints sliding toward the light
const SKULL_SHINE := preload("res://Sprites/table/skull_shine.png")  # tools/make_table.py
const SHINE_REACH := 190.0  # how near the spotlight has to be for the skull to catch it
const SKULL_SHIMMER := preload("res://Sprites/table/skull_shimmer.png")  # tools/make_table.py
const SHIMMER_FRAMES := 6
const SHIMMER_FPS := 14.0
const SHIMMER_REACH := 150.0  # the spotlight coming within this of the skull, or leaving, sets it shimmering
const LAMP_SIZE := 0.45
const EYE_SIZE := 0.3
const IDOL_SPOT_SIZE := 1.15  # a spotlight on the golden idol, taking in its spinning tower
const IDOL_SPOT_BELOW := 46.0  # scene units below the idol its middle falls: on the tower
const IDOL_GLOW := 1.0
const SKULL_SPOT_SIZE := 0.9  # a spotlight on the crystal skull while its jaws are open
const SKULL_GLOW := 0.9
const SPOT_BREATH_SECONDS := 3.2  # the idol's and skull's spots breathe this slowly...
const SPOT_BREATH := 0.18         # ...brightening and dimming this much
const SPOT_BREATH_SIZE := 0.08    # ...and swelling and shrinking this much
const EYE_YELLOW := Color(1.0, 0.9, 0.3)
const EYE_RED := Color(1.0, 0.15, 0.1)

var features: Node2D  # TableFeatures

var _pools := {}  # size -> its pixel pool
var _torch_lights: Array[PointLight2D] = []
var _whirl_light: PointLight2D
var _sky_light: PointLight2D
var _lava_glow: Sprite2D
var _sacrifice_light: PointLight2D
var _idol_light: PointLight2D
var _skull_light: PointLight2D
var _idol_spot_scale := 1.0
var _skull_spot_scale := 1.0
var _skull_shine: Sprite2D
var _skull_shimmer: Sprite2D
var _spot_on_skull := false
var _shimmer_time := -1.0  # how far through its shimmer the skull is (negative: not shimmering)
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
	_lava()
	_skull_shine = _shine_on(features.skull._sprite)
	_skull_shimmer = _shine_on(features.skull._sprite)
	_skull_shimmer.texture = SKULL_SHIMMER
	_skull_shimmer.hframes = SHIMMER_FRAMES
	_skull_shimmer.vframes = 2
	_skull_shimmer.hide()
	_sacrifice_light = _light(Vector2.ZERO, Color(1.0, 0.72, 0.4), 0.95, 0.85)  # a warm spot on the sacrifice
	_idol_light = _light(Vector2.ZERO, Color(1.0, 0.86, 0.45), IDOL_GLOW, IDOL_SPOT_SIZE)  # a spot on the golden idol
	_skull_light = _light(features.skull._sprite.global_position, Color(0.6, 0.85, 1.0), SKULL_GLOW, SKULL_SPOT_SIZE)  # ...and on the skull, open
	_idol_spot_scale = _idol_light.texture_scale
	_skull_spot_scale = _skull_light.texture_scale
	_whirl_light = _light(features.temple.AT, Color(0.85, 0.45, 1.0), 0.9, 1.4)
	for sprite: AnimatedSprite2D in [features.idol_tower._button, features.journey._button_sprite, features.dart_trap.button_sprite]:
		var glow := _light(sprite.position, Color(1.0, 0.85, 0.4), BUTTON_GLOW, 0.6)
		_button_lights.append([sprite, glow, glow.texture_scale])
	# the lamps set in the floor: the lanes', the bonus bars, the relics over Tlaloc, the spirit lane's
	for lamp: AnimatedSprite2D in features._top_lamps + features._bottom_lamps + features._bars:
		_lamp(lamp, Color(1.0, 0.85, 0.35), 1)
	for lamp: AnimatedSprite2D in features.journey._relic_lamps:
		_lamp(lamp, Color(1.0, 0.8, 0.3), 4)
	for lamp: AnimatedSprite2D in features.spirit_lane._lamps:
		_lamp(lamp, Color(0.4, 0.9, 1.0), 1)
	_lamp(features.rails._gem, Color(0.3, 1.0, 0.55), 0)  # the rail emerald glows green while it's there
	for frog: AnimatedSprite2D in features.kickback.frogs:
		_lamp(frog, Color(0.4, 1.0, 0.6), 1)  # awake (or leaping): its jade glows
	for eye: Sprite2D in features._face_eyes:
		_eye_lights.append(_light(eye.global_position, EYE_YELLOW, 0.8, EYE_SIZE))

func _lamp(sprite: AnimatedSprite2D, colour: Color, lit_from: int) -> void:
	_lamp_lights.append([sprite, _light(sprite.global_position, colour, 0.75, LAMP_SIZE), lit_from])

# A layer of glints over the skull, added on top of it, that the spotlight brings out
func _shine_on(skull: AnimatedSprite2D) -> Sprite2D:
	var shine := Sprite2D.new()
	shine.texture = SKULL_SHINE
	shine.hframes = 2
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	shine.material = add
	shine.z_index = skull.z_index
	shine.z_as_relative = false
	shine.modulate.a = 0.0
	skull.add_child(shine)
	shine.scale = Vector2.ONE  # it rides on the skull, which is already at the table's scale
	return shine

# The lava in the drain: drawn as it glows, not dimmed by the dusk
func _lava() -> void:
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_lava_glow = Sprite2D.new()
	_lava_glow.texture = LAVA_GLOW
	_lava_glow.centered = false
	_lava_glow.scale = features.MAP_SCALE
	_lava_glow.material = unshaded
	_lava_glow.z_index = 3  # over the flippers' undersides, which it lights
	_lava_glow.z_as_relative = false
	features.add_child(_lava_glow)
	var embers: AnimatedSprite2D = features._sprite(LAVA_EMBERS, 4, LAVA_EMBERS_AT * features.MAP_SCALE, 6.0)
	embers.material = unshaded
	embers.z_index = 3
	embers.z_as_relative = false
	embers.play()

# A light's pool, drawn in the table's own chunky pixels: two flat rings, brightest in
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
	if is_instance_valid(followed) and not followed.get("in_lava"):  # it stays put once the ball's in the lava
		_sky_light.global_position = _sky_light.global_position.lerp((followed as Node2D).global_position, minf(SKY_FOLLOW * delta, 1.0))
	_lava_glow.modulate.a = 0.8 + 0.2 * sin(_clock / LAVA_BREATH_SECONDS * TAU)
	# the skull gleams as the spotlight passes near it
	var skull: AnimatedSprite2D = features.skull._sprite
	var to_light := _sky_light.global_position - skull.global_position
	_skull_shine.frame = skull.frame
	_skull_shine.offset = skull.offset + Vector2(clampf(to_light.x / 80.0, -1.0, 1.0), clampf(to_light.y / 80.0, -1.0, 1.0)).round()
	_skull_shine.modulate.a = clampf(1.3 - to_light.length() / SHINE_REACH, 0.0, 1.0) * (0.65 + 0.2 * sin(_clock * 5.0))
	# ...and a glint sweeps over it as the spotlight comes onto it, and again as it leaves
	var on_skull := to_light.length() < SHIMMER_REACH
	if on_skull != _spot_on_skull:
		_spot_on_skull = on_skull
		_shimmer_time = 0.0
	if _shimmer_time >= 0.0:
		var step := int(_shimmer_time * SHIMMER_FPS)
		_shimmer_time += delta
		_skull_shimmer.visible = step < SHIMMER_FRAMES
		if step < SHIMMER_FRAMES:
			_skull_shimmer.frame = skull.frame * SHIMMER_FRAMES + step
			_skull_shimmer.offset = skull.offset
		else:
			_shimmer_time = -1.0
	var sacrifice: AnimatedSprite2D = features.sacrifices.current()
	_sacrifice_light.visible = sacrifice.visible and sacrifice.modulate.a > 0.3
	_sacrifice_light.global_position = sacrifice.global_position
	var idol: Sprite2D = features.idol_tower._idol
	_idol_light.visible = idol.visible and not features.idol_tower._claimed
	_idol_light.global_position = features.idol_tower.position + Vector2(idol.position.x, minf(idol.position.y + IDOL_SPOT_BELOW, features.idol_tower.IDOL_ON_FLOOR.y * features.MAP_SCALE.y))
	# the spots breathe: slowly swelling and brightening, then easing back
	var breath := sin(_clock * TAU / SPOT_BREATH_SECONDS)
	_idol_light.energy = IDOL_GLOW * (1.0 + SPOT_BREATH * breath)
	_idol_light.texture_scale = _idol_spot_scale * (1.0 + SPOT_BREATH_SIZE * breath)
	_skull_light.visible = features.skull.lit()  # while its jaws are open
	_skull_light.global_position = features.skull._sprite.global_position
	var skull_breath := sin(_clock * TAU / SPOT_BREATH_SECONDS + PI)  # out of step with the idol's
	_skull_light.energy = SKULL_GLOW * (1.0 + SPOT_BREATH * skull_breath)
	_skull_light.texture_scale = _skull_spot_scale * (1.0 + SPOT_BREATH_SIZE * skull_breath)
	for pair: Array in _lamp_lights:
		var lamp: AnimatedSprite2D = pair[0]
		(pair[1] as PointLight2D).visible = lamp.is_visible_in_tree() and lamp.frame >= pair[2]
	for i in _eye_lights.size():
		var eye: Sprite2D = features._face_eyes[i]
		_eye_lights[i].global_position = eye.global_position
		_eye_lights[i].visible = eye.visible  # not while it's been shot out
		_eye_lights[i].color = EYE_RED if eye.frame == 1 else EYE_YELLOW
		_eye_lights[i].energy = 0.8 + 0.15 * sin(_clock * 3.0)
	for i in _button_lights.size():
		var pair: Array = _button_lights[i]
		var light := pair[1] as PointLight2D
		light.visible = (pair[0] as AnimatedSprite2D).visible
		# they breathe like the torches' light, only gentler
		var waver := sin(_clock * FLICKER_RATES.x * 0.6 + i * 2.3) * 0.5 + sin(_clock * FLICKER_RATES.y * 0.6 + i * 1.1) * 0.5
		light.energy = BUTTON_GLOW * (1.0 + BUTTON_FLICKER * waver)
		light.texture_scale = pair[2] * (1.0 + BUTTON_FLICKER_SIZE * waver)
