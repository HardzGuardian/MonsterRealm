extends CanvasLayer

signal slot_selected(slot_idx: int)

const SETTINGS_PATH := "user://settings.json"


func _ready():
	layer   = 2000
	visible = false


func open():
	_build()
	visible = true


func _build():
	for c in get_children(): c.queue_free()

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color        = Color(0.02, 0.06, 0.12, 0.97)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text               = "Select Save Slot"
	title.size               = Vector2(1920, 80)
	title.position           = Vector2(0, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameTheme.apply_title(title, 48)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	dim.add_child(title)

	var sub := Label.new()
	sub.text               = "Your progress saves automatically per slot."
	sub.size               = Vector2(1920, 40)
	sub.position           = Vector2(0, 148)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
	dim.add_child(sub)

	var card_w := 380; var card_h := 460
	var total_w := card_w * 3 + 40 * 2
	var sx := (1920 - total_w) / 2

	for i in 3:
		var card := ColorRect.new()
		card.size     = Vector2(card_w, card_h)
		card.position = Vector2(sx + i * (card_w + 40), 240)
		card.color    = Color(0.06, 0.11, 0.18, 1)
		dim.add_child(card)

		var cborder := ColorRect.new()
		cborder.size     = Vector2(card_w + 4, card_h + 4)
		cborder.position = Vector2(-2, -2); cborder.z_index = -1
		cborder.color    = Color(0.24, 0.85, 0.82, 0.20)
		card.add_child(cborder)

		var hdr := ColorRect.new()
		hdr.size  = Vector2(card_w, 56); hdr.color = Color(0.04, 0.09, 0.15, 1)
		card.add_child(hdr)

		var hdr_lbl := Label.new()
		hdr_lbl.text = "SLOT  %d" % (i + 1)
		hdr_lbl.size = Vector2(card_w, 56)
		hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		GameTheme.apply_title(hdr_lbl, 22)
		hdr_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		hdr.add_child(hdr_lbl)

		var info := _build_slot_info(i, card_w)
		info.position = Vector2(20, 70)
		card.add_child(info)

		var has_save: bool = FileAccess.file_exists("user://save_slot_%d.json" % i)
		var btn := Button.new()
		btn.text     = "  Continue" if has_save else "  New Game"
		btn.position = Vector2(30, card_h - 70)
		btn.size     = Vector2(card_w - 60, 50)
		btn.add_theme_font_size_override("font_size", 18)
		if has_save and ResourceLoader.exists("res://assets/ui/icons/ic_continue.png"):
			btn.icon = load("res://assets/ui/icons/ic_continue.png")
		elif ResourceLoader.exists("res://assets/ui/icons/ic_add.png"):
			btn.icon = load("res://assets/ui/icons/ic_add.png")
		btn.pressed.connect(_on_slot_picked.bind(i))
		card.add_child(btn)

		if has_save:
			var del_btn := Button.new()
			del_btn.text     = ""
			del_btn.position = Vector2(card_w - 44, 60); del_btn.size = Vector2(36, 30)
			del_btn.flat     = true
			if ResourceLoader.exists("res://assets/ui/icons/ic_delete.png"):
				del_btn.icon        = load("res://assets/ui/icons/ic_delete.png")
				del_btn.expand_icon = true
			else:
				del_btn.text = "X"
				del_btn.add_theme_font_size_override("font_size", 14)
			del_btn.pressed.connect(_on_delete_slot.bind(i))
			card.add_child(del_btn)


func _build_slot_info(slot_idx: int, card_w: int) -> Control:
	var box := Control.new()
	box.size = Vector2(card_w - 40, 320)

	var path := "user://save_slot_%d.json" % slot_idx
	if not FileAccess.file_exists(path):
		var empty_lbl := Label.new()
		empty_lbl.text = "— Empty —"
		empty_lbl.size = Vector2(card_w - 40, 280)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 18)
		empty_lbl.add_theme_color_override("font_color", Color(0.40, 0.45, 0.52))
		box.add_child(empty_lbl)
		return box

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if file == null or json.parse(file.get_as_text()) != OK:
		return box
	var d: Dictionary = json.data if json.data is Dictionary else {}

	var caught: Array = d.get("caught_monsters", [])
	var team: Array   = d.get("team", [])
	var gold: int     = int(d.get("gold", 0))

	var lines := [
		"Monsters caught:  %d" % caught.size(),
		"Team size:  %d / 3" % team.size(),
		"Gold:  %d" % gold,
	]

	var instances: Dictionary = d.get("monster_instances", {})
	var y := 0
	for line in lines:
		var lbl := Label.new()
		lbl.text = line
		lbl.position = Vector2(0, y); lbl.size = Vector2(card_w - 40, 26)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 0.92))
		box.add_child(lbl)
		y += 30

	y += 10
	var team_hdr := Label.new()
	team_hdr.text = "Team:"
	team_hdr.position = Vector2(0, y); team_hdr.size = Vector2(card_w - 40, 24)
	team_hdr.add_theme_font_size_override("font_size", 14)
	team_hdr.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
	box.add_child(team_hdr)
	y += 28

	for tm in team:
		var sp: String = str(tm)
		var inst_arr: Array = instances.get(sp, [{"lvl": 1}])
		var lvl: int = int(inst_arr[0].get("lvl", 1)) if not inst_arr.is_empty() else 1
		var md: Dictionary = GameData.get_monster(sp)
		var nm: String = md.get("name", sp) if not md.is_empty() else sp
		var tm_lbl := Label.new()
		tm_lbl.text = "• %s  Lv.%d" % [nm, lvl]
		tm_lbl.position = Vector2(0, y); tm_lbl.size = Vector2(card_w - 40, 24)
		tm_lbl.add_theme_font_size_override("font_size", 14)
		tm_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
		box.add_child(tm_lbl)
		y += 26

	return box


func _on_slot_picked(slot_idx: int):
	SaveData.set_slot(slot_idx)
	_save_last_slot(slot_idx)
	visible = false
	slot_selected.emit(slot_idx)


func _on_delete_slot(slot_idx: int):
	var confirm := ConfirmationDialog.new()
	confirm.title       = "Delete Slot %d?" % (slot_idx + 1)
	confirm.dialog_text = "This cannot be undone."
	confirm.get_ok_button().text = "Delete"
	add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		DirAccess.remove_absolute("user://save_slot_%d.json" % slot_idx)
		confirm.queue_free()
		_build()
	)


func _save_last_slot(slot_idx: int):
	var d := {}
	var file := FileAccess.open("user://settings.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
			d = json.data
	d["current_slot"] = slot_idx
	var out := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(d, "\t"))
