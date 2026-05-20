extends Node

const MONSTERS_PATH    := "res://data/monsters.json"
const MOVES_PATH       := "res://data/moves.json"
const LEVELS_PATH      := "res://data/levels.json"
const ITEMS_PATH       := "res://data/items.json"
const GAME_CONFIG_PATH := "res://data/game_config.json"

var monsters: Dictionary = {}
var moves:    Dictionary = {}
var levels:   Dictionary = {}
var items:    Dictionary = {}
var config:   Dictionary = {}

var ELEMENTS:          Array      = []
var ELEMENT_COLORS:    Dictionary = {}
var ELEMENT_ICONS:     Dictionary = {}
var ELEMENT_TEXTURES:  Dictionary = {}


func _ready():
	reload()


func reload():
	monsters = _load_json(MONSTERS_PATH)
	moves    = _load_json(MOVES_PATH)
	levels   = _load_json(LEVELS_PATH)
	items    = _load_json(ITEMS_PATH)
	config   = _load_json(GAME_CONFIG_PATH)
	_cache_config()


func _cache_config():
	ELEMENT_COLORS   = {}
	ELEMENT_ICONS    = {}
	ELEMENT_TEXTURES = {}
	var ec: Dictionary = config.get("element_colors",     {})
	var ei: Dictionary = config.get("element_icons",      {})
	var ef: Dictionary = config.get("element_icon_files", {})
	ELEMENTS = ec.keys()
	for elem in ELEMENTS:
		var raw: Array = ec.get(elem, [0.5, 0.5, 0.5])
		ELEMENT_COLORS[elem] = Color(raw[0], raw[1], raw[2])
		ELEMENT_ICONS[elem]  = ei.get(elem, "◆")
		var path: String = ef.get(elem, "")
		if path != "" and ResourceLoader.exists(path):
			ELEMENT_TEXTURES[elem] = load(path) as Texture2D


func get_monster(id: String) -> Dictionary:
	return monsters.get(id, {})

func get_move(id: String) -> Dictionary:
	return moves.get(id, {})

func get_level(id: String) -> Dictionary:
	return levels.get(id, {})

func get_item(id: String) -> Dictionary:
	var it: Dictionary = items.get(id, {}).duplicate()
	it["id"] = id
	return it

func get_levels_sorted() -> Array:
	var result: Array = []
	for level_id in levels.keys():
		var lvl: Dictionary = levels[level_id].duplicate(true)
		lvl["id"] = level_id
		result.append(lvl)
	result.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))
	return result


func get_shop_items() -> Array:
	var result: Array = []
	for id in items.keys():
		var it: Dictionary = items[id].duplicate()
		if int(it.get("shop_price", 0)) > 0:
			it["id"] = id
			result.append(it)
	result.sort_custom(func(a, b): return int(a.get("shop_price", 0)) < int(b.get("shop_price", 0)))
	return result

func get_battle_items() -> Array:
	var result: Array = []
	for id in items.keys():
		var it: Dictionary = items[id].duplicate()
		if it.get("usable_in_battle", false):
			it["id"] = id
			result.append(it)
	return result


func get_effectiveness(attacker: String, defender: String) -> float:
	var chart: Dictionary = config.get("effectiveness", {})
	if attacker in chart and defender in chart[attacker]:
		return float(chart[attacker][defender])
	return 1.0

func battle_cfg(key: String, default = null):
	return config.get("battle", {}).get(key, default)

func prog_cfg(key: String, default = null):
	return config.get("progression", {}).get(key, default)

func rarity_cfg(rarity: String) -> Dictionary:
	return config.get("rarities", {}).get(rarity.to_lower(),
		{"capture_rate": 1.0, "color": [0.65, 0.70, 0.75]})

func rarity_color(rarity: String) -> Color:
	var raw: Array = rarity_cfg(rarity).get("color", [0.65, 0.70, 0.75])
	return Color(raw[0], raw[1], raw[2])

func get_element_texture(elem: String) -> Texture2D:
	return ELEMENT_TEXTURES.get(elem, null)


func get_growth(monster_id: String) -> Dictionary:
	var m := get_monster(monster_id)
	if m.has("growth"):
		return m["growth"]
	return prog_cfg("default_stat_growth", {"hp": 8, "attack": 2, "defense": 1, "speed": 1})


func get_available_moves(monster_id: String, level: int) -> Array:
	var learnset: Array = get_monster(monster_id).get("learnset", [])
	if learnset.is_empty():
		return get_monster(monster_id).get("moves", [])
	var learned: Array = []
	for entry: Dictionary in learnset:
		if int(entry.get("level", 99)) <= level:
			var mv: String = entry.get("move", "")
			if mv != "" and mv not in learned:
				learned.append(mv)
	return learned


func get_new_moves_at_level(monster_id: String, level: int) -> Array:
	var learnset: Array = get_monster(monster_id).get("learnset", [])
	var newly: Array = []
	for entry: Dictionary in learnset:
		if int(entry.get("level", 0)) == level:
			var mv: String = entry.get("move", "")
			if mv != "":
				newly.append(mv)
	return newly


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: cannot open %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("GameData: JSON error in %s — %s" % [path, json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		push_error("GameData: %s must be a JSON object" % path)
		return {}
	return json.data
