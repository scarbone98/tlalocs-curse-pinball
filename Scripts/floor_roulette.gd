extends Node2D
## The roulette, set into the floor just under Tlaloc's chin: when his mouth spins it
## (Scripts/temple_hole.gd) the prize pictures (Sprites/billboard.png, at the table's own
## pixel size) flick past, slowing, and come to rest on the prize, then it fades back into
## the floor.

const SHEET := preload("res://Sprites/billboard.png")
const AT := Vector2(339, 962)  # under the face, between the slingshots
const SHOW_SECONDS := 2.2
const FADE_SECONDS := 0.25
const SPIN_START_FPS := 18.0

var features: Node2D  # TableFeatures

var _reel: Sprite2D
var _tween: Tween
var _spin_left := 0.0
var _spin_total := 0.0
var _spin_result := 0
var _spin_caption := ""
var _spin_step := 0.0
var _spin_index := 0
var _hide_left := 0.0

func _ready() -> void:
	_reel = Sprite2D.new()
	_reel.texture = SHEET
	_reel.hframes = SHEET.get_width() / int(Billboard.PICTURE.x)
	_reel.scale = features.MAP_SCALE
	_reel.position = AT
	_reel.modulate.a = 0.0
	_reel.visible = false
	features.add_child(_reel)
	PinballEvents.billboard_spin.connect(spin)

## Spins through the prizes, slowing down, and lands on `result`
func spin(result: int, seconds: float, caption: String) -> void:
	_spin_left = seconds
	_spin_total = seconds
	_spin_result = result
	_spin_caption = caption
	_spin_step = 0.0
	_hide_left = 0.0
	_fade(1.0)

func _process(delta: float) -> void:
	if _spin_left > 0.0:
		_spin_left -= delta
		# fast at first, then slower, like a slot machine coming to rest
		var fps := SPIN_START_FPS * maxf(_spin_left / _spin_total, 0.15)
		_spin_step += delta * fps
		if _spin_step >= 1.0:
			_spin_step = 0.0
			_spin_index = (_spin_index + 1) % Billboard.PRIZES.size()
			_reel.frame = Billboard.PRIZE + _spin_index
		if _spin_left <= 0.0:
			_reel.frame = _spin_result
			PinballEvents.toast.emit(_spin_caption)
			_hide_left = SHOW_SECONDS
	elif _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			_fade(0.0)

func _fade(to: float) -> void:
	if _tween:
		_tween.kill()
	_reel.visible = true
	_tween = create_tween()
	_tween.tween_property(_reel, "modulate:a", to, FADE_SECONDS)
	if to == 0.0:
		_tween.tween_callback(_reel.hide)
