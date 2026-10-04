extends Node2D
## The orbits: a fast ball running along an orbit's outer wall is carried smoothly along a
## line a ball's radius in from the wall, the way the rails carry a riding ball. Left to the
## physics, a ball skidding round a tight curve of straight wall pieces hitches as it taps
## from one to the next. The table's gravity still slows it climbing and speeds it falling;
## one that slows right down is let go to fall back, and off either end it flies on as it
## was going. A slow ball, or one only grazing the wall, is the physics' own.
##
## The lines are placed by hand in the editor (node_2d.tscn's RailEdits):
##  - orbit_guide: the left orbit, round over the top and down the left lane, either way
##  - launch_guide: up out of the launch tube and round the top-right orbit, only that way
##    (a ball coming round the other way is left to meet the flap over the tube)
## Without them, the lines generated from the walls are used (Scripts/orbit_geometry.gd,
## from tools/make_orbit_path.py).

const Geometry := preload("res://Scripts/orbit_geometry.gd")

const ENGAGE_REACH := 10.0   # within this of a line...
const ENGAGE_SPEED := 320.0  # ...going at least this fast along it...
const ENGAGE_ALONG := 0.85   # ...and mostly along it (cosine), it's taken
const RELEASE_SPEED := 160.0 # slower than this, it's let go to fall back
const END_MARGIN := 6.0      # it isn't taken right at an end
const SETTLE_SECONDS := 0.1  # it slides onto the line this quickly
const BALL_RADIUS := 19.0
const BAKE_INTERVAL := 2.0
const LINES := {"orbit_guide": false, "launch_guide": true}  # name -> one way only (from its start)

class Line:
	var curve: Curve2D
	var one_way := false

class Ride:
	var line: Line
	var offset := 0.0
	var speed := 0.0   # along the line: + from its start toward its end
	var drift := Vector2.ZERO

var features: Node2D  # TableFeatures
var _lines: Array[Line] = []
var _curve: Curve2D  # the left orbit's (the debug view draws all of them: lines())
var _rides := {}  # ball -> Ride
var _steer_call: Callable

func _ready() -> void:
	features.orbit_guide = self
	for name: String in LINES:
		var placed := features.get_node_or_null(NodePath("../RailEdits/" + name)) as Path2D
		var curve := Curve2D.new()
		curve.bake_interval = BAKE_INTERVAL
		if placed and placed.curve and placed.curve.point_count > 1:
			var xf := placed.global_transform
			for i in placed.curve.point_count:
				curve.add_point(xf * placed.curve.get_point_position(i), xf.basis_xform(placed.curve.get_point_in(i)),
					xf.basis_xform(placed.curve.get_point_out(i)))
		else:
			for point: Vector2 in (Geometry.PATH if name == "orbit_guide" else Geometry.LAUNCH_PATH):
				curve.add_point(point)
		var line := Line.new()
		line.curve = curve
		line.one_way = LINES[name]
		_lines.append(line)
		if name == "orbit_guide":
			_curve = curve
	_steer_call = _steer

## True while it's carrying this ball round
func carrying(ball: Node) -> bool:
	return _rides.has(ball)

## Every guide line's curve (for the debug view)
func lines() -> Array[Curve2D]:
	var out: Array[Curve2D] = []
	for line in _lines:
		out.append(line.curve)
	return out

func _tangent(curve: Curve2D, offset: float) -> Vector2:
	var length := curve.get_baked_length()
	var a := curve.sample_baked(clampf(offset - 2.0, 0.0, length))
	var b := curve.sample_baked(clampf(offset + 2.0, 0.0, length))
	return (b - a).normalized()

func _physics_process(_delta: float) -> void:
	for ball: RigidBody2D in _rides.keys():
		if not is_instance_valid(ball) or ball.freeze or ball.rail_guide != _steer_call:
			_rides.erase(ball)
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if _rides.has(ball) or ball.freeze or ball.rail_guide.is_valid() or not features._is_ball_on_playfield(ball):
			continue
		for line in _lines:
			if _engage(ball, line):
				break

func _engage(ball: RigidBody2D, line: Line) -> bool:
	var curve := line.curve
	var length := curve.get_baked_length()
	var at := ball.global_position
	var offset := curve.get_closest_offset(at)
	if offset < END_MARGIN or offset > length - END_MARGIN:
		return false
	var on_line := curve.sample_baked(offset)
	if at.distance_to(on_line) > ENGAGE_REACH:
		return false
	var v := ball.linear_velocity
	var along := v.dot(_tangent(curve, offset))
	if absf(along) < ENGAGE_SPEED or absf(along) < ENGAGE_ALONG * v.length():
		return false
	if line.one_way and along < 0.0:
		return false  # only out of the launch tube, never back toward it
	var ride := Ride.new()
	ride.line = line
	ride.offset = offset
	ride.speed = along
	ride.drift = at - on_line
	_rides[ball] = ride
	ball.rail_guide = _steer_call
	return true

## From the ball's _integrate_forces while it's carried: on along the line. False once let go.
func _steer(ball: RigidBody2D, state: PhysicsDirectBodyState2D) -> bool:
	var ride: Ride = _rides.get(ball)
	if ride == null:
		ball.rail_guide = Callable()
		return false
	var curve := ride.line.curve
	var dt := state.step
	var tangent := _tangent(curve, ride.offset)
	var v := tangent * ride.speed
	ride.speed += ball._gravity(v.y) * tangent.y * dt  # the table's own gravity, along the line
	ride.offset += ride.speed * dt
	ride.drift = ride.drift.lerp(Vector2.ZERO, minf(dt / SETTLE_SECONDS, 1.0))
	var length := curve.get_baked_length()
	var off_end := ride.offset <= 0.0 or ride.offset >= length
	ride.offset = clampf(ride.offset, 0.0, length)
	tangent = _tangent(curve, ride.offset)
	var xf := state.transform
	xf.origin = curve.sample_baked(ride.offset) + ride.drift
	state.transform = xf
	state.linear_velocity = tangent * ride.speed
	state.angular_velocity = 0.0
	ball.set("_spin", clampf(-ride.speed / BALL_RADIUS, -ball.MAX_DRAWN_SPIN, ball.MAX_DRAWN_SPIN))  # rolling along the wall
	if off_end or absf(ride.speed) < RELEASE_SPEED:
		_rides.erase(ball)
		ball.rail_guide = Callable()  # the physics' own again, going as it was
		return false
	return true
