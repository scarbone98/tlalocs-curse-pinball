extends Node2D
## Interactive playfield features layered over the painted table art.
##
## The table art has empty lamp inserts painted in (lane circles, bonus bars,
## arrow inserts, wall lamps). This builds sprites on top of each one and runs
## the rules behind them: lane rollovers, bonus multiplier, the Tlaloc face
## target and the curse storm mode. Tlaloc watches from the stone face in the top-left
## corner: his eyes wake as the face is hit and the raindrop lamps under it fill toward
## the storm.

# The 256x424 table art is stretched to 720x1280, so feature sprites use the same scale
const MAP_SCALE := Vector2(720.0 / 256.0, 1280.0 / 424.0)

const LANE_LAMP := preload("res://Sprites/table/lane_lamp.png")
const BONUS_BAR := preload("res://Sprites/table/bonus_bar.png")
const RAINDROP := preload("res://Sprites/table/raindrop.png")
const STONE_EYE := preload("res://Sprites/table/stone_eye.png")
const RAIN_LAMP := preload("res://Sprites/table/rain_lamp.png")
const FACE_EYE := preload("res://Sprites/table/face_eye.png")
const SLING_LIT := [preload("res://Sprites/table/sling_left_lit.png"), preload("res://Sprites/table/sling_right_lit.png")]
const RampShots := preload("res://Scripts/ramp_shots.gd")
const Kickback := preload("res://Scripts/kickback.gd")
const SpiritCapture := preload("res://Scripts/spirit_capture.gd")
const Journey := preload("res://Scripts/journey.gd")
const Spinner := preload("res://Scripts/spinner.gd")
const Torches := preload("res://Scripts/torches.gd")
const Temple := preload("res://Scripts/temple.gd")
const Rails := preload("res://Scripts/rails.gd")
const IdolTower := preload("res://Scripts/idol_tower.gd")
const CrystalSkull := preload("res://Scripts/crystal_skull.gd")
const Warriors := preload("res://Scripts/warriors.gd")
const Awakening := preload("res://Scripts/awakening.gd")
const Hatchling := preload("res://Scripts/hatchling.gd")
const Nudge := preload("res://Scripts/nudge.gd")
const Palms := preload("res://Scripts/palms.gd")
const Plunger := preload("res://Scripts/plunger.gd")
const TableGeometry := preload("res://Scripts/table_geometry.gd")
const FloorRoulette := preload("res://Scripts/floor_roulette.gd")
const Lighting := preload("res://Scripts/lighting.gd")
const Sacrifices := preload("res://Scripts/sacrifices.gd")
const SpiritLane := preload("res://Scripts/spirit_lane.gd")
const Effects := preload("res://Scripts/effects.gd")
const TableLife := preload("res://Scripts/table_life.gd")
const Music := preload("res://Scripts/music.gd")
const TempleHole := preload("res://Scripts/temple_hole.gd")
const ElDorado := preload("res://Scripts/el_dorado.gd")

# Scene positions of the painted inserts (measured from Sprites/map_f1.png)
const TOP_LANES := [Vector2(329, 305), Vector2(388, 305), Vector2(447, 305)]
const BOTTOM_LANES := [Vector2(93, 1026), Vector2(160, 1026), Vector2(515, 1026), Vector2(582, 1026)]
const LANE_SENSOR_OFFSET := Vector2(0, 32)  # rollover slot painted just below each lamp
const BONUS_BARS := [Vector2(285, 1042), Vector2(311, 1042), Vector2(338, 1042), Vector2(364, 1042), Vector2(390, 1042)]
# Tlaloc watches from the stone face in the top-left corner (in table-art pixels): his
# eyes show his mood, and the raindrop lamps under it fill toward the storm, in order
const SHRINE_EYES_ART := [Vector2(31.5, 31.5), Vector2(39.5, 31.5)]
const SHRINE_LAMPS_ART := [Vector2(25, 55), Vector2(45, 55), Vector2(31, 58), Vector2(39, 58)]
# The centre face's eyes (the hand-drawn yelloweye.png and redeye.png over eyeless.png)
# follow the ball, a table-art pixel at most, from their sockets
const FACE_EYES_ART := [Vector2(-6, -6), Vector2(7, -6)]
# The slingshots light up (bumperleftlightup.png, bumperrightlightup.png) as they kick:
# where each lit sprite sits, in table-art pixels, and the kicker it belongs to
const SLINGS := [
	[Vector2(80, 352.5), ^"../layer_1_colliders/left_bumper_green"],
	[Vector2(161, 349.5), ^"../layer_1_colliders/right_bumper_green"],
]
const SLING_LIT_SECONDS := 0.15
const EYE_FOLLOW := 250.0  # scene units of distance for each art pixel the eyes turn

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
# Ball upgrades, like Pokemon Pinball Ruby & Sapphire's Poke, Great, Ultra and Master
# Balls: x1 to x4 on everything scored. Completing the top lanes moves up one; a minute
# later it wears down one, and so on back to iron. A drain costs one step, not all.
const BALL_TIERS := [["Iron", 1], ["Silver", 2], ["Emerald", 3], ["Gold", 4]]
const UPGRADE_SECONDS := 60.0
const TOP_TIER_POINTS := 25000  # completing the lanes with the gold ball already out
const MULTIBALL_DELAY := 1.4  # Tlaloc spits out the extra ball after the curse toast
const MULTIBALL_SPEED := 1300.0
const MAX_BALLS := 2  # only from a single ball, so multiball can't feed more curses

@export var face_path: NodePath = ^"../center_face"

var _top_lamps: Array[AnimatedSprite2D] = []
var _bottom_lamps: Array[AnimatedSprite2D] = []
var _bars: Array[AnimatedSprite2D] = []
var _torches: Array[AnimatedSprite2D] = []
var _top_lit := [false, false, false]
var _bottom_lit := [false, false, false, false]

var _face: Area2D
var _face_sprite: AnimatedSprite2D
var kickback: Node2D
var spirit: Node2D
var journey: Node2D
var temple: Node2D
var awakening: Node2D
var hatchling: Node2D
var ramps: Node2D
var rails: Node2D
var skull: Node2D
var idol_tower: Node2D
var spinner: Node2D
var el_dorado: Node2D
var roulette: Node2D  # Scripts/floor_roulette.gd sets itself here
var sacrifices: Node2D  # Scripts/sacrifices.gd
var spirit_lane: Node2D  # Scripts/spirit_lane.gd

var _face_hits := 0
var _face_cooldown := 0.0
var _curses := 0
var _tier := 0
var _tier_left := 0.0
var _rest_left := 0.0

enum { MASK_ASLEEP, MASK_STIRRING, MASK_CURSED, MASK_GLOWING }
var _shrine_mask: AnimatedSprite2D  # the stone face's left eye; the right one copies it
var _shrine_eye_right: AnimatedSprite2D
var _face_eyes: Array[Sprite2D] = []
var _eyes_red_left := 0.0
var _shrine_lamps: Array[AnimatedSprite2D] = []
var _shrine_flash_left := 0.0

var _rain: CPUParticles2D
var _storm_tint: CanvasModulate
var _lightning: ColorRect
var _curse_timer: Timer
var _skill_shot_left := 0.0
var _lane_cooldowns := {}  # sensor id -> seconds left

func _ready() -> void:
	_build_lanes()
	_build_bonus_bars()
	_build_shrine()
	_build_storm()
	_build_lane_gate()
	_hook_face()
	_build_slings()
	kickback = Kickback.new()
	spirit = SpiritCapture.new()
	journey = Journey.new()
	temple = TempleHole.new()
	awakening = Awakening.new()
	hatchling = Hatchling.new()
	ramps = RampShots.new()
	rails = Rails.new()
	skull = CrystalSkull.new()
	idol_tower = IdolTower.new()
	spinner = Spinner.new()
	for mode in [ramps, rails, kickback, spirit, journey, temple, spinner, Torches.new(), Temple.new(), idol_tower, skull, awakening, hatchling, Warriors.new(), Nudge.new(), Palms.new(), Plunger.new(), FloorRoulette.new(), Sacrifices.new(), SpiritLane.new(), Lighting.new()]:
		mode.features = self
		add_child(mode)
	add_child(Effects.new())
	add_child(Music.new())
	var life := TableLife.new()
	life.features = self
	add_child(life)
	# The bonus stage is its own chamber below the table, so it lives beside it
	el_dorado = ElDorado.new()
	el_dorado.features = self
	get_parent().add_child.call_deferred(el_dorado)

	PinballEvents.bonus_multiplier_changed.connect(_render_bonus_bars)
	PinballEvents.scored_at.connect(_spawn_popup)
	PinballEvents.ball_launched.connect(func(): _skill_shot_left = SKILL_SHOT_WINDOW)
	PinballEvents.ball_drained.connect(_on_ball_drained)
	_render_bonus_bars(GameManager.bonus_multiplier)

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

## One of the gold buttons painted in the basemap (Scripts/table_geometry.gd GOLD_BUTTONS):
## a sprite over it with two frames, lit and pressed, hidden while it's just the paint
func gold_button(button: String) -> AnimatedSprite2D:
	var texture: Texture2D = load("res://Sprites/table/%s.png" % button)  # tools/make_table.py
	var sprite := _sprite(texture, 2, TableGeometry.GOLD_BUTTONS[button] * MAP_SCALE)
	sprite.hide()
	return sprite

## Shows a gold button pressed for a moment after a hit, then lit while it's doing something
static func show_gold_button(sprite: AnimatedSprite2D, pressed_left: float, lit: bool) -> void:
	sprite.visible = pressed_left > 0.0 or lit
	sprite.frame = 1 if pressed_left > 0.0 else 0

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

# The launch lane runs up the right side and round the top-right orbit into the top of
# the table. Without a gate a ball in play could run the orbit backwards and drop all
# the way back into the launch lane, so, like Pokemon Pinball's, a one-way gate where
# the orbit meets the table lets launched balls out but turns balls in play away.
const LANE_GATE_X := 480.0
const LANE_GATE_SPAN := Vector2(215, 305)  # across the orbit, ends buried in its walls

func _build_lane_gate() -> void:
	var gate := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var segment := SegmentShape2D.new()
	segment.a = Vector2(-(LANE_GATE_SPAN.y - LANE_GATE_SPAN.x) / 2.0, 0)
	segment.b = Vector2((LANE_GATE_SPAN.y - LANE_GATE_SPAN.x) / 2.0, 0)
	shape.shape = segment
	shape.one_way_collision = true
	# One-way shapes stop bodies moving along their local +y; turned a quarter, that's
	# a ball heading right, into the orbit. Launched balls come out heading left.
	shape.rotation_degrees = -90.0
	shape.position = Vector2(LANE_GATE_X, (LANE_GATE_SPAN.x + LANE_GATE_SPAN.y) / 2.0)
	gate.add_child(shape)
	add_child(gate)

func _build_shrine() -> void:
	_shrine_mask = _sprite(STONE_EYE, 4, SHRINE_EYES_ART[0] * MAP_SCALE)
	_shrine_eye_right = _sprite(STONE_EYE, 4, SHRINE_EYES_ART[1] * MAP_SCALE)
	for at in SHRINE_LAMPS_ART:
		_shrine_lamps.append(_sprite(RAIN_LAMP, 2, at * MAP_SCALE))
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
	_rain.scale_amount_min = 3.0  # the table art's own scale
	_rain.scale_amount_max = 3.0
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

func _build_slings() -> void:
	for i in SLINGS.size():
		var lit: AnimatedSprite2D = _sprite(SLING_LIT[i], 1, SLINGS[i][0] * MAP_SCALE)
		lit.hide()
		var kicker := get_node_or_null(SLINGS[i][1]) as Area2D
		if kicker:
			kicker.body_entered.connect(func(body: Node):
				if body.is_in_group("ball"):
					lit.show()
					get_tree().create_timer(SLING_LIT_SECONDS, false).timeout.connect(lit.hide))

func _hook_face() -> void:
	_face = get_node_or_null(face_path) as Area2D
	if _face == null:
		push_warning("TableFeatures: center face not found at %s" % face_path)
		return
	_face_sprite = _face.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_face.body_entered.connect(_on_face_body_entered)
	for at in FACE_EYES_ART:
		var eye := Sprite2D.new()
		eye.texture = FACE_EYE
		eye.hframes = 2
		eye.scale = MAP_SCALE
		eye.position = at * MAP_SCALE
		_face.add_child(eye)
		_face_eyes.append(eye)

# The face's eyes turn a pixel toward the ball the camera's watching, and blaze red with it
func _follow_with_eyes() -> void:
	var camera := get_viewport().get_camera_2d()
	var followed: Variant = camera.get("_followed") if camera else null
	# an extra ball the camera followed may have drained and been freed since
	var target: Node2D = followed as Node2D if is_instance_valid(followed) else null
	for i in _face_eyes.size():
		var eye := _face_eyes[i]
		var home: Vector2 = FACE_EYES_ART[i] * MAP_SCALE
		var look := Vector2.ZERO
		if is_instance_valid(target):
			var to := (target.global_position - (_face.global_position + home)) / EYE_FOLLOW
			look = Vector2(clampf(roundf(to.x), -1.0, 1.0), clampf(roundf(to.y), -1.0, 1.0))
		eye.position = home + look * MAP_SCALE
		eye.frame = 1 if GameManager.curse_active or _eyes_red_left > 0.0 else 0

# ---------- rules ----------

## True while a mode is running (catch, Awakening, travel, a hatchling, El Dorado): the
## ramps' arrows don't light then, as on Pokemon Pinball Ruby & Sapphire
func mode_running() -> bool:
	return spirit._active or awakening.active or journey.traveling or hatchling.active \
		or (el_dorado != null and el_dorado._active)

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
	_eyes_red_left = maxf(_eyes_red_left - delta, 0.0)
	_follow_with_eyes()
	_shrine_eye_right.frame = _shrine_mask.frame
	if _shrine_flash_left > 0.0:
		_shrine_flash_left -= delta
		_shrine_mask.frame = MASK_CURSED  # eyes blazing while he takes an offering
		if _shrine_flash_left <= 0.0:
			_render_shrine()
	elif GameManager.curse_active:
		_render_shrine()  # the lamps drain as the storm runs out
	elif _shrine_mask.frame == MASK_STIRRING or _shrine_mask.frame == MASK_GLOWING:
		# his eyes smoulder while he stirs
		_shrine_mask.frame = MASK_GLOWING if Time.get_ticks_msec() % 900 < 450 else MASK_STIRRING
	if _tier > 0:
		_tier_left -= delta
		if _tier_left <= 0.0:
			_tier -= 1
			_tier_left = UPGRADE_SECONDS
			_apply_tier()
			AudioSfx.play("downgrade")
	for area in _lane_cooldowns:
		_lane_cooldowns[area] = maxf(_lane_cooldowns[area] - delta, 0.0)

	# Lane change: flippers rotate which lanes are lit, top and bottom, like a real table
	if Input.is_action_just_pressed("left_flipper"):
		_top_lit.push_back(_top_lit.pop_front())
		_bottom_lit.push_back(_bottom_lit.pop_front())
		_render_top_lanes()
		_render_bottom_lanes()
	if Input.is_action_just_pressed("right_flipper"):
		_top_lit.push_front(_top_lit.pop_back())
		_bottom_lit.push_front(_bottom_lit.pop_back())
		_render_top_lanes()
		_render_bottom_lanes()

func _on_top_lane(index: int) -> void:
	if _skill_shot_left > 0.0:
		_skill_shot_left = 0.0
		_award(SKILL_SHOT_POINTS, _top_lamps[index].global_position + Vector2(0, -40))
	_award(TOP_LANE_POINTS, _top_lamps[index].global_position)
	_top_lit[index] = true
	_render_top_lanes()
	if not _top_lit.has(false):
		_top_lit = [false, false, false]
		_award(TOP_LANES_COMPLETE_POINTS, _top_lamps[1].global_position)
		PinballEvents.top_lanes_completed.emit()
		_upgrade_ball()
		_celebrate(_top_lamps, _render_top_lanes)

## One step up the ball upgrades (the top lanes, and the market sells one)
func upgrade_ball() -> void:
	_upgrade_ball()

func _upgrade_ball() -> void:
	_tier_left = UPGRADE_SECONDS
	if _tier == BALL_TIERS.size() - 1:
		_award(TOP_TIER_POINTS, _top_lamps[1].global_position + Vector2(0, -40))
		return
	_tier += 1
	_apply_tier()
	PinballEvents.billboard.emit(Billboard.BALL + _tier, "%s Ball x%d!" % BALL_TIERS[_tier])
	AudioSfx.play("upgrade")

func _apply_tier() -> void:
	GameManager.set_multiplier(BALL_TIERS[_tier][1])
	PinballEvents.ball_tier_changed.emit(_tier)

func _on_bottom_lane(index: int) -> void:
	_award(BOTTOM_LANE_POINTS, _bottom_lamps[index].global_position)
	_bottom_lit[index] = true
	_render_bottom_lanes()
	if not _bottom_lit.has(false):
		_bottom_lit = [false, false, false, false]
		_award(BOTTOM_LANES_COMPLETE_POINTS, Vector2(338, 1000))
		PinballEvents.bottom_lanes_completed.emit()
		temple.light_roulette()
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
	stir_tlaloc()

## One step toward Tlaloc's curse (a shot up through his face, or an offering at his shrine)
func stir_tlaloc() -> void:
	if GameManager.curse_active or _rest_left > 0.0:
		return
	_face_hits += 1
	if _face_hits >= _face_hits_needed():
		_start_curse()
	else:
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
	create_tween().tween_property(_storm_tint, "color", Lighting.STORM, 0.8)
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
	# Not while the ball is held (temple, kickback) or off in El Dorado; the curse's
	# multiball waits for it to be back in play
	var ball := balls[0] as RigidBody2D
	if ball.freeze or ball.stage_origin != Vector2.ZERO:
		if GameManager.curse_active:
			get_tree().create_timer(0.5).timeout.connect(_release_extra_ball)
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
	_rain.emitting = false
	create_tween().tween_property(_storm_tint, "color", Lighting.MOOD, 1.2)
	for torch in _torches:
		torch.speed_scale = 1.0
	if _face_sprite:
		_face_sprite.frame = 0

func _strike_lightning() -> void:
	if not GameManager.curse_active:
		return
	PinballEvents.rumble.emit(5.0)
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

## Tlaloc's eyes blaze for a moment (while the shrine holds an offering)
func _flash_shrine(seconds: float) -> void:
	_shrine_flash_left = seconds

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

# A real drain (no saver running) costs the ball one upgrade step
func _on_ball_drained() -> void:
	if GameManager.ball_save_left() > 0.0 or _tier == 0:
		return
	_tier -= 1
	_tier_left = UPGRADE_SECONDS
	_apply_tier()

# The bars under the flippers show the end-of-ball bonus multiplier
func _render_bonus_bars(value: int) -> void:
	for i in _bars.size():
		_bars[i].frame = 1 if i < value else 0

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
	_eyes_red_left = 0.45
	if not GameManager.curse_active:
		get_tree().create_timer(0.45).timeout.connect(func():
			if not GameManager.curse_active:
				_face_sprite.frame = 0)

# ---------- score popups ----------

const POPUP_MIN_POINTS := 5000  # smaller awards add to the score without a number floating up

func _spawn_popup(points: int, at: Vector2) -> void:
	if points < POPUP_MIN_POINTS:
		return  # the small stuff just adds to the score
	var label := Label.new()
	label.text = "+%d" % (points * GameManager.score_factor())
	label.add_theme_font_override("font", TempleTheme.BODY_FONT)
	label.add_theme_font_size_override("font_size", TempleTheme.snap(24))
	label.add_theme_color_override("font_color", TempleTheme.GOLD)
	label.add_theme_color_override("font_outline_color", TempleTheme.SHADOW)
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 6
	label.z_as_relative = false
	add_child(label)
	label.position = at - Vector2(30, 40)

	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
