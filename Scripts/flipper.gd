# Flipper.gd
extends AnimatableBody2D

@export var action_name: StringName = &"left_flipper"
@export var rest_angle_deg: float = 0   # angle when released
@export var up_angle_deg: float = 65.0      # angle when pressed
@export var up_speed_deg: float = 1800.0    # how fast it flips up
@export var down_speed_deg: float = 800.0   # how fast it returns

## A moving AnimatableBody only nudges a RigidBody, so while swinging up we set the
## ball's speed off the flipper ourselves: kick_base plus the surface speed at the contact
## point times kick_gain. Hitting near the tip sends it further, like a real flipper.
@export var kick_base: float = 450.0
@export var kick_gain: float = 0.8
@export var contact_margin: float = 6.0

var _target: float
var _ball_radius := 19.0
var _tip_local := Vector2.ZERO    # flipper tip relative to the pivot, in local space
var _half_thickness := 12.0

func _ready() -> void:
	rotation = deg_to_rad(rest_angle_deg)
	_target = rotation
	_measure_shape()
	var ball := get_tree().get_first_node_in_group("ball") as RigidBody2D
	if ball:
		var shape := ball.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape and shape.shape is CircleShape2D:
			_ball_radius = (shape.shape as CircleShape2D).radius

# The tip is the polygon point farthest from the pivot; thickness is how far the
# polygon reaches off that pivot-to-tip line.
func _measure_shape() -> void:
	var poly: CollisionPolygon2D
	for child in get_children():
		if child is CollisionPolygon2D:
			poly = child
			break
	if poly == null:
		return
	var pts: Array[Vector2] = []
	for p in poly.polygon:
		pts.append(poly.transform * p)
	for p in pts:
		if p.length() > _tip_local.length():
			_tip_local = p
	var dir := _tip_local.normalized()
	var widest := 0.0
	for p in pts:
		widest = max(widest, absf(dir.cross(p)))
	if widest > 0.0:
		_half_thickness = widest * 0.5

func _physics_process(delta: float) -> void:
	var pressed := Input.is_action_pressed(action_name)
	_target = deg_to_rad(up_angle_deg if pressed else rest_angle_deg)
	var speed_deg := up_speed_deg if pressed else down_speed_deg

	var diff := wrapf(_target - rotation, -PI, PI)
	var step := deg_to_rad(speed_deg) * delta
	var turned: float = diff if abs(diff) <= step else clamp(diff, -step, step)
	rotation += turned

	if pressed and turned != 0.0:
		for ball in get_tree().get_nodes_in_group("ball"):  # multiball: every ball in play
			_kick_ball(ball as RigidBody2D, turned / delta)

func _kick_ball(ball: RigidBody2D, omega: float) -> void:
	if ball == null or ball.collision_mask == 0 or _tip_local == Vector2.ZERO:
		return
	var pivot := global_position
	var seg := global_transform * _tip_local - pivot
	var t: float = clamp((ball.global_position - pivot).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var closest := pivot + seg * t
	var to_ball := ball.global_position - closest
	if to_ball.length() > _ball_radius + _half_thickness + contact_margin:
		return

	var n := to_ball.normalized()
	var r := closest - pivot
	var surface_v := Vector2(-omega * r.y, omega * r.x)
	var push := surface_v.dot(n)
	if push <= 0.0:
		return  # ball is on the side the flipper is swinging away from

	var target := kick_base + push * kick_gain
	var v := ball.linear_velocity
	var along := v.dot(n)
	if along >= target:
		return
	v += n * (target - along)
	ball.linear_velocity = v  # the ball caps its own speed
