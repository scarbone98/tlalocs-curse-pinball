extends Node2D
## Nudging the table, like Pokemon Pinball Ruby & Sapphire's: bump it left, right or up
## and the ball gets a small shove that way (a strong one up near the flippers, to
## rescue a ball heading for the drain). The table jolts a few pixels. There's no tilt,
## only a short wait between bumps.
##
## Keys: Left Shift / Right Shift to bump sideways, Up arrow (or W) to bump up. On a
## phone, a quick swipe up, left or right does the same.

const COOLDOWN := 24.0 / 60.0
const SIDE_SHOVE := 220.0
const UP_SHOVE_LOW := 380.0   # near the flippers
const UP_SHOVE := 140.0
const LOW_Y := 1000.0
const SWIPE_SPEED := 1800.0   # screen pixels a second

var features: Node2D  # TableFeatures, which owns the shared helpers

var _cooldown := 0.0
var _swiped := {}  # touch index -> true once that touch has nudged

func _ready() -> void:
	_bind(&"nudge_left", [KEY_SHIFT], KEY_LOCATION_LEFT)
	_bind(&"nudge_right", [KEY_SHIFT], KEY_LOCATION_RIGHT)
	_bind(&"nudge_up", [KEY_UP, KEY_W])

func _bind(action: StringName, keys: Array, location := KEY_LOCATION_UNSPECIFIED) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.location = location
		InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.is_action_just_pressed(&"nudge_left"):
		nudge(Vector2.LEFT)
	elif Input.is_action_just_pressed(&"nudge_right"):
		nudge(Vector2.RIGHT)
	elif Input.is_action_just_pressed(&"nudge_up"):
		nudge(Vector2.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		_swiped.erase(event.index)
	elif event is InputEventScreenDrag and not _swiped.has(event.index):
		var v: Vector2 = event.velocity
		if v.length() < SWIPE_SPEED:
			return
		_swiped[event.index] = true
		if absf(v.y) > absf(v.x):
			if v.y < 0.0:
				nudge(Vector2.UP)
		else:
			nudge(Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT)

func nudge(direction: Vector2) -> void:
	if _cooldown > 0.0 or get_tree().paused:
		return
	_cooldown = COOLDOWN
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if ball.freeze or ball.collision_mask == 0:
			continue
		if direction == Vector2.UP:
			var low: bool = ball.global_position.y - ball.stage_origin.y > LOW_Y
			ball.linear_velocity.y -= UP_SHOVE_LOW if low else UP_SHOVE
		else:
			ball.linear_velocity.x += direction.x * SIDE_SHOVE
	PinballEvents.nudged.emit(direction)
	PinballEvents.rumble.emit(2.0)
