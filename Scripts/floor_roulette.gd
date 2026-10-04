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
const SPIN_LAPS_PER_SECOND := 1.6  # times round the reel for each second it spins
const SETTLE := 0.9  # how far past the result it runs before settling back (an ease-out-back)
const SINK := 1.0  # art pixels the tablet sinks under a ball

var features: Node2D  # TableFeatures

var _reel: Sprite2D       # the picture in the window...
var _reel_next: Sprite2D  # ...and, as it spins, the next one rolling down into it from above
var _frame := 0           # the picture showing, at rest
var _spin_steps := 0      # pictures it rolls through, start to stop
var _doors: Array[Sprite2D] = []
var _open := 0.0  # 0 shut, 1 slid all the way apart
var _door_tween: Tween
var _first := 0
var _count := 1
var _spin_left := 0.0
var _spin_total := 0.0
var _spin_result := 0
var _spin_caption := ""
var _hide_left := 0.0
var _starting := false  # the doors changing over to the reel before a spin
var _pieces: Array[Sprite2D] = []  # the reel and the doors: the surface that sinks (the frame round it doesn't)
var _gap: Sprite2D  # the shadow along the top of the window as the surface sinks
var _on_it := 0  # balls rolling over it
var _sunk := false

func _ready() -> void:
	features.roulette = self
	_reel = _piece(PICTURES)
	_reel.region_enabled = true
	_reel_next = _piece(PICTURES)
	_reel_next.region_enabled = true
	_show_reel(0, 0, 0.0)
	for side in 2:
		var door := _piece(DOORS)
		door.region_enabled = true
		_doors.append(door)
	var shade := Image.create(int(PICTURE.x), int(SINK), false, Image.FORMAT_RGBA8)
	shade.fill(Color(0.08, 0.06, 0.1, 0.85))
	_gap = Sprite2D.new()
	_gap.texture = ImageTexture.create_from_image(shade)
	_gap.scale = features.MAP_SCALE
	_gap.position = AT + Vector2(0, -PICTURE.y / 2.0 + SINK / 2.0) * features.MAP_SCALE
	_gap.hide()
	features.add_child(_gap)
	_piece(BORDER)  # over the surface's edges, staying put as it sinks
	_render_doors()
	_open_on_city.call_deferred()
	# it gives a little under a ball rolling over it, like a button (and does nothing)
	var tread := Area2D.new()
	tread.position = AT
	tread.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = PICTURE * features.MAP_SCALE
	shape.shape = rect
	tread.add_child(shape)
	tread.body_entered.connect(func(body: Node):
		if body.is_in_group("ball"):
			_on_it += 1)
	tread.body_exited.connect(func(body: Node):
		if body.is_in_group("ball"):
			_on_it = maxi(_on_it - 1, 0))
	add_child(tread)
	PinballEvents.billboard_spin.connect(func(result: int, seconds: float, caption: String):
		spin(PRIZE_FRAMES, Billboard.PRIZES.size(), PRIZE_FRAMES + result - Billboard.PRIZE, seconds, caption))

func _piece(texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = features.MAP_SCALE
	sprite.position = AT
	features.add_child(sprite)
	if texture != BORDER:
		_pieces.append(sprite)
	return sprite

# The city the journey's at: what it shows between spins
func _rest_frame() -> int:
	return CITY_FRAMES + (features.journey.city if features.journey else 0)

func _open_on_city() -> void:
	_set_frame(_rest_frame())
	_slide(1.0)

## True from a spin starting until a moment after it lands (the temple holds the ball till then)
func busy() -> bool:
	return _starting or _spin_left > 0.0 or _hide_left > SHOW_SECONDS - 0.6

# Shows another picture: the doors shut, it changes behind them, they open again
func _change_to(frame: int, then: Callable = Callable()) -> void:
	if _open > 0.0 and _frame == frame:
		_slide(1.0, then)
		return
	_slide(0.0, func():
		_set_frame(frame)
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
		# round the reel a few times, coming to rest on the result
		_spin_steps = count * maxi(2, int(seconds * SPIN_LAPS_PER_SECOND)) + posmod(result - first, count))

## Shows one city, no spin (the journey's first city, say)
func show_city(city: int, caption: String) -> void:
	_spin_left = 0.0
	PinballEvents.toast.emit(caption)
	_change_to(CITY_FRAMES + city)

## A journey setting off: the cities spin and stop on where it's going
func spin_to_city(city: int, caption: String) -> void:
	spin(CITY_FRAMES, 4, CITY_FRAMES + city, 1.6, caption)

func _process(delta: float) -> void:
	var sunk := _on_it > 0
	if sunk != _sunk:
		_sunk = sunk
		for piece in _pieces:
			piece.offset.y = SINK if sunk else 0.0  # the surface a pixel down in its frame, a touch darker
			piece.self_modulate = Color(0.88, 0.88, 0.88) if sunk else Color.WHITE
		_gap.visible = sunk
	if _spin_left > 0.0:
		_spin_left -= delta
		# the reel rolls down through the window like a slot machine's: fast at first, slowing,
		# running a touch past the result and settling back onto it
		var t := clampf(1.0 - _spin_left / _spin_total, 0.0, 1.0)
		var eased := 1.0 + (SETTLE + 1.0) * pow(t - 1.0, 3.0) + SETTLE * pow(t - 1.0, 2.0)
		var at := eased * _spin_steps
		var step := floori(at)
		_show_reel(_first + posmod(step, _count), _first + posmod(step + 1, _count), at - step)
		if _spin_left <= 0.0:
			_set_frame(_spin_result)
			PinballEvents.toast.emit(_spin_caption)
			_hide_left = SHOW_SECONDS
			landed.emit()
	elif _hide_left > 0.0:
		_hide_left -= delta
		if _hide_left <= 0.0:
			_change_to(_rest_frame())  # back to the city it's at (if it isn't showing it already)

func _set_frame(frame: int) -> void:
	_frame = frame
	_show_reel(frame, frame, 0.0)

# The window shows `shown`, slid `rolled` (0..1) of the way down out of it, and `next`
# coming down into the top of it: whole art pixels, each cut to the window
func _show_reel(shown: int, next: int, rolled: float) -> void:
	var h := PICTURE.y
	var down := roundf(clampf(rolled, 0.0, 1.0) * h)
	var top: float = AT.y / features.MAP_SCALE.y - h / 2.0  # the window's top, in art pixels
	_reel.visible = down < h
	_reel.region_rect = Rect2(shown * PICTURE.x, 0, PICTURE.x, h - down)
	_reel.position = Vector2(AT.x, (top + down + (h - down) / 2.0) * features.MAP_SCALE.y)
	_reel_next.visible = down > 0.0
	_reel_next.region_rect = Rect2(next * PICTURE.x, h - down, PICTURE.x, down)
	_reel_next.position = Vector2(AT.x, (top + down / 2.0) * features.MAP_SCALE.y)

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
