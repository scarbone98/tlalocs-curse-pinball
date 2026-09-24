extends Control
class_name MainMenu
## The title menu, over the table dimmed under Tlaloc's rain: his mask and the title,
## a billboard frame cycling through the journey's cities, and Play, the Spirit Codex
## and How to Play. The same menu opens as the pause menu during a game (Resume and
## Restart instead of Play), so the table itself stays clear of buttons.

signal play_pressed

const MASK := preload("res://Sprites/table/tlaloc_mask.png")
const BILLBOARD := preload("res://Sprites/billboard.png")
const RAINDROP := preload("res://Sprites/table/raindrop.png")
const MASK_SIZE := Vector2(35, 17)
const PICTURE := Vector2(64, 40)
const SCENES := [0, 1, 2, 3, 4]  # the four cities, then El Dorado (Scripts/billboard.gd)
const SCENE_SECONDS := 3.0
const HOW_TO_PLAY := [
	"Flippers: tap the left or right side of the screen, or Left / Right.",
	"Launch: hold Launch (or Space) and let go in the gold for a skill shot.",
	"Travel the four cities. Each has a feat; do it to win that city's gold relic.",
	"Ramps, the Chac Mool and the temple call up spirits. Hit one 3 times to catch it for your Codex.",
	"Hit Tlaloc's face to stir him. Wake him and the storm brings a second ball.",
	"All four relics open El Dorado: shoot the temple and strike the Gilded King.",
	"The spinner charges the frog kickback. Flip to move it to the outlane in danger.",
]

var _paused_game := false  # opened as the pause menu rather than the title
var _mask_atlas: AtlasTexture
var _picture_atlas: AtlasTexture
var _clock := 0.0
var _scene_index := 0
var _buttons: VBoxContainer
var _how_to: PanelContainer
var _codex: CodexScreen

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("touch_block")
	visible = false

## Shows the menu: the title before a game, or the pause menu during one
func open(as_pause: bool, codex: CodexScreen) -> void:
	_paused_game = as_pause
	_codex = codex
	get_tree().paused = true
	for child in get_children():
		child.queue_free()
	_build()
	visible = true

func close() -> void:
	visible = false
	get_tree().paused = false

# Escape resumes from the pause menu (or closes How to Play)
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel") or _codex.visible:
		return
	get_viewport().set_input_as_handled()
	if _how_to.visible:
		_how_to.visible = false
		_buttons.get_child(0).grab_focus()
	elif _paused_game:
		close()

func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	# Tlaloc's eyes smoulder, and the frame moves on through the journey
	_mask_atlas.region = Rect2(Vector2(1 if int(_clock * 2.0) % 2 == 0 else 3, 0) * MASK_SIZE, MASK_SIZE)
	var index := int(_clock / SCENE_SECONDS) % SCENES.size()
	if index != _scene_index:
		_scene_index = index
		_picture_atlas.region = Rect2(Vector2(SCENES[index] * PICTURE.x, 0), PICTURE)

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.12, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	add_child(_rain())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	_mask_atlas = AtlasTexture.new()
	_mask_atlas.atlas = MASK
	_mask_atlas.region = Rect2(Vector2(MASK_SIZE.x, 0), MASK_SIZE)
	column.add_child(_pixel_picture(_mask_atlas, MASK_SIZE * 8.0))
	column.add_child(_label("Tlaloc's Curse", "TitleLabel", 104))
	column.add_child(_label("The journey to El Dorado", "HintLabel", 34))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ScareathonTheme.pill_box(2.0))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picture_atlas = AtlasTexture.new()
	_picture_atlas.atlas = BILLBOARD
	_picture_atlas.region = Rect2(Vector2.ZERO, PICTURE)
	frame.add_child(_pixel_picture(_picture_atlas, PICTURE * 5.0))
	column.add_child(frame)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_buttons)
	var first := _button("Resume" if _paused_game else "Play", func():
		close()
		play_pressed.emit())
	_button("Spirit Codex  %d/%d" % [SpiritCodex.count(), SpiritCodex.SPECIES.size()], func():
		_codex.open())
	_button("How to Play", _show_how_to)
	if _paused_game:
		_button("Restart", func():
			get_tree().paused = false
			GameManager.restart())
	first.grab_focus()

	var best := HighScore.load_best()
	if best > 0:
		column.add_child(_label("Best  %d" % best, "ScoreLabel", 44))

	_how_to = PanelContainer.new()
	_how_to.visible = false
	var how_box := VBoxContainer.new()
	how_box.add_theme_constant_override("separation", 14)
	_how_to.add_child(how_box)
	how_box.add_child(_label("How to Play", "TitleLabel", 72))
	for line in HOW_TO_PLAY:
		var text := _label(line, "HintLabel", 30)
		text.custom_minimum_size = Vector2(560, 0)
		how_box.add_child(text)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func():
		_how_to.visible = false
		_buttons.get_child(0).grab_focus())
	how_box.add_child(back)
	var how_center := CenterContainer.new()
	how_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	how_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	how_center.add_child(_how_to)
	add_child(how_center)

func _show_how_to() -> void:
	_how_to.visible = true
	_how_to.get_child(0).get_child(-1).grab_focus()

func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(420, 0)
	button.pressed.connect(on_press)
	_buttons.add_child(button)
	return button

func _pixel_picture(texture: Texture2D, size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = size
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _label(text: String, variation: StringName, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

# Tlaloc's rain falling across the menu, the same drops as the curse storm
func _rain() -> CPUParticles2D:
	var rain := CPUParticles2D.new()
	rain.texture = RAINDROP
	rain.amount = 120
	rain.lifetime = 1.4
	rain.position = Vector2(360, -30)
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(420, 10)
	rain.direction = Vector2(-0.18, 1)
	rain.spread = 2.0
	rain.initial_velocity_min = 900.0
	rain.initial_velocity_max = 1200.0
	rain.gravity = Vector2.ZERO
	rain.scale_amount_min = 2.6
	rain.scale_amount_max = 3.4
	rain.modulate = Color(1, 1, 1, 0.55)
	return rain
