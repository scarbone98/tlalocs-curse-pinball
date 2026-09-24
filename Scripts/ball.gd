extends RigidBody2D

## Pokemon Pinball's plunger fires at 5.5 px/frame (1420 at this table's scale)
@export var launch_speed: float = -1420.0
## Holding launch sweeps power between this and full; a quick tap is always full power.
## Even the weakest launch clears the plunger lane.
@export var min_launch_power: float = 0.85
@export var tap_seconds: float = 0.15
@export var sweep_seconds: float = 0.9
## The sprite is drawn about 1.35x the collision circle. Pokemon Pinball draws its ball
## bigger still (a 16px sprite colliding as a 4px-radius circle), but here that spilled
## too far over the walls and posts the ball passes; this still fits the same gaps.
## Its spin copies that game too: every contact sets the spin from how fast the ball is
## sliding along the surface, and the ball keeps that spin in the air.
const SPIN_FRAMES := 16  # Sprites/ball_spin.png, one full turn per row
const SPIN_SHEET := preload("res://Sprites/ball_spin.png")
const SPIN_SIZE := 20
## Tuned to Pokemon Pinball's engine (pret/pokepinball). Its field is about 160x310px,
## so 1px there is about 4.3 units here, and it runs one physics step per 60Hz frame:
##  - no friction or drag, only gravity: 11/256 px/frame^2 (660 here, project settings)
##  - walls hand back a quarter of the speed going into them (bounce 0.25)
##  - two speed limits per axis. The ball can hold up to 8 px/frame (max_velocity)
##    but never moves more than 5 px/frame (max_travel). A hard shot therefore flies
##    at a flat top speed until gravity has eaten the banked speed, then arcs over.
@export var bounce: float = 0.25
@export var max_velocity: float = 2050.0
@export var max_travel: float = 1280.0
## The side ramps are water channels (collision layer 2, switched on by the gates). The
## current eases the climb: on a ramp gravity pulls the ball back at only this fraction
## of its strength, so a good shot glides all the way round and a weak one slows and
## rolls back down naturally, with no sudden push either way.
@export var ramp_gravity_scale: float = 0.4
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
# The right ramp's top branch runs on into the shrine doorway, painted on the base art
const SHRINE_CHUTE := Rect2(585, 160, 85, 150)

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
var _banked_v := Vector2.ZERO  # the velocity the ball holds, up to max_velocity
var _moved_v := Vector2.ZERO   # what it actually moved at last step, up to max_travel
var draw_scale := 1.0  # the sprite's scale as set in the scene (the temple hole shrinks it)
var stage_origin := Vector2.ZERO  # top left of the table the ball is on (El Dorado is below)
var _spin := 0.0   # radians per second, clockwise
var _impact_cooldown := 0.0
var _turn := 0.0   # how far the sprite has turned
const BANK_TOLERANCE := 30.0  # a step of gravity against the ball (660/120) still keeps it
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
		draw_scale = anim.scale.x

func _physics_process(delta: float) -> void:
	if anim:
		# The body itself never rotates (no friction); the frames show the spin instead
		anim.rotation = -rotation
		_turn = fposmod(_turn + _spin * delta, TAU)
		anim.frame = int(_turn / TAU * SPIN_FRAMES) % SPIN_FRAMES

	if freeze:
		# held by the temple or the kickback; whatever it banked before doesn't carry over
		_banked_v = Vector2.ZERO
		_moved_v = Vector2.ZERO
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	_watch_for_stuck(delta)
	_watch_ramp_exit(delta)

## Shows the ball as stone, jade, turquoise or gold (one row each of the spin sheet)
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
	if (collision_mask & RAMP_LAYER_BIT) == 0 or _over_ramp_art():
		_off_ramp_time = 0.0
		return
	_off_ramp_time += delta
	if _off_ramp_time >= off_ramp_grace:
		_off_ramp_time = 0.0
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
	_charging = false
	var power := _current_power()
	PinballEvents.launch_power_changed.emit(power, false)
	_launch(power)

# Starts at full power, then sweeps down to min_launch_power and back while held
func _current_power() -> float:
	var held := _charge_seconds
	if held < tap_seconds:
		return 1.0
	var t := fposmod((held - tap_seconds) / sweep_seconds, 2.0)
	var sweep := t if t <= 1.0 else 2.0 - t
	return lerpf(1.0, min_launch_power, sweep)

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
		extra_anim.scale = Vector2.ONE * draw_scale
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
		_banked_v = Vector2.ZERO
		_moved_v = Vector2.ZERO

		_cooldown_frames -= 1
		if _cooldown_frames <= 0:
			_pending_respawn = false
			collision_layer = _restore_layers
			collision_mask = _restore_mask
		return

	var v := state.linear_velocity
	v = _add_back_banked(v)
	_update_spin(state, v)
	var on_ramp := (collision_mask & RAMP_LAYER_BIT) != 0
	if on_ramp:
		# the engine has applied full gravity this step; give most of it back
		v -= state.total_gravity * state.step * (1.0 - ramp_gravity_scale)
	if on_ramp != _was_on_ramp:
		_was_on_ramp = on_ramp
		_ramp_trail.emitting = on_ramp
	_banked_v = _clamp_axes(v, max_velocity)
	_moved_v = _clamp_axes(_banked_v, max_travel)
	state.linear_velocity = _moved_v

# Rolling along a surface turns the ball at speed / radius. The spin radius is the
# drawn ball's, so the pattern rolls at the pace the big sprite would.
func _update_spin(state: PhysicsDirectBodyState2D, v: Vector2) -> void:
	if state.get_contact_count() == 0:
		return
	var normal := state.get_contact_local_normal(0)
	_spin = normal.cross(v) / _drawn_radius()
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

# The engine only knows the speed the ball moved at. Put the banked excess back on
# any axis where the ball is still going the same way at least as fast (free flight,
# or a flipper still pushing it); a hit that stopped or turned it spends the excess.
func _add_back_banked(v: Vector2) -> Vector2:
	var excess := _banked_v - _moved_v
	for axis in 2:
		if excess[axis] != 0.0 and signf(v[axis]) == signf(excess[axis]) \
				and absf(v[axis]) >= absf(_moved_v[axis]) - BANK_TOLERANCE:
			v[axis] += excess[axis]
	return v

# Pokemon Pinball limits x and y separately, so a diagonal ball can go a bit faster
func _clamp_axes(v: Vector2, limit: float) -> Vector2:
	return Vector2(clampf(v.x, -limit, limit), clampf(v.y, -limit, limit))

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
