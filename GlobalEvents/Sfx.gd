extends Node
class_name Sfx

# --- CONFIG ---------------------------------------------------------
# Use a non-const dictionary so we can register/override entries at runtime.
static var LIB: Dictionary = {
	"launch": preload("res://Audio/sfx/ball_launch.wav"),
	"bumper": preload("res://Audio/sfx/ball_launch.wav"),
}

const DEFAULT_BUS := "SFX"
const UI_BUS := "UI"
const MAX_SIMULTANEOUS_PER_KEY := 6
const DEFAULT_PITCH_RANGE := Vector2(0.96, 1.04)
const POOL_2D_SIZE := 16
const POOL_1D_SIZE := 8

# --- STATE ----------------------------------------------------------
var _active_by_key: Dictionary = {}      # key: StringName -> int
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_1d: Array[AudioStreamPlayer] = []

# --- LIFECYCLE ------------------------------------------------------
func _ready() -> void:
	_init_pools()

func _init_pools() -> void:
	for i in POOL_2D_SIZE:
		var p2d: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		p2d.bus = DEFAULT_BUS
		p2d.autoplay = false
		p2d.process_mode = Node.PROCESS_MODE_DISABLED
		p2d.finished.connect(_on_player_finished.bind(p2d))
		add_child(p2d)
		_pool_2d.append(p2d)

	for i in POOL_1D_SIZE:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = DEFAULT_BUS
		p.autoplay = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.finished.connect(_on_player_finished.bind(p))
		add_child(p)
		_pool_1d.append(p)

# --- PUBLIC API -----------------------------------------------------
func play(
		key: StringName,
		volume_db: float = 0.0,
		pitch_range: Vector2 = DEFAULT_PITCH_RANGE,
		bus: StringName = DEFAULT_BUS
	) -> void:
	var stream: AudioStream = _require_stream(key)
	if stream == null: return
	if not _can_play(key): return

	var p: AudioStreamPlayer = _borrow_1d()
	p.bus = bus
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = _rand_range(pitch_range.x, pitch_range.y)
	p.process_mode = Node.PROCESS_MODE_INHERIT
	_inc_active(key, p)
	p.play()

func play_2d(
		key: StringName,
		world_pos: Vector2,
		volume_db: float = 0.0,
		pitch_range: Vector2 = DEFAULT_PITCH_RANGE,
		bus: StringName = DEFAULT_BUS
	) -> void:
	var stream: AudioStream = _require_stream(key)
	if stream == null: return
	if not _can_play(key): return

	var p: AudioStreamPlayer2D = _borrow_2d()
	p.bus = bus
	p.stream = stream
	p.global_position = world_pos
	p.volume_db = volume_db
	p.pitch_scale = _rand_range(pitch_range.x, pitch_range.y)
	p.process_mode = Node.PROCESS_MODE_INHERIT
	_inc_active(key, p)
	p.play()

func ui(key: StringName = "ui_click", volume_db: float = 0.0) -> void:
	# No pitch variance for UI
	play(key, volume_db, Vector2.ONE, UI_BUS)

func register_stream(key: StringName, stream: AudioStream) -> void:
	LIB[key] = stream

# --- INTERNAL -------------------------------------------------------
func _require_stream(key: StringName) -> AudioStream:
	if not LIB.has(key):
		push_warning("[Sfx] Unknown sfx key: %s" % key)
		return null
	return LIB[key]

func _can_play(key: StringName) -> bool:
	var c: int = int(_active_by_key.get(key, 0))
	return c < MAX_SIMULTANEOUS_PER_KEY

func _inc_active(key: StringName, player: Node) -> void:
	var current: int = int(_active_by_key.get(key, 0))
	_active_by_key[key] = current + 1
	player.set_meta("sfx_key", key)

func _dec_active(player: Node) -> void:
	var key = player.get_meta("sfx_key")
	if key != null and _active_by_key.has(key):
		_active_by_key[key] = max(0, int(_active_by_key[key]) - 1)

func _borrow_1d() -> AudioStreamPlayer:
	for p in _pool_1d:
		if not p.playing:
			return p
	return _pool_1d[0] # voice steal

func _borrow_2d() -> AudioStreamPlayer2D:
	for p in _pool_2d:
		if not p.playing:
			return p
	return _pool_2d[0] # voice steal

func _on_player_finished(player: Node) -> void:
	_dec_active(player)
	if player is AudioStreamPlayer2D:
		var p2d := player as AudioStreamPlayer2D
		p2d.stream = null
		p2d.process_mode = Node.PROCESS_MODE_DISABLED
	elif player is AudioStreamPlayer:
		var p := player as AudioStreamPlayer
		p.stream = null
		p.process_mode = Node.PROCESS_MODE_DISABLED

func _rand_range(a: float, b: float) -> float:
	if a == b:
		return a
	var lo: float = min(a, b)
	var hi: float = max(a, b)
	return randf() * (hi - lo) + lo
