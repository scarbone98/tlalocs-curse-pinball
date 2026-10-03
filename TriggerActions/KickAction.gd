# BumperKickAction.gd
extends TriggerAction
class_name BumperKickAction
## The bumpers and slingshots copy Pokemon Pinball Ruby & Sapphire's: the ball keeps a
## fifth of the speed it came in with and gets a fixed kick on top (keep_fraction 0.2),
## so it rebounds much the same however hard it arrives. With keep_fraction below zero
## the kick is the older impulse model: base_impulse plus gain times the incoming speed.

@export var base_impulse: float = 1200.0    # minimum push
@export var gain: float = 1.4               # scales with incoming speed
@export var max_impulse: float = 3200.0     # clamp to keep it sane
@export var keep_fraction: float = -1.0     # Ruby & Sapphire: share of the ball's speed it keeps; the kick is base_impulse
@export var nudge_out_px: float = 1.0       # small push out to avoid sticking
@export var scatter_deg: float = 0.0        # random spread on the kick, so a ball can't settle into a repeating loop
@export var effect: String = ""             # particle burst where the ball was struck (see Scripts/effects.gd)
@export var rumble: float = 0.0             # screen shake for the hit, like the cartridge's rumble pak

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

	if keep_fraction >= 0.0:
		ball.linear_velocity = v * keep_fraction + n * base_impulse
	else:
		var impulse_mag: float = clamp(base_impulse + gain * speed_into, base_impulse, max_impulse)
		ball.apply_impulse(n * impulse_mag)
	if effect != "":
		PinballEvents.effect.emit(effect, trigger_pos.lerp(ball.global_position, 0.6))
	if rumble > 0.0:
		PinballEvents.rumble.emit(rumble)

	# optional small nudge outward so ball doesn’t stay overlapping
	if nudge_out_px > 0.0:
		ball.global_position += n * nudge_out_px
