extends Node

@export var starting_lives := 3
@export var ball_save_seconds := 8.0  # a quick drain right after launch gives the ball back once

var lives : int
var score : int = 0
var multiplier := 1
var curse_active := false

var _ball_save_left := 0.0
var _ball_save_used := false

func _ready():
	lives = starting_lives
	score = 0
	# Hook up to the global event bus
	PinballEvents.ball_drained.connect(_on_ball_drained)
	PinballEvents.add_score.connect(_on_add_score)
	PinballEvents.ball_launched.connect(_on_ball_launched)

	# Tell the UI the initial lives
	PinballEvents.lives_changed.emit(lives)
	PinballEvents.set_score.emit(0) # optional, reset score at start

func _physics_process(delta: float) -> void:
	_ball_save_left = maxf(_ball_save_left - delta, 0.0)

# Everything scored is scaled by the bonus multiplier, and doubled during the curse
func score_factor() -> int:
	return multiplier * (2 if curse_active else 1)

func set_multiplier(value: int) -> void:
	multiplier = value
	PinballEvents.multiplier_changed.emit(multiplier)

func set_curse_active(active: bool) -> void:
	curse_active = active
	PinballEvents.curse_changed.emit(active)

## A ball saver for the next few seconds (the torches award one): a drain gives the ball back
func grant_ball_save(seconds: float) -> void:
	_ball_save_left = maxf(_ball_save_left, seconds)

func ball_save_left() -> float:
	return _ball_save_left

func _on_ball_launched():
	if not _ball_save_used:
		_ball_save_left = ball_save_seconds

func _on_ball_drained():
	if _ball_save_left > 0.0:
		_ball_save_left = 0.0
		_ball_save_used = true
		PinballEvents.toast.emit("Ball saved!")
		return

	_ball_save_used = false
	lives -= 1
	PinballEvents.lives_changed.emit(lives)
	if multiplier > 1:
		set_multiplier(1)

	if lives <= 0:
		_game_over()
	elif lives == 1:
		PinballEvents.toast.emit("Last ball!")
	else:
		PinballEvents.toast.emit("Ball drained!")

func _on_add_score(points: int):
	score += points * score_factor()
	PinballEvents.set_score.emit(score)

func _game_over():
	var final_score := score
	_submit_arcade_score(final_score)

	var is_new_best := HighScore.submit(final_score)
	get_tree().paused = true
	PinballEvents.game_over.emit(final_score, is_new_best)

# Called by the game over screen; the scene reloads so the table starts fresh.
func restart() -> void:
	score = 0
	lives = starting_lives
	multiplier = 1
	curse_active = false
	_ball_save_left = 0.0
	_ball_save_used = false
	get_tree().paused = false
	get_tree().reload_current_scene()

func _submit_arcade_score(final_score: int) -> void:
	if not OS.has_feature("web"):
		return

	var script := "window.parent && window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*');" % final_score
	JavaScriptBridge.eval(script)
