extends Node2D
## The crystal skull at the top of the brown lane, right of the arena, in front of the
## palms: like Sharpedo and Wailmer on Pokemon Pinball Ruby & Sapphire's fields it eats
## a ball shot up the lane and spits it back out, but only with its jaws open. They open
## when it has something to give: a lit Awakening to start, or a spirit ready to rise once
## the ball has looped the right lane enough to light its lamps (Scripts/spirit_lane.gd):
## then a ball it takes calls the spirit up. With its jaws shut it's solid, and the ball bounces off it. It's drawn in
## two pieces, the ball between them: over the lower jaw, under the top, so a ball it
## takes goes into its mouth. It shuts its jaws on the ball and opens them again to spit
## it back out (shaking with it a moment first), and it bobs slowly up and down all the
## while, floating. Now and then its teeth chatter; a ball that hits its teeth, or goes
## into its mouth, knocks it back a little.

const TOP := preload("res://Sprites/table/skull_top.png")  # tools/make_table.py: jaws shut, open
const JAW := preload("res://Sprites/table/skull_jaw.png")

const AT := Vector2(526, 513)          # the skull sprite, at the lane's top (as in the layout mock-up)
const MOUTH := Vector2(523, 543)       # its mouth, where it takes the ball
const CATCH_RADIUS := 20.0
const HOLD_SECONDS := 1.0
const SPIT_VELOCITY := Vector2(-170, 620)  # back down the lane
const REARM_SECONDS := 1.2
const EAT_POINTS := 1500
const JAW_RADIUS := 20.0   # the shut jaws the ball bounces off
enum { CALM, OPEN }  # Sprites/table/skull_top.png: jaws shut, jaws open
const BOB_SECONDS := 2.4    # one slow bob, a pixel up and back
const OPEN_TO_SPIT := 0.25  # it opens its jaws this long before the ball comes back out
const SHAKE_SECONDS := 1.0  # it shakes this long, jaws shut, before it opens to spit
const CHATTER_EVERY := Vector2(5.0, 10.0)
const CHATTER_SECONDS := 0.5
const CHATTER_FPS := 14.0
const KNOCK := 2.0          # art pixels it's knocked back up by a hit
const KNOCK_SECONDS := 0.15
const TEETH_KICK := 450.0   # a ball off its shut teeth bounces away this fast

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D  # the top
var _jaw: AnimatedSprite2D
var _held: RigidBody2D
var _rearm := 0.0
var _jaws: CollisionShape2D
var _chewing := false  # the ball's inside, its jaws shut on it
var _opening := false  # opening up to spit it out
var _clock := 0.0
var _shake_left := 0.0
var _chatter_left := 0.0
var _chatter_wait := 6.0
var _knock_left := 0.0

func _ready() -> void:
	_jaw = features._sprite(JAW, 1, AT)  # under the ball
	_sprite = features._sprite(TOP, 2, AT)
	_sprite.z_index = 3  # over the ball, and in front of the palms
	_sprite.z_as_relative = false
	var body := StaticBody2D.new()
	body.position = MOUTH
	_jaws = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = JAW_RADIUS
	_jaws.shape = circle
	body.add_child(_jaws)
	add_child(body)
	# its shut teeth: a ball hitting them knocks the skull back and bounces off
	var teeth := Area2D.new()
	teeth.position = MOUTH
	teeth.monitorable = false
	var reach := CollisionShape2D.new()
	var around := CircleShape2D.new()
	around.radius = JAW_RADIUS + 8.0
	reach.shape = around
	teeth.add_child(reach)
	teeth.body_entered.connect(_on_teeth)
	add_child(teeth)

func _physics_process(delta: float) -> void:
	_rearm = maxf(_rearm - delta, 0.0)
	_clock += delta
	_shake_left = maxf(_shake_left - delta, 0.0)
	_knock_left = maxf(_knock_left - delta, 0.0)
	var bob := -1.0 if fposmod(_clock / BOB_SECONDS, 1.0) < 0.5 else 0.0
	var lift := -KNOCK if _knock_left > 0.0 else 0.0
	var shake := (1.0 if int(_clock * 20.0) % 2 == 0 else -1.0) if _shake_left > 0.0 else 0.0
	for piece in [_sprite, _jaw]:
		piece.offset = Vector2(shake, bob + lift)
	var open := lit()
	var jaws_open := _opening or (_held != null and not _chewing) or (_held == null and open)
	# now and then, shut and idle, its teeth chatter
	if _held == null and not open:
		_chatter_wait -= delta
		if _chatter_wait <= 0.0:
			_chatter_wait = randf_range(CHATTER_EVERY.x, CHATTER_EVERY.y)
			_chatter_left = CHATTER_SECONDS
	_chatter_left = maxf(_chatter_left - delta, 0.0)
	if _chatter_left > 0.0 and not jaws_open:
		jaws_open = int(_clock * CHATTER_FPS) % 2 == 0
	_sprite.frame = OPEN if jaws_open else CALM
	_jaw.visible = jaws_open
	if _held or _rearm > 0.0:
		return
	if _jaws.disabled != open:
		_jaws.set_deferred("disabled", open)
	if not open:
		return
	for node in get_tree().get_nodes_in_group("ball"):
		var ball := node as RigidBody2D
		if not ball.freeze and ball.linear_velocity.y < 0.0 and features._is_ball_on_playfield(ball) \
				and ball.global_position.distance_to(MOUTH) < CATCH_RADIUS:
			_eat(ball)
			return

## True when a shot into the skull would do something more than pay out: its jaws are open
func lit() -> bool:
	return not features.mode_running() and (features.awakening.lit or features.spirit_lane.spirit_ready)

func _eat(ball: RigidBody2D) -> void:
	_held = ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	_sprite.frame = OPEN
	_jaw.visible = true
	_knock_left = KNOCK_SECONDS
	# over the jaw and in under the top, then gone down its throat
	var gulp := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	gulp.tween_property(ball, "global_position", MOUTH + Vector2(0, -14), 0.18)
	gulp.tween_property(ball.anim, "modulate:a", 0.0, 0.1)
	gulp.tween_callback(func():
		ball.anim.visible = false
		ball.anim.modulate.a = 1.0
		_chewing = true  # snap: jaws shut on it
		AudioSfx.play("bumper", 0.0, Vector2.ONE * 0.7))
	features._award(EAT_POINTS, AT + Vector2(0, -40))
	AudioSfx.play("shrine")
	PinballEvents.rumble.emit(3.0)
	get_tree().create_timer(HOLD_SECONDS, false).timeout.connect(_decide)

func _decide() -> void:
	if not features.mode_running():
		if features.spirit_lane.spirit_ready:
			features.spirit.summon(features.spirit_lane.take())  # the spirit the lane's loops earned
		elif features.awakening.lit:
			features.awakening.start()
	_spit()

# It shakes a moment, then opens its jaws, then the ball comes back out
func _spit() -> void:
	_shake_left = SHAKE_SECONDS
	get_tree().create_timer(SHAKE_SECONDS, false).timeout.connect(func():
		_opening = true
		_chewing = false
		get_tree().create_timer(OPEN_TO_SPIT, false).timeout.connect(_release))

func _on_teeth(body: Node) -> void:
	if _held or _jaws.disabled or not features._is_ball_on_playfield(body):  # only while they're shut
		return
	var ball := body as RigidBody2D
	_knock_left = KNOCK_SECONDS
	var away := (ball.global_position - MOUTH).normalized()
	ball.linear_velocity = ball.linear_velocity.bounce(away) * 0.5 + away * TEETH_KICK
	AudioSfx.play("bumper", 0.0, Vector2.ONE * 1.2)
	PinballEvents.effect.emit("sparks", MOUTH + away * JAW_RADIUS)

func _release() -> void:
	_opening = false
	var ball := _held
	_held = null
	_rearm = REARM_SECONDS
	if ball == null or not is_instance_valid(ball):
		return
	ball.global_position = MOUTH
	ball.anim.visible = true
	ball.freeze = false
	ball.linear_velocity = SPIT_VELOCITY
	AudioSfx.play("shrine_out")
	PinballEvents.effect.emit("sparks", MOUTH)
