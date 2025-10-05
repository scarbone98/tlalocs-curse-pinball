extends RigidBody2D

@export var launch_speed: float = -2500.0
@export var anim_min_speed_scale: float = 0

var can_launch: bool = false
var spawn_xform: Transform2D
var _pending_respawn: bool = false
var _restore_layers: int
var _restore_mask: int
var _cooldown_frames: int = 0

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

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and can_launch:
		linear_velocity = Vector2(0.0, launch_speed)

func _on_start_region_body_entered(body: Node) -> void:
	if body == self:
		can_launch = true

func _on_start_region_body_exited(body: Node) -> void:
	if body == self:
		can_launch = false

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
