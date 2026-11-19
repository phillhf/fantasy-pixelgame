class_name Field
extends Node2D
## Karte von oben: Laufen, Reden, Menü, Zufallskämpfe, Ortswechsel.

signal encounter(enemy_ids: Array, background: String)

const TILE := 16

var map: Dictionary = {}
var rows: Array = []
var map_size := Vector2i.ZERO
var player: Avatar
var camera: Camera2D
var npcs: Array = []  # [{data, node, pos}]
var moving := false
var busy := false:
	set(v):
		busy = v
		Touch.set_walk_mode(not v and visible)
var steps_since_battle := 0

var ui: CanvasLayer
var dialog: DialogBox
var menu: ChoiceMenu
var info: PanelContainer
var info_label: Label
var _wander_timer := 0.0


func _ready() -> void:
	player = Avatar.new()
	player.z_index = 2
	add_child(player)
	camera = Camera2D.new()
	camera.position = Vector2(8, 8)
	player.add_child(camera)
	camera.make_current()

	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	dialog = DialogBox.new()
	ui.add_child(dialog)
	menu = ChoiceMenu.new()
	menu.position = Vector2(8, 8)
	ui.add_child(menu)
	info = UiTheme.panel(Rect2(282, 8, 94, 40))
	info_label = UiTheme.label()
	info.add_child(info_label)
	info.hide()
	ui.add_child(info)


## Betritt eine Karte. intro = Einleitungstext nach neuem Spiel.
func enter(id: String, at: Vector2i, intro: bool = false) -> void:
	_load(id, at)
	busy = false
	if intro:
		busy = true
		await get_tree().create_timer(0.4).timeout
		await dialog.play(Game.text("intro"))
		busy = false


func set_active(on: bool) -> void:
	visible = on
	ui.visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		camera.make_current()
	Touch.set_walk_mode(on and not busy)


func _load(id: String, at: Vector2i) -> void:
	map = Game.load_map(id)
	rows = map.get("rows", [])
	map_size = Vector2i(String(rows[0]).length(), rows.size()) if rows.size() > 0 else Vector2i.ONE
	Game.map_id = id
	Game.pos = at
	for n in npcs:
		n["node"].queue_free()
	npcs.clear()
	for d in map.get("npcs", []):
		var a := Avatar.new()
		a.kind = d.get("kind", "person")
		if a.kind != "shrine" and a.kind != "sign":
			a.kind = "person"
		a.body_color = Game.color(d.get("color", "#a0a0a0"))
		var p := Vector2i(int(d["at"][0]), int(d["at"][1]))
		a.position = Vector2(p * TILE)
		a.z_index = 1
		add_child(a)
		npcs.append({"data": d, "node": a, "pos": p})
	player.position = Vector2(at * TILE)
	player.facing = Game.facing
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size.x * TILE
	camera.limit_bottom = map_size.y * TILE
	camera.reset_smoothing()
	steps_since_battle = 0
	queue_redraw()


# ---------- Zeichnen der Karte (Platzhalter) ----------

func tile_at(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.y >= rows.size():
		return ""
	var r: String = rows[p.y]
	if p.x >= r.length():
		return ""
	return r[p.x]


func _draw() -> void:
	for y in rows.size():
		var r: String = rows[y]
		for x in r.length():
			_draw_tile(Vector2(x * TILE, y * TILE), r[x])


func _draw_tile(o: Vector2, ch: String) -> void:
	var t: Dictionary = Game.tiles.get(ch, {"color": "#ff00ff", "shape": "plain"})
	var base := Game.color(t.get("color", "#ff00ff"))
	var det := Game.color(t.get("detail", "#000000"))
	draw_rect(Rect2(o, Vector2(TILE, TILE)), base)
	match t.get("shape", "plain"):
		"tree":
			draw_rect(Rect2(o + Vector2(7, 10), Vector2(2, 5)), Color("#5a3a20"))
			draw_circle(o + Vector2(8, 7), 6, det)
			draw_circle(o + Vector2(6, 6), 2, det.lightened(0.2))
		"mountain":
			draw_colored_polygon(PackedVector2Array([o + Vector2(1, 15), o + Vector2(8, 2), o + Vector2(15, 15)]), det)
			draw_colored_polygon(PackedVector2Array([o + Vector2(6, 6), o + Vector2(8, 2), o + Vector2(10, 6)]), Color.WHITE)
		"water":
			draw_line(o + Vector2(2, 5), o + Vector2(7, 5), det)
			draw_line(o + Vector2(9, 11), o + Vector2(14, 11), det)
		"bridge":
			for i in 4:
				draw_line(o + Vector2(0, 2 + i * 4), o + Vector2(16, 2 + i * 4), det)
		"village":
			draw_rect(Rect2(o + Vector2(2, 7), Vector2(5, 6)), Color("#d8c8a0"))
			draw_rect(Rect2(o + Vector2(9, 5), Vector2(5, 8)), Color("#d8c8a0"))
			draw_colored_polygon(PackedVector2Array([o + Vector2(1, 7), o + Vector2(4.5, 3), o + Vector2(8, 7)]), det)
			draw_colored_polygon(PackedVector2Array([o + Vector2(8, 5), o + Vector2(11.5, 1), o + Vector2(15, 5)]), det)
		"fence":
			draw_rect(Rect2(o + Vector2(0, 6), Vector2(16, 2)), det)
			draw_rect(Rect2(o + Vector2(0, 11), Vector2(16, 2)), det)
		"roof":
			for i in 4:
				draw_line(o + Vector2(0, 3 + i * 4), o + Vector2(16, 3 + i * 4), det)
		"door":
			draw_rect(Rect2(o + Vector2(3, 2), Vector2(10, 14)), det.darkened(0.6))
			draw_circle(o + Vector2(11, 9), 1, det)


# ---------- Bewegung ----------

func _process(delta: float) -> void:
	_wander(delta)
	if busy or moving:
		return
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_up"):
		dir = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		dir = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		dir = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		dir = Vector2i.RIGHT
	if dir != Vector2i.ZERO:
		_try_move(dir)


func walkable(p: Vector2i) -> bool:
	var ch := tile_at(p)
	if ch == "":
		return false
	if not bool(Game.tiles.get(ch, {}).get("walk", false)):
		return false
	return npc_at(p).is_empty() and p != Game.pos


func npc_at(p: Vector2i) -> Dictionary:
	for n in npcs:
		if n["pos"] == p:
			return n
	return {}


func _try_move(dir: Vector2i) -> void:
	Game.facing = dir
	player.facing = dir
	var target := Game.pos + dir
	if not walkable(target):
		return
	moving = true
	Game.pos = target
	player.step = not player.step
	var t := create_tween()
	t.tween_property(player, "position", Vector2(target * TILE), float(Game.config.get("move_time", 0.14)))
	await t.finished
	moving = false
	_on_step(target)


func _on_step(p: Vector2i) -> void:
	for w in map.get("warps", []):
		if int(w["at"][0]) == p.x and int(w["at"][1]) == p.y:
			_warp(w)
			return
	steps_since_battle += 1
	var t: Dictionary = Game.tiles.get(tile_at(p), {})
	var enc: Dictionary = map.get("encounters", {})
	var rate := float(enc.get("rate", 0))
	if rate <= 0.0 or not bool(t.get("enc", false)) or steps_since_battle < 4:
		return
	var chance := float(t.get("enc_mult", 1.0)) / rate
	if randf() < chance:
		_start_encounter(enc.get("groups", []))


func _start_encounter(groups: Array) -> void:
	if groups.is_empty():
		return
	var total := 0
	for g in groups:
		total += int(g.get("weight", 1))
	var roll := randi() % maxi(1, total)
	for g in groups:
		roll -= int(g.get("weight", 1))
		if roll < 0:
			steps_since_battle = 0
			busy = true
			await Fade.flash()
			encounter.emit(g["enemies"], String(map.get("battle_bg", "wald")))
			return


## Wird nach dem Kampf vom Hauptskript aufgerufen.
func after_battle() -> void:
	busy = false


func _warp(w: Dictionary) -> void:
	busy = true
	await Fade.fade_out()
	var f: String = w.get("facing", "down")
	Game.facing = {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}.get(f, Vector2i.DOWN)
	_load(String(w["to"]), Vector2i(int(w["pos"][0]), int(w["pos"][1])))
	await Fade.fade_in()
	busy = false


func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer > 0.0:
		return
	_wander_timer = randf_range(1.2, 2.6)
	for n in npcs:
		if not bool(n["data"].get("wander", false)) or busy:
			continue
		var dirs := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		var d: Vector2i = dirs[randi() % 4]
		var target: Vector2i = n["pos"] + d
		var node: Avatar = n["node"]
		node.facing = d
		if walkable(target) and target != Game.pos + Game.facing and not _is_warp(target):
			n["pos"] = target
			create_tween().tween_property(node, "position", Vector2(target * TILE), 0.25)


func _is_warp(p: Vector2i) -> bool:
	for w in map.get("warps", []):
		if int(w["at"][0]) == p.x and int(w["at"][1]) == p.y:
			return true
	return false


# ---------- Eingaben: Reden und Menü ----------

func _unhandled_input(event: InputEvent) -> void:
	if busy or moving:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_interact()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_field_menu()


func _interact() -> void:
	var n := npc_at(Game.pos + Game.facing)
	if n.is_empty():
		return
	busy = true
	var d: Dictionary = n["data"]
	var node: Avatar = n["node"]
	if node.kind == "person":
		node.facing = -Game.facing
	var speaker: String = d.get("name", "") if node.kind == "person" else ""
	await dialog.play(Game.text(String(d.get("dialog", ""))), speaker)
	match String(d.get("kind", "talk")):
		"shrine":
			await _ask_save()
		"inn":
			await _inn(d)
		"shop":
			await _shop(d)
	busy = false


func _ask_save() -> void:
	await dialog.play(["Möchtest du deinen Fortschritt festhalten?"])
	menu.open(["Speichern", "Nicht jetzt"], false)
	var i: int = await menu.chosen
	menu.close()
	if i == 0:
		var ok := Game.save_game()
		await dialog.play(["Fortschritt gespeichert." if ok else "Speichern fehlgeschlagen!"])


func _inn(d: Dictionary) -> void:
	var price := int(d.get("price", 5))
	_show_gold()
	menu.open(["Übernachten (%d G)" % price, "Speichern", "Nichts"], false)
	var i: int = await menu.chosen
	menu.close()
	match i:
		0:
			if Game.gold < price:
				await dialog.play(["Das reicht leider nicht."], d.get("name", ""))
			else:
				Game.gold -= price
				_show_gold()
				await Fade.fade_out(0.5)
				Game.heal_party_full()
				await get_tree().create_timer(0.4).timeout
				await Fade.fade_in(0.5)
				await dialog.play(["Gut geschlafen? Kraft und Gesundheit sind zurück."], d.get("name", ""))
				await _ask_save()
		1:
			await _ask_save()
	info.hide()


func _shop(d: Dictionary) -> void:
	var stock: Array = d.get("shop", [])
	var sel := 0
	while true:
		_show_gold()
		var opts: Array = []
		for id in stock:
			opts.append("%s  %d G" % [Game.items[id]["name"], int(Game.items[id]["price"])])
		menu.open(opts, true, 1, sel)
		var i: int = await menu.chosen
		menu.close()
		if i < 0:
			break
		sel = i
		var id: String = stock[i]
		var price := int(Game.items[id]["price"])
		if Game.gold < price:
			await dialog.play(["Dafür reicht dein Gold nicht."], d.get("name", ""))
		else:
			Game.gold -= price
			Game.add_item(id)
			await dialog.play(["%s gekauft. Du hast jetzt %d." % [Game.items[id]["name"], int(Game.inventory[id])]])
	info.hide()


func _show_gold() -> void:
	info_label.text = "Gold\n%d G" % Game.gold
	info.show()


func _field_menu() -> void:
	busy = true
	var sel := 0
	while true:
		_show_gold()
		menu.open(["Status", "Gegenstände", "Schließen"], true, 1, sel)
		var i: int = await menu.chosen
		menu.close()
		if i < 0 or i == 2:
			break
		sel = i
		if i == 0:
			await _status()
		elif i == 1:
			await _items_menu()
	info.hide()
	busy = false


func _status() -> void:
	var lines: Array = []
	for m in Game.party:
		lines.append("%s – %s  Stufe %d\nLP %d/%d   KP %d/%d   Erfahrung %d (nächste Stufe: %d)\nStärke %d  Abwehr %d  Geschick %d  Magie %d" % [
			m["name"], Game.heroes[m["id"]].get("title", ""), m["level"], m["hp"], m["max_hp"], m["kp"], m["max_kp"],
			m["xp"], Game.xp_for_level(int(m["level"]) + 1), m["atk"], m["def"], m["agi"], m["mag"]])
	await dialog.play(lines)


func _items_menu() -> void:
	var sel := 0
	while true:
		var ids: Array = Game.inventory.keys()
		if ids.is_empty():
			await dialog.play(["Du hast keine Gegenstände."])
			return
		var opts: Array = []
		for id in ids:
			opts.append("%s ×%d" % [Game.items[id]["name"], int(Game.inventory[id])])
		menu.open(opts, true, 1, mini(sel, ids.size() - 1))
		var i: int = await menu.chosen
		menu.close()
		if i < 0:
			return
		sel = i
		var target: Dictionary = Game.party[0]
		if Game.party.size() > 1:
			var names: Array = []
			for m in Game.party:
				names.append(m["name"])
			menu.open(names)
			var j: int = await menu.chosen
			menu.close()
			if j < 0:
				continue
			target = Game.party[j]
		await dialog.play([Game.use_item(ids[i], target)])


## Nach einer Niederlage im Gasthaus aufwachen.
func wake_after_defeat() -> void:
	busy = true
	var p: Array = Game.config.get("defeat_return_pos", [0, 0])
	Game.facing = Vector2i.UP
	_load(String(Game.config.get("defeat_return_map", "erlenfurt")), Vector2i(int(p[0]), int(p[1])))
	await Fade.fade_in(0.6)
	await dialog.play(Game.text("besiegt"))
	busy = false
