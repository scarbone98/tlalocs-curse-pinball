# DirectionalLayersGate.gd
extends Area2D
class_name DirectionalLayersGate

# Collision flips while inside
@export var layers_to_disable: Array[int] = [1]   # lower/base
@export var layers_to_enable:  Array[int] = [2]   # upper
@export var affect_mask_only: bool = true

# Visual while "upper"
@export var active_z_index: int = 1

# Direction logic
@export var gate_normal: Vector2 = Vector2(0, -1)  # points "into upper"
@export var min_dot: float = 0.2                   # require at least this alignment (0..1)
@export var speed_threshold: float = 80.0          # ignore tiny/accidental nudges

# Optional filter
@export var target_group: String = ""              # e.g., "ball"

# Save originals per body so we can restore
var _original := {}  # id -> {"mask": int, "layer": int, "z": int}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = true

func _on_body_entered(body: Node) -> void:
	if not _is_target(body): return
	var rb := body as RigidBody2D
	var id := rb.get_instance_id()
	if not _original.has(id):
		_original[id] = {"mask": rb.collision_mask, "layer": rb.collision_layer, "z": rb.z_index}
	_apply_upper(rb)

func _on_body_exited(body: Node) -> void:
	if not _is_target(body): return
	var rb := body as RigidBody2D
	var v := rb.linear_velocity
	var speed := v.length()
	var n := gate_normal.normalized()
	var d := v.normalized().dot(gate_normal.normalized()) if speed > 0.0 else 0.0
	
	# Only restore when exiting "backward" (heading opposite the gate normal)
	# i.e., dot <= -min_dot AND we're moving with enough speed
	if speed >= speed_threshold and d <= -min_dot:
		_restore(rb)
	else:
		# still going up or too slow/sideways -> keep upper settings
		rb.sleeping = false

func _apply_upper(rb: RigidBody2D) -> void:
	var disable_mask := _bits_to_mask(layers_to_disable)
	var enable_mask  := _bits_to_mask(layers_to_enable)

	rb.collision_mask = (rb.collision_mask & ~disable_mask) | enable_mask
	if not affect_mask_only:
		rb.collision_layer = (rb.collision_layer & ~disable_mask) | enable_mask
	rb.z_index = active_z_index
	rb.sleeping = false

func _restore(rb: RigidBody2D) -> void:
	var id := rb.get_instance_id()
	if not _original.has(id): return
	var saved = _original[id]
	rb.collision_mask = int(saved["mask"])
	rb.collision_layer = int(saved["layer"])
	rb.z_index = int(saved["z"])
	_original.erase(id)

func _is_target(body: Node) -> bool:
	if not (body is RigidBody2D): return false
	return target_group == "" or body.is_in_group(target_group)

func _bits_to_mask(bits: Array[int]) -> int:
	var m := 0
	for b in bits:
		if b >= 1 and b <= 32:
			m |= 1 << (b - 1)
	return m
