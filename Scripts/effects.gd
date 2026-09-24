extends Node2D
## Hit effects: short bursts of chunky pixel particles wherever something gets hit,
## sent over the event bus (PinballEvents.effect) so any part of the table can ask
## for one. Strong rumbles also buzz the phone, where the browser allows it.
##
##   splash  water off a frog or the kickback
##   sparks  gold off the slingshots, serpents, coins and the Gilded King
##   dust    stone off a wall the ball slams into
##   gold    a shower of gold for a relic or the El Dorado jackpot
##   fire    sparks flying up off a torch as it catches

const VIBRATE_FROM := 6.0  # only the big moments (kickback, the King, the jackpot) buzz the phone
const VIBRATE_MS_PER_STRENGTH := 6

# kind -> [amount, lifetime, speed range, gravity, colors from bright to faded]
const KINDS := {
	"splash": [12, 0.4, Vector2(140, 300), 500.0, [Color("#e6fbff"), Color("#8be6ee"), Color(0.1, 0.53, 0.64, 0.0)]],
	"sparks": [10, 0.3, Vector2(200, 380), 200.0, [Color("#fffbd6"), Color("#f8d000"), Color(0.97, 0.63, 0.03, 0.0)]],
	"dust": [6, 0.3, Vector2(60, 140), 0.0, [Color("#b4c4cc"), Color("#748c9a"), Color(0.34, 0.43, 0.47, 0.0)]],
	"gold": [32, 0.7, Vector2(160, 420), 380.0, [Color("#fffbd6"), Color("#f8d000"), Color(0.75, 0.54, 0.06, 0.0)]],
	"fire": [14, 0.5, Vector2(60, 180), -260.0, [Color("#fffbd6"), Color("#f8a008"), Color(0.75, 0.34, 0.18, 0.0)]],
}

var _pixel: ImageTexture

func _ready() -> void:
	# One table-art pixel (3x3 on screen), so the bursts sit on the pixel grid's scale
	var image := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_pixel = ImageTexture.create_from_image(image)
	PinballEvents.effect.connect(_burst)
	PinballEvents.rumble.connect(_buzz)

func _burst(kind: String, at: Vector2) -> void:
	if not KINDS.has(kind):
		return
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
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.6
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
