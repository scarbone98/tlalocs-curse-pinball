extends Node2D
## The temple's mood: the whole table sits in a cool dusk (TableFeatures' CanvasModulate,
## darker still in Tlaloc's storm), lit by the things that burn and glow in it. Each torch
## throws a warm, flickering pool of light (bright while it blazes, low on embers), the
## golden temple glows, Tlaloc's whirl casts violet while his mouth is open, a lit gold
## button glows, and a faint light rides with the ball so it never gets lost in the dark.
## The pools are banded, a few flat rings rather than a smooth fade, to sit with the pixel art.

const MOOD := Color(0.56, 0.54, 0.68)   # dusk over the table
const STORM := Color(0.42, 0.45, 0.62)  # darker and bluer while the curse rains
const TORCH_COLOUR := Color(1.0, 0.62, 0.3)
const TORCH_SIZE := 1.3
const TORCH_BLAZE := 1.15
const TORCH_EMBER := 0.45
const FLICKER := 0.18            # how much a flame's light wavers
const FLAME_ABOVE := Vector2(0, -22)  # the flame sits above a torch's centre (Scripts/torches.gd)
const TEMPLE_AT := Vector2(588, 170)
const BALL_LIGHT := 0.5

var features: Node2D  # TableFeatures

var _pool: GradientTexture2D
var _torch_lights: Array[PointLight2D] = []
var _ball_lights := {}  # ball -> PointLight2D
var _whirl_light: PointLight2D
var _button_lights: Array = []  # [sprite, light]
var _clock := 0.0

func _ready() -> void:
	_pool = _banded_pool()
	features._storm_tint.color = MOOD
	for torch: AnimatedSprite2D in features._torches:
		var light := _light(torch.position + FLAME_ABOVE, TORCH_COLOUR, TORCH_EMBER, TORCH_SIZE)
		_torch_lights.append(light)
	_light(TEMPLE_AT, Color(1.0, 0.8, 0.4), 0.55, 2.6)
	_whirl_light = _light(features.temple.AT, Color(0.85, 0.45, 1.0), 0.9, 1.4)
	for sprite: AnimatedSprite2D in [features.idol_tower._button, features.journey._button_sprite]:
		_button_lights.append([sprite, _light(sprite.position, Color(1.0, 0.85, 0.4), 0.7, 0.6)])

# A light's pool: a few flat rings, brightest in the middle
func _banded_pool() -> GradientTexture2D:
	var bands := Gradient.new()
	bands.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	bands.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	bands.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.66), Color(1, 1, 1, 0.38), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = bands
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture

func _light(at: Vector2, colour: Color, energy: float, size: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _pool
	light.texture_scale = size
	light.color = colour
	light.energy = energy
	light.position = at
	features.add_child(light)
	return light

func _process(delta: float) -> void:
	_clock += delta
	for i in _torch_lights.size():
		var torch: AnimatedSprite2D = features._torches[i]
		var base := TORCH_BLAZE if torch.animation == &"blaze" else TORCH_EMBER
		var waver := sin(_clock * 11.0 + i * 1.7) * 0.5 + sin(_clock * 23.0 + i * 3.1) * 0.5
		_torch_lights[i].energy = base * (1.0 + FLICKER * waver)
	_whirl_light.visible = features.temple._whirl.visible
	for pair: Array in _button_lights:
		(pair[1] as PointLight2D).visible = (pair[0] as AnimatedSprite2D).visible
	# a faint light rides with every ball in play
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as Node2D
		if not _ball_lights.has(ball):
			_ball_lights[ball] = _light(ball.global_position, Color(1.0, 0.95, 0.85), BALL_LIGHT, 0.5)
		(_ball_lights[ball] as PointLight2D).global_position = ball.global_position
	for ball in _ball_lights.keys():
		if not is_instance_valid(ball):
			(_ball_lights[ball] as PointLight2D).queue_free()
			_ball_lights.erase(ball)
