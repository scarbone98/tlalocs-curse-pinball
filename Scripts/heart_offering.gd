extends Node2D
## Tlaloc demands a heart: when his curse breaks (Scripts/table_features.gd), a bloody heart
## (8 Bit Evil Returns' heartbeat, Sprites/table/blood_heart.png) rises in his open mouth,
## beating. Hit it three times to offer it up: the rain stops at once, with points and a
## ball saver for the trouble. While it's there his mouth takes nothing else.

const HEART := preload("res://Sprites/table/blood_heart.png")  # tools/make_table.py: 8 frames beating
const FRAMES := 8
const AT := Vector2(339, 840)  # in his mouth (Scripts/temple_hole.gd)
const RADIUS := 24.0
const HITS := 3
const HIT_COOLDOWN := 0.4
const BEAT_FPS := 10.0
const OFFERED_POINTS := 30000
const HIT_POINTS := 2000
const SAVER_SECONDS := 20.0

var features: Node2D  # TableFeatures

var active := false
var _heart: AnimatedSprite2D
var _body: StaticBody2D
var _shape: CollisionShape2D
var _sensor: Area2D
var _hits := 0
var _cooldown := 0.0
var _flash_left := 0.0
var _blood: CPUParticles2D

func _ready() -> void:
	features.heart = self
	_heart = features._sprite(HEART, FRAMES, AT, BEAT_FPS)
	_heart.z_index = 2  # over the face and the whirl
	_heart.z_as_relative = false
	_heart.hide()
	_body = StaticBody2D.new()
	_body.position = AT
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	_shape.shape = circle
	_shape.disabled = true
	_body.add_child(_shape)
	add_child(_body)
	_sensor = Area2D.new()
	_sensor.position = AT
	_sensor.monitorable = false
	var reach := CollisionShape2D.new()
	var around := CircleShape2D.new()
	around.radius = RADIUS + 8.0
	reach.shape = around
	_sensor.add_child(reach)
	_sensor.body_entered.connect(_on_hit)
	add_child(_sensor)
	_blood = _blood_burst()
	PinballEvents.curse_changed.connect(func(cursed: bool):
		if cursed:
			_rise()
		elif active:
			_sink())

func _blood_burst() -> CPUParticles2D:
	var drop := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	drop.fill(Color.WHITE)
	var blood := CPUParticles2D.new()
	blood.texture = ImageTexture.create_from_image(drop)
	blood.emitting = false
	blood.one_shot = true
	blood.amount = 18
	blood.lifetime = 0.7
	blood.explosiveness = 1.0
	blood.position = AT
	blood.spread = 180.0
	blood.initial_velocity_min = 80.0
	blood.initial_velocity_max = 220.0
	blood.gravity = Vector2(0, 500)
	blood.scale_amount_min = 2.9
	blood.scale_amount_max = 2.9
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.05, 0.08))
	fade.set_color(1, Color(0.4, 0.0, 0.02, 0.0))
	blood.color_ramp = fade
	blood.z_index = 2
	blood.z_as_relative = false
	features.add_child(blood)
	return blood

func _rise() -> void:
	active = true
	_hits = 0
	_heart.show()
	_heart.play()
	_heart.modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(_heart, "modulate:a", 1.0, 0.4)
	_shape.set_deferred("disabled", false)
	AudioSfx.play("shrine", 0.0, Vector2.ONE * 0.7)

func _sink() -> void:
	active = false
	_shape.set_deferred("disabled", true)
	var fade := create_tween()
	fade.tween_property(_heart, "modulate:a", 0.0, 0.4)
	fade.tween_callback(_heart.hide)

func _on_hit(body: Node) -> void:
	if not active or _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown = HIT_COOLDOWN
	_hits += 1
	_flash_left = 0.12
	_blood.restart()
	PinballEvents.rumble.emit(3.0)
	AudioSfx.play("bumper", 0.0, Vector2.ONE * 0.8)
	_heart.speed_scale = 1.0 + 0.5 * _hits  # it beats faster as it weakens
	if _hits < HITS:
		features._award(HIT_POINTS, AT + Vector2(0, -40))
		return
	# offered: the storm breaks off
	features._award(OFFERED_POINTS, AT + Vector2(0, -40))
	PinballEvents.toast.emit("The heart is offered!")
	PinballEvents.effect.emit("gold", AT)
	GameManager.grant_ball_save(SAVER_SECONDS)
	_sink()
	_heart.speed_scale = 1.0
	features._curse_timer.stop()
	features._end_curse()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left -= delta
		_heart.self_modulate = Color(2.0, 2.0, 2.0) if _flash_left > 0.0 else Color.WHITE
