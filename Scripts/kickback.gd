extends Node2D
## Outlane kickback, like Pikachu in Pokemon Pinball. Hitting the frogs in the pool
## charges it, and a charged kickback sends a ball that falls into either outlane
## back into play. The stone frog statues at the foot of the outlanes wake up jade
## when it's ready and leap when they fire.
##
## The outlanes aren't straight: the ball gets in through a slot between a wall ledge
## (y ~951) and the top of the inlane post (y ~1002), and no straight kick clears both.
## So the frog carries the ball up the lane and out through that slot, then flings it.

const FROG := preload("res://Sprites/table/kickback_frog.png")

const HITS_TO_CHARGE := 10
const CARRY_UP_SECONDS := 0.18
const CARRY_OUT_SECONDS := 0.1
const KICK_POINTS := 500
const FROG_AT := [Vector2(100, 1138), Vector2(586, 1138)]
# Just above each outlane drain, so the kick fires before the ball reaches it
const KICK_ZONES := [Vector2(90, 1128), Vector2(586, 1131)]
const KICK_ZONE_SIZE := Vector2(50, 40)
# Per outlane: top of the lane, just through the slot, and the fling out into the playfield
const CARRY_PATHS := [
	[Vector2(95, 977), Vector2(164, 977), Vector2(650, -950)],
	[Vector2(581, 977), Vector2(512, 977), Vector2(-650, -950)],
]

enum { STONE, AWAKE, LEAP }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var charged := false

var _frogs: Array[AnimatedSprite2D] = []
var _hits := 0

func _ready() -> void:
	for at in FROG_AT:
		_frogs.append(features._sprite(FROG, 3, at))
	for i in KICK_ZONES.size():
		_add_kick_zone(KICK_ZONES[i], i)
	var pool := features.get_node_or_null(^"../mushrooms")
	if pool:
		for frog in pool.get_children():
			if frog is Area2D:
				frog.body_entered.connect(_on_frog_hit)

func _add_kick_zone(at: Vector2, index: int) -> void:
	var area := Area2D.new()
	area.position = at
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = KICK_ZONE_SIZE
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_on_kick_zone_entered.bind(index))
	add_child(area)

func _on_frog_hit(body: Node) -> void:
	if not features._is_ball_on_playfield(body):
		return
	add_charge_hit()

## One step toward lighting the kickback (a frog hit, or turns of the spinner)
func add_charge_hit() -> void:
	if charged:
		return
	_hits += 1
	if _hits < HITS_TO_CHARGE:
		_blink_frogs()
		return
	charge()

## Lights the kickback now (the temple's roulette can award it). False if already lit.
func charge() -> bool:
	if charged:
		return false
	_hits = 0
	charged = true
	_show(AWAKE)
	PinballEvents.toast.emit("Kickback ready!")
	AudioSfx.play("charge")
	return true

func _on_kick_zone_entered(body: Node, index: int) -> void:
	if not charged or not features._is_ball_on_playfield(body):
		return
	var ball := body as RigidBody2D
	if ball.linear_velocity.y < 0.0:
		return  # already on its way back up the lane
	charged = false
	_carry_out(ball, CARRY_PATHS[index])
	features._award(KICK_POINTS, _frogs[index].global_position)
	PinballEvents.toast.emit("Kickback!")
	PinballEvents.effect.emit("splash", _frogs[index].global_position)
	PinballEvents.rumble.emit(6.0)
	AudioSfx.play("kickback")

	_frogs[index].frame = LEAP
	var other := _frogs[1 - index]
	other.frame = STONE
	get_tree().create_timer(0.3).timeout.connect(func():
		if not charged:
			_frogs[index].frame = STONE)

func _carry_out(ball: RigidBody2D, path: Array) -> void:
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(ball, "global_position", path[0], CARRY_UP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ball, "global_position", path[1], CARRY_OUT_SECONDS)
	tween.tween_callback(func():
		ball.freeze = false
		ball.linear_velocity = path[2])

# Each frog hit flickers the statues so you can see the charge building
func _blink_frogs() -> void:
	_show(AWAKE)
	get_tree().create_timer(0.08).timeout.connect(func():
		if not charged:
			_show(STONE))

func _show(frame: int) -> void:
	for frog in _frogs:
		frog.frame = frame
