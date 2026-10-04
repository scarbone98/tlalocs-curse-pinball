extends Control
class_name Hud

# The table viewport is 720 wide, twice the 360 the shared theme was tuned for.
const UI_SCALE := 2.0
const DESKTOP_SCALE := 0.62  # the HUD in the desktop view, which is barely half a phone's height
# The score and balls pills, sized to leave the pause button room between them. A long
# score shrinks toward SCORE_FONT_MIN rather than growing past SCORE_ROOM.
# Everything sits in a compact column at the top left, over the stone face's corner, so
# the golden temple (top right) stays in view
const TOP_FONT := 12
const HUD_LEFT := 8.0
const BAR_LEFT := 46.0   # the score and balls start right of the pause button
const SCORE_ROOM := 140.0  # widest the score pill grows before its font shrinks
const SCORE_FONT_MIN := 11
# Launch power that drops the ball into a top lane (see ball.gd); marked on the meter
const SKILL_SHOT_POWER := Vector2(0.815, 0.85)  # (measured: launches here drop into a top lane)
const MIN_LAUNCH_POWER := 0.5
const METER_LAMPS := 20

@onready var score_label: Label       = $HBoxContainer/ScoreLabel
@onready var lives_label: Label       = $HBoxContainer/LivesLabel

var _tween: Tween
var _toast_label: Label
var _lamps: Array = []  # the power meter's lamps: [its TextureRect, where along it, in the sweet spot]
var _launch_box: VBoxContainer
var _power_meter: Control
var _menu: MainMenu
var _objective_label: Label
var _billboard: Billboard
var _codex: CodexScreen
var _pause: Button
var _status_label: Label   # the ball saver's countdown while one runs, under the objective
var _shown_score := 0      # the score rolls up toward the real one rather than jumping
var _saver_left := 0.0

## The score counts up, like Pokemon Pinball Ruby & Sapphire's, quickly enough that a
## big award still lands within a second or so
const SCORE_ROLL_PER_SECOND := 1.2e6
const SCORE_ROLL_MIN_SECONDS := 0.6

func _ready() -> void:
	theme = TempleTheme.build(UI_SCALE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_top_bar()
	_build_toast()
	_build_launch_button()
	_build_objective()
	_build_billboard()
	_build_status()
	_build_menu()
	add_child(ModeBanner.new())
	add_child(BonusTally.new())
	move_child(_menu, -1)  # the pause menu goes over everything

	# Connect to global events
	PinballEvents.set_score.connect(_on_set_score)
	PinballEvents.lives_changed.connect(_on_lives_changed)
	PinballEvents.toast.connect(_on_toast)
	PinballEvents.launch_available.connect(_on_launch_available)
	PinballEvents.launch_power_changed.connect(_on_launch_power_changed)
	PinballEvents.game_over.connect(_on_game_over)
	PinballEvents.objective_changed.connect(_on_objective_changed)
	PinballEvents.ball_saver_changed.connect(_on_saver_changed)
	resized.connect(_fit_score)
	# the desktop view's window is much shorter than a phone's: the HUD's drawn smaller there
	PinballEvents.view_changed.connect(_fit_view)
	get_viewport().size_changed.connect(func(): _fit_view(GameManager.desktop_view))
	_fit_view.call_deferred(GameManager.desktop_view)

	_render_score()
	_render_lives()

# Phone view: the HUD fills the screen at its own size. Desktop view: it's drawn at
# DESKTOP_SCALE over an area that much bigger, so everything keeps its place, just smaller
func _fit_view(desktop: bool) -> void:
	if desktop:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		scale = Vector2.ONE * DESKTOP_SCALE
		size = get_viewport_rect().size / DESKTOP_SCALE
	else:
		scale = Vector2.ONE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _style_top_bar() -> void:
	var bar: HBoxContainer = $HBoxContainer
	bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	bar.offset_left = BAR_LEFT * UI_SCALE
	bar.offset_top = 8 * UI_SCALE
	bar.offset_right = bar.offset_left
	bar.offset_bottom = bar.offset_top
	bar.grow_horizontal = Control.GROW_DIRECTION_END
	bar.add_theme_constant_override("separation", int(4 * UI_SCALE))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [score_label, lives_label]:
		label.label_settings = null
		label.theme_type_variation = "ScoreLabel"
		label.add_theme_font_size_override("font_size", TempleTheme.snap(int(TOP_FONT * UI_SCALE)))
		label.add_theme_stylebox_override("normal", TempleTheme.pill_box(UI_SCALE))
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.theme_type_variation = "TitleLabel"
	_toast_label.add_theme_font_size_override("font_size", TempleTheme.snap(int(12 * UI_SCALE)))  # only the big moments get one
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long ones wrap, not run off
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.custom_minimum_size.x = 300 * UI_SCALE
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_stylebox_override("normal", TempleTheme.pill_box(UI_SCALE))  # on a slab, readable over the table
	add_child(_toast_label)

func _build_launch_button() -> void:
	# Meter sits above the button; both hide once the ball is in play
	_launch_box = VBoxContainer.new()
	_launch_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_launch_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_launch_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Sit just left of the plunger lane so the waiting ball stays visible
	_launch_box.offset_right = -48 * UI_SCALE
	_launch_box.offset_bottom = -28 * UI_SCALE
	_launch_box.add_theme_constant_override("separation", int(6 * UI_SCALE))
	_launch_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_box.visible = false
	add_child(_launch_box)

	_power_meter = _build_power_meter()
	_launch_box.add_child(_power_meter)

# The plunger's pull, as a row of little pixel lamps in a stone frame: they light one after
# another, ember red, as it's drawn back; the ones in the sweet spot (a launch that drops
# straight into a top lane) sit in gold-rimmed sockets and burn gold
func _build_power_meter() -> Control:
	var meter := PanelContainer.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.modulate.a = 0.0
	meter.add_theme_stylebox_override("panel", TempleTheme.panel_box(UI_SCALE))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", TempleTheme.FRAME_SCALE)  # one pixel between
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_child(row)
	_lamps.clear()
	for i in METER_LAMPS:
		var at := float(i + 0.5) / METER_LAMPS
		# its stretch of the pull overlaps the sweet spot
		var sweet := _meter_to_power(float(i + 1) / METER_LAMPS) >= SKILL_SHOT_POWER.x 			and _meter_to_power(float(i) / METER_LAMPS) <= SKILL_SHOT_POWER.y
		var lamp := TextureRect.new()
		lamp.texture = _lamp_art(sweet, LAMP_OFF)
		lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		lamp.stretch_mode = TextureRect.STRETCH_SCALE
		lamp.custom_minimum_size = Vector2(LAMP_ART) * TempleTheme.FRAME_SCALE
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lamp)
		_lamps.append([lamp, at, sweet])
	return meter

const LAMP_ART := Vector2i(4, 6)  # each lamp, in pixels (drawn 3x, like the frames)
enum { LAMP_OFF, LAMP_EMBER, LAMP_GOLD }
var _lamp_textures := {}

# A lamp in its socket, pixel by pixel: a rim (gold in the sweet spot) with clipped corners,
# a glint top left, its glass shaded darker bottom right
func _lamp_art(sweet: bool, state: int) -> Texture2D:
	var key := Vector2i(int(sweet), state)
	if _lamp_textures.has(key):
		return _lamp_textures[key]
	var glint: Color
	var glass: Color
	var shade: Color
	match state:
		LAMP_EMBER:
			glint = Color("#ffb060")
			glass = TempleTheme.TERRACOTTA
			shade = Color("#802814")
		LAMP_GOLD:
			glint = Color("#fff6b8")
			glass = TempleTheme.GOLD
			shade = TempleTheme.GOLD_DARK
		_:
			glint = TempleTheme.STONE
			glass = TempleTheme.STONE_DARK
			shade = TempleTheme.INK
	var rim := TempleTheme.GOLD_DARK if sweet else TempleTheme.INK
	var image := Image.create(LAMP_ART.x, LAMP_ART.y, false, Image.FORMAT_RGBA8)
	var w := LAMP_ART.x
	var h := LAMP_ART.y
	for y in h:
		for x in w:
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			var corner := (x == 0 or x == w - 1) and (y == 0 or y == h - 1)
			var col := Color(0, 0, 0, 0)
			if corner:
				pass
			elif edge:
				col = rim
			elif x == 1 and y == 1:
				col = glint
			elif x == w - 2 and y >= h - 3:
				col = shade
			else:
				col = glass
			image.set_pixel(x, y, col)
	var texture := ImageTexture.create_from_image(image)
	_lamp_textures[key] = texture
	return texture

func _meter_to_power(at: float) -> float:
	return lerpf(MIN_LAUNCH_POWER, 1.0, at)

func _in_sweet_spot(power: float) -> bool:
	return power >= SKILL_SHOT_POWER.x and power <= SKILL_SHOT_POWER.y

func _power_to_meter(power: float) -> float:
	return clampf((power - MIN_LAUNCH_POWER) / (1.0 - MIN_LAUNCH_POWER), 0.0, 1.0)

func _on_launch_power_changed(power: float, charging: bool) -> void:
	_power_meter.modulate.a = 1.0 if charging else 0.0
	var reached := _power_to_meter(power)
	for lamp: Array in _lamps:
		var lit: bool = lamp[1] <= reached
		var state := LAMP_OFF if not lit else (LAMP_GOLD if lamp[2] else LAMP_EMBER)
		(lamp[0] as TextureRect).texture = _lamp_art(lamp[2], state)

# The journey's current goal, in the hint's spot once the controls hint has gone
func _build_objective() -> void:
	_objective_label = Label.new()
	_objective_label.theme_type_variation = "HintLabel"
	_objective_label.add_theme_font_size_override("font_size", TempleTheme.snap(int(8 * UI_SCALE)))
	_objective_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_objective_label.offset_left = HUD_LEFT * UI_SCALE
	_objective_label.offset_top = 34 * UI_SCALE  # under the score
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_label.add_theme_stylebox_override("normal", TempleTheme.pill_box(UI_SCALE))
	_objective_label.visible = false
	add_child(_objective_label)

# While one runs, the ball saver's countdown, under the objective
func _build_status() -> void:
	_status_label = Label.new()
	_status_label.theme_type_variation = "HintLabel"
	_status_label.add_theme_font_size_override("font_size", TempleTheme.snap(int(8 * UI_SCALE)))
	_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_label.offset_left = HUD_LEFT * UI_SCALE
	_status_label.offset_top = 58 * UI_SCALE
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.add_theme_stylebox_override("normal", TempleTheme.pill_box(UI_SCALE))
	add_child(_status_label)
	_render_status()

func _on_saver_changed(seconds: float) -> void:
	_saver_left = seconds
	_render_status()

func _render_status() -> void:
	_status_label.visible = _saver_left > 0.0
	_status_label.text = "Saver %d" % ceili(_saver_left)

func _process(delta: float) -> void:
	if _saver_left > 0.0 and not get_tree().paused:
		var before := ceili(_saver_left)
		_saver_left = GameManager.ball_save_left()
		if ceili(_saver_left) != before:
			_render_status()
	if _shown_score != GameManager.score:
		var gap := GameManager.score - _shown_score
		var step := maxf(SCORE_ROLL_PER_SECOND * delta, absf(gap) * delta / SCORE_ROLL_MIN_SECONDS)
		_shown_score = GameManager.score if absf(gap) <= step else _shown_score + int(signf(gap) * step)
		score_label.text = grouped(_shown_score)
		_fit_score()

# Pops up under the objective line for the big moments (see Scripts/billboard.gd)
func _build_billboard() -> void:
	_billboard = Billboard.new()
	_billboard.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_billboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_billboard.offset_top = 74 * UI_SCALE
	add_child(_billboard)

# The pause button between the score and balls opens the menu (Resume, the Spirit Codex,
# How to Play, Restart). The same menu is the title screen when the game loads.
func _build_menu() -> void:
	var pause := Button.new()
	_pause = pause
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.add_to_group("touch_block")
	pause.add_theme_font_size_override("font_size", TempleTheme.snap(int(10 * UI_SCALE)))
	pause.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause.offset_left = HUD_LEFT * UI_SCALE
	pause.offset_top = 8 * UI_SCALE
	pause.custom_minimum_size = Vector2(34, 0) * UI_SCALE
	pause.pressed.connect(func(): _menu.open(true, _codex))
	add_child(pause)
	_menu = MainMenu.new()
	_menu.play_pressed.connect(func(): GameManager.show_title = false)
	add_child(_menu)
	_codex = CodexScreen.new()
	add_child(_codex)  # over the menu, which opens it
	if GameManager.show_title:
		_menu.open.call_deferred(false, _codex)

# Escape pauses, like the pause button
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_menu.open(true, _codex)

func _on_objective_changed(text: String) -> void:
	_objective_label.text = text
	_objective_label.visible = text != ""

func _on_set_score(_value: int) -> void:
	_render_score()

func _on_lives_changed(_lives: int) -> void:
	_render_lives()

func _on_launch_available(available: bool) -> void:
	_launch_box.visible = available
	_power_meter.modulate.a = 0.0

func _on_toast(message: String) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_toast_label.text = message
	_toast_label.pivot_offset = _toast_label.size / 2
	_toast_label.modulate.a = 1.0
	_toast_label.scale = Vector2(0.7, 0.7)
	_tween = create_tween()
	_tween.tween_property(_toast_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(1.0)         # hold visible for a second
	_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)

func _on_game_over(final_score: int, is_new_best: bool) -> void:
	_launch_box.visible = false
	_toast_label.modulate.a = 0.0

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.06, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.65, 0.3)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(14 * UI_SCALE))
	panel.add_child(box)

	box.add_child(_centered_label("Game Over", "TitleLabel"))
	box.add_child(_centered_label("Score  %d" % final_score, "ScoreLabel"))
	box.add_child(_centered_label("New best!" if is_new_best else "Best  %d" % HighScore.load_best(), "HintLabel"))

	box.add_child(_centered_label("Spirit Codex  %d/%d" % [SpiritCodex.count(), SpiritCodex.SPECIES.size()], "HintLabel"))
	var again := Button.new()
	again.text = "Play Again"
	again.pressed.connect(GameManager.restart)
	box.add_child(again)
	var codex := Button.new()
	codex.text = "Spirit Codex"
	codex.pressed.connect(func(): _codex.open())
	box.add_child(codex)
	var menu := Button.new()
	menu.text = "Menu"
	menu.pressed.connect(GameManager.to_title)
	box.add_child(menu)
	again.grab_focus()
	move_child(_codex, -1)  # the Codex opens over the game over panel

func _centered_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _render_score() -> void:
	if GameManager.score < _shown_score:
		_shown_score = GameManager.score  # a fresh game starts back at zero at once
	score_label.text = grouped(_shown_score)
	_fit_score()

# Shrinks the score's font until it fits left of the pause button
func _fit_score() -> void:
	if _pause == null:
		return
	var room: float = SCORE_ROOM * UI_SCALE - score_label.get_theme_stylebox("normal").get_minimum_size().x
	var font := score_label.get_theme_font("font")
	var font_size := int(TOP_FONT * UI_SCALE)
	while font_size > SCORE_FONT_MIN * UI_SCALE and font.get_string_size(score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	score_label.add_theme_font_size_override("font_size", TempleTheme.snap(font_size))

# 1234567 -> "1,234,567", the way pinball scores are shown
static func grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(-3)
	return ("-" if value < 0 else "") + digits + out

func _render_lives() -> void:
	lives_label.text = "Balls  %d" % max(GameManager.lives, 0)
