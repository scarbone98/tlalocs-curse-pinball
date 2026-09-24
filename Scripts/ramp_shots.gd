extends Node2D
## Ramp shots: a ball that climbs a side ramp and comes back down scores, and making
## the other ramp inside the combo window builds a combo, like the alley arrows in
## Pokemon Pinball. Gold inserts at each ramp mouth chase toward the ramp when idle
## and flash on the ramp to shoot next while a combo is live.

const ARROW_INSERT := preload("res://Sprites/table/arrow_insert.png")

const RAMP_POINTS := 1500
const COMBO_WINDOW := 5.0
const MAX_COMBO := 5
const TOP_Y := 320.0  # a ball above this line has made it over the top of either ramp
const MID_X := 340.0  # which gate the ball came through
# Two inserts per ramp mouth, listed mouth-first, angled to point up the ramp
const LAMPS := {
	"left": [[Vector2(205, 650), -42.0], [Vector2(222, 672), -42.0]],
	"right": [[Vector2(452, 712), 30.0], [Vector2(440, 735), 30.0]],
}

var features: Node2D  # TableFeatures, which owns the shared sprite and scoring helpers

var _lamps := {"left": [], "right": []}
var _runs := {}  # ball instance id -> {"side": String, "top": bool} while it's up a ramp
var _last_side := ""
var _combo := 0
var _combo_left := 0.0
var _clock := 0.0

func _ready() -> void:
	for side in LAMPS:
		for entry in LAMPS[side]:
			var lamp: AnimatedSprite2D = features._sprite(ARROW_INSERT, 2, entry[0])
			lamp.rotation_degrees = entry[1]
			_lamps[side].append(lamp)

func _physics_process(delta: float) -> void:
	_clock += delta
	_combo_left = maxf(_combo_left - delta, 0.0)
	for node in get_tree().get_nodes_in_group("ball"):
		_track(node as RigidBody2D)
	_render_lamps()

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

	features._award(RAMP_POINTS * _combo, _lamps[side][0].global_position)
	PinballEvents.toast.emit("Ramp!" if _combo == 1 else "Combo x%d!" % _combo)
	var pitch := 1.0 + 0.12 * (_combo - 1)
	AudioSfx.play("ramp", 0.0, Vector2(pitch, pitch))
	PinballEvents.ramp_made.emit(side, _combo)

func _render_lamps() -> void:
	var flash := int(_clock / 0.15) % 2 == 0
	var chase_step := int(_clock / 0.35) % 3  # far lamp, near lamp, dark
	for side in _lamps:
		var lamps: Array = _lamps[side]
		for i in lamps.size():
			var lit: bool
			if _combo_left > 0.0:
				lit = side != _last_side and flash
			else:
				lit = chase_step == lamps.size() - 1 - i
			lamps[i].frame = 1 if lit else 0
