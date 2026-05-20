extends Button

signal level_selected(level_id: String)

var level_id   := ""
var level_name := ""
var unlocked   := false
var completed  := false


func _ready():
	pressed.connect(_on_pressed)
	focus_mode                 = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	flat          = true
	text          = ""
	clip_contents = false


func configure(next_level_id: String, level_data: Dictionary, is_unlocked: bool, is_completed: bool):
	level_id   = next_level_id
	level_name = level_data.get("name", level_id)
	unlocked   = is_unlocked
	completed  = is_completed

	var map_position = level_data.get("position", [0, 0])
	position            = Vector2(float(map_position[0]), float(map_position[1]))
	size                = Vector2(48.0, 64.0)
	custom_minimum_size = size
	disabled            = not unlocked

	for c in get_children(): c.queue_free()

	# Boss: explicit difficulty flag OR late-game levels (order 40+)
	var is_boss: bool = level_data.get("difficulty", "") == "boss" or \
		int(level_data.get("order", 1)) >= 40

	var bg_path: String
	var icon_path: String
	var label_col: Color

	if completed:
		bg_path   = "res://assets/ui/map/node_completed.png"
		icon_path = "res://assets/ui/icons/ic_check_white.png"
		label_col = Color(0.55, 1.00, 0.65)
	elif not is_unlocked:
		bg_path   = "res://assets/ui/map/node_locked.png"
		icon_path = "res://assets/ui/icons/ic_locked_white.png"
		label_col = Color(0.60, 0.62, 0.68)
	elif is_boss:
		bg_path   = "res://assets/ui/map/node_boss.png"
		icon_path = "res://assets/ui/icons/ic_warning_white.png"
		label_col = Color(1.00, 0.60, 0.22)
	else:
		bg_path   = "res://assets/ui/map/node_available.png"
		icon_path = "res://assets/ui/icons/ic_star_white.png"
		label_col = Color(1.00, 0.90, 0.25)

	var bg := TextureRect.new()
	bg.size         = Vector2(48, 48)
	bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	if not is_unlocked: bg.modulate = Color(0.62, 0.62, 0.68)
	add_child(bg)

	var ic := TextureRect.new()
	ic.size         = Vector2(22, 22)
	ic.position     = Vector2(13, 6)
	ic.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	elif ResourceLoader.exists(icon_path.replace("_white", "")):
		ic.texture  = load(icon_path.replace("_white", ""))
		ic.modulate = Color.WHITE
	add_child(ic)

	var order: int = int(level_data.get("order", 0))
	var num := Label.new()
	num.text     = str(order)
	num.position = Vector2(-10, 50)
	num.size     = Vector2(68, 18)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fredoka One with dark outline for readability over the map background
	var ls := LabelSettings.new()
	ls.font_size     = 15
	ls.font_color    = Color.WHITE
	ls.outline_size  = 3
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.90)
	var font_path := "res://assets/fonts/FredokaOne.woff2"
	if ResourceLoader.exists(font_path):
		ls.font = load(font_path)
	elif FileAccess.file_exists(font_path):
		var img_font := Image.load_from_file(ProjectSettings.globalize_path(font_path))
		if img_font == null:
			pass
	num.label_settings = ls
	add_child(num)

	tooltip_text = "%s" % level_name


func _on_pressed():
	if unlocked:
		level_selected.emit(level_id)
