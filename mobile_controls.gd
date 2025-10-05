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
