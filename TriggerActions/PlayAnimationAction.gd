extends TriggerAction
class_name PlayAnimationAction

@export var animation_names: Array[StringName] = []   # e.g. [&"explode", &"shake"]
@export var target_paths: Array[NodePath] = []        # optional: subnodes to animate
@export var play_once: bool = true                    # if true: play one time only
@export var reset_to_first_frame: bool = true         # restore the original pose we snapshot

# Per-node snapshots (keyed by instance_id)
# id -> { "anim": StringName, "frame": int }
var _sprite_snapshots: Dictionary = {}
# id -> { "anim": StringName, "time": float }
var _player_snapshots: Dictionary = {}

func execute(ball: RigidBody2D, trigger: Node) -> void:
	if trigger == null:
		return
	if target_paths.size() > 0:
		_play_on_targets(trigger, target_paths)
	else:
		_play_on_children(trigger)

func _play_on_targets(trigger: Node, paths: Array[NodePath]) -> void:
	for path in paths:
		var node := trigger.get_node_or_null(path)
		_play_on_node(node)

func _play_on_children(trigger: Node) -> void:
	for child in trigger.get_children():
		_play_on_node(child)

func _play_on_node(node: Node) -> void:
	if node == null:
		return
	if node is AnimatedSprite2D:
		_snapshot_sprite_if_needed(node)
		_play_on_animated_sprite(node)
	elif node is AnimationPlayer:
		_snapshot_player_if_needed(node)
		_play_on_animation_player(node)

# ---------- Snapshots ----------
func _snapshot_sprite_if_needed(sprite: AnimatedSprite2D) -> void:
	var id := sprite.get_instance_id()
	if _sprite_snapshots.has(id):
		return
	_sprite_snapshots[id] = {
		"anim": sprite.animation,
		"frame": sprite.frame
	}

func _snapshot_player_if_needed(player: AnimationPlayer) -> void:
	var id := player.get_instance_id()
	if _player_snapshots.has(id):
		return
	_player_snapshots[id] = {
		"anim": player.current_animation,          # StringName (may be empty)
		"time": player.current_animation_position  # float
	}

# ---------- AnimatedSprite2D ----------
func _play_on_animated_sprite(sprite: AnimatedSprite2D) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return

	for anim in animation_names:
		if not frames.has_animation(anim):
			continue

		var original_loop := frames.get_animation_loop(anim)

		if play_once:
			frames.set_animation_loop(anim, false)
			if sprite.is_connected("animation_finished", Callable(self, "_on_sprite_finished")):
				sprite.disconnect("animation_finished", Callable(self, "_on_sprite_finished"))
			sprite.connect(
				"animation_finished",
				Callable(self, "_on_sprite_finished").bind(sprite, anim, original_loop),
				CONNECT_ONE_SHOT
			)

		sprite.play(anim)

func _on_sprite_finished(finished_anim: StringName, sprite: AnimatedSprite2D, expected_anim: StringName, restore_loop: bool) -> void:
	if finished_anim != expected_anim:
		return
	sprite.stop()

	if reset_to_first_frame:
		var id := sprite.get_instance_id()
		var snap: Dictionary = _sprite_snapshots.get(id, {})
		var orig_anim: StringName = snap.get("anim", &"")
		var orig_frame: int = snap.get("frame", 0)

		if sprite.sprite_frames and sprite.sprite_frames.has_animation(orig_anim):
			sprite.animation = orig_anim
			sprite.frame = orig_frame
		else:
			# Fallback if original anim no longer exists
			sprite.frame = 0

	# restore loop setting for the triggered anim
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(expected_anim):
		sprite.sprite_frames.set_animation_loop(expected_anim, restore_loop)

# ---------- AnimationPlayer ----------
func _play_on_animation_player(player: AnimationPlayer) -> void:
	for anim in animation_names:
		if not player.has_animation(anim):
			continue
		if play_once:
			if player.is_connected("animation_finished", Callable(self, "_on_player_finished")):
				player.disconnect("animation_finished", Callable(self, "_on_player_finished"))
			player.connect(
				"animation_finished",
				Callable(self, "_on_player_finished").bind(player, anim),
				CONNECT_ONE_SHOT
			)
		player.play(anim)

func _on_player_finished(finished_anim: StringName, player: AnimationPlayer, expected_anim: StringName) -> void:
	if finished_anim != expected_anim:
		return
	player.stop()

	if reset_to_first_frame:
		var id := player.get_instance_id()
		var psnap: Dictionary = _player_snapshots.get(id, {})
		var orig_anim: StringName = psnap.get("anim", &"")
		var orig_time: float = psnap.get("time", 0.0)

		if orig_anim != &"" and player.has_animation(orig_anim):
			player.play(orig_anim)
			player.seek(orig_time, true)
			player.stop()
		elif player.has_animation(expected_anim):
			# Fallback: pose at t=0 of the finished anim
			player.play(expected_anim)
			player.seek(0.0, true)
			player.stop()
