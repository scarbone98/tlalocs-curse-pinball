extends Control
class_name CodexScreen
## The Spirit Codex screen, like Pokemon Pinball's Pokedex: every spirit by city, the
## caught ones in colour with their names and the rest as dark silhouettes. Opening it
## pauses the game; closing it picks up where it left off.

const SPIRITS := preload("res://Sprites/table/spirits.png")
const SPIRIT_SIZE := Vector2(18, 14)
const ICON_SCALE := 4.0
const CITIES := ["Tenochtitlan", "Teotihuacan", "Chichen Itza", "Palenque"]

var _was_paused := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("touch_block")  # taps here aren't flipper presses
	visible = false

func open() -> void:
	for child in get_children():
		child.queue_free()
	_was_paused = get_tree().paused
	get_tree().paused = true
	visible = true

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	box.add_child(_label("Spirit Codex  %d/%d" % [SpiritCodex.count(), SpiritCodex.SPECIES.size()], "TitleLabel", 44))
	for city in CITIES.size():
		box.add_child(_label(CITIES[city] + ("  - complete!" if SpiritCodex.city_complete(city) else ""), "HintLabel", 30))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		for i in SpiritCodex.SPECIES.size():
			if SpiritCodex.SPECIES[i].city == city:
				row.add_child(_cell(i))

	var close := Button.new()
	close.text = "Back"
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(close_screen)
	box.add_child(close)
	close.grab_focus()

func close_screen() -> void:
	visible = false
	get_tree().paused = _was_paused

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_screen()
		get_viewport().set_input_as_handled()

func _cell(index: int) -> Control:
	var spirit: Dictionary = SpiritCodex.SPECIES[index]
	var found := SpiritCodex.has_caught(index)
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(150, 0)
	var atlas := AtlasTexture.new()
	atlas.atlas = SPIRITS
	atlas.region = Rect2(Vector2(0, index) * SPIRIT_SIZE, SPIRIT_SIZE)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = SPIRIT_SIZE * ICON_SCALE
	if not found:
		icon.modulate = Color(0, 0, 0, 0.85)  # a silhouette until it's caught
	cell.add_child(icon)
	var name: String = spirit.name if found else "???"
	if spirit.rare and found:
		name += " *"
	cell.add_child(_label(name, "HintLabel", 24))
	return cell

func _label(text: String, variation: StringName, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
