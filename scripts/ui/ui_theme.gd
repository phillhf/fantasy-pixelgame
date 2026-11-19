class_name UiTheme
extends RefCounted
## Aussehen aller Fenster und Menüs im Stil klassischer 16-Bit-Rollenspiele:
## schwarze Fenster mit weißem Pixelrahmen, eigene Pixelschrift, Zeiger ▶.

const FONT_SIZE := 12  # Originalgröße der Pixelschrift, nicht ändern (sonst unscharf)
const TEXT := Color(1, 1, 1)
const HIGHLIGHT := Color(1.0, 0.9, 0.4)
const DIM := Color(0.55, 0.55, 0.6)

static var _theme: Theme
static var font: Font
static var cursor_tex: Texture2D
static var blank_tex: Texture2D


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	font = load("res://assets/fonts/pixelfont.fnt")
	cursor_tex = load("res://assets/ui/cursor.png")
	blank_tex = load("res://assets/ui/blank.png")
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = FONT_SIZE

	var panel := StyleBoxTexture.new()
	panel.texture = load("res://assets/ui/window.png")
	panel.set_texture_margin_all(6)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 5
	panel.content_margin_bottom = 4
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 0
	empty.content_margin_right = 2
	empty.content_margin_top = 0
	empty.content_margin_bottom = 0
	for s in ["normal", "disabled", "focus", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(s, "Button", empty)
	for c in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_constant("h_separation", "Button", 3)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("line_spacing", "Label", 1)
	_theme = t
	return t


static func panel(rect: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = get_theme()
	p.position = rect.position
	p.size = rect.size
	p.custom_minimum_size = rect.size
	return p


## Textfeld. pixel_scale vergrößert ganzzahlig (z. B. 2 für Überschriften).
static func label(text: String = "", pixel_scale: int = 1) -> Label:
	var l := Label.new()
	l.theme = get_theme()
	l.text = text
	if pixel_scale > 1:
		l.scale = Vector2(pixel_scale, pixel_scale)
	return l


## Button mit ▶-Zeiger, der nur beim ausgewählten Eintrag erscheint.
static func menu_button(text: String) -> Button:
	get_theme()
	var b := Button.new()
	b.theme = _theme
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = blank_tex
	b.focus_entered.connect(func() -> void: b.icon = cursor_tex)
	b.focus_exited.connect(func() -> void: b.icon = blank_tex)
	return b
