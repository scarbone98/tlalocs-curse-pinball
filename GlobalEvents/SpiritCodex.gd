extends Node
## The Spirit Codex, like Pokemon Pinball's Pokedex: every spirit caught is recorded,
## and the record is kept between games. Each city has four spirits (three common and
## a rare one); a spirit that rises during the catch mode is one of the current city's.

const SAVE_PATH := "user://settings.cfg"  # shared with the high score
const SAVE_SECTION := "codex"
const RARE_CHANCE := 0.1

# In journey order, one row each of Sprites/table/spirits.png (tools/make_spirit_sprites.py)
const SPECIES := [
	{"id": "ajolote", "name": "Ajolote", "city": 0, "rare": false},
	{"id": "xolo", "name": "Xolo", "city": 0, "rare": false},
	{"id": "heron", "name": "Heron", "city": 0, "rare": false},
	{"id": "eagle", "name": "Golden Eagle", "city": 0, "rare": true},
	{"id": "butterfly", "name": "Papalotl", "city": 1, "rare": false},
	{"id": "owl", "name": "Owl", "city": 1, "rare": false},
	{"id": "coyote", "name": "Coyote", "city": 1, "rare": false},
	{"id": "feathered_serpent", "name": "Feathered Serpent", "city": 1, "rare": true},
	{"id": "iguana", "name": "Iguana", "city": 2, "rare": false},
	{"id": "bat", "name": "Camazotz", "city": 2, "rare": false},
	{"id": "rattlesnake", "name": "Rattlesnake", "city": 2, "rare": false},
	{"id": "sun_macaw", "name": "Sun Macaw", "city": 2, "rare": true},
	{"id": "howler_monkey", "name": "Howler Monkey", "city": 3, "rare": false},
	{"id": "hummingbird", "name": "Hummingbird", "city": 3, "rare": false},
	{"id": "tapir", "name": "Tapir", "city": 3, "rare": false},
	{"id": "quetzal", "name": "Quetzal", "city": 3, "rare": true},
]

var caught := {}  # species id -> times caught, across every game

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for spirit in SPECIES:
			caught[spirit.id] = int(config.get_value(SAVE_SECTION, spirit.id, 0))

## A spirit to rise in the given city: usually one of its three common ones, sometimes its rare
func pick(city: int) -> int:
	var common: Array[int] = []
	var rare := -1
	for i in SPECIES.size():
		if SPECIES[i].city == city:
			if SPECIES[i].rare:
				rare = i
			else:
				common.append(i)
	if rare >= 0 and randf() < RARE_CHANCE:
		return rare
	return common[randi() % common.size()]

## Records a catch and saves it. True if it's the first of its kind.
func register(index: int) -> bool:
	var id: String = SPECIES[index].id
	var first: bool = caught.get(id, 0) == 0
	caught[id] = caught.get(id, 0) + 1
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(SAVE_SECTION, id, caught[id])
	config.save(SAVE_PATH)
	return first

func has_caught(index: int) -> bool:
	return caught.get(SPECIES[index].id, 0) > 0

func count() -> int:
	var n := 0
	for i in SPECIES.size():
		if has_caught(i):
			n += 1
	return n

func city_complete(city: int) -> bool:
	for i in SPECIES.size():
		if SPECIES[i].city == city and not has_caught(i):
			return false
	return true
