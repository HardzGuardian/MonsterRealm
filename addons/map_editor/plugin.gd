@tool
extends EditorPlugin

const LEVELS_PATH := "res://data/levels.json"
const MAP_NODE_SCENE := "res://scenes/map/MapNode.tscn"

var _dock: VBoxContainer
var _info_label: Label
var _source_label: Label
var _connect_source: int = 0


func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)
	get_editor_interface().get_selection().selection_changed.connect(_refresh_status)
	_refresh_status()
	print("[MapEditor] Plugin loaded — see 'Map Editor' dock")


func _exit_tree() -> void:
	if get_editor_interface().get_selection().selection_changed.is_connected(_refresh_status):
		get_editor_interface().get_selection().selection_changed.disconnect(_refresh_status)
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()


func _build_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "Map Editor"
	_dock.add_theme_constant_override("separation", 6)
	_dock.custom_minimum_size = Vector2(220, 0)

	var title := Label.new()
	title.text = "MAP EDITOR"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_dock.add_child(title)

	_info_label = Label.new()
	_info_label.text = "Selected: (none)"
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(_info_label)

	_source_label = Label.new()
	_source_label.text = "Branch source: (none)"
	_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_dock.add_child(_source_label)

	_dock.add_child(HSeparator.new())

	_add_section("Create")
	_add_btn("Create Next Node",
		"Make new MapNode at the end of chain (max+1).\nLinks selected node → new node.",
		_action_create_next)

	_dock.add_child(HSeparator.new())
	_add_section("Delete")
	_add_btn("Delete & Relink Selected",
		"Remove selected MapNode from scene + levels.json.\nAll its predecessors get repointed to its successor.",
		_action_delete_relink)

	_dock.add_child(HSeparator.new())
	_add_section("Branch (two-step)")
	_add_btn("1. Set SOURCE = Selected",
		"Mark the selected node as the source for the next connect.",
		_action_set_source)
	_add_btn("2. Connect SOURCE → Selected",
		"Adds Selected to SOURCE's outgoing links (branching).",
		_action_connect)
	_add_btn("Disconnect SOURCE ✗→ Selected",
		"Removes the SOURCE → Selected link if it exists.",
		_action_disconnect)
	_add_btn("Clear Source", "", _action_clear_source)

	_dock.add_child(HSeparator.new())
	_add_section("Maintenance")
	_add_btn("Renumber Chain from level_1",
		"Walks unlock_after_win chain and renames everything contiguously.",
		_action_renumber)
	_add_btn("Refresh Path Dots", "", _action_refresh)

	_dock.add_child(HSeparator.new())
	_add_section("Danger Zone")
	var reset_btn := Button.new()
	reset_btn.text = "⚠  Reset Map (start from 1)"
	reset_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset_btn.tooltip_text = "Deletes ALL MapNodes and rewrites levels.json with a single fresh level_1."
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	reset_btn.pressed.connect(_action_reset_prompt)
	_dock.add_child(reset_btn)


func _add_section(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	_dock.add_child(l)


func _add_btn(text: String, tooltip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.tooltip_text = tooltip
	b.pressed.connect(cb)
	_dock.add_child(b)


func _refresh_status() -> void:
	if _info_label == null:
		return
	var sel := _selected_map_num()
	_info_label.text = "Selected: (none)" if sel == 0 else "Selected: MapNode%d" % sel
	_source_label.text = "Branch source: (none)" if _connect_source == 0 else "Branch source: MapNode%d" % _connect_source


func _selected_map_num() -> int:
	for n in get_editor_interface().get_selection().get_selected_nodes():
		if n.name.begins_with("MapNode"):
			var num := int(n.name.replace("MapNode", ""))
			if num > 0:
				return num
	return 0


func _get_map_nodes_parent() -> Node:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		_warn("No scene open"); return null
	var mn: Node = root.get_node_or_null("MapNodes")
	if mn == null:
		_warn("MapNodes node not found in current scene"); return null
	return mn


func _build_node_map(mn: Node) -> Dictionary:
	var node_map: Dictionary = {}
	for child in mn.get_children():
		if child.name.begins_with("MapNode"):
			var n := int(child.name.replace("MapNode", ""))
			if n > 0:
				node_map[n] = child
	return node_map


func _refresh_path_dots() -> void:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null: return
	var dots: Node = root.get_node_or_null("PathDots")
	if dots == null:
		for child in root.get_children():
			var nested := child.get_node_or_null("PathDots")
			if nested:
				dots = nested
				break
	if dots and dots.has_method("queue_redraw"):
		dots.queue_redraw()


func _load_levels() -> Dictionary:
	var abs_path := ProjectSettings.globalize_path(LEVELS_PATH)
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		_err("Cannot read " + abs_path); return {}
	var jp := JSON.new()
	var txt := f.get_as_text()
	f = null
	if jp.parse(txt) != OK or not (jp.data is Dictionary):
		_err("levels.json parse failed"); return {}
	return jp.data


func _save_levels(lv: Dictionary) -> bool:
	var abs_path := ProjectSettings.globalize_path(LEVELS_PATH)
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		_err("Cannot write " + abs_path); return false
	f.store_string(JSON.stringify(lv, "\t"))
	f = null
	_refresh_path_dots()
	return true


func _action_create_next() -> void:
	var source_num := _selected_map_num()
	if source_num == 0:
		_warn("Select a MapNode in the scene tree first"); return

	var mn := _get_map_nodes_parent()
	if mn == null: return
	var node_map := _build_node_map(mn)
	if not node_map.has(source_num):
		_err("MapNode%d not found" % source_num); return

	var source_node: Node = node_map[source_num]
	var max_order: int    = node_map.keys().max()
	var next_order: int   = max_order + 1
	var level_id: String  = "level_%d" % next_order
	var src_id: String    = "level_%d" % source_num

	var lv := _load_levels()
	if lv.is_empty():
		_err("Aborting create — levels.json unreadable"); return

	var root: Node = get_editor_interface().get_edited_scene_root()
	var new_node: Node = (load(MAP_NODE_SCENE) as PackedScene).instantiate()
	new_node.name     = "MapNode%d" % next_order
	new_node.position = source_node.position + Vector2(100, 0)
	mn.add_child(new_node)
	new_node.set_owner(root)
	new_node.set("text", str(next_order))

	_ensure_curve_control(source_node, level_id, Vector2(50, -30))

	if lv.has(src_id):
		var src_list := _as_unlock_list(lv[src_id].get("unlock_after_win", []))
		if not src_list.has(level_id):
			src_list.append(level_id)
		lv[src_id]["unlock_after_win"] = src_list
	if not lv.has(level_id):
		lv[level_id] = {
			"name":             "Level %d" % next_order,
			"order":            float(next_order),
			"position":         [int(new_node.position.x), int(new_node.position.y)],
			"control_point":    [50, -30],
			"enemy_team":       ["alyx"],
			"enemy_level":      next_order,
			"reward_gold":      10.0,
			"reward_drops":     {},
			"background":       "res://assets/map/map.png",
			"unlock_after_win": []
		}
	_save_levels(lv)

	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(new_node)
	_ok("Created MapNode%d  (added link: MapNode%d → MapNode%d)" % [next_order, source_num, next_order])


func _action_delete_relink() -> void:
	var target := _selected_map_num()
	if target == 0:
		_warn("Select a MapNode in the scene tree first"); return

	var mn := _get_map_nodes_parent()
	if mn == null: return
	var node_map := _build_node_map(mn)
	if not node_map.has(target):
		_err("MapNode%d not found" % target); return

	var lv := _load_levels()
	if lv.is_empty(): return

	var target_id := "level_%d" % target
	var successors: Array = []
	if lv.has(target_id):
		successors = _as_unlock_list(lv[target_id].get("unlock_after_win", []))

	for lid in lv.keys():
		var lst := _as_unlock_list(lv[lid].get("unlock_after_win", []))
		if lst.has(target_id):
			lst.erase(target_id)
			for s in successors:
				if not lst.has(s) and s != lid:
					lst.append(s)
			lv[lid]["unlock_after_win"] = lst
			var pred_num := int(lid.replace("level_", ""))
			if node_map.has(pred_num):
				var pn: Node = node_map[pred_num]
				var old_cc: Node = pn.get_node_or_null("CurveControl_" + target_id)
				if old_cc: old_cc.queue_free()
				for s in successors:
					_ensure_curve_control(pn, s, Vector2(50, -30))

	lv.erase(target_id)
	_save_levels(lv)

	(node_map[target] as Node).queue_free()
	_connect_source = 0
	_refresh_status()
	var succ_txt: String = ", ".join(successors) if successors.size() > 0 else "(end)"
	_ok("Deleted MapNode%d  (predecessors → %s)" % [target, succ_txt])


func _action_set_source() -> void:
	var n := _selected_map_num()
	if n == 0:
		_warn("Select a MapNode in the scene tree first"); return
	_connect_source = n
	_refresh_status()
	_ok("Source set to MapNode%d. Now select target and click Connect." % n)


func _action_connect() -> void:
	if _connect_source == 0:
		_warn("No source set. Use 'Set SOURCE' first."); return
	var target := _selected_map_num()
	if target == 0:
		_warn("Select a target MapNode in the scene tree first"); return
	if target == _connect_source:
		_warn("Source and target are the same"); return

	var lv := _load_levels()
	if lv.is_empty(): return
	var src_id := "level_%d" % _connect_source
	var tgt_id := "level_%d" % target
	if not lv.has(src_id):
		_err("%s not in levels.json" % src_id); return
	var src_list := _as_unlock_list(lv[src_id].get("unlock_after_win", []))
	if src_list.has(tgt_id):
		_warn("%s already links to %s" % [src_id, tgt_id])
	else:
		src_list.append(tgt_id)
		lv[src_id]["unlock_after_win"] = src_list
		var mn := _get_map_nodes_parent()
		if mn:
			var nm := _build_node_map(mn)
			if nm.has(_connect_source):
				_ensure_curve_control(nm[_connect_source], tgt_id, Vector2(50, -30))
		_save_levels(lv)
		_ok("Connected %s → %s" % [src_id, tgt_id])
	_connect_source = 0
	_refresh_status()


func _action_disconnect() -> void:
	if _connect_source == 0:
		_warn("No source set. Use 'Set SOURCE' first."); return
	var target := _selected_map_num()
	if target == 0:
		_warn("Select target MapNode first"); return
	var lv := _load_levels()
	if lv.is_empty(): return
	var src_id := "level_%d" % _connect_source
	var tgt_id := "level_%d" % target
	if not lv.has(src_id):
		_err("%s not in levels.json" % src_id); return
	var src_list := _as_unlock_list(lv[src_id].get("unlock_after_win", []))
	if not src_list.has(tgt_id):
		_warn("%s does not link to %s" % [src_id, tgt_id])
		return
	src_list.erase(tgt_id)
	lv[src_id]["unlock_after_win"] = src_list
	var mn2 := _get_map_nodes_parent()
	if mn2:
		var nm2 := _build_node_map(mn2)
		if nm2.has(_connect_source):
			var ccx: Node = nm2[_connect_source].get_node_or_null("CurveControl_" + tgt_id)
			if ccx:
				ccx.queue_free()
	_save_levels(lv)
	_ok("Disconnected %s ✗→ %s" % [src_id, tgt_id])
	_connect_source = 0
	_refresh_status()


# Add a per-edge CurveControl child named CurveControl_<target_id> if missing
func _ensure_curve_control(source_node: Node, target_id: String, offset: Vector2) -> void:
	var cc_name := "CurveControl_" + target_id
	if source_node.has_node(cc_name):
		return
	var root: Node = get_editor_interface().get_edited_scene_root()
	var cc := ColorRect.new()
	cc.name     = cc_name
	cc.size     = Vector2(16, 16)
	cc.color    = Color(1.0, 0.3, 0.3, 0.9)
	cc.position = offset
	source_node.add_child(cc)
	cc.set_owner(root)


# Coerce string|Array|null → Array[String]
func _as_unlock_list(v) -> Array:
	var out: Array = []
	if v is Array:
		for x in v:
			var s := str(x)
			if s != "": out.append(s)
	elif v is String and v != "":
		out.append(v)
	return out


func _action_clear_source() -> void:
	_connect_source = 0
	_refresh_status()


func _action_renumber() -> void:
	var mn := _get_map_nodes_parent()
	if mn == null: return
	var lv := _load_levels()
	if lv.is_empty(): return

	# BFS from level_1 to handle branches correctly
	var order: Array[String] = []
	var visited := {}
	var queue: Array[String] = ["level_1"]
	while queue.size() > 0:
		var cur: String = queue.pop_front()
		if visited.has(cur) or not lv.has(cur):
			continue
		visited[cur] = true
		order.append(cur)
		for n in _as_unlock_list(lv[cur].get("unlock_after_win", [])):
			queue.append(n)

	var orphans: Array[String] = []
	for lid in lv.keys():
		if not visited.has(lid):
			orphans.append(lid)
	orphans.sort_custom(func(a, b): return int(lv[a].get("order", 0)) < int(lv[b].get("order", 0)))
	for o in orphans:
		order.append(o)

	var remap: Dictionary = {}
	for i in order.size():
		remap[order[i]] = "level_%d" % (i + 1)

	var new_lv: Dictionary = {}
	for i in order.size():
		var old_id := order[i]
		var new_id: String = remap[old_id]
		var entry: Dictionary = (lv[old_id] as Dictionary).duplicate(true)
		entry["order"] = float(i + 1)
		entry["name"]  = "Level %d" % (i + 1)
		var remapped: Array = []
		for nxt in _as_unlock_list(entry.get("unlock_after_win", [])):
			if remap.has(nxt):
				remapped.append(remap[nxt])
		entry["unlock_after_win"] = remapped
		new_lv[new_id] = entry

	_save_levels(new_lv)

	var node_map := _build_node_map(mn)
	for old_id in remap.keys():
		var old_num := int(old_id.replace("level_", ""))
		if node_map.has(old_num):
			node_map[old_num].name = "MapNodeTMP%d" % old_num
	for old_id in remap.keys():
		var old_num := int(old_id.replace("level_", ""))
		var new_num := int((remap[old_id] as String).replace("level_", ""))
		var node: Node = mn.get_node_or_null("MapNodeTMP%d" % old_num)
		if node:
			node.name = "MapNode%d" % new_num
			node.set("text", str(new_num))
			# Two-pass rename to avoid collisions: temp names first, then final
			for child in node.get_children():
				var cn := str(child.name)
				if cn.begins_with("CurveControl_level_"):
					var old_tgt := cn.replace("CurveControl_", "")
					if remap.has(old_tgt):
						child.name = "CurveControlTMP_" + remap[old_tgt]
			for child in node.get_children():
				var cn2 := str(child.name)
				if cn2.begins_with("CurveControlTMP_"):
					child.name = "CurveControl_" + cn2.replace("CurveControlTMP_", "")

	_ok("Renumbered %d levels sequentially from level_1" % order.size())


func _action_refresh() -> void:
	_refresh_path_dots()
	_ok("Path dots redrawn")


func _action_reset_prompt() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "This will DELETE every MapNode in the scene and overwrite levels.json with only level_1.\n\nThis cannot be undone. Continue?"
	dlg.title = "Reset Map?"
	dlg.ok_button_text = "Reset"
	get_editor_interface().get_base_control().add_child(dlg)
	dlg.confirmed.connect(_action_reset_do)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.confirmed.connect(func(): dlg.queue_free(), CONNECT_DEFERRED)
	dlg.popup_centered()


func _action_reset_do() -> void:
	var mn := _get_map_nodes_parent()
	if mn == null: return

	for child in mn.get_children():
		if child.name.begins_with("MapNode"):
			child.queue_free()

	var root: Node = get_editor_interface().get_edited_scene_root()
	var new_node: Node = (load(MAP_NODE_SCENE) as PackedScene).instantiate()
	new_node.name     = "MapNode1"
	new_node.position = Vector2(200, 200)
	mn.add_child(new_node)
	new_node.set_owner(root)
	new_node.set("text", "1")

	var fresh: Dictionary = {
		"level_1": {
			"name":             "Level 1",
			"order":            1.0,
			"position":         [200, 200],
			"control_point":    [50, -30],
			"enemy_team":       ["alyx"],
			"enemy_level":      1,
			"reward_gold":      10.0,
			"reward_drops":     {},
			"background":       "res://assets/map/map.png",
			"unlock_after_win": []
		}
	}
	_save_levels(fresh)

	_connect_source = 0
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(new_node)
	_refresh_status()
	_ok("Map reset — fresh MapNode1 created")


func _ok(msg: String) -> void:
	print("[MapEditor] ✓ " + msg)

func _warn(msg: String) -> void:
	push_warning("[MapEditor] " + msg)

func _err(msg: String) -> void:
	push_error("[MapEditor] " + msg)
