extends Node2D
## The two wire rails (Sprites/layers/rails.png), the table's ramps.
##
##  - the left rail starts low on the left, runs up and round the top of the table, and
##    forks: its lower branch drops the ball onto the top lanes, its upper branch runs into
##    the temple's pipe. A diverter at the fork sends the ball up the upper branch when two
##    Summon arrows are lit, down onto the top lanes otherwise.
##  - the right rail starts at the mouth of the right-hand U lane and climbs straight up
##    into the temple's chute.
##
## A ball riding a rail is carried along the middle of its track (traced from the art by
## tools/make_table.py into Scripts/rails_geometry.gd PATHS), the way a wire ramp holds a
## real ball: it doesn't rattle between the wires, it just slows as it climbs and speeds
## up coming down. A ball that comes into a rail's mouth heading up it is lifted on; one
## that runs out of a rail's end, or rolls back out of its mouth, is let go there (the
## temple catches one running into it, Scripts/temple.gd).

const Geometry := preload("res://Scripts/rails_geometry.gd")

const RAIL_LAYER := 2
const ENTRIES := {  # opening -> the way up the rail from its mouth
	"left_entry": Vector2(-0.46, -0.89),  # up the chute at the rail's foot
	"right_entry": Vector2(0.55, -0.84),
}
const ARROWS_TO_TEMPLE := 2
# Where a ball heading up a rail is lifted on. Each mouth sits right beside another lane
# (the blue flippers' lane right of the left one, the skull's lane left of the right
# one), so only a ball heading along the rail is taken: within this much of its line
const ENTRY_AREAS := {
	"left_entry": Rect2(145, 665, 60, 50),
	"right_entry": Rect2(496, 715, 34, 55),  # below its mouth, which is barely wider than the ball
}
const ENTRY_ALIGN := {"left_entry": 0.94, "right_entry": 0.94}  # cosines: about 20 degrees
# ...and only on the rail's own line: the lanes running up under the rails, beside their
# mouths, head the same way, so a ball has to be within this much of the track's middle
# (or of the line it runs in on, short of the mouth)
const ENTRY_LATERAL := 40.0
const RAIL_GRAVITY := 650.0  # pulls a riding ball back down the slope (scene units/s²)
const RAIL_DRAG := 40.0      # speed lost each second to the wires
const SETTLE_SECONDS := 0.12 # a ball lifted on slides over onto the track's middle this quickly
const MIN_ENTRY_SPEED := 300.0
const BAKE_INTERVAL := 2.0
# Paths that end in the temple: running out of them, the ball carries on into it
const INTO_TEMPLE := ["left_temple", "right"]
# A ball coming all the way back down a rail leaves its mouth on its own, a little
# differently each time, rather than being placed
const MOUTH_SPREAD := 0.25            # radians either way
const MOUTH_SPEED := Vector2(0.75, 1.0)  # of the speed it came down with
# An emerald waits up the left rail; a ball riding past takes it, and another one turns
# up a while later
const GEM := preload("res://Sprites/table/rail_gem.png")  # tools/make_table.py: plain, glinting
const GEM_ALONG := 0.35   # how far up the left rail it sits
const GEM_REACH := 26.0
const GEM_POINTS := 5000
const GEM_BEADS := 5
const GEM_RETURN_SECONDS := 20.0

var features: Node2D  # TableFeatures

var to_temple := false

var _curves := {}  # path name -> Curve2D
var _fork_offset := 0.0  # along the left rail: short of here the diverter can still switch a ball
var _rides := {}  # ball -> Ride
var _gem: AnimatedSprite2D
var _gem_left := 0.0  # until the next emerald turns up
var _clock := 0.0

class Ride:
	var path: String
	var offset := 0.0
	var speed := 0.0
	var drift := Vector2.ZERO  # how far off the middle it was lifted on, settling away

func _ready() -> void:
	for path_name: String in Geometry.PATHS:
		_curves[path_name] = _curve(Geometry.PATHS[path_name])
	var left: Curve2D = _curves["left_lanes"]
	_gem = features._sprite(GEM, 2, left.sample_baked(left.get_baked_length() * GEM_ALONG))
	_gem.z_index = 3  # on the rail's art, under a ball riding past (z 4)
	_gem.z_as_relative = false
	# the left rail's two paths share their trunk up to the fork
	var lanes: Array = Geometry.PATHS["left_lanes"]
	var temple: Array = Geometry.PATHS["left_temple"]
	var shared := 0
	while shared < mini(lanes.size(), temple.size()) and lanes[shared] == temple[shared]:
		shared += 1
	_fork_offset = (_curves["left_lanes"] as Curve2D).get_closest_offset(lanes[maxi(shared - 3, 0)])
	for opening: String in ENTRIES:
		var rect: Rect2 = ENTRY_AREAS[opening]
		_add_area(rect.get_center(), rect.size, _on_entry.bind(opening))

# A smooth curve through the points: each one's handles point along the line from the
# point before it to the one after (Catmull-Rom)
func _curve(points: Array) -> Curve2D:
	var curve := Curve2D.new()
	curve.bake_interval = BAKE_INTERVAL
	for i in points.size():
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)]
		var handle := (after - before) / 6.0
		curve.add_point(points[i], -handle, handle)
	return curve

func _add_area(at: Vector2, size: Vector2, on_ball: Callable) -> void:
	var area := Area2D.new()
	area.position = at
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(on_ball)
	add_child(area)

func _on_entry(body: Node, opening: String) -> void:
	var ball := body as RigidBody2D
	if ball == null or not ball.is_in_group("ball") or ball.freeze or ball.collision_mask == 0:
		return
	if _rides.has(ball) or (ball.collision_mask & RAIL_LAYER) != 0:
		return
	var up: Vector2 = ENTRIES[opening]
	if ball.linear_velocity.normalized().dot(up) <= ENTRY_ALIGN[opening]:
		return
	var path := "right"
	if opening == "left_entry":
		path = "left_temple" if to_temple else "left_lanes"
	if _off_line(ball.global_position, _curves[path]) > ENTRY_LATERAL:
		return  # beside the mouth, under the rail: it stays on the playfield
	lift(ball, path)

# How far a point is from a track's middle; short of its mouth, from the line it runs in on
func _off_line(at: Vector2, curve: Curve2D) -> float:
	var mouth := curve.sample_baked(0.0)
	var way_in := _tangent(curve, 0.0)
	var rel := at - mouth
	if rel.dot(way_in) < 0.0:
		return absf(rel.cross(way_in))
	return at.distance_to(curve.get_closest_point(at))

## Puts a ball on a rail, carried on along it at the speed it's going that way (the
## entries, and the temple sending it back down). With no path named, the nearest.
func lift(ball: RigidBody2D, path: String = "") -> void:
	var at := ball.global_position
	if path == "":
		var best := INF
		for name: String in _curves:
			var near: Curve2D = _curves[name]
			var d := at.distance_to(near.get_closest_point(at))
			if d < best:
				best = d
				path = name
	var ride := Ride.new()
	ride.path = path
	var curve: Curve2D = _curves[path]
	ride.offset = curve.get_closest_offset(at)
	ride.drift = at - curve.sample_baked(ride.offset)
	ride.speed = ball.linear_velocity.dot(_tangent(curve, ride.offset))
	if absf(ride.speed) < MIN_ENTRY_SPEED:
		ride.speed = MIN_ENTRY_SPEED * (-1.0 if ride.speed < 0.0 else 1.0)
	_rides[ball] = ride
	ball.collision_mask = RAIL_LAYER
	ball.z_index = 4  # over the rails' art (the top layer, z 3)
	ball.sleeping = false
	ball.rail_guide = _steer

func _tangent(curve: Curve2D, offset: float) -> Vector2:
	var length := curve.get_baked_length()
	var a := curve.sample_baked(clampf(offset - 2.0, 0.0, length))
	var b := curve.sample_baked(clampf(offset + 2.0, 0.0, length))
	return (b - a).normalized()

## Called from the ball's _integrate_forces while it rides: moves it on along its track.
## Returns false once the ball has left the rail (it's then the ball's own physics again).
func _steer(ball: RigidBody2D, state: PhysicsDirectBodyState2D) -> bool:
	var ride: Ride = _rides.get(ball)
	if ride == null:
		return false
	var dt := state.step
	# the diverter: up the trunk, the ball is switched to the branch it should take
	if ride.path in ["left_lanes", "left_temple"] and ride.offset < _fork_offset and ride.speed > 0.0:
		ride.path = "left_temple" if to_temple else "left_lanes"
	var curve: Curve2D = _curves[ride.path]
	var tangent := _tangent(curve, ride.offset)
	ride.speed += RAIL_GRAVITY * tangent.y * dt
	ride.speed -= signf(ride.speed) * minf(RAIL_DRAG * dt, absf(ride.speed))
	ride.offset += ride.speed * dt
	ride.drift = ride.drift.lerp(Vector2.ZERO, minf(dt / SETTLE_SECONDS, 1.0))
	var length := curve.get_baked_length()
	var off_end := ride.offset >= length
	var off_mouth := ride.offset <= 0.0
	ride.offset = clampf(ride.offset, 0.0, length)
	tangent = _tangent(curve, ride.offset)
	var xf := state.transform
	xf.origin = curve.sample_baked(ride.offset) + ride.drift
	state.transform = xf
	state.linear_velocity = tangent * ride.speed
	state.angular_velocity = 0.0
	if ride.path.begins_with("left_") and _gem.visible and xf.origin.distance_to(_gem.position) < GEM_REACH:
		_take_gem.call_deferred()
	if off_mouth:
		state.linear_velocity = (tangent * ride.speed).rotated(randf_range(-MOUTH_SPREAD, MOUTH_SPREAD)) 			* randf_range(MOUTH_SPEED.x, MOUTH_SPEED.y)
	if off_end or off_mouth:
		_rides.erase(ball)
		ball.rail_guide = Callable()
		if not (off_end and ride.path in INTO_TEMPLE):
			ball.drop_off_rail.call_deferred()  # onto the top lanes, or back out of its mouth
		# running into the temple it carries on still riding, for the temple to catch
		return false
	return true

func _take_gem() -> void:
	if not _gem.visible:
		return
	_gem.hide()
	_gem_left = GEM_RETURN_SECONDS
	features._award(GEM_POINTS, _gem.position)
	GameManager.add_beads(GEM_BEADS)
	PinballEvents.effect.emit("sparks", _gem.position)
	PinballEvents.toast.emit("Rail emerald! +%d jade" % GEM_BEADS)
	AudioSfx.play("catch")

func _physics_process(delta: float) -> void:
	to_temple = features.ramps.arrows["summon"] >= ARROWS_TO_TEMPLE
	_clock += delta
	_gem.frame = 1 if fposmod(_clock, 2.0) < 0.15 else 0  # a glint now and then
	if _gem_left > 0.0:
		_gem_left -= delta
		if _gem_left <= 0.0:
			_gem.show()
	for ball: RigidBody2D in _rides.keys():
		if not is_instance_valid(ball) or ball.freeze or (ball.collision_mask & RAIL_LAYER) == 0:
			_rides.erase(ball)
			if is_instance_valid(ball):
				ball.rail_guide = Callable()
