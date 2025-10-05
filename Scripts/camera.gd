extends Camera2D

@export var ball: NodePath            # drag your Ball here

func _process(_dt):
	if not ball:
		return
	var ball_node := get_node_or_null(ball)
	if not ball_node:
		return

	# Follow only vertically; lock X
	global_position = Vector2(ball_node.global_position.x, ball_node.global_position.y)
