extends Node2D
## Tlaloc's mouth, in the great stone face in the middle of the table: Pokemon Pinball
## Ruby & Sapphire's centre hole. When something waits there he opens his mouth, with the
## magic whirl (the hand-drawn magicWhirl.png) turning in it, and a shot up into it (not
## a ball falling back over it) is swallowed, held a moment, then sent back down to the
## flippers:
##  - El Dorado's gate, opened by all four relics or by three bonus lamps: the ball goes
##    through to the bonus stage
##  - an Awakening with all its offerings found: the spirit awakens
##  - Travel mode with a way picked: the journey arrives at its city
##  - the roulette, lit by completing the bottom lanes: the temple's reel spins and stops
##    by itself on a prize. Each spin draws from a richer table than the last.
## With nothing waiting his mouth stays shut and the ball rolls over him.

const WHIRL := preload("res://Sprites/table/whirl.png")  # the hand-drawn magicWhirl.png, turning over his open mouth

const AT := Vector2(339, 838)  # Tlaloc's mouth, in the centre face (Sprites/face_sockets.png)
const CATCH_RADIUS := 36.0  # the ball's centre has to come this close, then it spirals in
# While his mouth is open the whirl draws a ball that comes near it in, harder the closer it gets
const PULL_RADIUS := 110.0
const PULL := 1400.0  # scene units/s² at the mouth, fading to nothing at PULL_RADIUS
const SWIRL := 900.0  # ...and round it, so the ball's drawn in spiralling, like a whirlpool
const SPIRAL_SECONDS := 0.7  # a caught ball circles in to the middle of his mouth
const SPIRAL_TURNS := 1.5
const HOLD_SECONDS := 1.1
const REARM_SECONDS := 1.5  # after spitting a ball out, so it can't be caught again at once
const EJECT_SPEED := 450.0
const EJECT_SPREAD := 150.0
# The reel stops by itself after 100 to 299 frames, as on Ruby's field
const SPIN_SECONDS := Vector2(100.0 / 60.0, 299.0 / 60.0)

enum { MOUTH_SHUT, MOUTH_OPEN }  # the face's frames

# The roulette's prize tables: each spin of the game draws from the next table, up to
# the last. [weight, prize] - prizes that can't apply right now pay points instead.
const PRIZE_TABLES := [
	[[4, "points_small"], [3, "points_small"], [3, "saver_short"], [2, "bonus_x"], [1, "kickback"]],
	[[3, "points_small"], [3, "points_big"], [3, "points_small"], [2, "saver_short"], [2, "bonus_x"], [2, "kickback"], [1, "spirit"]],
	[[3, "points_big"], [2, "points_big"], [2, "saver_long"], [2, "bonus_x"], [2, "kickback"], [2, "spirit"], [1, "upgrade"], [1, "travel"]],
	[[3, "points_huge"], [2, "points_big"], [2, "saver_long"], [3, "bonus_x2"], [2, "spirit"], [2, "upgrade"], [2, "travel"], [1, "awaken"], [1, "bonus_lamp"]],
]
const SPINS_PER_TABLE := 2
# What each prize shows on the billboard's reel (Scripts/billboard.gd PRIZES order)
const PRIZE_PICTURE := {
	"points_small": "points_small", "points_big": "points_big", "points_huge": "points_big",
	"saver_short": "kickback", "saver_long": "kickback",
	"bonus_x": "points_big", "bonus_x2": "points_big", "kickback": "kickback", "spirit": "spirit",
	"upgrade": "points_big", "travel": "travel", "awaken": "spirit", "bonus_lamp": "points_big",
}
const PRIZE_CAPTIONS := {
	"points_small": "Temple offering!", "points_big": "Temple treasure!", "points_huge": "Temple hoard!",
	"saver_short": "Ball saver 30s!", "saver_long": "Ball saver 60s!",
	"bonus_x": "Bonus +1!", "bonus_x2": "Bonus +2!", "kickback": "Kickback both sides!",
	"spirit": "A spirit rises!", "upgrade": "Ball upgrade!", "travel": "The road opens!",
	"awaken": "The spirits stir!", "bonus_lamp": "A bonus lamp!",
}

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var gate_open := false       # all four relics lit
var roulette_lit := false
var spins := 0

var _whirl: AnimatedSprite2D
var _was_open := false
var _held: RigidBody2D
var _rearm := 0.0
var _clock := 0.0

func _ready() -> void:
	_whirl = features._sprite(WHIRL, 3, AT, 8.0)
	_whirl.z_index = 1  # over the face
	_whirl.z_as_relative = false
	_whirl.play()
	_whirl.hide()

func set_gate_open(open: bool) -> void:
	gate_open = open

## Completing the bottom lanes lights the roulette
func light_roulette() -> void:
	if roulette_lit:
		return
	roulette_lit = true
	PinballEvents.toast.emit("Temple roulette lit!")

func _el_dorado_open() -> bool:
	return gate_open or GameManager.bonus_lamps >= GameManager.BONUS_LAMPS_FOR_EL_DORADO

func _waiting() -> bool:
	return _el_dorado_open() or features.awakening.finishing \
		or (features.journey.traveling and features.journey.travel_steps > 0) or roulette_lit

func _physics_process(delta: float) -> void:
	_clock += delta
	_rearm = maxf(_rearm - delta, 0.0)
	# his mouth opens, the whirl turning in it, while something waits (or he's holding the
	# ball); while the curse's heart sits in it, it takes nothing else (Scripts/heart_offering.gd)
	var heart_in: bool = features.heart != null and features.heart.active
	var open: bool = not heart_in and (_held != null or _waiting())
	_whirl.visible = open
	if open and features._face_sprite:
		features._face_sprite.frame = MOUTH_OPEN
	elif _was_open and features._face_sprite and not GameManager.curse_active:
		features._face_sprite.frame = MOUTH_SHUT  # nothing waiting any more: he shuts it
	_was_open = open
	if _held or _rearm > 0.0 or not _waiting() or heart_in:
		return
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.size() != 1:
		return  # multiball rolls straight over it
	var ball := balls[0] as RigidBody2D
	if ball.freeze or not features._is_ball_on_playfield(ball):
		return
	var to_mouth := AT - ball.global_position
	var near := to_mouth.length()
	if near < CATCH_RADIUS:
		_catch(ball)
	elif near < PULL_RADIUS:
		# the whirl draws it in, and takes the edge off its speed as it spirals toward the mouth
		var strength := 1.0 - near / PULL_RADIUS
		ball.linear_velocity += to_mouth.normalized() * PULL * strength * delta
		ball.linear_velocity += to_mouth.normalized().orthogonal() * SWIRL * strength * delta
		ball.linear_velocity *= 1.0 - 0.8 * strength * delta

func _catch(ball: RigidBody2D) -> void:
	_held = ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	# whirlpooled in: it circles round and down to the middle of his mouth, and sits there
	var from := ball.global_position - AT
	var sink := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	sink.tween_method(func(t: float):
		ball.global_position = AT + from.rotated(t * TAU * SPIRAL_TURNS) * (1.0 - t),
		0.0, 1.0, SPIRAL_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	AudioSfx.play("kickback")
	PinballEvents.rumble.emit(4.0)
	if _el_dorado_open():
		PinballEvents.effect.emit("gold", AT)
		var via_relics := gate_open
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func(): features.el_dorado.enter(ball, via_relics))
		return
	PinballEvents.effect.emit("dust", AT)
	if features.awakening.finishing:
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
			features.awakening.finish()
			eject(ball))
		return
	if features.journey.traveling and features.journey.travel_steps > 0:
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
			features.journey.arrive()
			eject(ball))
		return
	# The roulette: the prize is picked now so the billboard's reel can spin while the ball is held
	roulette_lit = false
	var prize := _pick_prize()
	var seconds := randf_range(SPIN_SECONDS.x, SPIN_SECONDS.y)
	var picture: int = Billboard.PRIZE + Billboard.PRIZES.find(PRIZE_PICTURE[prize])
	PinballEvents.billboard_spin.emit(picture, seconds, PRIZE_CAPTIONS[prize])
	get_tree().create_timer(seconds).timeout.connect(func():
		_award_prize(prize)
		spins += 1
		PinballEvents.roulette_spun.emit()
		eject(ball))

## Sends a held ball back down toward the flippers (the bonus stage returns it here too)
func eject(ball: RigidBody2D) -> void:
	_held = null
	_rearm = REARM_SECONDS
	ball.global_position = AT
	ball.anim.modulate.a = 1.0
	ball.freeze = false
	ball.linear_velocity = Vector2(randf_range(-EJECT_SPREAD, EJECT_SPREAD), EJECT_SPEED)
	AudioSfx.play("launch")
	PinballEvents.effect.emit("dust", AT)

func _pick_prize() -> String:
	var table: Array = PRIZE_TABLES[mini(spins / SPINS_PER_TABLE, PRIZE_TABLES.size() - 1)]
	var total := 0
	for prize in table:
		total += prize[0]
	var roll := randi() % total
	var pick := "points_small"
	for prize in table:
		roll -= prize[0]
		if roll < 0:
			pick = prize[1]
			break
	if pick == "kickback" and features.kickback.both_sides:
		return "points_big"
	if pick in ["spirit", "travel", "awaken"] and features.mode_running():
		return "points_big"
	if pick == "awaken" and SpiritCodex.awakenable().is_empty():
		return "points_big"
	return pick

func _award_prize(prize: String) -> void:
	var at := AT + Vector2(0, -40)
	match prize:
		"points_small":
			features._award(5000, at)
		"points_big":
			features._award(15000, at)
		"points_huge":
			features._award(50000, at)
		"saver_short":
			GameManager.grant_ball_save(30.0)
		"saver_long":
			GameManager.grant_ball_save(60.0)
		"bonus_x":
			GameManager.add_bonus_multiplier(1)
		"bonus_x2":
			GameManager.add_bonus_multiplier(2)
		"kickback":
			features.kickback.charge()
		"spirit":
			features.spirit.summon()
		"upgrade":
			features.upgrade_ball()
		"travel":
			features.journey._start_travel()
		"awaken":
			features.awakening.start()
		"bonus_lamp":
			GameManager.add_bonus_lamps(1)
