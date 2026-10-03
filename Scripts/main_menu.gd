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
	"Launch: tap Launch (or Space). Bump the table with Shift / Up, or swipe.",
	"Shoot up the lane under the right rail to light its three spirit lamps and call a spirit. Hit the warriors to break its glyphs, then hit it 3 times to catch it.",
	"When Tlaloc's curse breaks, a heart rises in his mouth: hit it 3 times to offer it and stop the rain.",
	"Left rail lights Awaken arrows: with 3, the crystal skull opens its jaws; feed it to awaken a spirit.",
	"Hit the idol's spinning tower 3 times (top left) to sink it into its pit, then hit the golden idol to claim it.",
	"Roll over the stone buttons between the torches to light them; light all six for a ball saver.",
	"Hit the golden button on the left inlane wall to wake the jaguars in the walls.",
	"While they're out, fill both jaguars' pips to Travel: a ramp picks the way, then shoot Tlaloc's mouth to go.",
	"The bottom lanes light the roulette: shoot Tlaloc's mouth to spin it for prizes.",
	"Catches light bonus lamps; 3 lamps (or all four relics) open El Dorado in Tlaloc's mouth.",
	"The blue flippers' lane pays jade beads and charges the frog kickback. Spend beads at the crystal skull.",
	"Hit Tlaloc's face to stir him. Wake him and the storm brings a second ball.",
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
	dim.color = Color(0.05, 0.02, 0.12, 0.94)  # the HUD mustn't show through behind the title
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
	var title := _label("Tlaloc's Curse", "TitleLabel", 80)
	title.custom_minimum_size.x = 640  # wider than the buttons, so it breaks between the words
	column.add_child(title)
	column.add_child(_label("The journey to El Dorado", "HintLabel", 34))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", TempleTheme.pill_box(2.0))
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
	var speed := _button("Speed: " + GameManager.speed_name(), func(): pass)
	speed.pressed.connect(func():
		GameManager.cycle_speed()
		speed.text = "Speed: " + GameManager.speed_name())
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
		var text := _label(line, "HintLabel", 26)
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
	label.add_theme_font_size_override("font_size", TempleTheme.snap(size))
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
