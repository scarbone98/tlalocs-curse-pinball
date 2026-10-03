extends RigidBody2D

## The plunger is a spring under the ball, like Pokemon Pinball Ruby & Sapphire's: hold
## launch and it pulls down (the ball resting on it sinks with it) the longer it's held,
## then let go and it fires the ball as hard as it was pulled. Scripts/plunger.gd is the
## spring.
@export var launch_speed: float = -1420.0
@export var min_launch_power: float = 0.5   # a tap; a weak one rolls back down the lane
@export var pull_seconds: float = 1.0       # to pull it all the way down
## The hand-drawn ball (tools/source_art/pinball_sprite.png) is drawn at 3x, about 1.2x
## the collision circle. Pokemon Pinball draws its ball bigger still (a 16px sprite
## colliding as a 4px-radius circle), but here that spilled too far over the walls and
## posts the ball passes; this still fits the same gaps. It stays upright and its 16
## frames roll it round, which is what makes it look solid. Its spin copies Pokemon
## Pinball: every contact sets the spin from how fast the ball is sliding along the
## surface, and the ball keeps that spin in the air.
const SPIN_FRAMES := 16  # Sprites/ball_spin.png, one full turn per row
const SPIN_SHEET := preload("res://Sprites/ball_spin.png")
const SPIN_SIZE := 16
## The roll is drawn no faster than this (about 3 turns a second, 48 frames a second), so
## each hand-drawn frame still shows on screen and the ball reads as turning, not strobing
const MAX_DRAWN_SPIN := TAU * 3.0
## Tuned to Pokemon Pinball Ruby & Sapphire's engine (pret/pokepinballrs), at 60 frames
## a second. The table's ramps and orbits were laid out for the Game Boy game's reach,
## 1px there to 4.3 units here, so the GBA's numbers use that scale too and a good shot
## still makes the ramps:
##  - no friction or drag. Gravity weakens as the ball falls faster, so falls float:
##    12/256 px/frame^2 (726 here) while it's slow, 8/256 (484) once it falls faster
##    than 1.25 px/frame (322), and 4/256 (242) past 2.5 px/frame (645)
##  - walls hand back about a quarter of the speed going into them (bounce 0.26)
##  - one limit on the ball's whole speed, not one per axis, higher down around the
##    flippers so the flipper zone plays faster. The GBA's are 5.25 and 6.25 px/frame
##    (1355 and 1613 here), raised about a fifth so the table's ramps, laid out for the
##    Game Boy game's faster ball, still make as often as before.
##    The plunger lane is left out, so a launch always makes it round the orbit.
@export var bounce: float = 0.26
@export var max_speed: float = 1650.0
@export var max_speed_low: float = 1900.0
const GRAVITY_BANDS := [[645.0, 242.0], [322.0, 484.0], [-INF, 726.0]]  # falling faster than -> gravity
const PLUNGER_LANE_X := 655.0
## The side ramps are water channels (collision layer 2, switched on by the gates). Like
## Pokemon Pinball's ramps they're plain physics with the table's own gravity: a good
## shot makes it round, a weak one rolls back out of the mouth.
## Ball search, like a real machine's: a ball that stays inside a small circle this long
## (say, pinned between a bumper and a wall) gets knocked back toward the middle of the
## table. The flipper area is left alone so a cradled ball stays put.
@export var stuck_seconds: float = 1.5
@export var stuck_radius: float = 40.0
@export var unstick_speed: float = 700.0
const UNSTICK_TOWARD := Vector2(340, 760)
const CRADLE_Y := 1080.0  # below this the ball is on or around the flippers
## The gates put a ball on the ramp colliders as it passes a ramp mouth. One that clips
## the lip and bounces back out would then ignore every playfield wall and fall off the
## table, so a ramp ball that stays out of the ramp zone this long goes back to the
## playfield. The zone is the ramp art with the gaps between its rails filled in
## (tools/make_ramp_zone.py), so a ball rolling up the middle of a ramp stays on it.
@export var off_ramp_grace: float = 0.15
const RAMP_ZONE := preload("res://Sprites/ramp_zone.png")
## Pokemon Pinball rumbles on any collision faster than 3 px/frame into the surface
## (770 here); harder hits shake more.
const IMPACT_SPEED := 770.0
const IMPACT_RUMBLE_PER_SPEED := 1.0 / 400.0
const IMPACT_MAX_RUMBLE := 3.0  # a wall never shakes as hard as the table's big moments
const IMPACT_COOLDOWN := 0.12
const ART_PER_SCENE := Vector2(256.0 / 720.0, 424.0 / 1280.0)
# Inside the golden temple, where the rails end (Scripts/temple.gd), counts as on the rails
const SHRINE_CHUTE := Rect2(439, 42, 281, 290)

var can_launch: bool = false
var spawn_xform: Transform2D
var _pending_respawn: bool = false
var _restore_layers: int
var _restore_mask: int
var _restore_z: int
var _cooldown_frames: int = 0
var _charging := false
var _charge_seconds := 0.0
var _was_on_ramp := false
var _ramp_trail: CPUParticles2D
var _stuck_anchor := Vector2.ZERO
var _stuck_time := 0.0
var _off_ramp_time := 0.0
var _moved_v := Vector2.ZERO   # what it moved at last step
var draw_scale := Vector2.ONE  # the sprite's scale as set in the scene (the table art's own)
var stage_origin := Vector2.ZERO  # top left of the table the ball is on (El Dorado is below)
var _spin := 0.0   # radians per second, clockwise
## Set by Scripts/rails.gd while the ball rides a rail: carries it along the track
var rail_guide := Callable()
var _impact_cooldown := 0.0
var _turn := 0.0   # how far the sprite has turned
static var _ramp_art: Image
static var _tier_frames := {}  # tier -> SpriteFrames for that row of the spin sheet

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	spawn_xform = global_transform
	_restore_layers = collision_layer
	_restore_mask = collision_mask
	_restore_z = z_index
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = bounce
	physics_material_override = mat
	gravity_scale = 0.0  # gravity is applied in _integrate_forces, by speed band
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = DAMP_MODE_REPLACE
	angular_damp = 0.0
	_build_ramp_trail()
	if _ramp_art == null:
		_ramp_art = RAMP_ZONE.get_image()

	var start_region: Area2D = get_tree().get_first_node_in_group("launch_region") as Area2D
	if start_region:
		start_region.body_entered.connect(_on_start_region_body_entered)
		start_region.body_exited.connect(_on_start_region_body_exited)

	for dz in get_tree().get_nodes_in_group("death_zone"):
		var area := dz as Area2D
		if area:
			area.body_entered.connect(_on_death_zone_body_entered)

	PinballEvents.launch_pressed.connect(_begin_charge)
	PinballEvents.launch_released.connect(_release_charge)

	PinballEvents.ball_tier_changed.connect(set_tier)
	max_contacts_reported = 4  # to read the surface the ball is rolling on
	if anim:
		anim.stop()
		draw_scale = anim.scale
		set_tier(0)

func _physics_process(delta: float) -> void:
	if anim:
		# The body itself never rotates (no friction); the frames show the spin instead
		anim.rotation = -rotation
		# the hand-drawn frames roll the other way round from the physics' spin
		_turn = fposmod(_turn - _spin * delta, TAU)
		anim.frame = int(_turn / TAU * SPIN_FRAMES) % SPIN_FRAMES

	if freeze:
		# held by the temple or the kickback
		_moved_v = Vector2.ZERO
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	_watch_for_stuck(delta)
	_watch_ramp_exit(delta)

## Shows the ball as iron, silver, emerald or gold (one row each of the spin sheet)
func set_tier(tier: int) -> void:
	if anim == null:
		return
	if not _tier_frames.has(tier):
		var frames := SpriteFrames.new()
		for i in SPIN_FRAMES:
			var atlas := AtlasTexture.new()
			atlas.atlas = SPIN_SHEET
			atlas.region = Rect2(i * SPIN_SIZE, tier * SPIN_SIZE, SPIN_SIZE, SPIN_SIZE)
			frames.add_frame("default", atlas)
		_tier_frames[tier] = frames
	var shown := anim.frame
	anim.sprite_frames = _tier_frames[tier]
	anim.frame = shown

func _watch_ramp_exit(delta: float) -> void:
	# (a rail carrying the ball along its track keeps it on the rail itself)
	if (collision_mask & RAMP_LAYER_BIT) == 0 or rail_guide.is_valid() or _over_ramp_art():
		_off_ramp_time = 0.0
		return
	_off_ramp_time += delta
	if _off_ramp_time >= off_ramp_grace:
		drop_off_rail()

## Back down onto the playfield from the rails (off their art, or off the end of one)
func drop_off_rail() -> void:
	_off_ramp_time = 0.0
	if (collision_mask & RAMP_LAYER_BIT) == 0:
		return
	collision_layer = _restore_layers
	collision_mask = _restore_mask
	z_index = _restore_z
	PinballEvents.ball_left_ramp.emit(self)

func _over_ramp_art() -> bool:
	if _ramp_art == null:
		return true  # no art to check against; leave it to the gates
	if SHRINE_CHUTE.has_point(global_position):
		return true
	var px := Vector2i((global_position * ART_PER_SCENE).floor())
	if px.x < 0 or px.y < 0 or px.x >= _ramp_art.get_width() or px.y >= _ramp_art.get_height():
		return false
	return _ramp_art.get_pixelv(px).a > 0.0

func _watch_for_stuck(delta: float) -> void:
	var pos := global_position
	var exempt := can_launch or freeze or _pending_respawn or pos.y - stage_origin.y > CRADLE_Y \
		or (collision_mask & RAMP_LAYER_BIT) != 0
	if exempt or pos.distance_to(_stuck_anchor) > stuck_radius:
		_stuck_anchor = pos
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= stuck_seconds:
		_stuck_time = 0.0
		_stuck_anchor = pos
		linear_velocity = (stage_origin + UNSTICK_TOWARD - pos).normalized() * unstick_speed

func _process(delta: float) -> void:
	if _charging:
		_charge_seconds += delta
		PinballEvents.launch_power_changed.emit(_current_power(), true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_begin_charge()
	elif event.is_action_released("ui_accept"):
		_release_charge()

func _begin_charge() -> void:
	if not can_launch or _charging:
		return
	_charging = true
	_charge_seconds = 0.0

func _release_charge() -> void:
	if not _charging:
		return
	var power := _current_power()  # read before letting go, while it still knows how far it's pulled
	_charging = false
	PinballEvents.launch_power_changed.emit(power, false)
	_launch(power)

## How far the spring is pulled down, 0 at rest to 1 all the way
func pull() -> float:
	return clampf(_charge_seconds / pull_seconds, 0.0, 1.0) if _charging else 0.0

func _current_power() -> float:
	return lerpf(min_launch_power, 1.0, pull())

func _launch(power: float = 1.0) -> void:
	if not can_launch:
		return
	linear_velocity = Vector2(0.0, launch_speed * power)
	AudioSfx.play("launch")
	PinballEvents.ball_launched.emit()

## Multiball: puts a copy of this ball into play at `from`. It shares the plunger spot,
## so whichever ball is left last respawns there as usual.
func spawn_extra_ball(from: Vector2, velocity: Vector2) -> RigidBody2D:
	var extra := duplicate() as RigidBody2D
	var trail := extra.get_node_or_null(^"RampTrail")
	if trail:
		extra.remove_child(trail)  # the copy builds its own in _ready
		trail.free()
	# Start on the playfield even if this ball is up a ramp right now
	extra.collision_layer = _restore_layers
	extra.collision_mask = _restore_mask
	extra.z_index = _restore_z
	# ...and loose on the main table, even if this one is held or shrunk into the temple
	extra.freeze = false
	extra.stage_origin = Vector2.ZERO
	extra.transform = Transform2D(0.0, get_parent().to_local(from))
	extra.linear_velocity = velocity
	var extra_anim := extra.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if extra_anim:
		extra_anim.scale = draw_scale
	get_parent().add_child(extra)
	extra.spawn_xform = spawn_xform
	return extra

func _on_start_region_body_entered(body: Node) -> void:
	if body == self:
		can_launch = true
		PinballEvents.launch_available.emit(true)

func _on_start_region_body_exited(body: Node) -> void:
	if body == self:
		can_launch = false
		_charging = false
		PinballEvents.launch_available.emit(false)

func _on_death_zone_body_entered(body: Node) -> void:
	if body == self and not _pending_respawn:
		if get_tree().get_nodes_in_group("ball").size() > 1:
			# Multiball: a ball that drains while others are still up just leaves play
			remove_from_group("ball")
			queue_free()
			return
		PinballEvents.ball_drained.emit()
		_pending_respawn = true
		_cooldown_frames = 3
		collision_layer = 0
		collision_mask = 0

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _pending_respawn:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
		state.transform = spawn_xform
		state.sleeping = false
		_moved_v = Vector2.ZERO

		_cooldown_frames -= 1
		if _cooldown_frames <= 0:
			_pending_respawn = false
			collision_layer = _restore_layers
			collision_mask = _restore_mask
		return

	if rail_guide.is_valid() and rail_guide.call(self, state):
		_moved_v = state.linear_velocity
		return
	var v := state.linear_velocity
	v.y += _gravity(v.y) * state.step
	_update_spin(state, v)
	var on_ramp := (collision_mask & RAMP_LAYER_BIT) != 0
	if on_ramp != _was_on_ramp:
		_was_on_ramp = on_ramp
		_ramp_trail.emitting = on_ramp
	var local := global_position - stage_origin
	var cap := max_speed_low if local.y > CRADLE_Y else max_speed
	_moved_v = v if local.x > PLUNGER_LANE_X and stage_origin == Vector2.ZERO else v.limit_length(cap)
	state.linear_velocity = _moved_v

# Rolling along a surface turns the ball at speed / radius. The spin radius is the
# drawn ball's, so the pattern rolls at the pace the big sprite would.
func _update_spin(state: PhysicsDirectBodyState2D, v: Vector2) -> void:
	if state.get_contact_count() == 0:
		return
	var normal := state.get_contact_local_normal(0)
	_spin = clampf(normal.cross(v) / _drawn_radius(), -MAX_DRAWN_SPIN, MAX_DRAWN_SPIN)
	# how fast it was going into the surface it just met
	var into := -_moved_v.dot(normal)
	if into > IMPACT_SPEED and _impact_cooldown <= 0.0:
		_impact_cooldown = IMPACT_COOLDOWN
		_on_impact.call_deferred(global_position - normal * 19.0, (into - IMPACT_SPEED) * IMPACT_RUMBLE_PER_SPEED + 1.0)

func _on_impact(at: Vector2, strength: float) -> void:
	PinballEvents.effect.emit("dust", at)
	PinballEvents.rumble.emit(minf(strength, IMPACT_MAX_RUMBLE))

func _drawn_radius() -> float:
	return anim.sprite_frames.get_frame_texture("default", 0).get_width() * anim.scale.x * 0.5 if anim else 19.0

func _gravity(falling: float) -> float:
	for band in GRAVITY_BANDS:
		if falling > band[0]:
			return band[1]
	return GRAVITY_BANDS[-1][1]

const RAMP_LAYER_BIT := 2

# Chunky turquoise droplets streaming off the ball while the channel current carries it
func _build_ramp_trail() -> void:
	var drop := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	drop.fill(Color.WHITE)
	_ramp_trail = CPUParticles2D.new()
	_ramp_trail.name = "RampTrail"
	_ramp_trail.texture = ImageTexture.create_from_image(drop)
	_ramp_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ramp_trail.emitting = false
	_ramp_trail.amount = 24
	_ramp_trail.lifetime = 0.35
	_ramp_trail.local_coords = false
	_ramp_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ramp_trail.emission_sphere_radius = 20.0  # around the drawn ball, not the collision circle
	_ramp_trail.gravity = Vector2.ZERO
	_ramp_trail.initial_velocity_min = 10.0
	_ramp_trail.initial_velocity_max = 40.0
	_ramp_trail.spread = 180.0
	_ramp_trail.scale_amount_min = 1.0  # 3px squares = one table-art pixel
	_ramp_trail.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 0.95, 0.9, 0.9))
	fade.set_color(1, Color(0.2, 0.7, 0.85, 0.0))
	_ramp_trail.color_ramp = fade
	_ramp_trail.z_index = -1
	add_child(_ramp_trail)
