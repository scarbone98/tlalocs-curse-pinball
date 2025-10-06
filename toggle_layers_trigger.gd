extends Node2D
class_name DirectionalRayOnlyGate

# What to toggle while "upper"
@export var layers_to_disable: Array[int] = [1]
@export var layers_to_enable:  Array[int] = [2]
@export var affect_mask_only: bool = true
@export var active_z_index: int = 1

# Optional filter
@export var target_group: String = ""   # e.g., "ball"

# Debounce
@export var rearm_frames: int = 6

# Assign these in the Inspector
@export var front_ray_path: NodePath
@export var back_ray_path: NodePath

var front_ray: RayCast2D
var back_ray: RayCast2D

# id -> Vector3i(mask, layer, z_index)
var _original: Dictionary[int, Vector3i] = {}
# id -> "front" | "back" | ""
var _last_side: Dictionary[int, String] = {}
# id -> frame index
var _cooldown: Dictionary[int, int] = {}
var _frame: int = 0

func _ready() -> void:
	# Resolve rays defensively
	front_ray = get_node_or_null(front_ray_path) as RayCast2D
	back_ray  = get_node_or_null(back_ray_path)  as RayCast2D

	if front_ray == null:
		push_warning("DirectionalRayOnlyGate: front_ray_path not set or node missing.")
	else:
		front_ray.enabled = true

	if back_ray == null:
		push_warning("DirectionalRayOnlyGate: back_ray_path not set or node missing.")
	else:
		back_ray.enabled = true

func _physics_process(_delta: float) -> void:
	_frame += 1
	if front_ray == null or back_ray == null:
		return  # rays not wired yet

	var f_body: RigidBody2D = _as_rb_if_target(front_ray.get_collider()) if front_ray.is_colliding() else null
	var b_body: RigidBody2D = _as_rb_if_target(back_ray.get_collider())  if back_ray.is_colliding()  else null

	if f_body != null:
		_process_side_for_body(f_body, "front")

	if b_body != null and b_body != f_body:
		_process_side_for_body(b_body, "back")

func _process_side_for_body(rb: RigidBody2D, side: String) -> void:
	var id: int = rb.get_instance_id()
	if _is_cooling(id):
		return

	if not _original.has(id):
		_original[id] = Vector3i(rb.collision_mask, rb.collision_layer, rb.z_index)

	var prev: String = _last_side.get(id, "")

	if side == "front":
		if prev != "front":
			_apply_upper(rb)
			_mark_cool(id)
		_last_side[id] = "front"
	elif side == "back":
		if prev != "back":
			_restore(rb)
			_mark_cool(id)
		_last_side[id] = "back"

func _apply_upper(rb: RigidBody2D) -> void:
	var disable_mask: int = _bits_to_mask(layers_to_disable)
	var enable_mask: int  = _bits_to_mask(layers_to_enable)

	rb.collision_mask = (rb.collision_mask & ~disable_mask) | enable_mask
	if not affect_mask_only:
		rb.collision_layer = (rb.collision_layer & ~disable_mask) | enable_mask
	rb.z_index = active_z_index
	rb.sleeping = false

func _restore(rb: RigidBody2D) -> void:
	var id: int = rb.get_instance_id()
	if not _original.has(id):
		return
	var saved: Vector3i = _original[id]
	rb.collision_mask = saved.x
	rb.collision_layer = saved.y
	rb.z_index = saved.z
	rb.sleeping = false

# ----- helpers -----
func _bits_to_mask(bits: Array[int]) -> int:
	var m: int = 0
	for b in bits:
		if b >= 1 and b <= 32:
			m |= 1 << (b - 1)
	return m

func _as_rb_if_target(node: Object) -> RigidBody2D:
	if node == null or not (node is RigidBody2D):
		return null
	var n: Node = node as Node
	if target_group != "" and not n.is_in_group(target_group):
		return null
	return node as RigidBody2D

func _is_cooling(id: int) -> bool:
	return _cooldown.has(id) and (_frame - _cooldown[id]) <= rearm_frames

func _mark_cool(id: int) -> void:
	_cooldown[id] = _frame
