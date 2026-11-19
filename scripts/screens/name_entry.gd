class_name NameEntry
extends CanvasLayer
## Namenseingabe über ein Buchstabenfeld. Funktioniert mit Tastatur, Controller und Touch.

signal done(hero_name: String)

const ROWS := [
	"ABCDEFGHIJKLM",
	"NOPQRSTUVWXYZ",
	"abcdefghijklm",
	"nopqrstuvwxyz",
	"ÄÖÜäöüß-'",
]

var current := ""
var name_label: Label
var max_len := 8
var _finished := false


func _ready() -> void:
	Touch.set_walk_mode(false)
	max_len = int(Game.config.get("max_name_length", 8))
	var bgr := ColorRect.new()
	bgr.color = Color("#0b1030")
	bgr.size = Vector2(384, 216)
	add_child(bgr)

	var head := UiTheme.panel(Rect2(40, 8, 304, 40))
	var v := VBoxContainer.new()
	v.add_child(UiTheme.label("Wie heißt der Ritter, der aus dem Krieg heimkehrt?"))
	name_label = UiTheme.label("", 12)
	name_label.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
	v.add_child(name_label)
	head.add_child(v)
	add_child(head)

	var pad := UiTheme.panel(Rect2(40, 54, 304, 154))
	var box := VBoxContainer.new()
	var grid := GridContainer.new()
	grid.columns = 13
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	var first: Button
	for row in ROWS:
		for i in 13:
			var b := Button.new()
			b.custom_minimum_size = Vector2(22, 16)
			if i < row.length():
				var ch: String = row[i]
				b.text = ch
				b.pressed.connect(_add.bind(ch))
			else:
				b.text = ""
				b.disabled = true
				b.focus_mode = Control.FOCUS_NONE
			grid.add_child(b)
			if first == null:
				first = b
	box.add_child(grid)
	var row2 := HBoxContainer.new()
	for pair in [["Leerzeichen", _add.bind(" ")], ["Löschen", _delete], ["Vorschlag", _suggest], ["Fertig", _finish]]:
		var b := Button.new()
		b.text = pair[0]
		b.pressed.connect(pair[1])
		row2.add_child(b)
	box.add_child(row2)
	pad.add_child(box)
	add_child(pad)
	_suggest()
	first.grab_focus()


func _add(ch: String) -> void:
	if current.length() < max_len:
		current += ch
	_refresh()


func _delete() -> void:
	if current.length() > 0:
		current = current.substr(0, current.length() - 1)
	_refresh()


func _suggest() -> void:
	current = String(Game.config.get("default_hero_name", "Garet"))
	_refresh()


func _refresh() -> void:
	name_label.text = current + "_".repeat(max(0, max_len - current.length()))


func _finish() -> void:
	if _finished:
		return
	var n := current.strip_edges()
	if n.is_empty():
		_suggest()
		return
	_finished = true
	done.emit(n)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_delete()
