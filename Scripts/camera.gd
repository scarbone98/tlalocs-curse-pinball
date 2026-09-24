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

var _followed: Node2D
var _shake := 0.0

func _ready() -> void:
	drag_vertical_enabled = true
	drag_horizontal_enabled = true
	drag_top_margin = DRAG_TOP
	drag_bottom_margin = DRAG_BOTTOM
	drag_left_margin = DRAG_SIDE
	drag_right_margin = DRAG_SIDE
	position_smoothing_enabled = true
	position_smoothing_speed = FOLLOW_SPEED
	PinballEvents.rumble.connect(func(strength: float): _shake = maxf(_shake, strength))

func _process(dt):
	var target := _pick_target()
	if target == null:
		return
	var first := _followed == null
	_followed = target
	global_position = target.global_position  # the drag margins and smoothing do the rest
	if first:
		reset_smoothing()
	_shake *= exp(-SHAKE_DECAY * dt)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.3 else Vector2.ZERO

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
