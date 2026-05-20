extends Node

var body_font:  FontFile = null
var title_font: FontFile = null


func _ready():
	_load_fonts()
	call_deferred("_apply_root_theme")


func _load_fonts():
	var bp := "res://assets/fonts/Nunito-Regular.ttf"
	var tp := "res://assets/fonts/FredokaOne.woff2"
	if ResourceLoader.exists(bp):
		body_font  = load(bp)
	if ResourceLoader.exists(tp):
		title_font = load(tp)


func _apply_root_theme():
	var theme := Theme.new()
	if body_font:
		theme.default_font      = body_font
		theme.default_font_size = 16
	get_tree().root.theme = theme


func apply_title(node: Control, size: int = FONT_TITLE):
	if title_font:
		node.add_theme_font_override("font", title_font)
	node.add_theme_font_size_override("font_size", size)


func apply_body(node: Control, size: int = FONT_NORMAL):
	if body_font:
		node.add_theme_font_override("font", body_font)
	node.add_theme_font_size_override("font_size", size)


const BG_OVERLAY   := Color(0.03, 0.05, 0.10, 0.96)
const BG_PANEL     := Color(0.05, 0.09, 0.14, 0.97)
const BG_DARK      := Color(0.03, 0.055, 0.10, 1.0)
const BG_DARKER    := Color(0.038, 0.060, 0.086, 1.0)
const BG_CARD      := Color(0.07, 0.12, 0.20, 1.0)
const BG_CARD_DIM  := Color(0.05, 0.08, 0.13, 1.0)
const BG_INPUT     := Color(0.06, 0.10, 0.15, 1.0)

const TEAL         := Color(0.24, 0.85, 0.82, 1.0)
const TEAL_DIM     := Color(0.16, 0.42, 0.58, 0.75)
const TEAL_GLOW    := Color(0.24, 0.85, 0.82, 0.30)
const GOLD         := Color(1.00, 0.85, 0.30, 1.0)
const GOLD_DIM     := Color(1.00, 0.80, 0.15, 0.80)

const SUCCESS      := Color(0.25, 0.92, 0.45, 1.0)
const WARNING      := Color(0.90, 0.65, 0.15, 1.0)
const DANGER       := Color(0.90, 0.25, 0.22, 1.0)
const DANGER_DIM   := Color(0.72, 0.22, 0.14, 0.80)

const HP_HIGH      := Color(0.20, 0.80, 0.35)
const HP_MID       := Color(0.90, 0.70, 0.10)
const HP_LOW       := Color(0.85, 0.20, 0.20)

static func hp_color(fraction: float) -> Color:
	if fraction > 0.5:  return HP_HIGH
	if fraction > 0.25: return HP_MID
	return HP_LOW

const TEXT_PRIMARY  := Color(1.00, 1.00, 1.00, 1.0)
const TEXT_NORMAL   := Color(0.85, 0.90, 0.95, 0.95)
const TEXT_MUTED    := Color(0.60, 0.70, 0.75, 0.85)
const TEXT_DIM      := Color(0.55, 0.65, 0.72, 0.80)
const TEXT_TEAL     := TEAL
const TEXT_GOLD     := GOLD
const TEXT_SUCCESS  := SUCCESS
const TEXT_DANGER   := DANGER

const FONT_HERO    := 52
const FONT_TITLE   := 28
const FONT_LARGE   := 22
const FONT_NORMAL  := 17
const FONT_SMALL   := 14
const FONT_TINY    := 12

const BORDER_TEAL  := Color(0.24, 0.85, 0.82, 0.28)
const BORDER_DIM   := Color(0.18, 0.32, 0.48, 0.45)
const DIVIDER      := Color(0.15, 0.30, 0.45, 0.55)

const DIM_HEAVY    := Color(0.00, 0.00, 0.00, 0.82)
const DIM_MEDIUM   := Color(0.00, 0.00, 0.00, 0.65)
const DIM_LIGHT    := Color(0.00, 0.00, 0.00, 0.45)


static func style_panel_button(btn: Button,
		bg: Color = BG_CARD,
		border: Color = BORDER_DIM,
		radius: int = 8):
	var sn := _flat(bg, border, radius)
	var sh := _flat(bg.lightened(0.10), border.lightened(0.15), radius)
	var sd := _flat(BG_DARKER, BORDER_DIM * Color(1,1,1,0.4), radius)
	btn.add_theme_stylebox_override("normal",   sn)
	btn.add_theme_stylebox_override("hover",    sh)
	btn.add_theme_stylebox_override("disabled", sd)


static func make_close_btn(pos: Vector2, size: Vector2 = Vector2(40, 40)) -> Button:
	var btn := Button.new()
	btn.position   = pos
	btn.size       = size
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.text       = ""
	var close_path := "res://assets/ui/btn_close.png"
	if ResourceLoader.exists(close_path):
		btn.icon        = load(close_path)
		btn.expand_icon = true
	else:
		btn.text = "✕"
		btn.add_theme_font_size_override("font_size", 20)
	return btn


static func _flat(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color    = bg
	s.border_color = border
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		s.set_border_width(side, 2)
	for r in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_right","corner_radius_bottom_left"]:
		s.set(r, radius)
	return s
