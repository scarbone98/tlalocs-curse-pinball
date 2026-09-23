extends Node

@export var starting_lives := 3
var lives : int
var score : int = 0

func _ready():
	lives = starting_lives
	score = 0
	# Hook up to the global event bus
	PinballEvents.ball_drained.connect(_on_ball_drained)
	PinballEvents.add_score.connect(_on_add_score)

	# Tell the UI the initial lives
	PinballEvents.lives_changed.emit(lives)
	PinballEvents.set_score.emit(0) # optional, reset score at start

func _on_ball_drained():
	lives -= 1
	PinballEvents.lives_changed.emit(lives)

	if lives <= 0:
		_game_over()
	elif lives == 1:
		PinballEvents.toast.emit("Last ball!")
	else:
		PinballEvents.toast.emit("Ball drained!")

func _on_add_score(points: int):
	score += points
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
	get_tree().paused = false
	get_tree().reload_current_scene()

func _submit_arcade_score(final_score: int) -> void:
	if not OS.has_feature("web"):
		return

	var script := "window.parent && window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*');" % final_score
	JavaScriptBridge.eval(script)
