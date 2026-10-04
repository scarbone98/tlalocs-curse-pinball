extends Node2D
## The six torches lining the left lane in two rows (the hand-drawn torch.png, placed as
## in Sprites/exampleLayout.png), with three stone buttons (torchbutton.png) set along the
## lane between them. Unlit they only smoulder and throw no light. Roll over all three
## buttons in order going up the lane, bottom to top, each soon after the last, and the
## next pair up catches with a flare, then burns for a while before dying back. Light all six before any goes out and the torches
## blaze up and hold a ball saver for a while, like Pokemon Pinball's Pikachu saver:
## drain in that time and the ball comes back. When it runs out they die back to embers.
## Up past the lane's top palm is a fourth button, a flame on it: with every torch lit, run
## up over all three stone buttons and on over it soon after, and it's an Inferno - the
## torches flare, a ball saver, and the ball goes about trailing fire for a while.

const TORCH := preload("res://Sprites/table/torch.png")
const BUTTON := preload("res://Sprites/table/torch_button.png")  # tools/make_table.py

# Scene positions of the torches, in pairs across the lane, top pair first
const PAIRS := [  # moved up the lane to make room for the dart trap at its foot
	[Vector2(105.6, 637.6), Vector2(43.7, 688.9)],
	[Vector2(131.4, 679.4), Vector2(72.3, 733.7)],
	[Vector2(154.3, 712.1), Vector2(92.5, 766.4)],
]
# Torches that just burn, for the look of the place: on the side walls, by the outlanes,
# beside the stone face (scene units)
const DECOR := [Vector2(40, 870), Vector2(612, 858), Vector2(40, 1135), Vector2(632, 1105), Vector2(165, 105), Vector2(35, 300), Vector2(548, 378)]  # ...and one above the skull's palms
# The stone buttons in the lane, one per pair (scene units, from the layout mock-up)
const BUTTONS := [Vector2(71.0, 658.4), Vector2(86.4, 721.6), Vector2(117.9, 784.2)]  # top to bottom, spread along the lane
const SEQUENCE_GAP := 1.5  # each button in the run up the lane must follow the last within this
const FIRE_BUTTON := preload("res://Sprites/table/fire_button.png")  # tools/make_table.py
const FIRE_AT := Vector2(198, 286)  # up past the lane's top palm, below the wall's shadow where the lane bends over the top
const FIRE_WINDOW := 2.0      # after a run up the three, the fire button must come within this
const FIRE_POINTS := 100
const INFERNO_POINTS := 30000
const INFERNO_SECONDS := 20.0  # the ball saver, and the fire trailing off the ball
const INFERNO_REST := 30.0
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
var _expect := 2         # the button the run up the lane needs next: bottom (2), then 1, then top (0)
var _since_press := 0.0
var _ablaze_left := 0.0
var _fire_button: AnimatedSprite2D
var _fire_cooldown := 0.0
var _run_done_left := 0.0  # a run up the three just finished: the fire button's open this long
var _inferno_left := 0.0
var _inferno_rest := 0.0
var _trails := {}  # ball -> the fire trailing off it
var _rest_left := 0.0

## Every torch burning (all three pairs lit, or the blaze after): the dart trap's darts
## come down flaming (Scripts/dart_trap.gd)
func all_lit() -> bool:
	return _ablaze_left > 0.0 or not _lit.has(false)

func _ready() -> void:
	features.torch_lane = self
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
	_fire_button = features._sprite(FIRE_BUTTON, 2, FIRE_AT)
	_fire_button.flip_h = true  # lying along the lane where it bends up and to the right
	features.move_child(_fire_button, 0)
	var fire_sensor := Area2D.new()
	fire_sensor.position = FIRE_AT
	fire_sensor.monitorable = false
	var fire_shape := CollisionShape2D.new()
	var fire_circle := CircleShape2D.new()
	fire_circle.radius = BUTTON_RADIUS
	fire_shape.shape = fire_circle
	fire_sensor.add_child(fire_shape)
	fire_sensor.body_entered.connect(_on_fire_button)
	add_child(fire_sensor)

func _on_fire_button(body: Node) -> void:
	if _fire_cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	_fire_cooldown = PASS_COOLDOWN
	_fire_button.frame = BUTTON_DOWN
	get_tree().create_timer(PRESSED_SECONDS, false).timeout.connect(func(): _fire_button.frame = BUTTON_UP)
	AudioSfx.play("spinner", 0.0, Vector2.ONE * 1.2)
	if _run_done_left > 0.0 and all_lit() and _inferno_rest <= 0.0:
		_inferno()
	else:
		features._award(FIRE_POINTS, FIRE_AT)

# Inferno: every torch flares, a ball saver, and each ball goes about trailing fire
func _inferno() -> void:
	_run_done_left = 0.0
	_inferno_left = INFERNO_SECONDS
	_inferno_rest = INFERNO_REST + INFERNO_SECONDS
	features._award(INFERNO_POINTS, FIRE_AT)
	GameManager.grant_ball_save(INFERNO_SECONDS)
	PinballEvents.toast.emit("Inferno!")
	PinballEvents.rumble.emit(6.0)
	AudioSfx.play("torch")
	PinballEvents.effect.emit("fire", FIRE_AT)
	for torch: AnimatedSprite2D in features._torches:
		PinballEvents.effect.emit("fire", torch.position + FLAME_TOP)
		torch.modulate = Color(1.7, 1.4, 1.0)
		create_tween().tween_property(torch, "modulate", Color.WHITE, 0.6)

func _trail() -> CPUParticles2D:
	var dot := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var fire := CPUParticles2D.new()
	fire.texture = ImageTexture.create_from_image(dot)
	fire.amount = 24
	fire.lifetime = 0.45
	fire.local_coords = false
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 10.0
	fire.direction = Vector2(0, -1)
	fire.spread = 30.0
	fire.initial_velocity_min = 20.0
	fire.initial_velocity_max = 50.0
	fire.gravity = Vector2(0, -40)
	fire.scale_amount_min = 2.9
	fire.scale_amount_max = 2.9
	var burn := Gradient.new()
	burn.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	burn.colors = PackedColorArray([Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.1), Color(0.6, 0.1, 0.0, 0.0)])
	fire.color_ramp = burn
	fire.z_index = 4
	fire.z_as_relative = false
	return fire

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_run_done_left = maxf(_run_done_left - delta, 0.0)
	_inferno_rest = maxf(_inferno_rest - delta, 0.0)
	# the fire trailing off each ball through an Inferno
	_inferno_left = maxf(_inferno_left - delta, 0.0)
	for ball in _trails.keys():
		if not is_instance_valid(ball) or _inferno_left <= 0.0:
			if is_instance_valid(_trails[ball]):
				_trails[ball].queue_free()
			_trails.erase(ball)
	if _inferno_left > 0.0:
		for ball in get_tree().get_nodes_in_group("ball"):
			if not _trails.has(ball):
				var fire := _trail()
				features.add_child(fire)
				_trails[ball] = fire
			(_trails[ball] as Node2D).global_position = (ball as Node2D).global_position
	_rest_left = maxf(_rest_left - delta, 0.0)
	_trip_left = maxf(_trip_left - delta, 0.0)
	_since_press += delta
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

func _on_button(body: Node, button: int) -> void:
	if _cooldown[button] > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown[button] = PASS_COOLDOWN
	_buttons[button].frame = BUTTON_DOWN
	get_tree().create_timer(PRESSED_SECONDS, false).timeout.connect(func(): _buttons[button].frame = BUTTON_UP)
	# the run up the lane: bottom, middle, top, each soon after the last
	var in_time := _since_press <= SEQUENCE_GAP
	_since_press = 0.0
	if button == _expect and (button == BUTTONS.size() - 1 or in_time):
		_expect -= 1
	else:
		_expect = BUTTONS.size() - 2 if button == BUTTONS.size() - 1 else BUTTONS.size() - 1
	AudioSfx.play("spinner", 0.0, Vector2.ONE * (0.6 + 0.15 * (BUTTONS.size() - 1 - button)))
	if _expect >= 0:
		return  # not up the whole lane yet
	_expect = BUTTONS.size() - 1
	_run_done_left = FIRE_WINDOW  # on over the fire button now, with every torch lit, for an Inferno
	# the next unlit pair up the lane catches
	var next := -1
	for pair in range(_lit.size() - 1, -1, -1):
		if not _lit[pair]:
			next = pair
			break
	if next < 0 or _rest_left > 0.0 or _ablaze_left > 0.0 or _trip_left > 0.0:
		for pair in _lit.size():
			if _lit[pair]:
				_burn_left[pair] = BURN_SECONDS
		features._award(RELIGHT_POINTS, BUTTONS[button])
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
