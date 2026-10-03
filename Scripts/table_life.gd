extends Node2D
## Idle life, like Pokemon Pinball's field creatures that move even when nothing hits
## them: the Gilded King blinks while he waits. (The jaguars blink in their slots, in
## Scripts/journey.gd, and the arena's warriors have their own life, in
## Scripts/warriors.gd.)

const KING_IDLE := 0
const KING_BLINK := 3

const REST := Vector2(2.5, 6.0)  # seconds between one creature's idle moves

var features: Node2D  # TableFeatures, which owns the shared sprite helpers

func _ready() -> void:
	_king_blink.call_deferred()

func _schedule(move: Callable, every := REST) -> void:
	get_tree().create_timer(randf_range(every.x, every.y), false).timeout.connect(func():
		move.call()
		_schedule(move, every))

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
