class_name HighScore
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"

static func load_best() -> int:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return 0
	return int(config.get_value("scores", "best", 0))

# Returns true when score beats the stored best.
static func submit(score: int) -> bool:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	if score <= int(config.get_value("scores", "best", 0)):
		return false
	config.set_value("scores", "best", score)
	config.save(SETTINGS_PATH)
	return true
