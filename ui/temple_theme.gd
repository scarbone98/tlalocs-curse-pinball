class_name TempleTheme
extends RefCounted
## The game's UI look: the temple's stone and gold, in a pixel font. Panels and buttons
## are pixel-art frames (tools/make_ui.py, drawn at the table art's pixel size and scaled
## up 3x like the table), and text is Silkscreen (assets/fonts, SIL Open Font License),
## an 8-pixel font kept crisp by using only sizes that are multiples of 8, with
## antialiasing off and a one-pixel drop shadow instead of a soft outline.

const INK := Color("#141824")
const STONE_DARK := Color("#232b3a")
const STONE := Color("#566d77")
const STONE_LIGHT := Color("#a4bac3")
const BONE := Color("#f4ecd8")
const GOLD := Color("#f8d000")
const GOLD_DARK := Color("#c88a10")
const JADE := Color("#20d8a0")
const TERRACOTTA := Color("#d0502a")
const SHADOW := Color("#141824")

const FRAME_SCALE := 3  # ui/frames are drawn 3x, like the table
const PANEL := preload("res://ui/frames/panel.png")
const BUTTON := preload("res://ui/frames/button.png")
const PILL := preload("res://ui/frames/pill.png")

static var BODY_FONT: FontFile = _crisp(preload("res://assets/fonts/Silkscreen-Regular.ttf"))
static var HEADING_FONT: FontFile = _crisp(preload("res://assets/fonts/Silkscreen-Bold.ttf"))

# A pixel font drawn without smoothing, so its pixels stay square
static func _crisp(font: FontFile) -> FontFile:
	var crisp := font.duplicate() as FontFile
	crisp.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	crisp.hinting = TextServer.HINTING_NONE
	crisp.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	crisp.generate_mipmaps = false
	return crisp

## A font size the pixel font draws crisply at: the nearest multiple of 8
static func snap(size: float) -> int:
	return maxi(8, int(roundf(size / 8.0)) * 8)

# ui_scale lets games with larger viewports (e.g. 720 wide) reuse the same look.
static func build(ui_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	theme.default_base_scale = ui_scale
	theme.default_font = BODY_FONT
	theme.default_font_size = snap(12 * ui_scale)

	for type in ["Label", "Button"]:
		theme.set_color("font_shadow_color", type, SHADOW)
		theme.set_constant("shadow_offset_x", type, FRAME_SCALE)
		theme.set_constant("shadow_offset_y", type, FRAME_SCALE)
		theme.set_constant("outline_size", type, 0)
	theme.set_color("font_color", "Label", BONE)

	theme.set_type_variation("TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", HEADING_FONT)
	theme.set_font_size("font_size", "TitleLabel", snap(28 * ui_scale))
	theme.set_color("font_color", "TitleLabel", GOLD)

	theme.set_type_variation("ScoreLabel", "Label")
	theme.set_font("font", "ScoreLabel", HEADING_FONT)
	theme.set_font_size("font_size", "ScoreLabel", snap(16 * ui_scale))
	theme.set_color("font_color", "ScoreLabel", GOLD)

	theme.set_type_variation("HintLabel", "Label")
	theme.set_font_size("font_size", "HintLabel", snap(12 * ui_scale))
	theme.set_color("font_color", "HintLabel", BONE)

	theme.set_stylebox("normal", "Button", _button(0))
	theme.set_stylebox("hover", "Button", _button(1))
	theme.set_stylebox("focus", "Button", _button(1))
	theme.set_stylebox("pressed", "Button", _button(2))
	theme.set_stylebox("disabled", "Button", _button(2))
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", GOLD_DARK)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color(BONE, 0.4))
	theme.set_font_size("font_size", "Button", snap(12 * ui_scale))

	for state in ["normal", "hover", "pressed", "focus"]:
		theme.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "CheckButton", BONE)
	theme.set_color("font_hover_color", "CheckButton", GOLD)
	theme.set_color("font_pressed_color", "CheckButton", BONE)

	theme.set_stylebox("panel", "PanelContainer", panel_box())
	return theme

static func _frame(texture: Texture2D, region: Rect2, margin: float, content: Vector2) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	if region.size != Vector2.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		box.texture = atlas
	else:
		box.texture = texture
	box.set_texture_margin_all(margin)
	box.content_margin_left = content.x
	box.content_margin_right = content.x
	box.content_margin_top = content.y
	box.content_margin_bottom = content.y
	return box

static func _button(state: int) -> StyleBoxTexture:
	var size := 12 * FRAME_SCALE
	var box := _frame(BUTTON, Rect2(state * size, 0, size, size), 3 * FRAME_SCALE, Vector2(30, 15))
	if state == 2:
		box.content_margin_top += FRAME_SCALE  # the label sinks a pixel as it's pressed
		box.content_margin_bottom -= FRAME_SCALE
	return box

## The stone slab behind menus, the market, the end-of-ball bonus and banners
static func panel_box(_ui_scale: float = 1.0) -> StyleBoxTexture:
	return _frame(PANEL, Rect2(), 6 * FRAME_SCALE, Vector2(36, 30))

## The small slab behind the score, the balls and the jade count
static func pill_box(_ui_scale: float = 1.0) -> StyleBoxTexture:
	return _frame(PILL, Rect2(), 3 * FRAME_SCALE, Vector2(18, 9))
