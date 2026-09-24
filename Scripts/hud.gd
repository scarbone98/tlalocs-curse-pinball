extends Control

# The table viewport is 720 wide, twice the 360 the shared theme was tuned for.
const UI_SCALE := 2.0
# Launch power that drops the ball into a top lane (see ball.gd); marked on the meter
const SKILL_SHOT_POWER := Vector2(0.70, 0.78)
const MIN_LAUNCH_POWER := 0.5

@onready var score_label: Label       = $HBoxContainer/ScoreLabel
@onready var lives_label: Label       = $HBoxContainer/LivesLabel

var _tween: Tween
var _toast_label: Label
var _launch_button: Button
var _launch_box: VBoxContainer
var _power_meter: Control
var _power_fill: ColorRect
var _menu: MainMenu
var _objective_label: Label
var _billboard: Billboard
var _codex: CodexScreen

func _ready() -> void:
	theme = ScareathonTheme.build(UI_SCALE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_top_bar()
	_build_toast()
	_build_launch_button()
	_build_objective()
	_build_billboard()
	_build_menu()

	# Connect to global events
	PinballEvents.set_score.connect(_on_set_score)
	PinballEvents.lives_changed.connect(_on_lives_changed)
	PinballEvents.toast.connect(_on_toast)
	PinballEvents.launch_available.connect(_on_launch_available)
	PinballEvents.launch_power_changed.connect(_on_launch_power_changed)
	PinballEvents.game_over.connect(_on_game_over)
	PinballEvents.objective_changed.connect(_on_objective_changed)

	_render_score()
	_render_lives()

func _style_top_bar() -> void:
	var bar: HBoxContainer = $HBoxContainer
	bar.offset_left = 16 * UI_SCALE
	bar.offset_right = -16 * UI_SCALE
	bar.offset_top = 12 * UI_SCALE
	bar.offset_bottom = 60 * UI_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [score_label, lives_label]:
		label.label_settings = null
		label.theme_type_variation = "ScoreLabel"
		label.add_theme_font_size_override("font_size", int(26 * UI_SCALE))
		label.add_theme_stylebox_override("normal", ScareathonTheme.pill_box(UI_SCALE))
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lives_label.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END

func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.theme_type_variation = "TitleLabel"
	_toast_label.add_theme_font_size_override("font_size", int(44 * UI_SCALE))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_launch_button = Button.new()
	_launch_button.text = "Launch"
	_launch_button.add_to_group("touch_block")
	_launch_button.focus_mode = Control.FOCUS_NONE
	_launch_button.button_down.connect(func(): PinballEvents.launch_pressed.emit())
	_launch_button.button_up.connect(func(): PinballEvents.launch_released.emit())
	_launch_box.add_child(_launch_button)

func _build_power_meter() -> Control:
	var meter := Panel.new()
	meter.custom_minimum_size = Vector2(0, 22 * UI_SCALE)
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.modulate.a = 0.0
	meter.add_theme_stylebox_override("panel", ScareathonTheme.pill_box(UI_SCALE))

	var inset := 3 * UI_SCALE
	_power_fill = ColorRect.new()
	_power_fill.color = ScareathonTheme.BLOOD
	_power_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fill.anchor_bottom = 1.0
	_power_fill.offset_left = inset
	_power_fill.offset_top = inset
	_power_fill.offset_bottom = -inset
	meter.add_child(_power_fill)

	# Sweet-spot marker is an outline drawn over the fill so it stays visible while charging
	var band := Panel.new()
	var band_box := StyleBoxFlat.new()
	band_box.draw_center = false
	band_box.border_color = ScareathonTheme.AMBER
	band_box.set_border_width_all(int(2 * UI_SCALE))
	band_box.set_corner_radius_all(int(3 * UI_SCALE))
	band.add_theme_stylebox_override("panel", band_box)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = _power_to_meter(SKILL_SHOT_POWER.x)
	band.anchor_right = _power_to_meter(SKILL_SHOT_POWER.y)
	band.anchor_bottom = 1.0
	band.offset_top = inset * 0.5
	band.offset_bottom = -inset * 0.5
	meter.add_child(band)
	return meter

func _power_to_meter(power: float) -> float:
	return clampf((power - MIN_LAUNCH_POWER) / (1.0 - MIN_LAUNCH_POWER), 0.0, 1.0)

func _on_launch_power_changed(power: float, charging: bool) -> void:
	_power_meter.modulate.a = 1.0 if charging else 0.0
	_power_fill.anchor_right = _power_to_meter(power)
	var in_sweet_spot := power >= SKILL_SHOT_POWER.x and power <= SKILL_SHOT_POWER.y
	_power_fill.color = ScareathonTheme.AMBER if in_sweet_spot else ScareathonTheme.BLOOD

# The journey's current goal, in the hint's spot once the controls hint has gone
func _build_objective() -> void:
	_objective_label = Label.new()
	_objective_label.theme_type_variation = "HintLabel"
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", int(13 * UI_SCALE))
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_objective_label.offset_top = 62 * UI_SCALE
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_label.add_theme_stylebox_override("normal", ScareathonTheme.pill_box(UI_SCALE))
	_objective_label.visible = false
	add_child(_objective_label)

# Pops up under the objective line for the big moments (see Scripts/billboard.gd)
func _build_billboard() -> void:
	_billboard = Billboard.new()
	_billboard.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_billboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_billboard.offset_top = 88 * UI_SCALE
	add_child(_billboard)

# The pause button between the score and balls opens the menu (Resume, the Spirit Codex,
# How to Play, Restart). The same menu is the title screen when the game loads.
func _build_menu() -> void:
	var pause := Button.new()
	pause.text = "II"
	pause.focus_mode = Control.FOCUS_NONE
	pause.add_to_group("touch_block")
	pause.add_theme_font_size_override("font_size", int(16 * UI_SCALE))
	pause.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause.offset_top = 16 * UI_SCALE
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
	score_label.text = "Score  %d" % GameManager.score

func _render_lives() -> void:
	lives_label.text = "Balls  %d" % max(GameManager.lives, 0)
