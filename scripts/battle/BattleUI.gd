class_name BattleUI extends RefCounted

const RADIUS := 10


static func _load_tex(path: String) -> Texture2D:
	if not FileAccess.file_exists(path): return null
	if ResourceLoader.exists(path): return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


static func _flat(bg: Color, border: Color = Color(0,0,0,0),
		border_w: int = 0, radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_border_width(side, border_w)
	for r in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_right","corner_radius_bottom_left"]:
		s.set(r, radius)
	return s


static func make_move_button() -> Button:
	var btn := Button.new()
	btn.flat       = false
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	# Default dark style — updated per-element in style_move_button
	var sn := _flat(Color(0.07, 0.12, 0.20), Color(0.18, 0.32, 0.50), 2)
	btn.add_theme_stylebox_override("normal",   sn)
	var sh := _flat(Color(0.10, 0.18, 0.30), Color(0.24, 0.45, 0.68), 2)
	btn.add_theme_stylebox_override("hover",    sh)
	var sd := _flat(Color(0.04, 0.06, 0.10, 0.6), Color(0.10, 0.15, 0.22), 1)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_color",          Color(0.90, 0.95, 1.00))
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.44, 0.50))
	return btn


static func make_action_button(lbl_text: String, bg: Color, border: Color) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text       = lbl_text
	btn.add_theme_font_size_override("font_size", 22)
	var sn := _flat(bg, border, 3, 12)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := _flat(bg.lightened(0.14), border.lightened(0.10), 3, 12)
	btn.add_theme_stylebox_override("hover", sh)
	var sp := _flat(bg.darkened(0.10), border, 2, 12)
	btn.add_theme_stylebox_override("pressed", sp)
	var sd := _flat(Color(0.06, 0.08, 0.11, 0.55), Color(0.14, 0.18, 0.24, 0.35), 1, 12)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_color",          Color.WHITE)
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.52, 0.56))
	return btn


static func make_circle_style(bg: Color, border: Color) -> StyleBoxFlat:
	return _flat(bg, border, 5, 136)


static func style_move_button(btn: Button, move_name: String, icon: String,
		element: String, col: Color, cur_pp: int, max_pp: int):
	for child in btn.get_children(): child.free()

	var bg_col: Color
	var border_col: Color
	if cur_pp <= 0:
		bg_col     = Color(0.06, 0.07, 0.10, 0.70)
		border_col = Color(0.18, 0.20, 0.26, 0.60)
	else:
		bg_col     = col.darkened(0.72)
		border_col = col.darkened(0.30)
		bg_col.a   = 1.0

	var sn := _flat(bg_col, border_col, 2)
	btn.add_theme_stylebox_override("normal", sn)
	var sh := _flat(bg_col.lightened(0.10), border_col.lightened(0.12), 2)
	btn.add_theme_stylebox_override("hover", sh)
	var sd := _flat(Color(0.04, 0.06, 0.10, 0.6), Color(0.10, 0.14, 0.20), 1)
	btn.add_theme_stylebox_override("disabled", sd)

	btn.add_theme_color_override("font_color",
		Color(0.85, 0.90, 0.95) if cur_pp > 0 else Color(0.38, 0.40, 0.44))
	btn.add_theme_color_override("font_disabled_color", Color(0.38, 0.40, 0.44))

	var accent := ColorRect.new()
	accent.size = Vector2(5, 128)
	accent.color = col if cur_pp > 0 else Color(0.22, 0.24, 0.30)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(accent)

	var badge := Label.new()
	badge.text = "%s  %s" % [icon, element.capitalize()]
	badge.position = Vector2(14, 8); badge.size = Vector2(300, 26)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", col if cur_pp > 0 else Color(0.38, 0.40, 0.44))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	var name_lbl := Label.new()
	name_lbl.text     = move_name
	name_lbl.position = Vector2(14, 38); name_lbl.size = Vector2(350, 56)
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color",
		Color(0.92, 0.96, 1.00) if cur_pp > 0 else Color(0.38, 0.40, 0.44))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(name_lbl)

	# PP colour: green > half, yellow > 0, red = empty
	var pp_col := Color(0.40, 0.80, 0.48) if cur_pp > max_pp / 2.0 \
		else (Color(0.92, 0.68, 0.18) if cur_pp > 0 else Color(0.72, 0.24, 0.22))
	var pp_lbl := Label.new()
	pp_lbl.text                 = "PP  %d/%d" % [cur_pp, max_pp]
	pp_lbl.position             = Vector2(btn.size.x - 144, 94)
	pp_lbl.size                 = Vector2(136, 24)
	pp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pp_lbl.add_theme_font_size_override("font_size", 14)
	pp_lbl.add_theme_color_override("font_color", pp_col)
	pp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pp_lbl)


static func add_elem_badge(parent: Node, elem: String, pos: Vector2, sz: Vector2,
		font_size: int = 16) -> void:
	var col: Color = GameData.ELEMENT_COLORS.get(elem, Color(0.5, 0.7, 0.8))
	var icon_size: int = font_size + 4
	var sized_tex: ImageTexture = null
	var icon_path := "res://assets/elements/elem_%s.png" % elem
	if FileAccess.file_exists(icon_path):
		var img := Image.load_from_file(icon_path)
		if img:
			img.resize(icon_size, icon_size, Image.INTERPOLATE_LANCZOS)
			sized_tex = ImageTexture.create_from_image(img)
	if sized_tex:
		var hbox := HBoxContainer.new()
		hbox.position  = pos
		hbox.size      = sz
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 4)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(hbox)
		var icon := TextureRect.new()
		icon.texture             = sized_tex
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate            = col
		icon.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
		var lbl := Label.new()
		lbl.text = elem.capitalize()
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", font_size)
		lbl.add_theme_color_override("font_color", col)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
	else:
		center_label(parent,
			"%s  %s" % [GameData.ELEMENT_ICONS.get(elem, "◆"), elem.capitalize()],
			font_size, col, pos, sz)


static func center_label(parent: Node, text: String, font_size: int,
		color: Color, pos: Vector2, sz: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text                 = text
	lbl.position             = pos
	lbl.size                 = sz
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


static func style_panel_button(btn: Button, bg: Color = Color(0.07,0.12,0.20),
		border: Color = Color(0.22,0.38,0.55), radius: int = 8):
	btn.add_theme_stylebox_override("normal",   _flat(bg, border, 2, radius))
	btn.add_theme_stylebox_override("hover",    _flat(bg.lightened(0.10), border.lightened(0.10), 2, radius))
	btn.add_theme_stylebox_override("disabled", _flat(bg.darkened(0.20), Color(0.14,0.20,0.28,0.40), 1, radius))
