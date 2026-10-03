extends Node2D
## Idle life, like Pokemon Pinball's field creatures that move even when nothing hits
## them: the mushrooms bob on their stalks, the serpents flick their tongues and the
## Gilded King blinks. Each only plays while that creature is resting, so it never
## fights a hit animation.

const SERPENT_IDLE := 0
const SERPENT_TONGUE := 2
const KING_IDLE := 0
const KING_BLINK := 3

const REST := Vector2(2.5, 6.0)  # seconds between one creature's idle moves
const BOB_SQUASH := Vector2(1.08, 0.9)  # a mushroom's cap settling on its stalk

var features: Node2D  # TableFeatures, which owns the shared sprite helpers

func _ready() -> void:
	var patch := features.get_node_or_null(^"../mushrooms")
	if patch:
		for mushroom in patch.get_children():
			var sprite := mushroom.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
			if sprite:
				_schedule(_bob.bind(sprite))
	for serpent in features.journey._serpents:
		_schedule(_flash_frame.bind(serpent, SERPENT_IDLE, SERPENT_TONGUE, 0.3))
	_king_blink.call_deferred()

func _schedule(move: Callable, every := REST) -> void:
	get_tree().create_timer(randf_range(every.x, every.y), false).timeout.connect(func():
		move.call()
		_schedule(move, every))

# The mushroom squashes down and springs back up, unless it's busy being hit
func _bob(mushroom: AnimatedSprite2D) -> void:
	if mushroom.is_playing():
		return
	var rest := mushroom.scale
	var bob := mushroom.create_tween()
	bob.tween_property(mushroom, "scale", rest * BOB_SQUASH, 0.12)
	bob.tween_property(mushroom, "scale", rest, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
