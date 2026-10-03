extends PanelContainer
class_name Billboard
## The billboard, like Pokemon Pinball's: a framed picture that fades in under the
## score for the big moments (a new city, a relic, a ball upgrade, El Dorado opening)
## and spins like its slot machine for the temple's roulette, then fades away so it
## doesn't cover the table. Pictures come from tools/make_billboard_art.py.

const SHEET := preload("res://Sprites/billboard.png")
const PICTURE := Vector2(64, 40)
const SCALE := 3.0  # table-art pixels to screen pixels; small enough not to hide much of the table

# Frames of Sprites/billboard.png
const CITY := 0            # four cities, in journey order
const EL_DORADO := 4
const PRIZE := 5           # offering, treasure, kickback, spirit, travel
const PRIZES := ["points_small", "points_big", "kickback", "spirit", "travel"]
const RELIC := 10          # four relics, in journey order
const BALL := 14           # four ball upgrades
const SPIRIT := 18         # sixteen spirits, in SpiritCodex.SPECIES order
const DIVINE := 34         # the same sixteen, awakened

const SHOW_SECONDS := 2.6
const FADE_SECONDS := 0.25

var _picture: TextureRect
var _caption: Label
var _atlas: AtlasTexture
var _tween: Tween
var _hide_at := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", TempleTheme.pill_box(2.0))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_atlas = AtlasTexture.new()
	_atlas.atlas = SHEET
	_picture = TextureRect.new()
	_picture.texture = _atlas
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.custom_minimum_size = PICTURE * SCALE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_picture)
	_caption = Label.new()
	_caption.theme_type_variation = "HintLabel"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", TempleTheme.snap(26))
	box.add_child(_caption)
	modulate.a = 0.0
	visible = false
	PinballEvents.billboard.connect(show_picture)
	# (the roulette spins on the floor under Tlaloc instead: Scripts/floor_roulette.gd)

## Shows one picture with a caption for a couple of seconds
func show_picture(index: int, caption: String) -> void:
	_set_frame(index)
	_caption.text = caption
	_fade_in()
	_hide_at = _now() + SHOW_SECONDS

func _process(_delta: float) -> void:
	if visible and _now() >= _hide_at:
		_fade_out()

func _set_frame(index: int) -> void:
	_atlas.region = Rect2(Vector2(index * PICTURE.x, 0), PICTURE)

func _fade_in() -> void:
	if _tween:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)

func _fade_out() -> void:
	_hide_at = INF
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(hide)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
