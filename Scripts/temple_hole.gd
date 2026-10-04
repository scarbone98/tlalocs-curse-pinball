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

const SmokeTornado := preload("res://Scripts/smoke_tornado.gd")
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
const MOUTH_SPIN_SECONDS := 1.2  # it whirls round in his mouth this long before he swallows it
const MOUTH_SPIN_TURNS := 3.0
const MOUTH_SPIN_RADIUS := 9.0
const MOUTH_SPIN_ROLL := 25.0    # how fast it's drawn rolling as it whirls (radians a second)
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
	"spirit": "A spirit rises!", "upgrade": "Ball upgrade!", "travel": "Travel!",
	"awaken": "The spirits stir!", "bonus_lamp": "A bonus lamp!",
}

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var gate_open := false       # all four relics lit
var roulette_lit := false
var spins := 0

var _whirl: AnimatedSprite2D
var _was_open := false
var _held: RigidBody2D
var swallowed := false  # the held ball's gone down his throat (his eyes roll: Scripts/table_features.gd)
var _after_reel := Callable()  # what to do once the floor roulette has landed, the ball still held
var _rearm := 0.0
var _clock := 0.0

func _ready() -> void:
	PinballEvents.lava_rescue.connect(_rescue)
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

func _el_dorado_open() -> bool:
	return gate_open or GameManager.bonus_lamps >= GameManager.BONUS_LAMPS_FOR_EL_DORADO

func _waiting() -> bool:
	return _el_dorado_open() or features.awakening.finishing \
		or (features.journey.traveling and features.journey.travel_steps > 0) or roulette_lit

func _physics_process(delta: float) -> void:
	_clock += delta
	_rearm = maxf(_rearm - delta, 0.0)
	# his mouth opens, the whirl turning in it, while something waits (or he's holding the
	# ball); while a sacrifice sits in it, it takes nothing else (Scripts/sacrifices.gd)
	var heart_in: bool = features.sacrifices != null and features.sacrifices.active
	var open: bool = not heart_in and not swallowed and (_held != null or _waiting())
	_whirl.visible = open
	var gaping := open or heart_in  # his mouth gapes round a sacrifice too
	if gaping and features._face_sprite:
		features._face_sprite.frame = MOUTH_OPEN
	elif _was_open and features._face_sprite:
		features._face_sprite.frame = MOUTH_SHUT  # nothing waiting any more: he shuts it
	_was_open = gaping
	if _after_reel.is_valid() and not features.roulette.busy():
		var then := _after_reel
		_after_reel = Callable()
		then.call()
	if _held or _rearm > 0.0 or not _waiting() or heart_in:
		return
	# with more than one ball in play (his curse's multiball, say) he takes whichever comes
	# to him; the others play on while he holds it
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if ball.freeze or not features._is_ball_on_playfield(ball):
			continue
		var to_mouth := AT - ball.global_position
		var near := to_mouth.length()
		if near < CATCH_RADIUS:
			_catch(ball)
			return
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
		_swallow(ball)
		get_tree().create_timer(HOLD_SECONDS).timeout.connect(func():
			features.journey.arrive()  # the cities spin on the floor while he holds it
			_after_reel = eject.bind(ball))
		return
	# The roulette: the prize is picked now so the billboard's reel can spin while the ball is held
	roulette_lit = false
	var prize := _pick_prize()
	var seconds := randf_range(SPIN_SECONDS.x, SPIN_SECONDS.y)
	var picture: int = Billboard.PRIZE + Billboard.PRIZES.find(PRIZE_PICTURE[prize])
	_swallow(ball)
	PinballEvents.billboard_spin.emit(picture, seconds, PRIZE_CAPTIONS[prize])
	_after_reel = func():  # once the floor's reel has come to rest
		_award_prize(prize)
		spins += 1
		PinballEvents.roulette_spun.emit()
		eject(ball)

# Once it's spiralled in, the ball whirls round and round in his mouth a while, tighter
# and tighter; then gulp: it goes down his throat and he shuts his mouth on it
func _swallow(ball: RigidBody2D) -> void:
	get_tree().create_timer(SPIRAL_SECONDS).timeout.connect(func():
		if _held != ball:
			return
		ball.z_index = 2  # over the magic whirl in his mouth, so you see it go round
		var whirl := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		whirl.tween_method(func(t: float):
			if _held != ball or swallowed:
				return
			ball.global_position = AT + Vector2.from_angle(t * TAU * MOUTH_SPIN_TURNS) * MOUTH_SPIN_RADIUS * (1.0 - 0.7 * t)
			ball.set("_spin", MOUTH_SPIN_ROLL),
			0.0, 1.0, MOUTH_SPIN_SECONDS)
		whirl.tween_callback(func():
			if _held != ball:
				return
			swallowed = true
			ball.global_position = AT
			ball.anim.hide()
			AudioSfx.play("tiki", 0.0, Vector2.ONE * 0.6)))

const RESCUE_RISE_SECONDS := 1.0  # a saved ball rides the tornado up to his mouth this long

# A ball saver's running as a ball hits the lava: a tornado of smoke twists up out of the
# lava into his mouth, carrying the ball spiralling up it; it whirls round in his mouth,
# and he spits it back out into play
func _rescue(ball: RigidBody2D) -> void:
	var layer := ball.collision_layer
	var mask := ball.collision_mask
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	ball.rail_guide = Callable()
	ball.z_index = 3  # between the tornado's far side and its near side
	var tornado := SmokeTornado.new()
	tornado.from = Vector2(clampf(ball.global_position.x, 300.0, 375.0), 1262.0)
	tornado.to = AT + Vector2(0, 14)
	tornado.seconds = SmokeTornado.GROW_SECONDS + RESCUE_RISE_SECONDS + 0.6
	features.add_child(tornado)
	PinballEvents.toast.emit("Ball saved!")
	PinballEvents.effect.emit("lava", ball.global_position)
	AudioSfx.play("shrine")
	PinballEvents.rumble.emit(5.0)
	var start := ball.global_position
	var rise := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	rise.tween_interval(SmokeTornado.GROW_SECONDS)  # it reaches down to the ball, then takes it
	rise.tween_method(func(t: float):
		# caught up in it: round and round, higher and higher, tighter and tighter
		var along := t * t * (3.0 - 2.0 * t)
		var on := tornado.point(along, tornado.turn(along) + PI * 0.5) if is_instance_valid(tornado) else AT
		var at := on.lerp(AT, smoothstep(0.85, 1.0, t))
		ball.global_position = start.lerp(at, smoothstep(0.0, 0.12, t))
		ball.set("_spin", MOUTH_SPIN_ROLL),
		0.0, 1.0, RESCUE_RISE_SECONDS)
	rise.tween_callback(func():
		_held = ball  # his mouth opens on it, the whirl turning
		_rearm = 0.0
		AudioSfx.play("kickback")
		_swallow(ball))
	rise.tween_interval(SPIRAL_SECONDS + MOUTH_SPIN_SECONDS + 0.4)
	rise.tween_callback(func():
		eject(ball)
		ball.collision_layer = layer
		ball.collision_mask = mask
		ball.set("rescued", false))

## Sends a held ball back down toward the flippers (the bonus stage returns it here too)
func eject(ball: RigidBody2D) -> void:
	_held = null
	swallowed = false
	_rearm = REARM_SECONDS
	ball.global_position = AT
	ball.anim.modulate.a = 1.0
	ball.anim.show()
	ball.z_index = 1  # back on the playfield's level
	if features._face_sprite:
		features._face_sprite.frame = MOUTH_OPEN  # he spits it out
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
