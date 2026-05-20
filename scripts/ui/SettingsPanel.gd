extends CanvasLayer

const SETTINGS_PATH := "user://settings.json"
const VERSION       := "v0.1.0"

signal closed()

var _panel: ColorRect


func _ready():
	layer   = 1000
	visible = false
	_build()
	load_settings()


func open():
	visible = true


func _build():
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color        = Color(0, 0, 0, 0.70)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = ColorRect.new()
	_panel.anchor_left   = 0.5; _panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -340; _panel.offset_top   = -300
	_panel.offset_right  =  340; _panel.offset_bottom = 300
	_panel.color         = Color(0.05, 0.09, 0.14, 0.98)
	add_child(_panel)

	var border := ColorRect.new()
	border.position = Vector2(-2, -2); border.size = Vector2(684, 604)
	border.color    = Color(0.24, 0.85, 0.82, 0.25); border.z_index = -1
	_panel.add_child(border)

	var header := ColorRect.new()
	header.size = Vector2(680, 60); header.color = Color(0.03, 0.055, 0.10, 1)
	_panel.add_child(header)

	var title := Label.new()
	title.text = "SETTINGS"
	title.size = Vector2(680, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	GameTheme.apply_title(title, 26)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	header.add_child(title)

	var close_btn := GameTheme.make_close_btn(Vector2(632, 10))
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	_add_section_label("Music Volume", 80)
	var music_slider := _add_slider(120, AudioManager.music_volume)
	music_slider.name = "MusicSlider"
	music_slider.value_changed.connect(func(v: float):
		AudioManager.set_music_volume(v)
		save_settings()
	)

	_add_section_label("Sound Effects Volume", 190)
	var sfx_slider := _add_slider(230, AudioManager.sfx_volume)
	sfx_slider.name = "SFXSlider"
	sfx_slider.value_changed.connect(func(v: float):
		AudioManager.set_sfx_volume(v)
		save_settings()
	)

	var div := ColorRect.new()
	div.position = Vector2(30, 330); div.size = Vector2(620, 1)
	div.color    = Color(0.24, 0.85, 0.82, 0.20)
	_panel.add_child(div)

	_add_section_label("Save Data", 350)

	var reset_btn := Button.new()
	reset_btn.text     = "Reset Save (Current Slot)"
	reset_btn.position = Vector2(30, 388); reset_btn.size = Vector2(300, 44)
	reset_btn.add_theme_font_size_override("font_size", 15)
	reset_btn.pressed.connect(_on_reset_pressed)
	_panel.add_child(reset_btn)

	var slot_lbl := Label.new()
	slot_lbl.name     = "SlotLabel"
	slot_lbl.position = Vector2(350, 400); slot_lbl.size = Vector2(300, 28)
	slot_lbl.add_theme_font_size_override("font_size", 14)
	slot_lbl.add_theme_color_override("font_color", Color(0.60, 0.70, 0.75))
	_panel.add_child(slot_lbl)
	_refresh_slot_label()

	var div2 := ColorRect.new()
	div2.position = Vector2(30, 450); div2.size = Vector2(620, 1)
	div2.color    = Color(0.18, 0.32, 0.48, 0.30)
	_panel.add_child(div2)

	var ver := Label.new()
	ver.text               = "MonsterRealm  %s" % VERSION
	ver.position           = Vector2(0, 462); ver.size = Vector2(680, 40)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(0.40, 0.50, 0.58))
	_panel.add_child(ver)

	var cr := Label.new()
	cr.text               = "Made with Godot 4"
	cr.position           = Vector2(0, 494); cr.size = Vector2(680, 28)
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr.add_theme_font_size_override("font_size", 12)
	cr.add_theme_color_override("font_color", Color(0.32, 0.40, 0.48))
	_panel.add_child(cr)


func _add_section_label_icon(text: String, y: int, icon_path: String = ""):
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture      = load(icon_path)
		ic.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size         = Vector2(22, 22)
		ic.position     = Vector2(30, y + 3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate     = Color(0.85, 0.90, 0.95)
		_panel.add_child(ic)
	_add_section_label(text, y, icon_path != "")


func _add_section_label(text: String, y: int, has_icon: bool = false):
	var lbl := Label.new()
	lbl.text     = text
	var lx: int  = 58 if has_icon else 30
	lbl.position = Vector2(lx, y); lbl.size = Vector2(300, 28)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	_panel.add_child(lbl)


func _add_slider(y: int, initial: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = initial
	slider.position  = Vector2(30, y)
	slider.size      = Vector2(540, 36)
	_panel.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.position = Vector2(584, y + 4)
	val_lbl.size     = Vector2(60, 28)
	val_lbl.text     = "%d%%" % int(initial * 100)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	_panel.add_child(val_lbl)

	slider.value_changed.connect(func(v: float): val_lbl.text = "%d%%" % int(v * 100))
	return slider


func _refresh_slot_label():
	var lbl := _panel.get_node_or_null("SlotLabel")
	if lbl:
		lbl.text = "Active slot:  %d  of  3" % (SaveData.current_slot + 1)


func _on_reset_pressed():
	var confirm := ConfirmationDialog.new()
	confirm.title            = "Reset Save?"
	confirm.dialog_text      = "This will delete all progress in slot %d.\nAre you sure?" % (SaveData.current_slot + 1)
	confirm.get_ok_button().text = "Yes, reset"
	_panel.add_child(confirm)
	confirm.popup_centered()
	confirm.confirmed.connect(func():
		SaveData.reset_save()
		confirm.queue_free()
	)


func _on_close():
	visible = false
	closed.emit()


func save_settings():
	var d := {
		"music_volume": AudioManager.music_volume,
		"sfx_volume":   AudioManager.sfx_volume,
		"current_slot": SaveData.current_slot,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(d, "\t"))


func load_settings():
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null: return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return
	var d: Dictionary = json.data if json.data is Dictionary else {}
	AudioManager.set_music_volume(float(d.get("music_volume", 0.8)))
	AudioManager.set_sfx_volume(float(d.get("sfx_volume", 0.8)))
	# Slot is handled by SaveSlotPanel on first load
