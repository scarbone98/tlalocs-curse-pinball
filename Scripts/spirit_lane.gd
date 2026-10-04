extends Node2D
## The right lane, running up under the right rail beside the wall: three stone lamps set
## in its floor (Sprites/table/spirit_lamp.png), and up at the top, under the palm, a red
## spinner (the hand-drawn flipper plate as drawn, like the left lane's blue ones). Each
## ball that gets up the lane past the spinner sets it turning and lights the next lamp;
## with all three lit the crystal skull opens its jaws (Scripts/crystal_skull.gd), and a
## ball it takes then calls up a water spirit to catch (Scripts/spirit_capture.gd); with
## Summon arrows lit on the right rail it may be a rare one. The lamps go dark again if
## the lane goes unshot for a while (unless they've readied the skull).

const LAMP := preload("res://Sprites/table/spirit_lamp.png")  # tools/make_table.py: dark, lit
const LAMPS_AT := [Vector2(584, 738), Vector2(596, 702), Vector2(607, 666)]  # bottom to top, along the lane's slant (scene units)
const SPINNER := preload("res://Sprites/table/red_flipper.png")  # tools/make_table.py
const SPINNER_AT := Vector2(608, 492)  # up the lane, just under the palm
const SENSOR_SIZE := Vector2(52, 14)   # the full width of the lane there
const SPIN_FRAMES := 15
const TURNS_PER_SPEED := 1.0 / 150.0   # as the blue ones (Scripts/spinner.gd)
const MAX_TURNS_PER_SECOND := 14.0
const FRICTION := 1.2
const TURN_POINTS := 100
const PASS_COOLDOWN := 1.0
const FADE_SECONDS := 40.0  # unshot this long, the lamps go dark
const LAMP_POINTS := 1000
const SUMMON_POINTS := 5000

var features: Node2D  # TableFeatures

var _lamps: Array[AnimatedSprite2D] = []
var spirit_ready := false  # all three lit: the skull's open for the spirit
var _lit := 0
var _cooldown := 0.0
var _since := 0.0
var _flash_left := 0.0
var _clock := 0.0
var _spinner: AnimatedSprite2D
var _rate := 0.0    # turns per second
var _turned := 0.0
var _scored := 0

func _ready() -> void:
	features.spirit_lane = self
	for at in LAMPS_AT:
		_lamps.append(features._sprite(LAMP, 2, at))
	_spinner = features._sprite(SPINNER, SPIN_FRAMES, SPINNER_AT)
	_spinner.z_index = 2  # the ball (z 1) passes under it, the palm's leaves over both
	_spinner.z_as_relative = false
	var sensor := Area2D.new()
	sensor.position = SPINNER_AT
	sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SENSOR_SIZE
	shape.shape = rect
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_pass)
	add_child(sensor)
	_render()

func _on_pass(body: Node) -> void:
	if not features._is_ball_on_playfield(body):
		return
	var velocity := (body as RigidBody2D).linear_velocity
	_rate = maxf(_rate, minf(absf(velocity.y) * TURNS_PER_SPEED, MAX_TURNS_PER_SECOND))  # it spins either way
	if _cooldown > 0.0 or velocity.y >= 0.0:
		return  # only a ball heading up the lane lights a lamp
	_cooldown = PASS_COOLDOWN
	_since = 0.0
	_lit = mini(_lit + 1, _lamps.size())
	features._award(LAMP_POINTS, LAMPS_AT[_lit - 1])
	AudioSfx.play("spinner", 0.0, Vector2.ONE * (1.2 + 0.15 * _lit))
	_render()
	if _lit == _lamps.size() and not spirit_ready:
		spirit_ready = true
		features._award(SUMMON_POINTS, LAMPS_AT[1])
		_flash_left = 1.2

## The skull took the ball: the spirit rises, and the lamps start again. True if it may be rare.
func take() -> bool:
	spirit_ready = false
	_lit = 0
	_render()
	return features.ramps.arrows["summon"] >= features.ramps.MAX_ARROWS

func _physics_process(delta: float) -> void:
	_clock += delta
	if _rate > 0.0:
		_turned += _rate * delta
		_rate = maxf(_rate - FRICTION * delta, 0.0)
		_spinner.frame = int(fposmod(_turned, 1.0) * SPIN_FRAMES) % SPIN_FRAMES
		while _scored < int(_turned):
			_scored += 1
			PinballEvents.add_score.emit(TURN_POINTS)
			AudioSfx.play("spinner", 0.0, Vector2.ONE * 0.9)
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since += delta
	if _lit > 0 and not spirit_ready and _since >= FADE_SECONDS:
		_lit = 0
		_render()
	if _flash_left > 0.0:
		_flash_left -= delta
		var on := int(_clock * 10.0) % 2 == 0
		for lamp in _lamps:
			lamp.frame = 1 if on and _flash_left > 0.0 else 0
		if _flash_left <= 0.0:
			_render()

func _render() -> void:
	for i in _lamps.size():
		_lamps[i].frame = 1 if i < _lit else 0
