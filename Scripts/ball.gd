extends RigidBody2D

@export var launch_speed: float = -2500.0
## Holding launch sweeps power between this and full; a quick tap is always full power
@export var min_launch_power: float = 0.5
@export var tap_seconds: float = 0.15
@export var sweep_seconds: float = 0.9
@export var anim_min_speed_scale: float = 0
## Pokemon Pinball's ball never loses speed to friction or drag, only to what it hits, and
## its speed is capped. That is what lets a good flip carry all the way up a ramp.
@export var bounce: float = 0.3
@export var max_speed: float = 2600.0
## The side ramps are water channels (collision layer 2, switched on by the gates). Once
## the ball is in one, the current carries it: speed never drops below ramp_min_speed, so
## a ball that made it through the gate always finishes the loop.
@export var ramp_entry_speed: float = 1300.0
@export var ramp_min_speed: float = 950.0

var can_launch: bool = false
var spawn_xform: Transform2D
var _pending_respawn: bool = false
var _restore_layers: int
var _restore_mask: int
var _cooldown_frames: int = 0
var _charging := false
var _charge_seconds := 0.0
var _was_on_ramp := false
var _ramp_trail: CPUParticles2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	spawn_xform = global_transform
	_restore_layers = collision_layer
	_restore_mask = collision_mask
	var mat := PhysicsMaterial.new()
	mat.friction = 0.0
	mat.bounce = bounce
	physics_material_override = mat
	linear_damp_mode = DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = DAMP_MODE_REPLACE
	angular_damp = 0.0
	_build_ramp_trail()

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

	if anim:
		anim.play()
		anim.speed_scale = 1.0

func _physics_process(_delta: float) -> void:
	if anim:
		anim.rotation = 0.0  # sprite stays upright

		# the ball slides without friction, so it barely spins; animate from how fast it
		# travels instead, turning the glyph the way it's heading
		var roll := linear_velocity.x / 19.0 + angular_velocity
		if absf(roll) > 0.5:
			anim.speed_scale = max(absf(roll) * 0.1, anim_min_speed_scale) * signf(roll)
		else:
			anim.speed_scale = 0

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

		_cooldown_frames -= 1
		if _cooldown_frames <= 0:
			_pending_respawn = false
			collision_layer = _restore_layers
			collision_mask = _restore_mask
		return

	var v := state.linear_velocity
	var on_ramp := (collision_mask & RAMP_LAYER_BIT) != 0
	if on_ramp and v.length() > 1.0:
		var floor_speed := ramp_entry_speed if not _was_on_ramp else ramp_min_speed
		if v.length() < floor_speed:
			v = v.normalized() * floor_speed
	if on_ramp != _was_on_ramp:
		_was_on_ramp = on_ramp
		_ramp_trail.emitting = on_ramp
	state.linear_velocity = v.limit_length(max_speed)

const RAMP_LAYER_BIT := 2

# Chunky turquoise droplets streaming off the ball while the channel current carries it
func _build_ramp_trail() -> void:
	var drop := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	drop.fill(Color.WHITE)
	_ramp_trail = CPUParticles2D.new()
	_ramp_trail.texture = ImageTexture.create_from_image(drop)
	_ramp_trail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ramp_trail.emitting = false
	_ramp_trail.amount = 24
	_ramp_trail.lifetime = 0.35
	_ramp_trail.local_coords = false
	_ramp_trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_ramp_trail.emission_sphere_radius = 12.0
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
