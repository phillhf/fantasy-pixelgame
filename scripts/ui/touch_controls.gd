extends CanvasLayer
## Bildschirmsteuerung für Touch-Geräte. Autoload "Touch".
## Steuerkreuz links, Bestätigen (A) und Menü rechts. In Menüs tippt man direkt auf die Einträge.

const BTN := 24.0

var _walk_mode := false
var _enabled := false


func _ready() -> void:
	layer = 80
	_enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or bool(Game.config.get("force_touch_controls", false))
	_add_button("ui_up", "▲", Vector2(38, 150))
	_add_button("ui_down", "▼", Vector2(38, 192))
	_add_button("ui_left", "◀", Vector2(17, 171))
	_add_button("ui_right", "▶", Vector2(59, 171))
	_add_button("ui_accept", "A", Vector2(354, 168), 15.0)
	_add_button("ui_cancel", "Menü", Vector2(318, 192), 13.0)
	_update()


func set_walk_mode(on: bool) -> void:
	_walk_mode = on
	_update()


func _update() -> void:
	visible = _enabled and _walk_mode


func _add_button(action: String, caption: String, center: Vector2, radius: float = 0.0) -> void:
	var b := TouchScreenButton.new()
	b.action = action
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	b.passby_press = true
	var shape: Shape2D
	if radius > 0.0:
		var c := CircleShape2D.new()
		c.radius = radius
		shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = Vector2(BTN, BTN)
		shape = r
	b.shape = shape
	b.shape_centered = true
	b.position = center
	var look := _ButtonLook.new()
	look.caption = caption
	look.radius = radius
	b.add_child(look)
	add_child(b)


class _ButtonLook extends Node2D:
	const BTN := 24.0
	var caption := ""
	var radius := 0.0

	func _draw() -> void:
		var bg := Color(1, 1, 1, 0.22)
		var fg := Color(1, 1, 1, 0.75)
		if radius > 0.0:
			draw_circle(Vector2.ZERO, radius, bg)
		else:
			draw_rect(Rect2(Vector2(-BTN / 2, -BTN / 2), Vector2(BTN, BTN)), bg)
		var font: Font = load("res://assets/fonts/pixelfont.fnt")
		var fs := 12
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-w / 2, 3), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
