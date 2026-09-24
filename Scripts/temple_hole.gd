extends Node2D
## The temple hole in the middle of the table, like Pokemon Pinball's Ditto and
## Bellsprout holes. A shot up into it (not a ball falling back over it) is caught,
## held for a moment, and spun on the temple's roulette before being sent back down
## to the flippers. With the road open (a serpent's pips full) it travels to the next
## city instead. Once all four relics are lit it's El Dorado's gate, and the ball goes
## through to the bonus stage.

const HOLE := preload("res://Sprites/table/temple_hole.png")

const AT := Vector2(337, 650)
const CATCH_RADIUS := 20.0  # the ball's centre has to come this close
const HOLD_SECONDS := 1.1
const REARM_SECONDS := 1.5  # after spitting a ball out, so it can't be caught again at once
const EJECT_SPEED := 450.0
const EJECT_SPREAD := 150.0

enum { HOLE_IDLE, HOLE_FLASH, GATE_A, GATE_B }

# Weight, then what it does. Kickback and spirit fall back to points when they can't apply.
const PRIZES := [
	[3, "points_small"], [2, "points_big"], [2, "kickback"], [2, "spirit"], [2, "travel"],
]
const PRIZE_CAPTIONS := {
	"points_small": "Temple offering!", "points_big": "Temple treasure!", "kickback": "Kickback both sides!",
	"spirit": "A spirit rises!", "travel": "The road opens!",
}

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var gate_open := false

var _sprite: AnimatedSprite2D
var _held: RigidBody2D
var _rearm := 0.0
var _clock := 0.0

func _ready() -> void:
	_sprite = features._sprite(HOLE, 4, AT)

func set_gate_open(open: bool) -> void:
	gate_open = open

func _physics_process(delta: float) -> void:
	_clock += delta
	_rearm = maxf(_rearm - delta, 0.0)
	if _held:
		_sprite.frame = HOLE_FLASH if int(_clock * 8.0) % 2 == 0 else HOLE_IDLE
	elif gate_open:
		_sprite.frame = GATE_A if int(_clock * 4.0) % 2 == 0 else GATE_B
	elif features.journey.road_open:
		_sprite.frame = HOLE_FLASH if int(_clock * 3.0) % 2 == 0 else HOLE_IDLE  # the road leads here
	else:
		_sprite.frame = HOLE_IDLE
	if _held or _rearm > 0.0:
		return
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.size() != 1:
		return  # multiball rolls straight over it
	var ball := balls[0] as RigidBody2D
	if ball.freeze or ball.linear_velocity.y >= 0.0 or not features._is_ball_on_playfield(ball):
		return
	if ball.global_position.distance_to(AT) < CATCH_RADIUS:
		_catch(ball)

func _catch(ball: RigidBody2D) -> void:
	_held = ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	var sink := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	sink.tween_property(ball, "global_position", AT, 0.1)
	sink.parallel().tween_property(ball.anim, "scale", ball.anim.scale * 0.6, 0.1)
	AudioSfx.play("kickback")
	PinballEvents.rumble.emit(4.0)
	PinballEvents.effect.emit("gold" if gate_open else "dust", AT)
	if gate_open:
		PinballEvents.toast.emit("To El Dorado!")
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func(): features.el_dorado.enter(ball))
		return
	if features.journey.road_open:
		PinballEvents.toast.emit("The road leads on...")
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
			features.journey.travel()
			eject(ball))
		return
	# The prize is picked now so the billboard's reel can spin while the ball is held
	var prize := _pick_prize()
	PinballEvents.billboard_spin.emit(Billboard.PRIZE + Billboard.PRIZES.find(prize), HOLD_SECONDS, PRIZE_CAPTIONS[prize])
	get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
		_award_prize(prize)
		eject(ball))

## Sends a held ball back down toward the flippers (the bonus stage returns it here too)
func eject(ball: RigidBody2D) -> void:
	_held = null
	_rearm = REARM_SECONDS
	ball.global_position = AT
	ball.anim.scale = Vector2.ONE * ball.draw_scale
	ball.freeze = false
	ball.linear_velocity = Vector2(randf_range(-EJECT_SPREAD, EJECT_SPREAD), EJECT_SPEED)
	AudioSfx.play("launch")

# What the roulette lands on. A prize that can't apply right now (the kickback's already
# lit, a spirit's already up) turns into an offering instead.
func _pick_prize() -> String:
	var total := 0
	for prize in PRIZES:
		total += prize[0]
	var roll := randi() % total
	var pick := "points_small"
	for prize in PRIZES:
		roll -= prize[0]
		if roll < 0:
			pick = prize[1]
			break
	if pick == "kickback" and features.kickback.both_sides:
		return "points_small"
	if pick == "spirit" and features.spirit._active:
		return "points_small"
	return pick

func _award_prize(prize: String) -> void:
	match prize:
		"kickback":
			features.kickback.charge()
		"spirit":
			features.spirit.summon()
		"travel":
			features.journey.travel()
		"points_big":
			features._award(15000, AT + Vector2(0, -40))
		_:
			features._award(5000, AT + Vector2(0, -40))
