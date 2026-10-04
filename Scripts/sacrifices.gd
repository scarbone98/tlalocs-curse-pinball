extends Node2D
## Tlaloc's sacrifice. Between his curses it waits on the round disc in the middle of the
## golden temple: the beating heart (8 Bit Evil Returns' heartbeat,
## Sprites/table/blood_heart.png), and on later curses a golden idol or an emerald instead,
## turn and turn about. When his curse breaks (Scripts/table_features.gd) it flies down into
## his open mouth: hit it three times to offer it up, each hit knocking the ball well away,
## and the rain stops at once, with points and a ball saver for the trouble. If the curse
## passes first, it flies back up to the temple. While it sits in his mouth, his mouth
## takes nothing else.

const HEART := preload("res://Sprites/table/blood_heart.png")  # tools/make_table.py: 8 frames beating
const IDOL := preload("res://Sprites/table/idol.png")          # tools/make_tiki_idol.py
const GEM := preload("res://Sprites/table/rail_gem.png")       # tools/make_table.py
const ORDER := ["heart", "idol", "emerald"]  # one for each curse, round and round
const MOUTH := Vector2(339, 840)          # in his mouth (Scripts/temple_hole.gd)
const TEMPLE_CIRCLE := Vector2(581, 118)  # the round disc in the middle of the golden temple
const RADIUS := 24.0
const HITS := 3
const HIT_COOLDOWN := 0.6
const KNOCK := 950.0     # how hard a hit on it sends the ball away
const FLY_SECONDS := 0.7
const BEAT_FPS := 10.0
const RETURNS := 8.0     # after one's offered, the next appears on the temple this much later
const OFFERED_POINTS := 30000
const HIT_POINTS := 2000
const SAVER_SECONDS := 20.0
const TOASTS := {"heart": "The heart is offered!", "idol": "The golden idol is offered!", "emerald": "The emerald is offered!"}

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
var _burst: CPUParticles2D

func _ready() -> void:
	features.sacrifices = self
	_sprites["heart"] = _sprite(HEART, 8, BEAT_FPS)
	_sprites["idol"] = _sprite(IDOL, 6, 0.0)
	_sprites["emerald"] = _sprite(GEM, 4, 6.0)  # light sweeping over its facets
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
	PinballEvents.curse_changed.connect(func(cursed: bool):
		if cursed:
			_descend()
		elif active:
			_ascend())

func _sprite(texture: Texture2D, frames: int, fps: float) -> AnimatedSprite2D:
	var sprite: AnimatedSprite2D = features._sprite(texture, frames, TEMPLE_CIRCLE, fps)
	sprite.z_index = 4  # over the temple's art up top, and over his face and whirl below
	sprite.z_as_relative = false
	sprite.hide()
	return sprite

func _kind() -> String:
	return ORDER[_turn % ORDER.size()]

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

# The curse breaks: down it flies, into his mouth
func _descend() -> void:
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	if not sprite.visible:
		return  # none back on the temple yet
	active = true
	_hits = 0
	_returns_left = 0.0
	sprite.modulate.a = 1.0
	var fly := create_tween()
	fly.tween_property(sprite, "position", MOUTH, FLY_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly.tween_callback(func():
		if active:
			_shape.set_deferred("disabled", false))
	AudioSfx.play("shrine", 0.0, Vector2.ONE * 0.7)

# The curse passed by itself: unoffered, it flies back up to the temple
func _ascend() -> void:
	active = false
	_shape.set_deferred("disabled", true)
	var sprite: AnimatedSprite2D = _sprites[_kind()]
	sprite.speed_scale = 1.0
	create_tween().tween_property(sprite, "position", TEMPLE_CIRCLE, FLY_SECONDS)

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
	var colours := {"heart": Color(0.85, 0.05, 0.08), "idol": Color(1.0, 0.82, 0.1), "emerald": Color(0.3, 0.95, 0.55)}
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
	features._curse_timer.stop()
	features._end_curse()

func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
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
