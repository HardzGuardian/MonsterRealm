extends Node

const MUSIC_PATH := "res://assets/audio/music/"
const SFX_PATH   := "res://assets/audio/sfx/"

var _music: AudioStreamPlayer
var _sfx:   AudioStreamPlayer

var music_volume: float = 0.8
var sfx_volume:   float = 0.8

var _current_track := ""

const SETTINGS_PATH := "user://settings.json"

func _ready():
	_music        = AudioStreamPlayer.new()
	_music.bus    = "Music"
	add_child(_music)

	_sfx          = AudioStreamPlayer.new()
	_sfx.bus      = "SFX"
	add_child(_sfx)

	_load_volume()
	_apply_music_volume()
	_apply_sfx_volume()


func _load_volume():
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	if json.data is Dictionary:
		music_volume = clampf(float(json.data.get("music_volume", 0.8)), 0.0, 1.0)
		sfx_volume   = clampf(float(json.data.get("sfx_volume",   0.8)), 0.0, 1.0)


func _save_volume():
	# Merge into existing settings so current_slot isn't overwritten
	var existing: Dictionary = {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			existing = json.data
	existing["music_volume"] = music_volume
	existing["sfx_volume"]   = sfx_volume
	var wf := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if wf:
		wf.store_string(JSON.stringify(existing, "\t"))


func play_music(track_name: String):
	if track_name == _current_track and _music.playing:
		return
	var path := MUSIC_PATH + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		path = MUSIC_PATH + track_name + ".mp3"
	if not ResourceLoader.exists(path):
		return
	_music.stream        = load(path)
	_music.stream.loop   = true
	_music.play()
	_current_track       = track_name


func stop_music():
	_music.stop()
	_current_track = ""


func set_music_volume(v: float):
	music_volume = clampf(v, 0.0, 1.0)
	_apply_music_volume()
	_save_volume()


func set_sfx_volume(v: float):
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_sfx_volume()
	_save_volume()


func play_sfx(sfx_name: String):
	var path := SFX_PATH + sfx_name + ".ogg"
	if not ResourceLoader.exists(path):
		path = SFX_PATH + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.play()


func _apply_music_volume():
	_music.volume_db = linear_to_db(music_volume) if music_volume > 0.0 else -80.0


func _apply_sfx_volume():
	_sfx.volume_db = linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0
