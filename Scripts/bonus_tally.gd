extends Control
class_name BonusTally
## The end-of-ball bonus, like Pokemon Pinball Ruby & Sapphire's: when a ball drains
## with nothing to save it, a stone tablet counts up what was done this ball (spirits,
## hatchlings, Awakenings, cities, temple spins, kickback saves), then multiplies it by
## the bonus multiplier. A flipper, launch or tap skips straight to the total.

const LINE_SECONDS := 0.45
const HOLD_SECONDS := 1.4

var _panel: PanelContainer
var _rows: VBoxContainer
var _total_label: Label
var _lines: Array = []
var _multiplier := 1
var _total := 0
var _step := 0
var _shown := 0
var _clock := 0.0
var _counting := false
var _done_at := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	box.add_child(_label("Bonus", "TitleLabel", 56))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	box.add_child(_rows)
	_total_label = _label("", "ScoreLabel", 40)
	box.add_child(_total_label)
	visible = false
	PinballEvents.bonus_tally.connect(_start)

func _label(text: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", TempleTheme.snap(font_size))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _start(lines: Array, multiplier: int) -> void:
	_lines = lines
	_multiplier = multiplier
	_total = 0
	for line in lines:
		_total += line[1] * line[2]
	_total *= multiplier
	for child in _rows.get_children():
		child.queue_free()
	_step = 0
	_shown = 0
	_clock = 0.0
	_done_at = -1.0
	_counting = true
	_total_label.text = "0"
	visible = true

func _process(delta: float) -> void:
	if not _counting:
		return
	_clock += delta
	if _done_at < 0.0:
		if _clock >= LINE_SECONDS:
			_clock = 0.0
			_add_next_line()
	elif _clock >= _done_at:
		_finish()

func _add_next_line() -> void:
	if _step < _lines.size():
		var line: Array = _lines[_step]
		_rows.add_child(_label("%s  %d x %s" % [line[0], line[1], Hud.grouped(line[2])], "HintLabel", 30))
		_shown += line[1] * line[2]
		_total_label.text = Hud.grouped(_shown)
		AudioSfx.play("spinner", 0.0, Vector2.ONE * (1.0 + 0.08 * _step))
	elif _step == _lines.size():
		_rows.add_child(_label("Bonus multiplier  x%d" % _multiplier, "HintLabel", 30))
		_total_label.text = Hud.grouped(_total)
		AudioSfx.play("upgrade")
		_done_at = HOLD_SECONDS
		_clock = 0.0
	_step += 1

func _skip() -> void:
	while _done_at < 0.0:
		_add_next_line()
	_clock = _done_at  # finish on the next frame

func _finish() -> void:
	_counting = false
	visible = false
	GameManager.end_tally(_total)

func _unhandled_input(event: InputEvent) -> void:
	if not _counting:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or event.is_action_pressed("left_flipper") or event.is_action_pressed("right_flipper") \
		or event.is_action_pressed("ui_accept")
	if pressed:
		get_viewport().set_input_as_handled()
		_skip()
