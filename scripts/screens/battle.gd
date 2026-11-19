class_name Battle
extends CanvasLayer
## Rundenbasierter Kampf in Seitenansicht. Gegner links, Gruppe rechts.
## Ergebnis über das Signal finished: "win", "escaped", "fled" (Gegner geflohen) oder "defeat".

signal finished(result: String)

var enemy_ids: Array
var bg: Dictionary
var foes: Array = []      # [{name, level, hp, max_hp, atk, def, agi, xp, gold, node}]
var heroes: Array = []    # [{m (Game.party-Eintrag), node, home}]

var msg_label: Label
var status_label: Label
var menu: ChoiceMenu
var _skip := false
var _waiting := false
var _ended := false


func _init(ids: Array, background: String) -> void:
	enemy_ids = ids
	bg = Game.backgrounds.get(background, Game.backgrounds.get("wald", {}))
	layer = 10


func _ready() -> void:
	Touch.set_walk_mode(false)
	_build()
	_run()


# ---------- Aufbau ----------

func _build() -> void:
	var back := _Backdrop.new()
	back.colors = bg
	add_child(back)

	# Gegner, links aufgestellt
	var count := enemy_ids.size()
	var letters := "ABCDEFGH"
	var name_count: Dictionary = {}
	for id in enemy_ids:
		name_count[id] = int(name_count.get(id, 0)) + 1
	var seen: Dictionary = {}
	for i in count:
		var id: String = enemy_ids[i]
		var e: Dictionary = Game.enemies[id]
		var nm: String = e["name"]
		if int(name_count[id]) > 1:
			nm += " " + letters[int(seen.get(id, 0))]
			seen[id] = int(seen.get(id, 0)) + 1
		var node := _EnemySprite.new()
		node.data = e
		node.position = Vector2(70 + (i % 2) * 44 + (i / 2) * 20, 72 + (i % 2) * 34 - (16 if count == 1 else 0))
		add_child(node)
		foes.append({"name": nm, "level": int(e["level"]), "hp": int(e["hp"]), "max_hp": int(e["hp"]),
			"atk": int(e["atk"]), "def": int(e["def"]), "agi": int(e["agi"]),
			"xp": int(e["xp"]), "gold": int(e["gold"]), "node": node})

	# Gruppe, rechts aufgestellt
	for i in Game.party.size():
		var m: Dictionary = Game.party[i]
		var a := Avatar.new()
		a.body_color = Game.color(Game.heroes[m["id"]].get("color", "#3a6fd8"))
		a.facing = Vector2i.LEFT
		a.scale = Vector2(2, 2)
		var home := Vector2(300 + i * 8, 56 + i * 26)
		a.position = home
		if int(m["hp"]) <= 0:
			a.modulate = Color(1, 0.4, 0.4, 0.6)
			a.rotation = -PI / 2
		add_child(a)
		heroes.append({"m": m, "node": a, "home": home})

	var top := UiTheme.panel(Rect2(4, 4, 376, 22))
	msg_label = UiTheme.label()
	top.add_child(msg_label)
	add_child(top)

	var status := UiTheme.panel(Rect2(152, 148, 228, 64))
	status_label = UiTheme.label()
	status.add_child(status_label)
	add_child(status)

	menu = ChoiceMenu.new()
	add_child(menu)
	_update_status()


func _update_status() -> void:
	var lines: Array = []
	for h in heroes:
		var m: Dictionary = h["m"]
		var tag := "" if int(m["hp"]) > 0 else "  (bewusstlos)"
		lines.append("%s  St.%d   LP %d/%d   KP %d/%d%s" % [m["name"], m["level"], m["hp"], m["max_hp"], m["kp"], m["max_kp"], tag])
	status_label.text = "\n".join(lines)


# ---------- Ablauf ----------

func _run() -> void:
	await get_tree().process_frame
	var names: Array = []
	for f in foes:
		names.append(f["name"])
	await msg("%s %s auf!" % [", ".join(names), "tauchen" if foes.size() > 1 else "taucht"])

	# Fluchtregel: Ist die Gruppe weit überlegen, rennen die Gegner weg.
	var max_level := 0
	for f in foes:
		max_level = maxi(max_level, int(f["level"]))
	if Game.average_level() - max_level >= float(Game.config.get("flee_level_diff", 10)):
		var t := create_tween().set_parallel()
		for f in foes:
			t.tween_property(f["node"], "position:x", -60.0, 0.6)
		await msg("Die Gegner spüren eure Stärke und ergreifen die Flucht!")
		_end("fled")
		return

	while not _ended:
		var plan: Array = []
		var escaped_attempt := false
		for h in _alive_heroes():
			var act: Dictionary = await _choose(h)
			if act.get("type", "") == "flee":
				escaped_attempt = true
				break
			plan.append(act)
		if escaped_attempt:
			if await _try_flee():
				return
			plan.clear()
		for f in _alive_foes():
			plan.append({"type": "enemy", "actor": f})
		for a in plan:
			a["speed"] = float(_agi(a)) * randf_range(0.75, 1.25)
		plan.sort_custom(func(x, y): return x["speed"] > y["speed"])
		for h in heroes:
			h["defending"] = false
		for a in plan:
			if a.get("type", "") == "defend":
				a["actor"]["defending"] = true
		for a in plan:
			if _ended:
				return
			if not _actor_alive(a):
				continue
			await _execute(a)
			_update_status()
			if _alive_foes().is_empty():
				await _victory()
				return
			if _alive_heroes().is_empty():
				await msg("Die Gruppe ist besiegt...")
				_end("defeat")
				return


func _agi(a: Dictionary) -> int:
	if a["type"] == "enemy":
		return int(a["actor"]["agi"])
	return int(a["actor"]["m"]["agi"])


func _actor_alive(a: Dictionary) -> bool:
	if a["type"] == "enemy":
		return int(a["actor"]["hp"]) > 0
	return int(a["actor"]["m"]["hp"]) > 0


func _alive_foes() -> Array:
	return foes.filter(func(f): return int(f["hp"]) > 0)


func _alive_heroes() -> Array:
	return heroes.filter(func(h): return int(h["m"]["hp"]) > 0)


# ---------- Befehle wählen ----------

func _choose(h: Dictionary) -> Dictionary:
	var m: Dictionary = h["m"]
	while true:
		msg_label.text = "Was tut %s?" % m["name"]
		menu.open(["Angreifen", "Fähigkeit", "Gegenstand", "Verteidigen", "Fliehen"], false, 2)
		menu.place_bottom_left(4, 212)
		var c: int = await menu.chosen
		menu.close()
		match c:
			0:
				var t := await _pick_foe()
				if not t.is_empty():
					return {"type": "attack", "actor": h, "target": t}
			1:
				var skill_ids: Array = Game.member_skills(m)
				var opts: Array = []
				for sid in skill_ids:
					var sk: Dictionary = Game.skills[sid]
					var warn := "!" if int(m["kp"]) < int(sk["kp"]) else ""
					opts.append("%s %d KP%s" % [sk["name"], int(sk["kp"]), warn])
				menu.open(opts, true)
				menu.place_bottom_left(4, 212)
				msg_label.text = "Welche Fähigkeit? (! = Überanstrengung, kostet LP)"
				var s: int = await menu.chosen
				menu.close()
				if s < 0:
					continue
				var sid: String = skill_ids[s]
				if Game.skills[sid]["target"] == "enemy":
					var t := await _pick_foe()
					if not t.is_empty():
						return {"type": "skill", "actor": h, "skill": sid, "target": t}
				else:
					var t := await _pick_hero()
					if not t.is_empty():
						return {"type": "skill", "actor": h, "skill": sid, "target": t}
			2:
				var ids: Array = Game.inventory.keys()
				if ids.is_empty():
					await msg("Keine Gegenstände.")
					continue
				var opts: Array = []
				for id in ids:
					opts.append("%s ×%d" % [Game.items[id]["name"], int(Game.inventory[id])])
				menu.open(opts, true)
				menu.place_bottom_left(4, 212)
				var s: int = await menu.chosen
				menu.close()
				if s < 0:
					continue
				var t := await _pick_hero()
				if not t.is_empty():
					return {"type": "item", "actor": h, "item": ids[s], "target": t}
			3:
				return {"type": "defend", "actor": h}
			4:
				return {"type": "flee", "actor": h}
	return {}


func _pick_foe() -> Dictionary:
	var alive := _alive_foes()
	if alive.size() == 1:
		return alive[0]
	var names: Array = []
	for f in alive:
		names.append(f["name"])
	msg_label.text = "Welchen Gegner?"
	menu.open(names, true)
	menu.place_bottom_left(4, 212)
	var i: int = await menu.chosen
	menu.close()
	return {} if i < 0 else alive[i]


func _pick_hero() -> Dictionary:
	if heroes.size() == 1:
		return heroes[0]
	var names: Array = []
	for h in heroes:
		names.append(h["m"]["name"])
	msg_label.text = "Für wen?"
	menu.open(names, true)
	menu.place_bottom_left(4, 212)
	var i: int = await menu.chosen
	menu.close()
	return {} if i < 0 else heroes[i]


# ---------- Aktionen ausführen ----------

func _execute(a: Dictionary) -> void:
	match a["type"]:
		"attack":
			var h: Dictionary = a["actor"]
			var t: Dictionary = a["target"]
			if int(t["hp"]) <= 0:
				var alive := _alive_foes()
				if alive.is_empty():
					return
				t = alive[0]
			await _lunge(h["node"], -18)
			await msg("%s greift an!" % h["m"]["name"])
			await _hit_foe(t, _damage(int(h["m"]["atk"]), int(t["def"])))
		"skill":
			await _use_skill(a)
		"item":
			var h: Dictionary = a["actor"]
			var t: Dictionary = a["target"]
			if not Game.inventory.has(a["item"]):
				await msg("%s hat nichts mehr davon." % h["m"]["name"])
				return
			await msg("%s benutzt %s." % [h["m"]["name"], Game.items[a["item"]]["name"]])
			await msg(Game.use_item(a["item"], t["m"]))
		"defend":
			await msg("%s geht in Deckung." % a["actor"]["m"]["name"])
		"enemy":
			var f: Dictionary = a["actor"]
			var alive := _alive_heroes()
			if alive.is_empty():
				return
			var t: Dictionary = alive[randi() % alive.size()]
			await _lunge(f["node"], 18)
			await msg("%s greift %s an!" % [f["name"], t["m"]["name"]])
			var dmg := _damage(int(f["atk"]), int(t["m"]["def"]))
			if dmg > 0 and bool(t.get("defending", false)):
				dmg = maxi(1, dmg / 2)
			await _hit_hero(t, dmg)


func _use_skill(a: Dictionary) -> void:
	var h: Dictionary = a["actor"]
	var m: Dictionary = h["m"]
	var sk: Dictionary = Game.skills[a["skill"]]
	var cost := int(sk["kp"])
	await msg("%s setzt %s ein!" % [m["name"], sk["name"]])
	if int(m["kp"]) >= cost:
		m["kp"] = int(m["kp"]) - cost
	else:
		var missing := cost - int(m["kp"])
		m["kp"] = 0
		var loss := missing * int(Game.config.get("overcast_hp_per_kp", 3))
		m["hp"] = maxi(0, int(m["hp"]) - loss)
		_update_status()
		await msg("Überanstrengung! %s verliert %d LP." % [m["name"], loss])
		if int(m["hp"]) <= 0:
			_knock_out(h)
			await msg("%s bricht zusammen." % m["name"])
			return
	match String(sk["effect"]):
		"heal":
			var t: Dictionary = a["target"]
			if int(t["m"]["hp"]) <= 0:
				await msg("%s ist bewusstlos. Kräuter allein helfen hier nicht." % t["m"]["name"])
				return
			var amount := int(sk.get("power", 10)) + int(m["mag"]) / 2
			var herb: String = sk.get("herb", "")
			if herb != "" and Game.remove_item(herb):
				amount += int(sk.get("herb_bonus", 0))
				await msg("Ein %s verstärkt die Heilung." % Game.items[herb]["name"])
			var before := int(t["m"]["hp"])
			t["m"]["hp"] = mini(int(t["m"]["max_hp"]), before + amount)
			_popup(t["node"].position + Vector2(16, 0), str(int(t["m"]["hp"]) - before), Color("#7dff8a"))
			_update_status()
			await msg("%s erhält %d LP zurück." % [t["m"]["name"], int(t["m"]["hp"]) - before])
		"damage":
			var t: Dictionary = a["target"]
			if int(t["hp"]) <= 0:
				var alive := _alive_foes()
				if alive.is_empty():
					return
				t = alive[0]
			await _lunge(h["node"], -24)
			var dmg := int(_damage(int(m["atk"]), int(t["def"])) * float(sk.get("multiplier", 1.0)))
			await _hit_foe(t, maxi(dmg, 1))


func _damage(atk: int, def: int) -> int:
	if randf() < 0.05:
		return 0
	var base := float(atk) - float(def) / 2.0
	return maxi(1, int(round(base * randf_range(0.85, 1.15))))


func _hit_foe(f: Dictionary, dmg: int) -> void:
	if dmg <= 0:
		await msg("Daneben!")
		return
	f["hp"] = maxi(0, int(f["hp"]) - dmg)
	var node: Node2D = f["node"]
	_blink(node)
	_popup(node.position + Vector2(0, -24), str(dmg), Color.WHITE)
	await msg("%s erleidet %d Schaden." % [f["name"], dmg])
	if int(f["hp"]) <= 0:
		create_tween().tween_property(node, "modulate:a", 0.0, 0.35)
		await msg("%s ist besiegt!" % f["name"])


func _hit_hero(h: Dictionary, dmg: int) -> void:
	if dmg <= 0:
		await msg("%s weicht aus!" % h["m"]["name"])
		return
	var m: Dictionary = h["m"]
	m["hp"] = maxi(0, int(m["hp"]) - dmg)
	_blink(h["node"])
	_shake()
	_popup(h["node"].position + Vector2(16, 0), str(dmg), Color("#ff8a7a"))
	_update_status()
	await msg("%s erleidet %d Schaden." % [m["name"], dmg])
	if int(m["hp"]) <= 0:
		_knock_out(h)
		await msg("%s bricht zusammen!" % m["name"])


func _knock_out(h: Dictionary) -> void:
	var node: Node2D = h["node"]
	node.modulate = Color(1, 0.4, 0.4, 0.6)
	node.rotation = -PI / 2
	_update_status()


func _try_flee() -> bool:
	var party_agi := 0.0
	for h in _alive_heroes():
		party_agi += int(h["m"]["agi"])
	party_agi /= maxf(1.0, float(_alive_heroes().size()))
	var foe_agi := 0.0
	for f in _alive_foes():
		foe_agi += int(f["agi"])
	foe_agi /= maxf(1.0, float(_alive_foes().size()))
	var chance := clampf(0.5 + (party_agi - foe_agi) * 0.05, 0.2, 0.9)
	await msg("Ihr versucht zu fliehen...")
	if randf() < chance:
		await msg("Ihr seid entkommen!")
		_end("escaped")
		return true
	await msg("Die Flucht misslingt!")
	return false


func _victory() -> void:
	var xp := 0
	var gold := 0
	for f in foes:
		xp += int(f["xp"])
		gold += int(f["gold"])
	Game.gold += gold
	await msg("Sieg! %d Erfahrung und %d Gold." % [xp, gold])
	for h in _alive_heroes():
		for line in Game.give_xp(h["m"], xp):
			_update_status()
			await msg(line)
	_end("win")


func _end(result: String) -> void:
	if _ended:
		return
	_ended = true
	finished.emit(result)


# ---------- Darstellung ----------

func msg(text: String) -> void:
	msg_label.text = text
	_skip = false
	_waiting = true
	var t := get_tree().create_timer(float(Game.config.get("battle_message_time", 0.9)))
	while t.time_left > 0.0 and not _skip:
		await get_tree().process_frame
	_waiting = false


func _unhandled_input(event: InputEvent) -> void:
	if _waiting and (event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed)):
		get_viewport().set_input_as_handled()
		_skip = true


func _lunge(node: Node2D, dx: float) -> void:
	var x := node.position.x
	var t := create_tween()
	t.tween_property(node, "position:x", x + dx, 0.1)
	t.tween_property(node, "position:x", x, 0.12)
	await t.finished


func _blink(node: Node2D) -> void:
	var base := node.modulate
	var t := create_tween()
	for i in 3:
		t.tween_property(node, "modulate:a", 0.2, 0.05)
		t.tween_property(node, "modulate:a", base.a, 0.05)


func _shake() -> void:
	var t := create_tween()
	for i in 4:
		t.tween_property(self, "offset", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	t.tween_property(self, "offset", Vector2.ZERO, 0.03)


func _popup(at: Vector2, text: String, col: Color) -> void:
	var l := UiTheme.label(text, 12)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.position = at
	add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", at.y - 14, 0.5)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.3)
	t.tween_callback(l.queue_free)


class _Backdrop extends Node2D:
	var colors: Dictionary = {}

	func _draw() -> void:
		var sky := Color.from_string(colors.get("sky", "#8fb8d8"), Color.SKY_BLUE)
		var far := Color.from_string(colors.get("far", "#3e6e46"), Color.DARK_GREEN)
		var ground := Color.from_string(colors.get("ground", "#4f7f36"), Color.DARK_OLIVE_GREEN)
		var line := Color.from_string(colors.get("line", "#2c4c24"), Color.BLACK)
		draw_rect(Rect2(0, 0, 384, 216), sky)
		for i in 14:
			var x := i * 30.0 - 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 70), Vector2(x + 16, 30 + (i * 7) % 18), Vector2(x + 32, 70)]), far)
		draw_rect(Rect2(0, 68, 384, 148), ground)
		for i in 8:
			draw_line(Vector2(0, 80 + i * 10), Vector2(384, 80 + i * 10), line.lerp(ground, 0.6))


class _EnemySprite extends Node2D:
	var data: Dictionary = {}

	func _draw() -> void:
		var c := Color.from_string(data.get("color", "#888888"), Color.GRAY)
		var s: Array = data.get("size", [24, 24])
		var w := float(s[0])
		var h := float(s[1])
		var dark := c.darkened(0.45)
		draw_rect(Rect2(-w / 2 - 2, h / 2 - 2, w + 4, 4), Color(0, 0, 0, 0.25))
		if data.get("shape", "beast") == "humanoid":
			draw_rect(Rect2(-w / 2, -h / 2 + 8, w, h - 8), dark)
			draw_rect(Rect2(-w / 2 + 1, -h / 2 + 9, w - 2, h - 10), c)
			draw_circle(Vector2(0, -h / 2 + 5), 6, dark)
			draw_circle(Vector2(0, -h / 2 + 5), 5, Color("#d8b090"))
			draw_rect(Rect2(-5, -h / 2, 10, 4), dark)
			draw_rect(Rect2(2, -h / 2 + 4, 2, 2), Color.BLACK)
			draw_line(Vector2(w / 2, -2), Vector2(w / 2 + 8, -12), Color("#c0c0c8"), 2)
		else:
			draw_rect(Rect2(-w / 2, -h / 2 + 4, w, h - 6), dark)
			draw_rect(Rect2(-w / 2 + 1, -h / 2 + 5, w - 2, h - 8), c)
			draw_circle(Vector2(w / 2, -h / 2 + 6), h / 3, dark)
			draw_circle(Vector2(w / 2, -h / 2 + 6), h / 3 - 1, c)
			draw_rect(Rect2(w / 2 + 1, -h / 2 + 3, 2, 2), Color.YELLOW)
			for i in 4:
				draw_rect(Rect2(-w / 2 + 2 + i * (w - 6) / 3, h / 2 - 3, 3, 5), dark)
