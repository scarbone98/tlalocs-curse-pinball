extends Node
## Debug view: F3 (or ?debug on the web page's address) draws the table's physics over it.
##
##   magenta    walls the playfield ball hits (collision layer 1)
##   cyan       walls a ball riding a rail hits (layer 2)
##   yellow     sensors (Area2D): buttons, lanes, targets, the rail mouths' lift zones...
##   grey       anything switched off just now
##   orange     a rail mouth's lift zone, its arrow the way up the rail; a ball inside it is
##              lifted on if it heads within the cone drawn (ENTRY_ALIGN) and stays within
##              the dashed lines of the track's middle (ENTRY_LATERAL)
##   green      each rail's track, the line a riding ball is carried along
##   white      one-way walls, the tick on the side they let balls through from
##   light blue the left orbit's guide line: a fast ball running round the orbit's wall is
##              carried along it (Scripts/orbit_guide.gd)
## Each ball shows its velocity, and its state: on a rail (which, and how fast), or not,
## and in a rail mouth, how well it lines up with the way up.

const Rails := preload("res://Scripts/rails.gd")

const WALL := Color(1.0, 0.2, 1.0, 0.9)
const RAIL_WALL := Color(0.2, 1.0, 1.0, 0.9)
const SENSOR := Color(1.0, 0.9, 0.2, 0.55)
const OFF := Color(0.6, 0.6, 0.6, 0.4)
const ENTRY := Color(1.0, 0.55, 0.1, 0.9)
const TRACK := Color(0.3, 1.0, 0.3, 0.9)
const ONE_WAY := Color(1.0, 1.0, 1.0, 0.95)
const ORBIT := Color(0.45, 0.85, 1.0, 0.9)

var features: Node2D  # TableFeatures
var _on := false
var _label: Label
var _layer: CanvasLayer
var _world: CanvasLayer  # its own canvas, so the dusk (a CanvasModulate) doesn't dim it
var _canvas: Node2D

func _ready() -> void:
	_world = CanvasLayer.new()
	_world.layer = 49
	_world.follow_viewport_enabled = true  # moves with the camera, like the table
	add_child(_world)
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_all)
	_world.add_child(_canvas)
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		_on = query is String and (query as String).contains("debug")
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_label = Label.new()
	_label.position = Vector2(8, 160)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_layer.add_child(_label)
	_show(_on)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		_show(not _on)

func _show(on: bool) -> void:
	_on = on
	_world.visible = on
	_layer.visible = on
	_canvas.queue_redraw()

func _process(_delta: float) -> void:
	if _on:
		_canvas.queue_redraw()
		_label.text = _status()

func _draw_all() -> void:
	if not _on:
		return
	var scene := get_tree().current_scene
	for node in scene.find_children("*", "CollisionShape2D", true, false):
		_draw_shape(node as CollisionShape2D)
	for node in scene.find_children("*", "CollisionPolygon2D", true, false):
		_draw_polygon(node as CollisionPolygon2D)
	_draw_rails()
	if features.orbit_guide:
		_canvas.draw_polyline(features.orbit_guide._curve.get_baked_points(), ORBIT, 2.0)
	for ball in get_tree().get_nodes_in_group("ball"):
		_draw_ball(ball as RigidBody2D)

func _colour(owner_body: CollisionObject2D, disabled: bool) -> Color:
	if disabled or owner_body == null or not owner_body.is_inside_tree():
		return OFF
	if owner_body is Area2D:
		return SENSOR if (owner_body as Area2D).monitoring else OFF
	if (owner_body.collision_layer & 1) == 0 and (owner_body.collision_layer & 2) != 0:
		return RAIL_WALL
	return WALL

func _draw_shape(node: CollisionShape2D) -> void:
	var body := node.get_parent() as CollisionObject2D
	if body == null or body.is_in_group("ball") or node.shape == null:
		return
	var colour := _colour(body, node.disabled)
	var xf := node.global_transform
	var shape := node.shape
	if shape is CircleShape2D:
		var r := (shape as CircleShape2D).radius * xf.get_scale().x
		_canvas.draw_arc(xf.origin, r, 0.0, TAU, 32, colour, 2.5)
	elif shape is RectangleShape2D:
		var h := (shape as RectangleShape2D).size / 2.0
		var corners := [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]
		_canvas.draw_polyline(PackedVector2Array(corners.map(func(c): return xf * c)), colour, 2.5)
	elif shape is SegmentShape2D:
		var seg := shape as SegmentShape2D
		var a := xf * seg.a
		var b := xf * seg.b
		_canvas.draw_line(a, b, ONE_WAY if node.one_way_collision else colour, 2.0)
		if node.one_way_collision:  # the tick points the way balls can pass through from
			var mid := (a + b) / 2.0
			_canvas.draw_line(mid, mid + xf.basis_xform(Vector2.UP).normalized() * 12.0, ONE_WAY, 2.0)
	elif shape is ConvexPolygonShape2D or shape is ConcavePolygonShape2D:
		var pts: PackedVector2Array = shape.points if shape is ConvexPolygonShape2D else shape.segments
		_canvas.draw_polyline(PackedVector2Array(Array(pts).map(func(p): return xf * p)), colour, 2.5)
	elif shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		_canvas.draw_arc(xf.origin, cap.radius, 0.0, TAU, 24, colour, 2.5)

func _draw_polygon(node: CollisionPolygon2D) -> void:
	var body := node.get_parent() as CollisionObject2D
	if body == null:
		return
	var colour := _colour(body, node.disabled)
	var xf := node.global_transform
	var pts := Array(node.polygon).map(func(p): return xf * p)
	if pts.size() < 2:
		return
	pts.append(pts[0])
	_canvas.draw_polyline(PackedVector2Array(pts), colour, 2.5)

func _draw_rails() -> void:
	var rails: Node2D = features.rails
	if rails == null:
		return
	for path_name: String in rails._curves:
		var curve: Curve2D = rails._curves[path_name]
		_canvas.draw_polyline(curve.get_baked_points(), TRACK, 2.0)
		var mouth := curve.sample_baked(0.0)
		_canvas.draw_circle(mouth, 4.0, TRACK)
		_canvas.draw_string(ThemeDB.fallback_font, mouth + Vector2(6, -6), path_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TRACK)
	for opening: String in Rails.ENTRIES:
		var rect: Rect2 = Rails.ENTRY_AREAS[opening]
		_canvas.draw_rect(rect, Color(ENTRY, 0.18), true)
		_canvas.draw_rect(rect, ENTRY, false, 2.0)
		var centre := rect.get_center()
		var up: Vector2 = Rails.ENTRIES[opening]
		var cone := acos(Rails.ENTRY_ALIGN[opening])
		_canvas.draw_line(centre, centre + up * 60.0, ENTRY, 3.0)
		_canvas.draw_line(centre, centre + up.rotated(cone) * 45.0, ENTRY, 1.0)
		_canvas.draw_line(centre, centre + up.rotated(-cone) * 45.0, ENTRY, 1.0)
		# the band a ball has to be within of the track's line, short of the mouth
		var path := "right" if opening == "right_entry" else ("left_temple" if rails.to_temple else "left_lanes")
		var curve: Curve2D = rails._curves[path]
		var mouth := curve.sample_baked(0.0)
		var way_in: Vector2 = rails._tangent(curve, 0.0)
		var side := Vector2(-way_in.y, way_in.x) * Rails.ENTRY_LATERAL
		for s in [side, -side]:
			_canvas.draw_dashed_line(mouth + s, mouth + s - way_in * 200.0, ENTRY, 1.0, 6.0)

func _draw_ball(ball: RigidBody2D) -> void:
	var p := ball.global_position
	var riding: bool = (features.rails != null and features.rails._rides.has(ball)) \
		or (features.orbit_guide != null and features.orbit_guide.carrying(ball))
	_canvas.draw_arc(p, 14.0, 0.0, TAU, 20, TRACK if riding else Color.WHITE, 2.0)
	_canvas.draw_line(p, p + ball.linear_velocity * 0.08, Color.WHITE, 2.0)

func _status() -> String:
	var lines := ["DEBUG (F3)", "magenta walls  cyan rail walls  yellow sensors", "orange rail mouths  green rail tracks  blue orbit guide"]
	var rails: Node2D = features.rails
	for ball in get_tree().get_nodes_in_group("ball"):
		var b := ball as RigidBody2D
		var text := "ball (%d, %d) speed %d" % [b.global_position.x, b.global_position.y, b.linear_velocity.length()]
		if rails and rails._rides.has(b):
			var ride = rails._rides[b]
			text += "  ON RAIL %s  along %d  speed %d" % [ride.path, ride.offset, ride.speed]
		elif features.orbit_guide and features.orbit_guide.carrying(b):
			text += "  ON ORBIT GUIDE"
		elif rails:
			for opening: String in Rails.ENTRIES:
				var rect: Rect2 = Rails.ENTRY_AREAS[opening]
				if rect.grow(14.0).has_point(b.global_position):
					var path := "right" if opening == "right_entry" else ("left_temple" if rails.to_temple else "left_lanes")
					var align := b.linear_velocity.normalized().dot(Rails.ENTRIES[opening])
					var off: float = rails._off_line(b.global_position, rails._curves[path])
					text += "  in %s: aim %.2f (needs > %.2f)  off line %d (needs < %d)" % [opening, align, Rails.ENTRY_ALIGN[opening], off, Rails.ENTRY_LATERAL]
		lines.append(text)
	if rails:
		lines.append("left rail goes to: " + ("TEMPLE" if rails.to_temple else "top lanes"))
	return "\n".join(lines)
