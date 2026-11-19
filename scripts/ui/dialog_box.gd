class_name DialogBox
extends PanelContainer
## Textfenster unten am Bildschirm. Weiter mit Bestätigen oder Antippen.
## Nutzung: await dialog.play(["Zeile 1", "Zeile 2"], "Name")

signal _advance

var _label: Label
var _typing := false
var _tween: Tween
var _open := false


func _init() -> void:
	theme = UiTheme.get_theme()
	position = Vector2(8, 150)
	custom_minimum_size = Vector2(368, 60)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.custom_minimum_size = Vector2(356, 50)
	add_child(_label)
	hide()


func is_open() -> bool:
	return _open


func play(lines: Array, speaker: String = "") -> void:
	if get_viewport():
		get_viewport().gui_release_focus()
	_open = true
	show()
	for line in lines:
		var t := String(line)
		if speaker != "":
			t = speaker + ": " + t
		_label.text = t
		_label.visible_ratio = 0.0
		_typing = true
		if _tween:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_label, "visible_ratio", 1.0, clampf(t.length() * 0.018, 0.1, 1.6))
		_tween.finished.connect(func() -> void: _typing = false)
		await _advance
	hide()
	_open = false


func _on_advance() -> void:
	if _typing:
		if _tween:
			_tween.kill()
		_label.visible_ratio = 1.0
		_typing = false
	else:
		_advance.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_advance()


func _gui_input(event: InputEvent) -> void:
	if _open and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_advance()
