extends Node2D
## The three temple torches on the wall peaks. Unlit they only smoulder; knocking the
## ball into a peak lights its torch with a flare, and it burns for a while before
## dying back. Light all three before any goes out and the torches blaze
## up and hold a ball saver for a while, like Pokemon Pinball's Pikachu saver: drain in
## that time and the ball comes back. When it runs out they die back to embers.

const TORCH := preload("res://Sprites/table/torch.png")

# Scene positions of the painted lamps on the peaks (measured from Sprites/map_f1.png)
const AT := [Vector2(319, 549), Vector2(442, 642), Vector2(208, 815)]
const SENSOR_RADIUS := 14.0  # the ball has to strike the peak, not just pass by
const FRAME := Vector2(9, 12)  # Sprites/table/torch.png: four blazing frames, then four embers
const HIT_COOLDOWN := 0.6
const LIGHT_POINTS := 500
const RELIGHT_POINTS := 250
const ABLAZE_POINTS := 10000
const SAVER_SECONDS := 15.0
const BURN_SECONDS := 10.0  # a lit torch dies back to embers unless all three get lit
const REST_SECONDS := 30.0  # after the saver, the torches won't catch again for a while

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _torches: Array[AnimatedSprite2D] = []
var _lit := [false, false, false]
var _cooldown := [0.0, 0.0, 0.0]
var _burn_left := [0.0, 0.0, 0.0]
var _ablaze_left := 0.0
var _rest_left := 0.0

func _ready() -> void:
	var frames := SpriteFrames.new()
	for anim in [[&"blaze", 0], [&"ember", 4]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], 8.0)
		for i in 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = TORCH
			atlas.region = Rect2(Vector2((anim[1] + i) * FRAME.x, 0), FRAME)
			frames.add_frame(anim[0], atlas)
	for i in AT.size():
		var torch := AnimatedSprite2D.new()
		torch.sprite_frames = frames
		torch.position = AT[i]
		torch.scale = features.MAP_SCALE
		torch.offset = Vector2(0, -4)  # the flame's base sits on the painted lamp
		torch.play(&"ember")
		torch.frame = randi() % 4
		features.add_child(torch)
		features._torches.append(torch)  # the curse makes them flicker faster
		_torches.append(torch)

		var sensor := Area2D.new()
		sensor.position = AT[i]
		sensor.monitorable = false
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = SENSOR_RADIUS
		shape.shape = circle
		sensor.add_child(shape)
		sensor.body_entered.connect(_on_hit.bind(i))
		add_child(sensor)

func _physics_process(delta: float) -> void:
	_rest_left = maxf(_rest_left - delta, 0.0)
	for i in _cooldown.size():
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
		if _lit[i] and _ablaze_left <= 0.0:
			_burn_left[i] -= delta
			if _burn_left[i] <= 0.0:
				_lit[i] = false
				_torches[i].play(&"ember")
	if _ablaze_left > 0.0:
		_ablaze_left -= delta
		# they die back when the saver runs out, or as soon as it has saved a ball
		if _ablaze_left <= 0.0 or GameManager.ball_save_left() <= 0.0:
			_ablaze_left = 0.0
			_rest_left = REST_SECONDS
			_lit = [false, false, false]
			for torch in _torches:
				torch.play(&"ember")

func _on_hit(body: Node, index: int) -> void:
	if _cooldown[index] > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown[index] = HIT_COOLDOWN
	var torch := _torches[index]
	PinballEvents.effect.emit("fire", AT[index] + Vector2(0, -12))
	AudioSfx.play("torch")
	# a flare as it catches (or roars again, if it's already alight)
	var flare := create_tween()
	flare.tween_property(torch, "scale", features.MAP_SCALE * 1.4, 0.08)
	flare.tween_property(torch, "scale", features.MAP_SCALE, 0.25)
	if _rest_left > 0.0:
		features._award(RELIGHT_POINTS, AT[index])
		return  # still smouldering from the last blaze
	if _lit[index] or _ablaze_left > 0.0:
		_burn_left[index] = BURN_SECONDS  # stoked, it burns a while longer
		features._award(RELIGHT_POINTS, AT[index])
		return
	_lit[index] = true
	_burn_left[index] = BURN_SECONDS
	torch.play(&"blaze")
	features._award(LIGHT_POINTS, AT[index])
	if not _lit.has(false):
		_ablaze()

func _ablaze() -> void:
	_ablaze_left = SAVER_SECONDS
	features._award(ABLAZE_POINTS, AT[0])
	GameManager.grant_ball_save(SAVER_SECONDS)
	PinballEvents.toast.emit("Torches ablaze! Ball saver")
	PinballEvents.rumble.emit(4.0)
	for at in AT:
		PinballEvents.effect.emit("fire", at + Vector2(0, -12))
