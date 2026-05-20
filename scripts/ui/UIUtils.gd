extends Node
class_name UIUtils

static func update_inventory_ui(panel: Control):
	if not panel:
		return

	panel.anchor_left   = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -600.0
	panel.offset_top    = -340.0
	panel.offset_right  = 600.0
	panel.offset_bottom = 340.0

	for child in panel.get_children():
		child.queue_free()
	await panel.get_tree().process_frame

	panel.color = Color(0.05, 0.09, 0.14, 0.97)

	var header := ColorRect.new()
	header.size  = Vector2(1200, 60)
	header.color = Color(0.03, 0.055, 0.10, 1)
	panel.add_child(header)

	var title := Label.new()
	title.text               = "INVENTORY"
	title.size               = Vector2(1200, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	GameTheme.apply_title(title, 28)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	header.add_child(title)

	var close_btn := GameTheme.make_close_btn(Vector2(1152, 10))
	close_btn.pressed.connect(func(): panel.visible = false)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 70)
	scroll.size     = Vector2(1160, 590)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	var items: Array = GameData.get_shop_items()

	for item: Dictionary in items:
		var count: int = SaveData.get_inventory_item(item["id"])

		var card := ColorRect.new()
		card.custom_minimum_size = Vector2(262, 226)
		card.clip_contents = true
		card.color = Color(0.07, 0.12, 0.20, 1) if count > 0 else Color(0.05, 0.08, 0.13, 1)
		grid.add_child(card)

		var accent := ColorRect.new()
		accent.size  = Vector2(262, 3)
		accent.color = Color(0.24, 0.65, 0.82, 0.7) if count > 0 else Color(0.2, 0.2, 0.25, 0.4)
		card.add_child(accent)

		var icon := TextureRect.new()
		icon.position     = Vector2(71, 14)
		icon.size         = Vector2(120, 110)
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate     = Color.WHITE if count > 0 else Color(0.4, 0.4, 0.45, 1)
		var icon_p: String = item.get("icon", "")
		if FileAccess.file_exists(icon_p):
			icon.texture = load(icon_p)
		card.add_child(icon)

		var badge_bg := ColorRect.new()
		badge_bg.position = Vector2(192, 10)
		badge_bg.size     = Vector2(60, 30)
		badge_bg.color    = Color(0.04, 0.08, 0.14, 0.9)
		card.add_child(badge_bg)

		var count_lbl := Label.new()
		count_lbl.text               = "x%d" % count
		count_lbl.size               = Vector2(60, 30)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 16)
		count_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if count > 0 else Color(0.45, 0.45, 0.50))
		badge_bg.add_child(count_lbl)

		var name_lbl := Label.new()
		name_lbl.text               = item.get("name", "")
		name_lbl.position           = Vector2(0, 130)
		name_lbl.size               = Vector2(262, 26)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color",
			Color.WHITE if count > 0 else Color(0.45, 0.48, 0.52))
		card.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text               = item.get("description", "")
		desc_lbl.anchor_left        = 0.0
		desc_lbl.anchor_right       = 1.0
		desc_lbl.anchor_top         = 0.0
		desc_lbl.anchor_bottom      = 0.0
		desc_lbl.offset_left        = 6
		desc_lbl.offset_right       = -6
		desc_lbl.offset_top         = 154
		desc_lbl.offset_bottom      = 196
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.70, 0.80))
		card.add_child(desc_lbl)

		if count == 0:
			var empty_lbl := Label.new()
			empty_lbl.text               = "— none —"
			empty_lbl.position           = Vector2(0, 194)
			empty_lbl.size               = Vector2(262, 24)
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 13)
			empty_lbl.add_theme_color_override("font_color", Color(0.40, 0.42, 0.45))
			card.add_child(empty_lbl)
