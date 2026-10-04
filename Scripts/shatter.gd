extends Node2D
## A sprite breaking apart (Scripts/idol_tower.gd's drums): the frame's own pixels cut into
## a dozen jagged chunks that burst out from where it was hit, tumble as they fly, land on
## the floor below and skitter, then fade. Each chunk keeps the art pixels it had, laid on
## the art-pixel grid as it flies. Frees itself once the last chunk has gone.

const CHUNKS := 12
const GRAVITY := 900.0
const BOUNCE := 0.35          # how much of its fall a chunk keeps, bouncing off the floor
const SKID := 0.6             # ...and of its slide
const TUMBLE_SECONDS := 0.07  # a flying chunk flips over this often
const LIVE_SECONDS := 0.9
const FADE_SECONDS := 0.35

var _pieces: Array = []  # each: [Sprite2D, velocity, landed]
var _floor_y := 0.0
var _px := Vector2.ONE
var _t := 0.0
var _tumble := 0.0

## Breaks `region` of `texture` (drawn at `scale`, centred on `at`) into chunks that burst
## away from `from` (where it was struck) and come down on the floor at `floor_y`
static func burst(parent: Node, texture: Texture2D, region: Rect2i, at: Vector2, scale: Vector2,
		from: Vector2, floor_y: float, z: int = 3) -> void:
	var shatter: Node2D = load("res://Scripts/shatter.gd").new()
	shatter._floor_y = floor_y
	shatter._px = scale
	shatter.z_index = z
	shatter.z_as_relative = false
	parent.add_child(shatter)
	var image := texture.get_image().get_region(region)
	if image.is_compressed():
		image.decompress()
	var size := image.get_size()
	# jagged chunks: each pixel goes to its nearest of a scatter of seeds
	var seeds: Array[Vector2] = []
	for i in CHUNKS:
		seeds.append(Vector2(randf() * size.x, randf() * size.y))
	var cells := PackedInt32Array()
	cells.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			var best := 0
			var near := INF
			for i in CHUNKS:
				var d := seeds[i].distance_squared_to(Vector2(x + 0.5, y + 0.5) * Vector2(1.0, 1.4))
				if d < near:
					near = d
					best = i
			cells[y * size.x + x] = best
	for i in CHUNKS:
		var box := Rect2i()
		var any := false
		for y in size.y:
			for x in size.x:
				if cells[y * size.x + x] == i and image.get_pixel(x, y).a > 0.0:
					box = Rect2i(x, y, 1, 1) if not any else box.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
					any = true
		if not any:
			continue
		var piece := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		for y in box.size.y:
			for x in box.size.x:
				var sx := box.position.x + x
				var sy := box.position.y + y
				if cells[sy * size.x + sx] == i:
					piece.set_pixel(x, y, image.get_pixel(sx, sy))
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(piece)
		sprite.scale = scale
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var centre := Vector2(box.get_center()) - Vector2(size) * 0.5
		sprite.position = at + centre * scale
		shatter.add_child(sprite)
		# out to either side, clear of whatever's behind it, kicked away from the blow
		var side := signf(centre.x) if absf(centre.x) > 0.5 else (1.0 if randf() < 0.5 else -1.0)
		var away := (sprite.position - from).normalized()
		var velocity := Vector2(side * randf_range(140.0, 300.0), randf_range(-240.0, -90.0)) + away * 60.0
		shatter._pieces.append([sprite, velocity, false])

func _process(delta: float) -> void:
	_t += delta
	_tumble += delta
	var flip := _tumble >= TUMBLE_SECONDS
	if flip:
		_tumble = 0.0
	for piece: Array in _pieces:
		var sprite: Sprite2D = piece[0]
		var v: Vector2 = piece[1]
		v.y += GRAVITY * delta
		var p := sprite.get_meta("at", sprite.position) as Vector2
		p += v * delta
		if p.y > _floor_y and v.y > 0.0:
			p.y = _floor_y
			v.y = -v.y * BOUNCE
			v.x *= SKID
			if absf(v.y) < 40.0:
				v.y = 0.0
				piece[2] = true
		piece[1] = v
		sprite.set_meta("at", p)
		sprite.position = (p / _px).floor() * _px  # on the art-pixel grid
		if flip and not piece[2]:
			if randf() < 0.5:
				sprite.flip_h = not sprite.flip_h
			else:
				sprite.flip_v = not sprite.flip_v
	modulate.a = 1.0 - smoothstep(LIVE_SECONDS - FADE_SECONDS, LIVE_SECONDS, _t)
	if _t > LIVE_SECONDS:
		queue_free()
