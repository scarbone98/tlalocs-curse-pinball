extends Node2D
## The golden idol at the top of the U-shaped lane, upper left, where Cyndaquil's Egg
## Stand is on Pokemon Pinball Ruby's field. The lane is a pit (Sprites/layers/basemap.png),
## and a tower of three spinning stone drums (the hand-drawn spinningtower.png) stands in
## it with the golden idol (Sprites/table/idol.png) on top. Spikes (spikes.png) guard the
## pit's mouth: a shot up the lane just bounces off them, until the ball rolls over the
## gold button beside them, which lowers them for a while. Then each shot up the lane
## strikes the tower: its top drum sinks away and the idol drops a step, rocking. With the
## drums gone the idol stands on the pit floor and the next shot claims it: points and one
## more on the bonus multiplier. Each strike throws off crystal shards. A while later the
## tower rises again with a new idol on top, and the spikes come back up (never on a ball
## still in the pit: they wait for it to roll out).

const DRUM := preload("res://Sprites/table/tower_drum.png")    # tools/make_table.py
const IDOL := preload("res://Sprites/table/idol.png")          # tools/make_tiki_idol.py
const IDOL_SPIN := preload("res://Sprites/table/idol_spin.png")  # tools/make_table.py: it turns on its tower
const SHARD := preload("res://Sprites/table/shard.png")
const IDOL_SPIN_FPS := 6.0
# Between the spikes and the tower's foot, where a ball can be when the spikes come back up
const PIT := Rect2(214, 470, 76, 98)
const SPIKES := preload("res://Sprites/table/spikes.png")

enum { GLEAM, GLINT, STRUCK, ROCK_LEFT, ROCK_RIGHT, TOPPLED }  # Sprites/table/idol.png
const IDOL_FRAMES := 6

# Placed as in the layout mock-up, in table-art pixels
const DRUM_ART := Vector2(89.5, 155)  # the bottom drum's centre; each one above sits DRUM_STEP higher
const DRUM_STEP := 10.0
const DRUM_FRAMES := 3
const SPIN_FPS := 8.0
const IDOL_ABOVE_TOP := 13.0          # from the top drum's centre up to the idol's
const IDOL_ON_FLOOR := Vector2(90, 164)
const SPIKES_ART := Vector2(91.5, 179.5)
const SPIKE_FRAMES := 3               # tall, lower, lowest; then they're gone into the floor
const DRUMS := 3
# The spikes along the pit's mouth (scene units): with them up, a shot bounces off here
const SPIKE_LINE := Rect2(224, 528, 56, 34)
# The front of the tower's bottom drum, which a shot strikes once the spikes are down
const TOWER_FRONT := Rect2(224, 478, 56, 20)
const SENSOR_DEPTH := 16.0
# The gold button beside the spikes (painted in the basemap), and how long it holds them down
const BUTTON_AT := Vector2(319, 549)
const BUTTON_RADIUS := 18.0
const SPIKES_DOWN_SECONDS := 20.0
const SPIKE_STEP_SECONDS := 0.07
const PRESSED_SECONDS := 0.35  # the gold button stays sunk this long, then glows while the spikes are down
const IDOL_RADIUS := 18.0
const HIT_COOLDOWN := 0.6
const BUTTON_POINTS := 500
const SINK_POINTS := 1500
const CLAIM_POINTS := 25000
const RESET_SECONDS := 12.0

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _drums: Array[Sprite2D] = []
var _idol: Sprite2D
var _spikes: Sprite2D
var _front: StaticBody2D
var _front_sensor: Area2D
var _idol_body: StaticBody2D
var _idol_shape: CollisionShape2D
var _idol_sensor: Area2D
var _standing := DRUMS
var _claimed := false
var _spikes_down_left := 0.0
var _spike_level := 0.0  # 0 up, SPIKE_FRAMES all the way down
var _cooldown := 0.0
var _struck_left := 0.0
var _rock_left := 0.0
var _reset_left := 0.0
var _clock := 0.0
var _turning: Sprite2D  # the idol turning, while it rides the tower
var _shards: CPUParticles2D
var _button: AnimatedSprite2D
var _pressed_left := 0.0

func _ready() -> void:
	for i in DRUMS:  # the bottom one first, so each drum above overlaps the one below
		var drum := _sheet_sprite(DRUM, DRUM_FRAMES)
		drum.position = (DRUM_ART - Vector2(0, DRUM_STEP * i)) * features.MAP_SCALE
		_drums.append(drum)
	_idol = _sheet_sprite(IDOL, IDOL_FRAMES)
	_idol.z_index = 3  # in front of the palm behind the tower (the palms are z 2)
	_idol.z_as_relative = false
	_turning = _sheet_sprite(IDOL_SPIN, 4)
	_turning.z_index = 3
	_turning.z_as_relative = false
	_shards = _shard_burst()
	_spikes = _sheet_sprite(SPIKES, SPIKE_FRAMES)
	_spikes.position = SPIKES_ART * features.MAP_SCALE

	# one wall across the lane: at the spikes while they're up, at the tower's foot once they're down
	_front = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SPIKE_LINE.size
	shape.shape = rect
	_front.add_child(shape)
	add_child(_front)
	var reach := RectangleShape2D.new()
	reach.size = Vector2(SPIKE_LINE.size.x, SENSOR_DEPTH)
	_front_sensor = _area(reach, _on_front_hit)

	_idol_body = StaticBody2D.new()
	_idol_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = IDOL_RADIUS
	_idol_shape.shape = circle
	_idol_body.add_child(_idol_shape)
	add_child(_idol_body)
	var idol_reach := CircleShape2D.new()
	idol_reach.radius = IDOL_RADIUS + 8.0
	_idol_sensor = _area(idol_reach, _on_idol_hit)

	_button = features.gold_button("spike_button")
	var button := CircleShape2D.new()
	button.radius = BUTTON_RADIUS
	_area(button, _on_button).position = BUTTON_AT
	_raise()

func _sheet_sprite(texture: Texture2D, frames: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = frames
	sprite.scale = features.MAP_SCALE
	features.add_child(sprite)
	return sprite

func _area(shape: Shape2D, on_ball: Callable) -> Area2D:
	var area := Area2D.new()
	area.monitorable = false
	var holder := CollisionShape2D.new()
	holder.shape = shape
	area.add_child(holder)
	area.body_entered.connect(on_ball)
	add_child(area)
	return area

## True once the tower has sunk and the idol waits on the pit floor
func idol_open() -> bool:
	return _standing == 0 and not _claimed

func _spikes_down() -> bool:
	return _spikes_down_left > 0.0

func _raise() -> void:
	_standing = DRUMS
	_claimed = false
	_idol.show()
	_idol.modulate = Color.WHITE
	_place()

# The idol rides on the top drum; with none left it stands on the pit floor, open to a shot
func _place() -> void:
	for i in _drums.size():
		_drums[i].visible = i < _standing
	var idol_art := IDOL_ON_FLOOR
	if _standing > 0:
		idol_art = DRUM_ART - Vector2(0, DRUM_STEP * (_standing - 1) + IDOL_ABOVE_TOP)
	_idol.position = idol_art * features.MAP_SCALE
	_idol_body.position = _idol.position
	_idol_sensor.position = _idol.position
	var open := _standing == 0
	var wall := TOWER_FRONT if _spikes_down() else SPIKE_LINE
	_front.position = wall.get_center()
	_front_sensor.position = Vector2(wall.get_center().x, wall.end.y + SENSOR_DEPTH * 0.5)
	(_front.get_child(0) as CollisionShape2D).set_deferred("disabled", open and _spikes_down())
	_front_sensor.set_deferred("monitoring", not (open and _spikes_down()))
	_idol_shape.set_deferred("disabled", not open or _claimed)
	_idol_sensor.set_deferred("monitoring", open and not _claimed)

func _physics_process(delta: float) -> void:
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_pressed_left = maxf(_pressed_left - delta, 0.0)
	features.show_gold_button(_button, _pressed_left, _spikes_down())
	_struck_left = maxf(_struck_left - delta, 0.0)
	_rock_left = maxf(_rock_left - delta, 0.0)
	for i in _drums.size():
		var turn := (int(_clock * SPIN_FPS) + i) % DRUM_FRAMES  # each turning a beat apart
		_drums[i].frame = DRUM_FRAMES - 1 - turn if i == 1 else turn  # the middle one turns the other way
	# the spikes sink into the floor (or rise back up) a frame at a time
	var was_down := _spikes_down()
	if _spikes_down_left > 0.0 and _spikes_down_left <= delta and _ball_in_pit():
		pass  # hold them down till the ball's rolled out of the pit
	else:
		_spikes_down_left = maxf(_spikes_down_left - delta, 0.0)
	if was_down and not _spikes_down():
		_place()
	_spike_level = move_toward(_spike_level, SPIKE_FRAMES if _spikes_down() else 0.0, delta / SPIKE_STEP_SECONDS)
	_spikes.visible = _spike_level < SPIKE_FRAMES
	_spikes.frame = mini(int(_spike_level), SPIKE_FRAMES - 1)
	_render_idol()
	if _reset_left > 0.0:
		_reset_left -= delta
		if _reset_left <= 0.0:
			_raise()
			PinballEvents.effect.emit("gold", _idol.position)

func _ball_in_pit() -> bool:
	for node in get_tree().get_nodes_in_group("ball"):
		if PIT.has_point((node as Node2D).global_position):
			return true
	return false

# A burst of crystal slivers off the tower as it's struck
func _shard_burst() -> CPUParticles2D:
	var burst := CPUParticles2D.new()
	burst.texture = SHARD
	burst.emitting = false
	burst.one_shot = true
	burst.local_coords = true
	burst.amount = 14
	burst.lifetime = 0.8
	burst.explosiveness = 1.0
	burst.scale = features.MAP_SCALE
	burst.direction = Vector2(0, -1)
	burst.spread = 75.0
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 70.0
	burst.gravity = Vector2(0, 120)
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	burst.color_ramp = fade
	burst.z_index = 3
	burst.z_as_relative = false
	features.add_child(burst)
	return burst

func _render_idol() -> void:
	_turning.position = _idol.position
	# turning on its tower; still once it's down on the pit floor, gleaming, waiting
	var spinning := not _claimed and _standing > 0 and _struck_left <= 0.0 and _rock_left <= 0.0
	_turning.visible = spinning and _idol.visible
	if spinning:
		_turning.frame = int(_clock * IDOL_SPIN_FPS) % 4
	if _claimed:
		return
	_idol.self_modulate.a = 0.0 if _turning.visible else 1.0
	if _struck_left > 0.0:
		_idol.frame = STRUCK
	elif _rock_left > 0.0:
		_idol.frame = ROCK_LEFT if int(_rock_left * 10.0) % 2 == 0 else ROCK_RIGHT
	elif idol_open():
		_idol.frame = GLINT if int(_clock * 4.0) % 2 == 0 else GLEAM  # it gleams, waiting
	else:
		_idol.frame = GLINT if fposmod(_clock, 2.5) < 0.2 else GLEAM

func _on_button(body: Node) -> void:
	if not features._is_ball_on_playfield(body):
		return
	var was_down := _spikes_down()
	_spikes_down_left = SPIKES_DOWN_SECONDS
	_pressed_left = PRESSED_SECONDS
	if was_down:
		return
	_place()
	features._award(BUTTON_POINTS, BUTTON_AT)
	PinballEvents.effect.emit("sparks", BUTTON_AT)
	AudioSfx.play("tiki", 0.0, Vector2.ONE * 0.8)

func _on_front_hit(body: Node) -> void:
	if _cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	if (body as RigidBody2D).linear_velocity.y > 0.0:
		return  # only a shot up the lane
	_cooldown = HIT_COOLDOWN
	if not _spikes_down():
		AudioSfx.play("bumper", 0.0, Vector2.ONE * 1.3)
		return
	if _standing == 0:
		return
	_standing -= 1
	_struck_left = 0.15
	_rock_left = 0.6
	# the wall keeps its place a moment so the striking ball bounces back down the lane
	get_tree().create_timer(0.25, false).timeout.connect(_place)
	features._award(SINK_POINTS, TOWER_FRONT.get_center())
	AudioSfx.play("tiki", 0.0, Vector2.ONE * (1.0 + 0.12 * (DRUMS - _standing)))
	PinballEvents.effect.emit("dust", TOWER_FRONT.get_center())
	_shards.position = (DRUM_ART - Vector2(0, DRUM_STEP * _standing)) * features.MAP_SCALE
	_shards.restart()
	PinballEvents.rumble.emit(3.0)

func _on_idol_hit(body: Node) -> void:
	if not idol_open() or not features._is_ball_on_playfield(body):
		return
	_claimed = true
	_idol.frame = TOPPLED
	_place.call_deferred()
	features._award(CLAIM_POINTS, _idol.position)
	GameManager.add_bonus_multiplier(1)
	PinballEvents.toast.emit("Golden idol claimed! Bonus +1")
	PinballEvents.effect.emit("gold", _idol.position)
	PinballEvents.rumble.emit(5.0)
	AudioSfx.play("upgrade")
	_shards.position = _idol.position
	_shards.restart()
	get_tree().create_timer(0.4, false).timeout.connect(_idol.hide)
	_spikes_down_left = minf(_spikes_down_left, 0.5)  # the spikes come back up behind it, once the ball has rolled out
	_reset_left = RESET_SECONDS
