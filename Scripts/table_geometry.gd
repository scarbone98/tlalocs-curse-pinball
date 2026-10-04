## Where the table's separate sprites sit, from tools/make_table.py.
## Generated: edit the art and re-run the tool rather than editing this.

## Each palm's box in Sprites/map_palms.png (art pixels)
const PALMS := [
	Rect2(27, 92, 40, 38),
	Rect2(16, 96, 15, 29),
	Rect2(82, 104, 41, 24),
	Rect2(168, 133, 61, 25),
	Rect2(0, 141, 47, 68),
	Rect2(95, 163, 36, 21),
]

## The gold buttons painted in the basemap: their centres (art pixels)
const GOLD_BUTTONS := {
	"spike_button": Vector2(113.5, 182.0),
	"frog_button": Vector2(74.5, 270.0),
	"skull_button": Vector2(157.0, 212.0),
}

## The centre of the temple's ring of gems (art pixels)
const TEMPLE_RING_CENTRE := Vector2(208.0, 50.0)

## The temple's ring gems in order round the ring: [centre (art pixels), its strip in
## Sprites/table/temple_gems_lit.png]
const TEMPLE_GEMS := [
	[Vector2(175.5, 49.5), Rect2(0, 0, 3, 5)],
	[Vector2(185.0, 30.5), Rect2(3, 0, 4, 3)],
	[Vector2(208.0, 21.5), Rect2(7, 0, 4, 1)],
	[Vector2(231.0, 30.5), Rect2(11, 0, 4, 3)],
	[Vector2(240.5, 49.5), Rect2(15, 0, 3, 5)],
	[Vector2(231.0, 69.5), Rect2(18, 0, 4, 3)],
	[Vector2(208.0, 77.5), Rect2(22, 0, 4, 3)],
	[Vector2(185.0, 69.5), Rect2(26, 0, 4, 3)],
]
