extends Node2D
## Smoke streaming up off the lava where a ball's going under (Scripts/effects.gd): a few
## ribbons of smoke, each rising from the lava in a wavering column that sways wider as it
## climbs, thinning and fading, drawn in the table's own chunky pixels. Frees itself once
## the last of it has faded.

const PX := Vector2(720.0 / 256.0, 1280.0 / 424.0)  # one table-art pixel (TableFeatures.MAP_SCALE)
const STREAMERS := 3
const EMIT_EVERY := 1.0 / 30.0
const LIFE := 1.7            # each bit of a ribbon rises this long as it fades
const RISE_SPEED := 120.0    # how fast it leaves the lava...
const RISE_SLOWING := 1.1    # ...slowing as it cools
const SWAY := 14.0           # how far a ribbon wavers side to side, at the top of its rise
const OUTER := Color(0.58, 0.57, 0.62)
const CORE := Color(0.86, 0.84, 0.82)
const EMBER := Color(1.0, 0.62, 0.3)

var seconds := 2.0  # how long it keeps streaming up

var _t := 0.0
var _streamers: Array = []  # each: {x, phase, wave, from, to, next, points: [[born, x0]]}

func _ready() -> void:
	z_index = 4
	z_as_relative = false
	for i in STREAMERS:
		var from := randf_range(0.0, seconds * 0.35) if i > 0 else 0.0
		_streamers.append({
			"x": (i - (STREAMERS - 1) / 2.0) * 11.0 + randf_range(-3.0, 3.0),
			"phase": randf() * TAU,
			"wave": randf_range(2.6, 3.6) * (1.0 if i % 2 == 0 else -1.0),
			"from": from,
			"to": randf_range(seconds * 0.6, seconds),
			"next": from,
			"points": [],
		})

func _process(delta: float) -> void:
	_t += delta
	var alive := false
	for s: Dictionary in _streamers:
		while _t >= s.next and s.next <= s.to:
			s.points.append(s.next)
			s.next += EMIT_EVERY
		while s.points.size() > 0 and _t - s.points[0] > LIFE:
			s.points.pop_front()
		alive = alive or s.points.size() > 0 or s.next <= s.to
	if not alive:
		queue_free()
	queue_redraw()

# Where the bit of a ribbon that left the lava at `born` has got to by now
func _at(s: Dictionary, born: float) -> Vector2:
	var age := _t - born
	var rise := RISE_SPEED * (1.0 - exp(-RISE_SLOWING * age)) / RISE_SLOWING
	var spread := minf(age / LIFE, 1.0)
	var sway := SWAY * spread * sin(s.phase + born * s.wave)
	return Vector2(s.x * (1.0 + spread) + sway, -rise)

func _draw() -> void:
	for layer in 2:  # the dark edge of each ribbon, then its pale core over it
		for s: Dictionary in _streamers:
			var pts: Array = s.points
			for i in range(pts.size() - 1, 0, -1):
				var born: float = pts[i]
				var age := (_t - born) / LIFE
				var a := _at(s, born)
				var b := _at(s, pts[i - 1])
				var fade := 1.0 - smoothstep(0.45, 1.0, age)
				var wide := 4.0 if age < 0.3 else (3.0 if age < 0.6 else 2.0)
				var col: Color
				if layer == 0:
					col = OUTER
					col.a = 0.75 * fade
				else:
					wide = wide - 2.0
					if wide <= 0.0:
						continue
					col = EMBER.lerp(CORE, smoothstep(0.0, 0.15, age))
					col.a = 0.9 * fade
				_ribbon(a, b, wide, col)

# A stretch of ribbon from a to b, `wide` art pixels across, laid on the art-pixel grid
func _ribbon(a: Vector2, b: Vector2, wide: float, col: Color) -> void:
	var steps := maxi(1, ceili(a.distance_to(b) / PX.y))
	var size := Vector2(wide * PX.x, PX.y)
	for k in steps:
		var p := a.lerp(b, float(k) / steps)
		var cell := (p / PX).floor() * PX
		draw_rect(Rect2(cell - Vector2(floorf(wide / 2.0) * PX.x, 0.0), size), col)
