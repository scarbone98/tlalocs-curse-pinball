# Bumper.gd
extends Node2D

## --- Tuning variables ---
@export var base_impulse: float = 1200.0    # minimum push
@export var gain: float = 1.4               # adds force based on incoming speed
@export var max_impulse: float = 3200.0     # clamp so it doesn’t launch ball to the moon
@export var cooldown_ms: int = 60           # time before it can trigger again (ms)
@export var score_points: int = 50          # how many points this bumper gives

var _next_ready_ms: int = 0

func _ready() -> void:
	# Connect the trigger sensor (Area2D)
	$Area2D.body_entered.connect(_on_hit)

func _on_hit(body: Node) -> void:
	if not body.is_in_group("ball"):
		return

	var now := Time.get_ticks_msec()
	if now < _next_ready_ms:
		return
	_next_ready_ms = now + cooldown_ms

	var ball := body as RigidBody2D

	# Direction from bumper center to ball
	var n: Vector2 = (ball.global_position - global_position).normalized()

	# Component of velocity going into the bumper
	var v: Vector2 = ball.linear_velocity
	var speed_into: float = max(0.0, -v.dot(n))

	# Calculate impulse
	var impulse_mag := clamp(base_impulse + gain * speed_into, base_impulse, max_impulse)
	var impulse: Vector2 = n * impulse_mag
	ball.apply_impulse(impulse)

	# Optional: nudge ball slightly outward to prevent sticking
	ball.global_position += n * 1.0
