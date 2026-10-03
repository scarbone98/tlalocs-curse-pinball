extends Node2D
## The plunger at the foot of the launch lane: a gold-capped spring (Sprites/table/spring.png)
## the ball sits on, like Pokemon Pinball Ruby & Sapphire's. Holding launch pulls it down a
## frame at a time, the ball resting on its cap sinking with it, and letting go snaps it
## back up as the ball fires (Scripts/ball.gd).

const SPRING := preload("res://Sprites/table/spring.png")  # tools/make_table.py
const FRAMES := 9           # at rest, then a pixel shorter each frame
const LANE_X := 685.0       # the middle of the launch lane (scene units)
const LANE_FLOOR := 1232.0  # the lane's floor, the spring's foot
const LANE_WIDTH := 46.0
const SNAP_SECONDS := 0.05  # how fast it springs back up when let go

var features: Node2D  # TableFeatures

var _spring: Sprite2D
var _shown := 0.0  # frames pulled down, as drawn
var _cap: AnimatableBody2D
var _art_pixel := 0.0  # one art pixel, in scene units down the table
var _rest_y := 0.0

func _ready() -> void:
	_spring = Sprite2D.new()
	_spring.texture = SPRING
	_spring.hframes = FRAMES
	_spring.scale = features.MAP_SCALE
	_spring.centered = false
	var size: Vector2 = Vector2(SPRING.get_width() / FRAMES, SPRING.get_height()) * features.MAP_SCALE
	_spring.position = Vector2(LANE_X - size.x * 0.5, LANE_FLOOR - size.y)
	features.add_child(_spring)
	# the spring's cap, at rest, is what the ball sits on
	_art_pixel = features.MAP_SCALE.y
	_cap = AnimatableBody2D.new()
	_cap.sync_to_physics = false
	_cap.position = Vector2(LANE_X, LANE_FLOOR - size.y)
	var shape := CollisionShape2D.new()
	var line := SegmentShape2D.new()
	line.a = Vector2(-LANE_WIDTH * 0.5, 0)
	line.b = Vector2(LANE_WIDTH * 0.5, 0)
	shape.shape = line
	_cap.add_child(shape)
	add_child(_cap)
	_rest_y = _cap.position.y

func _physics_process(delta: float) -> void:
	var pulled := 0.0
	for node in get_tree().get_nodes_in_group("ball"):
		if node.has_method("pull"):
			pulled = maxf(pulled, node.pull())
	var want := pulled * (FRAMES - 1)
	# down as it's pulled; back up at once when it's let go
	_shown = want if want >= _shown else move_toward(_shown, want, (FRAMES - 1) / SNAP_SECONDS * delta)
	_spring.frame = int(roundf(_shown))
	_cap.position.y = _rest_y + _spring.frame * _art_pixel  # the cap the ball sits on goes with it
