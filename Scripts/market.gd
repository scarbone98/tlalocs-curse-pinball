extends Control
class_name Market
## The market in the jaguar's den, like the Mart in Pokemon Pinball Ruby & Sapphire: the
## table waits while you spend jade beads on ball savers, a ball upgrade, frogs on both
## outlanes, more time in El Dorado or (once a game) an extra ball. Flippers move between
## the wares, Launch buys, and Leave (or Escape) goes back to the game.

signal closed

const WARES := [
	["saver_30", "Ball saver 30s", 10],
	["saver_60", "Ball saver 60s", 20],
	["saver_90", "Ball saver 90s", 30],
	["upgrade", "Ball upgrade", 40],
	["el_dorado_time", "More El Dorado time", 40],
	["kickback", "Frogs on both outlanes", 50],
	["extra_ball", "Extra ball", 99],
]

var features: Node2D  # TableFeatures, which the wares act on

var _buttons: Array[Button] = []
var _beads_label: Label
var _leave: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.05, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Jaguar Market"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", TempleTheme.snap(52))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_beads_label = Label.new()
	_beads_label.theme_type_variation = "HintLabel"
	_beads_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_beads_label)
	for ware in WARES:
		var button := Button.new()
		button.add_to_group("touch_block")
		button.pressed.connect(_buy.bind(ware[0], ware[2]))
		box.add_child(button)
		_buttons.append(button)
	_leave = Button.new()
	_leave.text = "Leave"
	_leave.add_to_group("touch_block")
	_leave.pressed.connect(close)
	box.add_child(_leave)
	visible = false

func open() -> void:
	get_tree().paused = true
	visible = true
	_render()
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return
	_leave.grab_focus()

func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()

func _render() -> void:
	_beads_label.text = "Jade beads: %d" % GameManager.beads
	for i in WARES.size():
		var ware: Array = WARES[i]
		var sold_out: bool = ware[0] == "extra_ball" and GameManager.extra_ball_bought
		_buttons[i].text = "%s  -  %s" % [ware[1], "sold out" if sold_out else "%d jade" % ware[2]]
		_buttons[i].disabled = sold_out or GameManager.beads < ware[2]

func _buy(ware: String, price: int) -> void:
	if not GameManager.spend_beads(price):
		return
	match ware:
		"saver_30":
			GameManager.grant_ball_save(GameManager.ball_save_left() + 30.0)
		"saver_60":
			GameManager.grant_ball_save(GameManager.ball_save_left() + 60.0)
		"saver_90":
			GameManager.grant_ball_save(GameManager.ball_save_left() + 90.0)
		"upgrade":
			features.upgrade_ball()
		"el_dorado_time":
			features.el_dorado.extra_seconds += 30.0
		"kickback":
			features.kickback.charge()
		"extra_ball":
			GameManager.extra_ball_bought = true
			GameManager.award_extra_ball()
	AudioSfx.play("catch")
	_render()
	if get_viewport().gui_get_focus_owner() == null or (get_viewport().gui_get_focus_owner() as Button).disabled:
		_leave.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("left_flipper") or event.is_action_pressed("right_flipper"):
		get_viewport().set_input_as_handled()
		var focus := get_viewport().gui_get_focus_owner()
		if focus:
			var next := focus.find_prev_valid_focus() if event.is_action_pressed("left_flipper") else focus.find_next_valid_focus()
			if next:
				next.grab_focus()
