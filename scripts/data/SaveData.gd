extends Node

var current_slot: int = 0
var save_path: String:
	get: return "user://save_slot_%d.json" % current_slot
var MAX_LEVEL: int:
	get: return int(GameData.prog_cfg("max_level", 50))

var data: Dictionary = {}


func _ready():
	_load_slot_from_settings()
	load_save()
	give_monster("alyx")


func set_slot(slot_idx: int):
	current_slot = clampi(slot_idx, 0, 2)
	load_save()
	give_monster("alyx")


func _load_slot_from_settings():
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	if json.data is Dictionary:
		current_slot = clampi(int(json.data.get("current_slot", 0)), 0, 2)


func get_default_save() -> Dictionary:
	return {
		"gold": 50000,
		"unlocked_levels": ["level_1"],
		"completed_levels": [],
		"caught_monsters": ["alyx"],
		"team": ["alyx"],
		"inventory": {"star_seed": 1000, "40hp_potion": 10, "250hp_potion": 5, "revive_potion": 5, "exp_booster": 5, "evolve_potion": 10, "pp_restore": 3},
		"monster_instances": {"alyx": [{"lvl": 1, "xp": 0}]},
	}


func _ensure_instances(species_id: String):
	if not data.has("monster_instances"):
		data["monster_instances"] = {}
	var inst: Dictionary = data["monster_instances"]
	if not inst.has(species_id):
		var count := 0
		for m in data.get("caught_monsters", []):
			if str(m) == species_id:
				count += 1
		var legacy_lvl: int = data.get("monster_levels", {}).get(species_id, 1)
		var legacy_xp:  int = data.get("monster_xp",     {}).get(species_id, 0)
		var arr: Array = []
		# count = 0 for uncaught enemies — empty array, no phantom instance
		for i in count:
			arr.append({"lvl": legacy_lvl if i == 0 else 1, "xp": legacy_xp if i == 0 else 0})
		inst[species_id] = arr


func get_all_instances(species_id: String) -> Array:
	_ensure_instances(species_id)
	return data["monster_instances"].get(species_id, [])


func get_instance_count(species_id: String) -> int:
	return get_all_instances(species_id).size()


func get_instance_level(species_id: String, idx: int = 0) -> int:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size():
		return 1
	return int(arr[idx].get("lvl", 1))


func get_instance_xp(species_id: String, idx: int = 0) -> int:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size():
		return 0
	return int(arr[idx].get("xp", 0))


func set_instance_level(species_id: String, idx: int, level: int):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["lvl"] = clampi(level, 1, MAX_LEVEL)
	save()


func set_instance_xp(species_id: String, idx: int, xp: int):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["xp"] = xp
	save()


func get_instance_custom_name(species_id: String, idx: int = 0) -> String:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return ""
	return str(arr[idx].get("custom_name", ""))


# Returns -1 if HP was never set (treat as full HP)
func get_instance_current_hp(species_id: String, idx: int = 0) -> int:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return -1
	return int(arr[idx].get("current_hp", -1))


func set_instance_current_hp(species_id: String, idx: int, hp: int):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["current_hp"] = hp
	save()


# Returns {} if PP was never set (treat as fresh PP)
func get_instance_pp(species_id: String, idx: int = 0) -> Dictionary:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return {}
	var pp = arr[idx].get("pp", {})
	return pp if pp is Dictionary else {}


func set_instance_pp(species_id: String, idx: int, pp_dict: Dictionary):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["pp"] = pp_dict
	save()


func get_instance_fainted(species_id: String, idx: int = 0) -> bool:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return false
	return bool(arr[idx].get("fainted", false))


func set_instance_fainted(species_id: String, idx: int, val: bool):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["fainted"] = val
		if val:
			arr[idx]["sleep_start"] = Time.get_unix_time_from_system()
		else:
			arr[idx].erase("sleep_start")
	save()


func get_instance_sleep_start(species_id: String, idx: int = 0) -> float:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return 0.0
	return float(arr[idx].get("sleep_start", 0.0))


func get_instance_roaming(species_id: String, idx: int = 0) -> bool:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return false
	# First instance of first-caught species roams by default
	if not arr[idx].has("roaming"):
		return idx == 0
	return bool(arr[idx].get("roaming", false))


func set_instance_roaming(species_id: String, idx: int, val: bool):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["roaming"] = val
	save()


func set_instance_custom_name(species_id: String, new_name: String, idx: int = 0):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["custom_name"] = new_name
	save()


# Returns the 4 active move IDs for this instance. Bootstraps from learnset on first call.
func get_active_moves(species_id: String, idx: int = 0) -> Array:
	var arr: Array = get_all_instances(species_id)
	if idx >= arr.size(): return GameData.get_monster(species_id).get("moves", [])
	var saved: Array = arr[idx].get("active_moves", [])
	if not saved.is_empty(): return saved
	var level: int = int(arr[idx].get("lvl", 1))
	var available: Array = GameData.get_available_moves(species_id, level)
	var initial: Array = available.slice(0, mini(4, available.size()))
	# Persist so subsequent calls don't re-bootstrap
	arr[idx]["active_moves"] = initial
	return initial


func set_active_moves(species_id: String, moves: Array, idx: int = 0):
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr[idx]["active_moves"] = moves
	save()


# Called on level-up: auto-equips new moves if fewer than 4 slots are used.
# Returns {"equipped": [...], "learned": [...]} so the caller can notify the player.
func apply_new_moves_on_levelup(species_id: String, new_level: int, idx: int = 0) -> Dictionary:
	var newly_learned: Array = GameData.get_new_moves_at_level(species_id, new_level)
	if newly_learned.is_empty(): return {"equipped": [], "learned": []}
	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx >= arr.size(): return {"equipped": [], "learned": []}
	var active: Array = get_active_moves(species_id, idx)
	var equipped: Array = []
	var learned_only: Array = []
	for mv: String in newly_learned:
		if mv not in active:
			if active.size() < 4:
				active.append(mv)
				equipped.append(mv)
			else:
				learned_only.append(mv)
	arr[idx]["active_moves"] = active
	save()
	return {"equipped": equipped, "learned": learned_only}


func add_instance(species_id: String, level: int = 1, xp: int = 0):
	if not data.has("monster_instances"):
		data["monster_instances"] = {}
	if not data["monster_instances"].has(species_id):
		data["monster_instances"][species_id] = []
	data["monster_instances"][species_id].append({"lvl": level, "xp": xp})


func remove_instance(species_id: String, idx: int):
	# Remove nth occurrence from the caught_monsters string array
	var caught: Array = data.get("caught_monsters", [])
	var n := 0
	for i in caught.size():
		if str(caught[i]) == species_id:
			if n == idx:
				caught.remove_at(i)
				break
			n += 1
	data["caught_monsters"] = caught

	_ensure_instances(species_id)
	var arr: Array = data["monster_instances"][species_id]
	if idx < arr.size():
		arr.remove_at(idx)
	data["monster_instances"][species_id] = arr

	save()


func xp_needed_for_level(level: int) -> int:
	return int(pow(level, 1.6) * 60)  # ~60 at lv1, ~2400 at lv50


func get_monster_level(species_id: String) -> int:
	return get_instance_level(species_id, 0)


func get_monster_xp(species_id: String) -> int:
	return get_instance_xp(species_id, 0)


func set_monster_level(species_id: String, level: int):
	set_instance_level(species_id, 0, level)


func set_monster_xp(species_id: String, xp: int):
	set_instance_xp(species_id, 0, xp)


func add_monster_to_caught(monster_id: String, starting_level: int = 1):
	if not data.has("caught_monsters"):
		data["caught_monsters"] = []
	data["caught_monsters"].append(monster_id)
	add_instance(monster_id, starting_level, 0)
	save()


func add_monster_to_team(monster_id: String, starting_level: int = 1):
	if not data.has("team"):
		data["team"] = []
	if data["team"].size() < 3:
		data["team"].append(monster_id)
	add_monster_to_caught(monster_id, starting_level)


func give_monster(monster_id: String):
	var caught: Array = data.get("caught_monsters", [])
	if not monster_id in caught:
		caught.append(monster_id)
		data["caught_monsters"] = caught
		var team: Array = data.get("team", [])
		if team.size() < 3:
			team.append(monster_id)
			data["team"] = team
		add_instance(monster_id, 1, 0)
		save()


func get_inventory_item(item_id: String) -> int:
	return data.get("inventory", {}).get(item_id, 0)


func use_inventory_item(item_id: String) -> bool:
	var inv: Dictionary = data.get("inventory", {})
	var count: int = inv.get(item_id, 0)
	if count > 0:
		inv[item_id] = count - 1
		data["inventory"] = inv
		save()
		return true
	return false


func add_inventory_item(item_id: String, amount: int):
	var inv: Dictionary = data.get("inventory", {})
	inv[item_id] = inv.get(item_id, 0) + amount
	data["inventory"] = inv
	save()


func load_save():
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		data = get_default_save()
		save()
		return
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK or not (json.data is Dictionary):
		data = get_default_save()
		save()
		return
	data = json.data
	ensure_defaults()
	_migrate_instances()
	_clean_doge()
	# Always guarantee level_1 is accessible regardless of save state
	if not data.get("unlocked_levels", []).has("level_1"):
		data["unlocked_levels"].append("level_1")
		save()


func _migrate_instances():
	# Build monster_instances from legacy data if missing
	if not data.has("monster_instances"):
		data["monster_instances"] = {}
		var caught: Array = data.get("caught_monsters", [])
		var counts: Dictionary = {}
		for m in caught:
			var s := str(m)
			counts[s] = counts.get(s, 0) + 1
		for species in counts.keys():
			var lvl: int = data.get("monster_levels", {}).get(species, 1)
			var xp: int  = data.get("monster_xp",     {}).get(species, 0)
			var arr: Array = []
			for i in counts[species]:
				arr.append({"lvl": lvl if i == 0 else 1, "xp": xp if i == 0 else 0})
			data["monster_instances"][species] = arr
		save()

	# Patch instances missing "current_hp" (old saves before the field was added)
	var _patched := false
	for species in data["monster_instances"].keys():
		var arr: Array = data["monster_instances"][species]
		for inst in arr:
			if not inst.has("current_hp"):
				inst["current_hp"] = 0   # 0 → Monster.gd reads as full HP
				_patched = true
	if _patched:
		save()


func _clean_doge():
	# Strip legacy "doge" entries — run once per load
	var caught: Array = data.get("caught_monsters", [])
	if "doge" not in caught:
		return
	data["caught_monsters"] = caught.filter(func(m): return str(m) != "doge")
	var team: Array = data.get("team", [])
	data["team"] = team.filter(func(m): return str(m) != "doge")
	if data.has("monster_instances"):
		data["monster_instances"].erase("doge")
	save()


func ensure_defaults():
	var defaults := get_default_save()
	for key in defaults.keys():
		if not data.has(key):
			data[key] = defaults[key]


func save():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % save_path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func reset_save():
	data = get_default_save()
	save()


func is_level_unlocked(level_id: String) -> bool:
	return data.get("unlocked_levels", []).has(level_id)


func is_level_completed(level_id: String) -> bool:
	return data.get("completed_levels", []).has(level_id)


func complete_level(level_id: String):
	var first_clear: bool = not data["completed_levels"].has(level_id)
	if first_clear:
		data["completed_levels"].append(level_id)
	var level_data := GameData.get_level(level_id)
	if first_clear:
		data["gold"] = int(data.get("gold", 0)) + int(level_data.get("reward_gold", 0))
	var next_raw = level_data.get("unlock_after_win", [])
	var next_list: Array = []
	if next_raw is Array:
		next_list = next_raw
	elif next_raw is String and next_raw != "":
		next_list = [next_raw]
	for next_level in next_list:
		var lid := str(next_level)
		if lid != "" and not data["unlocked_levels"].has(lid):
			data["unlocked_levels"].append(lid)
	save()


func get_team() -> Array:
	return data.get("team", [])


# e.g. team=["alyx","beefee","alyx"]: slot 0→idx 0, slot 1→idx 0, slot 2→idx 1
func get_team_instance_idx(team_slot: int) -> int:
	var team := get_team()
	if team_slot >= team.size(): return 0
	var species := str(team[team_slot])
	var count := 0
	for i in team_slot:
		if str(team[i]) == species:
			count += 1
	return count


func get_first_team_monster() -> String:
	var team := get_team()
	return str(team[0]) if not team.is_empty() else "alyx"
