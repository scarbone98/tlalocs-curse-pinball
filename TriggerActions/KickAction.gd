# BumperKickAction.gd
extends TriggerAction
class_name BumperKickAction
## The frogs and slingshots copy Pokemon Pinball's bumpers (base 514 = its 2 px/frame
## push, gain 1.25): the ball leaves with a quarter of the speed it came in with plus
## that push, however hard it arrives.

@export var base_impulse: float = 1200.0    # minimum push
@export var gain: float = 1.4               # scales with incoming speed
@export var max_impulse: float = 3200.0     # clamp to keep it sane
@export var nudge_out_px: float = 1.0       # small push out to avoid sticking
@export var scatter_deg: float = 0.0        # random spread on the kick, so a ball can't settle into a repeating loop

func execute(ball: RigidBody2D, trigger: Node) -> void:
	if ball == null:
		return
	if not (ball is RigidBody2D):
		return

	var trigger_node: Node2D = trigger as Node2D
	var trigger_pos: Vector2 = trigger_node.global_position

	var n: Vector2 = (ball.global_position - trigger_pos).normalized()
	if scatter_deg > 0.0:
		n = n.rotated(deg_to_rad(randf_range(-scatter_deg, scatter_deg)))
	var v: Vector2 = ball.linear_velocity
	var speed_into: float = max(0.0, -v.dot(n))

	var impulse_mag: float = clamp(base_impulse + gain * speed_into, base_impulse, max_impulse)
	var impulse: Vector2 = n * impulse_mag   # explicitly Vector2

	ball.apply_impulse(impulse)

	# optional small nudge outward so ball doesn’t stay overlapping
	if nudge_out_px > 0.0:
		ball.global_position += n * nudge_out_px
