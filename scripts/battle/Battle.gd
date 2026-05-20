extends Control

@onready var player_monster: Monster = $Battlefield/PlayerSide/PlayerMonster
@onready var enemy_monster: Monster  = $Battlefield/EnemySide/EnemyMonster
@onready var background: TextureRect = $Background

# ── UI layer & built nodes ────────────────────────────────────────────────────
var ui_layer: CanvasLayer
var bottom_bar: ColorRect
var move_buttons: Array[Button] = []
var turn_circle_bg: Control
var turn_label: Label
var action_item_btn: Button
var action_capture_btn: Button
var action_run_btn: Button
var active_portrait: TextureRect
var active_name_label: Label
var active_hp_fill: ColorRect
var active_hp_label: Label
var team_slot_icons: Array[TextureRect] = []
var item_overlay: Control
var swap_overlay: Control
var tooltip_panel: Control
var tooltip_labels: Dictionary = {}
var log_container: VBoxContainer
var log_lines: Array[Label] = []

const LOG_MAX     := 5
const LOG_COLORS  := {
	"player": Color(0.40, 0.92, 0.85, 1.0),
	"enemy":  Color(1.00, 0.55, 0.25, 1.0),
	"system": Color(0.85, 0.88, 0.92, 0.85),
	"good":   Color(0.40, 0.92, 0.50, 1.0),
	"bad":    Color(0.95, 0.35, 0.35, 1.0),
}

# ── Battle state ──────────────────────────────────────────────────────────────
var _state := BattleState.new()  ## all mutable battle state

# Element colors loaded from GameData.ELEMENT_COLORS (game_config.json)
const KIND_ICONS := {"damage": "⚔", "buff": "↑", "debuff": "↓"}

signal _prebattle_chosen(monster_id: String)
var _starter_id: String = ""


func _ready():
	randomize()
	$UI.visible = false
	_build_battle_ui()

	# Determine enemy before showing pre-battle screen
	var level_data  := GameData.get_level(GameState.selected_level_id)
	var enemy_team: Array = level_data.get("enemy_team", ["monster_1"])
	var enemy_id    := _pick_by_rarity(enemy_team) if not enemy_team.is_empty() else "monster_1"

	await _show_prebattle_select(enemy_id)
	setup_level(enemy_id, _starter_id)


# Weighted random pick from enemy_team based on each monster's rarity
func _pick_by_rarity(enemy_team: Array) -> String:
	var rarities: Dictionary = GameData.config.get("rarities", {})
	var pool: Array = []   # [{id, weight}]
	var total_weight: int = 0

	for mid in enemy_team:
		var mdata := GameData.get_monster(str(mid))
		var rarity := str(mdata.get("rarity", "common"))
		var weight: int = int(rarities.get(rarity, {}).get("encounter_weight", 60))
		pool.append({"id": str(mid), "weight": weight})
		total_weight += weight

	if total_weight == 0:
		return str(enemy_team[randi() % enemy_team.size()])

	var roll := randi() % total_weight
	var cumulative := 0
	for entry in pool:
		cumulative += entry.weight
		if roll < cumulative:
			return entry.id

	return str(pool[-1].id)


# ══════════════════════════════════════════════════════════════════════════════
# PRE-BATTLE SELECT
# ══════════════════════════════════════════════════════════════════════════════

func _show_prebattle_select(enemy_id: String):
	var enemy_data  := GameData.get_monster(enemy_id)
	var enemy_elem: String = enemy_data.get("element", "")
	var level_data  := GameData.get_level(GameState.selected_level_id)
	var level_name: String = level_data.get("name", "Battle!")
	var team: Array = SaveData.get_team()

	var overlay := ColorRect.new()
	overlay.offset_left   = 0;  overlay.offset_top    = 0
	overlay.offset_right  = 1920; overlay.offset_bottom = 1080
	overlay.color         = Color(0.03, 0.05, 0.10, 0.96)
	overlay.z_index       = 50
	ui_layer.add_child(overlay)

	overlay.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "modulate:a", 1.0, 0.35)
	await fade_in.finished

	# ── Header ────────────────────────────────────────────────────────────
	var level_lbl := Label.new()
	level_lbl.text               = level_name
	level_lbl.size               = Vector2(1920, 44)
	level_lbl.position           = Vector2(0, 22)
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 24)
	level_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75, 0.80))
	overlay.add_child(level_lbl)

	var appeared_lbl := Label.new()
	appeared_lbl.text               = "A wild %s appeared!" % enemy_data.get("name", enemy_id)
	appeared_lbl.size               = Vector2(1920, 52)
	appeared_lbl.position           = Vector2(0, 64)
	appeared_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	appeared_lbl.add_theme_font_size_override("font_size", 38)
	appeared_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	overlay.add_child(appeared_lbl)

	# Thin separator
	var sep := ColorRect.new()
	sep.size     = Vector2(900, 1)
	sep.position = Vector2(510, 124)
	sep.color    = Color(0.24, 0.85, 0.82, 0.20)
	overlay.add_child(sep)

	# ── LEFT — "Choose your Monster" + 3 team cards ───────────────────────
	var choose_lbl := Label.new()
	choose_lbl.text               = "Choose your Monster"
	choose_lbl.position           = Vector2(40, 136)
	choose_lbl.size               = Vector2(860, 42)
	choose_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choose_lbl.add_theme_font_size_override("font_size", 26)
	choose_lbl.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	overlay.add_child(choose_lbl)

	# 3 team cards — evenly distributed in x=40..900
	const CARD_W   := 260
	const CARD_H   := 540
	const CARD_Y   := 188
	const CARD_GAP := 20
	var total_cards_w := team.size() * CARD_W + (team.size() - 1) * CARD_GAP
	var cards_start_x := 40 + (860 - total_cards_w) / 2

	for i in team.size():
		var mid: String = str(team[i])
		var md          := GameData.get_monster(mid)
		var eff: float  = GameData.get_effectiveness(md.get("element", ""), enemy_elem)
		var cx          := cards_start_x + i * (CARD_W + CARD_GAP)
		_make_team_card(overlay, Vector2(cx, CARD_Y), CARD_W, CARD_H, mid, md, eff, i)

	# ── Vertical divider ──────────────────────────────────────────────────
	var vdiv := ColorRect.new()
	vdiv.position = Vector2(930, 136)
	vdiv.size     = Vector2(2, 592)
	vdiv.color    = Color(0.20, 0.35, 0.50, 0.35)
	overlay.add_child(vdiv)


	# ── RIGHT — Enemy info card ────────────────────────────────────────────
	var enemy_lbl := Label.new()
	enemy_lbl.text               = "Wild Monster"
	enemy_lbl.position           = Vector2(960, 136)
	enemy_lbl.size               = Vector2(920, 42)
	enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_lbl.add_theme_font_size_override("font_size", 22)
	enemy_lbl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.75, 0.80))
	overlay.add_child(enemy_lbl)

	# Enemy card centered in right section (x=960..1880)
	var ec_w := 460; var ec_h := 540
	var ec_x := 960 + (920 - ec_w) / 2
	_make_enemy_card(overlay, Vector2(ec_x, 188), ec_w, ec_h, enemy_data, enemy_id)

	# ── Legend ────────────────────────────────────────────────────────────
	var legend := Label.new()
	legend.text               = "Effective  •  Neutral  •  Less effective"
	legend.position           = Vector2(0, 952)
	legend.size               = Vector2(1920, 30)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_font_size_override("font_size", 16)
	legend.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68, 0.80))
	overlay.add_child(legend)

	var chosen = await _prebattle_chosen
	_starter_id = chosen[0] if chosen is Array else str(chosen)

	var slide := create_tween()
	slide.tween_property(overlay, "position:y", -1080.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await slide.finished
	overlay.queue_free()


func _make_enemy_card(parent: Node, pos: Vector2, cw: int, ch: int, md: Dictionary, mid: String):
	var card := ColorRect.new()
	card.position = pos
	card.size     = Vector2(cw, ch)
	card.color    = Color(0.06, 0.10, 0.16, 1.0)
	parent.add_child(card)

	var border := ColorRect.new()
	border.position = Vector2(-2, -2)
	border.size     = Vector2(cw + 4, ch + 4)
	border.color    = Color(0.20, 0.45, 0.62, 0.30)
	border.z_index  = -1
	card.add_child(border)

	# Large sprite — flipped to face left (toward player)
	var sprite := TextureRect.new()
	sprite.position     = Vector2((cw - 260) / 2, 20)
	sprite.size         = Vector2(260, 260)
	sprite.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.flip_h       = true
	var sp: String = md.get("sprite", "")
	if sp != "" and FileAccess.file_exists(sp):
		sprite.texture = load(sp)
	card.add_child(sprite)

	var elem: String = md.get("element", "")
	var elem_col: Color = GameData.ELEMENT_COLORS.get(elem, Color(0.5, 0.7, 0.8))

	BattleUI.center_label(card, md.get("name", mid), 30, Color(1.0, 0.85, 0.3), Vector2(0, 292), Vector2(cw, 44))
	BattleUI.add_elem_badge(card, elem, Vector2(0, 342), Vector2(cw, 30), 20)
	BattleUI.center_label(card, md.get("rarity", "common").capitalize(), 15, Color(0.60, 0.70, 0.75, 0.80), Vector2(0, 378), Vector2(cw, 26))

	# Stats row
	var base_hp:  int = md.get("hp",      0) as int
	var base_atk: int = md.get("attack",  0) as int
	var base_def: int = md.get("defense", 0) as int
	BattleUI.center_label(card,
		"HP %d   ATK %d   DEF %d" % [base_hp, base_atk, base_def],
		15, Color(0.70, 0.80, 0.85, 0.90), Vector2(0, 416), Vector2(cw, 24))

	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.35).set_delay(0.15)


func _make_team_card(parent: Node, pos: Vector2, cw: int, ch: int, mid: String, md: Dictionary, effectiveness: float, slot_idx: int):
	var border_col: Color
	if   effectiveness > 1.0: border_col = Color(0.20, 0.85, 0.35, 0.70)
	elif effectiveness < 1.0: border_col = Color(0.90, 0.25, 0.20, 0.65)
	else:                      border_col = Color(0.24, 0.45, 0.65, 0.40)

	var matchup_col: Color
	var matchup_text: String
	if   effectiveness > 1.0: matchup_text = "2x Effective!"; matchup_col = Color(0.25, 0.92, 0.45)
	elif effectiveness < 1.0: matchup_text = "2x Less";       matchup_col = Color(0.95, 0.30, 0.25)
	else:                      matchup_text = "Neutral";       matchup_col = Color(0.65, 0.70, 0.75)

	var card := ColorRect.new()
	card.position = pos
	card.size     = Vector2(cw, ch)
	card.color    = Color(0.07, 0.12, 0.20, 1.0)
	parent.add_child(card)

	var border := ColorRect.new()
	border.position = Vector2(-2, -2)
	border.size     = Vector2(cw + 4, ch + 4)
	border.color    = border_col
	border.z_index  = -1
	card.add_child(border)

	# Top accent strip in matchup colour
	var accent := ColorRect.new()
	accent.size  = Vector2(cw, 4)
	accent.color = matchup_col * Color(1,1,1, 0.60)
	card.add_child(accent)

	# Sprite
	var sprite := TextureRect.new()
	sprite.position     = Vector2((cw - 160) / 2, 14)
	sprite.size         = Vector2(160, 160)
	sprite.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sp: String = md.get("sprite", "")
	if sp != "" and FileAccess.file_exists(sp):
		sprite.texture = load(sp)
	card.add_child(sprite)

	var elem: String    = md.get("element", "")
	var level: int      = SaveData.get_monster_level(mid)
	var growth: Dictionary = GameData.get_growth(mid)
	var max_hp: int     = int(md.get("hp", 100)) + (level - 1) * int(growth.get("hp", 8))
	var saved_hp: int   = SaveData.get_instance_current_hp(mid)
	var cur_hp: int     = clampi(saved_hp, 1, max_hp) if saved_hp > 0 else max_hp
	var base_hp: int    = cur_hp  # used for the label below

	BattleUI.center_label(card, md.get("name", mid),                          18, Color.WHITE,                          Vector2(0, 182), Vector2(cw, 28))
	BattleUI.center_label(card, "Lv. %d" % level,                             14, Color(0.60, 0.75, 0.85, 0.85),        Vector2(0, 212), Vector2(cw, 22))
	BattleUI.add_elem_badge(card, elem, Vector2(0, 238), Vector2(cw, 22), 14)

	# Matchup badge
	var badge_bg := ColorRect.new()
	badge_bg.position = Vector2(16, 270)
	badge_bg.size     = Vector2(cw - 32, 34)
	badge_bg.color    = matchup_col * Color(1,1,1, 0.16)
	card.add_child(badge_bg)
	BattleUI.center_label(badge_bg, matchup_text, 16, matchup_col, Vector2(0, 0), Vector2(cw - 32, 34))

	# HP bar
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(16, 316)
	hp_bg.size     = Vector2(cw - 32, 8)
	hp_bg.color    = Color(0.06, 0.10, 0.15)
	card.add_child(hp_bg)
	var hp_pct: float = float(cur_hp) / float(max_hp)
	var hp_fill := ColorRect.new()
	hp_fill.size  = Vector2((cw - 32) * hp_pct, 8)
	hp_fill.color = Color(0.20, 0.78, 0.35) if hp_pct > 0.5 \
		else (Color(0.90, 0.70, 0.10) if hp_pct > 0.25 else Color(0.88, 0.22, 0.18))
	hp_bg.add_child(hp_fill)
	BattleUI.center_label(card, "%d / %d HP" % [cur_hp, max_hp], 12, Color(0.55, 0.75, 0.55, 0.85), Vector2(0, 328), Vector2(cw, 20))

	# GO! button
	var btn_sn := StyleBoxFlat.new()
	btn_sn.bg_color    = matchup_col * Color(1,1,1, 0.22)
	btn_sn.border_color = matchup_col
	for sd in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		btn_sn.set_border_width(sd, 2)
	btn_sn.corner_radius_top_left    = 8
	btn_sn.corner_radius_top_right   = 8
	btn_sn.corner_radius_bottom_right  = 8
	btn_sn.corner_radius_bottom_left   = 8
	var btn_sh := btn_sn.duplicate() as StyleBoxFlat
	btn_sh.bg_color = matchup_col * Color(1,1,1, 0.42)

	var is_fainted: bool = SaveData.get_instance_fainted(mid, 0)
	var go_btn := Button.new()
	go_btn.position = Vector2(16, ch - 72)
	go_btn.size     = Vector2(cw - 32, 56)
	go_btn.add_theme_font_size_override("font_size", 16 if is_fainted else 26)

	if is_fainted:
		# Grey overlay on the whole card
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color        = Color(0, 0, 0, 0.55)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(dim)

		var elapsed: float = Time.get_unix_time_from_system() - SaveData.get_instance_sleep_start(mid, 0)
		var secs_left: int = maxi(0, int(30.0 - elapsed))
		go_btn.text     = "💤 Recovering\n%ds" % secs_left
		go_btn.disabled = true
		var dis_sn := btn_sn.duplicate() as StyleBoxFlat
		dis_sn.bg_color = Color(0.12, 0.12, 0.16, 1.0)
		dis_sn.border_color = Color(0.30, 0.30, 0.36, 0.50)
		go_btn.add_theme_stylebox_override("normal",   dis_sn)
		go_btn.add_theme_stylebox_override("disabled", dis_sn)
		go_btn.add_theme_color_override("font_color",          Color(0.50, 0.55, 0.65))
		go_btn.add_theme_color_override("font_disabled_color", Color(0.50, 0.55, 0.65))
	else:
		go_btn.text = "GO!"
		go_btn.add_theme_stylebox_override("normal", btn_sn)
		go_btn.add_theme_stylebox_override("hover",  btn_sh)
		go_btn.pressed.connect(func():
			_starter_id = mid
			_prebattle_chosen.emit(mid)
		)
	card.add_child(go_btn)

	# Staggered entrance from below
	card.modulate.a = 0.0
	card.position   = pos + Vector2(0, 50)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.28).set_delay(0.07 * slot_idx)
	tw.tween_property(card, "position",   pos, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.07 * slot_idx)






# ══════════════════════════════════════════════════════════════════════════════
# UI BUILDER
# ══════════════════════════════════════════════════════════════════════════════



func _build_battle_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)

	const BAR_Y    := 788.0
	const BAR_H    := 292.0
	const SCREEN_W := 1920.0

	# ── Main bar background ──────────────────────────────────────────────
	bottom_bar = ColorRect.new()
	bottom_bar.offset_left   = 0
	bottom_bar.offset_top    = BAR_Y
	bottom_bar.offset_right  = SCREEN_W
	bottom_bar.offset_bottom = BAR_Y + BAR_H
	bottom_bar.color = Color(0.048, 0.072, 0.102, 0.97)
	ui_layer.add_child(bottom_bar)

	var top_accent := ColorRect.new()
	top_accent.size  = Vector2(SCREEN_W, 3)
	top_accent.color = Color(0.16, 0.42, 0.58, 0.75)
	bottom_bar.add_child(top_accent)

	# ═══════════════════════════════════════════════════════════════
	# SECTION A — Portrait  x=0..206
	# ═══════════════════════════════════════════════════════════════
	var portrait_bg := ColorRect.new()
	portrait_bg.position = Vector2(0, 0)
	portrait_bg.size     = Vector2(206, 292)
	portrait_bg.color    = Color(0.038, 0.060, 0.086, 1)
	bottom_bar.add_child(portrait_bg)

	# Divider
	var port_div := ColorRect.new()
	port_div.position = Vector2(204, 0)
	port_div.size     = Vector2(2, 292)
	port_div.color    = Color(0.16, 0.32, 0.48, 0.55)
	bottom_bar.add_child(port_div)

	# Circular portrait frame via Panel + StyleBoxFlat
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color    = Color(0.07, 0.13, 0.20, 1)
	pf_style.border_color = Color(0.22, 0.62, 0.80, 0.9)
	for sd in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		pf_style.set_border_width(sd, 3)
	pf_style.corner_radius_top_left     = 84
	pf_style.corner_radius_top_right    = 84
	pf_style.corner_radius_bottom_right = 84
	pf_style.corner_radius_bottom_left  = 84
	var port_frame := Panel.new()
	port_frame.position = Vector2(14, 10)
	port_frame.size     = Vector2(178, 178)
	port_frame.add_theme_stylebox_override("panel", pf_style)
	portrait_bg.add_child(port_frame)

	active_portrait = TextureRect.new()
	active_portrait.position     = Vector2(9, 9)
	active_portrait.size         = Vector2(160, 160)
	active_portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	active_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	port_frame.add_child(active_portrait)

	# Transparent clickable button over the portrait — opens swap popup
	var portrait_btn := Button.new()
	portrait_btn.flat          = true
	portrait_btn.size          = Vector2(178, 178)
	portrait_btn.focus_mode    = Control.FOCUS_NONE
	portrait_btn.self_modulate = Color(1, 1, 1, 0)
	portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	portrait_btn.tooltip_text  = "Switch Monster"
	portrait_btn.pressed.connect(_on_portrait_clicked)
	port_frame.add_child(portrait_btn)

	active_name_label = Label.new()
	active_name_label.position             = Vector2(0, 193)
	active_name_label.size                 = Vector2(206, 22)
	active_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_name_label.add_theme_font_size_override("font_size", 14)
	active_name_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	portrait_bg.add_child(active_name_label)

	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(12, 220)
	hp_bg.size     = Vector2(182, 10)
	hp_bg.color    = Color(0.06, 0.10, 0.15)
	portrait_bg.add_child(hp_bg)

	active_hp_fill = ColorRect.new()
	active_hp_fill.size  = Vector2(182, 10)
	active_hp_fill.color = Color(0.20, 0.80, 0.35)
	hp_bg.add_child(active_hp_fill)

	active_hp_label = Label.new()
	active_hp_label.position             = Vector2(0, 234)
	active_hp_label.size                 = Vector2(206, 18)
	active_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_hp_label.add_theme_font_size_override("font_size", 12)
	active_hp_label.add_theme_color_override("font_color", Color(0.70, 0.85, 0.70))
	portrait_bg.add_child(active_hp_label)

	team_slot_icons.clear()
	var slot_btn_tex: Texture2D = null
	var slot_btn_active_tex: Texture2D = null
	if ResourceLoader.exists("res://assets/ui/buttons/btn_slot.png"):
		slot_btn_tex = load("res://assets/ui/buttons/btn_slot.png")
	if ResourceLoader.exists("res://assets/ui/buttons/btn_slot_active.png"):
		slot_btn_active_tex = load("res://assets/ui/buttons/btn_slot_active.png")

	for i in 3:
		var sb := Control.new()
		sb.position = Vector2(12 + i * 60, 254)
		sb.size     = Vector2(54, 34)
		portrait_bg.add_child(sb)

		# Slot background using Kenney button texture
		var slot_bg := TextureRect.new()
		slot_bg.name         = "SlotBg"
		slot_bg.texture      = slot_btn_tex
		slot_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_bg.size         = Vector2(54, 34)
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sb.add_child(slot_bg)

		var ic := TextureRect.new()
		ic.size         = Vector2(54, 34)
		ic.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sb.add_child(ic)
		team_slot_icons.append(ic)
		# Direct gui_input on the slot background — more reliable than an invisible child button
		var slot_idx := i
		sb.mouse_filter = Control.MOUSE_FILTER_STOP
		sb.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton \
					and event.button_index == MOUSE_BUTTON_LEFT \
					and event.pressed:
				_try_swap_to_slot(slot_idx)
		)

	# ═══════════════════════════════════════════════════════════════
	# SECTION B — Left moves  x=210..630  (moves 0 & 1)
	# SECTION D — Right moves x=1180..1600 (move 2 & signature)
	# ═══════════════════════════════════════════════════════════════
	# Left moves x=210-630, right moves x=914-1596 (fills old log+signature space)
	move_buttons.clear()
	var move_pos := [
		Vector2(210, 10), Vector2(210, 152),   # left: moves 0, 1
		Vector2(914, 10), Vector2(914, 152),   # right: moves 2, 3
	]
	for i in 4:
		var btn := BattleUI.make_move_button()
		btn.position = move_pos[i]
		btn.size     = Vector2(686 if i >= 2 else 418, 128)
		btn.pressed.connect(_on_move_button_pressed.bind(i))
		btn.mouse_entered.connect(_on_move_btn_hover.bind(i))
		btn.mouse_exited.connect(_hide_tooltip)
		bottom_bar.add_child(btn)
		move_buttons.append(btn)

	# ═══════════════════════════════════════════════════════════════
	# SECTION C — Center: large CAPTURE / YOUR TURN circle  x=638
	# ═══════════════════════════════════════════════════════════════
	action_capture_btn = Button.new()
	action_capture_btn.position      = Vector2(638, 12)
	action_capture_btn.size          = Vector2(268, 268)
	action_capture_btn.flat          = true
	action_capture_btn.focus_mode    = Control.FOCUS_NONE
	action_capture_btn.clip_contents = false
	bottom_bar.add_child(action_capture_btn)

	# Kenney round button as background — yellow for player turn
	var circle_bg := TextureRect.new()
	circle_bg.name         = "CircleBg"
	circle_bg.size         = Vector2(268, 268)
	circle_bg.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	circle_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	circle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle_bg.z_index      = -1
	circle_bg.texture = BattleUI._load_tex("res://assets/ui/buttons/btn_round_blue.png")
	action_capture_btn.add_child(circle_bg)

	turn_circle_bg = action_capture_btn

	turn_label = Label.new()
	turn_label.size                 = Vector2(268, 268)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 26)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_capture_btn.add_child(turn_label)

	# Log removed — log_container stays null, add_log() is a no-op

	# ═══════════════════════════════════════════════════════════════
	# SECTION D — USE ITEM + RUN  x=1606..1916
	# ═══════════════════════════════════════════════════════════════
	action_item_btn = BattleUI.make_action_button(
		"USE ITEM",
		Color(0.06, 0.26, 0.14, 1), Color(0.22, 0.75, 0.38, 1)
	)
	action_item_btn.position = Vector2(1606, 10)
	action_item_btn.size     = Vector2(308, 128)
	action_item_btn.pressed.connect(_on_use_item_pressed)
	bottom_bar.add_child(action_item_btn)

	action_run_btn = BattleUI.make_action_button(
		"RUN",
		Color(0.24, 0.07, 0.07, 1), Color(0.72, 0.22, 0.18, 1)
	)
	action_run_btn.position = Vector2(1606, 152)
	action_run_btn.size     = Vector2(308, 128)
	action_run_btn.pressed.connect(_on_run_pressed)
	bottom_bar.add_child(action_run_btn)

	_build_tooltip()
	_build_item_overlay()
	_build_swap_overlay()




func add_log(_text: String, _type: String = "system"):
	return  # log removed


func _add_log_unused(text: String, type: String = "system"):
	if not log_container:
		return
	for i in range(LOG_MAX - 1):
		log_lines[i].text    = log_lines[i + 1].text
		log_lines[i].add_theme_color_override("font_color",
			log_lines[i + 1].get_theme_color("font_color"))
		log_lines[i].modulate.a = log_lines[i + 1].modulate.a * 0.72

	# Write newest at bottom
	var newest := log_lines[LOG_MAX - 1]
	newest.text = text
	newest.add_theme_color_override("font_color", LOG_COLORS.get(type, LOG_COLORS["system"]))
	newest.modulate.a = 0.0

	# Fade in newest line
	var tw := create_tween()
	tw.tween_property(newest, "modulate:a", 1.0, 0.25)


func _build_tooltip():
	tooltip_panel = ColorRect.new()
	tooltip_panel.visible = false
	tooltip_panel.color   = Color(0.04, 0.08, 0.13, 0.97)
	tooltip_panel.z_index = 40
	ui_layer.add_child(tooltip_panel)

	var border := ColorRect.new()
	border.color   = Color(0.24, 0.85, 0.82, 0.28)
	border.z_index = -1
	border.name    = "Border"
	tooltip_panel.add_child(border)
	# Content is built dynamically in _show_tooltip


func _show_tooltip(move_id: String, btn: Button):
	var md           := GameData.get_move(move_id)
	var kind: String  = md.get("kind", "damage")
	var accuracy: int = int(md.get("accuracy", 100))
	var elem: String  = md.get("element", "")
	var elem_col: Color = GameData.ELEMENT_COLORS.get(elem, Color(0.6, 0.7, 0.8))
	var move_name: String = md.get("name", move_id)

	# Clear old content (keep Border)
	for child in tooltip_panel.get_children():
		if child.name != "Border":
			child.free()

	# ── Header (move name) ──────────────────────────────────
	var header := Label.new()
	header.text     = move_name
	header.position = Vector2(10, 8)
	header.size     = Vector2(220, 24)
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", elem_col if elem != "" else Color(0.24, 0.85, 0.82))
	tooltip_panel.add_child(header)

	var divider := ColorRect.new()
	divider.position = Vector2(8, 34)
	divider.size     = Vector2(214, 1)
	divider.color    = Color(0.24, 0.85, 0.82, 0.25)
	tooltip_panel.add_child(divider)

	var rows: Array = []
	if kind == "damage":
		rows = [
			["Power",    str(md.get("power", 0))],
			["Accuracy", "%d%%" % accuracy],
			["Crit",     "10%"],
			["Element",  elem.capitalize() if elem != "" else "Neutral"],
		]
	else:
		# Buff / debuff — show plain-English description
		var effect_text: String = md.get("message", "Affects a stat.")
		# Clean up the message (remove leading verb phrases like "stoked its")
		rows = [
			["Type",     kind.capitalize()],
			["Accuracy", "%d%%" % accuracy],
			["Effect",   effect_text],
		]

	var y := 42
	for row in rows:
		var key := row[0] as String
		var val := row[1] as String
		var is_effect := key == "Effect"

		var key_lbl := Label.new()
		key_lbl.text     = key
		key_lbl.position = Vector2(10, y)
		key_lbl.size     = Vector2(74, 22)
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.72))
		tooltip_panel.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text     = val
		val_lbl.position = Vector2(88, y)
		val_lbl.size     = Vector2(142 if is_effect else 84, 52 if is_effect else 22)
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color.WHITE)
		if is_effect:
			val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tooltip_panel.add_child(val_lbl)

		y += 52 if is_effect else 22

	# Resize panel to fit content
	var panel_h := y + 10
	var panel_w := 240
	tooltip_panel.size = Vector2(panel_w, panel_h)
	var border := tooltip_panel.get_node("Border") as ColorRect
	border.position = Vector2(-2, -2)
	border.size     = Vector2(panel_w + 4, panel_h + 4)

	# Position above button, clamped to screen
	var btn_rect := btn.get_global_rect()
	var tx: float = clamp(btn_rect.position.x, 5.0, 1920.0 - float(panel_w) - 5.0)
	var ty := btn_rect.position.y - float(panel_h) - 10.0
	tooltip_panel.offset_left   = tx
	tooltip_panel.offset_top    = ty
	tooltip_panel.offset_right  = tx + panel_w
	tooltip_panel.offset_bottom = ty + panel_h
	tooltip_panel.visible = true


func _hide_tooltip():
	tooltip_panel.visible = false






func _build_item_overlay():
	item_overlay = ColorRect.new()
	item_overlay.visible      = false
	item_overlay.offset_left  = 0
	item_overlay.offset_top   = 0
	item_overlay.offset_right = 1920
	item_overlay.offset_bottom = 790
	item_overlay.color        = Color(0, 0, 0, 0.65)
	item_overlay.z_index      = 20
	ui_layer.add_child(item_overlay)

	var panel := ColorRect.new()
	panel.position = Vector2(660, 100)
	panel.size     = Vector2(600, 520)
	panel.color    = Color(0.05, 0.09, 0.14, 0.97)
	item_overlay.add_child(panel)

	var border := ColorRect.new()
	border.position = Vector2(-2, -2)
	border.size     = Vector2(604, 524)
	border.color    = Color(0.24, 0.85, 0.82, 0.25)
	border.z_index  = -1
	panel.add_child(border)

	var title := Label.new()
	title.text                 = "USE ITEM"
	title.position             = Vector2(0, 14)
	title.size                 = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	panel.add_child(title)

	var close_x := GameTheme.make_close_btn(Vector2(556, 8), Vector2(36, 36))
	close_x.pressed.connect(func(): item_overlay.visible = false)
	panel.add_child(close_x)

	# Items loaded from data/items.json — add/remove/reprice items there only
	var battle_items: Array = GameData.get_battle_items()

	for i in battle_items.size():
		var it: Dictionary = battle_items[i]
		var raw_col: Array  = it.get("ui_color", [0.08, 0.12, 0.20])
		var row := ColorRect.new()
		row.position    = Vector2(18, 66 + i * 74)
		row.size        = Vector2(564, 64)
		row.clip_contents = true
		row.color       = Color(raw_col[0], raw_col[1], raw_col[2], 1.0)
		panel.add_child(row)

		# Icon — left side
		var icon := TextureRect.new()
		icon.position     = Vector2(8, 8)
		icon.size         = Vector2(48, 48)
		icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_path: String = it.get("icon", "")
		if icon_path != "" and FileAccess.file_exists(icon_path):
			icon.texture = load(icon_path)
		row.add_child(icon)

		# Name — fixed 140px
		var lbl := Label.new()
		lbl.text               = it.get("name", "")
		lbl.position           = Vector2(64, 0)
		lbl.size               = Vector2(140, 64)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)

		# Description — anchored so it fills between name and count
		var desc := Label.new()
		desc.text               = it.get("description", "")
		desc.anchor_left        = 0.0
		desc.anchor_right       = 1.0
		desc.offset_left        = 208
		desc.offset_right       = -130
		desc.offset_top         = 0
		desc.offset_bottom      = 64
		desc.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", Color(0.75, 0.85, 0.90, 0.85))
		desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(desc)

		# Count badge
		var cnt := Label.new()
		cnt.name                 = "Cnt_%s" % it["id"]
		cnt.anchor_left          = 1.0
		cnt.anchor_right         = 1.0
		cnt.offset_left          = -124
		cnt.offset_right         = -72
		cnt.offset_top           = 0
		cnt.offset_bottom        = 64
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 16)
		cnt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cnt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cnt)

		# Use button — pinned to right edge
		var use := Button.new()
		use.text           = "Use"
		use.anchor_left    = 1.0
		use.anchor_right   = 1.0
		use.offset_left    = -66
		use.offset_right   = -4
		use.offset_top     = 12
		use.offset_bottom  = 52
		use.pressed.connect(_on_use_item_selected.bind(it["id"]))
		row.add_child(use)



func _build_swap_overlay():
	swap_overlay = ColorRect.new()
	swap_overlay.visible       = false
	swap_overlay.offset_left   = 0; swap_overlay.offset_top    = 0
	swap_overlay.offset_right  = 1920; swap_overlay.offset_bottom = 790
	swap_overlay.color         = Color(0, 0, 0, 0.72)
	swap_overlay.z_index       = 20
	swap_overlay.mouse_filter  = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(swap_overlay)
	# Click dim area to close
	swap_overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			swap_overlay.visible = false
	)


func _on_portrait_clicked():
	if _state.battle_over or not _state.is_player_turn: return
	_show_swap_popup()


func _show_swap_popup():
	var team: Array = SaveData.get_team()
	# Collect switchable monsters (alive, not currently active)
	var options: Array = []
	for mid_raw in team:
		var mid: String = str(mid_raw)
		if mid == player_monster.monster_id: continue
		if _state.is_fainted(mid): continue
		if SaveData.get_instance_fainted(mid, 0): continue
		options.append(mid)

	if options.is_empty():
		BattleAnimations.show_float_text(self,
			Vector2(960, 400), "No other monsters available!", Color(0.90, 0.65, 0.20))
		return

	# Rebuild swap panel content
	var panel := swap_overlay.get_node_or_null("SwapPanel") as ColorRect
	if panel: panel.queue_free()

	const CW := 260; const CH := 380; const GAP := 24
	var total_w: int = options.size() * CW + (options.size() - 1) * GAP
	var sx: int      = (1920 - total_w) / 2
	var sy: int      = 160

	var new_panel := ColorRect.new()
	new_panel.name     = "SwapPanel"
	new_panel.position = Vector2(sx - 24, sy - 60)
	new_panel.size     = Vector2(total_w + 48, CH + 120)
	new_panel.color    = Color(0.04, 0.07, 0.12, 0.96)
	swap_overlay.add_child(new_panel)

	# Title
	var title := Label.new()
	title.text = "SWITCH MONSTER"
	title.size = Vector2(total_w + 48, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82))
	new_panel.add_child(title)

	# Close button
	var close_x := GameTheme.make_close_btn(Vector2(total_w + 6, 4), Vector2(34, 34))
	close_x.pressed.connect(func(): swap_overlay.visible = false)
	new_panel.add_child(close_x)

	# Monster cards
	for i in options.size():
		var mid: String = options[i]
		var md: Dictionary = GameData.get_monster(mid)
		var cx: int = 24 + i * (CW + GAP)
		var cy: int = 52

		var card := ColorRect.new()
		card.position = Vector2(cx, cy); card.size = Vector2(CW, CH)
		card.color    = Color(0.07, 0.13, 0.22, 1.0)
		new_panel.add_child(card)

		# Top accent
		var acc := ColorRect.new()
		acc.size  = Vector2(CW, 4)
		acc.color = Color(0.22, 0.62, 0.85, 0.80)
		acc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(acc)

		# Monster sprite
		var spr := TextureRect.new()
		spr.position     = Vector2(30, 12); spr.size = Vector2(CW - 60, CW - 60)
		spr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sp: String = md.get("sprite", "")
		if sp != "" and FileAccess.file_exists(sp): spr.texture = load(sp)
		card.add_child(spr)

		# Name
		var lv: int = SaveData.get_monster_level(mid)
		var name_lbl := Label.new()
		name_lbl.text = md.get("name", mid)
		name_lbl.position = Vector2(0, CW - 48); name_lbl.size = Vector2(CW, 26)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv. %d" % lv
		lv_lbl.position = Vector2(0, CW - 22); lv_lbl.size = Vector2(CW, 20)
		lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv_lbl.add_theme_font_size_override("font_size", 13)
		lv_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 0.90))
		lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lv_lbl)

		# HP bar
		var saved_hp: int = SaveData.get_instance_current_hp(mid)
		var growth: Dictionary = GameData.get_growth(mid)
		var max_hp: int = int(md.get("hp", 100)) + (lv - 1) * int(growth.get("hp", 8))
		var cur_hp: int = clampi(saved_hp, 1, max_hp) if saved_hp > 0 else max_hp
		var hp_pct: float = float(cur_hp) / float(max_hp)
		var hp_bg := ColorRect.new()
		hp_bg.position = Vector2(12, CW + 2); hp_bg.size = Vector2(CW - 24, 8)
		hp_bg.color    = Color(0.06, 0.10, 0.16)
		hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hp_bg)
		var hp_fill := ColorRect.new()
		hp_fill.size  = Vector2((CW - 24) * hp_pct, 8)
		hp_fill.color = Color(0.22, 0.80, 0.38) if hp_pct > 0.5 \
			else (Color(0.90, 0.68, 0.14) if hp_pct > 0.25 else Color(0.88, 0.22, 0.18))
		hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bg.add_child(hp_fill)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d / %d HP" % [cur_hp, max_hp]
		hp_lbl.position = Vector2(0, CW + 12); hp_lbl.size = Vector2(CW, 18)
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 12)
		hp_lbl.add_theme_color_override("font_color", Color(0.60, 0.72, 0.80))
		hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(hp_lbl)

		# SWITCH button at bottom of card
		var switch_btn := Button.new()
		switch_btn.text     = "SWITCH"
		switch_btn.position = Vector2(12, CH - 52); switch_btn.size = Vector2(CW - 24, 44)
		switch_btn.add_theme_font_size_override("font_size", 18)
		var mid_cap := mid
		switch_btn.pressed.connect(func():
			swap_overlay.visible = false
			if _state.battle_over or not _state.is_player_turn: return
			await _execute_player_swap(mid_cap)
		)
		card.add_child(switch_btn)

	swap_overlay.visible = true


# ══════════════════════════════════════════════════════════════════════════════
# LEVEL SETUP
# ══════════════════════════════════════════════════════════════════════════════

# ── Signature move animations ─────────────────────────────────────────────────
## Called instead of normal projectile/lunge when a move has "signature": true.
## Uses only real VFX sprite assets + scale/modulate code effects. No fake shapes.
func _play_signature_anim(attacker: Node2D, defender: Node2D, element: String):
	var orig_scale: Vector2     = attacker.scale
	var def_orig_scale: Vector2 = defender.scale
	var elem_col: Color         = GameData.ELEMENT_COLORS.get(element, Color.WHITE)

	# No wind-up flash

	match element:

		# ── EARTHQUAKE — earth_rock 6×2(12f) + earth_impact 7×1(7f) ──────────
		"earth":
			var stomp := create_tween().set_parallel(true)
			stomp.tween_property(attacker, "scale", orig_scale * Vector2(1.35, 0.72), 0.14)
			stomp.tween_property(attacker, "global_position:y", attacker.global_position.y + 22, 0.14)
			await stomp.finished
			for _i in 3: BattleAnimations.shake_screen(self)
			_play_vfx_sheet(defender.global_position,               "res://assets/vfx/elements/earth/vfx_earth_rock.png",   6, 2, 14.0, 7.0)
			_play_vfx_sheet(defender.global_position + Vector2(0,20),"res://assets/vfx/elements/earth/vfx_earth_impact.png", 7, 1, 16.0, 6.0)
			await get_tree().create_timer(0.14).timeout
			var eq_sq := create_tween().set_parallel(true)
			eq_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.82, 1.22), 0.16)
			eq_sq.tween_property(defender, "modulate", Color(0.78, 0.62, 0.35, 1.0), 0.14)
			await eq_sq.finished

		# ── THUNDER STRIKE — Thunderstrike 13×1 + splash 14×1 ─────────────────
		"electric":
			_play_vfx_sheet(defender.global_position,              "res://assets/vfx/elements/thunder/Thunderstrike w blur.png",  13, 1, 18.0, 4.5)
			_play_vfx_sheet(defender.global_position + Vector2(0,10),"res://assets/vfx/elements/thunder/Thunder splash w blur.png",14, 1, 18.0, 4.0)
			BattleAnimations.shake_screen(self)
			await get_tree().create_timer(0.10).timeout
			var el_sq := create_tween().set_parallel(true)
			el_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.73, 1.32), 0.15)
			el_sq.tween_property(defender, "modulate", Color(1.6, 1.6, 0.30, 1.0), 0.12)
			await el_sq.finished

		# ── BLIZZARD — Frost Knight rise frames (ZIP, proper quality) ──────────
		"ice":
			_play_vfx_frames(defender.global_position,              "res://assets/vfx/elements/ice/rise/frames", 16.0)
			_play_vfx_frames(defender.global_position + Vector2(30,-20), "res://assets/vfx/elements/ice/frames",  20.0)
			BattleAnimations.shake_screen(self)
			await get_tree().create_timer(0.15).timeout
			var ic_sq := create_tween().set_parallel(true)
			ic_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.76, 1.28), 0.16)
			ic_sq.tween_property(defender, "modulate", Color(0.55, 0.88, 1.0,  1.0), 0.14)
			await ic_sq.finished

		# ── VOID STRIKE — dark frames (folder, skips 0KB) + sheets ───────────
		"dark":
			_play_vfx_frames(defender.global_position,              "res://assets/vfx/elements/dark/frames", 22.0)
			_play_vfx_frames(defender.global_position + Vector2(-15,-15), "res://assets/vfx/elements/dark/frames", 18.0)
			BattleAnimations.shake_screen(self)
			await get_tree().create_timer(0.12).timeout
			var dk_sq := create_tween().set_parallel(true)
			dk_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.78, 1.28), 0.15)
			dk_sq.tween_property(defender, "modulate", Color(0.50, 0.18, 0.78, 1.0), 0.13)
			await dk_sq.finished

		# ── CYCLONE — orbit + Air Explosion 4×3(12f) ──────────────────────────
		"wind":
			var orig_gp: Vector2 = attacker.global_position
			for loop in 2:
				for step in 16:
					var angle: float = (loop * 16 + step) / 16.0 * TAU
					attacker.global_position = defender.global_position + Vector2(cos(angle), sin(angle) * 0.40) * 130.0
					await get_tree().create_timer(0.022).timeout
			var ret := create_tween()
			ret.tween_property(attacker, "global_position", orig_gp, 0.18).set_trans(Tween.TRANS_QUAD)
			await ret.finished
			_play_vfx_sheet(defender.global_position, "res://assets/vfx/elements/wind/Air Explosion.png", 4, 3, 14.0, 5.0)
			BattleAnimations.shake_screen(self)
			var wn_sq := create_tween().set_parallel(true)
			wn_sq.tween_property(defender, "scale",           def_orig_scale * Vector2(0.76, 1.28), 0.16)
			wn_sq.tween_property(defender, "rotation_degrees", 14.0, 0.16)
			await wn_sq.finished

		# ── TIDAL WAVE — Water Blast 4×3(12f) + WaterBall impact ──────────────
		"water":
			_play_vfx_sheet(defender.global_position,               "res://assets/vfx/elements/water/Water Blast - Startup and Infinite.png", 4, 3, 14.0, 5.0)
			_play_vfx_sheet(defender.global_position + Vector2(0,10),"res://assets/vfx/elements/water/WaterBall - Impact.png",                 1, 1, 12.0, 4.0)
			BattleAnimations.shake_screen(self)
			await get_tree().create_timer(0.12).timeout
			var wa_sq := create_tween().set_parallel(true)
			wa_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.70, 1.34), 0.16)
			wa_sq.tween_property(defender, "modulate", Color(0.40, 0.72, 1.0,  1.0), 0.13)
			await wa_sq.finished

		# ── FIRE — fire_hit 5×1(5f) + fire_explosion 18×1(18f) ───────────────
		"fire":
			await _play_projectile_anim(attacker, defender, element)
			_play_vfx_sheet(defender.global_position,               "res://assets/vfx/elements/fire/vfx_fire_hit.png",       5,  1, 16.0, 4.5)
			_play_vfx_sheet(defender.global_position + Vector2(0,-10),"res://assets/vfx/elements/fire/vfx_fire_explosion.png",18, 1, 20.0, 5.0)
			BattleAnimations.shake_screen(self)
			BattleAnimations.shake_screen(self)
			var fi_sq := create_tween().set_parallel(true)
			fi_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.72, 1.32), 0.15)
			fi_sq.tween_property(defender, "modulate", Color(1.6,  0.55, 0.15, 1.0), 0.12)
			await fi_sq.finished

		# ── OTHER (nature/metal/light/poison/magic) — projectile + burst ───────
		_:
			await _play_projectile_anim(attacker, defender, element)
			BattleAnimations.shake_screen(self)
			BattleAnimations.shake_screen(self)
			_play_vfx_frames(defender.global_position, "res://assets/vfx/status/buff/atk_general/frames", 14.0)
			var ot_sq := create_tween().set_parallel(true)
			ot_sq.tween_property(defender, "scale",    def_orig_scale * Vector2(0.74, 1.32), 0.15)
			ot_sq.tween_property(defender, "modulate", Color(elem_col.r * 1.6, elem_col.g * 1.6, elem_col.b * 1.6, 1.0), 0.12)
			await ot_sq.finished

	# Universal restore
	var restore := create_tween().set_parallel(true)
	restore.tween_property(attacker, "scale",             orig_scale,     0.22).set_trans(Tween.TRANS_BACK)
	restore.tween_property(attacker, "modulate",          Color.WHITE,    0.20)
	restore.tween_property(defender, "scale",             def_orig_scale, 0.24).set_trans(Tween.TRANS_BACK)
	restore.tween_property(defender, "modulate",          Color.WHITE,    0.22)
	restore.tween_property(defender, "rotation_degrees",  0.0,            0.20)
	restore.tween_property(attacker, "global_position",   attacker.global_position, 0.01)
	await restore.finished


## Animates a sprite sheet by stepping through hframes×vframes at the given fps.
## This is the REAL animation — not a static display.
func _play_vfx_sheet(gpos: Vector2, path: String, hf: int, vf: int,
		fps: float = 14.0, scale_mult: float = 2.0):
	if not ResourceLoader.exists(path): return
	var spr := Sprite2D.new()
	spr.texture = load(path)
	if spr.texture == null: return
	spr.hframes         = hf
	spr.vframes         = vf
	spr.frame           = 0
	spr.z_index         = 90
	spr.global_position = gpos
	spr.scale           = Vector2(scale_mult, scale_mult)
	spr.modulate.a      = 0.0
	add_child(spr)

	var total: int      = hf * vf
	var ft: float       = 1.0 / fps

	# Fade in on first frame
	create_tween().tween_property(spr, "modulate:a", 1.0, ft)
	await get_tree().create_timer(ft).timeout

	# Step through every frame
	for i in range(1, total):
		spr.frame = i
		await get_tree().create_timer(ft).timeout

	# Fade out
	var fade := create_tween()
	fade.tween_property(spr, "modulate:a", 0.0, 0.14)
	await fade.finished
	spr.queue_free()


func _play_attack_anim(attacker: Node2D, defender: Node2D):
	# Use global_position — attacker and defender live in different parent nodes
	# so local position coordinates are incompatible.
	var orig_global: Vector2     = attacker.global_position
	var orig_scale: Vector2      = attacker.scale
	var def_orig_scale: Vector2  = defender.scale

	var target_global: Vector2   = orig_global.lerp(defender.global_position, 0.85)

	# Rush toward defender
	var rush := create_tween()
	rush.tween_property(attacker, "global_position", target_global, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await rush.finished

	# Impact squish
	var squish := create_tween().set_parallel(true)
	squish.tween_property(attacker, "scale", orig_scale * Vector2(1.25, 0.80), 0.12)
	squish.tween_property(defender, "scale", def_orig_scale * Vector2(0.80, 1.25), 0.12)
	await squish.finished

	# Snap back to original global position with bounce
	var snap := create_tween().set_parallel(true)
	snap.tween_property(attacker, "global_position", orig_global, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	snap.tween_property(attacker, "scale", orig_scale, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	snap.tween_property(defender, "scale", def_orig_scale, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await snap.finished


# ── Stat color helpers ────────────────────────────────────────────────────────
func _stat_color(stat: String, is_buff: bool) -> Color:
	if is_buff:
		match stat:
			"attack":  return Color(1.0, 0.60, 0.10)
			"defense": return Color(0.20, 0.65, 1.00)
			"speed":   return Color(0.30, 1.00, 0.80)
			"hp":      return Color(0.20, 0.92, 0.35)
		return Color(0.24, 0.85, 0.82)
	else:
		match stat:
			"attack":   return Color(0.95, 0.22, 0.22)
			"defense":  return Color(0.65, 0.35, 0.85)
			"speed":    return Color(0.55, 0.55, 0.75)
			"accuracy": return Color(0.50, 0.50, 0.55)
		return Color(0.80, 0.30, 0.80)


func _stat_label(stat: String, is_buff: bool) -> String:
	var arrow := "↑" if is_buff else "↓"
	match stat:
		"attack":   return "ATK %s" % arrow
		"defense":  return "DEF %s" % arrow
		"speed":    return "SPD %s" % arrow
		"accuracy": return "ACC %s" % arrow
		"hp":       return "HP %s" % arrow
	return stat.to_upper() + " " + arrow


# ── 1. BUFF animation (self-buff) ─────────────────────────────────────────────
func _play_buff_anim(caster: Node2D, stat: String):
	var col: Color        = _stat_color(stat, true)
	var orig_scale: Vector2 = caster.scale

	# Pulse scale up then bounce back
	var pulse := create_tween().set_parallel(true)
	pulse.tween_property(caster, "scale", orig_scale * 1.22, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(caster, "modulate", Color(col.r, col.g, col.b, 1.0), 0.18)
	await pulse.finished

	# Expanding ring at feet
	var ring := Panel.new()
	ring.z_index = 50
	var rs := StyleBoxFlat.new()
	rs.bg_color     = Color(0, 0, 0, 0)
	rs.border_color = col
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		rs.set_border_width(side, 3)
	rs.corner_radius_top_left     = 100
	rs.corner_radius_top_right    = 100
	rs.corner_radius_bottom_left  = 100
	rs.corner_radius_bottom_right = 100
	ring.add_theme_stylebox_override("panel", rs)
	ring.size = Vector2(10, 10)
	ring.pivot_offset = Vector2(5, 5)
	ring.global_position = caster.global_position - Vector2(5, 5)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ring)
	var rtw := create_tween().set_parallel(true)
	rtw.tween_property(ring, "size",         Vector2(180, 80),  0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rtw.tween_property(ring, "pivot_offset", Vector2(90, 40),   0.45)
	rtw.tween_property(ring, "global_position", caster.global_position - Vector2(90, 40), 0.45)
	rtw.tween_property(ring, "modulate:a",   0.0, 0.40).set_delay(0.12)

	# Restore scale and tint
	var restore := create_tween().set_parallel(true)
	restore.tween_property(caster, "scale",    orig_scale,    0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	restore.tween_property(caster, "modulate", Color.WHITE,   0.22)
	await restore.finished

	# Floating stat text
	BattleAnimations.show_float_text(self,
		caster.global_position + Vector2(0, -90),
		_stat_label(stat, true), col)
	# Play VFX sheet on top — Paladin buff sheets, exact frame counts
	match stat:
		"attack":  _play_vfx_sheet(caster.global_position + Vector2(0,-40), "res://assets/vfx/status/buff/vfx_buff_atk.png",     5, 4, 16.0, 3.2)
		"defense": _play_vfx_sheet(caster.global_position + Vector2(0,-40), "res://assets/vfx/status/buff/vfx_buff_def.png",     5, 4, 16.0, 3.2)
		"speed":   _play_vfx_frames(caster.global_position + Vector2(0,-40), "res://assets/vfx/status/buff/spd_up/frames",       16.0)
		_:         _play_vfx_sheet(caster.global_position + Vector2(0,-40), "res://assets/vfx/status/buff/vfx_buff_general.png", 5, 2, 14.0, 3.0)
	await get_tree().create_timer(0.10).timeout
	ring.queue_free()


# ── 2. DEBUFF animation (target enemy) ───────────────────────────────────────
func _play_debuff_anim(caster: Node2D, target: Node2D, stat: String):
	var col: Color = _stat_color(stat, false)

	# Caster rocks side-to-side (intimidation)
	var orig_x: float = caster.global_position.x
	var shake := create_tween()
	shake.tween_property(caster, "global_position:x", orig_x + 18,  0.07)
	shake.tween_property(caster, "global_position:x", orig_x - 18,  0.07)
	shake.tween_property(caster, "global_position:x", orig_x + 10,  0.06)
	shake.tween_property(caster, "global_position:x", orig_x,       0.06)
	await shake.finished

	# Target tints with sickly color + rocks back
	var orig_target_x: float = target.global_position.x
	var dir: float = 1.0 if target.global_position.x > caster.global_position.x else -1.0
	var hit := create_tween().set_parallel(true)
	hit.tween_property(target, "modulate", Color(col.r, col.g, col.b, 0.85), 0.12)
	hit.tween_property(target, "global_position:x", orig_target_x + dir * 20, 0.12)
	await hit.finished

	var restore := create_tween().set_parallel(true)
	restore.tween_property(target, "modulate",             Color.WHITE,      0.28)
	restore.tween_property(target, "global_position:x",   orig_target_x,    0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await restore.finished

	# Floating stat label on target
	BattleAnimations.show_float_text(self,
		target.global_position + Vector2(0, -90),
		_stat_label(stat, false), col)
	match stat:
		"attack":  _play_vfx_sheet(target.global_position, "res://assets/vfx/status/debuff/vfx_debuff_atk.png", 5, 3, 16.0, 3.2)
		"defense": _play_vfx_frames(target.global_position, "res://assets/vfx/status/debuff/def_down/frames",   16.0)
		"speed":   _play_vfx_frames(target.global_position, "res://assets/vfx/status/debuff/spd_down/frames",   16.0)
		_:         _play_vfx_sheet(target.global_position,  "res://assets/vfx/status/debuff/vfx_debuff_atk.png",5, 3, 14.0, 3.0)


# ── 3. HEAL animation ─────────────────────────────────────────────────────────
func _play_heal_anim(caster: Node2D):
	var col := Color(0.20, 0.92, 0.35)

	# Semi-transparent breath in/out
	var breath := create_tween()
	breath.tween_property(caster, "modulate:a", 0.55, 0.22).set_trans(Tween.TRANS_SINE)
	breath.tween_property(caster, "modulate:a", 1.00, 0.22).set_trans(Tween.TRANS_SINE)
	await breath.finished

	# Sparkle particles floating up
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in 7:
		var spark := Label.new()
		spark.text    = "✦"
		spark.z_index = 60
		spark.add_theme_font_size_override("font_size", rng.randi_range(14, 26))
		spark.add_theme_color_override("font_color", col)
		var sx: float = caster.global_position.x + rng.randf_range(-50, 50)
		var sy: float = caster.global_position.y + rng.randf_range(-20, 20)
		spark.global_position = Vector2(sx, sy)
		add_child(spark)
		var stw := create_tween().set_parallel(true)
		stw.tween_property(spark, "global_position:y", sy - rng.randf_range(70, 130), 0.80) \
			.set_delay(i * 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		stw.tween_property(spark, "modulate:a", 0.0, 0.55).set_delay(i * 0.06 + 0.30)
		stw.tween_callback(spark.queue_free).set_delay(i * 0.06 + 0.85)

	# Green glow pulse on caster
	var glow := create_tween().set_parallel(true)
	glow.tween_property(caster, "modulate", Color(col.r, col.g, col.b, 1.0), 0.18)
	glow.tween_property(caster, "scale",    caster.scale * 1.10,             0.18)
	await glow.finished
	var unglow := create_tween().set_parallel(true)
	unglow.tween_property(caster, "modulate", Color.WHITE,   0.22).set_trans(Tween.TRANS_BACK)
	unglow.tween_property(caster, "scale",    caster.scale / 1.10, 0.22).set_trans(Tween.TRANS_BACK)
	await unglow.finished
	_play_vfx_frames(caster.global_position + Vector2(0, -30), "res://assets/vfx/status/heal/wings/frames", 14.0)
	await get_tree().create_timer(0.35).timeout


# ── 4. RANGED PROJECTILE animation ───────────────────────────────────────────
func _play_projectile_anim(attacker: Node2D, defender: Node2D, element: String):
	var elem_col: Color = GameData.ELEMENT_COLORS.get(element, Color(0.24, 0.85, 0.82))
	var orig_scale: Vector2     = attacker.scale
	var def_orig_scale: Vector2 = defender.scale

	# Attacker wind-up: tiny scale down then snap forward
	var windup := create_tween()
	windup.tween_property(attacker, "scale", orig_scale * 0.88, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await windup.finished

	# Create orb projectile
	var orb := Panel.new()
	orb.z_index = 80
	var orb_size := Vector2(36, 36)
	orb.size = orb_size; orb.pivot_offset = orb_size / 2.0
	var orb_style := StyleBoxFlat.new()
	orb_style.bg_color = elem_col
	orb_style.corner_radius_top_left     = 18
	orb_style.corner_radius_top_right    = 18
	orb_style.corner_radius_bottom_left  = 18
	orb_style.corner_radius_bottom_right = 18
	orb.add_theme_stylebox_override("panel", orb_style)
	orb.global_position = attacker.global_position - orb_size / 2.0
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(orb)

	# Outer glow ring on orb
	var glow_lbl := Label.new()
	glow_lbl.text = "●"
	glow_lbl.modulate = Color(elem_col.r, elem_col.g, elem_col.b, 0.45)
	glow_lbl.add_theme_font_size_override("font_size", 60)
	glow_lbl.global_position = attacker.global_position - Vector2(30, 30)
	glow_lbl.z_index = 79
	add_child(glow_lbl)

	# Attacker snap-back while projectile flies
	var snapback := create_tween()
	snapback.tween_property(attacker, "scale", orig_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fly to target
	var target_gp: Vector2 = defender.global_position - orb_size / 2.0
	var fly := create_tween().set_parallel(true)
	fly.tween_property(orb, "global_position",     target_gp,             0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(glow_lbl, "global_position", defender.global_position - Vector2(30, 30), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(orb, "scale",               Vector2(1.3, 1.3),    0.38)
	await fly.finished

	# Impact burst
	orb.modulate = Color(elem_col.r * 2.0, elem_col.g * 2.0, elem_col.b * 2.0, 1.0)
	BattleAnimations.shake_screen(self)
	var burst := create_tween().set_parallel(true)
	burst.tween_property(orb,      "scale",      Vector2(2.5, 2.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(orb,      "modulate:a", 0.0,               0.18)
	burst.tween_property(glow_lbl, "modulate:a", 0.0,               0.18)
	# Defender impact squish
	burst.tween_property(defender, "scale", def_orig_scale * Vector2(0.78, 1.28), 0.12)
	await burst.finished

	var unsquish := create_tween()
	unsquish.tween_property(defender, "scale", def_orig_scale, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await unsquish.finished

	orb.queue_free(); glow_lbl.queue_free()


# ── 5. STATUS CONDITION TICK (per-turn visual for active debuffs) ─────────────
func _play_status_tick(monster: Node2D):
	# Shows a brief colored shimmer if the monster has active debuffs
	var has_atk_debuff: bool  = monster.attack_debuff_turns  > 0
	var has_def_debuff: bool  = monster.defense_debuff_turns > 0
	var has_spd_debuff: bool  = monster.speed_debuff_turns   > 0
	if not (has_atk_debuff or has_def_debuff or has_spd_debuff):
		return

	# Cycle through active debuff colors as a quick flash sequence
	var debuff_colors: Array = []
	if has_atk_debuff: debuff_colors.append(_stat_color("attack",  false))
	if has_def_debuff: debuff_colors.append(_stat_color("defense", false))
	if has_spd_debuff: debuff_colors.append(_stat_color("speed",   false))

	for col in debuff_colors:
		var flash := create_tween()
		flash.tween_property(monster, "modulate", Color(col.r, col.g, col.b, 0.80), 0.10)
		flash.tween_property(monster, "modulate", Color.WHITE,                       0.12)
		await flash.finished

	# Small "debuffed" particles drip downward
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in 4:
		var drip := Label.new()
		drip.text  = "▼"
		drip.z_index = 55
		drip.add_theme_font_size_override("font_size", 14)
		drip.add_theme_color_override("font_color", debuff_colors[i % debuff_colors.size()])
		var dx: float = monster.global_position.x + rng.randf_range(-40, 40)
		var dy: float = monster.global_position.y
		drip.global_position = Vector2(dx, dy)
		add_child(drip)
		var dtw := create_tween().set_parallel(true)
		dtw.tween_property(drip, "global_position:y", dy + 60, 0.55).set_delay(i * 0.07)
		dtw.tween_property(drip, "modulate:a", 0.0, 0.40).set_delay(i * 0.07 + 0.20)
		dtw.tween_callback(drip.queue_free).set_delay(i * 0.07 + 0.60)
	await get_tree().create_timer(0.45).timeout


# ── VFX Frame Player ─────────────────────────────────────────────────────────
## Plays a frame-by-frame VFX animation using AnimatedSprite2D.
## Skips 0-byte files (broken RAR extraction). Auto-cleans up.
func _play_vfx_frames(gpos: Vector2, frames_dir: String, fps: float = 14.0):
	var dir := DirAccess.open(frames_dir)
	if dir == null: return

	var paths: Array = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.to_lower().ends_with(".png"):
			var full: String = frames_dir + "/" + f
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(full)
			if bytes.size() > 128:           # skip 0-KB broken frames
				paths.append(full)
		f = dir.get_next()
	dir.list_dir_end()
	if paths.is_empty(): return
	paths.sort()

	# Build SpriteFrames resource at runtime
	var sf := SpriteFrames.new()
	sf.add_animation("play")
	sf.set_animation_speed("play", fps)
	sf.set_animation_loop("play", false)
	for p in paths:
		sf.add_frame("play", load(p))

	var anim := AnimatedSprite2D.new()
	anim.sprite_frames  = sf
	anim.animation      = "play"
	anim.z_index        = 90
	anim.global_position = gpos
	anim.scale          = Vector2(4.0, 4.0)
	add_child(anim)
	anim.play("play")
	await anim.animation_finished
	anim.queue_free()


## Returns the VFX frames directory for a given stat buff/debuff.
## Applies poison or paralysis from a move's status_effect field to the target.
func _try_apply_status(move_data: Dictionary, target: Monster):
	var effect: String  = move_data.get("status_effect", "")
	if effect == "": return
	var chance: float   = float(move_data.get("status_chance", 1.0))
	if randf() > chance: return
	var turns: int      = int(move_data.get("status_turns", 3))
	match effect:
		"poison":
			if target.poison_turns > 0:
				add_log("%s is already poisoned!" % target.display_name, "system")
				return
			target.apply_poison(turns)
			add_log("%s was poisoned! (%d turns)" % [target.display_name, turns], "bad" if target == player_monster else "good")
			BattleAnimations.show_float_text(self, target.global_position + Vector2(0, -70), "POISONED!", Color(0.75, 0.20, 0.90))
			_play_vfx_frames(target.global_position, "res://assets/vfx/status/smoke/frames")
		"paralysis":
			if target.paralysis_turns > 0:
				add_log("%s is already paralyzed!" % target.display_name, "system")
				return
			target.apply_paralysis(turns)
			add_log("%s was paralyzed! (%d turns)" % [target.display_name, turns], "bad" if target == player_monster else "good")
			BattleAnimations.show_float_text(self, target.global_position + Vector2(0, -70), "PARALYZED!", Color(1.0, 0.88, 0.15))
			_play_vfx_frames(target.global_position, "res://assets/vfx/elements/thunder")
		"burn":
			if target.burn_turns > 0:
				add_log("%s is already burned!" % target.display_name, "system")
				return
			target.apply_burn(turns)
			add_log("%s was burned! (%d turns)" % [target.display_name, turns], "bad" if target == player_monster else "good")
			BattleAnimations.show_float_text(self, target.global_position + Vector2(0, -70), "BURNED!", Color(1.0, 0.45, 0.10))
			_play_vfx_sheet(target.global_position, "res://assets/vfx/elements/fire/vfx_fire_hit.png", 5, 1, 16.0, 3.0)


## Ticks poison DoT for a monster. Returns HP lost (0 if not poisoned).
func _process_status_dot(monster: Monster) -> int:
	return monster.tick_poison()


func _vfx_path_for_stat(stat: String, is_buff: bool) -> String:
	if is_buff:
		match stat:
			"attack":  return "res://assets/vfx/status/buff/atk_up/frames"
			"defense": return "res://assets/vfx/status/buff/def_up/frames"
			"speed":   return "res://assets/vfx/status/buff/spd_up/frames"
		return "res://assets/vfx/status/buff/atk_general/frames"
	else:
		match stat:
			"attack":  return "res://assets/vfx/status/debuff/atk_down/frames"
			"defense": return "res://assets/vfx/status/debuff/def_down/frames"
			"speed":   return "res://assets/vfx/status/debuff/spd_down/frames"
		return "res://assets/vfx/status/debuff/atk_down/frames"


func _calc_enemy_level() -> int:
	var team: Array = SaveData.get_team()
	if team.is_empty(): return 1
	var total := 0
	for m in team:
		total += SaveData.get_monster_level(str(m))
	return maxi(1, total / team.size())


func _apply_enemy_level(monster: Monster, monster_id: String, lvl: int):
	monster.level = lvl
	var growth: Dictionary = GameData.get_growth(monster_id)
	var md: Dictionary     = monster.monster_data
	monster.max_hp  = int(md.get("hp",      100)) + (lvl - 1) * int(growth.get("hp",      8))
	monster.attack  = int(md.get("attack",   10))  + (lvl - 1) * int(growth.get("attack",  2))
	monster.defense = int(md.get("defense",   0))  + (lvl - 1) * int(growth.get("defense", 1))
	monster.speed   = int(md.get("speed",    10))  + (lvl - 1) * int(growth.get("speed",   1))
	monster.current_hp = monster.max_hp
	monster.setup_health_bar()


func setup_level(enemy_id: String, starter_id: String):
	var level_data := GameData.get_level(GameState.selected_level_id)
	var bg_path: String = level_data.get("background", "res://assets/map/map.png")
	background.texture = load(bg_path if (bg_path != "" and FileAccess.file_exists(bg_path)) else "res://assets/map/map.png")

	enemy_monster.set_monster_id(enemy_id)
	enemy_monster.sprite.flip_h = true
	enemy_monster.fainted.connect(_on_enemy_fainted)

	# Scale enemy level: use levels.json enemy_level, or match player avg
	var enemy_lvl: int = int(level_data.get("enemy_level", 0))
	if enemy_lvl <= 0:
		enemy_lvl = _calc_enemy_level()
	_apply_enemy_level(enemy_monster, enemy_id, enemy_lvl)

	# Use chosen starter; fall back to first team member
	var start_id := starter_id if starter_id != "" else SaveData.get_first_team_monster()
	var _team_start := SaveData.get_team()
	var _start_slot := _team_start.find(start_id)
	player_monster.instance_idx = SaveData.get_team_instance_idx(_start_slot if _start_slot >= 0 else 0)
	player_monster.set_monster_id(start_id)
	player_monster.clear_status_conditions()
	_state.participated_monsters.append(player_monster.monster_id)
	_state.init_pp(player_monster.monster_id)
	player_monster.set_active(true)
	enemy_monster.set_active(false)

	refresh_move_buttons()
	refresh_portrait()
	refresh_team_slots()
	refresh_action_buttons()
	# Send-out animation + "Go! X!" text
	BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -120),
		"Go!  %s!" % player_monster.display_name, Color(0.24, 0.85, 0.82))
	await BattleAnimations.play_sendout_animation(self, $Battlefield/PlayerSide)

	var level_name: String = GameData.get_level(GameState.selected_level_id).get("name", "Unknown")
	add_log("Your team enters %s!" % level_name, "system")
	add_log("A wild %s appeared!" % enemy_monster.display_name, "system")

	var turn_order := BattleManager.determine_turn_order(player_monster, enemy_monster)
	if turn_order[0] == enemy_monster:
		add_log("%s moves first!" % enemy_monster.display_name, "enemy")
		set_player_turn(false)
		await get_tree().create_timer(0.8).timeout
		await enemy_turn()
	else:
		set_player_turn(true)




# ══════════════════════════════════════════════════════════════════════════════
# UI REFRESH
# ══════════════════════════════════════════════════════════════════════════════

func refresh_move_buttons():
	var moves: Array  = player_monster.moves
	var pp: Dictionary = _state.monster_moves_pp.get(player_monster.monster_id, {})
	var m_data         := GameData.get_monster(player_monster.monster_id)
	var mon_elem: String = m_data.get("element", "")

	for i in 4:
		var btn := move_buttons[i]
		if i >= moves.size():
			btn.visible = false
			continue
		btn.visible = true
		var move_id: String    = moves[i]
		var md                 := GameData.get_move(move_id)
		var m_name: String     = md.get("name", move_id)
		var kind: String       = md.get("kind", "damage")
		var elem: String       = md.get("element", mon_elem)
		var signature: String  = GameData.get_monster(player_monster.monster_id).get("signature_move", "")
		var is_sig: bool       = (move_id == signature)
		var max_pp: int        = 6 if is_sig else (5 if kind in ["buff", "debuff"] else 10)
		var cur_pp: int        = pp.get(move_id, max_pp)
		var col: Color         = GameData.ELEMENT_COLORS.get(elem, Color(0.5, 0.7, 0.8))
		btn.disabled = cur_pp <= 0
		BattleUI.style_move_button(btn, m_name, KIND_ICONS.get(kind, "⚔"), elem, col, cur_pp, max_pp)




func refresh_portrait():
	var m_data := GameData.get_monster(player_monster.monster_id)
	var sp: String = m_data.get("sprite", "")
	if sp != "" and FileAccess.file_exists(sp):
		active_portrait.texture = load(sp)
	active_name_label.text = m_data.get("name", player_monster.monster_id)
	var pct: float = clamp(float(player_monster.current_hp) / float(player_monster.max_hp), 0.0, 1.0)
	active_hp_fill.size.x  = 160.0 * pct
	active_hp_fill.color   = Color(0.20, 0.80, 0.35) if pct > 0.5 \
		else (Color(0.90, 0.70, 0.10) if pct > 0.25 else Color(0.85, 0.20, 0.20))
	active_hp_label.text   = "%d / %d" % [player_monster.current_hp, player_monster.max_hp]


## Saves every team member's current HP and remaining PP to SaveData
## so they persist into the next battle.
func _persist_battle_state():
	var team: Array = SaveData.get_team()
	for slot_idx in team.size():
		var mid: String = str(team[slot_idx])
		var idx: int    = SaveData.get_team_instance_idx(slot_idx)
		var hp: int = player_monster.current_hp if mid == player_monster.monster_id \
			else _state.team_hp.get(mid, -1)
		if hp >= 0:
			SaveData._ensure_instances(mid)
			var arr: Array = SaveData.data["monster_instances"][mid]
			if idx < arr.size():
				arr[idx]["current_hp"] = hp
		var pp: Dictionary = _state.monster_moves_pp.get(mid, {})
		if not pp.is_empty():
			SaveData._ensure_instances(mid)
			var arr2: Array = SaveData.data["monster_instances"][mid]
			if idx < arr2.size():
				arr2[idx]["pp"] = pp
	SaveData.save()


func _try_swap_to_slot(_slot_idx: int):
	# Slot click now just opens the swap popup
	_on_portrait_clicked()


func _execute_player_swap(target_id: String):
	set_moves_enabled(false)
	set_player_turn(false)
	# Save current monster's HP before swapping out
	_state.save_hp(player_monster.monster_id, player_monster.current_hp)
	add_log("%s, switch out!" % player_monster.display_name, "player")
	# Swap animation — slide out
	var out_tw := create_tween()
	out_tw.tween_property(player_monster, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD)
	await out_tw.finished
	# Switch monster
	if target_id not in _state.participated_monsters:
		_state.participated_monsters.append(target_id)
	player_monster.set_monster_id(target_id)
	player_monster.clear_status_conditions()
	player_monster.modulate.a = 0.0
	if _state.team_hp.has(target_id):
		player_monster.current_hp = _state.team_hp[target_id]
		player_monster.update_hp_display()
	_state.init_pp(target_id)
	refresh_move_buttons()
	refresh_portrait()
	refresh_team_slots()
	player_monster.set_active(true)
	enemy_monster.set_active(false)
	BattleAnimations.show_float_text(self,
		player_monster.global_position + Vector2(0, -100),
		"Go!  %s!" % player_monster.display_name, Color(0.24, 0.85, 0.82))
	await BattleAnimations.play_sendout_animation(self, $Battlefield/PlayerSide)
	add_log("%s, go!" % player_monster.display_name, "player")
	# Swap uses the player's turn — enemy now attacks
	await get_tree().create_timer(0.3).timeout
	if not _state.battle_over:
		await enemy_turn()


func refresh_team_slots():
	var team := SaveData.get_team()
	var active_id: String = player_monster.monster_id if player_monster else ""

	for i in 3:
		team_slot_icons[i].texture = null
		var sb := team_slot_icons[i].get_parent() as Control

		# Remove old indicator nodes
		var old_arrow := sb.get_node_or_null("ActiveArrow")
		var old_ring  := sb.get_node_or_null("ActiveRing")
		if old_arrow: old_arrow.queue_free()
		if old_ring:  old_ring.queue_free()

		if i >= team.size():
			var empty_bg := sb.get_node_or_null("SlotBg") as TextureRect
			if empty_bg: empty_bg.modulate = Color(0.55, 0.55, 0.60)
			continue

		var mid: String = str(team[i])
		var md := GameData.get_monster(mid)
		var sp: String = md.get("sprite", "")
		if sp != "" and FileAccess.file_exists(sp):
			team_slot_icons[i].texture = load(sp)

		var hp: int = _state.team_hp.get(mid, -1)
		var is_fainted: bool = hp == 0
		var is_active: bool  = (mid == active_id)

		# Slot background tint via SlotBg modulate
		var slot_bg_node := sb.get_node_or_null("SlotBg") as TextureRect
		if slot_bg_node:
			if is_active:
				slot_bg_node.modulate = Color(0.40, 1.00, 0.85)
			elif is_fainted:
				slot_bg_node.modulate = Color(1.00, 0.45, 0.45)
			else:
				slot_bg_node.modulate = Color.WHITE

		# Fainted: show 💤 + sleep countdown on the slot
		var old_sleep_lbl := sb.get_node_or_null("SleepLbl")
		if old_sleep_lbl: old_sleep_lbl.queue_free()
		if is_fainted:
			var sleep_lbl := Label.new()
			sleep_lbl.name = "SleepLbl"
			sleep_lbl.text = "💤"
			sleep_lbl.size = Vector2(54, 26)
			sleep_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sleep_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			sleep_lbl.add_theme_font_size_override("font_size", 13)
			sleep_lbl.z_index = 5
			sleep_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sb.add_child(sleep_lbl)

		# Monster icon dim if fainted
		team_slot_icons[i].modulate = Color(0.28, 0.28, 0.28) if is_fainted else Color.WHITE
		# Pointer cursor on sb itself when swappable
		var can_swap: bool = not is_active and not is_fainted and i < SaveData.get_team().size()
		sb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_swap \
			else Control.CURSOR_ARROW

		if is_active:
			# Teal glow border ring around the active slot
			var ring := ColorRect.new()
			ring.name     = "ActiveRing"
			ring.size     = Vector2(sb.size.x + 4, sb.size.y + 4)
			ring.position = Vector2(-2, -2)
			ring.color    = Color(0.24, 0.85, 0.82, 0.80)
			ring.z_index  = -1
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sb.add_child(ring)

			# Small triangle arrow pointing UP below the slot
			var arrow := Label.new()
			arrow.name = "ActiveArrow"
			arrow.text = "▲"
			arrow.size = Vector2(sb.size.x, 14)
			arrow.position = Vector2(0, sb.size.y + 2)
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.add_theme_font_size_override("font_size", 11)
			arrow.add_theme_color_override("font_color", Color(0.24, 0.85, 0.82, 1.0))
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sb.add_child(arrow)


func refresh_action_buttons():
	pass  # circle is a pure visual turn indicator; no capture logic here


func refresh_signature_button():
	pass # signature button removed


func set_player_turn(is_turn: bool):
	_state.is_player_turn = is_turn
	# Swap circle texture colour — blue=player, red=enemy
	var circle_bg := action_capture_btn.get_node_or_null("CircleBg") as TextureRect
	if circle_bg:
		var col_path := "res://assets/ui/buttons/btn_round_%s.png" % ("blue" if is_turn else "red")
		var t := BattleUI._load_tex(col_path)
		if t: circle_bg.texture = t
	if is_turn:
		turn_label.text = "YOUR\nTURN"
		turn_label.add_theme_color_override("font_color", Color.WHITE)
		action_capture_btn.disabled = true
		_pulse_turn_indicator()
	else:
		turn_label.text = "ENEMY\nTURN"
		turn_label.add_theme_color_override("font_color", Color.WHITE)
		action_capture_btn.disabled = true
	set_moves_enabled(is_turn)


func _pulse_turn_indicator():
	var tw := create_tween().set_loops(2)
	tw.tween_property(action_capture_btn, "modulate", Color(1.18, 1.18, 1.18, 1.0), 0.28)
	tw.tween_property(action_capture_btn, "modulate", Color.WHITE, 0.28)


func set_moves_enabled(enabled: bool):
	for btn in move_buttons:
		if enabled:
			var moves: Array = player_monster.moves
			var idx := move_buttons.find(btn)
			if idx < moves.size():
				var pp: Dictionary = _state.monster_moves_pp.get(player_monster.monster_id, {})
				btn.disabled = pp.get(moves[idx], 1) <= 0
		else:
			btn.disabled = true
	action_item_btn.disabled    = not enabled
	action_capture_btn.disabled = not enabled or SaveData.get_inventory_item("star_seed") <= 0
	action_run_btn.disabled     = not enabled
	# signature button removed — no-op here


# ══════════════════════════════════════════════════════════════════════════════
# PLAYER MOVE
# ══════════════════════════════════════════════════════════════════════════════

func _on_move_button_pressed(index: int):
	if _state.battle_over or not _state.is_player_turn:
		return
	var moves: Array = player_monster.moves
	if index >= moves.size():
		return
	await use_player_move(moves[index])


func use_player_move(move_id: String):
	if _state.battle_over:
		return
	var pp: Dictionary = _state.monster_moves_pp.get(player_monster.monster_id, {})
	if pp.get(move_id, 0) <= 0:
		add_log("No PP left for %s!" % GameData.get_move(move_id).get("name", move_id), "system")
		BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "No PP!", Color(0.9, 0.5, 0.2))
		return

	set_moves_enabled(false)
	set_player_turn(false)

	var md         := GameData.get_move(move_id)
	var move_kind: String = md.get("kind", "")

	player_monster.set_active(true)
	enemy_monster.set_active(false)

	# Status DoT at start of player turn
	var poison_dmg: int = await _process_status_dot(player_monster)
	if poison_dmg > 0:
		add_log("%s is hurt by poison! (%d dmg)" % [player_monster.display_name, poison_dmg], "bad")
		if player_monster.current_hp <= 0: await _handle_player_fainted(); return
	var burn_dmg: int = player_monster.tick_burn()
	if burn_dmg > 0:
		add_log("%s is hurt by burn! (%d dmg)" % [player_monster.display_name, burn_dmg], "bad")
		if player_monster.current_hp <= 0: await _handle_player_fainted(); return

	# Paralysis check BEFORE spending PP — skip turn without wasting PP
	if player_monster.tick_paralysis():
		add_log("%s is paralyzed and can't move!" % player_monster.display_name, "bad")
		BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "PARALYZED!", Color(1.0, 0.88, 0.15))
		player_monster.process_turns()
		refresh_move_buttons(); refresh_portrait(); refresh_action_buttons()
		await get_tree().create_timer(1.0).timeout
		if not _state.battle_over: await enemy_turn()
		return

	# Deduct PP after all skip checks pass
	pp[move_id] -= 1
	_state.monster_moves_pp[player_monster.monster_id] = pp
	refresh_move_buttons()  # Update PP display immediately

	await _play_status_tick(player_monster)

	var move_name: String = md.get("name", move_id)
	add_log("%s used %s!" % [player_monster.display_name, move_name], "player")

	if move_kind == "damage":
		var result = CombatCalculator.calculate_damage(player_monster, enemy_monster, md)
		var is_ranged: bool    = md.get("ranged", false)
		var is_sig: bool       = md.get("signature", false)
		var elem: String       = md.get("element", "none")
		if result.get("missed", false):
			if is_sig:
				await _play_signature_anim(player_monster, enemy_monster, elem)
			elif is_ranged:
				await _play_projectile_anim(player_monster, enemy_monster, elem)
			else:
				await _play_attack_anim(player_monster, enemy_monster)
			add_log("%s's attack missed!" % player_monster.display_name, "system")
			BattleAnimations.show_miss_text(self)
		else:
			if is_sig:
				await _play_signature_anim(player_monster, enemy_monster, elem)
			elif is_ranged:
				await _play_projectile_anim(player_monster, enemy_monster, elem)
			else:
				await _play_attack_anim(player_monster, enemy_monster)
			if result.is_crit:
				BattleAnimations.shake_screen(self)
			await enemy_monster.take_damage(result.damage, result.is_crit, result.element, result.multiplier)
			if result.is_crit:
				add_log("Critical hit! %s took %d damage!" % [enemy_monster.display_name, result.damage], "good")
				BattleAnimations.show_float_text(self, enemy_monster.global_position + Vector2(60, -120), "Critical!", Color(1.0, 0.55, 0.10))
			elif result.multiplier > 1.0:
				add_log("2x effective! %s took %d damage!" % [enemy_monster.display_name, result.damage], "good")
				BattleAnimations.show_float_text(self, enemy_monster.global_position + Vector2(0, -80), "2x More Effective!", Color(1.0, 0.90, 0.10))
			elif result.multiplier < 1.0 and result.multiplier > 0.0:
				add_log("Resisted. %s took %d damage." % [enemy_monster.display_name, result.damage], "system")
				BattleAnimations.show_float_text(self, enemy_monster.global_position + Vector2(0, -80), "Resisted!", Color(0.60, 0.60, 0.75))
			else:
				add_log("%s took %d damage." % [enemy_monster.display_name, result.damage], "system")
	elif move_kind == "buff":
		var stat: String  = md.get("stat", "attack")
		var amount: int   = int(md.get("amount", 0))
		if stat == "hp":
			await _play_heal_anim(player_monster)
			await player_monster.heal(amount)
			add_log("%s restored %d HP!" % [player_monster.display_name, amount], "good")
		else:
			await _play_buff_anim(player_monster, stat)
			if stat == "attack":    player_monster.add_attack_buff(amount)
			elif stat == "defense": player_monster.add_defense_buff(amount)
			elif stat == "speed":   player_monster.add_speed_buff(amount)
			add_log("%s's %s rose!" % [player_monster.display_name, stat], "good")
	elif move_kind == "debuff":
		var stat: String  = md.get("stat", "attack")
		var amount: int   = int(md.get("amount", 0))
		await _play_debuff_anim(player_monster, enemy_monster, stat)
		if stat == "attack":    enemy_monster.add_attack_debuff(amount)
		elif stat == "defense": enemy_monster.add_defense_debuff(amount)
		elif stat == "speed":   enemy_monster.add_speed_debuff(amount)
		add_log("%s's %s fell!" % [enemy_monster.display_name, stat], "good")
	elif move_kind == "heal":
		var heal_amt: int = int(md.get("power", md.get("amount", 0)))
		await _play_heal_anim(player_monster)
		await player_monster.heal(heal_amt)
		refresh_portrait()
		add_log("%s recovered %d HP!" % [player_monster.display_name, heal_amt], "good")

	# Apply status condition from the move (poison / paralysis)
	_try_apply_status(md, enemy_monster)

	player_monster.process_turns()
	refresh_move_buttons()
	refresh_portrait()
	refresh_action_buttons()

	await get_tree().create_timer(0.55).timeout
	if not _state.battle_over and enemy_monster.current_hp > 0:
		await enemy_turn()
	elif not _state.battle_over:
		set_player_turn(true)


# ══════════════════════════════════════════════════════════════════════════════
# ITEMS
# ══════════════════════════════════════════════════════════════════════════════

func _on_use_item_pressed():
	if _state.battle_over or not _state.is_player_turn:
		return
	# Refresh counts from GameData — no hardcoded ID list
	var panel := item_overlay.get_child(0)
	for it in GameData.get_battle_items():
		var lbl := panel.get_node_or_null("Cnt_%s" % it["id"])
		if lbl:
			lbl.text = "x%d" % SaveData.get_inventory_item(it["id"])
	item_overlay.visible = true


func _on_use_item_selected(item_id: String):
	item_overlay.visible = false
	if _state.battle_over or not _state.is_player_turn:
		return
	if SaveData.get_inventory_item(item_id) <= 0:
		return
	SaveData.use_inventory_item(item_id)
	set_moves_enabled(false)
	set_player_turn(false)

	# Data-driven effect dispatch — to add a new usable item: edit items.json only
	var item_data: Dictionary = GameData.get_item(item_id)
	var effect:   String     = item_data.get("use_effect", "")
	var use_val:  int        = int(item_data.get("use_value", 0))

	match effect:
		"capture":
			await throw_star_seed()
			return
		"heal":
			await player_monster.heal(use_val)
			refresh_portrait()
			add_log("%s restored %d HP!" % [player_monster.display_name, use_val], "good")
		"revive":
			await player_monster.heal(player_monster.max_hp / 2)
			refresh_portrait()
			add_log("%s was revived!" % player_monster.display_name, "good")
		"exp_boost":
			_state.exp_boost_active = true
			add_log("Exp Booster activated! XP x2!", "good")
			BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "XP x2!", Color(0.24, 0.85, 0.82))
			await get_tree().create_timer(0.6).timeout
		"pp_restore":
			# Restore all PP for the active monster to max
			var md: Dictionary    = GameData.get_monster(player_monster.monster_id)
			var sig: String       = md.get("signature_move", "")
			var pp_dict: Dictionary = _state.monster_moves_pp.get(player_monster.monster_id, {})
			for move_id in pp_dict.keys():
				var kind: String = GameData.get_move(move_id).get("kind", "")
				if move_id == sig:           pp_dict[move_id] = 6
				elif kind in ["buff","debuff"]: pp_dict[move_id] = 5
				else:                        pp_dict[move_id] = 10
			_state.monster_moves_pp[player_monster.monster_id] = pp_dict
			SaveData.set_instance_pp(player_monster.monster_id, player_monster.instance_idx, pp_dict)
			refresh_move_buttons()
			add_log("All PP restored for %s!" % player_monster.display_name, "good")
			BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "PP Restored!", Color(0.24, 0.85, 0.82))
			await get_tree().create_timer(0.6).timeout
		_:
			push_warning("BattleItems: unknown use_effect '%s' for item '%s'" % [effect, item_id])

	await get_tree().create_timer(0.3).timeout
	if not _state.battle_over:
		await enemy_turn()




func _on_run_pressed():
	if _state.battle_over or not _state.is_player_turn:
		return
	_state.battle_over = true
	set_moves_enabled(false)
	BattleAnimations.show_float_text(self, Vector2(960, 380), "Got away safely!", Color(0.80, 0.80, 0.85))
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")


# ══════════════════════════════════════════════════════════════════════════════
# ENEMY TURN
# ══════════════════════════════════════════════════════════════════════════════

func enemy_turn():
	if _state.battle_over:
		return
	player_monster.set_active(false)
	enemy_monster.set_active(true)
	set_player_turn(false)

	await get_tree().create_timer(0.75).timeout

	# Status DoT at start of enemy turn
	var e_poison_dmg: int = await _process_status_dot(enemy_monster)
	if e_poison_dmg > 0:
		add_log("%s is hurt by poison! (%d dmg)" % [enemy_monster.display_name, e_poison_dmg], "good")
		if enemy_monster.current_hp <= 0: await _on_enemy_fainted(); return
	var e_burn_dmg: int = enemy_monster.tick_burn()
	if e_burn_dmg > 0:
		add_log("%s is hurt by burn! (%d dmg)" % [enemy_monster.display_name, e_burn_dmg], "good")
		if enemy_monster.current_hp <= 0: await _on_enemy_fainted(); return

	# Paralysis check
	if enemy_monster.tick_paralysis():
		add_log("%s is paralyzed and can't move!" % enemy_monster.display_name, "good")
		BattleAnimations.show_float_text(self, enemy_monster.global_position + Vector2(0, -80), "PARALYZED!", Color(1.0, 0.88, 0.15))
		enemy_monster.process_turns()
		refresh_portrait(); refresh_action_buttons()
		await get_tree().create_timer(1.0).timeout
		if not _state.battle_over:
			player_monster.set_active(true); enemy_monster.set_active(false)
			set_player_turn(true)
		return

	await _play_status_tick(enemy_monster)

	var move_id := BattleManager.select_enemy_move(enemy_monster, player_monster)
	var md      := GameData.get_move(move_id)
	var kind: String    = md.get("kind", "")
	var e_move_name: String = md.get("name", move_id)

	add_log("%s used %s!" % [enemy_monster.display_name, e_move_name], "enemy")

	if kind == "damage":
		var result = CombatCalculator.calculate_damage(enemy_monster, player_monster, md)
		var is_ranged: bool = md.get("ranged", false)
		var is_sig: bool    = md.get("signature", false)
		var elem: String    = md.get("element", "none")
		if result.get("missed", false):
			if is_sig:
				await _play_signature_anim(enemy_monster, player_monster, elem)
			elif is_ranged:
				await _play_projectile_anim(enemy_monster, player_monster, elem)
			else:
				await _play_attack_anim(enemy_monster, player_monster)
			add_log("%s's attack missed!" % enemy_monster.display_name, "system")
			BattleAnimations.show_miss_text(self)
		else:
			if is_sig:
				await _play_signature_anim(enemy_monster, player_monster, elem)
			elif is_ranged:
				await _play_projectile_anim(enemy_monster, player_monster, elem)
			else:
				await _play_attack_anim(enemy_monster, player_monster)
			if result.is_crit:
				BattleAnimations.shake_screen(self)
			await player_monster.take_damage(result.damage, result.is_crit, result.element, result.multiplier)
			if result.is_crit:
				add_log("Critical hit! %s took %d damage!" % [player_monster.display_name, result.damage], "bad")
				BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(60, -120), "Critical!", Color(1.0, 0.55, 0.10))
			elif result.multiplier > 1.0:
				add_log("2x effective! %s took %d damage!" % [player_monster.display_name, result.damage], "bad")
				BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "2x More Effective!", Color(1.0, 0.50, 0.20))
			elif result.multiplier < 1.0 and result.multiplier > 0.0:
				add_log("Resisted. %s took %d damage." % [player_monster.display_name, result.damage], "system")
				BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -80), "Resisted!", Color(0.60, 0.60, 0.75))
			else:
				add_log("%s took %d damage." % [player_monster.display_name, result.damage], "system")
	elif kind == "buff":
		var stat: String = md.get("stat", "attack")
		var amt: int     = int(md.get("amount", 0))
		if stat == "hp":
			await _play_heal_anim(enemy_monster)
			await enemy_monster.heal(amt)
			add_log("%s restored %d HP!" % [enemy_monster.display_name, amt], "bad")
		else:
			await _play_buff_anim(enemy_monster, stat)
			if stat == "attack":    enemy_monster.add_attack_buff(amt)
			elif stat == "defense": enemy_monster.add_defense_buff(amt)
			elif stat == "speed":   enemy_monster.add_speed_buff(amt)
			add_log("%s's %s rose!" % [enemy_monster.display_name, stat], "bad")
	elif kind == "debuff":
		var stat: String = md.get("stat", "attack")
		var amt: int     = int(md.get("amount", 0))
		await _play_debuff_anim(enemy_monster, player_monster, stat)
		if stat == "attack":    player_monster.add_attack_debuff(amt)
		elif stat == "defense": player_monster.add_defense_debuff(amt)
		elif stat == "speed":   player_monster.add_speed_debuff(amt)
		add_log("%s's %s fell!" % [player_monster.display_name, stat], "bad")
	elif kind == "heal":
		var heal_amt: int = int(md.get("power", md.get("amount", 0)))
		await _play_heal_anim(enemy_monster)
		await enemy_monster.heal(heal_amt)
		add_log("%s recovered %d HP!" % [enemy_monster.display_name, heal_amt], "bad")

	# Apply status condition from enemy move
	_try_apply_status(md, player_monster)

	enemy_monster.process_turns()
	refresh_portrait()
	refresh_action_buttons()

	if player_monster.current_hp <= 0:
		await _handle_player_fainted()
	else:
		player_monster.set_active(true)
		enemy_monster.set_active(false)
		set_player_turn(true)


func _handle_player_fainted():
	add_log("%s fainted!" % player_monster.display_name, "bad")
	_state.team_hp[player_monster.monster_id] = 0
	# Mark fainted in save — starts 30-second sleep recovery on home screen
	SaveData.set_instance_fainted(player_monster.monster_id, player_monster.instance_idx, true)
	await get_tree().create_timer(0.5).timeout
	var next := _get_next_alive_monster()
	if next == "":
		_state.battle_over = true
		set_moves_enabled(false)
		_persist_battle_state()
		BattleAnimations.show_float_text(self, Vector2(960, 380), "All monsters fainted!", Color(0.85, 0.20, 0.20))
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/map/WorldMap.tscn")
		return

	if next not in _state.participated_monsters:
		_state.participated_monsters.append(next)
	var _swap_team := SaveData.get_team()
	var _swap_slot := _swap_team.find(next)
	player_monster.instance_idx = SaveData.get_team_instance_idx(_swap_slot if _swap_slot >= 0 else 0)
	player_monster.set_monster_id(next)
	player_monster.clear_status_conditions()
	if _state.team_hp.has(next):
		player_monster.current_hp = _state.team_hp[next]
		player_monster.update_hp_display()

	var team := SaveData.get_team()
	var idx   := team.find(next)
	if idx > 0:
		var tmp = team[0]; team[0] = next; team[idx] = tmp
		SaveData.data["team"] = team

	_state.init_pp(next)
	refresh_move_buttons()
	refresh_portrait()
	refresh_team_slots()
	player_monster.set_active(true)
	enemy_monster.set_active(false)

	# Send-out animation
	BattleAnimations.show_float_text(self, player_monster.global_position + Vector2(0, -120),
		"Go!  %s!" % player_monster.display_name, Color(0.24, 0.85, 0.82))
	await BattleAnimations.play_sendout_animation(self, $Battlefield/PlayerSide)

	set_player_turn(true)


# ══════════════════════════════════════════════════════════════════════════════
# ENEMY FAINTED / VICTORY
# ══════════════════════════════════════════════════════════════════════════════

func _on_enemy_fainted():
	if _state.battle_over:
		return
	_state.battle_over = true
	set_moves_enabled(false)
	add_log("%s fainted! You win!" % enemy_monster.display_name, "good")
	await get_tree().create_timer(0.6).timeout
	_persist_battle_state()
	await _show_victory_screen()


func _show_victory_screen():
	var xp_base: int     = int(GameData.battle_cfg("xp_base", 30))
	var xp_per_lvl: int  = int(GameData.battle_cfg("xp_per_enemy_level", 8))
	var raw_xp: int      = xp_base + enemy_monster.level * xp_per_lvl
	var boost_mult: float = float(GameData.battle_cfg("exp_boost_multiplier", 2.0)) if _state.exp_boost_active else 1.0
	var total_xp: int    = int(raw_xp * boost_mult)
	var count: int       = _state.participated_monsters.size()
	var xp_per: int      = int(total_xp / maxi(count, 1))


	await get_tree().create_timer(0.8).timeout

	var overlay := ColorRect.new()
	overlay.size    = Vector2(1920, 1080)
	overlay.color   = Color(0.02, 0.04, 0.07, 0.0)
	overlay.z_index = 50
	ui_layer.add_child(overlay)

	var fade := create_tween()
	fade.tween_property(overlay, "color", Color(0.02, 0.04, 0.07, 0.88), 0.5)
	await fade.finished

	var title := Label.new()
	title.text                 = "VICTORY"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size                 = Vector2(1920, 70)
	title.position             = Vector2(0, 40)
	title.modulate.a           = 0
	overlay.add_child(title)
	create_tween().tween_property(title, "modulate:a", 1.0, 0.4)

	var card_w    := 320
	var gap       := 40
	var total_w   := count * card_w + (count - 1) * gap
	var start_x   := (1920 - total_w) / 2

	var xp_fills: Array = []
	var cnt_lbls: Array = []
	var lvl_lbls: Array = []
	var m_ids:    Array = []
	var cur_xps:  Array = []
	var cur_lvls: Array = []
	var xp_needs: Array = []
	var inst_idxs: Array = []

	# Map each participated species → its correct instance index from the team
	var _team := SaveData.get_team()
	var _species_seen: Dictionary = {}
	var _mid_to_idx: Dictionary = {}
	for _slot in _team.size():
		var _sp := str(_team[_slot])
		var _seen_count: int = _species_seen.get(_sp, 0)
		_mid_to_idx[_sp + "_" + str(_seen_count)] = _seen_count
		_species_seen[_sp] = _seen_count + 1
	var _part_seen: Dictionary = {}
	for _mid_raw in _state.participated_monsters:
		var _sp2 := str(_mid_raw)
		var _oc: int = _part_seen.get(_sp2, 0)
		_part_seen[_sp2] = _oc + 1

	var _p_seen2: Dictionary = {}
	for i in count:
		var mid: String = _state.participated_monsters[i]
		var _oc2: int = _p_seen2.get(mid, 0)
		_p_seen2[mid] = _oc2 + 1
		var inst_idx: int = SaveData.get_team_instance_idx(_team.find(mid))
		inst_idxs.append(inst_idx)
		var md          := GameData.get_monster(mid)
		var cur_xp      := SaveData.get_instance_xp(mid, inst_idx)
		var cur_lvl     := SaveData.get_instance_level(mid, inst_idx)
		var xp_need     := SaveData.xp_needed_for_level(cur_lvl)
		var cx          := start_x + i * (card_w + gap)
		m_ids.append(mid); cur_xps.append(cur_xp)
		cur_lvls.append(cur_lvl); xp_needs.append(xp_need)

		var card := ColorRect.new()
		card.size      = Vector2(card_w, 420)
		card.position  = Vector2(cx, 130)
		card.color     = Color(0.04, 0.08, 0.12, 0.70)
		card.modulate.a = 0
		overlay.add_child(card)
		create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.15 * i)

		var port_bg := ColorRect.new()
		port_bg.size     = Vector2(160, 160)
		port_bg.position = Vector2((card_w - 160) / 2, 20)
		port_bg.color    = Color(0.06, 0.12, 0.18)
		card.add_child(port_bg)

		var portrait := TextureRect.new()
		portrait.size = Vector2(140, 140); portrait.position = Vector2(10, 10)
		portrait.expand_mode = 1; portrait.stretch_mode = 5
		var sp: String = md.get("sprite", "")
		if sp != "": portrait.texture = load(sp)
		port_bg.add_child(portrait)

		BattleUI.center_label(card, md.get("name", mid), 22, Color.WHITE, Vector2(0, 192), Vector2(card_w, 30))

		var lvl_lbl := BattleUI.center_label(card, "Lv. %d" % cur_lvl, 17, Color(0.6, 0.8, 0.9, 0.8), Vector2(0, 226), Vector2(card_w, 24))
		lvl_lbls.append(lvl_lbl)

		BattleUI.center_label(card, "+%d XP" % xp_per, 22, Color(0.24, 0.85, 0.82), Vector2(0, 258), Vector2(card_w, 28))

		var bar_bg := ColorRect.new()
		bar_bg.size     = Vector2(card_w - 40, 22)
		bar_bg.position = Vector2(20, 298)
		bar_bg.color    = Color(0.06, 0.10, 0.15)
		card.add_child(bar_bg)

		var bw   := card_w - 40
		var fill := ColorRect.new()
		fill.size  = Vector2(bw * float(cur_xp) / xp_need, 22)
		fill.color = Color(0.24, 0.85, 0.82)
		bar_bg.add_child(fill)
		xp_fills.append({"fill": fill, "bw": bw})

		var cnt := Label.new()
		cnt.text                 = "%d / %d" % [cur_xp, xp_need]
		cnt.size                 = Vector2(bw, 22)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 13)
		cnt.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.85))
		bar_bg.add_child(cnt)
		cnt_lbls.append(cnt)

	await get_tree().create_timer(0.8 + 0.15 * count).timeout

	for i in count:
		var mid2: String = m_ids[i]
		var iidx: int    = inst_idxs[i]
		var cx2: int     = cur_xps[i]
		var cl: int      = cur_lvls[i]
		var xn: int      = xp_needs[i]
		var tx           := cx2 + xp_per
		var fill2: ColorRect = xp_fills[i]["fill"]
		var bw2: int     = xp_fills[i]["bw"]
		var cnt2: Label  = cnt_lbls[i]
		var lvl2: Label  = lvl_lbls[i]

		if cl >= SaveData.MAX_LEVEL:
			# Already max level — show full bar, no XP gain
			lvl2.text = "MAX LEVEL  Lv. %d" % cl
			lvl2.add_theme_color_override("font_color", Color(1.0, 0.80, 0.15))
			fill2.size.x = float(bw2)
			cnt2.text = "MAX"
		elif tx >= xn:
			var mn: String = GameData.get_monster(mid2).get("name", mid2)
			# Loop: handle multiple level-ups from a single battle (e.g. gaining 2+ levels)
			while tx >= xn and cl < SaveData.MAX_LEVEL:
				var t1 := create_tween()
				t1.tween_property(fill2, "size:x", float(bw2), 0.6).set_trans(Tween.TRANS_QUAD)
				await t1.finished
				cl += 1; tx -= xn; xn = SaveData.xp_needed_for_level(cl)
				lvl2.text = "LEVEL UP!  Lv. %d" % cl
				lvl2.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
				SaveData.set_instance_level(mid2, iidx, cl)
				var move_result: Dictionary = SaveData.apply_new_moves_on_levelup(mid2, cl, iidx)
				for mv_id: String in move_result.get("equipped", []):
					var mv_name: String = GameData.get_move(mv_id).get("name", mv_id)
					var notify := Label.new()
					notify.text = "%s equipped %s!" % [mn, mv_name]
					notify.add_theme_font_size_override("font_size", 20)
					notify.add_theme_color_override("font_color", Color(0.24, 0.92, 0.72))
					notify.position = Vector2(lvl2.position.x, lvl2.position.y + 32)
					notify.size     = Vector2(500, 28)
					lvl2.get_parent().add_child(notify)
					var tw := create_tween()
					tw.tween_property(notify, "modulate:a", 0.0, 1.2).set_delay(1.5)
					tw.tween_callback(notify.queue_free)
				for mv_id: String in move_result.get("learned", []):
					var mv_name: String = GameData.get_move(mv_id).get("name", mv_id)
					var notify2 := Label.new()
					notify2.text = "%s learned %s! (Go to Mogadex to equip)" % [mn, mv_name]
					notify2.add_theme_font_size_override("font_size", 15)
					notify2.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
					notify2.position = Vector2(lvl2.position.x, lvl2.position.y + 60)
					notify2.size     = Vector2(600, 24)
					lvl2.get_parent().add_child(notify2)
					var tw2 := create_tween()
					tw2.tween_property(notify2, "modulate:a", 0.0, 1.2).set_delay(2.0)
					tw2.tween_callback(notify2.queue_free)
				await get_tree().create_timer(0.6).timeout
				fill2.size.x = 0
				if tx < xn or cl >= SaveData.MAX_LEVEL:
					var t2 := create_tween()
					t2.tween_property(fill2, "size:x", bw2 * float(tx) / float(maxi(xn, 1)), 0.4).set_trans(Tween.TRANS_QUAD)
					cnt2.text = "%d / %d" % [tx, xn]
					await t2.finished
			SaveData.set_instance_xp(mid2, iidx, tx)
		else:
			var t := create_tween()
			t.tween_property(fill2, "size:x", bw2 * float(tx) / xn, 0.6).set_trans(Tween.TRANS_QUAD)
			cnt2.text = "%d / %d" % [tx, xn]
			await t.finished
			SaveData.set_instance_xp(mid2, iidx, tx)

	var level_id  := GameState.selected_level_id
	var is_first: bool = not SaveData.is_level_completed(level_id)

	if is_first:
		var ld     := GameData.get_level(level_id)
		var drops: Dictionary = ld.get("reward_drops", {})
		var gold: int         = int(ld.get("reward_gold", 0))

		var sep := ColorRect.new()
		sep.size = Vector2(600, 2); sep.position = Vector2(660, 590)
		sep.color = Color(0.24, 0.85, 0.82, 0.4)
		overlay.add_child(sep)

		BattleUI.center_label(overlay, "First Clear Rewards!", 28, Color(1.0, 0.85, 0.3), Vector2(0, 606), Vector2(1920, 36))

		var reward_items: Array = []
		if gold > 0:
			reward_items.append({
				"icon": "res://assets/ui/coin.png",
				"text": "%d Gold" % gold
			})
			SaveData.data["gold"] = SaveData.data.get("gold", 0) + gold
		for iid in drops:
			var qty: int = int(drops[iid])
			if qty > 0:
				var item_data: Dictionary = GameData.get_item(iid)
				var icon_path: String = item_data.get("icon", "")
				var label: String = "%s  x%d" % [item_data.get("name", iid), qty]
				reward_items.append({"icon": icon_path, "text": label})
				SaveData.add_inventory_item(iid, qty)

		var iw := 160; var ig := 24
		var itw: int = reward_items.size() * iw + (reward_items.size() - 1) * ig
		var isx: int = (1920 - itw) / 2
		for j in reward_items.size():
			var rd: Dictionary = reward_items[j]
			var ic := ColorRect.new()
			ic.size       = Vector2(iw, 110)
			ic.position   = Vector2(isx + j * (iw + ig), 646)
			ic.color      = Color(0.06, 0.12, 0.18, 0.85)
			ic.modulate.a = 0
			overlay.add_child(ic)

			# Icon TextureRect
			var icon_path: String = rd.get("icon", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var tex := TextureRect.new()
				tex.texture      = load(icon_path)
				tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
				tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex.size         = Vector2(72, 72)
				tex.position     = Vector2((iw - 72) / 2.0, 8)
				ic.add_child(tex)
			else:
				BattleUI.center_label(ic, "?", 36, Color.WHITE, Vector2(0, 8), Vector2(iw, 72))

			BattleUI.center_label(ic, rd.get("text", ""), 13,
				Color(0.90, 0.95, 1.00), Vector2(0, 84), Vector2(iw, 22))
			create_tween().tween_property(ic, "modulate:a", 1.0, 0.3).set_delay(0.3 + 0.15 * j)

		await get_tree().create_timer(0.5 + 0.15 * reward_items.size() + 1.5).timeout
	else:
		await get_tree().create_timer(2.0).timeout

	var cont := Button.new()
	cont.text     = "Continue  →"
	cont.size     = Vector2(210, 54)
	cont.position = Vector2(855, 978)
	cont.add_theme_font_size_override("font_size", 22)
	cont.modulate.a = 0
	cont.pressed.connect(func():
		overlay.queue_free()
		SaveData.save()
		GameState.finish_level()
	)
	overlay.add_child(cont)
	create_tween().tween_property(cont, "modulate:a", 1.0, 0.4)
	SaveData.save()



# ══════════════════════════════════════════════════════════════════════════════
# CAPTURE (STAR SEED THROW)
# ══════════════════════════════════════════════════════════════════════════════

func throw_star_seed():
	var orig_scale: Vector2 = enemy_monster.scale
	var orig_pos: Vector2   = enemy_monster.global_position

	var start_p: Vector2  = ($StartMarker as Marker2D).global_position
	var ground_p: Vector2 = ($GroundMarker as Marker2D).global_position

	# ── 1. Throw from StartMarker → arc to GroundMarker ──────────────────
	var seed := Sprite2D.new()
	seed.texture = load("res://assets/ui/star seed throw.png")
	seed.scale   = Vector2(0.16, 0.16)
	seed.z_index = 102
	seed.global_position = start_p
	add_child(seed)

	var fly := create_tween().set_parallel(true)
	fly.tween_property(seed, "rotation_degrees", 720.0, 0.55)
	fly.tween_method(func(t: float):
		var p: Vector2 = start_p.lerp(ground_p, t)
		p.y -= 220.0 * 4.0 * t * (1.0 - t)   # parabolic arc
		seed.global_position = p
	, 0.0, 1.0, 0.55).set_ease(Tween.EASE_OUT)
	await fly.finished

	# ── 2. Seed bounces on ground ─────────────────────────────────────────
	seed.rotation_degrees = 0
	BattleAnimations.shake_screen(self)
	var bounce := create_tween()
	bounce.tween_property(seed, "global_position:y", ground_p.y - 28.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(seed, "global_position:y", ground_p.y,        0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await bounce.finished

	# Landing glow pulse
	var glow := create_tween().set_loops(2)
	glow.tween_property(seed, "modulate", Color(1.8, 1.6, 0.4, 1.0), 0.12)
	glow.tween_property(seed, "modulate", Color(1.0, 1.0, 0.85, 1.0), 0.12)
	await glow.finished

	# ── 3. Monster sucks into the seed ───────────────────────────────────
	# White-out the enemy sprite first
	var wmat := ShaderMaterial.new()
	var sh   := Shader.new()
	sh.code = "shader_type canvas_item; uniform float w : hint_range(0.0,1.0)=0.0; void fragment(){vec4 t=texture(TEXTURE,UV);COLOR=vec4(mix(t.rgb,vec3(1.0),w),t.a);}"
	wmat.shader = sh
	var esp: Sprite2D = enemy_monster.get_node("Sprite2D") as Sprite2D
	esp.material = wmat
	var whiten := create_tween()
	whiten.tween_method(func(v: float): wmat.set_shader_parameter("w", v), 0.0, 1.0, 0.30)
	await whiten.finished

	# Suck toward the seed at ground_p
	var suck := create_tween().set_parallel(true)
	suck.tween_property(enemy_monster, "global_position", ground_p,         0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	suck.tween_property(enemy_monster, "scale",           Vector2(0.04, 0.04), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	suck.tween_property(enemy_monster, "modulate:a",      0.0,                0.45)
	await suck.finished

	# Seed flashes gold when monster enters
	seed.modulate = Color(2.2, 1.9, 0.5, 1.0)
	await get_tree().create_timer(0.12).timeout
	seed.modulate = Color(1.0, 1.0, 0.90, 1.0)

	# Two expanding teal rings on the ground
	for i in 2:
		var rd := i * 0.16
		var ring := Panel.new()
		ring.z_index = 101
		var rs := StyleBoxFlat.new()
		rs.bg_color     = Color(0, 0, 0, 0)
		rs.border_color = Color(0.24, 0.85, 0.82, 0.75)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			rs.set_border_width(side, 4)
		rs.corner_radius_top_left     = 120
		rs.corner_radius_top_right    = 120
		rs.corner_radius_bottom_right = 120
		rs.corner_radius_bottom_left  = 120
		ring.add_theme_stylebox_override("panel", rs)
		ring.size = Vector2(10, 10); ring.pivot_offset = Vector2(5, 5)
		ring.position = ground_p - Vector2(5, 5)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ring)
		var rtw := create_tween().set_parallel(true)
		rtw.tween_property(ring, "size",         Vector2(240, 240), 0.50).set_delay(rd).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rtw.tween_property(ring, "pivot_offset", Vector2(120, 120), 0.50).set_delay(rd)
		rtw.tween_property(ring, "position",     ground_p - Vector2(120, 120), 0.50).set_delay(rd)
		rtw.tween_property(ring, "modulate:a",   0.0, 0.45).set_delay(rd + 0.14)
		rtw.tween_callback(ring.queue_free).set_delay(rd + 0.60)

	# ── 4. Seed bobs gently ───────────────────────────────────────────────
	await get_tree().create_timer(0.12).timeout
	var bob := create_tween().set_loops(4)
	bob.tween_property(seed, "global_position:y", ground_p.y - 10.0, 0.26).set_trans(Tween.TRANS_SINE)
	bob.tween_property(seed, "global_position:y", ground_p.y,        0.26).set_trans(Tween.TRANS_SINE)
	await bob.finished

	# ── 5. Capture check — uses rarity modifier via CombatCalculator ────────
	var chance: float = CombatCalculator.calculate_capture_chance(enemy_monster)

	if randf() < chance:
		add_log("%s was captured!" % enemy_monster.display_name, "good")
		BattleAnimations.show_float_text(self, ground_p + Vector2(0, -60), "Captured!", Color(0.24, 0.85, 0.82))
		BattleAnimations.shake_screen(self)
		var ok := create_tween().set_parallel(true)
		ok.tween_property(seed, "scale",    Vector2(0.30, 0.30), 0.20)
		ok.tween_property(seed, "modulate", Color(2.0, 1.8, 0.5, 0.0), 0.35).set_delay(0.08)
		await ok.finished
		seed.queue_free()
		var _team_was_full: bool = SaveData.get_team().size() >= 3
		SaveData.add_monster_to_team(enemy_monster.monster_id, enemy_monster.level)
		if _team_was_full:
			add_log("%s was caught! (Team was full — added to Mogadex)" % enemy_monster.display_name, "good")
			BattleAnimations.show_float_text(self, enemy_monster.global_position + Vector2(0, -80),
				"Team Full! Added to Mogadex", Color(0.24, 0.85, 0.82))
			await get_tree().create_timer(1.5).timeout
		_state.battle_over = true
		await get_tree().create_timer(0.6).timeout
		GameState.finish_level()
	else:
		add_log("%s broke free!" % enemy_monster.display_name, "bad")
		BattleAnimations.show_float_text(self, ground_p + Vector2(0, -60), "Broke free!", Color(0.9, 0.3, 0.2))
		var fail := create_tween().set_parallel(true)
		fail.tween_property(seed, "rotation_degrees", 160.0,                  0.24)
		fail.tween_property(seed, "modulate",          Color(1.2, 0.2, 0.2, 0.0), 0.28)
		await fail.finished
		seed.queue_free()
		# Monster pops back at original position
		esp.material = null
		enemy_monster.global_position = orig_pos
		enemy_monster.scale           = Vector2(0.04, 0.04)
		enemy_monster.modulate        = Color.WHITE
		enemy_monster.modulate.a      = 1.0
		var reappear := create_tween()
		reappear.tween_property(enemy_monster, "scale", orig_scale * 1.10, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await reappear.finished
		create_tween().tween_property(enemy_monster, "scale", orig_scale, 0.14)
		await get_tree().create_timer(0.5).timeout
		if not _state.battle_over:
			await enemy_turn()


# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════



func _on_move_btn_hover(index: int):
	if not _state.is_player_turn or _state.battle_over:
		return
	var moves: Array = player_monster.moves
	if index >= moves.size():
		return
	_show_tooltip(moves[index], move_buttons[index])










func _get_next_alive_monster() -> String:
	var team := SaveData.get_team()
	for raw in team:
		var mid := str(raw)
		if mid == player_monster.monster_id:
			continue  # skip the one that just fainted
		var hp: int = _state.team_hp.get(mid, -1)
		if hp == -1 or hp > 0:
			return mid  # -1 = never entered battle (full HP), >0 = still has HP
	return ""
