extends Node2D
## Little things fluttering down: feathers knocked off a warrior (Scripts/warriors.gd),
## scraps of frond shaken off a palm (Scripts/palms.gd). Each piece pops out, then drifts
## down slowly, swinging side to side as it goes and flipping over at the end of each
## swing, the way a feather or a leaf falls; then it fades. Drawn on the table's art-pixel
## grid. Frees itself once the last piece has gone.

const FRAME := Vector2i(7, 4)  # each piece's frame in its sheet (tools/make_table.py)
const LIFE := 1.6
const FADE_SECONDS := 0.4
const DRAG := 3.5          # how quickly the air takes a piece's speed off it...
const FALL := 34.0         # ...till it drifts down at about this
const SWING := 22.0        # how far it swings side to side
const SWING_RATE := Vector2(5.0, 8.0)

var _pieces: Array = []  # each: [Sprite2D, velocity, swing phase, swing rate, where it'd be without the swing]
var _px := Vector2.ONE
var _t := 0.0

## `count` pieces from `sheet` (any of its frames), popping out from `at` within `spread`
## and fluttering down; `kick` sends them off that way to begin with
static func burst(parent: Node, sheet: Texture2D, at: Vector2, count: int, scale: Vector2,
		spread := Vector2(10, 6), kick := Vector2(0, -90), z := 4) -> void:
	var flutter: Node2D = load("res://Scripts/flutter.gd").new()
	flutter._px = scale
	flutter.z_index = z
	flutter.z_as_relative = false
	parent.add_child(flutter)
	var frames := sheet.get_width() / FRAME.x
	for i in count:
		var piece := Sprite2D.new()
		piece.texture = sheet
		piece.region_enabled = true
		piece.region_rect = Rect2(Vector2(randi() % frames * FRAME.x, 0), FRAME)
		piece.scale = scale
		piece.flip_h = randf() < 0.5
		flutter.add_child(piece)
		var from := at + Vector2(randf_range(-spread.x, spread.x), randf_range(-spread.y, spread.y))
		var velocity := kick.rotated(randf_range(-0.9, 0.9)) * randf_range(0.6, 1.3)
		flutter._pieces.append([piece, velocity, randf() * TAU, randf_range(SWING_RATE.x, SWING_RATE.y), from])

func _process(delta: float) -> void:
	_t += delta
	for p: Array in _pieces:
		var piece: Sprite2D = p[0]
		var v: Vector2 = p[1]
		v = v.lerp(Vector2(0, FALL), 1.0 - exp(-DRAG * delta))
		p[1] = v
		p[4] = (p[4] as Vector2) + v * delta
		var phase: float = p[2] + _t * p[3]
		var swing := sin(phase) * SWING * minf(_t * 2.0, 1.0)
		var at: Vector2 = (p[4] as Vector2) + Vector2(swing, -absf(cos(phase)) * 3.0)
		piece.position = (at / _px).floor() * _px  # on the art-pixel grid
		piece.flip_h = cos(phase) > 0.0  # it turns over at the end of each swing
	modulate.a = 1.0 - smoothstep(LIFE - FADE_SECONDS, LIFE, _t)
	if _t > LIFE:
		queue_free()
