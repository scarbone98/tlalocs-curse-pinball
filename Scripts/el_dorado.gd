extends Node2D
## El Dorado, the bonus stage at the end of the journey, like Pokemon Pinball's Mewtwo
## stage. It's a chamber of its own below the table, with the same flippers, inlanes
## and slingshots but no outlanes. The Gilded King slides across the top: strike him
## HITS_TO_WIN times before time runs out for the jackpot. Draining or running out of
## time just ends the trip; the ball goes back to the temple hole, no ball lost.
##
## The walls and art both come from tools/make_el_dorado.py (Scripts/el_dorado_geometry.gd
## and Sprites/el_dorado/stage.png), so they always line up.

const Geometry := preload("res://Scripts/el_dorado_geometry.gd")
const STAGE_ART := preload("res://Sprites/el_dorado/stage.png")
const KING := preload("res://Sprites/el_dorado/gilded_king.png")
const COIN := preload("res://Sprites/el_dorado/gold_coin.png")
const BUMPER_KICK := preload("res://TriggerActions/BumperActions/MushyKick.tres")
const BUMPER_SOUND := preload("res://TriggerActions/BumperActions/BumperSound.tres")

const ORIGIN := Vector2(0, 1600)  # stage-local (0, 0) in the world, clear of the table
const SECONDS := 60.0
const WARN_SECONDS := 10.0
const HITS_TO_WIN := 5
const KING_RADIUS := 34.0
const KING_SENSOR_RADIUS := 44.0
const KING_PERIOD := 4.5  # seconds for one sweep there and back
const KING_HIT_COOLDOWN := 0.5
const KING_POINTS := 5000
const COIN_POINTS := 500
const JACKPOT := 100000
const JACKPOT_STEP := 50000  # each trip's jackpot is worth more

enum { KING_IDLE, KING_HIT, KING_BEATEN }

var features: Node2D  # TableFeatures, for scoring and the table's own flippers
# The frogs' kick, with gold sparks instead of a water splash, for the coins and the King
var _gold_kick := _make_gold_kick()

var _ball: RigidBody2D
var _active := false
var _time_left := 0.0
var _hits := 0
var _king: AnimatableBody2D
var _king_sprite: AnimatedSprite2D
var _king_cooldown := 0.0
var _king_clock := 0.0
var _coins: Array[AnimatedSprite2D] = []
var _warned := false

func _ready() -> void:
	position = ORIGIN
	var art := Sprite2D.new()
	art.texture = STAGE_ART
	art.centered = false
	art.scale = features.MAP_SCALE
	add_child(art)

	var walls := StaticBody2D.new()
	for poly in Geometry.WALLS:
		var shape := CollisionPolygon2D.new()
		shape.polygon = PackedVector2Array(poly)
		walls.add_child(shape)
	add_child(walls)

	# The table's own flippers and slingshot kick, so the flipper area plays the same. The
	# table's flipper area sits left of centre (its plunger lane is on the right), so the
	# copies move over to the chamber's centre line, and the right side mirrors the left.
	var table := get_parent()
	var left_flipper := table.get_node("padels/l") as Node2D
	_add_copy(left_flipper, left_flipper.global_position + Vector2(Geometry.SHIFT, 0))
	var right_flipper := _add_copy(table.get_node("padels/r"), Vector2.ZERO)
	right_flipper.position = _mirror(left_flipper.global_position + Vector2(Geometry.SHIFT, 0))
	var sling := table.get_node("layer_1_colliders/left_bumper_green") as Node2D
	var sling_at := sling.global_position + Vector2(Geometry.SHIFT, 0)
	_add_copy(sling, sling_at)
	var right_sling := _add_copy(sling, _mirror(sling_at))
	var kick := right_sling.get_node("CollisionShape2D") as CollisionShape2D
	var segment := (kick.shape as SegmentShape2D).duplicate() as SegmentShape2D
	segment.a.x = -segment.a.x
	segment.b.x = -segment.b.x
	kick.shape = segment

	for at in Geometry.COINS:
		_add_coin(at)
	_add_king()

	var drain := Area2D.new()
	drain.position = Geometry.DRAIN_AT
	drain.monitorable = false
	var drain_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Geometry.DRAIN_SIZE
	drain_shape.shape = rect
	drain.add_child(drain_shape)
	drain.body_entered.connect(func(body): if body == _ball: _finish(false, "The gold slips away"))
	add_child(drain)

static func _make_gold_kick() -> BumperKickAction:
	var kick := BUMPER_KICK.duplicate() as BumperKickAction
	kick.effect = "sparks"
	return kick

func _add_copy(original: Node, at: Vector2) -> Node2D:
	var copy := original.duplicate() as Node2D
	add_child(copy)
	copy.position = at
	return copy

func _mirror(at: Vector2) -> Vector2:
	return Vector2(2.0 * Geometry.CENTRE - at.x, at.y)

func _add_coin(at: Vector2) -> void:
	var coin := Area2D.new()
	coin.set_script(preload("res://TriggerActions/trigger_area.gd"))
	var actions: Array[TriggerAction] = [_gold_kick, BUMPER_SOUND]
	coin.actions = actions
	coin.position = at
	coin.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Geometry.COIN_RADIUS
	shape.shape = circle
	coin.add_child(shape)
	add_child(coin)
	var sprite: AnimatedSprite2D = features._sprite(COIN, 2, Vector2.ZERO)
	sprite.reparent(coin, false)
	_coins.append(sprite)
	coin.body_entered.connect(func(body):
		if body != _ball:
			return
		features._award(COIN_POINTS, coin.global_position)
		sprite.frame = 1
		get_tree().create_timer(0.15).timeout.connect(func(): sprite.frame = 0))

func _add_king() -> void:
	_king = AnimatableBody2D.new()
	_king.position = Vector2(Geometry.KING_X.x, Geometry.KING_Y)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = KING_RADIUS
	shape.shape = circle
	_king.add_child(shape)
	add_child(_king)

	var sensor := Area2D.new()
	sensor.monitorable = false
	var sensor_shape := CollisionShape2D.new()
	var sensor_circle := CircleShape2D.new()
	sensor_circle.radius = KING_SENSOR_RADIUS
	sensor_shape.shape = sensor_circle
	sensor.add_child(sensor_shape)
	sensor.body_entered.connect(_on_king_hit)
	_king.add_child(sensor)

	_king_sprite = features._sprite(KING, 4, Vector2.ZERO)
	_king_sprite.reparent(_king, false)

func _physics_process(delta: float) -> void:
	# The King paces whether or not anyone's visiting, so the stage never looks frozen
	_king_clock += delta
	var sway := (1.0 - cos(_king_clock / KING_PERIOD * TAU)) * 0.5
	_king.position.x = lerpf(Geometry.KING_X.x, Geometry.KING_X.y, sway)
	_king_cooldown = maxf(_king_cooldown - delta, 0.0)
	if not _active:
		return
	var shown_seconds := ceili(_time_left)
	_time_left -= delta
	if ceili(_time_left) != shown_seconds:
		_show_progress()
	if _time_left <= WARN_SECONDS and not _warned:
		_warned = true
		PinballEvents.toast.emit("%d seconds!" % int(WARN_SECONDS))
	if _time_left <= 0.0:
		_finish(false, "Time's up")
	elif not Rect2(Vector2.ZERO, Vector2(720, 1280)).has_point(to_local(_ball.global_position)):
		_finish(false, "The gold slips away")  # can't happen through the walls, but never strand a ball

## Takes the ball the temple hole is holding and drops it into the chamber
func enter(ball: RigidBody2D) -> void:
	_ball = ball
	_active = true
	_time_left = SECONDS
	_hits = 0
	_warned = false
	_king_sprite.frame = KING_IDLE
	ball.stage_origin = ORIGIN
	ball.global_position = to_global(Geometry.ENTRY)
	ball.anim.scale = Vector2.ONE * ball.draw_scale
	ball.freeze = false
	ball.linear_velocity = Vector2(0, 150)
	_show_camera_on(Rect2(ORIGIN, Vector2(720, 1280)))
	PinballEvents.toast.emit("Strike the Gilded King!")
	_show_progress()
	AudioSfx.play("multiball")

func _on_king_hit(body: Node) -> void:
	if not _active or body != _ball or _king_cooldown > 0.0:
		return
	_king_cooldown = KING_HIT_COOLDOWN
	_gold_kick.execute(_ball, _king)
	PinballEvents.rumble.emit(6.0)
	_hits += 1
	features._award(KING_POINTS, _king.global_position)
	AudioSfx.play("spirit_hit", 0.0, Vector2.ONE * (1.0 + 0.1 * _hits))
	_king_sprite.frame = KING_HIT
	get_tree().create_timer(0.2).timeout.connect(func():
		if _active:
			_king_sprite.frame = KING_IDLE)
	if _hits >= HITS_TO_WIN:
		_king_sprite.frame = KING_BEATEN
		var jackpot: int = JACKPOT + JACKPOT_STEP * features.journey.trips
		features._award(jackpot, _king.global_position + Vector2(0, -60))
		PinballEvents.effect.emit("gold", _king.global_position)
		PinballEvents.rumble.emit(10.0)
		AudioSfx.play("catch")
		_finish(true, "EL DORADO!")
	else:
		PinballEvents.toast.emit("Gilded King %d/%d" % [_hits, HITS_TO_WIN])
		_show_progress()

func _show_progress() -> void:
	PinballEvents.objective_changed.emit("Gilded King %d/%d   %ds" % [_hits, HITS_TO_WIN, maxi(ceili(_time_left), 0)])

func _finish(won: bool, message: String) -> void:
	if not _active:
		return
	_active = false
	PinballEvents.toast.emit(message)
	var ball := _ball
	ball.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	ball.set_deferred("freeze", true)
	ball.linear_velocity = Vector2.ZERO
	# A beat to see the result before heading back up to the table
	get_tree().create_timer(1.5 if won else 0.8).timeout.connect(func():
		ball.stage_origin = Vector2.ZERO
		_show_camera_on(Rect2(0, 0, 720, 1280))
		features.journey.el_dorado_finished()
		features.temple.eject(ball))

func _show_camera_on(area: Rect2) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	camera.limit_left = int(area.position.x)
	camera.limit_top = int(area.position.y)
	camera.limit_right = int(area.end.x)
	camera.limit_bottom = int(area.end.y)
	camera.global_position = _ball.global_position
	camera.reset_smoothing.call_deferred()
