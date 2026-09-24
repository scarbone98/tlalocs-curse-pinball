extends Node2D
## The jaguar in its den, the little arch right of the right ramp's mouth. Pokemon Pinball
## gives out extra balls; here the jaguar does. Each shot up into its den makes it roar
## and lights the next rosettes on its brow; light them all on one ball for an extra
## ball (losing the ball puts them out). Then it sleeps a long while, so extra balls
## stay rare.

const JAGUAR := preload("res://Sprites/table/jaguar.png")

const ART_AT := Vector2(195.9, 204.0)   # table-art pixels, in the shadow under the arch
const SENSOR_AT := Vector2(527, 670)     # the top of the pocket the ball can reach
const SENSOR_RADIUS := 12.0
const STEPS := 3
const HIT_COOLDOWN := 1.0
const STEP_POINTS := 1500
const SLEEP_SECONDS := 240.0
enum { ROAR = 4, ASLEEP = 5 }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D
var _lit := 0
var _cooldown := 0.0
var _sleep_left := 0.0

func _ready() -> void:
	_sprite = features._sprite(JAGUAR, 6, ART_AT * features.MAP_SCALE)
	var sensor := Area2D.new()
	sensor.position = SENSOR_AT
	sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = SENSOR_RADIUS
	shape.shape = circle
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_ball)
	add_child(sensor)
	PinballEvents.ball_drained.connect(func():
		_lit = 0
		if _sleep_left <= 0.0:
			_sprite.frame = 0)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _sleep_left > 0.0:
		_sleep_left -= delta
		if _sleep_left <= 0.0:
			_sprite.frame = 0

func _on_ball(body: Node) -> void:
	if _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	if (body as RigidBody2D).linear_velocity.y > 0.0:
		return  # only a shot up into the den
	_cooldown = HIT_COOLDOWN
	PinballEvents.rumble.emit(3.0)
	if _sleep_left > 0.0:
		features._award(STEP_POINTS / 3, SENSOR_AT)  # it only stirs in its sleep
		return
	_lit += 1
	features._award(STEP_POINTS, SENSOR_AT)
	AudioSfx.play("roar", 0.0, Vector2.ONE * (1.0 + 0.1 * _lit))
	PinballEvents.effect.emit("sparks", SENSOR_AT)
	_sprite.frame = ROAR
	if _lit < STEPS:
		PinballEvents.toast.emit("Jaguar %d/%d" % [_lit, STEPS])
		get_tree().create_timer(0.35, false).timeout.connect(func():
			if _sleep_left <= 0.0:
				_sprite.frame = _lit)
		return
	_lit = 0
	GameManager.award_extra_ball()
	PinballEvents.billboard.emit(Billboard.RELIC + 3, "Extra ball!")
	AudioSfx.play("extra_ball")
	PinballEvents.effect.emit("gold", SENSOR_AT)
	get_tree().create_timer(0.8, false).timeout.connect(func():
		_sleep_left = SLEEP_SECONDS
		_sprite.frame = ASLEEP)
