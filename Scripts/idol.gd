extends Node2D
## The golden idol on its plinth in the middle of the table, above the temple hole, in
## the arc of the four relics. Balls dropping out of the mushroom patch and shots that
## run past the temple strike it: it rocks on its base, and the third strike topples it
## off the plinth in a shower of gold. A while later the temple's keepers set it back up.

const IDOL := preload("res://Sprites/table/idol.png")  # tools/make_tiki_idol.py

const AT := Vector2(337, 586)          # on the plinth painted into the table (tools/make_v2_table.py)
const BODY_RADIUS := 16.0
const SENSOR_RADIUS := 22.0
const HITS_TO_TOPPLE := 3
const HIT_COOLDOWN := 0.4
const HIT_POINTS := 750
const TOPPLE_POINTS := 15000
const DOWN_SECONDS := 20.0
const GLINT_EVERY := Vector2(2.0, 5.0)

enum { IDLE, GLINT, HIT, ROCK_LEFT, ROCK_RIGHT, TOPPLED }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _sprite: AnimatedSprite2D
var _body_shape: CollisionShape2D
var _hits := 0
var _cooldown := 0.0
var _down_left := 0.0

func _ready() -> void:
	_sprite = features._sprite(IDOL, 6, AT)

	var body := StaticBody2D.new()
	body.position = AT
	_body_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	_body_shape.shape = circle
	body.add_child(_body_shape)
	add_child(body)

	var sensor := Area2D.new()
	sensor.position = AT
	sensor.monitorable = false
	var shape := CollisionShape2D.new()
	var reach := CircleShape2D.new()
	reach.radius = SENSOR_RADIUS
	shape.shape = reach
	sensor.add_child(shape)
	sensor.body_entered.connect(_on_ball)
	add_child(sensor)
	_glint.call_deferred()

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _down_left > 0.0:
		_down_left -= delta
		if _down_left <= 0.0:
			_set_up()

func _on_ball(body: Node) -> void:
	if _cooldown > 0.0 or _down_left > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown = HIT_COOLDOWN
	_hits += 1
	PinballEvents.effect.emit("sparks", AT)
	PinballEvents.rumble.emit(2.5)
	if _hits < HITS_TO_TOPPLE:
		features._award(HIT_POINTS, AT)
		AudioSfx.play("bumper", 0.0, Vector2.ONE * (0.8 + 0.15 * _hits))
		PinballEvents.toast.emit("Golden idol %d/%d" % [_hits, HITS_TO_TOPPLE])
		# it rocks away from the side the ball struck
		var away := ROCK_RIGHT if (body as Node2D).global_position.x < AT.x else ROCK_LEFT
		var rock := create_tween()
		rock.tween_callback(func(): _sprite.frame = HIT)
		rock.tween_interval(0.06)
		for frame in [away, IDLE, ROCK_LEFT + ROCK_RIGHT - away, IDLE]:
			rock.tween_callback(func(): if _down_left <= 0.0: _sprite.frame = frame)
			rock.tween_interval(0.08)
		return
	_topple()

func _topple() -> void:
	_hits = 0
	_down_left = DOWN_SECONDS
	_sprite.frame = TOPPLED
	_body_shape.set_deferred("disabled", true)
	features._award(TOPPLE_POINTS, AT)
	PinballEvents.toast.emit("Idol toppled!")
	PinballEvents.effect.emit("gold", AT)
	PinballEvents.rumble.emit(5.0)
	AudioSfx.play("upgrade")

# Set back on its plinth, unless a ball is sitting where it stands
func _set_up() -> void:
	for node in get_tree().get_nodes_in_group("ball"):
		if (node as Node2D).global_position.distance_to(AT) < BODY_RADIUS + 22.0:
			_down_left = 0.5
			return
	_body_shape.set_deferred("disabled", false)
	_sprite.frame = IDLE
	PinballEvents.effect.emit("sparks", AT)

func _glint() -> void:
	get_tree().create_timer(randf_range(GLINT_EVERY.x, GLINT_EVERY.y), false).timeout.connect(func():
		if _sprite.frame == IDLE:
			_sprite.frame = GLINT
			get_tree().create_timer(0.2, false).timeout.connect(func():
				if _sprite.frame == GLINT:
					_sprite.frame = IDLE)
		_glint())
