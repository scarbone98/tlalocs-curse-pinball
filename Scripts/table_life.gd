extends Node2D
## Idle life, like Pokemon Pinball's field creatures that move even when nothing hits
## them: the frogs blink and puff their throats, the serpents flick their tongues, the
## Gilded King blinks, and ripples spread across the frog pool. Each only plays while
## that creature is resting, so it never fights a hit animation.

const FROG_SHEET := preload("res://bumper_mushroom.png")
const RIPPLE := preload("res://Sprites/table/ripple.png")

const FROG_SIZE := 42
enum { FROG_IDLE, FROG_HIT, FROG_BLINK, FROG_PUFF }
const SERPENT_IDLE := 0
const SERPENT_TONGUE := 2
const KING_IDLE := 0
const KING_BLINK := 3

const REST := Vector2(2.5, 6.0)  # seconds between one creature's idle moves
const RIPPLE_EVERY := Vector2(1.2, 2.8)
# Open water in the frog pool, clear of the frogs themselves
const POOL := Rect2(322, 360, 180, 175)
const FROG_CLEARANCE := 48.0

var features: Node2D  # TableFeatures, which owns the shared sprite helpers

var _frogs: Array[AnimatedSprite2D] = []
var _frog_positions: Array[Vector2] = []

func _ready() -> void:
	var pool := features.get_node_or_null(^"../mushrooms")
	if pool:
		for frog in pool.get_children():
			var sprite := frog.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
			if sprite:
				_add_frog_moves(sprite.sprite_frames)
				sprite.animation_finished.connect(_rest_frog.bind(sprite))
				_frogs.append(sprite)
				_frog_positions.append(frog.global_position)
	for frog in _frogs:
		_schedule(_frog_move.bind(frog))
	for serpent in features.journey._serpents:
		_schedule(_flash_frame.bind(serpent, SERPENT_IDLE, SERPENT_TONGUE, 0.3))
	_schedule(_ripple, RIPPLE_EVERY)
	_king_blink.call_deferred()

# The frogs share one SpriteFrames; the blink and puff are extra animations on it
func _add_frog_moves(frames: SpriteFrames) -> void:
	if frames.has_animation(&"blink"):
		return
	for move in [[&"blink", [FROG_IDLE, FROG_BLINK, FROG_IDLE], 8.0], [&"puff", [FROG_IDLE, FROG_PUFF, FROG_PUFF, FROG_IDLE], 5.0]]:
		frames.add_animation(move[0])
		frames.set_animation_loop(move[0], false)
		frames.set_animation_speed(move[0], move[2])
		for index in move[1]:
			var atlas := AtlasTexture.new()
			atlas.atlas = FROG_SHEET
			atlas.region = Rect2(index * FROG_SIZE, 0, FROG_SIZE, FROG_SIZE)
			frames.add_frame(move[0], atlas)

func _schedule(move: Callable, every := REST) -> void:
	get_tree().create_timer(randf_range(every.x, every.y), false).timeout.connect(func():
		move.call()
		_schedule(move, every))

func _frog_move(frog: AnimatedSprite2D) -> void:
	if frog.animation == &"default" and not frog.is_playing():
		frog.play(&"blink" if randf() < 0.6 else &"puff")

func _rest_frog(frog: AnimatedSprite2D) -> void:
	if frog.animation != &"default":
		frog.animation = &"default"
		frog.frame = FROG_IDLE

func _flash_frame(sprite: AnimatedSprite2D, rest: int, move: int, seconds: float) -> void:
	if sprite.frame != rest:
		return
	sprite.frame = move
	get_tree().create_timer(seconds, false).timeout.connect(func():
		if sprite.frame == move:
			sprite.frame = rest)

# The King lives in the El Dorado chamber, which is added a frame after the table
func _king_blink() -> void:
	var king: AnimatedSprite2D = features.el_dorado._king_sprite
	if king:
		_schedule(_flash_frame.bind(king, KING_IDLE, KING_BLINK, 0.15), Vector2(1.8, 4.5))

func _ripple() -> void:
	for attempt in 6:
		var at := POOL.position + Vector2(randf() * POOL.size.x, randf() * POOL.size.y)
		if _frog_positions.all(func(frog): return at.distance_to(frog) > FROG_CLEARANCE):
			var ripple: AnimatedSprite2D = features._sprite(RIPPLE, 4, at, 8.0)
			ripple.sprite_frames.set_animation_loop("default", false)
			ripple.modulate.a = 0.7
			ripple.animation_finished.connect(ripple.queue_free)
			ripple.play()
			return
