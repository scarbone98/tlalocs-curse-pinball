extends Node

@export var starting_lives := 3

## Ball savers, as generous as Pokemon Pinball Ruby & Sapphire's: a long one on the
## first ball, a shorter one on every ball after, and the modes hand out their own
## (see grant_ball_save). A drain while one runs gives the ball back, and the saver
## keeps running until its time is up.
const FIRST_BALL_SAVER := 60.0
const BALL_SAVER := 30.0

## The end-of-ball bonus: each thing done this ball is worth this much, all of it
## times the bonus multiplier (which goes back to x1 for the next ball).
const TALLY := [
	["spirits", "Spirits caught", 12500],
	["hatchlings", "Hatchlings caught", 12500],
	["awakenings", "Awakenings", 18750],
	["travels", "Cities travelled", 12500],
	["spins", "Temple spins", 2500],
	["saves", "Kickback saves", 2500],
]
const MAX_BONUS_MULTIPLIER := 5

const STARTING_BEADS := 10
const MAX_BEADS := 99
const BONUS_LAMPS_FOR_EL_DORADO := 3

var lives : int
var score : int = 0
var multiplier := 1          # the ball upgrade's multiplier on everything scored
var bonus_multiplier := 1    # the end-of-ball bonus multiplier
var beads := STARTING_BEADS
var bonus_lamps := 0
var curse_active := false
var show_title := true  # the title menu opens on load; Play Again goes straight back in
var extra_ball_bought := false

## Game speed. Normal (0.7) slows the whole game evenly from Pokemon Pinball's own 1:1 (time
## itself, so every proportion stays the same); it's the game, and the only speed the arcade
## scores. Fast is the 1:1, for fun, unscored.
const SPEEDS := [["Normal", 0.7], ["Fast (unscored)", 1.0]]
const SCORED_SPEED := 0
const SETTINGS_PATH := "user://settings.cfg"
var speed_index := 0
## The view: phone (the whole tall table, as made for a phone held upright) or desktop (a
## squarer, zoomed-in window like Pokemon Pinball Ruby & Sapphire's, scrolling after the ball)
const PHONE_CANVAS := Vector2i(720, 1280)
const DESKTOP_CANVAS := Vector2i(720, 648)  # the Game Boy Advance's 10:9, at the table's width
var desktop_view := false
var screen_band := 0.0  # screen pixels a band along the top and bottom of the screen takes (Scripts/hud.gd): the camera shows the table between them
var night := true  # night: the dusk and all its lights; day: daylight, only the torches lit (Scripts/lighting.gd)

var _ball_save_left := 0.0
var _first_ball := true
var _fresh_ball := true      # a new ball (not one a saver handed back) gets its launch saver
var _stats := {}
var _tally_pending := false

func _ready():
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		speed_index = clampi(int(config.get_value("options", "speed_mode", 0)), 0, SPEEDS.size() - 1)
		night = bool(config.get_value("options", "night", true))
	# with no choice saved, a landscape screen (a desktop's) starts in the desktop view
	desktop_view = bool(config.get_value("options", "desktop_view", _landscape_screen())) if config.has_section("options") \
		else _landscape_screen()
	apply_view.call_deferred()
	_apply_speed()
	lives = starting_lives
	score = 0
	_reset_stats()
	# Hook up to the global event bus
	PinballEvents.ball_drained.connect(_on_ball_drained)
	PinballEvents.add_score.connect(_on_add_score)
	PinballEvents.ball_launched.connect(_on_ball_launched)
	PinballEvents.spirit_caught.connect(_count.bind("spirits"))
	PinballEvents.hatched.connect(_count.bind("hatchlings"))
	PinballEvents.awakened.connect(_count.bind("awakenings"))
	PinballEvents.traveled.connect(_count.bind("travels"))
	PinballEvents.roulette_spun.connect(_count.bind("spins"))
	PinballEvents.kickback_saved.connect(_count.bind("saves"))

	# Tell the UI the initial lives
	PinballEvents.lives_changed.emit(lives)
	PinballEvents.set_score.emit(0) # optional, reset score at start
	PinballEvents.beads_changed.emit.call_deferred(beads)

func _physics_process(delta: float) -> void:
	if _ball_save_left > 0.0:
		_ball_save_left = maxf(_ball_save_left - delta, 0.0)
		if _ball_save_left == 0.0:
			PinballEvents.ball_saver_changed.emit(0.0)

# Everything scored is scaled by the ball upgrade, and doubled during the curse
func score_factor() -> int:
	return multiplier * (2 if curse_active else 1)

func set_multiplier(value: int) -> void:
	multiplier = value
	PinballEvents.multiplier_changed.emit(multiplier)

func add_bonus_multiplier(amount: int) -> void:
	bonus_multiplier = mini(bonus_multiplier + amount, MAX_BONUS_MULTIPLIER)
	PinballEvents.bonus_multiplier_changed.emit(bonus_multiplier)

func set_curse_active(active: bool) -> void:
	curse_active = active
	PinballEvents.curse_changed.emit(active)

## A ball saver for the next while (launches, modes, the torches and the market): a
## drain gives the ball back
func grant_ball_save(seconds: float) -> void:
	if seconds > _ball_save_left:
		_ball_save_left = seconds
		PinballEvents.ball_saver_changed.emit(seconds)

## One more ball (the market sells one)
func award_extra_ball() -> void:
	lives += 1
	PinballEvents.lives_changed.emit(lives)

func ball_save_left() -> float:
	return _ball_save_left

func add_beads(amount: int) -> void:
	beads = clampi(beads + amount, 0, MAX_BEADS)
	PinballEvents.beads_changed.emit(beads)

func spend_beads(amount: int) -> bool:
	if beads < amount:
		return false
	add_beads(-amount)
	return true

## Bonus lamps light from catches and Awakenings; three light El Dorado at the temple
func add_bonus_lamps(amount: int) -> void:
	bonus_lamps = mini(bonus_lamps + amount, BONUS_LAMPS_FOR_EL_DORADO)
	PinballEvents.bonus_lamps_changed.emit(bonus_lamps)

func clear_bonus_lamps() -> void:
	bonus_lamps = 0
	PinballEvents.bonus_lamps_changed.emit(0)

func _on_ball_launched():
	if _fresh_ball:
		_fresh_ball = false
		grant_ball_save(FIRST_BALL_SAVER if _first_ball else BALL_SAVER)
		_first_ball = false

func _count(key: String) -> void:
	_stats[key] += 1

func _reset_stats() -> void:
	for line in TALLY:
		_stats[line[0]] = 0

func _on_ball_drained():
	if _ball_save_left > 0.0:
		PinballEvents.toast.emit("Ball saved!")
		return

	_fresh_ball = true
	var lines := []
	for line in TALLY:
		if _stats[line[0]] > 0:
			lines.append([line[1], _stats[line[0]], line[2]])
	if lines.is_empty():
		_finish_ball()
		return
	# The HUD counts the bonus up with the table frozen, then calls end_tally
	_tally_pending = true
	get_tree().paused = true
	PinballEvents.bonus_tally.emit(lines, bonus_multiplier)

## The HUD has finished (or skipped) the end-of-ball count
func end_tally(total: int) -> void:
	if not _tally_pending:
		return
	_tally_pending = false
	score += total
	PinballEvents.set_score.emit(score)
	get_tree().paused = false
	_finish_ball()

func _finish_ball() -> void:
	_reset_stats()
	bonus_multiplier = 1
	PinballEvents.bonus_multiplier_changed.emit(1)
	lives -= 1
	PinballEvents.lives_changed.emit(lives)

	if lives <= 0:
		_game_over()
	elif lives == 1:
		PinballEvents.toast.emit("Last ball!")

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
	config.set_value("options", "speed_mode", speed_index)
	config.save(SETTINGS_PATH)

func _landscape_screen() -> bool:
	var screen := DisplayServer.screen_get_size()
	return screen.x > screen.y

func toggle_view() -> void:
	desktop_view = not desktop_view
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("options", "desktop_view", desktop_view)
	config.save(SETTINGS_PATH)
	apply_view()

## Sizes the game's canvas for the view (the camera zooms to suit: Scripts/camera.gd)
func apply_view() -> void:
	var window := get_tree().root
	window.content_scale_size = DESKTOP_CANVAS if desktop_view else PHONE_CANVAS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if desktop_view else Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	PinballEvents.view_changed.emit(desktop_view)
	_tell_arcade_shape()

## In the arcade the game sits in a frame the page sizes: this tells it the shape the view wants,
## so the desktop view fills the screen instead of sitting small in a frame cut for a phone
func _tell_arcade_shape() -> void:
	if not OS.has_feature("web"):
		return
	var canvas := DESKTOP_CANVAS if desktop_view else PHONE_CANVAS
	var script := "window.parent && window.parent !== window && window.parent.postMessage({ type: 'ASPECT_RATIO', ratio: %f }, '*');" % (float(canvas.x) / canvas.y)
	JavaScriptBridge.eval(script)

func toggle_night() -> void:
	night = not night
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("options", "night", night)
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
	bonus_multiplier = 1
	beads = STARTING_BEADS
	bonus_lamps = 0
	extra_ball_bought = false
	curse_active = false
	_ball_save_left = 0.0
	_first_ball = true
	_fresh_ball = true
	_tally_pending = false
	_reset_stats()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _submit_arcade_score(final_score: int) -> void:
	if not OS.has_feature("web"):
		return
	if speed_index != SCORED_SPEED:
		final_score = 0  # the game's over, but Fast doesn't go on the arcade's board

	var script := "window.parent && window.parent.postMessage({ type: 'PLAYER_DIED', score: %d }, '*');" % final_score
	JavaScriptBridge.eval(script)
