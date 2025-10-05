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

	if lives < 0:
		_game_over()

func _on_add_score(points: int):
	score += points
	print("Addtion score", score)
	PinballEvents.set_score.emit(score)

func _game_over():
	# Here you can stop spawning balls, show restart UI, etc.
	score = 0
	lives = starting_lives
	PinballEvents.set_score.emit(0) # optional, reset score at start
	PinballEvents.lives_changed.emit(starting_lives)
