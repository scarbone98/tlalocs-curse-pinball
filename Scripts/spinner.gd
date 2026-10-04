extends Node2D
## The three blue flippers stacked up the left lane: the hand-drawn flipper plate
## (tools/source_art/flipper.png, turned blue), each hung across the lane on its axle. A
## ball going through sets each one spinning as fast as the ball was going; they slow
## to a stop, scoring every turn.
##
## As on Pokemon Pinball Ruby & Sapphire, how fast the ball goes up the lane charges the
## kickback (one hard shot can fill it), and the lane pays like Ruby's coin orbit:
## 1000, then 2500, then 5000 a pass as its level climbs, each level fading back down if
## the lane goes unshot for a while.

const FLIPPER := preload("res://Sprites/table/blue_flipper.png")  # tools/make_table.py

const PLATES := [Vector2(164.5, 386), Vector2(164.5, 456), Vector2(170, 525)]  # top to bottom
const SENSOR_SIZE := Vector2(58, 14)  # the full width of the lane, so every ball through it counts
const FRAMES := 15  # one full turn
const TURNS_PER_SPEED := 1.0 / 150.0  # turns per second for each unit of ball speed
const MAX_TURNS_PER_SECOND := 14.0
const FRICTION := 1.2  # turns per second lost each second: they spin down slowly
const TURN_POINTS := 100
const PASS_POINTS := [1000, 2500, 5000]   # a pass at each level
const BEAD_LEVEL_SECONDS := [60.0, 30.0, 15.0]  # how long each level lasts before fading a step
const PASS_COOLDOWN := 0.8  # one trip up (or down) the lane pays once, however many plates it turns

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var bead_level := 0
var _sprites: Array[AnimatedSprite2D] = []
var _rates: Array[float] = []    # turns per second
var _turned: Array[float] = []
var _scored: Array[int] = []
var _bead_left := 0.0
var _pass_cooldown := 0.0

func _ready() -> void:
	for at in PLATES:
		var plate: AnimatedSprite2D = features._sprite(FLIPPER, FRAMES, at)
		plate.z_index = 2  # the ball (z 1) passes under the plates
		plate.z_as_relative = false
		_sprites.append(plate)
		_rates.append(0.0)
		_turned.append(0.0)
		_scored.append(0)
		var sensor := Area2D.new()
		sensor.position = at
		sensor.monitorable = false
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = SENSOR_SIZE
		shape.shape = rect
		sensor.add_child(shape)
		sensor.body_entered.connect(_on_ball_through.bind(_sprites.size() - 1))
		add_child(sensor)

func _on_ball_through(body: Node, index: int) -> void:
	if not features._is_ball_on_playfield(body):
		return
	var speed := absf((body as RigidBody2D).linear_velocity.y)
	_rates[index] = maxf(_rates[index], minf(speed * TURNS_PER_SPEED, MAX_TURNS_PER_SECOND))
	if _pass_cooldown > 0.0:
		return
	_pass_cooldown = PASS_COOLDOWN
	features.kickback.add_speed_charge(speed)
	features._award(PASS_POINTS[bead_level], PLATES[index])
	bead_level = mini(bead_level + 1, PASS_POINTS.size() - 1)
	_bead_left = BEAD_LEVEL_SECONDS[bead_level]

func _physics_process(delta: float) -> void:
	_pass_cooldown = maxf(_pass_cooldown - delta, 0.0)
	if bead_level > 0:
		_bead_left -= delta
		if _bead_left <= 0.0:
			bead_level -= 1
			_bead_left = BEAD_LEVEL_SECONDS[bead_level]
	for i in _sprites.size():
		if _rates[i] <= 0.0:
			continue
		_turned[i] += _rates[i] * delta
		_rates[i] = maxf(_rates[i] - FRICTION * delta, 0.0)
		_sprites[i].frame = int(fposmod(_turned[i], 1.0) * FRAMES) % FRAMES
		while _scored[i] < int(_turned[i]):
			_scored[i] += 1
			PinballEvents.add_score.emit(TURN_POINTS)
			AudioSfx.play("spinner", 0.0, Vector2.ONE * (1.0 + 0.08 * i))
