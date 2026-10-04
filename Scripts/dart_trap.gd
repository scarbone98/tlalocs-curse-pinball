extends Node2D
## The poison dart trap: hit the gold button on the left inlane wall's tip while it's lit
## and poisoned darts rain down out of the dark above the table, one after another, and
## stick upright in the floor in open spots here and there. While they stand they're
## pegs, like a pachinko board's: the ball rattles off them (each knock pays and sets the
## dart quivering). After a while they flicker and pop back out in a puff of poison, and
## the button lights again a little later.

const FALLING := preload("res://Sprites/table/dart_falling.png")  # tools/make_table.py
const STUCK := preload("res://Sprites/table/dart_stuck.png")      # still, quivering
const SHADOW := preload("res://Sprites/table/dart_shadow.png")
const BUTTON_AT := Vector2(207, 815)     # the gold button on the left inlane wall's tip
const BUTTON_RADIUS := 36.0              # it's set into the wall's tip, so it reaches out past the face
const BUTTON_POINTS := 500
const PRESSED_SECONDS := 0.35
const DARTS := 7
const DART_GAP := 0.15        # seconds between darts coming down
const DROP := 300.0           # scene units above its spot a dart falls from
const FALL_SECONDS := 0.45
const STAND_SECONDS := 12.0   # how long they stand as pegs
const FLICKER_SECONDS := 2.0  # ...flickering at the end, about to pop out
const RELOAD_SECONDS := 4.0   # after they're gone, until the button lights again
const PEG_RADIUS := 7.0
const PEG_BOUNCE := 0.55      # livelier than the walls: the ball rattles off them
const HIT_POINTS := 250
const HIT_COOLDOWN := 0.15
const QUIVER_SECONDS := 0.3
# Where darts may land: the open floor, with room round each one, clear of the walls and
# everything else (checked against the physics), and of the balls
const FIELD := Rect2(150, 560, 400, 520)
const CLEARANCE := 26.0       # from any wall, sensor or ball
const SPACING := 52.0         # between darts
const TRIES := 80

var features: Node2D  # TableFeatures
var button_sprite: AnimatedSprite2D  # Scripts/lighting.gd lights it
var _pressed_left := 0.0
var _reload_left := 0.0
var _to_drop := 0         # darts still to come down this volley
var _next_dart := 0.0
var _darts: Array[Dictionary] = []  # each standing (or falling) dart: spot, sprite, body, left, ...

func _ready() -> void:
	features.dart_trap = self
	button_sprite = features.gold_button("dart_button")
	var button := Area2D.new()
	button.position = BUTTON_AT
	button.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BUTTON_RADIUS
	shape.shape = circle
	button.add_child(shape)
	button.body_entered.connect(_on_button)
	add_child(button)

func ready_to_fire() -> bool:
	return _reload_left <= 0.0 and _to_drop == 0 and _darts.is_empty()

func _on_button(body: Node) -> void:
	if _pressed_left > 0.0 or not features._is_ball_on_playfield(body):
		return
	_pressed_left = PRESSED_SECONDS
	features._award(BUTTON_POINTS, BUTTON_AT)
	PinballEvents.effect.emit("sparks", BUTTON_AT)
	if not ready_to_fire():
		return
	_to_drop = DARTS
	_next_dart = 0.0
	AudioSfx.play("charge")

# An open spot on the floor, clear of everything, or none
func _find_spot() -> Variant:
	var space := get_world_2d().direct_space_state
	var probe := CircleShape2D.new()
	probe.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	for i in TRIES:
		var spot := FIELD.position + Vector2(randf() * FIELD.size.x, randf() * FIELD.size.y)
		var crowded := false
		for dart in _darts:
			if spot.distance_to(dart.spot) < SPACING:
				crowded = true
				break
		if crowded:
			continue
		query.transform = Transform2D(0.0, spot)
		if not space.intersect_shape(query, 1).is_empty():
			continue  # a wall, a bumper, a lane's sensor, a ball...
		return spot
	return null

func _drop_dart() -> void:
	var found: Variant = _find_spot()
	if found == null:
		return
	var spot: Vector2 = found
	var shadow: AnimatedSprite2D = features._sprite(SHADOW, 1, spot)
	shadow.z_index = 1
	shadow.z_as_relative = false
	shadow.modulate.a = 0.0
	var dart: AnimatedSprite2D = features._sprite(FALLING, 1, spot + Vector2(0, -DROP))
	dart.z_index = 4  # coming down from above everything
	dart.z_as_relative = false
	var entry := {"spot": spot, "sprite": dart, "shadow": shadow, "body": null, "left": STAND_SECONDS + FALL_SECONDS, "cooldown": 0.0, "quiver": 0.0}
	_darts.append(entry)
	var fall := create_tween()
	fall.tween_property(dart, "position", spot + _stand_offset(), FALL_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(shadow, "modulate:a", 1.0, FALL_SECONDS)
	fall.tween_callback(_stick.bind(entry))
	AudioSfx.play("flipper", 0.0, Vector2(1.6, 1.9))

# Where the stuck dart's sprite sits so its foot is on the spot
func _stand_offset() -> Vector2:
	return Vector2(0, -(STUCK.get_height() / 2.0 - 1.0)) * features.MAP_SCALE

# Thunk: it's in the floor, a peg now
func _stick(entry: Dictionary) -> void:
	if not _darts.has(entry):
		return
	var spot: Vector2 = entry.spot
	var sprite: AnimatedSprite2D = entry.sprite
	sprite.sprite_frames = features._frames(STUCK, 2)
	sprite.position = spot + _stand_offset()
	sprite.z_index = 2  # over a ball rolling behind it, like the palms
	(entry.shadow as Node).queue_free()
	entry.shadow = null
	var body := StaticBody2D.new()
	body.position = spot
	var bounce := PhysicsMaterial.new()
	bounce.bounce = PEG_BOUNCE
	body.physics_material_override = bounce
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PEG_RADIUS
	shape.shape = circle
	body.add_child(shape)
	var touch := Area2D.new()
	touch.monitorable = false
	var reach := CollisionShape2D.new()
	var around := CircleShape2D.new()
	around.radius = PEG_RADIUS + 22.0  # the ball's radius and a little
	reach.shape = around
	touch.add_child(reach)
	touch.body_entered.connect(_on_peg_hit.bind(entry))
	body.add_child(touch)
	features.add_child.call_deferred(body)
	entry.body = body
	PinballEvents.effect.emit("poison", spot)
	PinballEvents.rumble.emit(1.0)

func _on_peg_hit(body: Node, entry: Dictionary) -> void:
	if entry.cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	entry.cooldown = HIT_COOLDOWN
	entry.quiver = QUIVER_SECONDS
	features._award(HIT_POINTS, entry.spot)
	AudioSfx.play("bumper", 0.0, Vector2(1.5, 1.8))

# It pops back out of the floor in a puff of poison
func _remove(entry: Dictionary) -> void:
	_darts.erase(entry)
	PinballEvents.effect.emit("poison", entry.spot)
	for key in ["sprite", "shadow", "body"]:
		var node: Variant = entry[key]
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	if _darts.is_empty() and _to_drop == 0:
		_reload_left = RELOAD_SECONDS

func _physics_process(delta: float) -> void:
	_pressed_left = maxf(_pressed_left - delta, 0.0)
	_reload_left = maxf(_reload_left - delta, 0.0)
	if _to_drop > 0:
		_next_dart -= delta
		if _next_dart <= 0.0:
			_next_dart = DART_GAP
			_to_drop -= 1
			_drop_dart()
			if _to_drop == 0 and _darts.is_empty():
				_reload_left = RELOAD_SECONDS  # nowhere to land at all
	for entry in _darts.duplicate():
		entry.left -= delta
		entry.cooldown = maxf(entry.cooldown - delta, 0.0)
		var sprite: AnimatedSprite2D = entry.sprite
		if entry.body != null:
			entry.quiver = maxf(entry.quiver - delta, 0.0)
			sprite.frame = 1 if entry.quiver > 0.0 and int(entry.quiver * 30.0) % 2 == 0 else 0
			sprite.visible = entry.left > FLICKER_SECONDS or int(entry.left * 8.0) % 2 == 0
		if entry.left <= 0.0:
			_remove(entry)
	features.show_gold_button(button_sprite, _pressed_left, ready_to_fire())
