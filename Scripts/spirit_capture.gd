extends Node2D
## Catch mode, following Pokemon Pinball Ruby & Sapphire's. Two Summon arrows on the right
## ramp let the ziggurat's door call up a spirit of the current city (all three, and it
## may be its rare one); the temple's roulette can call one too. The spirit rises out of
## the temple floor in a whirl of magic, hidden under six carved glyph tiles.
##
## Mushroom hits earn tiles, and the tiles crack open one by one each time the ball comes
## back down the table. Earn every tile still standing in a single trip up the table and
## they all shatter at once in a burst of lightning, for a bonus. Once the spirit is out,
## hit it three times to catch it for the Spirit Codex, kept between games. The mode
## runs two minutes and comes with a long ball saver; each catch lights a bonus lamp.

const SPIRITS := preload("res://Sprites/table/spirits.png")  # tools/make_spirit_sprites.py
const SPIRIT_SIZE := Vector2(26, 22)
const WHIRL := preload("res://Sprites/table/whirl.png")  # the hand-drawn magicWhirl.png
const WHIRL_SECONDS := 0.7
const TILE := preload("res://Sprites/table/glyph_tile.png")  # tools/make_rs_sprites.py
const TILE_ART := 8.0  # one tile, in table-art pixels
const TILE_COLUMNS := 3
const TILE_ROWS := 2

const SPAWN_AT := Vector2(337, 595)  # just above the temple hole, between the relics
const HIT_RADIUS := 26.0
const HITS_TO_CATCH := 3
const CATCH_SECONDS := 120.0
const SAVER_FIRST := 100.0          # the first catch of the game comes with a longer saver
const SAVER := 70.0
const WARN_SECONDS := 10.0  # the spirit flickers when it's about to sink
const LOWER_TABLE_Y := 820.0        # back down the table: earned tiles crack open
const CRACK_EVERY := 0.25
const TILE_POINTS := 500
const LIGHTNING_POINTS := 7500      # every tile earned in one trip up the table
const HIT_POINTS := 1000
const CATCH_POINTS := 25000
const RARE_MULTIPLIER := 5          # a rare spirit is worth five times as much
const NEW_SPIRIT_POINTS := 20000    # first time it goes in the Codex
const CITY_COMPLETE_POINTS := 100000  # the last of a city's four
const BOUNCE_SPEED := 750.0
const HIT_COOLDOWN := 0.35
const ART_PIXEL_Y := 1280.0 / 424.0  # one table-art pixel, vertically (see TableFeatures.MAP_SCALE)

enum { IDLE_A, IDLE_B, HIT }
enum { TILE_WHOLE, TILE_CRACKED }

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers
var caught := 0
var species := 0  # which spirit is up, an index into SpiritCodex.SPECIES

var _active := false
var _hits := 0
var _time_left := 0.0
var _cooldown := 0.0
var _clock := 0.0
var _area: Area2D
var _spirit: AnimatedSprite2D
var _whirl: AnimatedSprite2D
var _frames := {}  # species -> SpriteFrames for its row of the sheet
var _tiles: Array[AnimatedSprite2D] = []
var _earned := 0          # tiles earned and waiting to crack open
var _earned_this_trip := 0
var _crack_left := 0.0
var _shown_seconds := -1

func _ready() -> void:
	_area = Area2D.new()
	_area.position = SPAWN_AT
	_area.monitorable = false
	_area.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	_area.add_child(shape)
	_area.body_entered.connect(_on_body_entered)
	add_child(_area)

	_whirl = features._sprite(WHIRL, 3, SPAWN_AT, 12.0)
	_whirl.hide()
	_spirit = AnimatedSprite2D.new()
	_spirit.scale = features.MAP_SCALE
	_spirit.position = SPAWN_AT
	_spirit.z_index = 2  # over Tlaloc's face and his mouth's whirl
	_spirit.z_as_relative = false
	features.add_child(_spirit)
	_spirit.hide()
	for row in TILE_ROWS:
		for column in TILE_COLUMNS:
			var offset := Vector2((column - (TILE_COLUMNS - 1) * 0.5) * TILE_ART, (row - (TILE_ROWS - 1) * 0.5) * TILE_ART)
			var tile: AnimatedSprite2D = features._sprite(TILE, 2, SPAWN_AT + offset * features.MAP_SCALE)
			tile.hide()
			_tiles.append(tile)
	_hook_mushrooms.call_deferred()

# Mushroom hits earn tiles while a spirit is hidden
func _hook_mushrooms() -> void:
	var patch := features.get_node_or_null(^"../mushrooms")
	if patch == null:
		return
	for mushroom in patch.get_children():
		if mushroom is Area2D:
			mushroom.body_entered.connect(_on_mushroom_hit)

## Calls up a spirit now (the ziggurat's door and the temple's roulette). False if one is
## already up. With rare_allowed the city's rare spirit may rise.
func summon(rare_allowed := false) -> bool:
	if _active:
		return false
	species = SpiritCodex.pick(features.journey.city, rare_allowed)
	_spirit.sprite_frames = _frames_for(species)
	_active = true
	_hits = 0
	_time_left = CATCH_SECONDS
	_clock = 0.0
	_earned = 0
	_earned_this_trip = 0
	_crack_left = 0.0
	_shown_seconds = -1
	_splash()
	_spirit.frame = IDLE_A
	_spirit.modulate = Color(0, 0, 0, 0.85)  # a shadow under the tiles
	_spirit.show()
	for tile in _tiles:
		tile.frame = TILE_WHOLE
		tile.show()
	PinballEvents.banner.emit("A spirit rises!", Billboard.PRIZE + 3)
	GameManager.grant_ball_save(SAVER_FIRST if caught == 0 else SAVER)
	PinballEvents.spirit_changed.emit(true)
	PinballEvents.mode_changed.emit()
	AudioSfx.play("spirit")
	return true

func _frames_for(index: int) -> SpriteFrames:
	if not _frames.has(index):
		var frames := SpriteFrames.new()
		for i in 3:
			var atlas := AtlasTexture.new()
			atlas.atlas = SPIRITS
			atlas.region = Rect2(Vector2(i, index) * SPIRIT_SIZE, SPIRIT_SIZE)
			frames.add_frame("default", atlas)
		_frames[index] = frames
	return _frames[index]

func _tiles_left() -> int:
	return _tiles.filter(func(tile): return tile.visible).size()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_clock += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	_time_left -= delta
	if ceili(_time_left) != _shown_seconds:
		_shown_seconds = ceili(_time_left)
		_show_progress()
	if _time_left <= 0.0:
		_dismiss()
		return

	if _tiles_left() > 0:
		_crack_tiles(delta)
	# Gills shimmer and the spirit bobs one art pixel, so it stays on the table's grid
	if _cooldown == 0.0:
		_spirit.frame = IDLE_A if int(_clock * 3.0) % 2 == 0 else IDLE_B
	var bob := ART_PIXEL_Y if int(_clock * 2.0) % 2 == 0 else 0.0
	_spirit.position = SPAWN_AT - Vector2(0, bob)
	_spirit.visible = _time_left > WARN_SECONDS or int(_clock * 8.0) % 2 == 0

# Earned tiles crack open while the ball is back down the table, one at a time
func _crack_tiles(delta: float) -> void:
	var ball_low := false
	for node in get_tree().get_nodes_in_group("ball"):
		if (node as Node2D).global_position.y > LOWER_TABLE_Y:
			ball_low = true
	if not ball_low:
		return
	_earned_this_trip = 0
	if _earned <= 0:
		return
	_crack_left -= delta
	if _crack_left > 0.0:
		return
	_crack_left = CRACK_EVERY
	_earned -= 1
	_break_tile()

func _on_mushroom_hit(body: Node) -> void:
	if not _active or _tiles_left() == 0 or not features._is_ball_on_playfield(body):
		return
	var waiting := _tiles_left() - _earned
	if waiting <= 0:
		return
	_earned += 1
	_earned_this_trip += 1
	for i in _tiles.size():  # the next tile to go shows a crack
		if _tiles[i].visible and _tiles[i].frame == TILE_WHOLE:
			_tiles[i].frame = TILE_CRACKED
			break
	if _earned_this_trip >= _tiles.size():
		_lightning()

# Every tile in one trip: they all shatter at once
func _lightning() -> void:
	_earned = 0
	_earned_this_trip = 0
	for tile in _tiles:
		if tile.visible:
			tile.hide()
			PinballEvents.effect.emit("dust", tile.position)
	features._award(LIGHTNING_POINTS, SPAWN_AT)
	PinballEvents.effect.emit("gold", SPAWN_AT)
	PinballEvents.rumble.emit(6.0)
	AudioSfx.play("upgrade")
	_reveal()

func _break_tile() -> void:
	for tile in _tiles:
		if tile.visible:
			tile.hide()
			features._award(TILE_POINTS, tile.position)
			PinballEvents.effect.emit("dust", tile.position)
			AudioSfx.play("bumper", 0.0, Vector2.ONE * 1.3)
			break
	if _tiles_left() == 0:
		_reveal()

func _reveal() -> void:
	_spirit.modulate = Color.WHITE
	_area.set_deferred("monitoring", true)
	var spirit: Dictionary = SpiritCodex.SPECIES[species]
	PinballEvents.billboard.emit(Billboard.SPIRIT + species, ("A rare %s!" if spirit.rare else "A %s!") % spirit.name)
	_show_progress()

func _on_body_entered(body: Node) -> void:
	if not _active or _cooldown > 0.0 or _tiles_left() > 0 or not features._is_ball_on_playfield(body):
		return
	var ball := body as RigidBody2D
	_cooldown = HIT_COOLDOWN
	_hits += 1

	var away := (ball.global_position - SPAWN_AT).normalized()
	ball.linear_velocity = away * maxf(ball.linear_velocity.length(), BOUNCE_SPEED)
	_spirit.frame = HIT
	var pitch := 1.0 + 0.15 * _hits
	AudioSfx.play("spirit_hit", 0.0, Vector2(pitch, pitch))
	features._award(HIT_POINTS, SPAWN_AT)

	if _hits < HITS_TO_CATCH:
		return
	caught += 1
	var spirit: Dictionary = SpiritCodex.SPECIES[species]
	var first := SpiritCodex.register(species)
	var points: int = CATCH_POINTS * (RARE_MULTIPLIER if spirit.rare else 1)
	features._award(points, SPAWN_AT + Vector2(0, -40))
	if first:
		features._award(NEW_SPIRIT_POINTS, SPAWN_AT + Vector2(0, -80))
	PinballEvents.billboard.emit(Billboard.SPIRIT + species,
		("New in the Codex: %s!" if first else "%s caught!") % spirit.name)
	AudioSfx.play("catch")
	PinballEvents.effect.emit("gold", SPAWN_AT)
	if first and SpiritCodex.city_complete(spirit.city):
		features._award(CITY_COMPLETE_POINTS, SPAWN_AT + Vector2(0, -120))
		get_tree().create_timer(2.8).timeout.connect(func():
			PinballEvents.toast.emit("%s's spirits complete!" % features.journey.CITIES[spirit.city].name))
	GameManager.add_bonus_lamps(1)
	PinballEvents.spirit_caught.emit()
	_dismiss()

func _dismiss() -> void:
	_active = false
	PinballEvents.spirit_changed.emit(false)
	PinballEvents.mode_changed.emit()
	_area.set_deferred("monitoring", false)
	_spirit.hide()
	for tile in _tiles:
		tile.hide()
	_splash()
	features.journey._announce_goal()

func _show_progress() -> void:
	var left := maxi(ceili(_time_left), 0)
	var text := "Break the glyphs: %d/%d" % [_tiles.size() - _tiles_left(), _tiles.size()] if _tiles_left() > 0 \
		else "Catch the %s: %d/%d" % [SpiritCodex.SPECIES[species].name, _hits, HITS_TO_CATCH]
	PinballEvents.objective_changed.emit("%s   %d:%02d" % [text, left / 60, left % 60])

# The spirit comes and goes in a whirl of magic, its frames swirling, then fading away
func _splash() -> void:
	_whirl.show()
	_whirl.play()
	_whirl.modulate.a = 1.0
	var fade := _whirl.create_tween()
	fade.tween_interval(WHIRL_SECONDS * 0.7)
	fade.tween_property(_whirl, "modulate:a", 0.0, WHIRL_SECONDS * 0.3)
	fade.tween_callback(_whirl.hide)
