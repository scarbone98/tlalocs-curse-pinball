extends Node2D
## The ball saver's tornado (Scripts/temple_hole.gd): smoke twisting up out of the lava into
## Tlaloc's mouth, wide where it boils up off the lava and drawn in tight at his lips. Three
## long strands of smoke twist round each other, drawn in the table's own chunky pixels: the ones round
## its far side darker and under the ball, the ones round its near side pale and over it.
## It reaches down out of his mouth to the lava, spins a while, then thins away and frees itself.

const PX := Vector2(720.0 / 256.0, 1280.0 / 424.0)  # one table-art pixel (TableFeatures.MAP_SCALE)
const STRANDS := 3
const TURNS := 1.4            # how many times a strand winds round, bottom to top
const SPIN := 17.0            # how fast it turns (radians a second)
const WIDE := 34.0            # its radius at the lava...
const NARROW := 9.0          # ...and at his mouth
const GROW_SECONDS := 0.45    # it reaches down from his mouth to the lava this fast
const FADE_SECONDS := 0.45
const NEAR := Color(0.92, 0.9, 0.88)
const FAR := Color(0.5, 0.49, 0.55)
const EMBER := Color(1.0, 0.6, 0.28)

var from := Vector2.ZERO   # the lava, where it boils up
var to := Vector2.ZERO     # his mouth
var seconds := 1.8

var _t := 0.0
var _far: Node2D

func _ready() -> void:
	z_index = 5  # the near side, over the ball
	z_as_relative = false
	_far = Node2D.new()
	_far.z_index = 2  # the far side, under it
	_far.z_as_relative = false
	_far.draw.connect(_draw_side.bind(_far, false))
	add_child(_far)

func _process(delta: float) -> void:
	_t += delta
	if _t > seconds:
		queue_free()
		return
	queue_redraw()
	_far.queue_redraw()

## Where along it (0 at the lava, 1 at his mouth), and how far round, a point on it lies
func point(along: float, angle: float) -> Vector2:
	var centre := from.lerp(to, along)
	var radius := lerpf(WIDE, NARROW, sqrt(along))
	return centre + Vector2(cos(angle) * radius, sin(angle) * radius * 0.25)

## How far round it's turned at this height by now
func turn(along: float) -> float:
	return along * TURNS * TAU - _t * SPIN

func _draw() -> void:
	_draw_side(self, true)

func _draw_side(canvas: Node2D, near: bool) -> void:
	var fade := smoothstep(0.0, 0.15, _t) * (1.0 - smoothstep(seconds - FADE_SECONDS, seconds, _t))
	var reach := minf(_t / GROW_SECONDS, 1.0)  # how far down from his mouth it's reached
	var steps := int(absf(to.y - from.y) / PX.y)
	for strand in STRANDS:
		var offset := float(strand) / STRANDS * TAU
		var last_x := INF  # where it was a row down: a strand swinging across is joined up
		for k in steps:
			var along := float(k) / steps
			if along < 1.0 - reach:
				last_x = INF
				continue
			var angle := turn(along) + offset
			if (sin(angle) > 0.0) != near:  # (the near side's the lower half of each loop)
				last_x = INF
				continue
			var at := (canvas.to_local(to_global(point(along, angle))) / PX).floor() * PX
			var col := (NEAR if near else FAR)
			col = EMBER.lerp(col, smoothstep(0.0, 0.25, along))  # glowing where it leaves the lava
			col.a = fade * (1.0 if near else 0.8) * (1.0 - 0.3 * along)
			# a thick strand of smoke: a darker edge either side of its pale core
			var wide := floorf(lerpf(6.0, 3.0, along) if near else lerpf(5.0, 2.0, along))
			at.x -= floorf(wide / 2.0) * PX.x
			var left := at.x
			var right := at.x + wide * PX.x
			if last_x != INF:  # stretched across to meet the row below
				left = minf(left, last_x)
				right = maxf(right, last_x + wide * PX.x)
			last_x = at.x
			var edge := col.darkened(0.3)
			canvas.draw_rect(Rect2(Vector2(left, at.y), Vector2(right - left, PX.y)), edge)
			if right - left > 2.0 * PX.x:
				canvas.draw_rect(Rect2(Vector2(left + PX.x, at.y), Vector2(right - left - 2.0 * PX.x, PX.y)), col)
