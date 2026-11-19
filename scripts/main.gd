extends Node
## Hauptablauf: Titel → Namenseingabe → Karte ↔ Kampf.

var field: Field


func _ready() -> void:
	randomize()
	goto_title()
	if "--autotest" in OS.get_cmdline_user_args():
		var t: Node = load("res://tools/autotest.gd").new()
		get_tree().root.add_child.call_deferred(t)


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	field = null


func goto_title() -> void:
	_clear()
	var t := TitleScreen.new()
	t.new_game.connect(_on_new_game)
	t.continue_game.connect(_on_continue)
	add_child(t)


func _on_new_game() -> void:
	await Fade.fade_out()
	_clear()
	var n := NameEntry.new()
	n.done.connect(_on_name_done)
	add_child(n)
	await Fade.fade_in()


func _on_name_done(hero_name: String) -> void:
	await Fade.fade_out()
	Game.new_game(hero_name)
	_start_field(true)
	await Fade.fade_in()


func _on_continue() -> void:
	await Fade.fade_out()
	if Game.load_game():
		_start_field(false)
	else:
		goto_title()
	await Fade.fade_in()


func _start_field(intro: bool) -> void:
	_clear()
	field = Field.new()
	field.encounter.connect(_on_encounter)
	add_child(field)
	field.enter(Game.map_id, Game.pos, intro)


func _on_encounter(enemy_ids: Array, background: String) -> void:
	field.set_active(false)
	var b := Battle.new(enemy_ids, background)
	add_child(b)
	var result: String = await b.finished
	await Fade.fade_out()
	b.queue_free()
	field.set_active(true)
	if result == "defeat":
		Game.gold = Game.gold / 2
		Game.heal_party_full()
		field.wake_after_defeat()
	else:
		field.after_battle()
		await Fade.fade_in()
