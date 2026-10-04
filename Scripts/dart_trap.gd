extends Node2D
## The poison dart trap: hit the gold button on the left inlane wall's tip while it's lit
## and poisoned darts rain down out of the dark above the table, one after another. Most
## stick upright in the floor in open spots here and there, and while they stand they're
## pegs, like a pachinko board's: the ball rattles off them (each knock pays and sets the
## dart quivering), and a second knock snaps one. Some come down on what's about: a
## warrior stung by one hops down the hole in the arena for a while, a jaguar ducks back
## into its hole, and one in Tlaloc's eye shoots it clean out of his head, for a lot. With
## all the torches lit the darts come down flaming: worth more, and they spark when hit.
## The button stays lit while the darts are out; after a while the pegs flicker and pop
## back out in a puff, and a little later the button works again.

const FALLING := preload("res://Sprites/table/dart_falling.png")  # tools/make_table.py
const STUCK := preload("res://Sprites/table/dart_stuck.png")      # still, quivering
const SHADOW := preload("res://Sprites/table/dart_shadow.png")
const RUNE_LIT := preload("res://Sprites/table/dart_rune_lit.png")  # the skull and crossbones over the button, glowing
const RUNE_ART := Vector2(62, 256)  # its top left, in table-art pixels (tools/make_table.py DART_RUNE_AT)
const BUTTON_AT := Vector2(207, 815)     # the gold button on the left inlane wall's tip
const BUTTON_REACH := 32.0               # a knock into the wall this near it presses it
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
const BREAK_POINTS := 1000    # the second knock snaps it
const KNOCKS_TO_BREAK := 2
const BREAK_DELAY := 0.15     # a snapped dart stands this long, for the ball to bounce off it
const FLAMING_MULTIPLIER := 3  # a flaming dart pays this many times as much
const HIT_COOLDOWN := 0.15
const QUIVER_SECONDS := 0.3
# Where darts may land: the open floor, with room round each one, clear of the walls and
# everything else (checked against the physics), and of the balls
const FIELD := Rect2(150, 560, 400, 520)
const CLEARANCE := 26.0       # from any wall, sensor or ball
const SPACING := 52.0         # between darts
const TRIES := 80
# Some darts come down on what's about, a little off: within these it's a hit
const AIM_CHANCE := 0.45      # each dart, if there's anything to aim at
const EYE_AIM_CHANCE := 0.3   # ...and his eyes are among them only some volleys
const AIM_SCATTER := {"warrior": 18.0, "jaguar": 18.0, "eye": 9.0}
const HIT_REACH := {"warrior": 22.0, "jaguar": 26.0, "eye": 8.0}
const STING_POINTS := 2500

var features: Node2D  # TableFeatures
var button_sprite: AnimatedSprite2D  # Scripts/lighting.gd lights it
var _pressed_left := 0.0
var _reload_left := 0.0
var _rune: Sprite2D
var _to_drop := 0         # darts still to come down this volley
var _next_dart := 0.0
var _flaming := false     # this volley's darts are alight
var _eyes_in_play := false
var _darts: Array[Dictionary] = []  # each standing (or falling) dart: spot, sprite, body, left, ...

func _ready() -> void:
	_rune = Sprite2D.new()
	_rune.texture = RUNE_LIT
	_rune.centered = false
	_rune.scale = features.MAP_SCALE
	_rune.position = RUNE_ART * features.MAP_SCALE
	_rune.visible = false
	features.add_child(_rune)
	features.dart_trap = self
	button_sprite = features.gold_button("dart_button")
	# pressed only by a ball knocked into it, not one grazing past or rolling over it
	PinballEvents.ball_struck.connect(func(ball: RigidBody2D, at: Vector2, _into: float):
		if at.distance_to(BUTTON_AT) < BUTTON_REACH:
			_on_button(ball))

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
	_flaming = features.torch_lane != null and features.torch_lane.all_lit()
	_eyes_in_play = randf() < EYE_AIM_CHANCE
	AudioSfx.play("charge")

# What's about to aim at: [kind, index, where]
func _targets() -> Array:
	var out: Array = []
	if features.warriors:
		var warriors: Dictionary = features.warriors.targets()
		for i in warriors:
			out.append(["warrior", i, warriors[i]])
	if features.journey:
		var jaguars: Dictionary = features.journey.targets()
		for side in jaguars:
			out.append(["jaguar", side, jaguars[side]])
	if _eyes_in_play:
		var eyes: Dictionary = features.eye_targets()
		for i in eyes:
			out.append(["eye", i, eyes[i]])
	return out

# An open spot on the floor, clear of everything, or none
func _find_spot() -> Variant:
	var space := get_world_2d().direct_space_state
	for i in TRIES:
		var spot := FIELD.position + Vector2(randf() * FIELD.size.x, randf() * FIELD.size.y)
		if _crowded(spot) or not _clear(space, spot):
			continue
		return spot
	return null

func _crowded(spot: Vector2) -> bool:
	for dart in _darts:
		if spot.distance_to(dart.spot) < SPACING:
			return true
	return false

func _clear(space: PhysicsDirectSpaceState2D, spot: Vector2) -> bool:
	var probe := CircleShape2D.new()
	probe.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	query.transform = Transform2D(0.0, spot)
	return space.intersect_shape(query, 1).is_empty()  # no wall, bumper, lane sensor, ball...

func _drop_dart() -> void:
	var spot: Vector2
	var targets := _targets()
	if not targets.is_empty() and randf() < AIM_CHANCE:
		var target: Array = targets.pick_random()
		spot = target[2] + Vector2.from_angle(randf() * TAU) * randf() * AIM_SCATTER[target[0]]
	else:
		var found: Variant = _find_spot()
		if found == null:
			return
		spot = found
	var shadow: AnimatedSprite2D = features._sprite(SHADOW, 1, spot)
	shadow.z_index = 1
	shadow.z_as_relative = false
	shadow.modulate.a = 0.0
	var dart: AnimatedSprite2D = features._sprite(FALLING, 1, spot + Vector2(0, -DROP))
	dart.z_index = 4  # coming down from above everything
	dart.z_as_relative = false
	var entry := {"spot": spot, "sprite": dart, "shadow": shadow, "body": null, "fire": null,
		"left": STAND_SECONDS + FALL_SECONDS, "cooldown": 0.0, "quiver": 0.0, "knocks": 0, "flaming": _flaming}
	if _flaming:
		dart.modulate = Color(1.0, 0.8, 0.55)
		entry.fire = _flame(dart)
	_darts.append(entry)
	var fall := create_tween()
	fall.tween_property(dart, "position", spot + _stand_offset(), FALL_SECONDS).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(shadow, "modulate:a", 1.0, FALL_SECONDS)
	fall.tween_callback(_land.bind(entry))
	AudioSfx.play("flipper", 0.0, Vector2(1.6, 1.9))

# Fire licking up off a flaming dart's flights
func _flame(dart: Node2D) -> CPUParticles2D:
	var dot := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	dot.fill(Color.WHITE)
	var fire := CPUParticles2D.new()
	fire.texture = ImageTexture.create_from_image(dot)
	fire.amount = 10
	fire.lifetime = 0.4
	fire.local_coords = false
	fire.position = Vector2(0, -5)  # at its flights (the dart's own art pixels)
	fire.scale = Vector2.ONE / features.MAP_SCALE
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(5, 3)
	fire.direction = Vector2(0, -1)
	fire.spread = 20.0
	fire.initial_velocity_min = 20.0
	fire.initial_velocity_max = 45.0
	fire.gravity = Vector2.ZERO
	fire.scale_amount_min = 2.9
	fire.scale_amount_max = 2.9
	var burn := Gradient.new()
	burn.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	burn.colors = PackedColorArray([Color(1.0, 0.95, 0.6), Color(1.0, 0.5, 0.1), Color(0.6, 0.1, 0.0, 0.0)])
	fire.color_ramp = burn
	dart.add_child(fire)
	return fire

# Where the stuck dart's sprite sits so its foot is on the spot
func _stand_offset() -> Vector2:
	return Vector2(0, -(STUCK.get_height() / 2.0 - 1.0)) * features.MAP_SCALE

# It comes down: in something about (a warrior, a jaguar, his eye), or in the floor
func _land(entry: Dictionary) -> void:
	if not _darts.has(entry):
		return
	var spot: Vector2 = entry.spot
	for target in _targets() + _eye_targets_always():
		if spot.distance_to(target[2]) <= HIT_REACH[target[0]]:
			_hit(target, spot)
			_remove(entry, false)
			return
	if not _clear(get_world_2d().direct_space_state, spot) or _crowded_by_others(entry):
		_remove(entry, false)  # it clatters off whatever's there
		return
	_stick(entry)

# His eyes count wherever a dart comes down, not only in the volleys that aim at them
func _eye_targets_always() -> Array:
	if _eyes_in_play:
		return []  # already among the targets
	var out: Array = []
	var eyes: Dictionary = features.eye_targets()
	for i in eyes:
		out.append(["eye", i, eyes[i]])
	return out

func _crowded_by_others(entry: Dictionary) -> bool:
	for dart in _darts:
		if dart != entry and dart.body != null and entry.spot.distance_to(dart.spot) < SPACING * 0.6:
			return true
	return false

func _hit(target: Array, at: Vector2) -> void:
	PinballEvents.effect.emit("poison", at)
	match target[0]:
		"warrior":
			features.warriors.sting(target[1])
			features._award(STING_POINTS, at)
		"jaguar":
			features.journey.sting(target[1])
			features._award(STING_POINTS, at)
		"eye":
			features.shoot_eye(target[1])

# Thunk: it's in the floor, a peg now
func _stick(entry: Dictionary) -> void:
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
	PinballEvents.effect.emit("sparks" if entry.flaming else "poison", spot)
	PinballEvents.rumble.emit(1.0)

func _on_peg_hit(body: Node, entry: Dictionary) -> void:
	if entry.cooldown > 0.0 or not features._is_ball_on_playfield(body) or not _darts.has(entry):
		return
	entry.cooldown = HIT_COOLDOWN
	entry.quiver = QUIVER_SECONDS
	entry.knocks += 1
	var worth := FLAMING_MULTIPLIER if entry.flaming else 1
	if entry.flaming:
		PinballEvents.effect.emit("sparks", entry.spot)
	if entry.knocks >= KNOCKS_TO_BREAK:
		features._award(BREAK_POINTS * worth, entry.spot)
		AudioSfx.play("tiki", 0.0, Vector2(1.6, 1.9))  # crack
		PinballEvents.effect.emit("dust", entry.spot)
		entry.cooldown = 99.0
		# snapped - but it stands a moment longer, so the ball still bounces off it
		get_tree().create_timer(BREAK_DELAY, false).timeout.connect(func():
			if _darts.has(entry):
				_remove(entry, false))
		return
	features._award(HIT_POINTS * worth, entry.spot)
	AudioSfx.play("bumper", 0.0, Vector2(1.5, 1.8))

# It's gone: popped back out of the floor in a puff, or snapped, or in something
func _remove(entry: Dictionary, puff: bool = true) -> void:
	_darts.erase(entry)
	if puff:
		PinballEvents.effect.emit("poison", entry.spot)
	for key in ["sprite", "shadow", "body"]:
		var node: Variant = entry[key]
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	if _darts.is_empty() and _to_drop == 0:
		_reload_left = RELOAD_SECONDS

func _physics_process(delta: float) -> void:
	# the skull over the button glows poison green while the darts are out
	_rune.visible = _to_drop > 0 or not _darts.is_empty()
	if _rune.visible:
		_rune.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
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
	features.show_gold_button(button_sprite, _pressed_left, _to_drop > 0 or not _darts.is_empty())  # lit while the darts are out
