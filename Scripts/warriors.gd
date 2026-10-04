extends Node2D
## The arena's three bumpers are Aztec warriors (the hand-drawn warrior.png) standing
## round the ring drawn in the dirt. Each one flashes the moment the ball touches it. Now
## and then, and whenever a ball has been rattling about the arena for a moment, they set
## off marching round the ring together, turning as they go, and keep going for ten
## seconds, so a ball can't settle into one spot between them. Which way they go round,
## clockwise or against it, is a toss-up each time; or instead they patrol, the three of
## them together, up and down the arena or from side to side, and back to their places. Every so often they're gone
## altogether: the stone tablet in the middle of the arena slides open and one by one they
## hop down into the hole beneath it, and the arena stands empty a while before they hop
## back out to their places.

const CENTRE := Vector2(412, 445)     # the ring in the dirt (Sprites/layers/basemap.png)
const RADIUS := 48.0
const MARCH_SECONDS := 10.0
const TURNS_PER_SECOND := 0.35
enum { CIRCLE, UP_DOWN, LEFT_RIGHT }  # how they march
const PATROL_RATE := 0.3  # patrols a second: a march's ten seconds is three of them, ending back home
const PATROL_REACH := {UP_DOWN: Vector2(0, 30), LEFT_RIGHT: Vector2(26, 0)}  # how far either way (scene units)
const MARCH_EVERY := Vector2(20.0, 35.0)
const LINGER_SECONDS := 0.8           # a ball this long inside the arena sets them marching
const AWAY_EVERY := Vector2(45.0, 80.0)
const AWAY_SECONDS := 15.0
const HOLE := preload("res://Sprites/table/arena_hole.png")  # tools/make_table.py: shut, open
enum { HOLE_SHUT, HOLE_OPEN }
const HOP_SECONDS := 0.45
const HOP_HEIGHT := 8.0   # art pixels up at the top of a hop
const HOP_STAGGER := 0.2
const ARENA_RADIUS := 95.0
const STEP_EVERY := 0.18
const FLASH_SECONDS := 0.12
const SHEET := preload("res://Sprites/table/warrior.png")  # tools/make_table.py
const FRAME := Vector2(17, 23)
const TURN_FRAMES := 4     # front, turning, back, turning
const TURN_FPS := 8.0
enum { STANDING = 0, GLANCING = 1, FLASHING = 4 }  # the last frame is the warrior struck
# Standing about, each one breathes (a pixel's bob) and now and then glances aside
const BREATH_SECONDS := 1.3
const GLANCE_EVERY := Vector2(3.0, 7.0)
const GLANCE_SECONDS := 0.5

var features: Node2D  # TableFeatures

var _warriors: Array[Node2D] = []
var _sprites: Array[AnimatedSprite2D] = []
var _flash_left: Array[float] = []
var _glance_wait: Array[float] = []
var _glance_left: Array[float] = []
var _angle := -PI / 2.0
var _march_left := 0.0
var _march_way := 1.0  # 1 clockwise, -1 the other way (and which way a patrol sets off)
var _pattern := CIRCLE
var _offset := Vector2.ZERO  # how far a patrol has taken them off their places
var _away_wait := 60.0
var _away_left := 0.0
var _hole: AnimatedSprite2D
var _hopping := 0  # warriors mid-hop
var _rest_left := 0.0
var _linger := 0.0
var _clock := 0.0

func _ready() -> void:
	var patch := features.get_node_or_null(^"../mushrooms")
	if patch == null:
		return
	for warrior in patch.get_children():
		_warriors.append(warrior)
		var sprite := warrior.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
		sprite.sprite_frames = _frames()
		sprite.stop()
		sprite.frame = STANDING
		_sprites.append(sprite)
		_flash_left.append(0.0)
		_glance_wait.append(randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y))
		_glance_left.append(0.0)
		(warrior as Area2D).body_entered.connect(_on_touch.bind(_sprites.size() - 1))
	_hole = features._sprite(HOLE, 2, CENTRE)  # under the warriors (they're drawn after the table's features)
	_place()
	_rest_left = randf_range(MARCH_EVERY.x, MARCH_EVERY.y)
	_away_wait = randf_range(AWAY_EVERY.x, AWAY_EVERY.y)

func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	for i in TURN_FRAMES + 1:
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		atlas.region = Rect2(Vector2(i * FRAME.x, 0), FRAME)
		frames.add_frame("default", atlas)
	return frames

func _place() -> void:
	for i in _warriors.size():
		var angle := _angle + TAU * i / _warriors.size()
		_warriors[i].global_position = CENTRE + _offset + Vector2(cos(angle), sin(angle)) * RADIUS

func _on_touch(body: Node, index: int) -> void:
	if body.is_in_group("ball"):
		_flash_left[index] = FLASH_SECONDS
		_sprites[index].frame = FLASHING

func _physics_process(delta: float) -> void:
	_clock += delta
	for i in _sprites.size():
		if _flash_left[i] > 0.0:
			_flash_left[i] -= delta
			if _flash_left[i] <= 0.0:
				_sprites[i].frame = STANDING
	if _march_left > 0.0:
		_march_left -= delta
		var turn := 0
		if _pattern == CIRCLE:
			_angle += TAU * TURNS_PER_SECOND * delta * _march_way
			turn = int(_clock * TURN_FPS) % TURN_FRAMES
		else:
			# out one way, back through their places, out the other, and home again
			var phase := (MARCH_SECONDS - _march_left) * PATROL_RATE * TAU
			_offset = PATROL_REACH[_pattern] * sin(phase) * _march_way
			var heading := cos(phase) * _march_way  # which way they're going now
			if _pattern == UP_DOWN:
				turn = 0 if heading > 0.0 else 2  # facing down the table, or turned away up it
			else:
				turn = 1 if heading > 0.0 else 3  # turned to the side they're heading
		if _march_left <= 0.0:
			_offset = Vector2.ZERO
			turn = 0
		_place()
		var up := int(_clock / STEP_EVERY) % 2 == 1 and _march_left > 0.0
		for i in _sprites.size():
			_sprites[i].offset.y = -1.0 if up else 0.0  # they bob a pixel as they march
			if _flash_left[i] <= 0.0:
				_sprites[i].frame = turn
		return
	# now and then they leave the arena empty for a while
	if _hopping > 0:
		return
	if _away_left > 0.0:
		_away_left -= delta
		if _away_left <= 0.0:
			_set_here(true)
		return
	_away_wait -= delta
	if _away_wait <= 0.0:
		_away_wait = randf_range(AWAY_EVERY.x, AWAY_EVERY.y)
		_away_left = AWAY_SECONDS
		_set_here(false)
		return
	_idle(delta)
	_rest_left -= delta
	var ball_in := false
	for node in get_tree().get_nodes_in_group("ball"):
		if (node as Node2D).global_position.distance_to(CENTRE) < ARENA_RADIUS:
			ball_in = true
	_linger = _linger + delta if ball_in else 0.0
	if _rest_left <= 0.0 or _linger >= LINGER_SECONDS:
		_march()

func _idle(delta: float) -> void:
	for i in _sprites.size():
		var phase := fposmod(_clock / BREATH_SECONDS + float(i) / _sprites.size(), 1.0)
		_sprites[i].offset.y = -1.0 if phase < 0.5 else 0.0
		_glance_wait[i] -= delta
		_glance_left[i] = maxf(_glance_left[i] - delta, 0.0)
		if _glance_wait[i] <= 0.0:
			_glance_wait[i] = randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y)
			_glance_left[i] = GLANCE_SECONDS
		if _flash_left[i] <= 0.0:
			_sprites[i].frame = GLANCING if _glance_left[i] > 0.0 else STANDING

# The tablet slides open and the warriors hop down into the hole one by one (the ball then
# passes through where they stood), or hop back out of it to their places round the ring
func _set_here(here: bool) -> void:
	_hole.frame = HOLE_OPEN
	_hopping = _warriors.size()
	for i in _warriors.size():
		var warrior := _warriors[i]
		var sprite := _sprites[i]
		var angle := _angle + TAU * i / _warriors.size()
		var spot := CENTRE + Vector2(cos(angle), sin(angle)) * RADIUS
		for shape in warrior.find_children("*", "CollisionShape2D", true, false):
			(shape as CollisionShape2D).set_deferred("disabled", true)
		var hop := create_tween()
		hop.tween_interval(HOP_STAGGER * i)
		if here:
			hop.tween_callback(func():
				warrior.global_position = CENTRE
				warrior.show())
		hop.tween_method(func(t: float):
			warrior.global_position = (spot.lerp(CENTRE, t) if not here else CENTRE.lerp(spot, t))
			sprite.offset.y = -sin(t * PI) * HOP_HEIGHT, 0.0, 1.0, HOP_SECONDS)
		hop.tween_callback(func():
			sprite.offset.y = 0.0
			if here:
				for shape in warrior.find_children("*", "CollisionShape2D", true, false):
					(shape as CollisionShape2D).set_deferred("disabled", false)
			else:
				warrior.hide()  # down the hole
			_hopping -= 1
			if _hopping == 0:
				_hole.frame = HOLE_SHUT)
		AudioSfx.play("tiki", 0.0, Vector2.ONE * (0.8 + 0.1 * i))

func _march() -> void:
	_march_left = MARCH_SECONDS
	_march_way = 1.0 if randf() < 0.5 else -1.0
	_pattern = [CIRCLE, UP_DOWN, LEFT_RIGHT].pick_random()
	_linger = 0.0
	_rest_left = randf_range(MARCH_EVERY.x, MARCH_EVERY.y)
	AudioSfx.play("roar", 0.0, Vector2.ONE * 0.7)
