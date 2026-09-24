extends Node2D
## Interactive playfield features layered over the painted table art.
##
## The table art has empty lamp inserts painted in (lane circles, bonus bars,
## arrow inserts, wall lamps). This builds sprites on top of each one and runs
## the rules behind them: lane rollovers, bonus multiplier, the Tlaloc face
## target and the curse storm mode. Tlaloc's shrine, top right, shows the curse:
## his mask wakes as the face is hit and its raindrop lamps fill toward the storm.

# The 256x424 table art is stretched to 720x1280, so feature sprites use the same scale
const MAP_SCALE := Vector2(720.0 / 256.0, 1280.0 / 424.0)

const LANE_LAMP := preload("res://Sprites/table/lane_lamp.png")
const BONUS_BAR := preload("res://Sprites/table/bonus_bar.png")
const ARROW_INSERT := preload("res://Sprites/table/arrow_insert.png")
const TORCH := preload("res://Sprites/table/torch.png")
const RAINDROP := preload("res://Sprites/table/raindrop.png")
const TLALOC_MASK := preload("res://Sprites/table/tlaloc_mask.png")
const RAIN_LAMP := preload("res://Sprites/table/rain_lamp.png")
const BRAZIER := preload("res://Sprites/table/brazier.png")
const RampShots := preload("res://Scripts/ramp_shots.gd")
const Kickback := preload("res://Scripts/kickback.gd")
const SpiritCapture := preload("res://Scripts/spirit_capture.gd")
const Journey := preload("res://Scripts/journey.gd")
const TempleHole := preload("res://Scripts/temple_hole.gd")
const ElDorado := preload("res://Scripts/el_dorado.gd")

# Scene positions of the painted inserts (measured from Sprites/map_f1.png)
const TOP_LANES := [Vector2(329, 305), Vector2(388, 305), Vector2(447, 305)]
const BOTTOM_LANES := [Vector2(93, 1026), Vector2(160, 1026), Vector2(515, 1026), Vector2(582, 1026)]
const LANE_SENSOR_OFFSET := Vector2(0, 32)  # rollover slot painted just below each lamp
const BONUS_BARS := [Vector2(285, 1042), Vector2(311, 1042), Vector2(338, 1042), Vector2(364, 1042), Vector2(390, 1042)]
const ARROWS := [
	[Vector2(190, 366), 22.0], [Vector2(103, 374), 22.0], [Vector2(179, 555), 0.0],
	[Vector2(86, 725), -22.0], [Vector2(592, 725), 22.0],
]
const TORCHES := [Vector2(319, 549), Vector2(442, 642), Vector2(208, 815)]
# The shrine's empty panels, in table-art pixels (see tools/make_shrine_sprites.py)
const SHRINE_MASK_ART := Vector2(223.5, 42.5)
# Raindrop lamps either side of the mask, in fill order: bottom pair, then top pair
const SHRINE_LAMPS_ART := [Vector2(202.5, 46.5), Vector2(245.5, 46.5), Vector2(202.5, 38.5), Vector2(245.5, 38.5)]
const SHRINE_BRAZIERS_ART := [Vector2(202, 75.5), Vector2(246, 75.5)]

const TOP_LANE_POINTS := 250
const TOP_LANES_COMPLETE_POINTS := 2000
const BOTTOM_LANE_POINTS := 100
const BOTTOM_LANES_COMPLETE_POINTS := 5000
const FACE_POINTS := 500
const SKILL_SHOT_POINTS := 5000
const SKILL_SHOT_WINDOW := 3.0  # seconds; a top lane this soon after launch came straight off the plunger
const LANE_COOLDOWN := 0.8  # one bounce inside a rollover slot shouldn't score twice
const FACE_HITS_FOR_CURSE := 5  # for the first curse; each one after needs FACE_HITS_STEP more
const FACE_HITS_STEP := 2
const FACE_HIT_COOLDOWN := 1.5  # a ball rattling around on the face only counts once
const CURSE_SECONDS := 20.0
const CURSE_REST_SECONDS := 30.0  # once the rain passes Tlaloc sleeps, and face hits don't build
const MAX_MULTIPLIER := 5
const MULTIBALL_DELAY := 1.4  # Tlaloc spits out the extra ball after the curse toast
const MULTIBALL_SPEED := 1300.0
const MAX_BALLS := 2  # only from a single ball, so multiball can't feed more curses

@export var face_path: NodePath = ^"../center_face"

var _top_lamps: Array[AnimatedSprite2D] = []
var _bottom_lamps: Array[AnimatedSprite2D] = []
var _bars: Array[AnimatedSprite2D] = []
var _arrows: Array[AnimatedSprite2D] = []
var _torches: Array[AnimatedSprite2D] = []
var _top_lit := [false, false, false]
var _bottom_lit := [false, false, false, false]

var _face: Area2D
var _face_sprite: AnimatedSprite2D
var kickback: Node2D
var spirit: Node2D
var journey: Node2D
var temple: Node2D
var el_dorado: Node2D

var _face_hits := 0
var _face_cooldown := 0.0
var _curses := 0
var _rest_left := 0.0

enum { MASK_ASLEEP, MASK_STIRRING, MASK_CURSED }
var _shrine_mask: AnimatedSprite2D
var _shrine_lamps: Array[AnimatedSprite2D] = []

var _rain: CPUParticles2D
var _storm_tint: CanvasModulate
var _lightning: ColorRect
var _curse_timer: Timer
var _chase_step := 0
var _skill_shot_left := 0.0
var _lane_cooldowns := {}  # sensor id -> seconds left

func _ready() -> void:
	_build_lanes()
	_build_bonus_bars()
	_build_arrows()
	_build_torches()
	_build_shrine()
	_build_storm()
	_hook_face()
	kickback = Kickback.new()
	spirit = SpiritCapture.new()
	journey = Journey.new()
	temple = TempleHole.new()
	for mode in [RampShots.new(), kickback, spirit, journey, temple]:
		mode.features = self
		add_child(mode)
	# The bonus stage is its own chamber below the table, so it lives beside it
	el_dorado = ElDorado.new()
	el_dorado.features = self
	get_parent().add_child.call_deferred(el_dorado)

	var chase := Timer.new()
	chase.wait_time = 0.18
	chase.autostart = true
	chase.timeout.connect(_advance_chase)
	add_child(chase)

	PinballEvents.multiplier_changed.connect(_on_multiplier_changed)
	PinballEvents.scored_at.connect(_spawn_popup)
	PinballEvents.ball_launched.connect(func(): _skill_shot_left = SKILL_SHOT_WINDOW)
	_on_multiplier_changed(GameManager.multiplier)

# ---------- building ----------

func _frames(texture: Texture2D, frame_count: int, fps: float = 0.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", fps)
	frames.set_animation_loop("default", fps > 0.0)
	var w := texture.get_width() / frame_count
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * w, 0, w, texture.get_height())
		frames.add_frame("default", atlas)
	return frames

func _sprite(texture: Texture2D, frame_count: int, at: Vector2, fps: float = 0.0) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _frames(texture, frame_count, fps)
	sprite.position = at
	sprite.scale = MAP_SCALE
	add_child(sprite)
	return sprite

func _build_lanes() -> void:
	for i in TOP_LANES.size():
		_top_lamps.append(_sprite(LANE_LAMP, 2, TOP_LANES[i]))
		_add_sensor(TOP_LANES[i] + LANE_SENSOR_OFFSET, Vector2(22, 34), _on_top_lane.bind(i))
	for i in BOTTOM_LANES.size():
		_bottom_lamps.append(_sprite(LANE_LAMP, 2, BOTTOM_LANES[i]))
		_add_sensor(BOTTOM_LANES[i] + LANE_SENSOR_OFFSET, Vector2(24, 36), _on_bottom_lane.bind(i))

func _add_sensor(at: Vector2, size: Vector2, on_ball: Callable) -> void:
	var area := Area2D.new()
	area.position = at
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.body_entered.connect(func(body: Node):
		if _is_ball_on_playfield(body) and _lane_cooldowns.get(area, 0.0) <= 0.0:
			_lane_cooldowns[area] = LANE_COOLDOWN
			on_ball.call())
	add_child(area)

func _build_bonus_bars() -> void:
	for at in BONUS_BARS:
		_bars.append(_sprite(BONUS_BAR, 2, at))

func _build_arrows() -> void:
	for entry in ARROWS:
		var arrow := _sprite(ARROW_INSERT, 2, entry[0])
		arrow.rotation_degrees = entry[1]
		_arrows.append(arrow)

func _build_torches() -> void:
	for at in TORCHES:
		# Flame base sits on the painted lamp, flame rises above it
		var torch := _sprite(TORCH, 4, at, 8.0)
		torch.offset = Vector2(0, -4)
		torch.frame = randi() % 4
		torch.play()
		_torches.append(torch)

func _build_shrine() -> void:
	_shrine_mask = _sprite(TLALOC_MASK, 3, SHRINE_MASK_ART * MAP_SCALE)
	for at in SHRINE_LAMPS_ART:
		_shrine_lamps.append(_sprite(RAIN_LAMP, 2, at * MAP_SCALE))
	for at in SHRINE_BRAZIERS_ART:
		var brazier := _sprite(BRAZIER, 4, at * MAP_SCALE, 8.0)
		brazier.frame = randi() % 4
		brazier.play()
		_torches.append(brazier)  # flares up with the torches during the curse
	_render_shrine()

func _build_storm() -> void:
	_storm_tint = CanvasModulate.new()
	_storm_tint.color = Color.WHITE
	add_child(_storm_tint)

	_rain = CPUParticles2D.new()
	_rain.texture = RAINDROP
	_rain.emitting = false
	_rain.amount = 260
	_rain.lifetime = 0.9
	_rain.position = Vector2(360, -40)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(420, 10)
	_rain.direction = Vector2(-0.18, 1)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 1400.0
	_rain.initial_velocity_max = 1700.0
	_rain.gravity = Vector2.ZERO
	_rain.scale_amount_min = 2.6
	_rain.scale_amount_max = 3.4
	_rain.z_index = 4
	_rain.z_as_relative = false
	_rain.local_coords = false
	add_child(_rain)

	# Lives in the table world (not a CanvasLayer) so the flash doesn't wash out the HUD
	_lightning = ColorRect.new()
	_lightning.color = Color(0.85, 0.92, 1.0, 0.0)
	_lightning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning.size = Vector2(720, 1280)
	_lightning.z_index = 5
	_lightning.z_as_relative = false
	add_child(_lightning)

	_curse_timer = Timer.new()
	_curse_timer.one_shot = true
	_curse_timer.timeout.connect(_end_curse)
	add_child(_curse_timer)

func _hook_face() -> void:
	_face = get_node_or_null(face_path) as Area2D
	if _face == null:
		push_warning("TableFeatures: center face not found at %s" % face_path)
		return
	_face_sprite = _face.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_face.body_entered.connect(_on_face_body_entered)

# ---------- rules ----------

# Balls up on the ramps (gate added layer 2 to their mask) pass over playfield features
func _is_ball_on_playfield(body: Node) -> bool:
	var ball := body as RigidBody2D
	return ball != null and ball.is_in_group("ball") and (ball.collision_mask & 2) == 0

func _physics_process(delta: float) -> void:
	# Timers run on game time so they stay correct on slow frames
	_skill_shot_left = maxf(_skill_shot_left - delta, 0.0)
	_face_cooldown = maxf(_face_cooldown - delta, 0.0)
	if _rest_left > 0.0:
		_rest_left = maxf(_rest_left - delta, 0.0)
		if _rest_left == 0.0:
			_render_shrine()
	if GameManager.curse_active:
		_render_shrine()  # the lamps drain as the storm runs out
	for area in _lane_cooldowns:
		_lane_cooldowns[area] = maxf(_lane_cooldowns[area] - delta, 0.0)

	# Lane change: flippers rotate which top lanes are lit, like a real table
	if Input.is_action_just_pressed("left_flipper"):
		_top_lit.push_back(_top_lit.pop_front())
		_render_top_lanes()
	if Input.is_action_just_pressed("right_flipper"):
		_top_lit.push_front(_top_lit.pop_back())
		_render_top_lanes()

func _on_top_lane(index: int) -> void:
	if _skill_shot_left > 0.0:
		_skill_shot_left = 0.0
		_award(SKILL_SHOT_POINTS, _top_lamps[index].global_position + Vector2(0, -40))
		PinballEvents.toast.emit("Skill shot!")
	_award(TOP_LANE_POINTS, _top_lamps[index].global_position)
	_top_lit[index] = true
	_render_top_lanes()
	if not _top_lit.has(false):
		_top_lit = [false, false, false]
		_award(TOP_LANES_COMPLETE_POINTS, _top_lamps[1].global_position)
		PinballEvents.top_lanes_completed.emit()
		if GameManager.multiplier < MAX_MULTIPLIER:
			GameManager.set_multiplier(GameManager.multiplier + 1)
			PinballEvents.toast.emit("Bonus x%d" % GameManager.multiplier)
		_celebrate(_top_lamps, _render_top_lanes)

func _on_bottom_lane(index: int) -> void:
	_award(BOTTOM_LANE_POINTS, _bottom_lamps[index].global_position)
	_bottom_lit[index] = true
	_render_bottom_lanes()
	if not _bottom_lit.has(false):
		_bottom_lit = [false, false, false, false]
		_award(BOTTOM_LANES_COMPLETE_POINTS, Vector2(338, 1000))
		PinballEvents.toast.emit("Lanes complete!")
		_celebrate(_bottom_lamps, _render_bottom_lanes)

func _on_face_body_entered(body: Node) -> void:
	if not _is_ball_on_playfield(body):
		return
	if _face_cooldown > 0.0:
		return
	_face_cooldown = FACE_HIT_COOLDOWN

	_award(FACE_POINTS, _face.global_position)
	_flash_face_eyes()
	if GameManager.curse_active or _rest_left > 0.0:
		return
	# Only a shot up through the face stirs Tlaloc; a ball falling back over it doesn't
	if (body as RigidBody2D).linear_velocity.y > 0.0:
		return
	_face_hits += 1
	if _face_hits >= _face_hits_needed():
		_start_curse()
	else:
		PinballEvents.toast.emit("Tlaloc stirs %d/%d" % [_face_hits, _face_hits_needed()])
		_render_shrine()

func _face_hits_needed() -> int:
	return FACE_HITS_FOR_CURSE + FACE_HITS_STEP * _curses

func _award(points: int, at: Vector2) -> void:
	PinballEvents.add_score.emit(points)
	PinballEvents.scored_at.emit(points, at)

func _start_curse() -> void:
	_face_hits = 0
	_curses += 1
	GameManager.set_curse_active(true)
	PinballEvents.toast.emit("Tlaloc's Curse!")
	_rain.emitting = true
	create_tween().tween_property(_storm_tint, "color", Color(0.76, 0.8, 0.96), 0.8)
	for torch in _torches:
		torch.speed_scale = 2.0
	if _face_sprite:
		_face_sprite.frame = 1
	_strike_lightning()
	_curse_timer.start(CURSE_SECONDS)
	get_tree().create_timer(MULTIBALL_DELAY).timeout.connect(_release_extra_ball)

# Multiball: Tlaloc spits a copy of the ball out of the face, straight up the table
func _release_extra_ball() -> void:
	var balls := get_tree().get_nodes_in_group("ball")
	if balls.is_empty() or balls.size() >= MAX_BALLS or _face == null:
		return
	var from := _face.global_position + Vector2(0, -90)
	var velocity := Vector2(randf_range(-250.0, 250.0), -MULTIBALL_SPEED)
	balls[0].spawn_extra_ball(from, velocity)
	PinballEvents.toast.emit("Multiball!")
	AudioSfx.play("multiball")

func _end_curse() -> void:
	GameManager.set_curse_active(false)
	_rest_left = CURSE_REST_SECONDS
	_render_shrine()
	PinballEvents.toast.emit("The rain passes")
	_rain.emitting = false
	create_tween().tween_property(_storm_tint, "color", Color.WHITE, 1.2)
	for torch in _torches:
		torch.speed_scale = 1.0
	if _face_sprite:
		_face_sprite.frame = 0

func _strike_lightning() -> void:
	if not GameManager.curse_active:
		return
	var tween := create_tween()
	tween.tween_property(_lightning, "color:a", 0.55, 0.04)
	tween.tween_property(_lightning, "color:a", 0.0, 0.08)
	tween.tween_property(_lightning, "color:a", 0.35, 0.04)
	tween.tween_property(_lightning, "color:a", 0.0, 0.25)
	get_tree().create_timer(randf_range(2.5, 5.0)).timeout.connect(_strike_lightning)

# ---------- lamps ----------

func _render_top_lanes() -> void:
	for i in _top_lamps.size():
		_top_lamps[i].frame = 1 if _top_lit[i] else 0

func _render_bottom_lanes() -> void:
	for i in _bottom_lamps.size():
		_bottom_lamps[i].frame = 1 if _bottom_lit[i] else 0

# Mask: asleep, stirring once the face has been hit, blazing under the curse. The rain
# lamps fill toward the next curse, then drain as the storm runs out.
func _render_shrine() -> void:
	var lit := 0
	if GameManager.curse_active:
		_shrine_mask.frame = MASK_CURSED
		lit = ceili(_shrine_lamps.size() * _curse_timer.time_left / CURSE_SECONDS)
	elif _face_hits > 0 and _rest_left == 0.0:
		_shrine_mask.frame = MASK_STIRRING
		# spread over the hits before the one that brings the storm, so every hit shows
		lit = mini(ceili(float(_shrine_lamps.size() * _face_hits) / (_face_hits_needed() - 1)), _shrine_lamps.size())
	else:
		_shrine_mask.frame = MASK_ASLEEP
	for i in _shrine_lamps.size():
		_shrine_lamps[i].frame = 1 if i < lit else 0

func _on_multiplier_changed(multiplier: int) -> void:
	for i in _bars.size():
		_bars[i].frame = 1 if i < multiplier else 0

func _celebrate(lamps: Array[AnimatedSprite2D], restore: Callable) -> void:
	var tween := create_tween()
	for i in 4:
		tween.tween_callback(func(): for lamp in lamps: lamp.frame = 1)
		tween.tween_interval(0.12)
		tween.tween_callback(func(): for lamp in lamps: lamp.frame = 0)
		tween.tween_interval(0.12)
	tween.tween_callback(restore)

func _flash_face_eyes() -> void:
	if _face_sprite == null:
		return
	_face_sprite.frame = 1
	var pulse := create_tween()
	pulse.tween_property(_face, "scale", Vector2(2.2, 2.2), 0.06)
	pulse.tween_property(_face, "scale", Vector2(2, 2), 0.12)
	if not GameManager.curse_active:
		get_tree().create_timer(0.45).timeout.connect(func():
			if not GameManager.curse_active:
				_face_sprite.frame = 0)

func _advance_chase() -> void:
	# Arrow inserts chase toward the orbits; during the curse they all strobe
	_chase_step += 1
	for i in _arrows.size():
		if GameManager.curse_active:
			_arrows[i].frame = _chase_step % 2
		else:
			_arrows[i].frame = 1 if (_chase_step % _arrows.size()) == i else 0

# ---------- score popups ----------

func _spawn_popup(points: int, at: Vector2) -> void:
	var label := Label.new()
	label.text = "+%d" % (points * GameManager.score_factor())
	label.add_theme_font_override("font", ScareathonTheme.BODY_FONT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", ScareathonTheme.AMBER)
	label.add_theme_color_override("font_outline_color", ScareathonTheme.SHADOW)
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 6
	label.z_as_relative = false
	add_child(label)
	label.position = at - Vector2(30, 40)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
