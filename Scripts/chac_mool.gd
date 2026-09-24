extends Node2D
## The Chac Mool at the end of the U-shaped lane left of the frog pool: a reclining stone
## figure holding an offering bowl. Each shot up the lane fills his bowl a little; when
## it's full he calls up a water spirit to catch, another way to the spirit catch besides
## the ramps (or, if one is already up, pays out instead).

const CHAC_MOOL := preload("res://Sprites/table/chac_mool.png")

const ART_AT := Vector2(89.6, 143.1)   # table-art pixels, the top of the lane
const SENSOR_AT := Vector2(252, 440)
const SENSOR_RADIUS := 16.0             # the ball has to run right up the lane
const HIT_COOLDOWN := 1.0
const FILLS := 3
const FILL_POINTS := 1000
const OVERFLOW_POINTS := 10000          # full bowl with a spirit already up
const EMPTY_AFTER := 2.0

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D
var _level := 0
var _cooldown := 0.0

func _ready() -> void:
	_sprite = features._sprite(CHAC_MOOL, FILLS + 1, ART_AT * features.MAP_SCALE)
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

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)

func _on_ball(body: Node) -> void:
	if _cooldown > 0.0 or _level >= FILLS or not features._is_ball_on_playfield(body):
		return
	if (body as RigidBody2D).linear_velocity.y > 0.0:
		return  # only a shot up the lane pours an offering
	_cooldown = HIT_COOLDOWN
	_level += 1
	_sprite.frame = _level
	features._award(FILL_POINTS, SENSOR_AT)
	AudioSfx.play("chac_mool", 0.0, Vector2.ONE * (1.0 + 0.1 * _level))
	PinballEvents.effect.emit("splash", SENSOR_AT + Vector2(0, -8))
	PinballEvents.rumble.emit(3.0)
	if _level < FILLS:
		PinballEvents.toast.emit("Chac Mool %d/%d" % [_level, FILLS])
		return
	if features.spirit.summon():
		PinballEvents.toast.emit("Chac Mool calls a spirit!")
	else:
		features._award(OVERFLOW_POINTS, SENSOR_AT + Vector2(0, -40))
		PinballEvents.toast.emit("Chac Mool's offering!")
	get_tree().create_timer(EMPTY_AFTER, false).timeout.connect(func():
		_level = 0
		_sprite.frame = 0)
