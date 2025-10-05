extends Control

@onready var score_label: Label       = $HBoxContainer/ScoreLabel
@onready var lives_label: Label       = $HBoxContainer/LivesLabel

var _score: int = 0
var _tween: Tween

func _ready() -> void:
	# Connect to global events
	PinballEvents.add_score.connect(_on_add_score)
	PinballEvents.set_score.connect(_on_set_score)
	PinballEvents.lives_changed.connect(_on_lives_changed)
	PinballEvents.toast.connect(_on_toast)
	PinballEvents.ball_drained.connect(_on_ball_drained)

	_render_score()
	_render_lives() # default; your GameManager can call lives_changed on start

func _on_add_score(points: int) -> void:
	_score += points
	_render_score()

func _on_set_score(value: int) -> void:
	_score = value
	_render_score()

func _on_lives_changed(lives: int) -> void:
	_render_lives()

func _on_ball_drained() -> void:
	_on_toast("[center]Ball drained![/center]")

func _on_toast(message: String) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.0)         # hold visible for a second

func _render_score() -> void:
	score_label.text = "SCORE: %06d" % GameManager.score

func _render_lives() -> void:
	lives_label.text = "BALLS: %d" % GameManager.lives
