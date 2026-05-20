extends Node2D
class_name Monster

signal health_changed(current_hp: int, max_hp: int)
signal fainted

@export var monster_id: String = "alyx"
var instance_idx: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $HealthBox/NameLabel
@onready var hp_bar_fill: ColorRect = $HealthBox/HPBarBg/HPBarFill
@onready var hp_text: Label = $HealthBox/HPBarBg/HPText

var monster_data: Dictionary = {}

var max_hp := 100
var current_hp := 100
var level := 1
var xp := 0
var pulse_tween: Tween
var attack := 10
var defense := 0
var speed := 10
var attack_buff := 0
var attack_debuff := 0
var defense_buff := 0
var defense_debuff := 0
var speed_buff := 0
var speed_debuff := 0
var attack_buff_turns := 0
var attack_debuff_turns := 0
var defense_buff_turns := 0
var defense_debuff_turns := 0
var speed_buff_turns := 0
var speed_debuff_turns := 0
var status_label: Label
var rank_label: Label

var poison_turns:    int  = 0
var paralysis_turns: int  = 0
var burn_turns:      int  = 0
var _status_icon: Label  = null
var display_name := ""
var moves: Array = []
var is_fainted := false


func _ready():
	load_monster_data()
	setup_health_bar()

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	$HealthBox.add_child(status_label)
	status_label.position = Vector2(0, 45)

	rank_label = Label.new()
	rank_label.add_theme_font_size_override("font_size", 13)
	$HealthBox.add_child(rank_label)
	rank_label.position = Vector2(110, 2)
	rank_label.size = Vector2(90, 20)
	_update_rank_label()


func set_monster_id(next_monster_id: String):
	monster_id = next_monster_id
	load_monster_data()
	setup_health_bar()
	_update_rank_label()


func setup_health_bar():
	update_hp_display()
	name_label.text = "%s Lv.%d" % [display_name, level]
	health_changed.emit(current_hp, max_hp)
	position_health_bar()


func position_health_bar():
	if sprite.texture == null:
		return

	var sprite_size = sprite.texture.get_size() * Vector2(abs(sprite.scale.x), abs(sprite.scale.y))
	var head_y = sprite.position.y - (sprite_size.y * 0.5)

	var health_box = $HealthBox
	health_box.position = Vector2(sprite.position.x - 100.0, head_y - 80.0)


func update_hp_display():
	if hp_bar_fill:
		var percent = float(current_hp) / float(max_hp)
		var max_bar_width = hp_bar_fill.get_parent().size.x
		hp_bar_fill.size.x = max_bar_width * percent
		hp_text.text = "%d/%d" % [current_hp, max_hp]
		# Colour: green > 50%, yellow > 25%, red <= 25%
		if percent > 0.5:
			hp_bar_fill.color = Color(0.20, 0.80, 0.35)
		elif percent > 0.25:
			hp_bar_fill.color = Color(0.90, 0.72, 0.10)
		else:
			hp_bar_fill.color = Color(0.90, 0.22, 0.18)


func _update_rank_label():
	if not rank_label:
		return
	var rarity: String = monster_data.get("rarity", "common")
	rank_label.text = rarity.capitalize()
	rank_label.add_theme_color_override("font_color", GameData.rarity_color(rarity))


func load_monster_data():
	monster_data = GameData.get_monster(monster_id)

	if monster_data.is_empty():
		push_error("Monster id not found in data/monsters.json: %s" % monster_id)
		return
	var base_name: String = monster_data.get("name", monster_id)
	var custom_name: String = SaveData.get_instance_custom_name(monster_id, instance_idx)
	display_name = custom_name if custom_name != "" else base_name

	level = SaveData.get_instance_level(monster_id, instance_idx)
	xp    = SaveData.get_instance_xp(monster_id, instance_idx)

	var growth := GameData.get_growth(monster_id)
	max_hp  = int(monster_data.get("hp",      100)) + (level - 1) * int(growth.get("hp",      8))
	attack  = int(monster_data.get("attack",   10)) + (level - 1) * int(growth.get("attack",  2))
	defense = int(monster_data.get("defense",   0)) + (level - 1) * int(growth.get("defense", 1))
	speed   = int(monster_data.get("speed",     10)) + (level - 1) * int(growth.get("speed",   1))
	# Use saved HP; treat 0 or -1 (never set) as full HP
	var saved_hp: int = SaveData.get_instance_current_hp(monster_id, instance_idx)
	current_hp = clampi(saved_hp, 1, max_hp) if saved_hp > 0 else max_hp
	moves      = SaveData.get_active_moves(monster_id, instance_idx)
	is_fainted = false

	var sprite_path = monster_data.get("sprite", "")
	if sprite_path != "":
		sprite.texture = load(sprite_path)


func take_damage(amount: int, is_crit: bool = false, element: String = "none", multiplier: float = 1.0):
	var effective_defense = max(defense + defense_buff - defense_debuff, 0)
	var final_damage = max(amount - effective_defense, 1)
	current_hp -= final_damage
	current_hp = clamp(current_hp, 0, max_hp)

	var main_color: Color
	var badge_text: String  = ""
	var badge_color: Color  = Color.WHITE
	var num_size: int       = 52

	if is_crit:
		main_color  = Color(1.00, 0.35, 0.10)
		badge_text  = "CRITICAL!"
		badge_color = Color(1.00, 0.70, 0.15)
		num_size    = 64
	elif multiplier > 1.0:
		main_color  = Color(1.00, 0.88, 0.15)
		badge_text  = "Super Effective!"
		badge_color = Color(1.00, 0.88, 0.15)
		num_size    = 58
	elif multiplier < 1.0:
		main_color  = Color(0.60, 0.65, 0.72)
		badge_text  = "Resisted"
		badge_color = Color(0.60, 0.65, 0.72)
		num_size    = 44
	else:
		main_color = Color.WHITE

	spawn_damage_number(final_damage, main_color, num_size, badge_text, badge_color)

	if hp_bar_fill:
		var new_percent = float(current_hp) / float(max_hp)
		var max_bar_width = hp_bar_fill.get_parent().size.x
		var tween = create_tween()
		tween.tween_property(hp_bar_fill, "size:x", max_bar_width * new_percent, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		hp_text.text = "%d/%d" % [current_hp, max_hp]

	health_changed.emit(current_hp, max_hp)

	await hit_effect()

	if current_hp <= 0 and not is_fainted:
		is_fainted = true
		fainted.emit()


func get_attack_power() -> int:
	return max(attack + attack_buff - attack_debuff, 1)


func add_attack_buff(amount: int, turns: int = 3):
	attack_buff = amount
	attack_buff_turns = turns
	update_status_display()


func add_attack_debuff(amount: int, turns: int = 3):
	attack_debuff = amount
	attack_debuff_turns = turns
	update_status_display()


func add_defense_buff(amount: int, turns: int = 3):
	defense_buff = amount
	defense_buff_turns = turns
	update_status_display()


func add_defense_debuff(amount: int, turns: int = 3):
	defense_debuff = amount
	defense_debuff_turns = turns
	update_status_display()


func add_speed_buff(amount: int, turns: int = 3):
	speed_buff = amount
	speed_buff_turns = turns
	update_status_display()


func add_speed_debuff(amount: int, turns: int = 3):
	speed_debuff = amount
	speed_debuff_turns = turns
	update_status_display()


func process_turns():
	if attack_buff_turns > 0:
		attack_buff_turns -= 1
		if attack_buff_turns == 0: attack_buff = 0

	if attack_debuff_turns > 0:
		attack_debuff_turns -= 1
		if attack_debuff_turns == 0: attack_debuff = 0

	if defense_buff_turns > 0:
		defense_buff_turns -= 1
		if defense_buff_turns == 0: defense_buff = 0

	if defense_debuff_turns > 0:
		defense_debuff_turns -= 1
		if defense_debuff_turns == 0: defense_debuff = 0

	if speed_buff_turns > 0:
		speed_buff_turns -= 1
		if speed_buff_turns == 0: speed_buff = 0

	if speed_debuff_turns > 0:
		speed_debuff_turns -= 1
		if speed_debuff_turns == 0: speed_debuff = 0

	update_status_display()


func update_status_display():
	if not status_label:
		return

	var texts = []
	if attack_buff_turns > 0:
		texts.append("⚔️+%d (%d)" % [attack_buff, attack_buff_turns])
	if attack_debuff_turns > 0:
		texts.append("⚔️-%d (%d)" % [attack_debuff, attack_debuff_turns])
	if defense_buff_turns > 0:
		texts.append("🛡️+%d (%d)" % [defense_buff, defense_buff_turns])
	if defense_debuff_turns > 0:
		texts.append("🛡️-%d (%d)" % [defense_debuff, defense_debuff_turns])
	if speed_buff_turns > 0:
		texts.append("💨+%d (%d)" % [speed_buff, speed_buff_turns])
	if speed_debuff_turns > 0:
		texts.append("💨-%d (%d)" % [speed_debuff, speed_debuff_turns])

	status_label.text = " ".join(texts)


func hit_effect():
	var original_position = sprite.position

	sprite.modulate = Color(1.0, 0.25, 0.25)
	sprite.position = original_position + Vector2(8.0, 0.0)

	await get_tree().create_timer(0.04).timeout

	sprite.position = original_position + Vector2(-8.0, 0.0)

	await get_tree().create_timer(0.04).timeout

	sprite.position = original_position + Vector2(4.0, 0.0)

	await get_tree().create_timer(0.04).timeout

	sprite.position = original_position
	sprite.modulate = Color.WHITE


func heal(amount: int):
	var old_hp = current_hp
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)

	var healed_amount = current_hp - old_hp
	if healed_amount > 0:
		spawn_damage_number(healed_amount, Color(0.25, 0.95, 0.42), 50, "Heal", Color(0.25, 0.95, 0.42), true)

		if hp_bar_fill:
			var new_percent = float(current_hp) / float(max_hp)
			var tween = create_tween()
			tween.tween_property(hp_bar_fill, "size:x", hp_bar_fill.get_parent().size.x * new_percent, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			await tween.finished
			hp_text.text = "%d/%d" % [current_hp, max_hp]

		health_changed.emit(current_hp, max_hp)


func spawn_damage_number(amount: int, main_col: Color, font_sz: int,
		badge: String = "", badge_col: Color = Color.WHITE, is_heal: bool = false):
	var spawn_y: float = $HealthBox.position.y - 30.0
	var spawn_x: float = $HealthBox.position.x + 50.0

	var prefix: String = "+" if is_heal else "-"
	var num_lbl := Label.new()
	num_lbl.text         = prefix + str(amount)
	num_lbl.position     = Vector2(spawn_x, spawn_y)
	num_lbl.z_index      = 100

	var ls := LabelSettings.new()
	ls.font_size     = font_sz
	ls.font_color    = main_col
	ls.outline_size  = 4
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.88)
	num_lbl.label_settings = ls

	add_child(num_lbl)

	num_lbl.pivot_offset = num_lbl.size / 2.0

	num_lbl.scale = Vector2(0.35, 0.35)
	var bounce := create_tween()
	bounce.tween_property(num_lbl, "scale", Vector2(1.20, 1.20), 0.11) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.tween_property(num_lbl, "scale", Vector2(1.00, 1.00), 0.08) \
		.set_trans(Tween.TRANS_QUAD)
	await bounce.finished

	var rise := create_tween().set_parallel(true)
	rise.tween_property(num_lbl, "position:y", spawn_y - 90.0, 0.65) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rise.tween_property(num_lbl, "modulate:a", 0.0, 0.40).set_delay(0.30)
	rise.tween_callback(num_lbl.queue_free).set_delay(0.70)

	if badge != "":
		var badge_lbl := Label.new()
		badge_lbl.text    = badge
		badge_lbl.z_index = 100

		var bls := LabelSettings.new()
		bls.font_size     = int(font_sz * 0.45)
		bls.font_color    = badge_col
		bls.outline_size  = 3
		bls.outline_color = Color(0.0, 0.0, 0.0, 0.85)
		badge_lbl.label_settings = bls

		badge_lbl.position = Vector2(spawn_x - 10.0, spawn_y + font_sz * 0.55)
		add_child(badge_lbl)

		badge_lbl.scale = Vector2(0.4, 0.4)
		var bbounce := create_tween()
		bbounce.tween_property(badge_lbl, "scale", Vector2(1.0, 1.0), 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
		await bbounce.finished

		var brise := create_tween().set_parallel(true)
		brise.tween_property(badge_lbl, "position:y", badge_lbl.position.y - 80.0, 0.60) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		brise.tween_property(badge_lbl, "modulate:a", 0.0, 0.38).set_delay(0.28)
		brise.tween_callback(badge_lbl.queue_free).set_delay(0.65)


func apply_poison(turns: int):
	poison_turns = maxi(poison_turns, turns)
	_refresh_status_icon()


func apply_paralysis(turns: int):
	paralysis_turns = maxi(paralysis_turns, turns)
	_refresh_status_icon()


func apply_burn(turns: int):
	burn_turns = maxi(burn_turns, turns)
	add_attack_debuff(3, turns)  # burn reduces ATK
	_refresh_status_icon()


func tick_burn() -> int:
	if burn_turns <= 0: return 0
	var dmg := 5
	current_hp -= dmg
	current_hp  = maxi(current_hp, 0)
	burn_turns -= 1
	_refresh_status_icon()
	spawn_damage_number(dmg, Color(1.0, 0.45, 0.10), 38, "Burn", Color(1.0, 0.45, 0.10))
	if hp_bar_fill:
		var pct: float = float(current_hp) / float(max_hp)
		var w: float   = hp_bar_fill.get_parent().size.x
		create_tween().tween_property(hp_bar_fill, "size:x", w * pct, 0.35)
		hp_text.text = "%d/%d" % [current_hp, max_hp]
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0 and not is_fainted:
		is_fainted = true
		fainted.emit()
	return dmg


# Returns true if paralysis procs this turn (50% chance) and decrements
func tick_paralysis() -> bool:
	if paralysis_turns <= 0: return false
	paralysis_turns -= 1
	_refresh_status_icon()
	return randf() < 0.50


func tick_poison() -> int:
	if poison_turns <= 0: return 0
	var dmg := 5
	current_hp -= dmg
	current_hp  = maxi(current_hp, 0)
	poison_turns -= 1
	_refresh_status_icon()
	spawn_damage_number(dmg, Color(0.75, 0.20, 0.90), 38, "Poison", Color(0.75, 0.20, 0.90))
	if hp_bar_fill:
		var pct: float = float(current_hp) / float(max_hp)
		var w: float   = hp_bar_fill.get_parent().size.x
		create_tween().tween_property(hp_bar_fill, "size:x", w * pct, 0.35)
		hp_text.text = "%d/%d" % [current_hp, max_hp]
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0 and not is_fainted:
		is_fainted = true
		fainted.emit()
	return dmg


func _refresh_status_icon():
	if not _status_icon:
		_status_icon = Label.new()
		_status_icon.position    = Vector2(115, -4)
		_status_icon.z_index     = 10
		_status_icon.add_theme_font_size_override("font_size", 18)
		$HealthBox.add_child(_status_icon)

	var parts: Array = []
	if poison_turns > 0:    parts.append("☠×%d" % poison_turns)
	if paralysis_turns > 0: parts.append("⚡×%d" % paralysis_turns)
	if burn_turns > 0:      parts.append("🔥×%d" % burn_turns)
	_status_icon.text = "  ".join(parts)
	var col := Color(0.75, 0.20, 0.90) if poison_turns > 0 \
		else (Color(1.0, 0.45, 0.10) if burn_turns > 0 else Color(1.0, 0.88, 0.15))
	_status_icon.add_theme_color_override("font_color", col)


func clear_status_conditions():
	poison_turns    = 0
	paralysis_turns = 0
	burn_turns      = 0
	_refresh_status_icon()


func set_active(active: bool):
	if pulse_tween:
		pulse_tween.kill()
	sprite.modulate = Color.WHITE
