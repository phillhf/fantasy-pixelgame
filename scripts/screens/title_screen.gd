class_name TitleScreen
extends CanvasLayer
## Titelbild mit Neues Spiel / Fortsetzen / Beenden.

signal new_game
signal continue_game

var menu: ChoiceMenu


func _ready() -> void:
	Touch.set_walk_mode(false)
	var bgr := ColorRect.new()
	bgr.color = Color("#0b1030")
	bgr.size = Vector2(384, 216)
	add_child(bgr)
	var title := UiTheme.label("FantasyPixelgame", 24)
	title.position = Vector2(0, 40)
	title.size = Vector2(384, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiTheme.HIGHLIGHT)
	add_child(title)
	var sub := UiTheme.label("Arbeitstitel · Prototyp %s" % ProjectSettings.get_setting("application/config/version", "0.1.0"))
	sub.position = Vector2(0, 74)
	sub.size = Vector2(384, 14)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	menu = ChoiceMenu.new()
	add_child(menu)
	_open_menu()


func _open_menu() -> void:
	var opts: Array = ["Neues Spiel"]
	if Game.has_save():
		opts.append("Fortsetzen")
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		opts.append("Beenden")
	menu.open(opts, false, 1, 1 if Game.has_save() else 0)
	menu.position = Vector2(150, 120)
	var i: int = await menu.chosen
	menu.close()
	match String(opts[i]):
		"Neues Spiel":
			new_game.emit()
		"Fortsetzen":
			continue_game.emit()
		"Beenden":
			get_tree().quit()
