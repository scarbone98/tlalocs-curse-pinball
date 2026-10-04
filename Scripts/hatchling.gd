extends Node2D
## A hatchling: a young spirit of the current city that breaks out of the tiki's nest
## and wanders a winding path across the middle of the table, like the hatched critter
## on Pokemon Pinball Ruby's field. Hit it twice before it wanders off the far end to
## catch it for the Spirit Codex. It comes with a short ball saver and lights a bonus lamp.

const SPIRITS := preload("res://Sprites/table/spirits.png")  # tools/make_spirit_sprites.py
const SPIRIT_SIZE := Vector2(26, 22)

# Its walk across the open floor, clear of the walls and of Tlaloc's face (scene units)
const PATH := [
	Vector2(250, 560), Vector2(240, 640), Vector2(245, 710), Vector2(240, 775), Vector2(255, 865),
	Vector2(305, 935), Vector2(375, 935), Vector2(430, 870), Vector2(445, 790), Vector2(440, 720),
	Vector2(400, 690), Vector2(360, 690),
]
const SPEED := 45.0
const HIT_RADIUS := 24.0
const HITS_TO_CATCH := 2
const HIT_COOLDOWN := 0.4
const BOUNCE_SPEED := 700.0
const SAVER := 30.0
const HIT_POINTS := 1000
const CATCH_POINTS := 75000
const HOP_EVERY := 0.25

enum { IDLE_A, IDLE_B, HIT }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var active := false

var _species := 0
var _hits := 0
var _cooldown := 0.0
var _next := 1
var _clock := 0.0
var _area: Area2D
var _sprite: AnimatedSprite2D

func _ready() -> void:
	_area = Area2D.new()
	_area.monitorable = false
	_area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	_area.body_entered.connect(_on_ball)
	add_child(_area)
	_sprite = AnimatedSprite2D.new()
	_sprite.scale = features.MAP_SCALE
	_sprite.z_index = 2  # over Tlaloc's face as it wanders past
	_sprite.z_as_relative = false
	features.add_child(_sprite)
	_sprite.hide()

## Hatches a young spirit at the nest, which sets off across the table
func hatch() -> void:
	if active:
		return
	active = true
	_species = SpiritCodex.pick(features.journey.city)
	var frames := SpriteFrames.new()
	for i in 3:
		var atlas := AtlasTexture.new()
		atlas.atlas = SPIRITS
		atlas.region = Rect2(Vector2(i, _species) * SPIRIT_SIZE, SPIRIT_SIZE)
		frames.add_frame("default", atlas)
	_sprite.sprite_frames = frames
	_hits = 0
	_next = 1
	_clock = 0.0
	_area.position = PATH[0]
	_sprite.position = PATH[0]
	_sprite.show()
	_area.set_deferred("monitoring", true)
	PinballEvents.banner.emit("A hatchling!", Billboard.SPIRIT + _species)
	GameManager.grant_ball_save(SAVER)
	PinballEvents.mode_changed.emit()
	AudioSfx.play("spirit")

func _physics_process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var target: Vector2 = PATH[_next]
	var at := _area.position.move_toward(target, SPEED * delta)
	if at.distance_to(target) < 0.5:
		_next += 1
		if _next >= PATH.size():
			PinballEvents.toast.emit("The hatchling wandered off")
			_end()
			return
	_sprite.flip_h = target.x < _area.position.x
	_area.position = at
	# it hops along a pixel at a time, blinking as it goes
	var hop: float = features.MAP_SCALE.y if int(_clock / HOP_EVERY) % 2 == 0 else 0.0
	_sprite.position = at - Vector2(0, hop)
	if _cooldown == 0.0:
		_sprite.frame = IDLE_A if int(_clock * 3.0) % 2 == 0 else IDLE_B
	PinballEvents.objective_changed.emit("Catch the hatchling: %d/%d" % [_hits, HITS_TO_CATCH])

func _on_ball(body: Node) -> void:
	if not active or _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	var ball := body as RigidBody2D
	_cooldown = HIT_COOLDOWN
	_hits += 1
	var away := (ball.global_position - _area.position).normalized()
	ball.linear_velocity = away * maxf(ball.linear_velocity.length(), BOUNCE_SPEED)
	_sprite.frame = HIT
	AudioSfx.play("spirit_hit", 0.0, Vector2.ONE * (1.0 + 0.2 * _hits))
	features._award(HIT_POINTS, _area.position)
	if _hits < HITS_TO_CATCH:
		PinballEvents.toast.emit("Hatchling %d/%d" % [_hits, HITS_TO_CATCH])
		return
	var spirit: Dictionary = SpiritCodex.SPECIES[_species]
	var first := SpiritCodex.register(_species)
	features._award(CATCH_POINTS, _area.position + Vector2(0, -40))
	PinballEvents.billboard.emit(Billboard.SPIRIT + _species,
		("New in the Codex: %s!" if first else "%s hatchling caught!") % spirit.name)
	PinballEvents.effect.emit("gold", _area.position)
	AudioSfx.play("catch")
	GameManager.add_bonus_lamps(1)
	PinballEvents.hatched.emit()
	_end()

func _end() -> void:
	active = false
	_area.set_deferred("monitoring", false)
	_sprite.hide()
	PinballEvents.mode_changed.emit()
	features.journey._announce_goal()
