extends Node2D
## The palms from the layout mock-up (Sprites/map_palms.png), each its own sprite over a
## ball on the playfield (the ball goes under them unless it's up on a rail). A ball
## rolling under one shakes it, and a few scraps of frond flutter down.

const Geometry := preload("res://Scripts/table_geometry.gd")
const PALMS := preload("res://Sprites/map_palms.png")
const LEAF := preload("res://Sprites/table/leaf_bit.png")  # tools/make_table.py

const SHAKE := [1.0, -1.0, 1.0, -1.0, 0.0]  # art pixels side to side, one step each
const SHAKE_STEP := 0.07
const COOLDOWN := 0.8  # one palm shakes at most this often
const LEAVES := 4

var features: Node2D  # TableFeatures

var _palms: Array[Sprite2D] = []
var _leaves: Array[CPUParticles2D] = []
var _boxes: Array[Rect2] = []
var _shake_left: Array[float] = []
var _cooldown: Array[float] = []
var _image: Image

func _ready() -> void:
	_image = PALMS.get_image()
	for box: Rect2 in Geometry.PALMS:
		var palm := Sprite2D.new()
		palm.texture = PALMS
		palm.region_enabled = true
		palm.region_rect = box
		palm.scale = features.MAP_SCALE
		palm.position = box.get_center() * features.MAP_SCALE
		palm.z_index = 2
		palm.z_as_relative = false
		features.add_child(palm)
		_palms.append(palm)
		_leaves.append(_leaf_fall(box))
		_boxes.append(box)
		_shake_left.append(0.0)
		_cooldown.append(0.0)

# A handful of frond scraps falling from under a palm, drawn at the table's pixel size
func _leaf_fall(box: Rect2) -> CPUParticles2D:
	var leaves := CPUParticles2D.new()
	leaves.texture = LEAF
	leaves.emitting = false
	leaves.one_shot = true
	leaves.local_coords = true  # so the scale draws the scraps at the table's pixel size
	leaves.amount = LEAVES
	leaves.lifetime = 1.1
	leaves.explosiveness = 0.7
	leaves.scale = features.MAP_SCALE
	leaves.position = box.get_center() * features.MAP_SCALE
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = box.size * 0.35
	leaves.direction = Vector2(0, 1)
	leaves.spread = 50.0
	leaves.initial_velocity_min = 4.0
	leaves.initial_velocity_max = 10.0
	leaves.gravity = Vector2(0, 14)
	leaves.damping_min = 2.0
	leaves.damping_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	leaves.color_ramp = fade
	leaves.z_index = 2
	leaves.z_as_relative = false
	features.add_child(leaves)
	return leaves

func _physics_process(delta: float) -> void:
	for i in _palms.size():
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
		if _shake_left[i] > 0.0:
			_shake_left[i] -= delta
			var step := clampi(int((SHAKE.size() * SHAKE_STEP - _shake_left[i]) / SHAKE_STEP), 0, SHAKE.size() - 1)
			_palms[i].offset.x = SHAKE[step] if _shake_left[i] > 0.0 else 0.0
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if ball.freeze or not features._is_ball_on_playfield(ball):
			continue
		var art: Vector2 = ball.global_position / features.MAP_SCALE
		for i in _boxes.size():
			if _cooldown[i] > 0.0 or not _boxes[i].has_point(art):
				continue
			if _image.get_pixelv(Vector2i(art.floor())).a > 0.0:  # under its fronds, not just its box
				_shake(i)

func _shake(i: int) -> void:
	_cooldown[i] = COOLDOWN
	_shake_left[i] = SHAKE.size() * SHAKE_STEP
	_leaves[i].restart()
