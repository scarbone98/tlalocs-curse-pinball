extends Node2D
## The Awakening, like Pokemon Pinball Ruby & Sapphire's Evolution mode. Three Awaken
## arrows on the left ramp light it in the jaguar's den (the temple's roulette can
## award it too); the next shot into the den starts it for one of your caught spirits.
## Three sacred offerings then appear one after another on the open floor; roll over
## all three, then shoot the temple to finish, before the two minutes run out, and the
## spirit awakens into its divine form, recorded in the Spirit Codex. It comes with a
## ball saver, and an Awakening lights two bonus lamps.

const OFFERING := preload("res://Sprites/table/offering.png")

# Open floor the ball crosses often, clear of walls (checked against the colliders)
const SPOTS := [
	Vector2(250, 690), Vector2(430, 700), Vector2(400, 720), Vector2(200, 960), Vector2(475, 960),
	Vector2(260, 780), Vector2(420, 790), Vector2(520, 800),
]
const OFFERINGS := 3
const SECONDS := 120.0
const SAVER := 60.0
const BONUS_LAMPS := 2
const PICK_RADIUS := 18.0
const OFFERING_POINTS := 5000
const AWAKEN_POINTS := 50000
const RARE_MULTIPLIER := 2

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var lit := false       # lit in the jaguar's den, waiting for a shot
var active := false
var finishing := false # all three offerings found; the temple finishes it

var _species := 0
var _collected := 0
var _time_left := 0.0
var _last_spot := -1
var _offering: Area2D
var _offering_sprite: AnimatedSprite2D
var _shown_seconds := -1

func _ready() -> void:
	_offering = Area2D.new()
	_offering.monitorable = false
	_offering.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICK_RADIUS
	shape.shape = circle
	_offering.add_child(shape)
	_offering.body_entered.connect(_on_offering)
	add_child(_offering)
	_offering_sprite = features._sprite(OFFERING, 2, Vector2.ZERO, 4.0)
	_offering_sprite.reparent(_offering, false)
	_offering_sprite.play()
	_offering.hide()


## Three Awaken arrows light it in the jaguar's den
func light() -> void:
	if lit or active or SpiritCodex.awakenable().is_empty():
		return
	lit = true

## Starts the Awakening for one of the caught spirits. False if none is waiting to awaken.
func start() -> bool:
	var waiting := SpiritCodex.awakenable()
	if active or waiting.is_empty():
		return false
	lit = false
	active = true
	finishing = false
	features.ramps.clear_arrows("awaken")
	_species = waiting[randi() % waiting.size()]
	_collected = 0
	_time_left = SECONDS
	PinballEvents.banner.emit("Awaken the %s!" % SpiritCodex.SPECIES[_species].name, Billboard.SPIRIT + _species)
	GameManager.grant_ball_save(SAVER)
	PinballEvents.awakening_changed.emit(true)
	PinballEvents.mode_changed.emit()
	AudioSfx.play("spirit")
	_place_offering()
	return true

func _physics_process(delta: float) -> void:
	if not active:
		return
	_time_left -= delta
	if ceili(_time_left) != _shown_seconds:
		_shown_seconds = ceili(_time_left)
		_show_progress()
	if _time_left <= 0.0:
		_end()

func _place_offering() -> void:
	var spot := randi() % SPOTS.size()
	while spot == _last_spot:
		spot = randi() % SPOTS.size()
	_last_spot = spot
	_offering.position = SPOTS[spot]
	_offering.show()
	_offering.set_deferred("monitoring", true)
	PinballEvents.effect.emit("sparks", SPOTS[spot])

func _on_offering(body: Node) -> void:
	if not active or not features._is_ball_on_playfield(body):
		return
	_collected += 1
	features._award(OFFERING_POINTS, _offering.position)
	PinballEvents.effect.emit("gold", _offering.position)
	AudioSfx.play("charge", 0.0, Vector2.ONE * (1.0 + 0.15 * _collected))
	_offering.set_deferred("monitoring", false)
	_offering.hide()
	if _collected < OFFERINGS:
		_show_progress()
		_place_offering.call_deferred()
		return
	finishing = true
	PinballEvents.toast.emit("Shoot Tlaloc's mouth!")
	_show_progress()

## The temple caught the ball with all three offerings found: the spirit awakens
func finish() -> void:
	if not finishing:
		return
	var spirit: Dictionary = SpiritCodex.SPECIES[_species]
	SpiritCodex.awaken(_species)
	features._award(AWAKEN_POINTS * (RARE_MULTIPLIER if spirit.rare else 1), _offering.position + Vector2(0, -40))
	PinballEvents.billboard.emit(Billboard.DIVINE + _species, "%s awakens: %s!" % [spirit.name, spirit.divine])
	PinballEvents.rumble.emit(6.0)
	AudioSfx.play("catch")
	GameManager.add_bonus_lamps(BONUS_LAMPS)
	PinballEvents.awakened.emit()
	_end()

func _end() -> void:
	active = false
	finishing = false
	_offering.set_deferred("monitoring", false)
	_offering.hide()
	PinballEvents.awakening_changed.emit(false)
	PinballEvents.mode_changed.emit()
	features.journey._announce_goal()

func _show_progress() -> void:
	var left := maxi(ceili(_time_left), 0)
	var goal := "shoot Tlaloc's mouth!" if finishing else "offerings %d/%d" % [_collected, OFFERINGS]
	PinballEvents.objective_changed.emit("Awaken the %s: %s   %d:%02d" % [
		SpiritCodex.SPECIES[_species].name, goal, left / 60, left % 60])
