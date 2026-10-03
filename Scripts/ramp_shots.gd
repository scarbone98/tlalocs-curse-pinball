extends Node2D
## Ramp shots: a ball that climbs a side ramp and comes back down scores, and making
## the other ramp inside the combo window builds a combo.
##
## Like the orbit arrows on Pokemon Pinball Ruby & Sapphire's fields, each ramp also
## lights arrows, up to three, while no mode is running: the right ramp's Summon arrows
## and the left ramp's Awaken arrows, worth more as they climb. Two Summon arrows let
## the ziggurat's door call up a spirit to catch (three, and it may be a rare one);
## three Awaken arrows light the Awakening in the jaguar's den. The gold inserts at each
## ramp mouth show its arrows, and chase toward the ramp on the ones still dark.


const RAMP_POINTS := 1500
const MAX_ARROWS := 3
const ARROW_POINTS := [1500, 3750, 7500]  # the first, second and third arrow on a ramp
const COMBO_WINDOW := 5.0
const MAX_COMBO := 5
const TOP_Y := 320.0  # a ball above this line has made it over the top of either ramp
const MID_X := 340.0  # which gate the ball came through
# Three inserts per ramp mouth, listed mouth-first, angled to point up the ramp
const SHOT_AT := {"left": Vector2(205, 650), "right": Vector2(493, 748)}  # where a made rail's points pop up
const ARROW_KIND := {"left": "awaken", "right": "summon"}

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var arrows := {"awaken": 0, "summon": 0}
var _runs := {}  # ball instance id -> {"side": String, "top": bool} while it's up a ramp
var _last_side := ""
var _combo := 0
var _combo_left := 0.0
var _clock := 0.0

func _physics_process(delta: float) -> void:
	_clock += delta
	_combo_left = maxf(_combo_left - delta, 0.0)
	for node in get_tree().get_nodes_in_group("ball"):
		_track(node as RigidBody2D)

# The gates put layer 2 in a ball's mask while it's on a ramp and take it out again
# once it's back down, so a finished ramp is: mask on, above TOP_Y, mask off.
func _track(ball: RigidBody2D) -> void:
	if ball == null:
		return
	var id := ball.get_instance_id()
	if (ball.collision_mask & 2) != 0:
		if not _runs.has(id):
			_runs[id] = {"side": "left" if ball.global_position.x < MID_X else "right", "top": false}
		if ball.global_position.y < TOP_Y:
			_runs[id].top = true
	elif _runs.has(id):
		var run: Dictionary = _runs[id]
		_runs.erase(id)
		if run.top:
			_ramp_made(run.side)

func _ramp_made(side: String) -> void:
	if _combo_left > 0.0 and side != _last_side:
		_combo = mini(_combo + 1, MAX_COMBO)
	else:
		_combo = 1
	_last_side = side
	_combo_left = COMBO_WINDOW

	features._award(RAMP_POINTS * _combo, SHOT_AT[side])
	var kind: String = ARROW_KIND[side]
	if not features.mode_running() and arrows[kind] < MAX_ARROWS:
		features._award(ARROW_POINTS[arrows[kind]], SHOT_AT[side] + Vector2(0, -40))
		arrows[kind] += 1
		PinballEvents.arrows_changed.emit(kind, arrows[kind])
		PinballEvents.toast.emit("%s arrow %d/%d" % [kind.capitalize(), arrows[kind], MAX_ARROWS])
		if kind == "awaken" and arrows[kind] == MAX_ARROWS:
			features.awakening.light()
	else:
		PinballEvents.toast.emit("Ramp!" if _combo == 1 else "Combo x%d!" % _combo)
	var pitch := 1.0 + 0.12 * (_combo - 1)
	AudioSfx.play("ramp", 0.0, Vector2(pitch, pitch))
	PinballEvents.ramp_made.emit(side, _combo)

## Spends the arrows of one kind (a mode they lit has started)
func clear_arrows(kind: String) -> void:
	arrows[kind] = 0
	PinballEvents.arrows_changed.emit(kind, 0)
