extends Control

const HOME_ROAMING_MONSTER_SCENE := preload("res://scenes/home/HomeRoamingMonster.tscn")
const ROAM_BOUNDS := Rect2(160.0, 160.0, 1420.0, 600.0)

@onready var map_button: Button = $TopBar/MapButton
@onready var home_button: Button = $TopBar/HomeButton
@onready var pokedex_button: Button = $TopBar/PokedexButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var team_button: Button = $TopBar/TeamButton
@onready var shop_button: Button = $TopBar/ShopButton
@onready var gold_label: Label = $TopBar/GoldDisplay/Label

@onready var roaming_monsters: Node2D = $RoamingMonsters
var _shop: Node = null

@onready var team_slot_one: TextureRect = $BottomSlotBar/TeamSlotOne
@onready var team_slot_two: TextureRect = $BottomSlotBar/TeamSlotTwo
@onready var team_slot_three: TextureRect = $BottomSlotBar/TeamSlotThree

@onready var inventory_button: Button = $TopBar/InventoryButton
@onready var inventory_panel: Control = $InventoryPanel
@onready var inv_close_button: Button = $InventoryPanel/CloseButton

var _mogadex:  Node = null
var _settings: Node = null
var _slot_panel: Node = null

var monster_data: Dictionary = {}


func _ready():
	map_button.pressed.connect(_on_map_pressed)
	home_button.pressed.connect(_on_home_pressed)
	pokedex_button.pressed.connect(_on_collection_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	inv_close_button.pressed.connect(_on_inventory_close_pressed)

	monster_data = GameData.monsters
	inventory_panel.z_index = 1000

	_mogadex = load("res://scripts/ui/MogadexPanel.gd").new()
	add_child(_mogadex)
	_mogadex.visible = false
	_mogadex.closed.connect(_on_mogadex_closed)
	_mogadex.team_changed.connect(func():
		update_team_slots()
		spawn_captured_monsters()
	)

	_shop = load("res://scripts/ui/ShopPanel.gd").new()
	add_child(_shop)
	_shop.closed.connect(_on_shop_closed)

	_settings = load("res://scripts/ui/SettingsPanel.gd").new()
	add_child(_settings)
	_settings.closed.connect(func(): $BottomSlotBar.visible = true)

	_apply_nav_icons()
	update_gold_display()
	spawn_captured_monsters()
	update_team_slots()

	_maybe_show_slot_picker()


func _apply_nav_icons():
	var nav: Array = [
		[home_button,      "res://assets/ui/icon_home.png"],
		[map_button,       "res://assets/ui/icon_map.png"],
		[pokedex_button,   "res://assets/ui/icon_mogadex.png"],
		[inventory_button, "res://assets/ui/icon_inventory.png"],
		[shop_button,      "res://assets/ui/icon_shop.png"],
		[settings_button,  "res://assets/ui/icon_settings.png"],
	]
	const BTN_SIZE := 62
	const GAP     := 8
	const START_X := 12
	const TOP_Y   := 4
	for i in nav.size():
		var btn: Button  = nav[i][0]
		var path: String = nav[i][1]
		if FileAccess.file_exists(path):
			btn.icon        = load(path)
			btn.expand_icon = true
		btn.text                = ""
		btn.flat                = true
		btn.focus_mode          = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.size                = Vector2(BTN_SIZE, BTN_SIZE)
		btn.position            = Vector2(START_X + i * (BTN_SIZE + GAP), TOP_Y)


func _close_all_panels():
	if _mogadex: _mogadex.visible = false
	if _shop:    _shop.visible    = false
	inventory_panel.visible = false
	$BottomSlotBar.visible  = true


func _open_panel(panel: CanvasItem):
	_close_all_panels()
	$BottomSlotBar.visible = false
	panel.visible = true


func _on_collection_pressed():
	_close_all_panels()
	$BottomSlotBar.visible = false
	_mogadex.open()


func _on_mogadex_closed():
	$BottomSlotBar.visible = true


func spawn_captured_monsters():
	for child in roaming_monsters.get_children():
		child.queue_free()

	const MAX_ROAMING := 8
	var seen: Dictionary = {}
	var instances: Dictionary = SaveData.data.get("monster_instances", {})
	var caught: Array = SaveData.data.get("caught_monsters", [])
	var team: Array = SaveData.get_team()

	# Team members spawn first
	var priority_order: Array = team.duplicate()
	for sp in instances.keys():
		if str(sp) not in priority_order:
			priority_order.append(str(sp))

	for species in priority_order:
		if roaming_monsters.get_child_count() >= MAX_ROAMING: break
		if str(species) not in caught: continue
		if not instances.has(species): continue
		if not monster_data.has(str(species)): continue
		var arr: Array = instances[species]
		var should_spawn := false
		for i in arr.size():
			if SaveData.get_instance_roaming(str(species), i) \
					or SaveData.get_instance_fainted(str(species), i):
				should_spawn = true
				break
		if should_spawn and not seen.has(str(species)):
			seen[str(species)] = true
			var roaming_monster = HOME_ROAMING_MONSTER_SCENE.instantiate()
			roaming_monsters.add_child(roaming_monster)
			roaming_monster.configure(str(species), ROAM_BOUNDS)


func update_team_slots():
	var slots: Array[TextureRect] = [team_slot_one, team_slot_two, team_slot_three]
	var team: Array = SaveData.get_team()
	var slot_path := "res://assets/ui/slot.png"
	for i in slots.size():
		var slot := slots[i]
		if FileAccess.file_exists(slot_path):
			slot.texture = load(slot_path)
		if i >= team.size():
			continue
		var m_data: Dictionary = GameData.get_monster(str(team[i]))
		var icon_path: String = m_data.get("icon", m_data.get("sprite", ""))
		if icon_path != "":
			slot.texture = load(icon_path)
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		_close_all_panels()


func _on_settings_pressed():
	_close_all_panels()
	$BottomSlotBar.visible = false
	_settings.open()


func _maybe_show_slot_picker():
	# Show slot picker if settings.json has no slot recorded
	var settings_file := FileAccess.open("user://settings.json", FileAccess.READ)
	var has_slot := false
	if settings_file:
		var json := JSON.new()
		if json.parse(settings_file.get_as_text()) == OK and json.data is Dictionary:
			has_slot = json.data.has("current_slot")
	if not has_slot:
		_slot_panel = load("res://scripts/ui/SaveSlotPanel.gd").new()
		add_child(_slot_panel)
		_slot_panel.slot_selected.connect(func(_idx: int):
			update_gold_display()
			spawn_captured_monsters()
			update_team_slots()
		)
		_slot_panel.open()


func _on_map_pressed():
	GameState.go_world_map()


func _on_home_pressed():
	pass


func _on_shop_pressed():
	_close_all_panels()
	$BottomSlotBar.visible = false
	_shop.open()


func _on_shop_closed():
	$BottomSlotBar.visible = true


func update_gold_display():
	var gold: int = SaveData.data.get("gold", 0)
	_ensure_coin_icon(gold_label)
	gold_label.text = str(gold)


func _ensure_coin_icon(lbl: Label):
	if lbl.get_parent().get_node_or_null("CoinIcon"): return
	var gd := lbl.get_parent()
	gd.offset_left  = 1750.0
	gd.offset_right = 1910.0
	var coin := TextureRect.new()
	coin.name         = "CoinIcon"
	coin.texture      = load("res://assets/ui/coin.png")
	coin.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size         = Vector2(30, 30)
	coin.position     = Vector2(0, 10)
	coin.z_index      = 1
	gd.add_child(coin)
	lbl.offset_left  = 36
	lbl.offset_right = 160
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _on_inventory_pressed():
	_open_panel(inventory_panel)
	UIUtils.update_inventory_ui(inventory_panel)


func _on_inventory_close_pressed():
	inventory_panel.visible = false
