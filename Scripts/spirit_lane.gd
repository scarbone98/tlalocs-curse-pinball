extends Node2D
## The right lane, running up under the right rail beside the wall: three stone lamps set
## in its floor (Sprites/table/spirit_lamp.png). Each trip up the lane lights the next one;
## with all three lit a water spirit rises to catch (Scripts/spirit_capture.gd), and with
## Summon arrows lit on the right rail it may be a rare one. The lamps go dark again if
## the lane goes unshot for a while.

const LAMP := preload("res://Sprites/table/spirit_lamp.png")  # tools/make_table.py: dark, lit
const LAMPS_AT := [Vector2(612, 742), Vector2(612, 704), Vector2(612, 666)]  # bottom to top (scene units)
const SENSOR := Rect2(584, 676, 54, 24)  # across the lane, among the lamps
const PASS_COOLDOWN := 1.0
const FADE_SECONDS := 40.0  # unshot this long, the lamps go dark
const LAMP_POINTS := 1000
const SUMMON_POINTS := 5000

var features: Node2D  # TableFeatures

var _lamps: Array[AnimatedSprite2D] = []
var _lit := 0
var _cooldown := 0.0
var _since := 0.0
var _flash_left := 0.0
var _clock := 0.0

func _ready() -> void:
	features.spirit_lane = self
	for at in LAMPS_AT:
		_lamps.append(features._sprite(LAMP, 2, at))
	var sensor := Area2D.new()
	sensor.position = SENSOR.get_center()
	sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SENSOR.size
	shape.shape = rect
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_pass)
	add_child(sensor)
	_render()

func _on_pass(body: Node) -> void:
	if _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	if (body as RigidBody2D).linear_velocity.y >= 0.0:
		return  # only a ball heading up the lane
	_cooldown = PASS_COOLDOWN
	_since = 0.0
	_lit = mini(_lit + 1, _lamps.size())
	features._award(LAMP_POINTS, LAMPS_AT[_lit - 1])
	AudioSfx.play("spinner", 0.0, Vector2.ONE * (1.2 + 0.15 * _lit))
	_render()
	if _lit == _lamps.size() and not features.mode_running():
		var rare: bool = features.ramps.arrows["summon"] >= features.ramps.MAX_ARROWS
		if features.spirit.summon(rare):
			features._award(SUMMON_POINTS, LAMPS_AT[1])
			_flash_left = 1.2
			_lit = 0

func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_since += delta
	if _lit > 0 and _since >= FADE_SECONDS:
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
