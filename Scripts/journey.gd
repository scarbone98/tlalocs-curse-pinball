extends Node2D
## The journey to El Dorado, like Pokemon Pinball's map moves toward Mewtwo.
##
## Each city has a feat; doing it there earns that city's gold relic and moves the
## journey on to the next city still missing its relic. Two stone serpents sit in the
## side walls where the Digletts would be: hitting one three times before its pips
## fade opens the road, and the next shot into the temple hole takes it, skipping a
## feat you're stuck on. Progress at a city is kept if you leave. With all four relics lit, El Dorado opens at the temple hole. After a
## trip there the relics reset and the ramp feat gets longer.

const SERPENT := preload("res://Sprites/table/serpent.png")
const SERPENT_PIP := preload("res://Sprites/table/serpent_pip.png")
const RELICS := preload("res://Sprites/table/relics.png")

# Sloped wedges set into the side walls, so a ball rolls off rather than resting on
# top or tucking in beside them (the walls there run from y 868 to 949)
const LEFT_WEDGE := [Vector2(131, 868), Vector2(176, 892), Vector2(178, 915), Vector2(131, 945)]
const RIGHT_WEDGE := [Vector2(545, 864), Vector2(500, 889), Vector2(498, 912), Vector2(545, 942)]
const SENSOR_GROW := 8.0  # the hit sensor reaches this far past the wedge
const SERPENT_ART := [Vector2(52, 300), Vector2(186, 299)]  # table-art pixels
const PIP_ART_OFFSET := [Vector2(4, -14), Vector2(-4, -14)]  # three pips above each head
const RELIC_ART := [Vector2(98.5, 197.5), Vector2(112.5, 193.5), Vector2(126.5, 193.5), Vector2(140.5, 197.5)]

const HITS_TO_TRAVEL := 3
const PIP_FADE_SECONDS := 10.0  # like a Diglett's count, the pips go out if you stop hitting
const HIT_COOLDOWN := 1.0  # one rattle against a serpent counts once
const HIT_POINTS := 750
const HIT_PUSH := 350.0
const TRAVEL_POINTS := 2500
const RELIC_POINTS := 10000

const CITIES := [
	{"name": "Tenochtitlan", "goal": "Make %d ramps", "feat": "ramps", "need": 3},
	{"name": "Teotihuacan", "goal": "Catch %d water spirit", "feat": "spirit", "need": 1},
	{"name": "Chichen Itza", "goal": "Wake Tlaloc's curse", "feat": "curse", "need": 1},
	{"name": "Palenque", "goal": "Light all top lanes", "feat": "lanes", "need": 1},
]

enum { SERPENT_IDLE, SERPENT_HIT }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var city := 0
var relics := [false, false, false, false]
var el_dorado_open := false
var road_open := false  # a serpent's pips are full; the temple hole travels instead of spinning
var trips := 0  # visits to El Dorado; each one makes the ramp feat longer

var _progress := [0, 0, 0, 0]
var _hits := [0, 0]
var _since_hit := [0.0, 0.0]
var _cooldown := [0.0, 0.0]
var _serpents: Array[AnimatedSprite2D] = []
var _pips: Array = [[], []]
var _relic_lamps: Array[AnimatedSprite2D] = []
var _clock := 0.0

func _ready() -> void:
	_build_serpent(0, LEFT_WEDGE, Vector2.RIGHT)
	_build_serpent(1, RIGHT_WEDGE, Vector2.LEFT)
	for i in RELIC_ART.size():
		_relic_lamps.append(features._sprite(RELICS, 8, RELIC_ART[i] * features.MAP_SCALE))
	PinballEvents.ramp_made.connect(func(_side, _combo): _feat_done("ramps"))
	PinballEvents.spirit_caught.connect(func(): _feat_done("spirit"))
	PinballEvents.curse_changed.connect(func(active): if active: _feat_done("curse"))
	PinballEvents.top_lanes_completed.connect(func(): _feat_done("lanes"))
	_render()
	_announce_goal.call_deferred()

func _build_serpent(side: int, wedge: Array, facing: Vector2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionPolygon2D.new()
	shape.polygon = PackedVector2Array(wedge)
	body.add_child(shape)
	add_child(body)

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
	var head: AnimatedSprite2D = features._sprite(SERPENT, 3, art * features.MAP_SCALE)
	head.flip_h = side == 1
	_serpents.append(head)
	for i in HITS_TO_TRAVEL:
		var at: Vector2 = art + PIP_ART_OFFSET[side] + Vector2((i - 1) * 5 * facing.x, 0)
		_pips[side].append(features._sprite(SERPENT_PIP, 2, at * features.MAP_SCALE))

func _physics_process(delta: float) -> void:
	_clock += delta
	for side in 2:
		_cooldown[side] = maxf(_cooldown[side] - delta, 0.0)
		_since_hit[side] += delta
		if _hits[side] > 0 and not road_open and _since_hit[side] >= PIP_FADE_SECONDS:
			_hits[side] = 0
			_render()
	# The next relic to earn blinks; a lit El Dorado makes all four shimmer
	for i in _relic_lamps.size():
		var lit: bool = relics[i]
		if el_dorado_open:
			lit = int(_clock * 6.0 + i) % 3 != 0
		elif i == city and not relics[i]:
			lit = int(_clock * 3.0) % 2 == 0
		_relic_lamps[i].frame = i + (4 if lit else 0)
	if road_open:
		var flash := int(_clock * 6.0) % 2
		for side in 2:
			for pip in _pips[side]:
				pip.frame = flash

func _on_serpent_hit(body: Node, side: int, facing: Vector2) -> void:
	if _cooldown[side] > 0.0 or not features._is_ball_on_playfield(body):
		return
	_cooldown[side] = HIT_COOLDOWN
	var ball := body as RigidBody2D
	ball.linear_velocity += facing * HIT_PUSH
	features._award(HIT_POINTS, _serpents[side].global_position)
	AudioSfx.play("bumper")
	PinballEvents.effect.emit("sparks", ball.global_position - facing * 20.0)
	PinballEvents.rumble.emit(5.0)
	_serpents[side].frame = SERPENT_HIT
	get_tree().create_timer(0.25).timeout.connect(func(): _serpents[side].frame = SERPENT_IDLE)
	if road_open or el_dorado_open:
		return
	_hits[side] += 1
	_since_hit[side] = 0.0
	if _hits[side] >= HITS_TO_TRAVEL:
		road_open = true
		PinballEvents.toast.emit("Road open!")
		_announce_goal()
	_render()

## Moves on to the next city still missing its relic (a finished feat, the serpents and
## the temple's roulette all call this). Nowhere left to go once all four are found.
func travel() -> void:
	road_open = false
	_hits = [0, 0]
	_render()
	if not relics.has(false):
		_announce_goal()
		return
	city = (city + 1) % CITIES.size()
	while relics[city]:
		city = (city + 1) % CITIES.size()
	features._award(TRAVEL_POINTS, _serpents[0].global_position.lerp(_serpents[1].global_position, 0.5))
	PinballEvents.toast.emit("Travel to %s!" % CITIES[city].name)
	AudioSfx.play("ramp")
	_announce_goal()

func _feat_done(feat: String) -> void:
	if el_dorado_open or relics[city] or CITIES[city].feat != feat:
		return
	_progress[city] += 1
	if _progress[city] < _need():
		_announce_goal()
		return
	relics[city] = true
	features._award(RELIC_POINTS, _relic_lamps[city].global_position)
	PinballEvents.effect.emit("gold", _relic_lamps[city].global_position)
	PinballEvents.rumble.emit(4.0)
	PinballEvents.toast.emit("Relic of %s!" % CITIES[city].name)
	AudioSfx.play("catch")
	if not relics.has(false):
		el_dorado_open = true
		features.temple.set_gate_open(true)
		get_tree().create_timer(1.6).timeout.connect(func(): PinballEvents.toast.emit("El Dorado awakens!"))
		_announce_goal()
		return
	get_tree().create_timer(1.6).timeout.connect(travel)

## Called by the bonus stage when a trip to El Dorado ends, won or not
func el_dorado_finished() -> void:
	trips += 1
	relics = [false, false, false, false]
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
		text = "El Dorado is open! Shoot the temple"
	elif road_open:
		text = "Road open! Shoot the temple to travel"
	else:
		var goal: String = CITIES[city].goal
		if goal.contains("%d"):
			goal = goal % _need()
		if _need() > 1:
			goal += " (%d/%d)" % [_progress[city], _need()]
		text = "%s: %s" % [CITIES[city].name, goal]
	PinballEvents.objective_changed.emit(text)

func _render() -> void:
	for side in 2:
		for i in _pips[side].size():
			_pips[side][i].frame = 1 if i < _hits[side] else 0
