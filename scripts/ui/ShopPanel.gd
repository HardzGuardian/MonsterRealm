extends CanvasLayer

signal closed()

var _panel:    ColorRect = null
var _gold_lbl: Label     = null


func _ready():
	layer   = 1000
	visible = false
	_build()


func open():
	_refresh_gold()
	visible = true


func _build():
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color        = GameTheme.DIM_MEDIUM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = ColorRect.new()
	_panel.anchor_left   = 0.5; _panel.anchor_top    = 0.5
	_panel.anchor_right  = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left   = -700; _panel.offset_top   = -380
	_panel.offset_right  =  700; _panel.offset_bottom = 400
	_panel.color         = GameTheme.BG_PANEL
	add_child(_panel)

	var header := ColorRect.new()
	header.size  = Vector2(1400, 60)
	header.color = GameTheme.BG_DARK
	_panel.add_child(header)

	var title_lbl := Label.new()
	title_lbl.text               = "SHOP"
	title_lbl.size               = Vector2(1400, 60)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	GameTheme.apply_title(title_lbl, GameTheme.FONT_TITLE)
	title_lbl.add_theme_color_override("font_color", GameTheme.GOLD)
	header.add_child(title_lbl)

	var header_coin := TextureRect.new()
	header_coin.texture      = load("res://assets/ui/coin.png")
	header_coin.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	header_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_coin.size         = Vector2(32, 32)
	header_coin.position     = Vector2(1138, 14)
	header.add_child(header_coin)

	_gold_lbl = Label.new()
	_gold_lbl.position           = Vector2(1172, 0)
	_gold_lbl.size               = Vector2(168, 60)
	_gold_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_lbl.add_theme_font_size_override("font_size", GameTheme.FONT_NORMAL)
	_gold_lbl.add_theme_color_override("font_color", GameTheme.GOLD)
	header.add_child(_gold_lbl)

	var close_btn := GameTheme.make_close_btn(Vector2(1352, 10))
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 72)
	scroll.size     = Vector2(1360, 680)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for item in GameData.get_shop_items():
		_add_card(grid, item)


func _add_card(grid: GridContainer, item: Dictionary):
	var card := ColorRect.new()
	card.custom_minimum_size = Vector2(310, 258)
	card.clip_contents = true
	card.color = GameTheme.BG_CARD
	grid.add_child(card)

	var accent := ColorRect.new()
	accent.size  = Vector2(310, 3)
	accent.color = GameTheme.TEAL_DIM
	card.add_child(accent)

	var icon := TextureRect.new()
	icon.position     = Vector2(95, 16)
	icon.size         = Vector2(120, 120)
	icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_path: String = item.get("icon", "")
	if FileAccess.file_exists(icon_path):
		icon.texture = load(icon_path)
	card.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text               = item.get("name", "")
	name_lbl.position           = Vector2(0, 144)
	name_lbl.size               = Vector2(310, 28)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameTheme.FONT_NORMAL)
	name_lbl.add_theme_color_override("font_color", GameTheme.TEXT_PRIMARY)
	card.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text               = item.get("description", "")
	desc_lbl.anchor_left        = 0.0
	desc_lbl.anchor_right       = 1.0
	desc_lbl.anchor_top         = 0.0
	desc_lbl.anchor_bottom      = 0.0
	desc_lbl.offset_left        = 6
	desc_lbl.offset_right       = -6
	desc_lbl.offset_top         = 170
	desc_lbl.offset_bottom      = 212
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode      = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	card.add_child(desc_lbl)

	var coin_tex := TextureRect.new()
	coin_tex.texture      = load("res://assets/ui/coin.png")
	coin_tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	coin_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_tex.size         = Vector2(26, 26)
	coin_tex.position     = Vector2(10, 219)
	card.add_child(coin_tex)

	var price_lbl := Label.new()
	price_lbl.text               = " %d" % int(item.get("shop_price", 0))
	price_lbl.position           = Vector2(38, 216)
	price_lbl.size               = Vector2(130, 32)
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 18)
	price_lbl.add_theme_color_override("font_color", GameTheme.GOLD)
	card.add_child(price_lbl)

	var buy_btn := Button.new()
	buy_btn.text     = "Buy"
	buy_btn.position = Vector2(196, 216)
	buy_btn.size     = Vector2(106, 32)
	buy_btn.add_theme_font_size_override("font_size", GameTheme.FONT_SMALL)
	var iid: String = item.get("id", "")
	var cost: int   = int(item.get("shop_price", 0))
	buy_btn.pressed.connect(_on_buy.bind(iid, cost))
	card.add_child(buy_btn)


func _on_buy(item_id: String, cost: int):
	var gold: int = SaveData.data.get("gold", 0)
	if gold >= cost:
		SaveData.data["gold"] = gold - cost
		SaveData.add_inventory_item(item_id, 1)
		_refresh_gold()


func _refresh_gold():
	if _gold_lbl:
		_gold_lbl.text = " %d" % SaveData.data.get("gold", 0)


func _on_close():
	visible = false
	closed.emit()
