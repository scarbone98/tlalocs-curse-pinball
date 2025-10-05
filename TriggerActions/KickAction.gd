# BumperKickAction.gd
extends TriggerAction
class_name BumperKickAction

@export var base_impulse: float = 1200.0    # minimum push
@export var gain: float = 1.4               # scales with incoming speed
@export var max_impulse: float = 3200.0     # clamp to keep it sane
@export var nudge_out_px: float = 1.0       # small push out to avoid sticking

func execute(ball: RigidBody2D, trigger: Node) -> void:
	if ball == null:
		return
	if not (ball is RigidBody2D):
		return

	var trigger_node: Node2D = trigger as Node2D
	var trigger_pos: Vector2 = trigger_node.global_position

	var n: Vector2 = (ball.global_position - trigger_pos).normalized()
	var v: Vector2 = ball.linear_velocity
	var speed_into: float = max(0.0, -v.dot(n))

	var impulse_mag: float = clamp(base_impulse + gain * speed_into, base_impulse, max_impulse)
	var impulse: Vector2 = n * impulse_mag   # explicitly Vector2

	ball.apply_impulse(impulse)

	# optional small nudge outward so ball doesn’t stay overlapping
	if nudge_out_px > 0.0:
		ball.global_position += n * nudge_out_px
