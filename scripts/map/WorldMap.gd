@tool
extends Control

const MAP_NODE_SCENE := preload("res://scenes/map/MapNode.tscn")

@export_group("Map Editor Tools")

@export var load_map_from_json: bool = false:
	set(value):
		load_map_from_json = false
		if value and Engine.is_editor_hint():
			load_positions_from_json()

@export var save_map_to_json: bool = false:
	set(value):
		save_map_to_json = false
		if value and Engine.is_editor_hint():
			save_positions_to_json()


@onready var map_nodes: Control = $MapNodes
@onready var gold_label: Label = $TopBar/GoldDisplay/Label
@onready var home_button: Button = $TopBar/HomeButton
@onready var map_button: Button = $TopBar/MapButton
@onready var pokedex_button: Button = $TopBar/PokedexButton
@onready var team_button: Button = $TopBar/TeamButton
@onready var shop_button: Button = $TopBar/ShopButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var inventory_button: Button = $TopBar/InventoryButton
@onready var inventory_panel: ColorRect = $InventoryPanel
@onready var inv_close_button: Button = $InventoryPanel/CloseButton

@onready var map_slot_one: TextureRect = $BottomSlotBar/MapSlotOne
@onready var map_slot_two: TextureRect = $BottomSlotBar/MapSlotTwo
@onready var map_slot_three: TextureRect = $BottomSlotBar/MapSlotThree

var _mogadex:  Node = null
var _shop:     Node = null
var _settings: Node = null

func _ready():
	home_button.pressed.connect(_on_home_pressed)
	map_button.pressed.connect(_on_map_pressed)
	pokedex_button.pressed.connect(_on_pokedex_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	inv_close_button.pressed.connect(_on_inventory_close_pressed)
	home_button.focus_mode = Control.FOCUS_NONE
	map_button.focus_mode = Control.FOCUS_NONE

	_mogadex = load("res://scripts/ui/MogadexPanel.gd").new()
	_shop    = load("res://scripts/ui/ShopPanel.gd").new()
	add_child(_shop)
	_shop.closed.connect(func(): _shop.visible = false)

	_settings = load("res://scripts/ui/SettingsPanel.gd").new()
	add_child(_settings)

	add_child(_mogadex)
	_mogadex.visible = false
	_mogadex.closed.connect(func(): _mogadex.visible = false)
	_mogadex.team_changed.connect(update_team_slots)

	if not Engine.is_editor_hint():
		# Hide editor-only bezier handles at runtime
		for map_node in map_nodes.get_children():
			var cc := map_node.get_node_or_null("CurveControl")
			if cc: cc.visible = false

		update_team_slots()
		update_gold_display()

	_apply_nav_icons()
	build_map()


func _apply_nav_icons():
	var nav: Array = [
		[home_button,      "res://assets/ui/icon_home.png"],
		[map_button,       "res://assets/ui/icon_map.png"],
		[pokedex_button,   "res://assets/ui/icon_mogadex.png"],
		[inventory_button, "res://assets/ui/icon_inventory.png"],
		[shop_button,      "res://assets/ui/icon_shop.png"],
		[settings_button,  "res://assets/ui/icon_settings.png"],
	]
	const BTN_SIZE := 62
	const GAP     := 8
	const START_X := 12
	const TOP_Y   := 4
	for i in nav.size():
		var btn: Button  = nav[i][0]
		var path: String = nav[i][1]
		if FileAccess.file_exists(path):
			btn.icon        = load(path)
			btn.expand_icon = true
		btn.text                = ""
		btn.flat                = true
		btn.focus_mode          = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.size                = Vector2(BTN_SIZE, BTN_SIZE)
		btn.position            = Vector2(START_X + i * (BTN_SIZE + GAP), TOP_Y)


var _slot_refresh_timer: float = 0.0

func _process(delta):
	if Engine.is_editor_hint():
		if has_node("PathDots"):
			$PathDots.queue_redraw()
		return
	# Poll fainted monsters once per second and auto-recover if time has elapsed
	_slot_refresh_timer += delta
	if _slot_refresh_timer >= 1.0:
		_slot_refresh_timer = 0.0
		var team: Array = SaveData.data.get("team", [])
		for mid in team:
			if SaveData.get_instance_fainted(str(mid), 0):
				var elapsed: float = Time.get_unix_time_from_system() - SaveData.get_instance_sleep_start(str(mid), 0)
				if elapsed >= 30.0:
					SaveData.set_instance_fainted(str(mid), 0, false)
					SaveData.set_instance_pp(str(mid), 0, {})
					var _md := GameData.get_monster(str(mid))
					var _lvl := SaveData.get_instance_level(str(mid), 0)
					var _gr  := GameData.get_growth(str(mid))
					var _max_hp := int(_md.get("hp", 100)) + (_lvl - 1) * int(_gr.get("hp", 8))
					SaveData.set_instance_current_hp(str(mid), 0, _max_hp)
		update_team_slots()


func _draw_path(drawer: CanvasItem):
	var node_info: Dictionary = {}

	if Engine.is_editor_hint():
		var chain: Dictionary = {}
		var jf := FileAccess.open("res://data/levels.json", FileAccess.READ)
		if jf:
			var jp := JSON.new()
			if jp.parse(jf.get_as_text()) == OK and jp.data is Dictionary:
				for lid in jp.data.keys():
					chain[lid] = _unlock_list(jp.data[lid].get("unlock_after_win", []))
		for node in map_nodes.get_children():
			if node is Control and node.name.begins_with("MapNode"):
				var num := int(node.name.replace("MapNode", ""))
				var lid := "level_%d" % num
				var base_pos: Vector2 = node.position
				var default_cp_pos: Vector2 = base_pos + Vector2(32, 32) + Vector2(0, -50)
				var legacy_cp := node.get_node_or_null("CurveControl")
				if legacy_cp:
					default_cp_pos = base_pos + legacy_cp.position + Vector2(8, 8)
				var per_target: Dictionary = {}
				for child in node.get_children():
					var cn := str(child.name)
					if cn.begins_with("CurveControl_level_"):
						var target_id := cn.replace("CurveControl_", "")
						per_target[target_id] = base_pos + child.position + Vector2(8, 8)
				node_info[lid] = {
					"pos":         base_pos + Vector2(32.0, 32.0),
					"default_cp":  default_cp_pos,
					"per_target":  per_target,
					"next":        chain.get(lid, [])
				}
	else:
		var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var levels_dict: Dictionary = json.data
				for lid in levels_dict.keys():
					var level: Dictionary = levels_dict[lid]
					var position_data = level.get("position", [0, 0])
					var cp_data = level.get("control_point", [32, -50])
					var bx := float(position_data[0])
					var by := float(position_data[1])
					var default_cp := Vector2(bx + float(cp_data[0]) + 8.0, by + float(cp_data[1]) + 8.0)
					var per_target: Dictionary = {}
					var raw_cps = level.get("control_points", {})
					if raw_cps is Dictionary:
						for k in raw_cps.keys():
							var arr = raw_cps[k]
							if arr is Array and arr.size() >= 2:
								per_target[str(k)] = Vector2(bx + float(arr[0]) + 8.0, by + float(arr[1]) + 8.0)
					node_info[lid] = {
						"pos":         Vector2(bx + 32.0, by + 32.0),
						"default_cp":  default_cp,
						"per_target":  per_target,
						"next":        _unlock_list(level.get("unlock_after_win", []))
					}

	for lid in node_info.keys():
		var info: Dictionary = node_info[lid]
		for next_id in info.next:
			if node_info.has(next_id):
				var cp: Vector2 = info.per_target.get(next_id, info.default_cp)
				_draw_dots_between_curvy(drawer, info.pos, cp, node_info[next_id].pos)


# Coerce string|Array|null → Array of level ids
func _unlock_list(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			var s := str(x)
			if s != "": out.append(s)
	elif v is String and v != "":
		out.append(v)
	return out


func _draw_dots_between_curvy(drawer: CanvasItem, p0: Vector2, cp: Vector2, p2: Vector2):
	var sample_points = []
	var num_samples = 10
	for i in range(num_samples + 1):
		var t = float(i) / float(num_samples)
		var t_inv = 1.0 - t
		var pos = (t_inv * t_inv * p0) + (2.0 * t_inv * t * cp) + (t * t * p2)
		sample_points.append(pos)

	var total_length = 0.0
	for i in range(num_samples):
		total_length += sample_points[i].distance_to(sample_points[i+1])

	var dot_spacing = 30.0
	var num_dots = int(total_length / dot_spacing)

	for i in range(1, num_dots):
		var t = float(i) / float(num_dots)
		var t_inv = 1.0 - t
		var dot_pos = (t_inv * t_inv * p0) + (2.0 * t_inv * t * cp) + (t * t * p2)
		drawer.draw_circle(dot_pos, 4.0, Color(1, 1, 1, 1))


func build_map():
	if Engine.is_editor_hint():
		return

	for child in map_nodes.get_children():
		child.queue_free()

	var levels = []

	var file = FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var levels_dict = json.data
			for level_id in levels_dict.keys():
				var level = levels_dict[level_id].duplicate(true)
				level["id"] = level_id
				levels.append(level)
			levels.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	if not Engine.is_editor_hint():
		update_gold_display()

	for level in levels:
		var level_id = level["id"]
		var position_data = level.get("position", [0, 0])

		var node = MAP_NODE_SCENE.instantiate()
		map_nodes.add_child(node)

		if Engine.is_editor_hint():
			node.text = str(int(level.get("order", 0)))
			node.position = Vector2(float(position_data[0]), float(position_data[1]))
		else:
			node.configure(
				level_id,
				level,
				SaveData.is_level_unlocked(level_id),
				SaveData.is_level_completed(level_id)
			)
			node.level_selected.connect(_on_level_selected)


func _on_level_selected(level_id: String):
	# Block battle if every team monster is still recovering
	var team: Array = SaveData.data.get("team", [])
	var any_alive := false
	for mid in team:
		if not SaveData.get_instance_fainted(str(mid), 0):
			any_alive = true
			break
	if not any_alive:
		_show_all_fainted_msg()
		return
	GameState.start_level(level_id)


func _show_all_fainted_msg():
	var team: Array = SaveData.data.get("team", [])
	var min_secs := 99
	for mid in team:
		var elapsed := Time.get_unix_time_from_system() - SaveData.get_instance_sleep_start(str(mid), 0)
		var left := maxi(0, int(30.0 - elapsed))
		if left < min_secs:
			min_secs = left
	var msg := Label.new()
	msg.text = "All monsters are recovering!\nReady in %d seconds..." % min_secs
	msg.z_index = 200
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.size = Vector2(700, 80)
	msg.position = Vector2(610, 460)
	add_child(msg)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(msg, "modulate:a", 0.0, 0.60).set_delay(2.5)
	tw.tween_callback(msg.queue_free).set_delay(3.1)


func _on_home_pressed():
	GameState.go_home()


func _on_map_pressed():
	pass


func update_team_slots():
	var slots = [map_slot_one, map_slot_two, map_slot_three]
	var team  = SaveData.data.get("team", [])

	for i in range(slots.size()):
		var slot: TextureRect = slots[i]

		var old_lbl := slot.get_parent().get_node_or_null("SleepOverlay_%d" % i)
		if old_lbl: old_lbl.queue_free()

		var placeholder_path := "res://assets/ui/placeholder_slot.png"
		if not FileAccess.file_exists(placeholder_path):
			placeholder_path = "res://assets/ui/slot_clean.png"
		slot.texture = load(placeholder_path)
		slot.modulate = Color.WHITE

		if i >= team.size():
			continue

		var mid: String = str(team[i])
		var monster_data := GameData.get_monster(mid)
		var icon_path: String = monster_data.get("icon", monster_data.get("sprite", ""))
		if icon_path != "" and FileAccess.file_exists(icon_path):
			slot.texture      = load(icon_path)
			slot.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

		if SaveData.get_instance_fainted(mid, 0):
			slot.modulate = Color(0.40, 0.40, 0.55, 0.80)
			var sleep_start: float = SaveData.get_instance_sleep_start(mid, 0)
			var secs_left: int = maxi(0, int(30.0 - (Time.get_unix_time_from_system() - sleep_start)))
			var lbl := Label.new()
			lbl.name = "SleepOverlay_%d" % i
			lbl.text = "💤 %ds" % secs_left
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.add_theme_color_override("font_color", Color(0.55, 0.70, 1.0))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.size        = slot.size
			lbl.z_index     = 5
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.get_parent().add_child(lbl)


func update_gold_display():
	var gold: int = SaveData.data.get("gold", 0)
	_ensure_coin_icon(gold_label)
	gold_label.text = str(gold)


func _ensure_coin_icon(lbl: Label):
	if lbl.get_parent().get_node_or_null("CoinIcon"): return
	var gd := lbl.get_parent()
	gd.offset_left  = 1750.0
	gd.offset_right = 1910.0
	var coin := TextureRect.new()
	coin.name         = "CoinIcon"
	coin.texture      = load("res://assets/ui/coin.png")
	coin.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size         = Vector2(30, 30)
	coin.position     = Vector2(0, 10)
	coin.z_index      = 1
	gd.add_child(coin)
	lbl.offset_left  = 36
	lbl.offset_right = 160
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _on_inventory_pressed():
	UIUtils.update_inventory_ui(inventory_panel)
	inventory_panel.visible = true


func _on_inventory_close_pressed():
	inventory_panel.visible = false


func save_positions_to_json():
	if not Engine.is_editor_hint():
		return

	var nodes = map_nodes.get_children()
	nodes.sort_custom(func(a, b): return int(a.name.replace("MapNode", "")) < int(b.name.replace("MapNode", "")))

	var old_levels_dict = {}
	var file = FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			old_levels_dict = json.data

	var new_levels_dict = {}

	for i in range(nodes.size()):
		var node = nodes[i]
		if node is Control:
			var original_number = int(node.name.replace("MapNode", ""))
			var old_key = "level_" + str(original_number)

			var level_data = {}
			if old_levels_dict.has(old_key):
				level_data = old_levels_dict[old_key].duplicate(true)
			else:
				level_data = {
					"name": "Level " + str(i + 1),
					"enemy_team": ["monster_1"],
					"reward_gold": 10
				}

			level_data["position"] = [int(node.position.x), int(node.position.y)]
			level_data["order"] = float(i + 1)
			if not level_data.has("unlock_after_win"):
				level_data["unlock_after_win"] = []

			var cp = node.get_node_or_null("CurveControl")
			if cp:
				level_data["control_point"] = [int(cp.position.x), int(cp.position.y)]
			var per_target_cps: Dictionary = {}
			for child in node.get_children():
				var cn := str(child.name)
				if cn.begins_with("CurveControl_level_"):
					var target_id := cn.replace("CurveControl_", "")
					per_target_cps[target_id] = [int(child.position.x), int(child.position.y)]
			if not per_target_cps.is_empty():
				level_data["control_points"] = per_target_cps

			var new_key = "level_" + str(i + 1)
			new_levels_dict[new_key] = level_data

	var abs_write: String = ProjectSettings.globalize_path("res://data/levels.json")
	var file_write = FileAccess.open(abs_write, FileAccess.WRITE)
	if file_write:
		file_write.store_string(JSON.stringify(new_levels_dict, "\t"))
		print("Saved " + str(nodes.size()) + " map positions to levels.json!")
	else:
		push_error("Cannot write levels.json — check file permissions")


func load_positions_from_json():
	if not Engine.is_editor_hint():
		return

	for child in map_nodes.get_children():
		child.queue_free()
		map_nodes.remove_child(child)

	var file = FileAccess.open("res://data/levels.json", FileAccess.READ)
	if not file: return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	var levels_dict = json.data

	var sorted_levels = []
	for level_id in levels_dict.keys():
		var level = levels_dict[level_id].duplicate()
		level["id"] = level_id
		sorted_levels.append(level)
	sorted_levels.sort_custom(func(a, b): return int(a.get("order", 0)) < int(b.get("order", 0)))

	for i in range(sorted_levels.size()):
		var level = sorted_levels[i]
		var pos = level.get("position", [0, 0])

		var node = MAP_NODE_SCENE.instantiate()
		node.name = "MapNode" + str(i + 1)
		map_nodes.add_child(node)
		node.position = Vector2(float(pos[0]), float(pos[1]))
		node.text = str(int(level.get("order", 0)))

		var cp = ColorRect.new()
		cp.name = "CurveControl"
		cp.size = Vector2(16, 16)
		cp.color = Color(1, 0.3, 0.3, 0.8)
		node.add_child(cp)

		var cp_pos = level.get("control_point", [32, -50])
		cp.position = Vector2(float(cp_pos[0]), float(cp_pos[1]))

		if get_tree() and get_tree().edited_scene_root:
			node.owner = get_tree().edited_scene_root
			cp.owner = get_tree().edited_scene_root

	print("Loaded " + str(sorted_levels.size()) + " nodes from JSON into editor!")


func _on_pokedex_pressed():
	if _mogadex:
		_mogadex.open()


func _on_pokedex_close_pressed():
	if _mogadex:
		_mogadex.visible = false


func _on_shop_pressed():
	if _shop: _shop.open()


func _on_settings_pressed():
	if _settings: _settings.open()


func _on_add_to_team(monster_id: String):
	var team = SaveData.get_team()
	if team.size() >= 3:
		return
	team.append(monster_id)
	SaveData.data["team"] = team
	SaveData.save()
	update_team_slots()


func _on_remove_from_team(monster_id: String):
	var team = SaveData.get_team()
	team.erase(monster_id)
	SaveData.data["team"] = team
	SaveData.save()
	update_team_slots()
