extends Node2D
## Sacrifices for Tlaloc. Between times the beating heart (8 Bit Evil Returns' heartbeat,
## Sprites/table/blood_heart.png) waits on top of the golden temple. When his curse breaks
## it flies down into his open mouth; other sacrifices fly there when they're won: the
## golden idol claimed from the tower, the emerald taken from the left rail. One sits in
## his mouth at a time (the rest wait their turn), and a few hits offer it up, each one
## knocking the ball well away. The heart stops the rain at once; the idol and the emerald
## pay their own rewards. While a sacrifice sits in his mouth, it takes nothing else.

const HEART := preload("res://Sprites/table/blood_heart.png")  # tools/make_table.py: 8 frames beating
const IDOL := preload("res://Sprites/table/idol.png")          # tools/make_tiki_idol.py
const GEM := preload("res://Sprites/table/rail_gem.png")       # tools/make_table.py
const MOUTH := Vector2(339, 840)    # in his mouth (Scripts/temple_hole.gd)
const TEMPLE_TOP := Vector2(588, 52)  # where the heart waits, on the golden temple's crown
const RADIUS := 24.0
const HIT_COOLDOWN := 0.6
const KNOCK := 950.0     # how hard a hit on a sacrifice sends the ball away
const FLY_SECONDS := 0.7
const BEAT_FPS := 10.0
const HEART_REGROWS := 8.0  # after it's offered, a new heart beats on the temple again
const HIT_POINTS := 2000
# kind: [hits to offer it, points, toast]
const KINDS := {
	"heart": [3, 30000, "The heart is offered!"],
	"idol": [3, 25000, "The golden idol is offered! Bonus +1"],
	"emerald": [2, 15000, "The emerald is offered! Ball saver"],
}
const SAVER_SECONDS := {"heart": 20.0, "emerald": 15.0}

var features: Node2D  # TableFeatures

var active := false  # a sacrifice sits in his mouth, ready to be hit
var _kind := ""      # the one in his mouth (or on its way there)
var _queue: Array = []  # [kind, from]
var _sprites := {}  # kind -> AnimatedSprite2D
var _waiting_heart: AnimatedSprite2D  # the heart on the temple between times
var _body: StaticBody2D
var _shape: CollisionShape2D
var _hits := 0
var _cooldown := 0.0
var _flash_left := 0.0
var _regrow_left := 0.0
var _clock := 0.0
var _burst: CPUParticles2D

func _ready() -> void:
	features.sacrifices = self
	_waiting_heart = _sprite(HEART, 8, TEMPLE_TOP, BEAT_FPS)
	_waiting_heart.play()
	_sprites["heart"] = _sprite(HEART, 8, MOUTH, BEAT_FPS)
	_sprites["idol"] = _sprite(IDOL, 6, MOUTH, 0.0)
	_sprites["emerald"] = _sprite(GEM, 2, MOUTH, 0.0)
	for kind: String in _sprites:
		_sprites[kind].hide()
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
	PinballEvents.curse_changed.connect(func(cursed: bool):
		if cursed and _waiting_heart.visible:
			bring("heart", TEMPLE_TOP)
		elif not cursed:
			_withdraw_heart())

func _sprite(texture: Texture2D, frames: int, at: Vector2, fps: float) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = features._sprite(texture, frames, at, fps)
	sprite.z_index = 4  # over the temple's art up top, and over his face and whirl below
	sprite.z_as_relative = false
	return sprite

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

## A sacrifice flies from `from` to his mouth (or waits its turn behind the one there)
func bring(kind: String, from: Vector2) -> void:
	if _kind != "":
		if kind == "heart":
			_queue.push_front([kind, from])  # the curse's heart comes first
		else:
			_queue.append([kind, from])
		return
	_kind = kind
	_hits = 0
	if kind == "heart":
		_waiting_heart.hide()
	var sprite: AnimatedSprite2D = _sprites[kind]
	sprite.position = from
	sprite.show()
	sprite.play()
	var fly := create_tween()
	fly.tween_property(sprite, "position", MOUTH, FLY_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly.tween_callback(func():
		if _kind == kind:
			active = true
			_shape.set_deferred("disabled", false))
	AudioSfx.play("shrine", 0.0, Vector2.ONE * 0.7)

# The curse lifted by itself: an unoffered heart goes back up on the temple
func _withdraw_heart() -> void:
	for i in range(_queue.size() - 1, -1, -1):
		if _queue[i][0] == "heart":
			_queue.remove_at(i)
			_waiting_heart.show()
	if _kind != "heart":
		return
	var sprite: AnimatedSprite2D = _sprites["heart"]
	_end_turn()
	sprite.show()
	var fly := create_tween()
	fly.tween_property(sprite, "position", TEMPLE_TOP, FLY_SECONDS)
	fly.tween_callback(func():
		sprite.hide()
		_waiting_heart.show())

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
	_burst.color_ramp = _burst_colours(_kind)
	_burst.restart()
	PinballEvents.rumble.emit(3.0)
	AudioSfx.play("bumper", 0.0, Vector2.ONE * 0.8)
	var sprite: AnimatedSprite2D = _sprites[_kind]
	if _kind == "heart":
		sprite.speed_scale = 1.0 + 0.5 * _hits  # it beats faster as it weakens
	if _hits < KINDS[_kind][0]:
		features._award(HIT_POINTS, MOUTH + Vector2(0, -40))
		return
	_offer()

func _burst_colours(kind: String) -> Gradient:
	var colours := {"heart": Color(0.85, 0.05, 0.08), "idol": Color(1.0, 0.82, 0.1), "emerald": Color(0.3, 0.95, 0.55)}
	var colour: Color = colours[kind]
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	return fade

func _offer() -> void:
	var kind := _kind
	features._award(KINDS[kind][1], MOUTH + Vector2(0, -40))
	PinballEvents.toast.emit(KINDS[kind][2])
	PinballEvents.effect.emit("gold", MOUTH)
	if SAVER_SECONDS.has(kind):
		GameManager.grant_ball_save(SAVER_SECONDS[kind])
	if kind == "idol":
		GameManager.add_bonus_multiplier(1)
	_end_turn()
	if kind == "heart":
		_regrow_left = HEART_REGROWS
		features._curse_timer.stop()
		features._end_curse()

# Clears his mouth, and the next sacrifice in line comes down
func _end_turn() -> void:
	var sprite: AnimatedSprite2D = _sprites[_kind]
	sprite.hide()
	sprite.speed_scale = 1.0
	active = false
	_kind = ""
	_shape.set_deferred("disabled", true)
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		bring.call_deferred(next[0], next[1])

func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _regrow_left > 0.0:
		_regrow_left -= delta
		if _regrow_left <= 0.0 and _kind != "heart":
			_waiting_heart.show()
			_waiting_heart.modulate.a = 0.0
			create_tween().tween_property(_waiting_heart, "modulate:a", 1.0, 1.0)
	if _flash_left > 0.0 and _kind != "":
		_flash_left -= delta
		(_sprites[_kind] as AnimatedSprite2D).self_modulate = Color(2.0, 2.0, 2.0) if _flash_left > 0.0 else Color.WHITE
	# the one on the temple bobs gently on its altar
	_waiting_heart.offset.y = -1.0 if fposmod(_clock, 1.6) < 0.8 else 0.0
