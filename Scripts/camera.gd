extends Camera2D

@export var ball: NodePath            # the starting ball; used until the ball group is ready

## Screens, like Pokemon Pinball's. Its camera never follows the ball: each half of the
## table is a fixed screen, and it flips between them only when the ball crosses over
## (pret/pokepinball: ScrollScreenToShowPinball holds the vertical scroll still;
## FieldVerticalTransition swaps screens). Sideways it only shifts to show the launch
## lane. So the table holds still while the ball moves, which is a lot of why that game
## feels calm. Here there are two screens each way; the view moves on only when the
## ball comes near the edge of the one it's on, sliding over briefly instead of cutting.
const EDGE_MARGIN := 150.0   # how close to the top/bottom edge before changing screens
const SIDE_MARGIN := 70.0    # the same, sideways
const SLIDE_SECONDS := 0.2

## With multiball the camera watches the ball nearest the flippers, and only switches
## when another ball is clearly lower.
const SWITCH_MARGIN := 80.0

## Rumble, like the Pokemon Pinball cartridge's rumble pak: hard hits jolt the view a
## few pixels, and the shake dies away in a fraction of a second.
const SHAKE_DECAY := 14.0

var _followed: Node2D
var _goal := Vector2.INF   # the screen it's on (or sliding to)
var _from := Vector2.ZERO
var _slide := 1.0          # 0..1 through the current slide
var _shake := 0.0

func _ready() -> void:
	position_smoothing_enabled = false  # the screens slide on their own
	PinballEvents.rumble.connect(func(strength: float): _shake = maxf(_shake, strength))

func _process(dt):
	var target := _pick_target()
	if target == null:
		return
	_followed = target
	var view := get_viewport_rect().size / zoom
	var area := Rect2(limit_left, limit_top, limit_right - limit_left, limit_bottom - limit_top)
	var want := _screen_for(target.global_position, view, area)
	if want != _goal:
		# A long way off (a new stage, or the first frame) cuts straight there
		if _goal == Vector2.INF or want.distance_to(global_position) > view.length():
			global_position = want
			_slide = 1.0
		else:
			_from = global_position
			_slide = 0.0
		_goal = want
	if _slide < 1.0:
		_slide = minf(_slide + dt / SLIDE_SECONDS, 1.0)
		global_position = _from.lerp(_goal, ease(_slide, -2.0))
	else:
		global_position = _goal

	_shake *= exp(-SHAKE_DECAY * dt)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.3 else Vector2.ZERO

func _screen_for(at: Vector2, view: Vector2, area: Rect2) -> Vector2:
	return Vector2(
		_pick(at.x, area.position.x, area.end.x, view.x, SIDE_MARGIN, _goal.x),
		_pick(at.y, area.position.y, area.end.y, view.y, EDGE_MARGIN, _goal.y))

# One axis: the low screen (lo..lo+size) or the high one (hi-size..hi). Stay on the
# current one until the ball gets within `margin` of its edge.
func _pick(at: float, lo: float, hi: float, size: float, margin: float, current: float) -> float:
	var low := lo + size * 0.5
	var high := hi - size * 0.5
	if high <= low:
		return (lo + hi) * 0.5  # one screen covers it all
	var on_low := is_equal_approx(current, low)
	var on_high := is_equal_approx(current, high)
	if on_low and at < low + size * 0.5 - margin:
		return low
	if on_high and at > high - size * 0.5 + margin:
		return high
	# Not on either (or near an edge): whichever screen shows the ball furthest from its edges
	return low if absf(at - low) < absf(at - high) else high

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
