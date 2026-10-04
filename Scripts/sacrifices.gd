extends Node2D
## Tlaloc's sacrifice. It waits on the round disc in the middle of the golden temple: first
## a white goat, then a bronze turkey, and last the beating heart (8 Bit Evil Returns'
## heartbeat, Sprites/table/blood_heart.png), then round again. Three laps round
## inside the temple (Scripts/temple.gd) call it down: it fades from the temple and rises
## up out of Tlaloc's mouth. Hit it three times to offer it up, each hit knocking the ball
## well away, for points and a ball saver (and if his curse is raining, it stops at once).
## Left unoffered too long, it sinks back down his throat and returns to the temple.
## While it sits in his mouth, his mouth gapes, his eyes blaze red, and it takes nothing else.

const HEART := preload("res://Sprites/table/blood_heart.png")  # tools/make_table.py: 8 frames beating
const GOAT := preload("res://Sprites/table/sacrifice_goat.png")      # tools/make_sacrifice_sprites.py
const TURKEY := preload("res://Sprites/table/sacrifice_turkey.png")
const ORDER := ["goat", "turkey", "heart"]  # the heart last, then round again
const MOUTH := Vector2(339, 840)          # in his mouth (Scripts/temple_hole.gd)
const TEMPLE_CIRCLE := Vector2(581, 118)  # the round disc in the middle of the golden temple
const RADIUS := 24.0
const HITS := 3
const HIT_COOLDOWN := 0.6
const KNOCK := 950.0     # how hard a hit on it sends the ball away
const FLY_SECONDS := 0.7
const LAPS_TO_CALL := 3.0   # laps round the temple, all told, that call the sacrifice down
const RISE := 18.0          # scene units it rises up out of his mouth
const WAIT_SECONDS := 40.0  # unoffered this long, it goes back to the temple
const BEAT_FPS := 10.0
const RETURNS := 8.0     # after one's offered, the next appears on the temple this much later
const OFFERED_POINTS := 30000
const HIT_POINTS := 2000
const SAVER_SECONDS := 20.0
const TOASTS := {"heart": "The heart is offered!", "goat": "The goat is offered!", "turkey": "The turkey is offered!"}

var features: Node2D  # TableFeatures

var active := false  # it's in his mouth (or flying there)
var _turn := 0       # which of ORDER is next
var _sprites := {}   # kind -> AnimatedSprite2D
var _body: StaticBody2D
var _shape: CollisionShape2D
var _hits := 0
var _cooldown := 0.0
var _flash_left := 0.0
var _returns_left := 0.0
var _clock := 0.0
var _laps := 0.0
var _wait_left := 0.0
var _burst: CPUParticles2D

func _ready() -> void:
	features.sacrifices = self
	_sprites["heart"] = _sprite(HEART, 8, BEAT_FPS)
	_sprites["goat"] = _sprite(GOAT, 6, 3.0)      # its tail flicks, it blinks, it bleats
	_sprites["turkey"] = _sprite(TURKEY, 6, 3.0)  # its fan quivers, it blinks, it gobbles
	_body = StaticBody2D.new()
	_body.position = MOUTH
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	_shape.shape = circle
	_shape.disabled = true
	_body.add_child(_shape)
	add_child(_body)
	var sensor := Area2D.new()
	sensor.position = MOUTH
	sensor.monitorable = false
	var reach := CollisionShape2D.new()
	var around := CircleShape2D.new()
	around.radius = RADIUS + 8.0
	reach.shape = around
	sensor.add_child(reach)
	sensor.body_entered.connect(_on_hit)
	add_child(sensor)
	_burst = _make_burst()
	_show_waiting()


func _sprite(texture: Texture2D, frames: int, fps: float) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = features._sprite(texture, frames, TEMPLE_CIRCLE, fps)
	sprite.z_index = 4  # over the temple's art up top, and over his face and whirl below
	sprite.z_as_relative = false
	sprite.hide()
	return sprite

func _kind() -> String:
	return ORDER[_turn % ORDER.size()]

## The sacrifice in sight: on the temple, or in his mouth (for the spotlight on it)
func current() -> AnimatedSprite2D:
	return _sprites[_kind()]

## Laps the ball made round inside the temple; enough of them call the sacrifice down
func add_laps(laps: float) -> void:
	if active:
		return
	_laps += laps
	if _laps >= LAPS_TO_CALL:
		_laps = 0.0
		_descend()

func _make_burst() -> CPUParticles2D:
	var drop := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	drop.fill(Color.WHITE)
	var burst := CPUParticles2D.new()
	burst.texture = ImageTexture.create_from_image(drop)
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 18
	burst.lifetime = 0.7
	burst.explosiveness = 1.0
	burst.position = MOUTH
	burst.spread = 180.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2(0, 500)
	burst.scale_amount_min = 2.9
	burst.scale_amount_max = 2.9
	burst.z_index = 4
	burst.z_as_relative = false
	features.add_child(burst)
	return burst

# The next sacrifice appears on the temple, waiting
func _show_waiting() -> void:
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	sprite.position = TEMPLE_CIRCLE
	sprite.show()
	sprite.play()
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, 1.0)

# Called down: it fades from the temple and rises up out of his mouth
func _descend() -> void:
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	if not sprite.visible:
		return  # none back on the temple yet
	active = true
	_hits = 0
	_returns_left = 0.0
	_wait_left = WAIT_SECONDS
	var move := create_tween()
	move.tween_property(sprite, "modulate:a", 0.0, FLY_SECONDS * 0.5)
	move.tween_callback(func():
		sprite.position = MOUTH + Vector2(0, RISE))
	move.tween_property(sprite, "position", MOUTH, FLY_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	move.parallel().tween_property(sprite, "modulate:a", 1.0, FLY_SECONDS * 0.6)
	move.tween_callback(func():
		if active:
			_shape.set_deferred("disabled", false))
	AudioSfx.play("shrine", 0.0, Vector2.ONE * 0.7)

# Unoffered too long: it sinks back down his throat and returns to the temple
func _ascend() -> void:
	active = false
	_shape.set_deferred("disabled", true)
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	sprite.speed_scale = 1.0
	var move := create_tween()
	move.tween_property(sprite, "position", MOUTH + Vector2(0, RISE), FLY_SECONDS * 0.6)
	move.parallel().tween_property(sprite, "modulate:a", 0.0, FLY_SECONDS * 0.6)
	move.tween_callback(func():
		sprite.position = TEMPLE_CIRCLE)
	move.tween_property(sprite, "modulate:a", 1.0, FLY_SECONDS)

func _on_hit(body: Node) -> void:
	if not active or _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown = HIT_COOLDOWN
	_hits += 1
	_flash_left = 0.12
	var ball := body as RigidBody2D
	var away := (ball.global_position - MOUTH).normalized()
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	ball.linear_velocity = away.rotated(randf_range(-0.25, 0.25)) * KNOCK  # knocked well away
	_burst.color_ramp = _burst_colours(_kind())
	_burst.restart()
	PinballEvents.rumble.emit(3.0)
	AudioSfx.play("bumper", 0.0, Vector2.ONE * 0.8)
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	if _kind() == "heart":
		sprite.speed_scale = 1.0 + 0.5 * _hits  # it beats faster as it weakens
	if _hits < HITS:
		features._award(HIT_POINTS, MOUTH + Vector2(0, -40))
		return
	_offer()

func _burst_colours(kind: String) -> Gradient:
	var colours := {"heart": Color(0.85, 0.05, 0.08), "goat": Color(0.95, 0.93, 0.86), "turkey": Color(0.62, 0.4, 0.2)}
	var colour: Color = colours[kind]
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	return fade

# Offered: the storm breaks off, and the next sacrifice will turn up on the temple
func _offer() -> void:
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	features._award(OFFERED_POINTS, MOUTH + Vector2(0, -40))
	PinballEvents.toast.emit(TOASTS[_kind()])
	PinballEvents.effect.emit("gold", MOUTH)
	GameManager.grant_ball_save(SAVER_SECONDS)
	active = false
	_shape.set_deferred("disabled", true)
	sprite.hide()
	sprite.speed_scale = 1.0
	_turn += 1
	_returns_left = RETURNS
	if GameManager.curse_active:  # and Tlaloc's rain stops
		features._curse_timer.stop()
		features._end_curse()

func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if active and _wait_left > 0.0:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_ascend()
	if _returns_left > 0.0:
		_returns_left -= delta
		if _returns_left <= 0.0:
			_show_waiting()
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	if _flash_left > 0.0:
		_flash_left -= delta
		sprite.self_modulate = Color(2.0, 2.0, 2.0) if _flash_left > 0.0 else Color.WHITE
	# waiting on the temple, it bobs gently on its disc
	sprite.offset.y = (-1.0 if fposmod(_clock, 1.6) < 0.8 else 0.0) if not active else 0.0
