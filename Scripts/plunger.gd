extends Node2D
## The plunger at the foot of the launch lane: a gold-capped spring (Sprites/table/spring.png)
## the ball sits on, like Pokemon Pinball Ruby & Sapphire's. Holding launch pulls it down a
## frame at a time, the ball resting on its cap sinking with it, and letting go snaps it
## back up as the ball fires (Scripts/ball.gd).

const SPRING := preload("res://Sprites/table/spring.png")  # tools/make_table.py
const FRAME_WIDTH := 14     # art pixels: at rest, then a pixel shorter each frame (tools/make_table.py)
const LANE_X := 685.0       # the middle of the launch lane (scene units)
const LANE_FLOOR := 1232.0  # the lane's floor, the spring's foot
const LANE_WIDTH := 46.0
const SNAP_SECONDS := 0.05  # how fast it springs back up when let go

var features: Node2D  # TableFeatures

var _spring: Sprite2D
var _shown := 0.0  # frames pulled down, as drawn
var _cap: AnimatableBody2D
var _cap_shape: CollisionShape2D
var _passing := false  # the cap lets the ball through: snapping back up, or till the ball's clear of it
var _art_pixel := 0.0  # one art pixel, in scene units down the table
var _rest_y := 0.0
var _frames := 1

func _ready() -> void:
	_spring = Sprite2D.new()
	_spring.texture = SPRING
	_frames = SPRING.get_width() / FRAME_WIDTH
	_spring.hframes = _frames
	_spring.scale = features.MAP_SCALE
	_spring.centered = false
	var size: Vector2 = Vector2(FRAME_WIDTH, SPRING.get_height()) * features.MAP_SCALE
	_spring.position = Vector2(LANE_X - size.x * 0.5, LANE_FLOOR - size.y)
	features.add_child(_spring)
	# the spring's cap, at rest, is what the ball sits on
	_art_pixel = features.MAP_SCALE.y
	_cap = AnimatableBody2D.new()
	_cap.sync_to_physics = false
	_cap.position = Vector2(LANE_X, LANE_FLOOR - size.y)
	var shape := CollisionShape2D.new()
	var line := SegmentShape2D.new()
	line.a = Vector2(-LANE_WIDTH * 0.5, 0)
	line.b = Vector2(LANE_WIDTH * 0.5, 0)
	shape.shape = line
	_cap.add_child(shape)
	_cap_shape = shape
	add_child(_cap)
	_rest_y = _cap.position.y
	_fit_lane.call_deferred()

const BALL_RADIUS := 19.0
const LAUNCH_ZONE_ABOVE := 45.0  # the launch zone reaches this far above the ball on the cap

# The ball waits on the spring's cap, however tall it stands: it's put back there (not
# inside the spring) when it respawns, and the launch zone reaches up to it
func _fit_lane() -> void:
	var on_cap := _rest_y - BALL_RADIUS - 1.0
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if ball.get("spawn_xform") == null or absf(ball.spawn_xform.origin.x - LANE_X) > LANE_WIDTH:
			continue
		var was_waiting: bool = ball.global_position.distance_to(ball.spawn_xform.origin) < 80.0
		ball.spawn_xform.origin.y = on_cap
		if was_waiting:
			PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, ball.spawn_xform)
			ball.global_position = ball.spawn_xform.origin
	var zone := get_tree().get_first_node_in_group("launch_region") as Area2D
	if zone:
		for child in zone.get_children():
			var holder := child as CollisionShape2D
			if holder and holder.shape is RectangleShape2D:
				var rect := (holder.shape as RectangleShape2D).duplicate() as RectangleShape2D
				var top := on_cap - LAUNCH_ZONE_ABOVE
				rect.size.y = LANE_FLOOR - top
				holder.shape = rect
				holder.global_position.y = (top + LANE_FLOOR) * 0.5

func _physics_process(delta: float) -> void:
	var pulled := 0.0
	for node in get_tree().get_nodes_in_group("ball"):
		if node.has_method("pull"):
			pulled = maxf(pulled, node.pull())
	var want := pulled * (_frames - 1)
	# down as it's pulled; back up at once when it's let go
	_shown = want if want >= _shown else move_toward(_shown, want, (_frames - 1) / SNAP_SECONDS * delta)
	# snapping back up it passes through the ball rather than batting it on: the launch
	# itself (Scripts/ball.gd) is all the kick it gets
	# (and it stays so till the ball's clear above it, not shoving it on as they part)
	var snapping := want < _shown
	if snapping:
		_passing = true
	elif _passing:
		_passing = false
		for node in get_tree().get_nodes_in_group("ball"):
			var ball := node as Node2D
			if absf(ball.global_position.x - LANE_X) < LANE_WIDTH and ball.global_position.y > _rest_y - BALL_RADIUS - 2.0:
				_passing = true
	if _cap_shape.disabled != _passing:
		_cap_shape.set_deferred("disabled", _passing)
	_spring.frame = int(roundf(_shown))
	_cap.position.y = _rest_y + _spring.frame * _art_pixel  # the cap the ball sits on goes with it
