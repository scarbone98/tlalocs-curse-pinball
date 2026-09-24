extends Node2D
## Catch mode, like Catch 'Em mode in Pokemon Pinball: every third ramp shot (or a
## full Chac Mool bowl, or the roulette) a spirit of the current city rises out of the
## temple floor, now and then its rare one. Hit it three times before it sinks back
## down to catch it; every catch goes in the Spirit Codex, which is kept between games.

const SPIRITS := preload("res://Sprites/table/spirits.png")  # tools/make_spirit_sprites.py
const SPIRIT_SIZE := Vector2(18, 14)
const RIPPLE := preload("res://Sprites/table/ripple.png")

const SPAWN_AT := Vector2(337, 760)  # below the temple hole, above the face
const RIPPLE_OFFSET := Vector2(0, 26)
const HIT_RADIUS := 26.0
const RAMPS_TO_SUMMON := 3
const HITS_TO_CATCH := 3
const CATCH_SECONDS := 30.0
const WARN_SECONDS := 5.0  # the spirit flickers when it's about to sink
const HIT_POINTS := 1000
const CATCH_POINTS := 25000
const RARE_MULTIPLIER := 2          # a rare spirit is worth twice as much
const NEW_SPIRIT_POINTS := 20000    # first time it goes in the Codex
const CITY_COMPLETE_POINTS := 100000  # the last of a city's four
const BOUNCE_SPEED := 750.0
const HIT_COOLDOWN := 0.35
const ART_PIXEL_Y := 1280.0 / 424.0  # one table-art pixel, vertically (see TableFeatures.MAP_SCALE)

enum { IDLE_A, IDLE_B, HIT }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var caught := 0
var species := 0  # which spirit is up, an index into SpiritCodex.SPECIES

var _ramps := 0
var _active := false
var _hits := 0
var _time_left := 0.0
var _cooldown := 0.0
var _clock := 0.0
var _area: Area2D
var _spirit: AnimatedSprite2D
var _ripple: AnimatedSprite2D
var _frames := {}  # species -> SpriteFrames for its row of the sheet

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
	_spirit = AnimatedSprite2D.new()
	_spirit.scale = features.MAP_SCALE
	_spirit.position = SPAWN_AT
	features.add_child(_spirit)
	_spirit.hide()

	PinballEvents.ramp_made.connect(_on_ramp_made)

func _on_ramp_made(_side: String, _combo: int) -> void:
	if _active:
		return
	_ramps += 1
	if _ramps >= RAMPS_TO_SUMMON:
		_ramps = 0
		_summon()

## Raises a spirit now (the temple's roulette can award one). False if one is already up.
func summon() -> bool:
	if _active:
		return false
	_ramps = 0
	_summon()
	return true

func _frames_for(index: int) -> SpriteFrames:
	if not _frames.has(index):
		var frames := SpriteFrames.new()
		for i in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = SPIRITS
			atlas.region = Rect2(Vector2(i, index) * SPIRIT_SIZE, SPIRIT_SIZE)
			frames.add_frame("default", atlas)
		_frames[index] = frames
	return _frames[index]

func _summon() -> void:
	species = SpiritCodex.pick(features.journey.city)
	_spirit.sprite_frames = _frames_for(species)
	var spirit: Dictionary = SpiritCodex.SPECIES[species]
	_active = true
	_hits = 0
	_time_left = CATCH_SECONDS
	_clock = 0.0
	_splash()
	_spirit.frame = IDLE_A
	_spirit.show()
	_area.set_deferred("monitoring", true)
	var caption := ("A rare %s rises!" if spirit.rare else "A %s rises!") % spirit.name
	PinballEvents.billboard.emit(Billboard.SPIRIT + species, caption)
	PinballEvents.spirit_changed.emit(true)
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
	var spirit: Dictionary = SpiritCodex.SPECIES[species]
	var first := SpiritCodex.register(species)
	var points: int = CATCH_POINTS * caught * (RARE_MULTIPLIER if spirit.rare else 1)
	features._award(points, SPAWN_AT + Vector2(0, -40))
	if first:
		features._award(NEW_SPIRIT_POINTS, SPAWN_AT + Vector2(0, -80))
	PinballEvents.billboard.emit(Billboard.SPIRIT + species,
		("New in the Codex: %s!" if first else "%s caught!") % spirit.name)
	AudioSfx.play("catch")
	PinballEvents.effect.emit("gold", SPAWN_AT)
	if first and SpiritCodex.city_complete(spirit.city):
		features._award(CITY_COMPLETE_POINTS, SPAWN_AT + Vector2(0, -120))
		get_tree().create_timer(2.8).timeout.connect(func():
			PinballEvents.toast.emit("%s's spirits complete!" % features.journey.CITIES[spirit.city].name))
	PinballEvents.spirit_caught.emit()
	_dismiss()

func _dismiss() -> void:
	_active = false
	PinballEvents.spirit_changed.emit(false)
	_area.set_deferred("monitoring", false)
	_spirit.hide()
	_splash()

func _splash() -> void:
	_ripple.show()
	_ripple.frame = 0
	_ripple.play()
