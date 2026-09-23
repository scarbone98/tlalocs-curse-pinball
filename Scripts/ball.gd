extends RigidBody2D

@export var launch_speed: float = -2500.0
## Holding launch sweeps power between this and full; a quick tap is always full power
@export var min_launch_power: float = 0.5
@export var tap_seconds: float = 0.15
@export var sweep_seconds: float = 0.9
@export var anim_min_speed_scale: float = 0

var can_launch: bool = false
var spawn_xform: Transform2D
var _pending_respawn: bool = false
var _restore_layers: int
var _restore_mask: int
var _cooldown_frames: int = 0
var _charging := false
var _charge_seconds := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	spawn_xform = global_transform
	_restore_layers = collision_layer
	_restore_mask = collision_mask

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

		# drive animation speed from raw angular velocity
		# use at least anim_min_speed_scale when spinning
		var spin = angular_velocity
		if spin != 0:
			anim.speed_scale = max(abs(spin) * 0.1, anim_min_speed_scale) * sign(spin)
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
