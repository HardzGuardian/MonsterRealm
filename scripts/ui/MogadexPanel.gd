extends CanvasLayer

signal closed()
signal team_changed()

var _panel: ColorRect
var _type_sidebar_list: VBoxContainer
var _monster_grid: GridContainer
var _detail_overlay: Control
var _detail_image: TextureRect
var _detail_name: Label
var _detail_element: Label
var _detail_rarity: Label
var _detail_stats: Label
var _detail_team_btn: Button
var _detail_evolve_btn: Button
var _detail_rename_btn: Button
var _detail_roam_btn: Button
var _selected_copy_idx: int = 0
var _collection_team_slots: Array[TextureRect] = []
var _instance_container: Control
var _selected_evolve_indices: Array = []
var _selected_type: String = ""
var _current_monster: String = ""
var _monster_data: Dictionary = {}


func _ready():
	layer = 1000
	_monster_data = GameData.monsters
	_build()


func open():
	visible = true
	_populate_type_sidebar()
	_refresh_team_slots()
	if _selected_type == "" and GameData.ELEMENTS.size() > 0:
		_select_type(GameData.ELEMENTS[0])
	else:
		_select_type(_selected_type)


func _build():
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = ColorRect.new()
	_panel.anchor_left   = 0.5; _panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -600; _panel.offset_top  = -400
	_panel.offset_right  =  600; _panel.offset_bottom = 400
	_panel.color         = Color(0.05, 0.08, 0.13, 0.97)
	_panel.z_index       = 1
	add_child(_panel)

	var header := ColorRect.new()
	header.color = Color(0.03, 0.055, 0.10, 1.0)
	header.size  = Vector2(1200, 56)
	_panel.add_child(header)

	var title := Label.new()
	title.text                 = "MOGADEX & TEAM"
	title.position             = Vector2(0, 14)
	title.size                 = Vector2(1200, 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameTheme.apply_title(title, 22)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	header.add_child(title)

	var close_btn := GameTheme.make_close_btn(Vector2(1152, 8))
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	var sidebar_bg := ColorRect.new()
	sidebar_bg.position = Vector2(0, 56); sidebar_bg.size = Vector2(210, 664)
	sidebar_bg.color    = Color(0.03, 0.05, 0.09, 1.0)
	_panel.add_child(sidebar_bg)

	var divider := ColorRect.new()
	divider.position = Vector2(208, 56); divider.size = Vector2(2, 664)
	divider.color    = Color(0.15, 0.40, 0.50, 0.40)
	_panel.add_child(divider)

	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.size = Vector2(210, 664)
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_bg.add_child(sidebar_scroll)

	_type_sidebar_list = VBoxContainer.new()
	_type_sidebar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(_type_sidebar_list)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.position = Vector2(210, 56); grid_scroll.size = Vector2(990, 664)
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(grid_scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 14)
	grid_margin.add_theme_constant_override("margin_top",  14)
	grid_margin.add_theme_constant_override("margin_right", 14)
	grid_scroll.add_child(grid_margin)

	_monster_grid = GridContainer.new()
	_monster_grid.columns = 10
	_monster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monster_grid.add_theme_constant_override("h_separation", 8)
	_monster_grid.add_theme_constant_override("v_separation", 8)
	grid_margin.add_child(_monster_grid)

	var team_bar := ColorRect.new()
	team_bar.position = Vector2(0, 720); team_bar.size = Vector2(1200, 80)
	team_bar.color    = Color(0.03, 0.055, 0.10, 1.0)
	_panel.add_child(team_bar)

	var sep := ColorRect.new()
	sep.size  = Vector2(1200, 1); sep.color = Color(0.24, 0.85, 0.82, 0.25)
	team_bar.add_child(sep)

	var team_lbl := Label.new()
	team_lbl.text     = "Your Team:"
	team_lbl.position = Vector2(20, 0); team_lbl.size = Vector2(110, 80)
	team_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	team_lbl.add_theme_font_size_override("font_size", 13)
	team_lbl.add_theme_color_override("font_color", Color(0.45, 0.58, 0.68, 0.85))
	team_bar.add_child(team_lbl)

	_collection_team_slots.clear()
	const SLOT_W := 72; const SLOT_H := 62; const SLOT_GAP := 12; const SLOT_START_X := 140
	for i in 3:
		var sx: int = SLOT_START_X + i * (SLOT_W + SLOT_GAP)

		var sbg := ColorRect.new()
		sbg.position = Vector2(sx, 8); sbg.size = Vector2(SLOT_W, SLOT_H)
		sbg.color    = Color(0.06, 0.11, 0.18, 1.0)
		team_bar.add_child(sbg)

		var acc := ColorRect.new()
		acc.position = Vector2(sx, 8); acc.size = Vector2(3, SLOT_H)
		acc.color    = Color(0.24, 0.85, 0.82, 0.60)
		acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		team_bar.add_child(acc)

		var sl := TextureRect.new()
		sl.position     = Vector2(sx + 4, 10); sl.size = Vector2(SLOT_W - 8, SLOT_H - 4)
		sl.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		sl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sl.mouse_filter = Control.MOUSE_FILTER_STOP
		sl.gui_input.connect(_on_team_slot_click.bind(i))
		team_bar.add_child(sl)
		_collection_team_slots.append(sl)

	var hint := Label.new()
	hint.text     = "Click a monster to add  •  Click slot to remove"
	hint.position = Vector2(SLOT_START_X + 3 * (SLOT_W + SLOT_GAP) + 16, 0)
	hint.size     = Vector2(500, 80)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.42, 0.52, 0.58, 0.65))
	team_bar.add_child(hint)

	_detail_overlay = ColorRect.new()
	_detail_overlay.visible       = false
	_detail_overlay.position      = Vector2(210, 56)
	_detail_overlay.size          = Vector2(990, 664)
	_detail_overlay.color         = Color(0.04, 0.07, 0.12, 0.96)
	_detail_overlay.z_index       = 10
	_detail_overlay.clip_contents = true
	_panel.add_child(_detail_overlay)

	var dborder := ColorRect.new()
	dborder.position = Vector2(-2, -2); dborder.size = Vector2(994, 668)
	dborder.color = Color(0.24, 0.85, 0.82, 0.30); dborder.z_index = -1
	_detail_overlay.add_child(dborder)

	_detail_image = TextureRect.new()
	_detail_image.position = Vector2(70, 28); _detail_image.size = Vector2(320, 320)
	_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_overlay.add_child(_detail_image)

	var copies_hdr := Label.new()
	copies_hdr.name     = "CopiesHeader"
	copies_hdr.text     = "My Mogas"
	copies_hdr.position = Vector2(40, 358); copies_hdr.size = Vector2(420, 20)
	copies_hdr.add_theme_font_size_override("font_size", 12)
	copies_hdr.add_theme_color_override("font_color", Color(0.50, 0.60, 0.68, 0.75))
	_detail_overlay.add_child(copies_hdr)

	_instance_container = Control.new()
	_instance_container.position = Vector2(40, 382)
	_instance_container.size     = Vector2(430, 260)
	_detail_overlay.add_child(_instance_container)

	var vdiv := ColorRect.new()
	vdiv.position = Vector2(484, 16); vdiv.size = Vector2(1, 632)
	vdiv.color    = Color(0.18, 0.32, 0.48, 0.45)
	_detail_overlay.add_child(vdiv)

	const RX := 500; const RW := 470
	_detail_name = Label.new()
	_detail_name.position = Vector2(RX, 24); _detail_name.size = Vector2(RW, 44)
	_detail_name.add_theme_font_size_override("font_size", 28)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_detail_overlay.add_child(_detail_name)

	_detail_element = Label.new()
	_detail_element.position = Vector2(RX, 74); _detail_element.size = Vector2(RW, 26)
	_detail_element.add_theme_font_size_override("font_size", 16)
	_detail_overlay.add_child(_detail_element)

	_detail_rarity = Label.new()
	_detail_rarity.position = Vector2(RX, 104); _detail_rarity.size = Vector2(RW, 22)
	_detail_rarity.add_theme_font_size_override("font_size", 14)
	_detail_rarity.add_theme_color_override("font_color", Color(0.6, 0.78, 0.88))
	_detail_overlay.add_child(_detail_rarity)

	var dsep := ColorRect.new()
	dsep.position = Vector2(RX, 132); dsep.size = Vector2(RW, 1)
	dsep.color    = Color(0.24, 0.85, 0.82, 0.20)
	_detail_overlay.add_child(dsep)

	_detail_stats = Label.new()
	_detail_stats.position = Vector2(RX, 138); _detail_stats.size = Vector2(RW, 28)
	_detail_stats.add_theme_font_size_override("font_size", 14)
	_detail_stats.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	_detail_overlay.add_child(_detail_stats)

	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.position = Vector2(RX, 172); desc_lbl.size = Vector2(RW, 56)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.58, 0.66, 0.72, 0.82))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_overlay.add_child(desc_lbl)

	var dsep2 := ColorRect.new()
	dsep2.position = Vector2(RX, 234); dsep2.size = Vector2(RW, 1)
	dsep2.color    = Color(0.18, 0.32, 0.48, 0.30)
	_detail_overlay.add_child(dsep2)

	_detail_team_btn = Button.new()
	_detail_team_btn.position = Vector2(RX, 248); _detail_team_btn.size = Vector2(226, 42)
	_detail_team_btn.add_theme_font_size_override("font_size", 15)
	_detail_team_btn.pressed.connect(_on_toggle_team)
	_detail_overlay.add_child(_detail_team_btn)

	_detail_rename_btn = Button.new()
	_detail_rename_btn.text     = "Rename"
	_detail_rename_btn.position = Vector2(RX + 234, 248)
	_detail_rename_btn.size     = Vector2(236, 42)
	_detail_rename_btn.add_theme_font_size_override("font_size", 15)
	_detail_rename_btn.pressed.connect(_on_rename_clicked)
	_detail_overlay.add_child(_detail_rename_btn)

	_detail_evolve_btn = Button.new()
	_detail_evolve_btn.text     = "Evolve"
	_detail_evolve_btn.position = Vector2(RX, 300); _detail_evolve_btn.size = Vector2(RW, 42)
	_detail_evolve_btn.visible  = false
	_detail_evolve_btn.add_theme_font_size_override("font_size", 15)
	_detail_evolve_btn.pressed.connect(_on_evolve_clicked)
	_detail_overlay.add_child(_detail_evolve_btn)

	_detail_roam_btn = Button.new()
	_detail_roam_btn.position = Vector2(RX, 352); _detail_roam_btn.size = Vector2(RW, 42)
	_detail_roam_btn.add_theme_font_size_override("font_size", 15)
	_detail_roam_btn.pressed.connect(_on_roam_toggle)
	_detail_overlay.add_child(_detail_roam_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(RX, 624); back_btn.size = Vector2(150, 40)
	back_btn.pressed.connect(func(): _detail_overlay.visible = false)
	_detail_overlay.add_child(back_btn)


func _populate_type_sidebar():
	for child in _type_sidebar_list.get_children():
		child.queue_free()
	var caught: Array = SaveData.data.get("caught_monsters", [])
	for element in GameData.ELEMENTS:
		var total := 0; var caught_n := 0
		for m_id in _monster_data.keys():
			if _monster_data[m_id].get("element","") == element:
				total += 1
				if m_id in caught: caught_n += 1
		var row := Button.new()
		row.custom_minimum_size = Vector2(210, 52)
		row.flat = true; row.focus_mode = Control.FOCUS_NONE
		row.pressed.connect(_select_type.bind(element))
		_type_sidebar_list.add_child(row)
		# Load and resize PNG to exactly 26×26
		var icon_tex := _load_sized_texture("res://assets/elements/elem_%s.png" % element, 26)
		if icon_tex:
			var icon_img := TextureRect.new()
			icon_img.texture      = icon_tex
			icon_img.size         = Vector2(26, 26)
			icon_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_img.position     = Vector2(8, 13)
			icon_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon_img)
		else:
			var icon_lbl := Label.new()
			icon_lbl.text         = GameData.ELEMENT_ICONS.get(element, "?")
			icon_lbl.position     = Vector2(8, 12)
			icon_lbl.add_theme_font_size_override("font_size", 20)
			icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon_lbl)

		var name_lbl := Label.new(); name_lbl.text = element.capitalize()
		name_lbl.position = Vector2(40, 16); name_lbl.size = Vector2(102, 22)
		name_lbl.add_theme_font_size_override("font_size",15)
		name_lbl.add_theme_color_override("font_color", GameData.ELEMENT_COLORS.get(element, Color.WHITE))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(name_lbl)
		var cnt_lbl := Label.new(); cnt_lbl.text = "%d/%d" % [caught_n, total]
		cnt_lbl.position = Vector2(148,16); cnt_lbl.size = Vector2(55,24)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.add_theme_font_size_override("font_size",14)
		cnt_lbl.add_theme_color_override("font_color", Color(0.7,0.85,0.9,0.85))
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(cnt_lbl)
		if element == _selected_type:
			var hl := ColorRect.new(); hl.size = Vector2(210,52)
			hl.color = Color(0.24,0.85,0.82,0.10); hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(hl)
			var la := ColorRect.new(); la.size = Vector2(4,52)
			la.color = Color(0.24,0.85,0.82,0.90); la.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(la)
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(210,1)
		sep.color = Color(0.12,0.20,0.28,0.70)
		_type_sidebar_list.add_child(sep)


func _select_type(element: String):
	_selected_type = element
	_detail_overlay.visible = false
	_populate_type_sidebar()
	for child in _monster_grid.get_children():
		child.queue_free()
	var caught: Array = SaveData.data.get("caught_monsters", [])
	var team: Array   = SaveData.get_team()
	var type_monsters: Array = []
	for m_id in _monster_data.keys():
		if _monster_data[m_id].get("element","") == element:
			type_monsters.append(m_id)
	for m_id in type_monsters:
		var md: Dictionary = _monster_data[m_id]
		var is_caught: bool = m_id in caught
		var in_team: bool   = m_id in team
		var owned: int      = caught.count(m_id)
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(72,72)
		_monster_grid.add_child(slot)
		if in_team:
			var tb := ColorRect.new(); tb.size = Vector2(72,72)
			tb.color = Color(0.24,0.85,0.82,0.70); slot.add_child(tb)
		var bg := ColorRect.new()
		bg.position = Vector2(2,2) if in_team else Vector2(0,0)
		bg.size     = Vector2(68,68) if in_team else Vector2(72,72)
		bg.color    = Color(0.09,0.15,0.22,1) if is_caught else Color(0.05,0.08,0.12,1)
		slot.add_child(bg)
		var icon := TextureRect.new()
		icon.position = Vector2(6,6); icon.size = Vector2(60,60)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_caught:
			var sp: String = md.get("sprite","")
			if sp != "" and FileAccess.file_exists(sp): icon.texture = load(sp)
		else:
			if FileAccess.file_exists("res://assets/ui/placeholder_slot.png"):
				icon.texture = load("res://assets/ui/placeholder_slot.png")
			icon.modulate = Color(0.25,0.25,0.28,1)
		slot.add_child(icon)
		if not is_caught:
			var q := Label.new(); q.text = "?"; q.position = Vector2(24,16)
			q.size = Vector2(24,40); q.add_theme_font_size_override("font_size",28)
			q.add_theme_color_override("font_color",Color(0.38,0.42,0.48,0.9))
			q.mouse_filter = Control.MOUSE_FILTER_IGNORE; slot.add_child(q)
		if is_caught and owned > 1:
			var bb := ColorRect.new(); bb.position = Vector2(44,48); bb.size = Vector2(26,18)
			bb.color = Color(0.06,0.18,0.32,0.95); bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(bb)
			var bl := Label.new(); bl.text = "x%d" % owned; bl.size = Vector2(26,18)
			bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bl.add_theme_font_size_override("font_size",11)
			bl.add_theme_color_override("font_color", Color(1.0,0.85,0.3))
			bl.mouse_filter = Control.MOUSE_FILTER_IGNORE; bb.add_child(bl)
		var btn := Button.new(); btn.flat = true; btn.size = Vector2(72,72)
		btn.focus_mode = Control.FOCUS_NONE; btn.self_modulate = Color(1,1,1,0)
		if is_caught: btn.pressed.connect(_show_monster_detail.bind(m_id))
		slot.add_child(btn)


func _show_monster_detail(monster_id: String):
	_current_monster = monster_id
	var md: Dictionary  = GameData.get_monster(monster_id)
	var caught: Array   = SaveData.data.get("caught_monsters", [])
	var team: Array     = SaveData.get_team()

	_detail_image.texture = null
	var sp: String = md.get("sprite","")
	if sp != "" and FileAccess.file_exists(sp): _detail_image.texture = load(sp)

	_detail_name.text = md.get("name", monster_id)
	var elem: String = md.get("element", "-")
	_update_element_label(_detail_element, elem)

	var rarity: String = md.get("rarity", "common").capitalize()
	_detail_rarity.text = "Rarity:  %s" % rarity

	var owned: int = caught.count(monster_id)
	var lv0: int   = SaveData.get_monster_level(monster_id)
	var growth: Dictionary = GameData.get_growth(monster_id)
	_detail_stats.text = "Owned: %d   |   HP: %d   ATK: %d   DEF: %d" % [
		owned,
		int(md.get("hp",0))      + (lv0 - 1) * int(growth.get("hp",      8)),
		int(md.get("attack",0))  + (lv0 - 1) * int(growth.get("attack",  2)),
		int(md.get("defense",0)) + (lv0 - 1) * int(growth.get("defense", 1))
	]

	var desc_node := _detail_overlay.get_node_or_null("DescLabel")
	if desc_node: desc_node.text = md.get("description","")

	_selected_evolve_indices.clear()
	_rebuild_instance_boxes(monster_id, md)

	if monster_id in team:
		_detail_team_btn.text = "Remove from Team"
		_detail_team_btn.disabled = false
	else:
		_detail_team_btn.text = "Add to Team"
		_detail_team_btn.disabled = team.size() >= 3

	var evolves_to: String = md.get("evolves_to","")
	if evolves_to != "":
		_detail_evolve_btn.visible  = true
		_detail_evolve_btn.disabled = false
		_detail_evolve_btn.text     = "Evolve"
	else:
		_detail_evolve_btn.visible = false

	_selected_copy_idx = 0
	_rebuild_move_equip(monster_id)
	_refresh_roam_btn()
	_detail_overlay.visible = true


func _rebuild_instance_boxes(species: String, md: Dictionary):
	for child in _instance_container.get_children():
		child.queue_free()

	var instances: Array  = SaveData.get_all_instances(species)
	var team: Array       = SaveData.get_team()
	var sp: String        = md.get("sprite", "")
	var growth: Dictionary = GameData.get_growth(species)
	var base_hp: int      = md.get("hp",      0) as int
	var base_atk: int     = md.get("attack",  0) as int
	var base_def: int     = md.get("defense", 0) as int

	const BOX  := 100
	const H    := 116
	const GAP  := 12
	const COLS := 4
	var boxes: Array = []

	for i in instances.size():
		var inst: Dictionary = instances[i]
		var lv: int          = int(inst.get("lvl", 1))
		var xp: int          = int(inst.get("xp",  0))
		var is_roaming: bool = SaveData.get_instance_roaming(species, i)
		# First copy is "in team" when the species appears in the team
		var in_team: bool    = (i == 0 and species in team)

		var col: int = i % COLS
		var row: int = i / COLS

		var box := ColorRect.new()
		box.position = Vector2(col * (BOX + GAP), row * (H + GAP))
		box.size     = Vector2(BOX, H)
		if in_team:
			box.color = Color(0.18, 0.14, 0.06, 1.0)
		elif is_roaming:
			box.color = Color(0.06, 0.16, 0.18, 1.0)
		else:
			box.color = Color(0.07, 0.12, 0.20, 1.0)
		_instance_container.add_child(box)
		boxes.append(box)

		var bdr := ColorRect.new()
		bdr.name     = "Bdr"
		bdr.position = Vector2(-2, -2)
		bdr.size     = Vector2(BOX + 4, H + 4)
		bdr.z_index  = -1
		if in_team:
			bdr.color = Color(1.00, 0.80, 0.15, 0.90)
		elif is_roaming:
			bdr.color = Color(0.24, 0.85, 0.82, 0.60)
		else:
			bdr.color = Color(0.15, 0.28, 0.42, 0.35)
		box.add_child(bdr)

		if in_team:
			var team_badge := Label.new()
			team_badge.text = "👑"
			team_badge.position = Vector2(3, 2)
			team_badge.add_theme_font_size_override("font_size", 14)
			team_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(team_badge)

		var img := TextureRect.new()
		img.position     = Vector2(8, 16)
		img.size         = Vector2(BOX - 16, 68)
		img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sp != "" and FileAccess.file_exists(sp):
			img.texture = load(sp)
		box.add_child(img)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv. %d" % lv
		lv_lbl.position = Vector2(0, 86)
		lv_lbl.size     = Vector2(BOX, 18)
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_lbl.add_theme_font_size_override("font_size", 13)
		lv_lbl.add_theme_color_override("font_color",
			Color(1.00, 0.85, 0.30) if in_team else Color(0.75, 0.88, 0.95))
		lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lv_lbl)

		var xp_bg := ColorRect.new()
		xp_bg.position = Vector2(8, 106); xp_bg.size = Vector2(BOX - 16, 5)
		xp_bg.color    = Color(0.10, 0.18, 0.28)
		xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(xp_bg)
		var xp_need: int = SaveData.xp_needed_for_level(lv)
		var xp_fill := ColorRect.new()
		xp_fill.position = Vector2(8, 106)
		xp_fill.size     = Vector2((BOX - 16) * float(xp) / float(maxi(xp_need, 1)), 5)
		xp_fill.color    = Color(0.24, 0.85, 0.82)
		xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(xp_fill)

		var idx_cap := i

		var btn := Button.new()
		btn.flat = true
		btn.size = Vector2(BOX, H)
		btn.position = Vector2(0, 0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.self_modulate = Color(1, 1, 1, 0)
		btn.pressed.connect(func():
			_selected_copy_idx = idx_cap
			var cur_lv: int  = int(SaveData.get_all_instances(species)[idx_cap].get("lvl", 1))
			var cur_xp2: int = int(SaveData.get_all_instances(species)[idx_cap].get("xp",  0))
			var xp_n: int    = SaveData.xp_needed_for_level(cur_lv)
			_detail_stats.text = "Lv.%d   XP %d/%d  |  HP: %d  ATK: %d  DEF: %d" % [
				cur_lv, cur_xp2, xp_n,
				base_hp  + (cur_lv - 1) * int(growth.get("hp",      8)),
				base_atk + (cur_lv - 1) * int(growth.get("attack",  2)),
				base_def + (cur_lv - 1) * int(growth.get("defense", 1))
			]
			_refresh_roam_btn()
			for j in boxes.size():
				var b := boxes[j] as ColorRect
				var bd := b.get_node_or_null("Bdr") as ColorRect
				if bd:
					bd.color = Color(0.24, 0.85, 0.82, 0.90) if j == idx_cap \
						else (Color(1.0, 0.80, 0.15, 0.90) if (j == 0 and species in SaveData.get_team()) \
						else Color(0.15, 0.28, 0.42, 0.35))
		)
		box.add_child(btn)


func _toggle_box(idx: int, box: ColorRect, bdr: ColorRect, plus: Label, _needed: int, _species: String, _md: Dictionary):
	if idx in _selected_evolve_indices:
		_selected_evolve_indices.erase(idx)
		box.color = Color(0.07,0.12,0.20,1); bdr.color = Color(0.15,0.28,0.42,0.50)
		plus.text = "+"; plus.add_theme_color_override("font_color",Color(0.35,0.65,0.80,0.75))
	else:
		if _selected_evolve_indices.size() >= _needed: return
		_selected_evolve_indices.append(idx)
		box.color = Color(0.05,0.22,0.20,1); bdr.color = Color(0.24,0.85,0.82,0.90)
		plus.text = "✓"; plus.add_theme_color_override("font_color",Color(0.24,0.92,0.72))


func _on_toggle_team():
	if _current_monster == "": return
	var team: Array = SaveData.get_team()
	if _current_monster in team: team.erase(_current_monster)
	else:
		if team.size() >= 3: return
		team.append(_current_monster)
	SaveData.data["team"] = team; SaveData.save()
	_refresh_team_slots()
	_select_type(_selected_type)
	_show_monster_detail(_current_monster)
	team_changed.emit()


func _rebuild_move_equip(species: String):
	for child in _detail_overlay.get_children():
		if child.name.begins_with("MoveBtn_") or child.name == "MoveSlotHeader":
			child.queue_free()

	const RX       := 500
	const RW       := 470
	const MAX_ACTIVE := 4
	const PILL_H   := 40
	const PILL_GAP := 8
	const COLS     := 2
	const PILL_W   := 228

	var level: int   = SaveData.get_monster_level(species)
	var learned: Array = GameData.get_available_moves(species, level)
	var active: Array  = SaveData.get_active_moves(species).duplicate()

	var slot_hdr := Label.new()
	slot_hdr.name = "MoveSlotHeader"
	slot_hdr.text = "MOVES  (%d / %d equipped)" % [active.size(), MAX_ACTIVE]
	slot_hdr.position = Vector2(RX, 458)
	slot_hdr.size     = Vector2(RW, 20)
	slot_hdr.add_theme_font_size_override("font_size", 12)
	slot_hdr.add_theme_color_override("font_color",
		Color(0.24, 0.85, 0.82) if active.size() >= MAX_ACTIVE else Color(0.50, 0.60, 0.68, 0.85))
	_detail_overlay.add_child(slot_hdr)

	for i in learned.size():
		var mv_id: String    = str(learned[i])
		var mv: Dictionary   = GameData.get_move(mv_id)
		var mv_name: String  = mv.get("name", mv_id)
		var kind: String     = mv.get("kind", "damage")
		var elem: String     = mv.get("element", "")
		var power: int       = int(mv.get("power", 0))
		var is_sig: bool     = mv.get("signature", false)
		var is_active: bool  = mv_id in active
		var is_full: bool    = active.size() >= MAX_ACTIVE and not is_active

		var elem_col: Color  = GameData.ELEMENT_COLORS.get(elem, Color(0.55, 0.65, 0.75))

		var col_idx: int = i % COLS
		var row_idx: int = i / COLS
		var px: int = RX + col_idx * (PILL_W + 14)
		var py: int = 482 + row_idx * (PILL_H + PILL_GAP)

		var pill := Button.new()
		pill.name       = "MoveBtn_%s" % mv_id
		pill.position   = Vector2(px, py)
		pill.size       = Vector2(PILL_W, PILL_H)
		pill.focus_mode = Control.FOCUS_NONE
		pill.text       = ""

		var sn := StyleBoxFlat.new()
		if is_active:
			sn.bg_color    = Color(0.06, 0.26, 0.22, 1.0)
			sn.border_color = Color(0.24, 0.85, 0.82, 1.0)
		elif is_full:
			sn.bg_color    = Color(0.08, 0.11, 0.16, 1.0)
			sn.border_color = Color(0.20, 0.28, 0.38, 0.50)
		else:
			sn.bg_color    = Color(0.09, 0.14, 0.22, 1.0)
			sn.border_color = Color(0.25, 0.35, 0.50, 0.70)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			sn.set_border_width(side, 2)
		sn.corner_radius_top_left     = 6
		sn.corner_radius_top_right    = 6
		sn.corner_radius_bottom_left  = 6
		sn.corner_radius_bottom_right = 6

		pill.add_theme_stylebox_override("normal", sn)
		var sh := sn.duplicate() as StyleBoxFlat
		sh.bg_color = sh.bg_color.lightened(0.08)
		pill.add_theme_stylebox_override("hover",   sh)
		_detail_overlay.add_child(pill)

		var stripe := ColorRect.new()
		stripe.size  = Vector2(4, PILL_H - 4)
		stripe.position = Vector2(2, 2)
		stripe.color = elem_col if elem != "" else Color(0.40, 0.50, 0.60, 0.60)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(stripe)

		var dot := Label.new()
		dot.text = "✔" if is_active else ("⊘" if is_full else "○")
		dot.position = Vector2(10, 0); dot.size = Vector2(22, PILL_H)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 14)
		dot.add_theme_color_override("font_color",
			Color(0.24, 0.92, 0.72) if is_active
			else (Color(0.35, 0.40, 0.45) if is_full else Color(0.50, 0.60, 0.70)))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(dot)

		var name_lbl := Label.new()
		name_lbl.text = ("★ " if is_sig else "") + mv_name
		name_lbl.position = Vector2(34, 0); name_lbl.size = Vector2(PILL_W - 90, PILL_H)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color",
			Color(1.00, 0.95, 1.00) if is_active
			else (Color(0.40, 0.45, 0.50) if is_full else Color(0.80, 0.88, 0.95)))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(name_lbl)

		var kind_badge := Label.new()
		match kind:
			"damage":  kind_badge.text = "ATK %d" % power
			"buff":    kind_badge.text = "BUFF"
			"debuff":  kind_badge.text = "DEBUFF"
			_:         kind_badge.text = kind.to_upper()
		kind_badge.position = Vector2(PILL_W - 56, 0); kind_badge.size = Vector2(52, PILL_H)
		kind_badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		kind_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		kind_badge.add_theme_font_size_override("font_size", 11)
		kind_badge.add_theme_color_override("font_color",
			elem_col if is_active else Color(0.40, 0.48, 0.55))
		kind_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(kind_badge)

		var mv_id_cap := mv_id
		pill.pressed.connect(func():
			var cur: Array = SaveData.get_active_moves(species).duplicate()
			if mv_id_cap in cur:
				if cur.size() > 1:
					cur.erase(mv_id_cap)
					SaveData.set_active_moves(species, cur)
			else:
				if cur.size() < MAX_ACTIVE:
					cur.append(mv_id_cap)
					SaveData.set_active_moves(species, cur)
				# If slots are full, do nothing — user must deselect one first
			_rebuild_move_equip(species)
		)


func _refresh_roam_btn():
	if not _detail_roam_btn or _current_monster == "": return
	var is_roaming: bool = SaveData.get_instance_roaming(_current_monster, _selected_copy_idx)
	_detail_roam_btn.text = "On Home  (Copy %d)" % (_selected_copy_idx + 1) if is_roaming \
		else "Add Copy %d to Home" % (_selected_copy_idx + 1)
	var sn := StyleBoxFlat.new()
	sn.bg_color     = Color(0.06, 0.26, 0.24, 1.0) if is_roaming else Color(0.08, 0.13, 0.20, 1.0)
	sn.border_color = Color(0.24, 0.85, 0.82, 0.85) if is_roaming else Color(0.22, 0.32, 0.46, 0.60)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sn.set_border_width(side, 2)
	sn.corner_radius_top_left     = 6
	sn.corner_radius_top_right    = 6
	sn.corner_radius_bottom_left  = 6
	sn.corner_radius_bottom_right = 6
	_detail_roam_btn.add_theme_stylebox_override("normal", sn)
	_detail_roam_btn.add_theme_color_override("font_color",
		Color(0.24, 0.92, 0.82) if is_roaming else Color(0.55, 0.68, 0.78))


func _on_roam_toggle():
	if _current_monster == "": return
	var cur: bool = SaveData.get_instance_roaming(_current_monster, _selected_copy_idx)
	SaveData.set_instance_roaming(_current_monster, _selected_copy_idx, not cur)
	_refresh_roam_btn()
	_rebuild_instance_boxes(_current_monster, GameData.get_monster(_current_monster))


func _on_rename_clicked():
	if _current_monster == "": return
	var has_tag: bool = SaveData.get_inventory_item("name_tag") > 0
	_show_rename_dialog(_current_monster, has_tag)


func _show_rename_dialog(species: String, has_tag: bool):
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color   = Color(0, 0, 0, 0.72)
	overlay.z_index = 300
	add_child(overlay)

	var box := ColorRect.new()
	box.color    = Color(0.06, 0.11, 0.18, 0.98)
	box.size     = Vector2(480, 240)
	box.position = Vector2((_panel.size.x - 480) / 2.0, (_panel.size.y - 240) / 2.0)
	overlay.add_child(box)

	var border := ColorRect.new()
	border.color    = Color(0.24, 0.85, 0.82, 0.30)
	border.size     = Vector2(484, 244)
	border.position = Vector2(-2, -2)
	border.z_index  = -1
	box.add_child(border)

	var title_lbl := Label.new()
	title_lbl.text               = "Rename Monster"
	title_lbl.size               = Vector2(480, 44)
	title_lbl.position           = Vector2(0, 12)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	box.add_child(title_lbl)

	var current_name: String = SaveData.get_instance_custom_name(species)
	if current_name == "": current_name = GameData.get_monster(species).get("name", species)

	var input := LineEdit.new()
	input.text             = current_name
	input.position         = Vector2(24, 70)
	input.size             = Vector2(432, 44)
	input.placeholder_text = "Enter new name…"
	input.max_length       = 20
	input.add_theme_font_size_override("font_size", 18)
	box.add_child(input)
	input.grab_focus()
	input.select_all()

	if not has_tag:
		var warn := Label.new()
		warn.text               = "You need a Name Tag to rename!"
		warn.position           = Vector2(0, 122)
		warn.size               = Vector2(480, 28)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_font_size_override("font_size", 13)
		warn.add_theme_color_override("font_color", Color(0.95, 0.65, 0.20))
		box.add_child(warn)

	var confirm_btn := Button.new()
	confirm_btn.text     = "Confirm"
	confirm_btn.position = Vector2(24, 166)
	confirm_btn.size     = Vector2(200, 44)
	confirm_btn.disabled = not has_tag
	confirm_btn.add_theme_font_size_override("font_size", 16)
	box.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text     = "Cancel"
	cancel_btn.position = Vector2(256, 166)
	cancel_btn.size     = Vector2(200, 44)
	cancel_btn.add_theme_font_size_override("font_size", 16)
	box.add_child(cancel_btn)

	cancel_btn.pressed.connect(overlay.queue_free)
	confirm_btn.pressed.connect(func():
		var new_name: String = input.text.strip_edges()
		if new_name == "": return
		SaveData.use_inventory_item("name_tag")
		SaveData.set_instance_custom_name(species, new_name)
		_detail_name.text = new_name
		overlay.queue_free()
	)
	input.text_submitted.connect(func(_t: String): confirm_btn.emit_signal("pressed"))


func _on_evolve_clicked():
	if _current_monster == "": return
	var md := GameData.get_monster(_current_monster)
	var evolves_to: String = md.get("evolves_to","")
	if evolves_to == "": return
	_open_evolve_popup(_current_monster, md, evolves_to)


func _open_evolve_popup(species: String, md: Dictionary, evolves_to: String):
	var needed: int       = md.get("evolve_monsters_needed",0)
	var potions_need: int = md.get("evolve_potions_needed",0)
	var instances: Array  = SaveData.get_all_instances(species)
	var sprite_path: String = md.get("sprite","")
	var evo_name: String  = GameData.get_monster(evolves_to).get("name",evolves_to)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0,0,0,0.75); overlay.z_index = 200
	_panel.add_child(overlay)
	overlay.modulate.a = 0.0
	get_tree().create_tween().tween_property(overlay,"modulate:a",1.0,0.22)

	var pw := 820; var ph := 540
	var panel := ColorRect.new()
	panel.position = Vector2((1200-pw)/2, (800-ph)/2); panel.size = Vector2(pw,ph)
	panel.color = Color(0.05,0.09,0.14,0.98); overlay.add_child(panel)
	var pbdr := ColorRect.new(); pbdr.position = Vector2(-2,-2); pbdr.size = Vector2(pw+4,ph+4)
	pbdr.color = Color(0.24,0.85,0.82,0.30); pbdr.z_index = -1; panel.add_child(pbdr)

	var hdr := Label.new()
	hdr.text = "Evolve  %s  →  %s" % [md.get("name",species), evo_name]
	hdr.position = Vector2(0,14); hdr.size = Vector2(pw,36)
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_theme_font_size_override("font_size",22)
	hdr.add_theme_color_override("font_color",Color(1.0,0.85,0.3)); panel.add_child(hdr)

	var hdiv := ColorRect.new(); hdiv.position = Vector2(20,54); hdiv.size = Vector2(pw-40,1)
	hdiv.color = Color(0.24,0.85,0.82,0.22); panel.add_child(hdiv)

	var slot_lbl := Label.new()
	slot_lbl.text = "Select %d copies  +  %d potion(s)" % [needed,potions_need]
	slot_lbl.position = Vector2(0,62); slot_lbl.size = Vector2(pw,24)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size",14)
	slot_lbl.add_theme_color_override("font_color",Color(0.60,0.70,0.78)); panel.add_child(slot_lbl)

	var have_p := SaveData.get_inventory_item("evolve_potion")
	var p_lbl := Label.new()
	p_lbl.text = "Evolve Potions:  %d / %d  %s" % [have_p,potions_need,"✓" if have_p>=potions_need else "✗"]
	p_lbl.position = Vector2(0,86); p_lbl.size = Vector2(pw,22)
	p_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_lbl.add_theme_font_size_override("font_size",14)
	p_lbl.add_theme_color_override("font_color",Color(0.30,0.90,0.45) if have_p>=potions_need else Color(0.90,0.35,0.28))
	panel.add_child(p_lbl)

	const SB:=80; const SG:=12
	var stw := needed*SB+(needed-1)*SG; var sx := (pw-stw)/2
	var evo_slots: Array = []; var filled: Array = []
	for s in needed:
		var slot := ColorRect.new(); slot.position = Vector2(sx+s*(SB+SG),116)
		slot.size = Vector2(SB,SB); slot.color = Color(0.06,0.11,0.18,1); panel.add_child(slot)
		var sbdr := ColorRect.new(); sbdr.position = Vector2(-2,-2); sbdr.size = Vector2(SB+4,SB+4)
		sbdr.color = Color(0.20,0.40,0.55,0.45); sbdr.z_index = -1; slot.add_child(sbdr)
		var simg := TextureRect.new(); simg.name = "Img"
		simg.position = Vector2(8,8); simg.size = Vector2(SB-16,SB-16)
		simg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		simg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		simg.mouse_filter = Control.MOUSE_FILTER_IGNORE; slot.add_child(simg)
		var slv := Label.new(); slv.name = "Lv"
		slv.position = Vector2(0,SB-18); slv.size = Vector2(SB,16)
		slv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slv.add_theme_font_size_override("font_size",11)
		slv.add_theme_color_override("font_color",Color(0.24,0.85,0.82))
		slv.mouse_filter = Control.MOUSE_FILTER_IGNORE; slot.add_child(slv)
		evo_slots.append(slot)

	var pick_lbl := Label.new(); pick_lbl.text = "Your copies  (click + to add)"
	pick_lbl.position = Vector2(20,210); pick_lbl.size = Vector2(pw-40,22)
	pick_lbl.add_theme_font_size_override("font_size",13)
	pick_lbl.add_theme_color_override("font_color",Color(0.55,0.65,0.72,0.85)); panel.add_child(pick_lbl)

	const CB:=90; const CG:=10; const CCOLS:=7
	# Create button before loop so lambdas can safely reference it
	var evolve_now_btn: Button = Button.new()
	for ci in instances.size():
		var lv: int  = int(instances[ci].get("lvl",1))
		var col: int = ci % int(CCOLS)
		var row: int = ci / CCOLS
		var cbox := ColorRect.new()
		cbox.position = Vector2(20+col*(CB+CG),238+row*(CB+CG)); cbox.size = Vector2(CB,CB)
		cbox.color = Color(0.07,0.12,0.20,1); panel.add_child(cbox)
		var cbdr := ColorRect.new(); cbdr.name="Bdr"
		cbdr.position = Vector2(-2,-2); cbdr.size = Vector2(CB+4,CB+4)
		cbdr.color = Color(0.15,0.28,0.42,0.45); cbdr.z_index=-1; cbox.add_child(cbdr)
		var cimg := TextureRect.new()
		cimg.position = Vector2(10,6); cimg.size = Vector2(CB-20,CB-28)
		cimg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cimg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cimg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if sprite_path!="" and FileAccess.file_exists(sprite_path): cimg.texture=load(sprite_path)
		cbox.add_child(cimg)
		var clv := Label.new(); clv.text="Lv.%d"%lv
		clv.position=Vector2(0,CB-22); clv.size=Vector2(CB,20)
		clv.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		clv.add_theme_font_size_override("font_size",12)
		clv.add_theme_color_override("font_color",Color(0.70,0.82,0.90))
		clv.mouse_filter=Control.MOUSE_FILTER_IGNORE; cbox.add_child(clv)
		var cplus:=Label.new(); cplus.name="Plus"; cplus.text="+"
		cplus.position=Vector2(CB-18,2); cplus.size=Vector2(16,16)
		cplus.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		cplus.add_theme_font_size_override("font_size",15)
		cplus.add_theme_color_override("font_color",Color(0.35,0.65,0.80,0.80))
		cplus.mouse_filter=Control.MOUSE_FILTER_IGNORE; cbox.add_child(cplus)
		var cbtn:=Button.new(); cbtn.flat=true; cbtn.size=Vector2(CB,CB)
		cbtn.focus_mode=Control.FOCUS_NONE; cbtn.self_modulate=Color(1,1,1,0)
		var ci_cap:=ci
		cbtn.pressed.connect(func():
			if ci_cap in filled:
				filled.erase(ci_cap); cbox.color=Color(0.07,0.12,0.20,1)
				cbdr.color=Color(0.15,0.28,0.42,0.45); cplus.text="+"
				cplus.add_theme_color_override("font_color",Color(0.35,0.65,0.80,0.80))
			else:
				if filled.size()>=needed: return
				filled.append(ci_cap); cbox.color=Color(0.05,0.22,0.20,1)
				cbdr.color=Color(0.24,0.85,0.82,0.90); cplus.text="✓"
				cplus.add_theme_color_override("font_color",Color(0.24,0.92,0.72))
			for s2 in evo_slots.size():
				var si2:=evo_slots[s2].get_node_or_null("Img") as TextureRect
				var sl2:=evo_slots[s2].get_node_or_null("Lv") as Label
				if s2<filled.size():
					var fi_lv:=int(instances[filled[s2]].get("lvl",1))
					if si2 and sprite_path!="" and FileAccess.file_exists(sprite_path): si2.texture=load(sprite_path)
					if sl2: sl2.text="Lv.%d"%fi_lv
				else:
					if si2: si2.texture=null
					if sl2: sl2.text=""
			if evolve_now_btn:
				evolve_now_btn.disabled = filled.size() != needed
		)
		cbox.add_child(cbtn)

	evolve_now_btn.text     = "EVOLVE NOW!"
	evolve_now_btn.position = Vector2(pw/2.0-150, ph-68)
	evolve_now_btn.size     = Vector2(300, 48)
	evolve_now_btn.disabled = true
	evolve_now_btn.add_theme_font_size_override("font_size", 20)
	panel.add_child(evolve_now_btn)
	var cancel_btn:=Button.new(); cancel_btn.text="Cancel"
	cancel_btn.position=Vector2(pw/2.0+162,ph-68); cancel_btn.size=Vector2(100,48)
	cancel_btn.pressed.connect(func():
		var tw:=get_tree().create_tween(); tw.tween_property(overlay,"modulate:a",0.0,0.18)
		await tw.finished; overlay.queue_free()
	); panel.add_child(cancel_btn)

	evolve_now_btn.pressed.connect(func():
		if filled.size() != needed: return
		var owned_potions: int = SaveData.get_inventory_item("evolve_potion")
		if owned_potions < potions_need:
			evolve_now_btn.text = "Need %d Potions! (have %d)" % [potions_need, owned_potions]
			evolve_now_btn.modulate = Color(0.95, 0.35, 0.28)
			await panel.get_tree().create_timer(2.0).timeout
			if is_instance_valid(evolve_now_btn):
				evolve_now_btn.text = "✨  EVOLVE NOW!"
				evolve_now_btn.modulate = Color.WHITE
			return
		overlay.queue_free()
		await _do_evolve(species, evolves_to, filled.duplicate(), potions_need)
	)


func _do_evolve(species: String, evolves_to: String, indices: Array, potions_needed: int):
	var best_lvl := 1; var best_xp := 0
	for idx in indices:
		var lv:int = SaveData.get_instance_level(species,idx)
		var xp:int = SaveData.get_instance_xp(species,idx)
		if lv>best_lvl or (lv==best_lvl and xp>best_xp): best_lvl=lv; best_xp=xp
	var sorted := indices.duplicate(); sorted.sort(); sorted.reverse()
	for idx in sorted: SaveData.remove_instance(species,idx)
	SaveData.add_inventory_item("evolve_potion",-potions_needed)
	SaveData.add_instance(evolves_to,best_lvl,best_xp)
	SaveData.data.get_or_add("caught_monsters",[]).append(evolves_to)
	var remaining: int = SaveData.get_instance_count(species)
	var team: Array    = SaveData.get_team()
	var team_max: int  = int(GameData.prog_cfg("team_max_size", 3))

	# Remove excess team slots if we removed more copies than remain
	var team_count: int = 0
	for m in team:
		if str(m) == species: team_count += 1
	var excess: int = team_count - remaining
	if excess > 0:
		var i: int = team.size() - 1
		while i >= 0 and excess > 0:
			if str(team[i]) == species:
				team.remove_at(i)
				excess -= 1
			i -= 1

	if team.size() < team_max:
		team.append(evolves_to)

	SaveData.data["team"] = team
	SaveData.save()
	await _play_evo_anim(species, evolves_to)
	team_changed.emit()
	_detail_overlay.visible = false
	var evo_elem:String = GameData.get_monster(evolves_to).get("element",_selected_type)
	_select_type(evo_elem)


func _play_evo_anim(old_id: String, new_id: String):
	var old_data: Dictionary = GameData.get_monster(old_id)
	var new_data: Dictionary = GameData.get_monster(new_id)

	var PW := 1200.0; var PH := 800.0
	var IMG_SIZE := 360.0

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color   = Color(0, 0, 0, 0.0)
	overlay.z_index = 60
	_panel.add_child(overlay)

	var fd := get_tree().create_tween()
	fd.tween_property(overlay, "color", Color(0, 0, 0, 0.90), 0.35)
	await fd.finished

	var img := TextureRect.new()
	img.position     = Vector2((PW - IMG_SIZE) / 2.0, (PH - IMG_SIZE) / 2.0 - 60.0)
	img.size         = Vector2(IMG_SIZE, IMG_SIZE)
	img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.pivot_offset = Vector2(IMG_SIZE / 2.0, IMG_SIZE / 2.0)
	img.modulate.a   = 0.0
	var old_sp: String = old_data.get("sprite", "")
	if old_sp != "" and FileAccess.file_exists(old_sp): img.texture = load(old_sp)
	overlay.add_child(img)
	get_tree().create_tween().tween_property(img, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(0.8).timeout

	var glow := get_tree().create_tween().set_loops(4)
	glow.tween_property(img, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.22)
	glow.tween_property(img, "modulate", Color.WHITE, 0.22)
	await glow.finished

	var flash := get_tree().create_tween().set_parallel(true)
	flash.tween_property(overlay, "color", Color(1, 1, 1, 1), 0.28)
	flash.tween_property(img, "modulate", Color(2.5, 2.5, 2.5, 1), 0.28)
	await flash.finished

	var new_sp: String = new_data.get("sprite", "")
	if new_sp != "" and FileAccess.file_exists(new_sp): img.texture = load(new_sp)
	img.scale = Vector2(0.15, 0.15)

	get_tree().create_tween().tween_property(overlay, "color", Color(0, 0, 0, 0.90), 0.28)
	await get_tree().create_timer(0.30).timeout

	var si := get_tree().create_tween().set_parallel(true)
	si.tween_property(img, "scale", Vector2(1.15, 1.15), 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	si.tween_property(img, "modulate", Color.WHITE, 0.40)
	await si.finished
	get_tree().create_tween().tween_property(img, "scale", Vector2(1.0, 1.0), 0.12)

	var name_lbl := Label.new()
	name_lbl.text               = "%s  →  %s" % [old_data.get("name", old_id), new_data.get("name", new_id)]
	name_lbl.size               = Vector2(PW, 50)
	name_lbl.position           = Vector2(0.0, img.position.y + IMG_SIZE + 20.0)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	name_lbl.modulate.a = 0.0
	overlay.add_child(name_lbl)
	get_tree().create_tween().tween_property(name_lbl, "modulate:a", 1.0, 0.4)

	var sub_lbl := Label.new()
	sub_lbl.text               = "Evolution complete!"
	sub_lbl.size               = Vector2(PW, 32)
	sub_lbl.position           = Vector2(0.0, name_lbl.position.y + 56.0)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82, 0.90))
	sub_lbl.modulate.a = 0.0
	overlay.add_child(sub_lbl)
	get_tree().create_tween().tween_property(sub_lbl, "modulate:a", 1.0, 0.4).set_delay(0.2)

	await get_tree().create_timer(2.2).timeout
	var fo := get_tree().create_tween()
	fo.tween_property(overlay, "modulate:a", 0.0, 0.4)
	await fo.finished
	overlay.queue_free()


func _refresh_team_slots():
	var team:Array = SaveData.get_team()
	for i in _collection_team_slots.size():
		_collection_team_slots[i].texture=null
		if i<team.size():
			var md:=GameData.get_monster(str(team[i]))
			var sp:String=md.get("sprite","")
			if sp!="" and FileAccess.file_exists(sp): _collection_team_slots[i].texture=load(sp)


func _on_team_slot_click(slot_index: int, event: InputEvent):
	if not(event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT): return
	var team:Array=SaveData.get_team()
	if slot_index>=team.size(): return
	team.remove_at(slot_index); SaveData.data["team"]=team; SaveData.save()
	_refresh_team_slots()
	if _selected_type!="": _select_type(_selected_type)
	team_changed.emit()


func _update_element_label(lbl: Label, elem: String):
	var col: Color = GameData.ELEMENT_COLORS.get(elem, Color.WHITE)
	lbl.add_theme_color_override("font_color", col)
	for child in lbl.get_parent().get_children():
		if child.name.begins_with("ElemIcon_"):
			child.queue_free()
	var icon_tex := _load_sized_texture("res://assets/elements/elem_%s.png" % elem, 20)
	if icon_tex:
		lbl.text = "      " + elem.capitalize()  # indent space for the 20px icon
		var icon := TextureRect.new()
		icon.name         = "ElemIcon_" + elem
		icon.texture      = icon_tex
		icon.size         = Vector2(20, 20)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position     = Vector2(lbl.position.x, lbl.position.y + 3)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate     = col
		lbl.get_parent().add_child(icon)
	else:
		var emoji: String = GameData.ELEMENT_ICONS.get(elem, "◆")
		lbl.text = "%s  %s" % [emoji, elem.capitalize()]


func _load_sized_texture(path: String, target_size: int) -> ImageTexture:
	if not FileAccess.file_exists(path): return null
	var img := Image.load_from_file(path)
	if img == null: return null
	img.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


func _apply_kenney_btn(btn: Button, color: String, icon_path: String = ""):
	var path := "res://assets/ui/buttons/btn_rect_%s.png" % color
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img: tex = ImageTexture.create_from_image(img)

	var old_bg := btn.get_node_or_null("KenneyBg")
	if old_bg: old_bg.queue_free()

	if tex:
		var bg := TextureRect.new()
		bg.name         = "KenneyBg"
		bg.texture      = tex
		bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size         = btn.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index      = -1
		# Grey button texture is dark; darken further so text stays readable
		if color == "grey": bg.modulate = Color(0.35, 0.35, 0.40)
		btn.flat = true
		btn.add_child(bg)

	if icon_path != "":
		var ic: Texture2D = null
		if ResourceLoader.exists(icon_path): ic = load(icon_path)
		elif FileAccess.file_exists(icon_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(icon_path))
			if img: ic = ImageTexture.create_from_image(img)
		if ic:
			btn.icon = ic
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

	btn.alignment          = HORIZONTAL_ALIGNMENT_CENTER
	btn.icon_alignment     = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_color_override("font_color",          Color.WHITE)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.15, 0.15, 0.18))


func _on_close():
	visible = false
	closed.emit()
