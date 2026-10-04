extends Node2D
## Hit effects: short bursts of chunky pixel particles wherever something gets hit,
## sent over the event bus (PinballEvents.effect) so any part of the table can ask
## for one. Strong rumbles also buzz the phone, where the browser allows it.
##
##   splash  water off the kickback
##   spores  a puff off a mushroom bumper
##   sparks  gold off the slingshots, serpents, coins and the Gilded King
##   dust    stone off a wall the ball slams into
##   gold    a shower of gold for a relic or the El Dorado jackpot
##   fire    sparks flying up off a torch as it catches
##   lava    molten drops thrown up as a ball plops into the lava
##   smoke   a slow grey puff rising off the lava
##   smoke_trail  wisps of smoke streaming up off a ball sinking into the lava, a while

const VIBRATE_FROM := 6.0  # only the big moments (kickback, the King, the jackpot) buzz the phone
const VIBRATE_MS_PER_STRENGTH := 6

# kind -> [amount, lifetime, speed range, gravity, colors from bright to faded]
const KINDS := {
	"splash": [12, 0.4, Vector2(140, 300), 500.0, [Color("#e6fbff"), Color("#8be6ee"), Color(0.1, 0.53, 0.64, 0.0)]],
	"spores": [12, 0.45, Vector2(90, 220), 120.0, [Color("#f8f8f8"), Color("#f040c8"), Color(0.55, 0.25, 0.75, 0.0)]],
	"sparks": [10, 0.3, Vector2(200, 380), 200.0, [Color("#fffbd6"), Color("#f8d000"), Color(0.97, 0.63, 0.03, 0.0)]],
	"dust": [6, 0.3, Vector2(60, 140), 0.0, [Color("#b4c4cc"), Color("#748c9a"), Color(0.34, 0.43, 0.47, 0.0)]],
	"gold": [32, 0.7, Vector2(160, 420), 380.0, [Color("#fffbd6"), Color("#f8d000"), Color(0.75, 0.54, 0.06, 0.0)]],
	"fire": [14, 0.5, Vector2(60, 180), -260.0, [Color("#fffbd6"), Color("#f8a008"), Color(0.75, 0.34, 0.18, 0.0)]],
	"lava": [18, 0.6, Vector2(120, 300), 700.0, [Color("#fff0a0"), Color("#f86010"), Color(0.6, 0.08, 0.02, 0.0)]],
	"poison": [12, 0.7, Vector2(30, 110), -30.0, [Color("#c8ffb0"), Color("#40d040"), Color(0.1, 0.45, 0.1, 0.0)]],
	"smoke": [10, 1.4, Vector2(10, 40), -45.0, [Color(0.55, 0.52, 0.5, 0.8), Color(0.35, 0.33, 0.33, 0.55), Color(0.2, 0.2, 0.2, 0.0)]],
}

# The everyday hits don't burst every time - only now and then, and not too close together
# (kind -> chance a hit shows one); the big moments (gold, fire, lava...) always do
const SOMETIMES := {"sparks": 0.35, "dust": 0.3, "spores": 0.4, "poison": 0.6}
const SOMETIMES_GAP := 0.2  # seconds between two bursts of one of those kinds

var _pixel: ImageTexture
var _last := {}  # kind -> when it last burst (seconds)

func _ready() -> void:
	# One table-art pixel (3x3 on screen), so the bursts sit on the pixel grid's scale
	var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(image)
	PinballEvents.effect.connect(_burst)
	PinballEvents.rumble.connect(_buzz)

func _burst(kind: String, at: Vector2) -> void:
	if kind == "smoke_trail":
		_smoke_trail(at)
		return
	if not KINDS.has(kind):
		return
	if SOMETIMES.has(kind):
		var now := Time.get_ticks_msec() / 1000.0
		if randf() > SOMETIMES[kind] or now - float(_last.get(kind, -10.0)) < SOMETIMES_GAP:
			return
		_last[kind] = now
	var spec: Array = KINDS[kind]
	var particles := CPUParticles2D.new()
	particles.texture = _pixel
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = spec[0]
	particles.lifetime = spec[1]
	particles.spread = 180.0
	particles.initial_velocity_min = spec[2].x
	particles.initial_velocity_max = spec[2].y
	particles.gravity = Vector2(0, spec[3])
	particles.scale_amount_min = 1.0  # one table-art pixel, never resized
	particles.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	fade.colors = PackedColorArray(spec[4])
	particles.color_ramp = fade
	particles.local_coords = false
	particles.z_index = 3
	particles.z_as_relative = false
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

func _buzz(strength: float) -> void:
	if strength >= VIBRATE_FROM:
		Input.vibrate_handheld(int(strength * VIBRATE_MS_PER_STRENGTH))

const TRAIL_SECONDS := 2.0   # smoke streams up off the lava this long...
const TRAIL_RISE := 3.2      # ...each wisp rising this long as it fades

# Wisps of smoke streaming up off the lava where a ball's going under: single pixels,
# rising and slowing, curling a little as they go, pale and fading to nothing
func _smoke_trail(at: Vector2) -> void:
	var smoke := CPUParticles2D.new()
	smoke.texture = _pixel
	smoke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke.amount = 220
	smoke.lifetime = TRAIL_RISE
	smoke.position = at
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(10, 3)
	smoke.direction = Vector2(0, -1)
	smoke.spread = 10.0
	smoke.initial_velocity_min = 70.0
	smoke.initial_velocity_max = 120.0
	smoke.gravity = Vector2(0, -10)   # hot, still lifting a little
	smoke.damping_min = 14.0
	smoke.damping_max = 26.0
	smoke.orbit_velocity_min = -0.05  # curling as it rises
	smoke.orbit_velocity_max = 0.05
	smoke.tangential_accel_min = -14.0
	smoke.tangential_accel_max = 14.0
	smoke.scale_amount_min = 1.0      # one or two table-art pixels, thinning as they rise
	smoke.scale_amount_max = 2.0
	var thin := Curve.new()
	thin.add_point(Vector2(0.0, 1.0))
	thin.add_point(Vector2(1.0, 0.5))
	smoke.scale_amount_curve = thin
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	fade.colors = PackedColorArray([Color(1.0, 0.78, 0.45, 1.0), Color(0.95, 0.93, 0.9, 0.95), Color(0.8, 0.79, 0.79, 0.6), Color(0.6, 0.6, 0.62, 0.0)])
	smoke.color_ramp = fade
	smoke.z_index = 4
	smoke.z_as_relative = false
	add_child(smoke)
	smoke.emitting = true
	get_tree().create_timer(TRAIL_SECONDS).timeout.connect(func(): smoke.emitting = false)
	get_tree().create_timer(TRAIL_SECONDS + TRAIL_RISE + 0.2).timeout.connect(smoke.queue_free)
