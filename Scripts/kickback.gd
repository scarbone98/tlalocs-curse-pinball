extends Node2D
## Outlane kickback, following Pokemon Pinball's Pikachu saver (pret/pokepinball):
##  - only the spinner charges it; as on Pokemon Pinball Ruby & Sapphire the charge grows
##    with how fast the ball goes through, so one hard shot can fill it
##  - it guards one outlane at a time; the flippers move it (left flipper, left outlane)
##  - saving a ball uses it up; each new ball starts with it charged, guarding the left
##    outlane, so the frogs are always there for the first save
##  - the temple roulette and the market can award one that guards both outlanes, like
##    Ruby & Sapphire's Pichu: it doesn't get used up, it lasts until the ball drains
## The stone frog statue at the guarded outlane wakes up jade when it's ready and leaps
## when it fires. A ball it doesn't save doesn't drain in the frog's pit: it rolls on along
## the gutter track under the inlane and the flipper, down into the lava pit in the middle,
## and drains there.
##
## The outlanes aren't straight: the ball gets in through a slot between a wall ledge
## (y ~951) and the top of the inlane post (y ~1002), and no straight kick clears both.
## So the frog carries the ball up the lane and out through that slot, then flings it.

const FROG := preload("res://Sprites/table/kickback_frog.png")

const FULL_CHARGE_SPEED := 600.0  # one pass at this speed charges it fully
const CARRY_UP_SECONDS := 0.18
const CARRY_OUT_SECONDS := 0.1
const KICK_POINTS := 500
const FROG_AT := [Vector2(88, 1166), Vector2(586, 1166)]  # each squatting on its outlane's green pad
# Just above each outlane drain, so the kick fires before the ball reaches it
const KICK_ZONES := [Vector2(90, 1128), Vector2(586, 1131)]
const KICK_ZONE_SIZE := Vector2(50, 40)
# The bottom of each frog's pit, and the gutter track from there down into the lava pit
const PIT_ZONES := [Vector2(90, 1182), Vector2(586, 1184)]
const PIT_ZONE_SIZE := Vector2(48, 28)
# (each ends just above the drain, which it then drops into like any ball)
const GUTTERS := [
	[Vector2(88, 1178), Vector2(130, 1190), Vector2(178, 1210), Vector2(232, 1228), Vector2(284, 1236), Vector2(322, 1236)],
	[Vector2(586, 1180), Vector2(546, 1192), Vector2(498, 1212), Vector2(446, 1230), Vector2(392, 1236), Vector2(350, 1236)],
]
const GUTTER_SECONDS := 0.9
# Per outlane: top of the lane, just through the slot, and the fling out into the playfield
const CARRY_PATHS := [
	[Vector2(95, 977), Vector2(164, 977), Vector2(650, -950)],
	[Vector2(581, 977), Vector2(512, 977), Vector2(-650, -950)],
]

# The corridor under each outlane's roof was wide open, so a ball just rolling along
# the side drifted in, and outlanes took most drains (Pokemon Pinball's take a minority).
# A lip hanging under each roof lowers the corridor's ceiling: a ball still gets in if
# it comes in low and level, but not by drifting. The kickback's carry path runs under it.
const OUTLANE_LIPS := [
	[Vector2(70, 952), Vector2(82, 948), Vector2(131, 941), Vector2(138, 947), Vector2(138, 956), Vector2(70, 956)],
	[Vector2(538, 956), Vector2(538, 946), Vector2(546, 940), Vector2(612, 946), Vector2(612, 956)],
]

enum { STONE, AWAKE, LEAP }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var charged := false
var side := 0             # the outlane it guards: 0 left, 1 right
var both_sides := false   # the roulette's version guards both

var frogs: Array[AnimatedSprite2D] = []  # Scripts/lighting.gd lights an awake one
var _roll: Tween  # a ball rolling down a gutter
var _charge := 0.0

func _ready() -> void:
	for at in FROG_AT:
		frogs.append(features._sprite(FROG, 3, at))
	for i in KICK_ZONES.size():
		_add_kick_zone(KICK_ZONES[i], i)
		_add_pit_zone(PIT_ZONES[i], i)
	var lips := StaticBody2D.new()
	for lip in OUTLANE_LIPS:
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array(lip)
		lips.add_child(shape)
	add_child(lips)
	PinballEvents.ball_drained.connect(_reset)
	PinballEvents.ball_drained.connect(func():
		if _roll:
			_roll.kill())
	_reset()

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

func _add_pit_zone(at: Vector2, index: int) -> void:
	var area := Area2D.new()
	area.position = at
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PIT_ZONE_SIZE
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(_on_pit.bind(index))
	add_child(area)

# Unsaved, it rolls on down the gutter track into the lava pit, where it drains
func _on_pit(body: Node, index: int) -> void:
	var ball := body as RigidBody2D
	if ball == null or not ball.is_in_group("ball") or ball.freeze or not features._is_ball_on_playfield(ball):
		return
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	var path: Array = GUTTERS[index]
	var lengths: Array[float] = [0.0]
	for i in range(1, path.size()):
		lengths.append(lengths[-1] + (path[i] - path[i - 1]).length())
	if _roll:
		_roll.kill()
	var roll := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_roll = roll
	roll.tween_method(func(t: float):
		var along := t * lengths[-1]
		var i := 1
		while i < lengths.size() - 1 and lengths[i] < along:
			i += 1
		var k := inverse_lerp(lengths[i - 1], lengths[i], along)
		ball.global_position = (path[i - 1] as Vector2).lerp(path[i], k),
		0.0, 1.0, GUTTER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	roll.tween_callback(func():
		ball.freeze = false
		ball.linear_velocity = Vector2(0, 300))  # down into the lava pit's drain

func _physics_process(_delta: float) -> void:
	# The flippers move the guard between outlanes, as they move Pikachu
	if not charged or both_sides:
		return
	if Input.is_action_just_pressed("left_flipper") and side != 0:
		side = 0
		_render()
	elif Input.is_action_just_pressed("right_flipper") and side != 1:
		side = 1
		_render()

## A ball through the spinner at this speed, toward lighting the kickback
func add_speed_charge(speed: float) -> void:
	if charged:
		return
	_charge += speed / FULL_CHARGE_SPEED
	if _charge < 1.0:
		_blink_frogs()
		return
	_charge = 0.0
	charged = true
	_render()
	AudioSfx.play("charge")

## The roulette's kickback: guards both outlanes until it saves a ball. False if one's
## already guarding both.
func charge() -> bool:
	if charged and both_sides:
		return false
	_charge = 0.0
	charged = true
	both_sides = true
	_render()
	AudioSfx.play("charge")
	return true

func _reset() -> void:
	charged = true  # a fresh ball starts guarded
	both_sides = false
	side = 0
	_charge = 0.0
	_render()

func _guards(index: int) -> bool:
	return charged and (both_sides or side == index)

func _render() -> void:
	for i in frogs.size():
		frogs[i].frame = AWAKE if _guards(i) else STONE

func _on_kick_zone_entered(body: Node, index: int) -> void:
	if not _guards(index) or not features._is_ball_on_playfield(body):
		return
	var ball := body as RigidBody2D
	if ball.linear_velocity.y < 0.0:
		return  # already on its way back up the lane
	if not both_sides:
		charged = false  # the both-sides frogs keep guarding until the ball drains
	_carry_out(ball, CARRY_PATHS[index])
	PinballEvents.kickback_saved.emit()
	features._award(KICK_POINTS, frogs[index].global_position)
	PinballEvents.effect.emit("splash", frogs[index].global_position)
	PinballEvents.rumble.emit(6.0)
	AudioSfx.play("kickback")

	_render()
	frogs[index].frame = LEAP
	get_tree().create_timer(0.3).timeout.connect(_render)

func _carry_out(ball: RigidBody2D, path: Array) -> void:
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(ball, "global_position", path[0], CARRY_UP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ball, "global_position", path[1], CARRY_OUT_SECONDS)
	tween.tween_callback(func():
		ball.freeze = false
		ball.linear_velocity = path[2])

# Each spinner turn flickers the statues so you can see the charge building
func _blink_frogs() -> void:
	for frog in frogs:
		frog.frame = AWAKE
	get_tree().create_timer(0.08).timeout.connect(_render)
