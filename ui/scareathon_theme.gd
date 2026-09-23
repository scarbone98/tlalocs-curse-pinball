class_name ScareathonTheme
extends RefCounted

# Palette mirrors the Scareathon site (Tailwind red/purple/amber/orange scales).
const BLOOD := Color("#ef4444")
const BLOOD_DEEP := Color("#7f1d1d")
const BLOOD_DARK := Color("#450a0a")
const PURPLE := Color("#c084fc")
const PURPLE_DARK := Color("#3b0764")
const AMBER := Color("#fcd34d")
const BONE := Color("#ffedd5")
const SHADOW := Color(0, 0, 0, 0.85)

const HEADING_FONT := preload("res://assets/fonts/zombie.ttf")
const BODY_FONT := preload("res://assets/fonts/scoobydoo.ttf")

# ui_scale lets games with larger viewports (e.g. 720 wide) reuse the same look.
static func build(ui_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = ui_scale
	theme.default_font = BODY_FONT
	theme.default_font_size = int(26 * ui_scale)

	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_outline_color", "Label", SHADOW)
	theme.set_constant("outline_size", "Label", int(6 * ui_scale))

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", HEADING_FONT)
	theme.set_font_size("font_size", "TitleLabel", int(64 * ui_scale))
	theme.set_color("font_color", "TitleLabel", BLOOD)
	theme.set_constant("outline_size", "TitleLabel", int(10 * ui_scale))

	theme.set_type_variation("ScoreLabel", "Label")
	theme.set_font_size("font_size", "ScoreLabel", int(34 * ui_scale))
	theme.set_color("font_color", "ScoreLabel", AMBER)

	theme.set_type_variation("HintLabel", "Label")
	theme.set_font_size("font_size", "HintLabel", int(18 * ui_scale))
	theme.set_color("font_color", "HintLabel", Color(BONE, 0.75))

	theme.set_stylebox("normal", "Button", _box(BLOOD_DARK, BLOOD, BLOOD, 3, ui_scale))
	theme.set_stylebox("hover", "Button", _box(BLOOD_DEEP, AMBER, AMBER, 3, ui_scale))
	theme.set_stylebox("pressed", "Button", _box(BLOOD_DEEP, AMBER, AMBER, 1, ui_scale))
	theme.set_stylebox("focus", "Button", _focus_box(ui_scale))
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", AMBER)
	theme.set_color("font_pressed_color", "Button", AMBER)
	theme.set_color("font_focus_color", "Button", BONE)
	theme.set_color("font_outline_color", "Button", SHADOW)
	theme.set_constant("outline_size", "Button", int(4 * ui_scale))
	theme.set_font_size("font_size", "Button", int(30 * ui_scale))

	for state in ["normal", "hover", "pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "CheckButton", BONE)
	theme.set_color("font_hover_color", "CheckButton", AMBER)
	theme.set_color("font_pressed_color", "CheckButton", BONE)

	theme.set_stylebox("panel", "PanelContainer", _panel_box(ui_scale))
	return theme

static func _box(fill: Color, border: Color, glow: Color, glow_size: int, ui_scale: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(int(3 * ui_scale))
	box.set_corner_radius_all(int(14 * ui_scale))
	box.shadow_color = Color(glow, 0.45)
	box.shadow_size = int(glow_size * 3 * ui_scale)
	box.content_margin_left = int(28 * ui_scale)
	box.content_margin_right = int(28 * ui_scale)
	box.content_margin_top = int(12 * ui_scale)
	box.content_margin_bottom = int(12 * ui_scale)
	return box

static func _focus_box(ui_scale: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = AMBER
	box.set_border_width_all(int(2 * ui_scale))
	box.set_corner_radius_all(int(16 * ui_scale))
	box.set_expand_margin_all(int(4 * ui_scale))
	return box

static func _panel_box(ui_scale: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(PURPLE_DARK, 0.92)
	box.border_color = PURPLE
	box.set_border_width_all(int(2 * ui_scale))
	box.set_corner_radius_all(int(18 * ui_scale))
	box.shadow_color = Color(PURPLE, 0.35)
	box.shadow_size = int(14 * ui_scale)
	box.content_margin_left = int(28 * ui_scale)
	box.content_margin_right = int(28 * ui_scale)
	box.content_margin_top = int(24 * ui_scale)
	box.content_margin_bottom = int(24 * ui_scale)
	return box

static func pill_box(ui_scale: float = 1.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(BLOOD_DARK, 0.8)
	box.border_color = BLOOD
	box.set_border_width_all(int(2 * ui_scale))
	box.set_corner_radius_all(int(20 * ui_scale))
	box.content_margin_left = int(16 * ui_scale)
	box.content_margin_right = int(16 * ui_scale)
	box.content_margin_top = int(4 * ui_scale)
	box.content_margin_bottom = int(4 * ui_scale)
	return box
