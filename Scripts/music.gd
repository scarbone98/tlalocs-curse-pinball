extends Node
## Mode music, like Pokemon Pinball's, which changes for Catch 'Em mode, Evolution and
## each bonus stage. The table's own track plays until a mode starts, then crossfades
## to that mode's loop (tools/make_mode_music.py); when the mode ends the table track
## fades back in where it left off. If modes overlap, the bigger one's music wins.

const TRACKS := {
	"el_dorado": preload("res://Audio/music/el_dorado.ogg"),
	"curse": preload("res://Audio/music/curse.ogg"),
	"spirit": preload("res://Audio/music/spirit.ogg"),
}
const PRIORITY := ["el_dorado", "curse", "spirit"]
const MODE_VOLUME_DB := 0.0  # the loops are already matched to the table track's loudness
const SILENT_DB := -40.0
const FADE_IN_SECONDS := 1.2
const FADE_BACK_SECONDS := 1.5  # back to the table track, a touch slower still

var _table: AudioStreamPlayer
var _mode: AudioStreamPlayer
var _table_volume_db := 0.0
var _active := {"el_dorado": false, "curse": false, "spirit": false}
var _playing := ""

func _ready() -> void:
	_table = get_node_or_null(^"../../Music") as AudioStreamPlayer
	if _table:
		_table_volume_db = _table.volume_db
	_mode = AudioStreamPlayer.new()
	_mode.volume_db = SILENT_DB
	add_child(_mode)
	PinballEvents.curse_changed.connect(_mode_changed.bind("curse"))
	PinballEvents.spirit_changed.connect(_mode_changed.bind("spirit"))
	PinballEvents.el_dorado_changed.connect(_mode_changed.bind("el_dorado"))

func _mode_changed(active: bool, mode: String) -> void:
	_active[mode] = active
	var wanted := ""
	for name in PRIORITY:
		if _active[name]:
			wanted = name
			break
	if wanted != _playing:
		_switch_to(wanted)

func _switch_to(mode: String) -> void:
	_playing = mode
	var fade := create_tween().set_parallel()
	if mode == "":
		fade.tween_property(_mode, "volume_db", SILENT_DB, FADE_BACK_SECONDS)
		if _table:
			_table.stream_paused = false
			fade.tween_property(_table, "volume_db", _table_volume_db, FADE_BACK_SECONDS)
		fade.chain().tween_callback(_mode.stop)
		return
	_mode.stream = TRACKS[mode]
	_mode.volume_db = SILENT_DB
	_mode.play()
	fade.tween_property(_mode, "volume_db", MODE_VOLUME_DB, FADE_IN_SECONDS)
	if _table and not _table.stream_paused:
		fade.tween_property(_table, "volume_db", SILENT_DB, FADE_IN_SECONDS)
		fade.chain().tween_callback(func(): if _playing != "": _table.stream_paused = true)
