extends Node2D
## The travel totem, on the wall to the left of the left jaguar, like the Gulpin piling up
## on Pokemon Pinball Ruby's field: each hit on a jaguar that's out (Scripts/journey.gd)
## drops a carved stone head (Sprites/table/totem_heads.png, tools/make_table.py) onto the
## stack, bouncing as it lands and jolting the one below. Three heads and the road's open.
## Once the trip's over, the trap door it stands on opens and the stack sinks down through
## it out of sight, the way a jaguar slides back into its slot; then it shuts again.

const HEADS := preload("res://Sprites/table/totem_heads.png")
const DOOR := preload("res://Sprites/table/totem_door.png")  # tools/make_table.py: shut, open
const HEAD_SIZE := Vector2i(26, 22)  # one head's frame, in art pixels (its ears, beak or wings and all)
const FULL := 3
const DOOR_ART := Vector2(18, 297)   # the trap door's middle, in table-art pixels: the totem's foot
const STEP_ART := 12.0               # each head sits this much higher than the one below
const DROP := 260.0                  # scene units above its place a head drops from
const DROP_SECONDS := 0.45
const SINK_ART_PER_SECOND := 90.0

var features: Node2D  # TableFeatures

var _heads: Array[Sprite2D] = []
var _clock := 0.0
var lit := false  # the road's open: the stack glows
var _door: Sprite2D
var _sinking: Array[Sprite2D] = []  # heads going down through the open door

func _ready() -> void:
	_door = Sprite2D.new()
	_door.texture = DOOR
	_door.hframes = 2
	_door.scale = features.MAP_SCALE
	_door.position = DOOR_ART * features.MAP_SCALE
	_door.z_index = 1  # under the heads standing on it
	_door.z_as_relative = false
	features.add_child(_door)

func count() -> int:
	return _heads.size()

func full() -> bool:
	return _heads.size() >= FULL

# Where head i's top left corner sits, stacked on the door (its bottom edge's middle on the
# door's middle)
func _place(i: int) -> Vector2:
	var art := DOOR_ART - Vector2(HEAD_SIZE.x * 0.5, HEAD_SIZE.y - 1 + STEP_ART * i)
	return art * features.MAP_SCALE

# Shows only what's above the door's middle: what's gone down through it is out of sight
func _crop(head: Sprite2D) -> void:
	var floor_y: float = DOOR_ART.y * features.MAP_SCALE.y
	var shown := clampf((floor_y - head.position.y) / features.MAP_SCALE.y, 0.0, HEAD_SIZE.y)
	head.region_rect = Rect2(head.get_meta("frame", 0) * HEAD_SIZE.x, 0, HEAD_SIZE.x, floori(shown))
	head.visible = shown >= 1.0

## One more head drops onto the stack
func add_head() -> void:
	if full():
		return
	var i := _heads.size()
	var head := Sprite2D.new()
	head.texture = HEADS
	head.centered = false
	head.region_enabled = true
	head.set_meta("frame", i)
	head.region_rect = Rect2(i * HEAD_SIZE.x, 0, HEAD_SIZE.x, HEAD_SIZE.y)
	head.scale = features.MAP_SCALE
	head.z_index = 2
	head.z_as_relative = false
	var to := _place(i)
	head.position = to - Vector2(0, DROP)
	features.add_child(head)
	_heads.append(head)
	var fall := create_tween()
	fall.tween_property(head, "position", to, DROP_SECONDS).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(DROP_SECONDS * 0.36, false).timeout.connect(func():
		AudioSfx.play("tiki", 0.0, Vector2.ONE * (0.8 + 0.12 * i))
		PinballEvents.effect.emit("dust", to + Vector2(HEAD_SIZE.x * 0.5, HEAD_SIZE.y) * features.MAP_SCALE)
		PinballEvents.rumble.emit(2.0)
		if i > 0 and i - 1 < _heads.size():
			_jolt(_heads[i - 1]))

# The head below takes the weight of one landing on it: a quick dip of an art pixel
func _jolt(head: Sprite2D) -> void:
	var at := head.position
	var dip := create_tween()
	dip.tween_property(head, "position", at + Vector2(0, features.MAP_SCALE.y), 0.05)
	dip.tween_property(head, "position", at, 0.08)

## The trip's over: the trap door opens and the whole stack sinks down through it, out of
## sight; then it shuts, ready for the next
func crumble() -> void:
	lit = false
	if _heads.is_empty():
		return
	_sinking.append_array(_heads)
	_heads.clear()
	_door.frame = 1
	AudioSfx.play("tiki", 0.0, Vector2.ONE * 0.55)
	PinballEvents.effect.emit("dust", _door.position)

func _process(delta: float) -> void:
	_clock += delta
	for head in _sinking.duplicate():
		head.position.y += SINK_ART_PER_SECOND * features.MAP_SCALE.y * delta
		_crop(head)
		if not head.visible:
			_sinking.erase(head)
			head.queue_free()
			if _sinking.is_empty():
				_door.frame = 0  # the last one's gone: it shuts
				AudioSfx.play("tiki", 0.0, Vector2.ONE * 0.7)
	# while the road's open the heads glow, one after another up the stack
	for i in _heads.size():
		var glow := 0.0
		if lit:
			glow = 0.5 + 0.5 * sin(_clock * 6.0 - i * 1.2)
		_heads[i].modulate = Color.WHITE.lerp(Color(1.5, 1.35, 0.9), glow * 0.6)
