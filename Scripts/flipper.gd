# Flipper.gd
extends AnimatableBody2D

@export var action_name: StringName = &"left_flipper"
@export var rest_angle_deg: float = 0   # angle when released
@export var up_angle_deg: float = 65.0      # angle when pressed
@export var up_speed_deg: float = 1200.0    # how fast it flips up
@export var down_speed_deg: float = 800.0   # how fast it returns

var _target: float

func _ready() -> void:
	rotation = deg_to_rad(rest_angle_deg)
	_target = rotation

func _physics_process(delta: float) -> void:
	var pressed := Input.is_action_pressed(action_name)
	_target = deg_to_rad(up_angle_deg if pressed else rest_angle_deg)
	var speed_deg := up_speed_deg if pressed else down_speed_deg

	var diff := wrapf(_target - rotation, -PI, PI)
	var step := deg_to_rad(speed_deg) * delta

	if abs(diff) <= step:
		rotation = _target
	else:
		rotation += clamp(diff, -step, step)
