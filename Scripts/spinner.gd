extends Node2D
## The spinner across the left loop lane, like the one on Pokemon Pinball's Red Field
## that charges Pikachu. A ball going through sets the plate spinning as fast as the
## ball was going; it slows to a stop, scoring every turn, and every turn charges the
## kickback, as Pokemon Pinball's spinner charges its Pikachu saver.

const SPINNER := preload("res://Sprites/table/spinner.png")

const AT := Vector2(169, 465)
const SENSOR_SIZE := Vector2(58, 14)  # the full width of the lane, so every ball through it counts
const ART_AT := Vector2(60, 154)  # table-art pixels
const FRAMES := 8  # one full turn
const TURNS_PER_SPEED := 1.0 / 150.0  # turns per second for each unit of ball speed
const MAX_TURNS_PER_SECOND := 14.0
const FRICTION := 3.0  # turns per second lost each second
const TURN_POINTS := 100

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D
var _rate := 0.0  # turns per second
var _turned := 0.0
var _scored_turns := 0

func _ready() -> void:
	_sprite = features._sprite(SPINNER, FRAMES, ART_AT * features.MAP_SCALE)
	var sensor := Area2D.new()
	sensor.position = AT
	sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SENSOR_SIZE
	shape.shape = rect
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_ball_through)
	add_child(sensor)

func _on_ball_through(body: Node) -> void:
	if not features._is_ball_on_playfield(body):
		return
	var speed := absf((body as RigidBody2D).linear_velocity.y)
	_rate = maxf(_rate, minf(speed * TURNS_PER_SPEED, MAX_TURNS_PER_SECOND))

func _physics_process(delta: float) -> void:
	if _rate <= 0.0:
		return
	_turned += _rate * delta
	_rate = maxf(_rate - FRICTION * delta, 0.0)
	_sprite.frame = int(fposmod(_turned, 1.0) * FRAMES) % FRAMES
	while _scored_turns < int(_turned):
		_scored_turns += 1
		PinballEvents.add_score.emit(TURN_POINTS)
		AudioSfx.play("spinner")
		features.kickback.add_spinner_turn()
	if _rate == 0.0:
		# settle face up, so it never stops edge-on
		_turned = float(_scored_turns)
		_sprite.frame = 0
