extends Node2D
## The roulette, set into the floor just under Tlaloc's chin: a stone frame with two carved
## stone doors (tools/make_table.py). When his mouth spins the roulette (Scripts/temple_hole.gd),
## or a journey sets off for a new city (Scripts/journey.gd), the pictures flick past,
## slowing, until they come to rest on the result. In between it stands open on the city
## the journey's at; its doors only slide shut for a moment to change what's behind them.

signal landed  # a spin's come to rest on its result

const PICTURES := preload("res://Sprites/table/roulette_pictures.png")  # the four cities, then the five prizes
const BORDER := preload("res://Sprites/table/roulette_border.png")
const DOORS := preload("res://Sprites/table/roulette_doors.png")
const PICTURE := Vector2(48, 30)
const CITY_FRAMES := 0   # four of them
const PRIZE_FRAMES := 4  # five of them, in Billboard.PRIZES order
const AT := Vector2(339, 958)  # under the face, between the slingshots
const SHOW_SECONDS := 2.2
const DOOR_SECONDS := 0.3
const SPIN_START_FPS := 18.0

var features: Node2D  # TableFeatures

var _reel: Sprite2D
var _doors: Array[Sprite2D] = []
var _open := 0.0  # 0 shut, 1 slid all the way apart
var _door_tween: Tween
var _first := 0
var _count := 1
var _spin_left := 0.0
var _spin_total := 0.0
var _spin_result := 0
var _spin_caption := ""
var _spin_step := 0.0
var _spin_index := 0
var _hide_left := 0.0
var _starting := false  # the doors changing over to the reel before a spin

func _ready() -> void:
	features.roulette = self
	_reel = _piece(PICTURES)
	_reel.hframes = PICTURES.get_width() / int(PICTURE.x)
	for side in 2:
		var door := _piece(DOORS)
		door.region_enabled = true
		_doors.append(door)
	_piece(BORDER)
	_render_doors()
	_open_on_city.call_deferred()
	PinballEvents.billboard_spin.connect(func(result: int, seconds: float, caption: String):
		spin(PRIZE_FRAMES, Billboard.PRIZES.size(), PRIZE_FRAMES + result - Billboard.PRIZE, seconds, caption))

func _piece(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = features.MAP_SCALE
	sprite.position = AT
	features.add_child(sprite)
	return sprite

# The city the journey's at: what it shows between spins
func _rest_frame() -> int:
	return CITY_FRAMES + (features.journey.city if features.journey else 0)

func _open_on_city() -> void:
	_reel.frame = _rest_frame()
	_slide(1.0)

## True from a spin starting until a moment after it lands (the temple holds the ball till then)
func busy() -> bool:
	return _starting or _spin_left > 0.0 or _hide_left > SHOW_SECONDS - 0.6

# Shows another picture: the doors shut, it changes behind them, they open again
func _change_to(frame: int, then: Callable = Callable()) -> void:
	if _open > 0.0 and _reel.frame == frame:
		_slide(1.0, then)
		return
	_slide(0.0, func():
		_reel.frame = frame
		_slide(1.0, then))

## Spins through `count` pictures from `first`, slowing down, to land on `result`
func spin(first: int, count: int, result: int, seconds: float, caption: String) -> void:
	_first = first
	_count = count
	_spin_result = result
	_spin_caption = caption
	_spin_left = 0.0
	_hide_left = 0.0
	_starting = true
	_change_to(first, func():
		_starting = false
		_spin_left = seconds
		_spin_total = seconds
		_spin_step = 0.0)

## Shows one city, no spin (the journey's first city, say)
func show_city(city: int, caption: String) -> void:
	_spin_left = 0.0
	PinballEvents.toast.emit(caption)
	_change_to(CITY_FRAMES + city)

## A journey setting off: the cities spin and stop on where it's going
func spin_to_city(city: int, caption: String) -> void:
	spin(CITY_FRAMES, 4, CITY_FRAMES + city, 1.6, caption)

func _process(delta: float) -> void:
	if _spin_left > 0.0:
		_spin_left -= delta
		# fast at first, then slower, like a slot machine coming to rest
		var fps := SPIN_START_FPS * maxf(_spin_left / _spin_total, 0.15)
		_spin_step += delta * fps
		if _spin_step >= 1.0:
			_spin_step = 0.0
			_spin_index = (_spin_index + 1) % _count
			_reel.frame = _first + _spin_index
		if _spin_left <= 0.0:
			_reel.frame = _spin_result
			PinballEvents.toast.emit(_spin_caption)
			_hide_left = SHOW_SECONDS
			landed.emit()
	elif _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			_change_to(_rest_frame())  # back to the city it's at (if it isn't showing it already)

func _slide(to: float, then: Callable = Callable()) -> void:
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween()
	_door_tween.tween_method(func(v: float):
		_open = v
		_render_doors(), _open, to, maxf(DOOR_SECONDS * absf(to - _open), 0.01))
	if then.is_valid():
		_door_tween.tween_callback(then)

# Each door slides out sideways into the frame: what's left of it shows at its outer edge
func _render_doors() -> void:
	var half := PICTURE.x / 2.0
	var shown := roundf(half * (1.0 - _open))
	for side in 2:
		var door := _doors[side]
		door.visible = shown > 0.0
		if side == 0:  # the left door: its inner part, pressed against the left side
			door.region_rect = Rect2(half - shown, 0, shown, PICTURE.y)
			door.position = AT + Vector2(-half + shown / 2.0, 0) * features.MAP_SCALE
		else:
			door.region_rect = Rect2(half, 0, shown, PICTURE.y)
			door.position = AT + Vector2(half - shown / 2.0, 0) * features.MAP_SCALE
