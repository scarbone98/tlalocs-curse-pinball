extends Node2D
## The golden temple, top right: Tlaloc's shrine. Both wire rails run into it (the left
## rail's upper branch through its pipe, the right rail up its chute). A ball that gets
## inside races round the temple's ring a couple of times, like the loop inside the
## structure on Pokemon Pinball Sapphire's field, while Tlaloc's eyes blaze. The offering
## stirs him a step toward his curse (the spirits come from the right lane now,
## Scripts/spirit_lane.gd). Then the temple sends the ball
## back out through its pipe and all the way down the left rail. The blue gems round the
## temple's ring light up one after another as the ball races past them inside.

const Geometry := preload("res://Scripts/rails_geometry.gd")
const TableGeometry := preload("res://Scripts/table_geometry.gd")
const GEMS_LIT := preload("res://Sprites/table/temple_gems_lit.png")  # tools/make_table.py
const GEM_GLOW_SECONDS := 0.3   # a gem stays lit this long after the ball passes it
const GEM_REACH := 0.45         # radians either side of a gem the ball lights it from

const CATCH_RADIUS := 30.0
# The ring the ball races round inside (scene units; the temple's round body)
const LOOP_CENTRE := Vector2(588, 182)
const LOOP_RADIUS := Vector2(72, 78)
const LOOP_LAPS := 2.0
const LOOP_SECONDS := 1.5
const SPIT_FROM := Vector2(440, 100)   # just back down the pipe, on the rail's upper branch
const SPIT_VELOCITY := Vector2(-760, 30)
const REARM_SECONDS := 1.0
const OFFERING_POINTS := 2500
const ARROWS_TO_SUMMON := 2

var features: Node2D  # TableFeatures, which owns the shrine's eyes and scoring helpers

var _held: RigidBody2D
var _rearm := 0.0
var _gems: Array[Sprite2D] = []
var _gem_angles: Array[float] = []
var _gem_glow: Array[float] = []
var _ring_centre := Vector2.ZERO

func _ready() -> void:
	_ring_centre = TableGeometry.TEMPLE_RING_CENTRE * features.MAP_SCALE
	for gem: Array in TableGeometry.TEMPLE_GEMS:
		var lit := Sprite2D.new()
		lit.texture = GEMS_LIT
		lit.region_enabled = true
		lit.region_rect = gem[1]
		lit.scale = features.MAP_SCALE
		lit.position = (gem[0] as Vector2) * features.MAP_SCALE
		lit.z_index = 4  # over the temple's art (the top layer)
		lit.z_as_relative = false
		lit.visible = false
		features.add_child(lit)
		_gems.append(lit)
		_gem_angles.append((lit.position - _ring_centre).angle())
		_gem_glow.append(0.0)

# Each gem the ball is passing lights up, and fades just behind it: a ring chasing it round
func _light_gems(delta: float) -> void:
	var angle := (_held.global_position - _ring_centre).angle() if _held else INF
	for i in _gems.size():
		if _held and absf(angle_difference(angle, _gem_angles[i])) < GEM_REACH:
			_gem_glow[i] = GEM_GLOW_SECONDS
		_gem_glow[i] = maxf(_gem_glow[i] - delta, 0.0)
		_gems[i].visible = _gem_glow[i] > 0.0
		_gems[i].modulate.a = clampf(_gem_glow[i] / GEM_GLOW_SECONDS * 1.5, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	_rearm = maxf(_rearm - delta, 0.0)
	_light_gems(delta)
	if _held or _rearm > 0.0:
		return
	var pipe: Vector2 = Geometry.OPENINGS["left_pipe"][0]
	var chute: Vector2 = Geometry.OPENINGS["right_top"][0]
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if ball.freeze or (ball.collision_mask & 2) == 0:
			continue
		var p := ball.global_position
		if (p.distance_to(pipe) < CATCH_RADIUS and ball.linear_velocity.x > 0.0) \
				or (p.distance_to(chute) < CATCH_RADIUS and ball.linear_velocity.y < 0.0):
			_swallow(ball)
			return

func _swallow(ball: RigidBody2D) -> void:
	_held = ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	ball.z_index = 1  # under the temple's art, out of sight inside it
	var start := (ball.global_position - LOOP_CENTRE) / LOOP_RADIUS
	var from_angle := atan2(start.y, start.x)
	var loop := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	loop.tween_method(func(t: float):
		var angle := from_angle - t * TAU * LOOP_LAPS
		ball.global_position = LOOP_CENTRE + Vector2(cos(angle), sin(angle)) * LOOP_RADIUS,
		0.0, 1.0, LOOP_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop.tween_callback(_offering)
	loop.tween_interval(0.3)
	loop.tween_callback(_spit.bind(ball))
	AudioSfx.play("shrine")
	PinballEvents.rumble.emit(4.0)
	features._flash_shrine(LOOP_SECONDS + 0.3)

func _offering() -> void:
	for i in _gems.size():
		_gem_glow[i] = GEM_GLOW_SECONDS * 2.0  # the whole ring blazes as the offering's made
	features._award(OFFERING_POINTS, LOOP_CENTRE + Vector2(0, 60))
	PinballEvents.toast.emit("An offering to Tlaloc!")
	PinballEvents.effect.emit("gold", LOOP_CENTRE)
	features.stir_tlaloc()
	if features.ramps.arrows["summon"] >= ARROWS_TO_SUMMON:
		features.ramps.clear_arrows("summon")  # they sent it here; now they start again

func _spit(ball: RigidBody2D) -> void:
	_held = null
	_rearm = REARM_SECONDS
	ball.global_position = SPIT_FROM
	ball.freeze = false
	ball.linear_velocity = SPIT_VELOCITY.rotated(randf_range(-0.1, 0.1)) * randf_range(0.8, 1.15)  # never quite the same twice
	features.rails.lift(ball, "left_temple")  # back down the pipe and all the way down the left rail
	AudioSfx.play("shrine_out")
	PinballEvents.rumble.emit(3.0)
