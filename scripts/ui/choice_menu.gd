class_name ChoiceMenu
extends PanelContainer
## Auswahlmenü. Bedienbar mit Tastatur, Controller und Touch.
## Nutzung: menu.open(["A", "B"]); var i: int = await menu.chosen  (-1 = Zurück)

signal chosen(index: int)

var _grid: GridContainer
var _buttons: Array[Button] = []
var _active := false
var _allow_cancel := true


func _init() -> void:
	theme = UiTheme.get_theme()
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 2)
	add_child(_grid)
	hide()


func open(options: Array, allow_cancel: bool = true, columns: int = 1, start: int = 0) -> void:
	for b in _buttons:
		_grid.remove_child(b)
		b.queue_free()
	_buttons.clear()
	_grid.columns = columns
	_allow_cancel = allow_cancel
	var all: Array = options.duplicate()
	if allow_cancel:
		all.append("Zurück")
	for i in all.size():
		var b := UiTheme.menu_button(String(all[i]))
		b.custom_minimum_size = Vector2(56, 0)
		var idx: int = i if i < options.size() else -1
		b.pressed.connect(_on_pressed.bind(idx))
		_grid.add_child(b)
		_buttons.append(b)
	size = Vector2.ZERO
	reset_size()
	show()
	_active = true
	_buttons[clampi(start, 0, _buttons.size() - 1)].grab_focus()


## Setzt das Menü so, dass die untere linke Ecke bei (x, bottom) liegt.
func place_bottom_left(x: float, bottom: float) -> void:
	reset_size()
	position = Vector2(x, bottom - get_combined_minimum_size().y)


func close() -> void:
	_active = false
	hide()


func _on_pressed(idx: int) -> void:
	if not _active:
		return
	_active = false
	chosen.emit(idx)


func _unhandled_input(event: InputEvent) -> void:
	if _active and _allow_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_active = false
		chosen.emit(-1)
