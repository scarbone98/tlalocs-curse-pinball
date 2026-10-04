extends Node2D
## The journey to El Dorado, like Pokemon Pinball's map moves toward Mewtwo.
##
## Each city has a feat; doing it there earns that city's gold relic and moves the
## journey on to the next city still missing its relic. Two jaguars (the hand-drawn
## jaguar) lurk in slots in the side walls with only their snouts showing. Hitting the
## gold button at the foot of the crystal skull's lane brings them out for a while, as
## Chikorita wakes the Linoone on Pokemon Pinball Ruby's field; while they're out, each
## hit on one drops a carved head onto the totem by the left one (Scripts/totem.gd), as
## each hit on a Linoone brings a Gulpin; three heads and Travel mode starts, like Ruby &
## Sapphire's. For a minute (with a ball saver) shoot the right
## rail to head for the next city or the left (harder to reach) to skip one, then sink the temple
## hole to arrive. Progress at a city is kept if you leave. With all four relics lit, El Dorado opens at the temple hole. After a
## trip there the relics reset and the ramp feat gets longer.

const SERPENT := preload("res://Sprites/table/wall_jaguar.png")  # the hand-drawn jaguar (tools/make_table.py)

# Sloped wedges set into the side walls, so a ball rolls off rather than resting on
# top or tucking in beside them (the walls there run from y 868 to 949)
const LEFT_WEDGE := [Vector2(131, 868), Vector2(176, 892), Vector2(178, 915), Vector2(131, 945)]
const RIGHT_WEDGE := [Vector2(545, 864), Vector2(500, 889), Vector2(498, 912), Vector2(545, 942)]
const SENSOR_GROW := 8.0  # the hit sensor reaches this far past the wedge
const SERPENT_ART := [Vector2(52, 300), Vector2(186, 299)]  # table-art pixels
# The jaguars' slots in the walls (tools/make_table.py paints them) and how much of a
# head shows: its snout while it lurks, nearly all of it once it's out
const SLOT_X_ART := [47.0, 193.0]
const HEAD_SIZE := Vector2(20, 24)  # one frame of Sprites/table/wall_jaguar.png
const PEEK := 5.0
const OUT := 17.0
const EMERGE_PER_SECOND := 40.0  # art pixels a second as a head slides out or back
# The gold button that wakes them, at the foot of the skull's lane (scene units)
const BUTTON_AT := Vector2(441.6, 640)  # the gold button at the foot of the skull's lane
const BUTTON_REACH := 20.0  # a knock into the wall this near it presses it
const OUT_SECONDS := 10.0  # not long, so they aren't forever in the way of shots up the rails
# Now and then they come out by themselves for a while: usually just one, sometimes both
const PROWL_EVERY := Vector2(25.0, 50.0)
const PROWL_SECONDS := 8.0
const PROWL_BOTH := 0.3
const STUNG_SECONDS := 12.0  # a jaguar hit by a poison dart (Scripts/dart_trap.gd) hides in its hole this long
const BUTTON_POINTS := 1000
const ROAR_SECONDS := 0.6  # the heads roar at the button's press
const LURK_POINTS := 100  # a hit on a head still in its slot
enum { HEAD_WATCHING, HEAD_ROARING, HEAD_BLINKING }
# Two each side of the temple hole, like an arch over it
const RELIC_AT := Vector2(339, 700)  # where a relic's points pop up, over Tlaloc
const RELICS := preload("res://Sprites/table/relics.png")  # tools/make_journey_sprites.py: 4 dark, then 4 lit
# The four relic idols in an arch over Tlaloc's face, lit as each is won (scene units)
const RELIC_ARCH := [Vector2(238, 729), Vector2(300, 683), Vector2(378, 683), Vector2(440, 729)]

const Totem := preload("res://Scripts/totem.gd")
# The road's two ways, inlaid in the floor at the foot of each rail's lane, pointing up it
# (tools/make_table.py: dark, lit): they light, flashing turn about, while a way's to be picked
const ROAD_ARROWS := {
	"left": [preload("res://Sprites/table/road_arrow_left.png"), Vector2(186, 648)],
	"right": [preload("res://Sprites/table/road_arrow_right.png"), Vector2(506, 736)],
}
const ROAD_FLASH := 3.0  # flashes a second
const HIT_COOLDOWN := 1.0  # one rattle against a head counts once
const HIT_POINTS := 750
const HIT_KICK := 900.0  # a jaguar that's out knocks the ball back, like a bumper
const RECOIL := 8.0      # art pixels a struck jaguar is knocked back into its slot
const BREATH_SECONDS := 1.8  # idle: a head eases a pixel out of its slot and back as it breathes
const CLAW := preload("res://Sprites/table/claw_swipe.png")  # tools/make_table.py
const CLAW_REACH := 26.0     # scene units in front of the slot the swipe rakes
const SNEAK := 10.0      # how far a lurking jaguar sneaks out now and then
const SNEAK_EVERY := Vector2(4.0, 9.0)
const SNEAK_SECONDS := 1.4
const TRAVEL_POINTS := 12500
const TRAVEL_SECONDS := 60.0
const TRAVEL_SAVER := 30.0
const TRAVEL_REST := 30.0  # after a trip a full totem won't start another for a while
const RELIC_POINTS := 10000

const CITIES := [
	{"name": "Tenochtitlan", "goal": "Make %d ramps", "feat": "ramps", "need": 3},
	{"name": "Teotihuacan", "goal": "Catch a spirit", "feat": "spirit", "need": 1},
	{"name": "Chichen Itza", "goal": "Wake Tlaloc's curse", "feat": "curse", "need": 1},
	{"name": "Palenque", "goal": "Light all top lanes", "feat": "lanes", "need": 1},
]


var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var city := 0
var relics := [false, false, false, false]
var el_dorado_open := false
var road_open := false  # the totem's full: Travel mode is on
var traveling := false  # Travel mode: pick a way with a ramp, then the temple hole
var travel_steps := 0   # 1 the next city (right rail), 2 skip one (left rail, the harder shot); 0 not yet picked
var _travel_left := 0.0
var _rest_left := 0.0
var trips := 0  # visits to El Dorado; each one makes the ramp feat longer

var _progress := [0, 0, 0, 0]
var _totem: Node2D
var _road_arrows := {}  # side -> Sprite2D
var _cooldown := [0.0, 0.0]
var _serpents: Array[Sprite2D] = []
var _wedges: Array[CollisionPolygon2D] = []
var _head_frame := [HEAD_WATCHING, HEAD_WATCHING]
var _shown := [PEEK, PEEK]
var _relic_lamps: Array[AnimatedSprite2D] = []
var _prowl_left := [0.0, 0.0]  # out on its own
var _prowl_wait := 30.0
var _stung_left := [0.0, 0.0]  # hiding in its hole after a dart
var _breath := [0.0, 0.0]
var _claws: Array[AnimatedSprite2D] = []
var _out_left := 0.0
var _button_cooldown := 0.0
var _button_sprite: AnimatedSprite2D
var _pressed_left := 0.0
const PRESSED_SECONDS := 0.35  # the gold button stays sunk this long, then glows while the jaguars are out
var _blink_left := 3.0
var _sneak_left := [0.0, 0.0]
var _sneak_wait := [5.0, 7.0]
var _clock := 0.0

func _ready() -> void:
	_totem = Totem.new()
	_totem.features = features
	add_child(_totem)
	for side: String in ROAD_ARROWS:
		var arrow := Sprite2D.new()
		arrow.texture = ROAD_ARROWS[side][0]
		arrow.hframes = 2
		arrow.scale = features.MAP_SCALE
		arrow.position = ROAD_ARROWS[side][1]
		features.add_child(arrow)
		_road_arrows[side] = arrow
	_build_serpent(0, LEFT_WEDGE, Vector2.RIGHT)
	_build_serpent(1, RIGHT_WEDGE, Vector2.LEFT)
	# pressed only by a ball knocked into it, not one passing it on the way up the lane
	PinballEvents.ball_struck.connect(func(ball: RigidBody2D, at: Vector2, _into: float):
		if at.distance_to(BUTTON_AT) < BUTTON_REACH:
			_on_button(ball))
	_button_sprite = features.gold_button("skull_button")
	for side in 2:
		var claw: AnimatedSprite2D = features._sprite(CLAW, 3, Vector2.ZERO, 16.0)
		claw.flip_h = side == 1
		claw.sprite_frames.set_animation_loop("default", false)
		claw.animation_finished.connect(claw.hide)
		claw.z_index = 2
		claw.z_as_relative = false
		claw.hide()
		_claws.append(claw)
	for at in RELIC_ARCH:
		_relic_lamps.append(features._sprite(RELICS, 8, at))
	_render_relics()
	PinballEvents.ramp_made.connect(func(side, _combo):
		_feat_done("ramps")
		_pick_way(side))
	PinballEvents.spirit_caught.connect(func(): _feat_done("spirit"))
	PinballEvents.curse_changed.connect(func(active): if active: _feat_done("curse"))
	PinballEvents.top_lanes_completed.connect(func(): _feat_done("lanes"))
	_announce_goal.call_deferred()
	# The first launch shows where the journey starts, behind the roulette's doors under Tlaloc
	PinballEvents.ball_launched.connect(func():
		features.roulette.show_city(city, "The journey begins: %s" % CITIES[city].name), CONNECT_ONE_SHOT)

func _build_serpent(side: int, wedge: Array, facing: Vector2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array(wedge)
	shape.disabled = true  # only there while the head is out of its slot
	body.add_child(shape)
	add_child(body)
	_wedges.append(shape)

	var centre := Vector2.ZERO
	for p in wedge:
		centre += p / wedge.size()
	var grown := PackedVector2Array()
	for p in wedge:
		grown.append(p + (p - centre).normalized() * SENSOR_GROW)
	var sensor := Area2D.new()
	sensor.monitorable = false
	var sensor_shape := CollisionPolygon2D.new()
	sensor_shape.polygon = grown
	sensor.add_child(sensor_shape)
	sensor.body_entered.connect(_on_serpent_hit.bind(side, facing))
	add_child(sensor)

	var art: Vector2 = SERPENT_ART[side]
	var head := Sprite2D.new()
	head.texture = SERPENT
	head.region_enabled = true
	head.scale = features.MAP_SCALE
	head.flip_h = side == 1
	features.add_child(head)
	_serpents.append(head)
	_render_head(side)

# Only the part of a head that's out of its slot shows: the frame is cropped to the
# columns nearest the snout, and set against the slot
func _render_head(side: int) -> void:
	var head := _serpents[side]
	var shown := clampf(roundf(_shown[side]) + _breath[side], 0.0, HEAD_SIZE.x)
	head.region_rect = Rect2(_head_frame[side] * HEAD_SIZE.x + HEAD_SIZE.x - shown, 0, shown, HEAD_SIZE.y)
	var x: float = SLOT_X_ART[side] + (shown / 2.0 if side == 0 else -shown / 2.0)
	head.position = Vector2(x, SERPENT_ART[side].y) * features.MAP_SCALE

# The jaguar rakes its claws at the ball as it knocks it away
func _swipe(side: int, at: Vector2) -> void:
	var claw := _claws[side]
	claw.position = Vector2(_serpents[side].global_position.x + (CLAW_REACH if side == 0 else -CLAW_REACH), at.y)
	claw.show()
	claw.frame = 0
	claw.play()

func _head_out(side: int) -> bool:
	return _shown[side] >= OUT - 0.5

## The jaguars a dart could hit: out of their holes (side -> where its head is)
func targets() -> Dictionary:
	var out := {}
	for side in 2:
		if _head_out(side) and _stung_left[side] <= 0.0:
			out[side] = _serpents[side].global_position
	return out

## Hit by a poison dart: it ducks back into its hole and stays there a while
func sting(side: int) -> void:
	_stung_left[side] = STUNG_SECONDS
	_prowl_left[side] = 0.0
	_head_frame[side] = HEAD_ROARING
	get_tree().create_timer(0.4).timeout.connect(func():
		_head_frame[side] = HEAD_WATCHING
		_render_head(side))
	AudioSfx.play("roar", 0.0, Vector2.ONE * 1.3)

func _on_button(body: Node) -> void:
	if _button_cooldown > 0.0 or not features._is_ball_on_playfield(body):
		return
	_button_cooldown = 1.0
	_pressed_left = PRESSED_SECONDS
	features._award(BUTTON_POINTS, BUTTON_AT)
	PinballEvents.effect.emit("sparks", BUTTON_AT)
	AudioSfx.play("roar", 0.0, Vector2(0.9, 1.1))  # the jaguars answer it
	for side in 2:
		if _stung_left[side] > 0.0:
			continue
		_head_frame[side] = HEAD_ROARING
		_render_head(side)
		get_tree().create_timer(ROAR_SECONDS).timeout.connect(func():
			if _head_frame[side] == HEAD_ROARING:
				_head_frame[side] = HEAD_WATCHING
				_render_head(side))
	_out_left = OUT_SECONDS

func _physics_process(delta: float) -> void:
	_clock += delta
	_pressed_left = maxf(_pressed_left - delta, 0.0)
	features.show_gold_button(_button_sprite, _pressed_left, _out_left > 0.0)
	_button_cooldown = maxf(_button_cooldown - delta, 0.0)
	if _out_left > 0.0:
		_out_left -= delta
	_blink_left -= delta
	_prowl_wait -= delta
	if _prowl_wait <= 0.0:
		_prowl_wait = randf_range(PROWL_EVERY.x, PROWL_EVERY.y)
		if randf() < PROWL_BOTH:
			_prowl_left = [PROWL_SECONDS, PROWL_SECONDS]
		else:
			_prowl_left[randi() % 2] = PROWL_SECONDS
	for side in 2:
		var breath := 1.0 if fposmod(_clock / BREATH_SECONDS + side * 0.5, 1.0) < 0.5 else 0.0
		if breath != _breath[side]:
			_breath[side] = breath
			_render_head(side)
	for side in 2:
		_sneak_wait[side] -= delta
		_sneak_left[side] = maxf(_sneak_left[side] - delta, 0.0)
		if _sneak_wait[side] <= 0.0:
			_sneak_wait[side] = randf_range(SNEAK_EVERY.x, SNEAK_EVERY.y)
			_sneak_left[side] = SNEAK_SECONDS
		_prowl_left[side] = maxf(_prowl_left[side] - delta, 0.0)
		_stung_left[side] = maxf(_stung_left[side] - delta, 0.0)
		var want := OUT if _out_left > 0.0 or _prowl_left[side] > 0.0 else (SNEAK if _sneak_left[side] > 0.0 else PEEK)
		if _stung_left[side] > 0.0:
			want = 0.0  # hiding right down in its hole
		var before := roundf(_shown[side])
		_shown[side] = move_toward(_shown[side], want, EMERGE_PER_SECOND * delta)
		var out := _head_out(side)
		if _wedges[side].disabled == out:
			_wedges[side].set_deferred("disabled", not out)
		if _blink_left <= 0.0 and _head_frame[side] == HEAD_WATCHING:
			_head_frame[side] = HEAD_BLINKING
			get_tree().create_timer(0.15).timeout.connect(func():
				if _head_frame[side] == HEAD_BLINKING:
					_head_frame[side] = HEAD_WATCHING
					_render_head(side))
		if roundf(_shown[side]) != before or _blink_left <= 0.0:
			_render_head(side)
	if _blink_left <= 0.0:
		_blink_left = randf_range(2.5, 6.0)
	for side in 2:
		_cooldown[side] = maxf(_cooldown[side] - delta, 0.0)
	_rest_left = maxf(_rest_left - delta, 0.0)
	# the road's ways light up while one's to be picked, flashing turn about
	var choosing := traveling and travel_steps == 0
	var flash := int(_clock * ROAD_FLASH) % 2
	(_road_arrows["left"] as Sprite2D).frame = 1 if choosing and flash == 0 else 0
	(_road_arrows["right"] as Sprite2D).frame = 1 if choosing and flash == 1 else 0
	# a full totem opens the road as soon as nothing else is going on
	if _totem.full() and not road_open and not el_dorado_open and _rest_left <= 0.0 			and not features.mode_running():
		_start_travel()
	if traveling:
		_travel_left -= delta
		if ceili(_travel_left) != ceili(_travel_left + delta):
			_announce_goal()
		if _travel_left <= 0.0:
			_end_travel()

func _on_serpent_hit(body: Node, side: int, facing: Vector2) -> void:
	if _cooldown[side] > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown[side] = HIT_COOLDOWN
	var was_out := _head_out(side)
	# struck, it's knocked back into its slot, then slides out again
	_shown[side] = maxf(_shown[side] - RECOIL, 0.0)
	_render_head(side)
	if not was_out:
		features._award(LURK_POINTS, _serpents[side].global_position)
		return  # still in its slot: the button brings it out
	var ball := body as RigidBody2D
	ball.linear_velocity = ball.linear_velocity * 0.2 + facing.rotated(randf_range(-0.3, 0.3)) * HIT_KICK
	_swipe(side, ball.global_position)
	features._award(HIT_POINTS, _serpents[side].global_position)
	AudioSfx.play("bumper")
	PinballEvents.effect.emit("sparks", ball.global_position - facing * 20.0)
	PinballEvents.rumble.emit(5.0)
	_head_frame[side] = HEAD_ROARING
	_render_head(side)
	get_tree().create_timer(0.25).timeout.connect(func():
		_head_frame[side] = HEAD_WATCHING
		_render_head(side))
	if road_open or el_dorado_open:
		return
	_totem.add_head()  # (the road opens once it's full: _physics_process)

func _start_travel() -> void:
	road_open = true
	traveling = true
	travel_steps = 0
	_travel_left = TRAVEL_SECONDS
	_totem.lit = true
	AudioSfx.play("roar", 0.0, Vector2(0.9, 1.1))
	GameManager.grant_ball_save(TRAVEL_SAVER)
	PinballEvents.mode_changed.emit()
	_announce_goal()

func _pick_way(side: String) -> void:
	if not traveling:
		return
	travel_steps = 2 if side == "left" else 1  # the left rail, the harder shot, skips one; his mouth opens on its whirl: the way's open
	_announce_goal()

## The temple hole caught the ball during Travel mode with a way picked
func arrive() -> void:
	if not traveling or travel_steps == 0:
		return
	var steps := travel_steps
	_end_travel()
	for i in steps:
		travel(i == steps - 1)

func _end_travel() -> void:
	_rest_left = TRAVEL_REST
	traveling = false
	road_open = false
	travel_steps = 0
	_totem.crumble()
	PinballEvents.mode_changed.emit()
	_announce_goal()

## Moves on to the next city still missing its relic (a finished feat, Travel mode and
## the temple's roulette all call this). Nowhere left to go once all four are found.
func travel(announce := true) -> void:
	road_open = false
	if not relics.has(false):
		_announce_goal()
		return
	city = (city + 1) % CITIES.size()
	while relics[city]:
		city = (city + 1) % CITIES.size()
	if not announce:
		return  # a city passed through on the way
	features._award(TRAVEL_POINTS, _serpents[0].global_position.lerp(_serpents[1].global_position, 0.5))
	features.roulette.spin_to_city(city, "Travel to %s!" % CITIES[city].name)  # on the floor under Tlaloc
	AudioSfx.play("ramp")
	PinballEvents.traveled.emit()
	_announce_goal()

func _feat_done(feat: String) -> void:
	if el_dorado_open or relics[city] or CITIES[city].feat != feat:
		return
	_progress[city] += 1
	if _progress[city] < _need():
		_announce_goal()
		return
	relics[city] = true
	_render_relics()
	features._award(RELIC_POINTS, _relic_lamps[city].global_position)
	PinballEvents.effect.emit("gold", RELIC_AT)
	PinballEvents.rumble.emit(4.0)
	PinballEvents.billboard.emit(Billboard.RELIC + city, "Relic of %s!" % CITIES[city].name)
	AudioSfx.play("catch")
	if not relics.has(false):
		el_dorado_open = true
		features.temple.set_gate_open(true)
		get_tree().create_timer(2.8).timeout.connect(func(): PinballEvents.billboard.emit(Billboard.EL_DORADO, "El Dorado awakens!"))
		_announce_goal()
		return
	get_tree().create_timer(1.6).timeout.connect(travel)

## Called by the bonus stage when a trip to El Dorado ends, won or not
func el_dorado_finished() -> void:
	trips += 1
	relics = [false, false, false, false]
	_render_relics()
	el_dorado_open = false
	_progress = [0, 0, 0, 0]
	features.temple.set_gate_open(false)
	_announce_goal()

func _need() -> int:
	var need: int = CITIES[city].need
	return need + trips if CITIES[city].feat == "ramps" else need

func _announce_goal() -> void:
	var text: String
	if el_dorado_open:
		text = "El Dorado is open!"
	elif traveling:
		var left := maxi(ceili(_travel_left), 0)
		var way := "the portal is open" if travel_steps > 0 else "right rail: next city, left: skip one"
		text = "Travel: %s   %d:%02d" % [way, left / 60, left % 60]
	else:
		var goal: String = CITIES[city].goal
		if goal.contains("%d"):
			goal = goal % _need()
		if _need() > 1:
			goal += " (%d/%d)" % [_progress[city], _need()]
		text = "%s: %s" % [CITIES[city].name, goal]
	PinballEvents.objective_changed.emit(text)

func _render_relics() -> void:
	for i in _relic_lamps.size():
		_relic_lamps[i].frame = i + (4 if relics[i] else 0)

