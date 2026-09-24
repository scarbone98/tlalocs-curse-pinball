extends Node2D
## Catch mode, like Catch 'Em mode in Pokemon Pinball: every third ramp shot an
## ajolote water spirit rises out of the temple floor. Hit it three times before
## it sinks back down to catch it. Each catch is worth more than the last.

const SPIRIT := preload("res://Sprites/table/spirit.png")
const RIPPLE := preload("res://Sprites/table/ripple.png")

const SPAWN_AT := Vector2(345, 700)
const RIPPLE_OFFSET := Vector2(0, 26)
const HIT_RADIUS := 26.0
const RAMPS_TO_SUMMON := 3
const HITS_TO_CATCH := 3
const CATCH_SECONDS := 30.0
const WARN_SECONDS := 5.0  # the spirit flickers when it's about to sink
const HIT_POINTS := 1000
const CATCH_POINTS := 25000
const BOUNCE_SPEED := 750.0
const HIT_COOLDOWN := 0.35
const ART_PIXEL_Y := 1280.0 / 424.0  # one table-art pixel, vertically (see TableFeatures.MAP_SCALE)

enum { IDLE_A, IDLE_B, HIT }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var caught := 0

var _ramps := 0
var _active := false
var _hits := 0
var _time_left := 0.0
var _cooldown := 0.0
var _clock := 0.0
var _area: Area2D
var _spirit: AnimatedSprite2D
var _ripple: AnimatedSprite2D

func _ready() -> void:
	_area = Area2D.new()
	_area.position = SPAWN_AT
	_area.monitorable = false
	_area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

	_ripple = features._sprite(RIPPLE, 4, SPAWN_AT + RIPPLE_OFFSET, 10.0)
	_ripple.sprite_frames.set_animation_loop("default", false)
	_ripple.animation_finished.connect(_ripple.hide)
	_ripple.hide()
	_spirit = features._sprite(SPIRIT, 3, SPAWN_AT)
	_spirit.hide()

	PinballEvents.ramp_made.connect(_on_ramp_made)

func _on_ramp_made(_side: String, _combo: int) -> void:
	if _active:
		return
	_ramps += 1
	if _ramps >= RAMPS_TO_SUMMON:
		_ramps = 0
		_summon()

func _summon() -> void:
	_active = true
	_hits = 0
	_time_left = CATCH_SECONDS
	_clock = 0.0
	_splash()
	_spirit.frame = IDLE_A
	_spirit.show()
	_area.set_deferred("monitoring", true)
	PinballEvents.toast.emit("A water spirit rises!")
	AudioSfx.play("spirit")

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_time_left -= delta
	if _time_left <= 0.0:
		PinballEvents.toast.emit("The spirit slipped away")
		_dismiss()
		return

	# Gills shimmer and the spirit bobs one art pixel, so it stays on the table's grid
	if _cooldown == 0.0:
		_spirit.frame = IDLE_A if int(_clock * 3.0) % 2 == 0 else IDLE_B
	var bob := ART_PIXEL_Y if int(_clock * 2.0) % 2 == 0 else 0.0
	_spirit.position = SPAWN_AT - Vector2(0, bob)
	_spirit.visible = _time_left > WARN_SECONDS or int(_clock * 8.0) % 2 == 0

func _on_body_entered(body: Node) -> void:
	if not _active or _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	var ball := body as RigidBody2D
	_cooldown = HIT_COOLDOWN
	_hits += 1

	var away := (ball.global_position - SPAWN_AT).normalized()
	ball.linear_velocity = away * maxf(ball.linear_velocity.length(), BOUNCE_SPEED)
	_spirit.frame = HIT
	var pitch := 1.0 + 0.15 * _hits
	AudioSfx.play("spirit_hit", 0.0, Vector2(pitch, pitch))
	features._award(HIT_POINTS, SPAWN_AT)

	if _hits < HITS_TO_CATCH:
		PinballEvents.toast.emit("Spirit %d/%d" % [_hits, HITS_TO_CATCH])
		return
	caught += 1
	features._award(CATCH_POINTS * caught, SPAWN_AT + Vector2(0, -40))
	PinballEvents.toast.emit("Ajolote caught! x%d" % caught)
	AudioSfx.play("catch")
	_dismiss()

func _dismiss() -> void:
	_active = false
	_area.set_deferred("monitoring", false)
	_spirit.hide()
	_splash()

func _splash() -> void:
	_ripple.show()
	_ripple.frame = 0
	_ripple.play()
