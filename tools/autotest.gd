extends Node
## Automatischer Durchlauf zum Testen. Start: godot --path . -- --autotest [--shots=ORDNER]
## Spielt Namenseingabe, Laufen, Ortswechsel, Kämpfe, Fluchtregel und Speichern/Laden durch.

var main: Node
var shots := ""
var errors: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots = a.substr(8)
	Game.config["battle_message_time"] = 0.02
	Game.config["move_time"] = 0.02
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("OK   " if cond else "FEHLER ") + what)
	if not cond:
		errors.append(what)


func frames(n: int = 5) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(name + ".png"))


## Klickt sich durch offene Textfenster und Menüs, bis cond() wahr ist.
func pump(cond: Callable, choice: int = 0, max_frames: int = 3000) -> void:
	for i in max_frames:
		if cond.call():
			return
		for d in _all(main, "DialogBox"):
			if d.is_open():
				d._on_advance()
		for m in _all(main, "ChoiceMenu"):
			if m._active:
				m._on_pressed(choice)
		await get_tree().process_frame
	check(false, "Zeitüberschreitung beim Warten")


func wait_battle() -> Battle:
	for i in 2000:
		var b := _all(main, "Battle")
		if not b.is_empty():
			return b[0]
		await get_tree().process_frame
	return null


func _all(n: Node, cls: String) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c.get_script() and c.get_script().get_global_name() == cls:
			out.append(c)
		out.append_array(_all(c, cls))
	return out


func _run() -> void:
	main = get_tree().current_scene
	await frames(10)
	await shot("01_titel")

	main._on_new_game()
	await frames(30)
	await shot("02_name")
	main._on_name_done("Testa")
	for i in 600:
		if main.field != null:
			break
		await get_tree().process_frame
	var field: Field = main.field
	check(field != null, "Karte geladen")
	await pump(func(): return not field.busy)
	await shot("03_welt")
	check(Game.hero_name() == "Testa", "Heldenname gesetzt")

	# Laufen
	var start := Game.pos
	field.steps_since_battle = -1000
	await field._try_move(Vector2i.LEFT)
	check(Game.pos == start + Vector2i.LEFT, "Laufen nach links")

	# Kampf (gewinnen)
	Game.party[0]["atk"] = 99
	field._start_encounter([{"enemies": ["wolf", "raeuber"], "weight": 1}])
	var battle: Battle = await wait_battle()
	check(battle != null, "Kampf gestartet")
	if battle:
		await frames(30)
		await shot("04_kampf")
		var res := [""]
		battle.finished.connect(func(r): res[0] = r)
		await pump(func(): return res[0] != "", 0)
		check(res[0] == "win", "Kampf gewonnen (Ergebnis: %s)" % res[0])
		check(int(Game.party[0]["xp"]) > 0, "Erfahrung erhalten")
	await frames(40)
	await pump(func(): return not field.busy)

	# Heilfähigkeit und Überanstrengung
	var hero: Dictionary = Game.party[0]
	hero["hp"] = 5
	hero["kp"] = 0
	hero["atk"] = 1
	var herbs := int(Game.inventory.get("heilkraut", 0))
	field._start_encounter([{"enemies": ["wolf"], "weight": 1}])
	battle = await wait_battle()
	var res2 := [""]
	battle.finished.connect(func(r): res2[0] = r)
	# Befehl 1 = Fähigkeit, dann Eintrag 0 = Kräuterheilung
	await pump(func(): return battle.menu._active, 0)
	battle.menu._on_pressed(1)
	await pump(func(): return battle.menu._active, 0)
	battle.menu._on_pressed(0)
	await frames(5)
	await pump(func(): return battle.menu._active or res2[0] != "", 0)
	check(int(Game.inventory.get("heilkraut", 0)) < herbs or res2[0] == "defeat", "Heilkraut bei Kräuterheilung verbraucht")
	hero["atk"] = 99
	await pump(func(): return res2[0] != "", 0)
	check(res2[0] in ["win", "defeat"], "Zweiter Kampf beendet (%s)" % res2[0])
	await frames(60)
	await pump(func(): return not field.busy)

	# Fluchtregel
	hero["level"] = 15
	field._start_encounter([{"enemies": ["wolf"], "weight": 1}])
	battle = await wait_battle()
	var res3 := [""]
	battle.finished.connect(func(r): res3[0] = r)
	await pump(func(): return res3[0] != "")
	check(res3[0] == "fled", "Gegner fliehen bei 10 Stufen Unterschied")
	hero["level"] = 2
	await frames(40)
	await pump(func(): return not field.busy)

	# Ortswechsel nach Erlenfurt
	await field._warp({"to": "erlenfurt", "pos": [12, 14], "facing": "up"})
	await frames(40)
	check(Game.map_id == "erlenfurt", "Ortswechsel nach Erlenfurt")
	await shot("05_erlenfurt")
	# Mit der Wirtin reden und übernachten
	Game.pos = Vector2i(21, 6)
	Game.facing = Vector2i.UP
	field.player.position = Vector2(Game.pos * Field.TILE)
	Game.gold = 50
	hero["hp"] = 1
	field._interact()
	await pump(func(): return not field.busy, 0)
	check(int(hero["hp"]) == int(hero["max_hp"]), "Gasthaus heilt")

	# Speichern und Laden
	check(Game.save_game(), "Speichern")
	var gold_saved := Game.gold
	Game.gold = 1
	check(Game.load_game() and Game.gold == gold_saved, "Laden stellt Gold wieder her")

	print("AUTOTEST " + ("BESTANDEN" if errors.is_empty() else "FEHLGESCHLAGEN: " + ", ".join(errors)))
	get_tree().quit(0 if errors.is_empty() else 1)
