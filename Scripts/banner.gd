extends Control
class_name ModeBanner
## Mode-start banners, like Pokemon Pinball Ruby & Sapphire's: when a mode starts the
## whole table freezes (ball, flippers and timers), dims, and a banner sweeps across with
## the mode's picture and name. Then it sweeps away and play picks up where it stopped.
## Banners that arrive while one is showing wait their turn.

const SHEET := preload("res://Sprites/billboard.png")
const PICTURE := Vector2(64, 40)
const PICTURE_SCALE := 4.0
const HOLD_SECONDS := 1.6
const SWEEP_SECONDS := 0.25
const DIM := 0.45

var _dim: ColorRect
var _band: PanelContainer
var _picture: TextureRect
var _atlas: AtlasTexture
var _title: Label
var _queue: Array = []
var _showing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.0, 0.05, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	_band = PanelContainer.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_theme_stylebox_override("panel", TempleTheme.pill_box(2.0))
	add_child(_band)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(box)
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_picture = TextureRect.new()
	_picture.texture = _atlas
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.custom_minimum_size = PICTURE * PICTURE_SCALE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_picture)
	_title = Label.new()
	_title.theme_type_variation = "TitleLabel"
	_title.add_theme_font_size_override("font_size", TempleTheme.snap(56))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 600
	box.add_child(_title)
	_band.visible = false
	PinballEvents.banner.connect(_on_banner)

func _on_banner(title: String, picture: int) -> void:
	_queue.append([title, picture])
	if not _showing:
		_next()

func _next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	# Wait out the menu, the end-of-ball count or the game over screen
	if get_tree().paused and not _showing:
		get_tree().create_timer(0.3, true).timeout.connect(_next)
		return
	_showing = true
	var entry: Array = _queue.pop_front()
	_title.text = entry[0]
	_picture.visible = entry[1] >= 0
	if entry[1] >= 0:
		_atlas.region = Rect2(Vector2(entry[1] * PICTURE.x, 0), PICTURE)
	get_tree().paused = true
	_band.visible = true
	_band.reset_size()
	var area := get_viewport_rect().size  # the HUD canvas, whatever this control was laid out at
	var width := area.x
	var y := (area.y - _band.size.y) * 0.42
	_band.position = Vector2(width, y)
	var centre := (width - _band.size.x) * 0.5
	var tween := create_tween()
	tween.tween_property(_dim, "color:a", DIM, SWEEP_SECONDS)
	tween.parallel().tween_property(_band, "position:x", centre, SWEEP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_band, "position:x", -_band.size.x, SWEEP_SECONDS).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_dim, "color:a", 0.0, SWEEP_SECONDS)
	tween.tween_callback(func():
		_band.visible = false
		if _queue.is_empty():
			get_tree().paused = false
			_showing = false
		else:
			_next())
