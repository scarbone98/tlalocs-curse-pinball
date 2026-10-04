extends Camera2D

@export var ball: NodePath            # the starting ball; used until the ball group is ready

## Calm, like Pokemon Pinball's view: the table holds still while the ball moves about
## the middle of the screen. The camera only drifts once the ball wanders toward an
## edge, and eases along after it rather than sticking to it. (Pokemon Pinball cuts
## between two screens that barely overlap, blinking to black; ours overlap by most of
## the table on a phone, so cutting between them just lurched.)
const DRAG_TOP := 0.35     # share of the half-view the ball roams freely above the centre
const DRAG_BOTTOM := 0.3   # ...and below it, a little less so the flippers stay in view
const DRAG_SIDE := 0.25
const FOLLOW_SPEED := 3.5  # how quickly the view catches up once it moves

## With multiball the camera watches the ball nearest the flippers, and only switches
## when another ball is clearly lower.
const SWITCH_MARGIN := 80.0

## Rumble, like the Pokemon Pinball cartridge's rumble pak: hard hits jolt the view a
## few pixels, and the shake dies away in a fraction of a second.
const SHAKE_DECAY := 14.0

## Like Pokemon Pinball Ruby & Sapphire's camera, the view leans ahead of the ball the way
## it's heading, easing there rather than snapping, and shifts over a little while the
## ball waits in the plunger lane.
const LOOK_AHEAD_PER_SPEED := 0.12
const MAX_LOOK_AHEAD := 150.0
const LOOK_EASE := 3.0
const PLUNGER_LANE_X := 655.0
const PLUNGER_SHIFT := 48.0
## Side to side it holds still once the ball's out of the launch lane, flush with the
## table's left edge so the border down that side is in view, and only moves up and down: it
## swings right for the launch lane, and for the right rail up into the golden temple (and
## while the ball's inside it).
const RIGHT_X := 720.0     # as far right as the limits allow
const REST_LEFT_EDGE := 0.0  # at rest the view's left edge: the table's own, border and all
const SHRINE := Rect2(439, 42, 281, 290)  # inside the golden temple
## A nudge jolts the table a few pixels the way it was pushed, and settles back
const NUDGE_JOLT := 9.0
const NUDGE_SETTLE := 18.0

var _followed: Node2D
var _shake := 0.0
var _look := Vector2.ZERO
var _jolt := Vector2.ZERO

func _ready() -> void:
	drag_vertical_enabled = true
	drag_horizontal_enabled = false
	drag_top_margin = DRAG_TOP
	drag_bottom_margin = DRAG_BOTTOM
	drag_left_margin = DRAG_SIDE
	drag_right_margin = DRAG_SIDE
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED
	PinballEvents.rumble.connect(func(strength: float): _shake = maxf(_shake, strength))
	PinballEvents.nudged.connect(func(direction: Vector2): _jolt = -direction * NUDGE_JOLT)

func _process(dt):
	var target := _pick_target()
	if target == null:
		return
	var first := _followed == null
	_followed = target
	var want := Vector2.ZERO
	var body := target as RigidBody2D
	if body:
		want.y = clampf(body.linear_velocity.y * LOOK_AHEAD_PER_SPEED, -MAX_LOOK_AHEAD, MAX_LOOK_AHEAD)
		if target.global_position.x > PLUNGER_LANE_X:
			want.x = -PLUNGER_SHIFT
	_look = _look.lerp(want, 1.0 - exp(-LOOK_EASE * dt))
	global_position = target.global_position + _look  # the drag margins and smoothing do the rest
	global_position.x = _view_x(target)
	if first:
		reset_smoothing()
	_shake *= exp(-SHAKE_DECAY * dt)
	_jolt *= exp(-NUDGE_SETTLE * dt)
	offset = _jolt + (Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.3 else Vector2.ZERO)

func _view_x(target: Node2D) -> float:
	var at := target.global_position
	if at.x > PLUNGER_LANE_X or SHRINE.has_point(at) or _on_right_rail(target):
		return RIGHT_X
	var half := get_viewport_rect().size.x / (2.0 * zoom.x)
	return half + REST_LEFT_EDGE

func _on_right_rail(target: Node2D) -> bool:
	var features := get_tree().current_scene.get_node_or_null(^"TableFeatures")
	if features == null or features.rails == null:
		return false
	var ride = features.rails._rides.get(target)
	return ride != null and ride.path == "right"

func _pick_target() -> Node2D:
	var followed_ok := is_instance_valid(_followed) and _followed.is_in_group("ball")
	var lowest: Node2D = _followed if followed_ok else null
	var margin := SWITCH_MARGIN if followed_ok else 0.0
	for node in get_tree().get_nodes_in_group("ball"):
		var candidate := node as Node2D
		if candidate == null or candidate == lowest:
			continue
		if lowest == null or candidate.global_position.y > lowest.global_position.y + margin:
			lowest = candidate
	if lowest == null and ball:
		lowest = get_node_or_null(ball) as Node2D
	return lowest
