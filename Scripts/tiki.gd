extends Node2D
## The tiki at the top of the U-shaped lane, upper left, standing where Cyndaquil stands
## on Pokemon Pinball Ruby's field. It blocks the lane: each shot up it knocks the tiki
## back a step, and the third knocks it over onto its back, which calls up a spirit to
## catch (or, if one is already up, pays out instead). With the tiki down the lane runs
## clear to the back wall, until it climbs back to its feet.

const TIKI := preload("res://Sprites/table/tiki.png")  # tools/make_tiki_idol.py

const LANE_X := 251.0
# Where it stands (sprite centre y) before each hit: knocked a step back up the lane each time
const STANDS := [474.0, 459.0, 444.0]
const BODY_SIZE := Vector2(52, 46)
const BODY_OFFSET := Vector2(0, 12)    # the head and body; the leaf crown sticks up past it
const SENSOR_SIZE := Vector2(56, 20)
const SENSOR_OFFSET := Vector2(0, 42)  # just below the body, where a shot up the lane arrives
const HIT_COOLDOWN := 0.6
const HIT_POINTS := 1000
const TOPPLE_POINTS := 5000
const OVERFLOW_POINTS := 10000         # toppled with a spirit already up
const DOWN_SECONDS := 10.0
const STAGGER_SECONDS := 0.25
const FLARE_EVERY := Vector2(3.0, 7.0) # it glares about while it waits

enum { IDLE, FLARE, HIT, TOTTER, FALLEN }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D
var _body: StaticBody2D
var _body_shape: CollisionShape2D
var _sensor: Area2D
var _hits := 0
var _cooldown := 0.0
var _down_left := 0.0

func _ready() -> void:
	_sprite = features._sprite(TIKI, 5, Vector2(LANE_X, STANDS[0]))

	_body = StaticBody2D.new()
	_body_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	_body_shape.shape = rect
	_body_shape.position = BODY_OFFSET
	_body.add_child(_body_shape)
	add_child(_body)

	_sensor = Area2D.new()
	_sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var sensor_rect := RectangleShape2D.new()
	sensor_rect.size = SENSOR_SIZE
	shape.shape = sensor_rect
	shape.position = SENSOR_OFFSET
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_ball)
	add_child(_sensor)

	_stand_at(0)
	_glare.call_deferred()

func _stand_at(step: int) -> void:
	var at := Vector2(LANE_X, STANDS[step])
	_sprite.position = at
	_body.position = at
	_sensor.position = at

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _down_left > 0.0:
		_down_left -= delta
		if _down_left <= 0.0:
			_get_up()

func _on_ball(body: Node) -> void:
	if _cooldown > 0.0 or _down_left > 0.0 or not features._is_ball_on_playfield(body):
		return
	if (body as RigidBody2D).linear_velocity.y > 0.0:
		return  # only a shot up the lane knocks it
	_cooldown = HIT_COOLDOWN
	_hits += 1
	AudioSfx.play("tiki", 0.0, Vector2.ONE * (1.0 + 0.12 * _hits))
	PinballEvents.effect.emit("dust", _sprite.position + SENSOR_OFFSET)
	PinballEvents.rumble.emit(3.0)
	if _hits < STANDS.size():
		features._award(HIT_POINTS, _sprite.position)
		PinballEvents.toast.emit("Tiki %d/%d" % [_hits, STANDS.size()])
		_sprite.frame = HIT
		var step := _hits
		get_tree().create_timer(0.08, false).timeout.connect(func(): _stand_at.call_deferred(step))
		get_tree().create_timer(STAGGER_SECONDS, false).timeout.connect(func():
			if _down_left <= 0.0:
				_sprite.frame = IDLE)
		return
	_topple()

func _topple() -> void:
	_hits = 0
	_down_left = DOWN_SECONDS
	_sprite.frame = TOTTER
	_body_shape.set_deferred("disabled", true)
	get_tree().create_timer(0.15, false).timeout.connect(func():
		_sprite.frame = FALLEN
		PinballEvents.effect.emit("dust", _sprite.position + Vector2(0, -20))
		PinballEvents.rumble.emit(4.0))
	features._award(TOPPLE_POINTS, _sprite.position)
	PinballEvents.toast.emit("Tiki toppled!")
	if not features.spirit.summon():  # the billboard announces the spirit it calls up
		features._award(OVERFLOW_POINTS, _sprite.position + Vector2(0, -40))

# It climbs back to its feet at the front of the lane, but not on top of a ball
func _get_up() -> void:
	var front := Vector2(LANE_X, STANDS[0]) + BODY_OFFSET
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as Node2D
		if absf(ball.global_position.x - front.x) < BODY_SIZE.x and absf(ball.global_position.y - front.y) < BODY_SIZE.y:
			_down_left = 0.5
			return
	_stand_at(0)
	_body_shape.set_deferred("disabled", false)
	_sprite.frame = TOTTER
	get_tree().create_timer(STAGGER_SECONDS, false).timeout.connect(func(): _sprite.frame = IDLE)

func _glare() -> void:
	get_tree().create_timer(randf_range(FLARE_EVERY.x, FLARE_EVERY.y), false).timeout.connect(func():
		if _sprite.frame == IDLE:
			_sprite.frame = FLARE
			get_tree().create_timer(0.3, false).timeout.connect(func():
				if _sprite.frame == FLARE:
					_sprite.frame = IDLE)
		_glare())
