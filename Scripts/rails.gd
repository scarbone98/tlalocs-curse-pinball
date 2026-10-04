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
# The rail lines and lift boxes can be placed by hand in the editor: node_2d.tscn's RailEdits
# holds a Path2D for each line (left_lanes, left_temple, right) and an Area2D for each mouth's
# lift box (left_entry, right_entry). Without them, the traced lines (Scripts/rails_geometry.gd)
# and the boxes below are used. Each mouth's way up is the start of its line.
const ARROWS_TO_TEMPLE := 2
# Where a ball heading up a rail is lifted on. Each mouth sits right beside another lane
# (the blue flippers' lane right of the left one, the skull's lane left of the right
# one), so only a ball heading along the rail is taken: within this much of its line
const ENTRY_AREAS := {
	"left_entry": Rect2(128, 596, 52, 46),   # right in its mouth, between the wires' ends
	"right_entry": Rect2(500, 650, 60, 55),  # right in its mouth, as drawn
}
const ENTRY_ALIGN := {"left_entry": 0.94, "right_entry": 0.94}  # cosines: about 20 degrees
# ...and only on the rail's own line: the lanes running up under the rails, beside their
# mouths, head the same way, so a ball has to be within this much of the track's middle
# (or of the line it runs in on, short of the mouth)
const ENTRY_LATERAL := 60.0
const RAIL_GRAVITY := 650.0  # pulls a riding ball back down the slope (scene units/s²)
const RAIL_DRAG := 40.0      # speed lost each second to the wires
const SETTLE_SECONDS := 0.12 # a ball lifted on slides over onto the track's middle this quickly
const MIN_ENTRY_SPEED := 300.0
const BALL_RADIUS := 19.0      # for how fast it's drawn rolling along a track
const SWAY := 2.0              # scene units it sways either side of a track's middle
const SWAY_WAVELENGTH := 90.0  # ...over this much track
const RELEASE_EARLY := 26.0    # it leaves a track that drops it on the playfield this far short of its end
const END_SPREAD := 0.18       # radians either way it flies off the end
const END_SPEED_MIN := 160.0
const BAKE_INTERVAL := 2.0
# Paths that end in the temple: running out of them, the ball carries on into it
const INTO_TEMPLE := ["left_temple", "right"]
# A ball coming all the way back down a rail leaves its mouth on its own, a little
# differently each time, rather than being placed
const MOUTH_SPREAD := 0.25            # radians either way
const MOUTH_SPEED := Vector2(0.75, 1.0)  # of the speed it came down with
# An emerald waits up the left rail; a ball riding past takes it, and another one turns
# up a while later
const GEM := preload("res://Sprites/table/rail_gem.png")  # tools/make_table.py: a cut emerald, light sweeping over its facets
const GEM_FRAMES := 4
const GEM_FPS := 6.0
const GEM_SHADOW := preload("res://Sprites/table/rail_gem_shadow.png")
const GEM_ALONG := 0.6    # how far up the left rail it sits
const GEM_HOVER := 4.0    # art pixels it floats over its shadow
const GEM_BOB_SECONDS := 1.4
const GEM_REACH := 26.0
const GEM_POINTS := 5000
const GEM_RETURN_SECONDS := 20.0

var features: Node2D  # TableFeatures

var to_temple := false

var _curves := {}  # path name -> Curve2D
var _fork_offset := 0.0  # along the left rail: short of here the diverter can still switch a ball
var _rides := {}  # ball -> Ride
var _entry_areas := {}  # opening -> its Area2D
var entry_rects := {}  # opening -> its lift box (scene rect), as placed
var entry_dirs := {}   # opening -> the way up its rail from the mouth
var _gem: AnimatedSprite2D
var _gem_shadow: AnimatedSprite2D
var _gem_sparkles: CPUParticles2D
var _gem_left := 0.0  # until the next emerald turns up
var _clock := 0.0

class Ride:
	var path: String
	var offset := 0.0
	var speed := 0.0
	var drift := Vector2.ZERO  # how far off the middle it was lifted on, settling away

func _ready() -> void:
	var edits := features.get_node_or_null(^"../RailEdits")
	for path_name: String in Geometry.PATHS:
		var placed := edits.get_node_or_null(path_name) as Path2D if edits else null
		if placed and placed.curve and placed.curve.point_count > 1:
			_curves[path_name] = _from_path(placed)  # as placed by hand in the editor
		else:
			_curves[path_name] = _curve(Geometry.PATHS[path_name])
	var left: Curve2D = _curves["left_lanes"]
	var gem_at := left.sample_baked(left.get_baked_length() * GEM_ALONG)
	_gem_shadow = features._sprite(GEM_SHADOW, 1, gem_at + Vector2(0, 7) * features.MAP_SCALE)
	_gem = features._sprite(GEM, GEM_FRAMES, gem_at, GEM_FPS)
	_gem.play()
	_gem_sparkles = _sparkles(gem_at)
	for piece in [_gem_shadow, _gem]:
		piece.z_index = 3  # on the rail's art, under a ball riding past (z 4)
		piece.z_as_relative = false
	# the left rail's two paths share their trunk up to the fork
	_fork_offset = _fork(_curves["left_lanes"], _curves["left_temple"])
	for opening: String in ENTRY_ALIGN:
		entry_dirs[opening] = _tangent(_curves["right" if opening == "right_entry" else "left_lanes"], 0.0)
		var placed := edits.get_node_or_null(opening) as Area2D if edits else null
		if placed:
			placed.monitorable = false
			placed.body_entered.connect(_on_entry.bind(opening))
			_entry_areas[opening] = placed
			entry_rects[opening] = _area_rect(placed)
		else:
			var rect: Rect2 = ENTRY_AREAS[opening]
			entry_rects[opening] = rect
			_entry_areas[opening] = _add_area(rect.get_center(), rect.size, _on_entry.bind(opening))

# A line placed in the editor, as a curve in scene units
func _from_path(node: Path2D) -> Curve2D:
	var xf := node.global_transform
	var curve := Curve2D.new()
	curve.bake_interval = BAKE_INTERVAL
	for i in node.curve.point_count:
		curve.add_point(xf * node.curve.get_point_position(i), xf.basis_xform(node.curve.get_point_in(i)),
			xf.basis_xform(node.curve.get_point_out(i)))
	return curve

# A lift box placed in the editor, as a scene rect
func _area_rect(area: Area2D) -> Rect2:
	var shape := area.get_child(0) as CollisionShape2D
	var size: Vector2 = (shape.shape as RectangleShape2D).size * area.global_scale * shape.scale
	return Rect2(area.global_position + shape.position - size / 2.0, size)

# How far along the first line it runs together with the second, before they part
func _fork(a: Curve2D, b: Curve2D) -> float:
	var offset := 0.0
	while offset < a.get_baked_length():
		var at := a.sample_baked(offset)
		if at.distance_to(b.get_closest_point(at)) > 3.0:
			return maxf(offset - 12.0, 0.0)
		offset += 4.0
	return a.get_baked_length()

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

func _add_area(at: Vector2, size: Vector2, on_ball: Callable) -> Area2D:
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
	return area

func _on_entry(body: Node, opening: String) -> void:
	var ball := body as RigidBody2D
	if ball == null or not ball.is_in_group("ball") or ball.freeze or ball.collision_mask == 0:
		return
	if _rides.has(ball) or (ball.collision_mask & RAIL_LAYER) != 0:
		return
	var up: Vector2 = entry_dirs[opening]
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
	ball.set("_spin", clampf(ride.speed / BALL_RADIUS, -ball.MAX_DRAWN_SPIN, ball.MAX_DRAWN_SPIN))  # it rolls along the wires
	ride.speed -= signf(ride.speed) * minf(RAIL_DRAG * dt, absf(ride.speed))
	ride.offset += ride.speed * dt
	ride.drift = ride.drift.lerp(Vector2.ZERO, minf(dt / SETTLE_SECONDS, 1.0))
	var length := curve.get_baked_length()
	# short of a track's end that drops it on the playfield, it leaves under its own steam
	var release_at := length if ride.path in INTO_TEMPLE else length - RELEASE_EARLY
	var off_end := ride.offset >= release_at
	var off_mouth := ride.offset <= 0.0
	ride.offset = clampf(ride.offset, 0.0, length)
	tangent = _tangent(curve, ride.offset)
	var xf := state.transform
	# a little sway from wire to wire as it goes, rather than running dead on the line
	var sway := tangent.orthogonal() * sin(ride.offset / SWAY_WAVELENGTH * TAU) * SWAY
	xf.origin = curve.sample_baked(ride.offset) + ride.drift + sway
	state.transform = xf
	state.linear_velocity = tangent * ride.speed
	state.angular_velocity = 0.0
	if ride.path.begins_with("left_") and _gem.visible and xf.origin.distance_to(_gem.position) < GEM_REACH:
		_take_gem.call_deferred()
	if off_mouth:
		state.linear_velocity = (tangent * ride.speed).rotated(randf_range(-MOUTH_SPREAD, MOUTH_SPREAD)) 			* randf_range(MOUTH_SPEED.x, MOUTH_SPEED.y)
	elif off_end and not ride.path in INTO_TEMPLE:
		# off the end it flies on as it was going, a little differently each time
		state.linear_velocity = (tangent * maxf(ride.speed, END_SPEED_MIN)).rotated(randf_range(-END_SPREAD, END_SPREAD))
	if off_end or off_mouth:
		_rides.erase(ball)
		ball.rail_guide = Callable()
		if not (off_end and ride.path in INTO_TEMPLE):
			ball.drop_off_rail.call_deferred()  # onto the top lanes, or back out of its mouth
		# running into the temple it carries on still riding, for the temple to catch
		return false
	return true

# Green and white glints twinkling round the emerald
func _sparkles(at: Vector2) -> CPUParticles2D:
	var dot := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var sparkles := CPUParticles2D.new()
	sparkles.texture = ImageTexture.create_from_image(dot)
	sparkles.amount = 6
	sparkles.lifetime = 1.0
	sparkles.position = at + Vector2(0, -12)
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(26, 24)
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 40.0
	sparkles.initial_velocity_min = 6.0
	sparkles.initial_velocity_max = 18.0
	sparkles.gravity = Vector2.ZERO
	sparkles.scale_amount_min = 2.9
	sparkles.scale_amount_max = 2.9
	var twinkle := Gradient.new()
	twinkle.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	twinkle.colors = PackedColorArray([Color(0.6, 1.0, 0.75, 0.0), Color(1, 1, 1, 1), Color(0.4, 1.0, 0.6, 0.8), Color(0.2, 0.9, 0.5, 0.0)])
	sparkles.color_ramp = twinkle
	sparkles.z_index = 4
	sparkles.z_as_relative = false
	features.add_child(sparkles)
	return sparkles

func _take_gem() -> void:
	if not _gem.visible:
		return
	_gem.hide()
	_gem_shadow.hide()
	_gem_left = GEM_RETURN_SECONDS
	features._award(GEM_POINTS, _gem.position)
	PinballEvents.effect.emit("sparks", _gem.position)
	AudioSfx.play("catch")

func _physics_process(delta: float) -> void:
	to_temple = features.ramps.arrows["summon"] >= ARROWS_TO_TEMPLE
	# a ball already in a mouth that turns to head up it (off a bounce, say) is taken too
	for opening: String in _entry_areas:
		for body in (_entry_areas[opening] as Area2D).get_overlapping_bodies():
			_on_entry(body, opening)
	_clock += delta
	_gem_sparkles.emitting = _gem.visible
	_gem.offset.y = -GEM_HOVER - (1.0 if fposmod(_clock / GEM_BOB_SECONDS, 1.0) < 0.5 else 0.0)  # hovering, bobbing
	if _gem_left > 0.0:
		_gem_left -= delta
		if _gem_left <= 0.0:
			_gem.show()
			_gem_shadow.show()
	for ball: RigidBody2D in _rides.keys():
		if not is_instance_valid(ball) or ball.freeze or (ball.collision_mask & RAIL_LAYER) == 0:
			_rides.erase(ball)
			if is_instance_valid(ball):
				ball.rail_guide = Callable()
