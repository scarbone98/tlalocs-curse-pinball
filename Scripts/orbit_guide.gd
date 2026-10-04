extends Node2D
## The left orbit: a fast ball running along its outer wall - round over the top from the
## launch side and down the left lane, or up the torch lane and round the other way - is
## carried smoothly along a line a ball's radius in from the wall (Scripts/orbit_geometry.gd,
## from tools/make_orbit_path.py), the way the rails carry a riding ball. Left to the
## physics, a ball skidding round a tight curve of straight wall pieces hitches as it taps
## from one to the next. The table's gravity still slows it climbing and speeds it falling;
## one that slows right down is let go to fall back, and off either end it flies on as it
## was going. A slow ball, or one only grazing the wall, is the physics' own.

const Geometry := preload("res://Scripts/orbit_geometry.gd")

const ENGAGE_REACH := 10.0   # within this of the line...
const ENGAGE_SPEED := 320.0  # ...going at least this fast along it...
const ENGAGE_ALONG := 0.85   # ...and mostly along it (cosine), it's taken
const RELEASE_SPEED := 160.0 # slower than this, it's let go to fall back
const END_MARGIN := 6.0      # it isn't taken right at an end
const SETTLE_SECONDS := 0.1  # it slides onto the line this quickly
const BALL_RADIUS := 19.0
const BAKE_INTERVAL := 2.0

class Ride:
	var offset := 0.0
	var speed := 0.0   # along the line: + from the top run toward the lane, - back up it
	var drift := Vector2.ZERO

var features: Node2D  # TableFeatures
var _curve: Curve2D
var _rides := {}  # ball -> Ride
var _steer_call: Callable

func _ready() -> void:
	features.orbit_guide = self
	_curve = Curve2D.new()
	_curve.bake_interval = BAKE_INTERVAL
	for point: Vector2 in Geometry.PATH:
		_curve.add_point(point)
	_steer_call = _steer

## True while it's carrying this ball round
func carrying(ball: Node) -> bool:
	return _rides.has(ball)

func _tangent(offset: float) -> Vector2:
	var length := _curve.get_baked_length()
	var a := _curve.sample_baked(clampf(offset - 2.0, 0.0, length))
	var b := _curve.sample_baked(clampf(offset + 2.0, 0.0, length))
	return (b - a).normalized()

func _physics_process(_delta: float) -> void:
	for ball: RigidBody2D in _rides.keys():
		if not is_instance_valid(ball) or ball.freeze or ball.rail_guide != _steer_call:
			_rides.erase(ball)
	var length := _curve.get_baked_length()
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if _rides.has(ball) or ball.freeze or ball.rail_guide.is_valid() or not features._is_ball_on_playfield(ball):
			continue
		var at := ball.global_position
		var offset := _curve.get_closest_offset(at)
		if offset < END_MARGIN or offset > length - END_MARGIN:
			continue
		var on_line := _curve.sample_baked(offset)
		if at.distance_to(on_line) > ENGAGE_REACH:
			continue
		var v := ball.linear_velocity
		var along := v.dot(_tangent(offset))
		if absf(along) < ENGAGE_SPEED or absf(along) < ENGAGE_ALONG * v.length():
			continue
		var ride := Ride.new()
		ride.offset = offset
		ride.speed = along
		ride.drift = at - on_line
		_rides[ball] = ride
		ball.rail_guide = _steer_call

## From the ball's _integrate_forces while it's carried: on along the line. False once let go.
func _steer(ball: RigidBody2D, state: PhysicsDirectBodyState2D) -> bool:
	var ride: Ride = _rides.get(ball)
	if ride == null:
		ball.rail_guide = Callable()
		return false
	var dt := state.step
	var tangent := _tangent(ride.offset)
	var v := tangent * ride.speed
	ride.speed += ball._gravity(v.y) * tangent.y * dt  # the table's own gravity, along the line
	ride.offset += ride.speed * dt
	ride.drift = ride.drift.lerp(Vector2.ZERO, minf(dt / SETTLE_SECONDS, 1.0))
	var length := _curve.get_baked_length()
	var off_end := ride.offset <= 0.0 or ride.offset >= length
	ride.offset = clampf(ride.offset, 0.0, length)
	tangent = _tangent(ride.offset)
	var xf := state.transform
	xf.origin = _curve.sample_baked(ride.offset) + ride.drift
	state.transform = xf
	state.linear_velocity = tangent * ride.speed
	state.angular_velocity = 0.0
	ball.set("_spin", clampf(-ride.speed / BALL_RADIUS, -ball.MAX_DRAWN_SPIN, ball.MAX_DRAWN_SPIN))  # rolling along the wall
	if off_end or absf(ride.speed) < RELEASE_SPEED:
		_rides.erase(ball)
		ball.rail_guide = Callable()  # the physics' own again, going as it was
		return false
	return true
