extends Node2D
## The palms from the layout mock-up (Sprites/map_palms.png), each its own sprite over a
## ball on the playfield (the ball goes under them unless it's up on a rail). A ball
## rolling under one shakes it, its fronds twisting back and forth, and a few scraps of
## frond flutter down.

const Geometry := preload("res://Scripts/table_geometry.gd")
const PALMS := preload("res://Sprites/map_palms.png")
const LEAVES_SHEET := preload("res://Sprites/table/leaves.png")  # tools/make_table.py
const Flutter := preload("res://Scripts/flutter.gd")
const SWAY_SHADER := preload("res://Scripts/palm_sway.gdshader")

const SHAKE_SECONDS := 0.9
const SWAY := 2.6        # art pixels the frond tips swing at first...
const SWAY_RATE := 22.0  # ...back and forth this fast (radians a second), dying away
const COOLDOWN := 0.8  # one palm shakes at most this often
const LEAVES := 5

var features: Node2D  # TableFeatures

var _palms: Array[Sprite2D] = []
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
		var sway := ShaderMaterial.new()
		sway.shader = SWAY_SHADER
		sway.set_shader_parameter("region", Vector4(box.position.x, box.position.y, box.size.x, box.size.y))
		palm.material = sway
		features.add_child(palm)
		_palms.append(palm)
		_boxes.append(box)
		_shake_left.append(0.0)
		_cooldown.append(0.0)

func _physics_process(delta: float) -> void:
	for i in _palms.size():
		_cooldown[i] = maxf(_cooldown[i] - delta, 0.0)
		if _shake_left[i] > 0.0:
			_shake_left[i] = maxf(_shake_left[i] - delta, 0.0)
			var t := SHAKE_SECONDS - _shake_left[i]
			var sway := SWAY * exp(-t * 4.0) * sin(t * SWAY_RATE)
			(_palms[i].material as ShaderMaterial).set_shader_parameter("sway", sway if _shake_left[i] > 0.0 else 0.0)
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
	_shake_left[i] = SHAKE_SECONDS
	Flutter.burst(features, LEAVES_SHEET, _palms[i].position, LEAVES, features.MAP_SCALE,
		_boxes[i].size * features.MAP_SCALE * 0.3, Vector2(0, 30), 3)
