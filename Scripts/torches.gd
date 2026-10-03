extends Node2D
## The six torches lining the left lane in two rows (the hand-drawn torch.png, placed as
## in Sprites/exampleLayout.png), with a stone button (torchbutton.png) set in the lane
## between each pair. Unlit they only smoulder. A ball rolling down the lane presses the
## buttons as it goes, and the first unlit pair it passes catches with a flare (one pair a
## trip down the lane), then burns for a while before dying back. Light all six before any goes out and the torches
## blaze up and hold a ball saver for a while, like Pokemon Pinball's Pikachu saver:
## drain in that time and the ball comes back. When it runs out they die back to embers.

const TORCH := preload("res://Sprites/table/torch.png")
const BUTTON := preload("res://Sprites/table/torch_button.png")  # tools/make_table.py

# Scene positions of the torches, in pairs across the lane, top pair first
const PAIRS := [
	[Vector2(123.8, 673.2), Vector2(61.9, 724.5)],
	[Vector2(157.5, 730.6), Vector2(98.4, 784.9)],
	[Vector2(188.4, 778.9), Vector2(126.6, 833.2)],
]
# Torches that just burn, for the look of the place: on the side walls, by the outlanes,
# beside the stone face (scene units)
const DECOR := [Vector2(40, 870), Vector2(612, 858), Vector2(40, 1135), Vector2(632, 1105), Vector2(165, 105), Vector2(35, 300)]
# The stone buttons in the lane, one per pair (scene units, from the layout mock-up)
const BUTTONS := [Vector2(84.4, 715.5), Vector2(112.5, 772.8), Vector2(143.4, 824.2)]
const BUTTON_RADIUS := 22.0
const PRESSED_SECONDS := 0.35
enum { BUTTON_UP, BUTTON_DOWN }
const FRAME := Vector2(16, 24)  # Sprites/table/torch.png: six burning frames, then six embers
const FLAME_TOP := Vector2(0, -22)  # where the flame leaps from, above the torch's centre
const PASS_COOLDOWN := 0.8
const TRIP_SECONDS := 1.2  # one trip down the lane lights one pair, however many buttons it rolls over
const LIGHT_POINTS := 500
const RELIGHT_POINTS := 250
const ABLAZE_POINTS := 10000
const SAVER_SECONDS := 15.0
const BURN_SECONDS := 12.0  # a lit pair dies back to embers unless all six get lit
const REST_SECONDS := 30.0  # after the saver, the torches won't catch again for a while

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _torches: Array = []  # per pair: [AnimatedSprite2D, AnimatedSprite2D]
var _lit := [false, false, false]
var _burn_left := [0.0, 0.0, 0.0]
var _cooldown := [0.0, 0.0, 0.0]
var _buttons: Array[AnimatedSprite2D] = []
var _trip_left := 0.0
var _ablaze_left := 0.0
var _rest_left := 0.0

func _ready() -> void:
	var frames := SpriteFrames.new()
	for anim in [[&"blaze", 0], [&"ember", 6]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], 10.0)
		for i in 6:
			var atlas := AtlasTexture.new()
			atlas.atlas = TORCH
			atlas.region = Rect2(Vector2((anim[1] + i) * FRAME.x, 0), FRAME)
			frames.add_frame(anim[0], atlas)
	for pair in PAIRS:
		var both := []
		for at in pair:
			var torch := AnimatedSprite2D.new()
			torch.sprite_frames = frames
			torch.position = at
			torch.scale = features.MAP_SCALE
			torch.play(&"ember")
			torch.frame = randi() % 6
			features.add_child(torch)
			features._torches.append(torch)  # the curse makes them flicker faster
			both.append(torch)
		_torches.append(both)
	for at in DECOR:
		var torch := AnimatedSprite2D.new()
		torch.sprite_frames = frames
		torch.position = at
		torch.scale = features.MAP_SCALE
		torch.play(&"blaze")
		torch.frame = randi() % 6
		features.add_child(torch)
		features._torches.append(torch)  # lit like the others (Scripts/lighting.gd), and the curse quickens them

	for i in BUTTONS.size():
		var button: AnimatedSprite2D = features._sprite(BUTTON, 2, BUTTONS[i])
		features.move_child(button, 0)  # under the torches, as in the layout
		_buttons.append(button)
		var sensor := Area2D.new()
		sensor.position = BUTTONS[i]
		sensor.monitorable = false
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = BUTTON_RADIUS
		shape.shape = circle
		sensor.add_child(shape)
		sensor.body_entered.connect(_on_button.bind(i))
		add_child(sensor)

func _physics_process(delta: float) -> void:
	_rest_left = maxf(_rest_left - delta, 0.0)
	_trip_left = maxf(_trip_left - delta, 0.0)
	for i in _cooldown.size():
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
	for i in _lit.size():
		if _lit[i] and _ablaze_left <= 0.0:
			_burn_left[i] -= delta
			if _burn_left[i] <= 0.0:
				_lit[i] = false
				_play(i, &"ember")
	if _ablaze_left > 0.0:
		_ablaze_left -= delta
		# they die back when the saver runs out, or as soon as it has saved a ball
		if _ablaze_left <= 0.0 or GameManager.ball_save_left() <= 0.0:
			_ablaze_left = 0.0
			_rest_left = REST_SECONDS
			_lit = [false, false, false]
			for i in _lit.size():
				_play(i, &"ember")

func _play(pair: int, anim: StringName) -> void:
	for torch in _torches[pair]:
		torch.play(anim)

func _on_button(body: Node, next: int) -> void:
	if _cooldown[next] > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown[next] = PASS_COOLDOWN
	_buttons[next].frame = BUTTON_DOWN
	get_tree().create_timer(PRESSED_SECONDS, false).timeout.connect(func(): _buttons[next].frame = BUTTON_UP)
	AudioSfx.play("spinner", 0.0, Vector2.ONE * 0.6)
	if _rest_left > 0.0 or _ablaze_left > 0.0 or _lit[next] or _trip_left > 0.0:
		_burn_left[next] = BURN_SECONDS if _lit[next] else _burn_left[next]
		features._award(RELIGHT_POINTS, BUTTONS[next])
		return
	_trip_left = TRIP_SECONDS
	_lit[next] = true
	_burn_left[next] = BURN_SECONDS
	for i in _lit.size():
		if _lit[i]:
			_burn_left[i] = BURN_SECONDS  # each new pair stokes the others
	_play(next, &"blaze")
	AudioSfx.play("torch")
	for torch in _torches[next]:
		PinballEvents.effect.emit("fire", torch.position + FLAME_TOP)
		torch.modulate = Color(1.6, 1.4, 1.0)  # a flare as it catches
		create_tween().tween_property(torch, "modulate", Color.WHITE, 0.3)
	features._award(LIGHT_POINTS, BUTTONS[next])
	if not _lit.has(false):
		_ablaze()

func _ablaze() -> void:
	_ablaze_left = SAVER_SECONDS
	features._award(ABLAZE_POINTS, BUTTONS[1])
	GameManager.grant_ball_save(SAVER_SECONDS)
	PinballEvents.toast.emit("Torches ablaze! Ball saver")
	PinballEvents.rumble.emit(4.0)
