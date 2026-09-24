extends Node2D
## Tlaloc's shrine swallows the ball, like Cloyster and Slowpoke in Pokemon Pinball. The
## right ramp's top branch runs up into the shrine's doorway: a ball that gets there is
## drawn inside and vanishes, Tlaloc's eyes flare, and the offering stirs him one step
## toward his curse. Then the shrine spits the ball back out and down the ramp.

const DOOR := Vector2(631, 205)   # just inside the doorway, top right (see Sprites/map_f1.png)
const CATCH_AT := Vector2(631, 218)
const CATCH_RADIUS := 24.0
const SPIT_FROM := Vector2(631, 236)
const SPIT_SPEED := 800.0         # straight back down the chute, onto the ramp
const HOLD_SECONDS := 1.3
const REARM_SECONDS := 1.0        # the spat-out ball passes back over the catch point
const OFFERING_POINTS := 2500

var features: Node2D  # TableFeatures, which owns the shrine mask and scoring helpers

var _held: RigidBody2D
var _rearm := 0.0

func _physics_process(delta: float) -> void:
	_rearm = maxf(_rearm - delta, 0.0)
	if _held or _rearm > 0.0:
		return
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		var on_ramp := (ball.collision_mask & 2) != 0
		if on_ramp and not ball.freeze and ball.linear_velocity.y < 0.0 \
				and ball.global_position.distance_to(CATCH_AT) < CATCH_RADIUS:
			_swallow(ball)
			return

func _swallow(ball: RigidBody2D) -> void:
	_held = ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	# drawn into the dark of the doorway
	var sink := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	sink.tween_property(ball, "global_position", DOOR, 0.15)
	sink.parallel().tween_property(ball.anim, "scale", ball.anim.scale * 0.3, 0.15)
	sink.tween_callback(func(): ball.anim.visible = false)
	AudioSfx.play("shrine")
	PinballEvents.rumble.emit(4.0)
	features._award(OFFERING_POINTS, DOOR + Vector2(0, 40))
	PinballEvents.toast.emit("An offering to Tlaloc!")
	features._flash_shrine(HOLD_SECONDS)
	features.stir_tlaloc()
	get_tree().create_timer(HOLD_SECONDS, false).timeout.connect(_spit.bind(ball))

func _spit(ball: RigidBody2D) -> void:
	_held = null
	_rearm = REARM_SECONDS
	ball.global_position = SPIT_FROM
	ball.anim.scale = Vector2.ONE * ball.draw_scale
	ball.anim.visible = true
	ball.freeze = false
	ball.linear_velocity = Vector2(0, SPIT_SPEED)
	AudioSfx.play("shrine_out")
	PinballEvents.effect.emit("splash", SPIT_FROM)
	PinballEvents.rumble.emit(3.0)
