extends CanvasLayer
class_name MobilePaddleInput

@export var left_action: StringName = &"left_flipper"
@export var right_action: StringName = &"right_flipper"
@export var allow_drag_side_switch: bool = true  # dragging across center swaps paddle

var _touch_side: Dictionary = {}  # touch index -> "left" | "right"

func _ready() -> void:
	set_process_unhandled_input(true)
	_ensure_actions()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var side := _side_for_pos(event.position)
		if event.pressed and _is_on_button(event.position):
			return
		if event.pressed:
			_touch_side[event.index] = side
			Input.action_press(left_action if side == "left" else right_action)
		else:
			if _touch_side.has(event.index):
				var s: String = _touch_side[event.index]
				Input.action_release(left_action if s == "left" else right_action)
				_touch_side.erase(event.index)

	elif event is InputEventScreenDrag and allow_drag_side_switch:
		if _touch_side.has(event.index):
			var new_side := _side_for_pos(event.position)
			var cur_side: String = _touch_side[event.index]
			if new_side != cur_side:
				Input.action_release(left_action if cur_side == "left" else right_action)
				Input.action_press(left_action if new_side == "left" else right_action)
				_touch_side[event.index] = new_side

# On-screen buttons (like Launch) shouldn't also fire a flipper
func _is_on_button(p: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("touch_block"):
		var control := node as Control
		if control and control.is_visible_in_tree() and control.get_global_rect().has_point(p):
			return true
	return false

func _side_for_pos(p: Vector2) -> String:
	var mid := get_viewport().get_visible_rect().size.x * 0.5
	return "left" if p.x < mid else "right"

func _ensure_actions() -> void:
	# Optional: create actions + default keybindings at runtime if missing
	if not InputMap.has_action(left_action):
		InputMap.add_action(left_action)
		var ev_l := InputEventKey.new(); ev_l.keycode = Key.KEY_LEFT
		InputMap.action_add_event(left_action, ev_l)
	if not InputMap.has_action(right_action):
		InputMap.add_action(right_action)
		var ev_r := InputEventKey.new(); ev_r.keycode = Key.KEY_RIGHT
		InputMap.action_add_event(right_action, ev_r)
	# Arrow keys are the first thing most players try, so bind them alongside Z and /
	_add_key_if_missing(left_action, Key.KEY_LEFT)
	_add_key_if_missing(right_action, Key.KEY_RIGHT)

func _add_key_if_missing(action: StringName, key: Key) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode == key or event.physical_keycode == key):
			return
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
