extends Camera2D

@export var ball: NodePath            # the starting ball; used until the ball group is ready

## With multiball the camera follows the ball nearest the flippers. It only switches
## when another ball is clearly lower, and glides over instead of cutting.
const SWITCH_MARGIN := 80.0
const GLIDE_SECONDS := 0.35

var _followed: Node2D
var _glide := 0.0

func _process(dt):
	var target := _pick_target()
	if target == null:
		return
	if target != _followed:
		if _followed != null:
			_glide = GLIDE_SECONDS
		_followed = target

	if _glide > 0.0:
		# Closes the remaining gap evenly over what's left of the glide, landing exactly on the ball
		global_position = global_position.lerp(target.global_position, clampf(dt / _glide, 0.0, 1.0))
		_glide = maxf(_glide - dt, 0.0)
	else:
		global_position = target.global_position

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
