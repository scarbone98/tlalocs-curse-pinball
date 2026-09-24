extends Node
## The Spirit Codex, like Pokemon Pinball's Pokedex: every spirit caught is recorded,
## and the record is kept between games. Each city has four spirits (three common and
## a rare one); a spirit that rises during the catch mode is one of the current city's.
## A caught spirit can be awakened into its divine form (the Awakening, like Pokemon
## Pinball's evolutions); those are recorded too.

const SAVE_PATH := "user://settings.cfg"  # shared with the high score
const SAVE_SECTION := "codex"
const AWAKENED_SECTION := "awakened"
const RARE_CHANCE := 0.1

# In journey order, one row each of Sprites/table/spirits.png (tools/make_spirit_sprites.py)
const SPECIES := [
	{"id": "ajolote", "name": "Ajolote", "divine": "Xolotl", "city": 0, "rare": false},
	{"id": "xolo", "name": "Xolo", "divine": "Mictlan Guide", "city": 0, "rare": false},
	{"id": "heron", "name": "Heron", "divine": "Heron of Aztlan", "city": 0, "rare": false},
	{"id": "eagle", "name": "Golden Eagle", "divine": "Sun Eagle", "city": 0, "rare": true},
	{"id": "butterfly", "name": "Papalotl", "divine": "Itzpapalotl", "city": 1, "rare": false},
	{"id": "owl", "name": "Owl", "divine": "Owl of Mictlan", "city": 1, "rare": false},
	{"id": "coyote", "name": "Coyote", "divine": "Huehuecoyotl", "city": 1, "rare": false},
	{"id": "feathered_serpent", "name": "Feathered Serpent", "divine": "Quetzalcoatl", "city": 1, "rare": true},
	{"id": "iguana", "name": "Iguana", "divine": "Itzamna", "city": 2, "rare": false},
	{"id": "bat", "name": "Bat", "divine": "Camazotz", "city": 2, "rare": false},
	{"id": "rattlesnake", "name": "Rattlesnake", "divine": "Kukulkan", "city": 2, "rare": false},
	{"id": "sun_macaw", "name": "Sun Macaw", "divine": "Kinich Ahau", "city": 2, "rare": true},
	{"id": "howler_monkey", "name": "Howler Monkey", "divine": "Hun Batz", "city": 3, "rare": false},
	{"id": "hummingbird", "name": "Hummingbird", "divine": "Huitzilopochtli", "city": 3, "rare": false},
	{"id": "tapir", "name": "Tapir", "divine": "Sacred Tapir", "city": 3, "rare": false},
	{"id": "quetzal", "name": "Quetzal", "divine": "Royal Quetzal", "city": 3, "rare": true},
]

var caught := {}  # species id -> times caught, across every game
var awakened := {}  # species id -> true once awakened

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		for spirit in SPECIES:
			caught[spirit.id] = int(config.get_value(SAVE_SECTION, spirit.id, 0))
			awakened[spirit.id] = bool(config.get_value(AWAKENED_SECTION, spirit.id, false))

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

## Records a spirit awakened into its divine form, and saves it
func awaken(index: int) -> void:
	var id: String = SPECIES[index].id
	awakened[id] = true
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(AWAKENED_SECTION, id, true)
	config.save(SAVE_PATH)

func is_awakened(index: int) -> bool:
	return awakened.get(SPECIES[index].id, false)

## Caught spirits still waiting to be awakened
func awakenable() -> Array[int]:
	var out: Array[int] = []
	for i in SPECIES.size():
		if has_caught(i) and not is_awakened(i):
			out.append(i)
	return out

func awakened_count() -> int:
	var n := 0
	for i in SPECIES.size():
		if is_awakened(i):
			n += 1
	return n

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
