extends Node2D

const SLEEP_DURATION := 30.0

@export var monster_id := "alyx"
@export var roam_bounds := Rect2(700.0, 260.0, 1020.0, 560.0)

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel

var rng := RandomNumberGenerator.new()
var target_position := Vector2.ZERO
var move_speed := 70.0
var jiggle_time := 0.0
var jiggle_offset := 0.0
var is_dragging := false
var drag_offset := Vector2.ZERO

var is_sleeping := false
var _zzz_timer: float = 0.0
var _recovery_timer: Timer = null
var _sleep_bar_bg: ColorRect = null
var _sleep_bar_fill: ColorRect = null

var _last_click_time: float = 0.0
var _click_count: int = 0
const DOUBLE_CLICK_WINDOW := 0.35


func _ready():
	rng.randomize()
	jiggle_offset = rng.randf_range(0.0, TAU)
	move_speed = rng.randf_range(45.0, 85.0)
	load_monster_data()

	if not roam_bounds.has_point(position):
		position = get_random_point()

	target_position = get_random_point()


func configure(next_monster_id: String, next_roam_bounds: Rect2):
	monster_id = next_monster_id
	roam_bounds = next_roam_bounds

	if is_node_ready():
		load_monster_data()
		position = get_random_point()
		target_position = get_random_point()


func load_monster_data():
	var monster_data = GameData.get_monster(monster_id)

	if monster_data.is_empty():
		name_label.text = monster_id
		return

	var sprite_path: String = monster_data.get("sprite", "")
	if sprite_path != "" and FileAccess.file_exists(sprite_path):
		sprite.texture = load(sprite_path)

	var lv: int = SaveData.get_monster_level(monster_id)
	var custom_name: String = SaveData.get_instance_custom_name(monster_id)
	var display: String = custom_name if custom_name != "" else monster_data.get("name", monster_id)

	if SaveData.get_instance_fainted(monster_id, 0):
		_enter_sleep_mode(display, lv)
	else:
		is_sleeping = false
		sprite.modulate   = Color.WHITE
		name_label.text   = "%s  Lv.%d" % [display, lv]


func _enter_sleep_mode(display_name: String, lvl: int):
	is_sleeping = true

	sprite.modulate = Color(0.55, 0.60, 0.80, 0.75)
	name_label.text = "💤 %s  Lv.%d" % [display_name, lvl]

	if not _sleep_bar_bg:
		_sleep_bar_bg = ColorRect.new()
		_sleep_bar_bg.size     = Vector2(80, 8)
		_sleep_bar_bg.position = Vector2(-40, 30)
		_sleep_bar_bg.color    = Color(0.10, 0.14, 0.22)
		add_child(_sleep_bar_bg)

		_sleep_bar_fill = ColorRect.new()
		_sleep_bar_fill.size   = Vector2(0, 8)
		_sleep_bar_fill.color  = Color(0.24, 0.55, 0.85)
		_sleep_bar_bg.add_child(_sleep_bar_fill)

	if _recovery_timer:
		_recovery_timer.queue_free()
	_recovery_timer = Timer.new()
	_recovery_timer.wait_time = 1.0
	_recovery_timer.autostart = true
	_recovery_timer.timeout.connect(_tick_recovery)
	add_child(_recovery_timer)


func _tick_recovery():
	if not SaveData.get_instance_fainted(monster_id, 0):
		_wake_up(); return

	var sleep_start: float = SaveData.get_instance_sleep_start(monster_id, 0)
	var elapsed: float     = Time.get_unix_time_from_system() - sleep_start
	var progress: float    = clampf(elapsed / SLEEP_DURATION, 0.0, 1.0)

	if _sleep_bar_fill:
		_sleep_bar_fill.size.x = 80.0 * progress

	if elapsed >= SLEEP_DURATION:
		_wake_up()


func _wake_up():
	if _recovery_timer:
		_recovery_timer.queue_free()
		_recovery_timer = null
	if _sleep_bar_bg:
		_sleep_bar_bg.queue_free()
		_sleep_bar_bg = null
		_sleep_bar_fill = null

	SaveData.set_instance_fainted(monster_id, 0, false)
	# Full recovery — reset HP and PP so next battle starts fresh
	SaveData.set_instance_current_hp(monster_id, 0, 0)
	SaveData.set_instance_pp(monster_id, 0, {})
	is_sleeping = false
	sprite.modulate = Color.WHITE

	var md: Dictionary    = GameData.get_monster(monster_id)
	var custom_name: String = SaveData.get_instance_custom_name(monster_id)
	var display: String   = custom_name if custom_name != "" else md.get("name", monster_id)
	var lv: int           = SaveData.get_monster_level(monster_id)
	name_label.text = "%s  Lv.%d" % [display, lv]

	var wake := Label.new()
	wake.text = "✨ Recovered!"
	wake.z_index = 10
	wake.add_theme_font_size_override("font_size", 16)
	wake.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	wake.position = Vector2(-40, -20)
	add_child(wake)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(wake, "position:y", wake.position.y - 50, 1.2)
	tw.tween_property(wake, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tw.tween_callback(wake.queue_free).set_delay(1.2)

	var wake_md: Dictionary = GameData.get_monster(monster_id)
	var sprite_path: String = wake_md.get("sprite", "")
	if sprite_path != "":
		sprite.texture = load(sprite_path)


func _any_panel_open() -> bool:
	var home := get_tree().root.get_node_or_null("Home")
	if home == null:
		return false
	for prop in ["_mogadex", "_shop"]:
		var panel = home.get(prop)
		if panel and panel.visible:
			return true
	var inv: Node = home.get("inventory_panel")
	if inv and inv.visible:
		return true
	return false


func _input(event: InputEvent):
	if _any_panel_open(): return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT): return
	if get_global_mouse_position().distance_to(global_position) > 80.0: return

	if event.pressed:
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_click_time < DOUBLE_CLICK_WINDOW:
			_click_count = 0
			is_dragging  = false
			get_viewport().set_input_as_handled()
			_on_double_click()
			return
		_last_click_time = now
		_click_count     = 1
		if not is_sleeping:
			is_dragging = true
			drag_offset = global_position - get_global_mouse_position()
			get_viewport().set_input_as_handled()
	else:
		if is_dragging:
			is_dragging = false
			target_position = get_random_point()


func _on_double_click():
	if is_sleeping:
		_show_tooltip("Already recovering... 💤")
		return

	var md: Dictionary     = GameData.get_monster(monster_id)
	var lv: int            = SaveData.get_monster_level(monster_id)
	var growth: Dictionary = GameData.get_growth(monster_id)
	var max_hp: int    = int(md.get("hp", 100)) + (lv - 1) * int(growth.get("hp", 8))
	var cur_hp: int    = SaveData.get_instance_current_hp(monster_id)
	if cur_hp <= 0: cur_hp = max_hp
	var hp_pct: float  = float(cur_hp) / float(max_hp)

	if hp_pct > 0.5:
		_show_tooltip("HP is still high!\nDouble-click when below 50%")
		return

	# Put to sleep — starts 30s recovery
	SaveData.set_instance_fainted(monster_id, 0, true)
	var custom_name: String = SaveData.get_instance_custom_name(monster_id)
	var display: String     = custom_name if custom_name != "" else md.get("name", monster_id)
	_enter_sleep_mode(display, lv)
	_show_tooltip("Going to sleep... 💤\nRecovers in 30s")


func _show_tooltip(msg: String):
	var lbl := Label.new()
	lbl.text = msg
	lbl.z_index = 20
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.50))
	lbl.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	lbl.size           = Vector2(160, 48)
	lbl.position       = Vector2(-80, -70)
	var bg := ColorRect.new()
	bg.color    = Color(0.04, 0.08, 0.14, 0.88)
	bg.size     = Vector2(164, 52)
	bg.position = Vector2(-82, -72)
	bg.z_index  = 19
	add_child(bg)
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.50).set_delay(1.80)
	tw.tween_property(bg,  "modulate:a", 0.0, 0.50).set_delay(1.80)
	tw.tween_callback(lbl.queue_free).set_delay(2.35)
	tw.tween_callback(bg.queue_free).set_delay(2.35)


func _process(delta):
	jiggle_time += delta

	if is_sleeping:
		_zzz_timer += delta
		if _zzz_timer >= 1.8:
			_zzz_timer = 0.0
			_spawn_zzz()
		return

	if is_dragging:
		if _any_panel_open():
			is_dragging = false
			target_position = get_random_point()
		else:
			global_position = get_global_mouse_position() + drag_offset
			position.x = clamp(position.x, roam_bounds.position.x, roam_bounds.position.x + roam_bounds.size.x)
			position.y = clamp(position.y, roam_bounds.position.y, roam_bounds.position.y + roam_bounds.size.y)
			z_index = int(position.y)
			return

	if position.distance_to(target_position) < 12.0:
		target_position = get_random_point()

	var direction = position.direction_to(target_position)
	position = position.move_toward(target_position, move_speed * delta)
	position.x = clamp(position.x, roam_bounds.position.x, roam_bounds.position.x + roam_bounds.size.x)
	position.y = clamp(position.y, roam_bounds.position.y, roam_bounds.position.y + roam_bounds.size.y)

	if abs(direction.x) > 0.05:
		sprite.flip_h = direction.x < 0.0

	sprite.position.y = sin((jiggle_time * 7.0) + jiggle_offset) * 5.0
	sprite.rotation_degrees = sin((jiggle_time * 4.0) + jiggle_offset) * 3.0
	z_index = int(position.y)


func _spawn_zzz():
	var letters := ["z", "Z", "Z"]
	for i in letters.size():
		var z := Label.new()
		z.text    = letters[i]
		z.z_index = 8
		z.add_theme_font_size_override("font_size", 12 + i * 5)
		z.add_theme_color_override("font_color", Color(0.55, 0.70, 1.0, 0.90))
		z.position = Vector2(rng.randf_range(-10, 20), -10 - i * 8)
		add_child(z)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(z, "position:y", z.position.y - 40, 1.0).set_delay(i * 0.2)
		tw.tween_property(z, "modulate:a", 0.0, 0.7).set_delay(i * 0.2 + 0.4)
		tw.tween_callback(z.queue_free).set_delay(i * 0.2 + 1.1)


func get_random_point() -> Vector2:
	return Vector2(
		rng.randf_range(roam_bounds.position.x, roam_bounds.position.x + roam_bounds.size.x),
		rng.randf_range(roam_bounds.position.y, roam_bounds.position.y + roam_bounds.size.y)
	)
