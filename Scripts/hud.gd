extends Control

# The table viewport is 720 wide, twice the 360 the shared theme was tuned for.
const UI_SCALE := 2.0

@onready var score_label: Label       = $HBoxContainer/ScoreLabel
@onready var lives_label: Label       = $HBoxContainer/LivesLabel

var _tween: Tween
var _toast_label: Label
var _launch_button: Button
var _hint_label: Label

func _ready() -> void:
	theme = ScareathonTheme.build(UI_SCALE)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_top_bar()
	_build_toast()
	_build_launch_button()
	_build_hint()

	# Connect to global events
	PinballEvents.set_score.connect(_on_set_score)
	PinballEvents.lives_changed.connect(_on_lives_changed)
	PinballEvents.toast.connect(_on_toast)
	PinballEvents.launch_available.connect(_on_launch_available)
	PinballEvents.game_over.connect(_on_game_over)

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
	_launch_button = Button.new()
	_launch_button.text = "Launch"
	_launch_button.add_to_group("touch_block")
	_launch_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_launch_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_launch_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Sit just left of the plunger lane so the waiting ball stays visible
	_launch_button.offset_right = -48 * UI_SCALE
	_launch_button.offset_bottom = -28 * UI_SCALE
	_launch_button.focus_mode = Control.FOCUS_NONE
	_launch_button.visible = false
	_launch_button.pressed.connect(func(): PinballEvents.launch_requested.emit())
	add_child(_launch_button)

func _build_hint() -> void:
	_hint_label = Label.new()
	_hint_label.theme_type_variation = "HintLabel"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", int(15 * UI_SCALE))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_label.offset_top = 62 * UI_SCALE
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_stylebox_override("normal", ScareathonTheme.pill_box(UI_SCALE))
	# Touch laptops report a touchscreen too, so show both control schemes
	_hint_label.text = "Flippers: tap sides or Left / Right\nLaunch: button or Space"
	add_child(_hint_label)

func _on_set_score(_value: int) -> void:
	_render_score()

func _on_lives_changed(_lives: int) -> void:
	_render_lives()

func _on_launch_available(available: bool) -> void:
	_launch_button.visible = available
	# The controls hint only matters until the first ball is in play
	if not available and _hint_label.visible:
		create_tween().tween_property(_hint_label, "modulate:a", 0.0, 0.4).finished.connect(_hint_label.hide)

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
	_launch_button.visible = false
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

	var again := Button.new()
	again.text = "Play Again"
	again.pressed.connect(GameManager.restart)
	box.add_child(again)
	again.grab_focus()

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
