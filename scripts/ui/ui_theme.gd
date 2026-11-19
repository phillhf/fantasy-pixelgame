class_name UiTheme
extends RefCounted
## Gemeinsames Aussehen aller Fenster und Menüs (Platzhalter im Stil klassischer Rollenspiele).

const FONT_SIZE := 10
const PANEL_BG := Color(0.06, 0.08, 0.22, 0.94)
const PANEL_BORDER := Color(0.92, 0.92, 0.98)
const TEXT := Color(0.97, 0.97, 1.0)
const HIGHLIGHT := Color(1.0, 0.86, 0.35)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT_SIZE

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = PANEL_BORDER
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(2)
	panel.set_content_margin_all(4)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var empty := StyleBoxEmpty.new()
	empty.set_content_margin_all(1)
	empty.content_margin_left = 8
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.14)
	focus.set_content_margin_all(1)
	focus.content_margin_left = 8
	focus.border_color = HIGHLIGHT
	focus.border_width_left = 3
	for s in ["normal", "disabled"]:
		t.set_stylebox(s, "Button", empty)
	for s in ["focus", "hover", "pressed", "hover_pressed"]:
		t.set_stylebox(s, "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", HIGHLIGHT)
	t.set_color("font_hover_color", "Button", HIGHLIGHT)
	t.set_color("font_pressed_color", "Button", HIGHLIGHT)
	t.set_color("font_hover_pressed_color", "Button", HIGHLIGHT)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.6, 0.65))
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t


static func panel(rect: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = get_theme()
	p.position = rect.position
	p.size = rect.size
	p.custom_minimum_size = rect.size
	return p


static func label(text: String = "", size: int = FONT_SIZE) -> Label:
	var l := Label.new()
	l.theme = get_theme()
	l.text = text
	if size != FONT_SIZE:
		l.add_theme_font_size_override("font_size", size)
	return l
