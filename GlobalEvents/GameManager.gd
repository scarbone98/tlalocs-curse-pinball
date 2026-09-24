extends Node

@export var starting_lives := 3
@export var ball_save_seconds := 8.0  # a quick drain right after launch gives the ball back once

var lives : int
var score : int = 0
var multiplier := 1
var curse_active := false
var show_title := true  # the title menu opens on load; Play Again goes straight back in

## Game speed. The physics match Pokemon Pinball 1:1 at its own 60Hz; Relaxed slows the
## whole game evenly (time itself, so every proportion stays the same) for a floatier feel.
const SPEEDS := [["1:1", 1.0], ["Relaxed", 0.8]]
const SETTINGS_PATH := "user://settings.cfg"
var speed_index := 0

var _ball_save_left := 0.0
var _ball_save_used := false

func _ready():
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		speed_index = clampi(int(config.get_value("options", "speed", 0)), 0, SPEEDS.size() - 1)
	_apply_speed()
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

## One more ball (the jaguar awards these)
func award_extra_ball() -> void:
	lives += 1
	PinballEvents.lives_changed.emit(lives)

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
func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_apply_speed()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("options", "speed", speed_index)
	config.save(SETTINGS_PATH)

func speed_name() -> String:
	return SPEEDS[speed_index][0]

func _apply_speed() -> void:
	Engine.time_scale = SPEEDS[speed_index][1]

## Back to the title menu, with a fresh table behind it
func to_title() -> void:
	show_title = true
	restart()

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
