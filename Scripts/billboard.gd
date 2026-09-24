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

const SHOW_SECONDS := 2.6
const FADE_SECONDS := 0.25
const SPIN_START_FPS := 18.0

var _picture: TextureRect
var _caption: Label
var _atlas: AtlasTexture
var _tween: Tween
var _spin_left := 0.0
var _spin_total := 0.0
var _spin_result := 0
var _spin_caption := ""
var _spin_step := 0.0
var _spin_index := 0
var _hide_at := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ScareathonTheme.pill_box(2.0))
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
	_caption.add_theme_font_size_override("font_size", 26)
	box.add_child(_caption)
	modulate.a = 0.0
	visible = false
	PinballEvents.billboard.connect(show_picture)
	PinballEvents.billboard_spin.connect(spin)

## Shows one picture with a caption for a couple of seconds
func show_picture(index: int, caption: String) -> void:
	_spin_left = 0.0
	_set_frame(index)
	_caption.text = caption
	_fade_in()
	_hide_at = _now() + SHOW_SECONDS

## Spins through the roulette's prizes, slowing down, and lands on `result`
func spin(result: int, seconds: float, caption: String) -> void:
	_spin_left = seconds
	_spin_total = seconds
	_spin_result = result
	_spin_caption = caption
	_spin_step = 0.0
	_caption.text = "..."
	_fade_in()
	_hide_at = INF

func _process(delta: float) -> void:
	if _spin_left > 0.0:
		_spin_left -= delta
		# the reel starts fast and slows, like a slot machine coming to rest
		var fps := SPIN_START_FPS * maxf(_spin_left / _spin_total, 0.15)
		_spin_step += delta * fps
		if _spin_step >= 1.0:
			_spin_step = 0.0
			_spin_index = (_spin_index + 1) % PRIZES.size()
			_set_frame(PRIZE + _spin_index)
		if _spin_left <= 0.0:
			_set_frame(_spin_result)
			_caption.text = _spin_caption
			_hide_at = _now() + SHOW_SECONDS
	elif visible and _now() >= _hide_at:
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
