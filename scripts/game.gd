extends Node
## Globaler Spielzustand: Daten aus /data, Gruppe, Inventar, Speichern und Laden.

const SAVE_VERSION := 1
const SAVE_PATH := "user://spielstand1.json"
const CHAPTER := 0  # 0 = Prototyp

var config: Dictionary
var tiles: Dictionary
var heroes: Dictionary
var skills: Dictionary
var items: Dictionary
var enemies: Dictionary
var dialogs: Dictionary
var backgrounds: Dictionary

var party: Array = []
var inventory: Dictionary = {}
var gold: int = 0
var map_id: String = ""
var pos: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var flags: Dictionary = {}


func _ready() -> void:
	_setup_input()
	config = load_json("res://data/config.json")
	tiles = load_json("res://data/tiles.json")
	heroes = load_json("res://data/heroes.json")
	skills = load_json("res://data/skills.json")
	items = load_json("res://data/items.json")
	enemies = load_json("res://data/enemies.json")
	dialogs = load_json("res://data/dialogs.json")
	backgrounds = load_json("res://data/battle_backgrounds.json")


func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Datei fehlt oder ist leer: " + path)
		return {}
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Fehler in JSON-Datei: " + path)
		return {}
	return data


func load_map(id: String) -> Dictionary:
	return load_json("res://data/maps/%s.json" % id)


# ---------- Eingabe ----------

func _setup_input() -> void:
	_add_key("ui_accept", KEY_Z)
	_add_key("ui_cancel", KEY_X)
	_add_key("ui_cancel", KEY_BACKSPACE)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)
	for pair in [["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN],
			["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT],
			["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)
	for pair in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0],
			["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var ev := InputEventJoypadMotion.new()
		ev.axis = pair[1]
		ev.axis_value = pair[2]
		if not InputMap.action_has_event(pair[0], ev):
			InputMap.action_add_event(pair[0], ev)


func _add_key(action: String, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


# ---------- Neues Spiel ----------

func new_game(hero_name: String) -> void:
	party = [make_member("held", int(config.get("start_level", 1)))]
	party[0]["name"] = hero_name
	inventory = {}
	var inv: Dictionary = config.get("start_inventory", {})
	for k in inv:
		inventory[k] = int(inv[k])
	gold = int(config.get("start_gold", 0))
	map_id = config.get("start_map", "welt")
	var p: Array = config.get("start_pos", [0, 0])
	pos = Vector2i(int(p[0]), int(p[1]))
	facing = Vector2i.LEFT
	flags = {}


func make_member(id: String, level: int) -> Dictionary:
	var m := {"id": id, "name": heroes[id].get("name", id), "level": level, "xp": xp_for_level(level)}
	_apply_stats(m)
	m["hp"] = m["max_hp"]
	m["kp"] = m["max_kp"]
	return m


func _apply_stats(m: Dictionary) -> void:
	var def: Dictionary = heroes[m["id"]]
	var lv: int = int(m["level"]) - 1
	var b: Dictionary = def["base"]
	var g: Dictionary = def["growth"]
	m["max_hp"] = int(b["hp"]) + int(g["hp"]) * lv
	m["max_kp"] = int(b["kp"]) + int(g["kp"]) * lv
	for s in ["atk", "def", "agi", "mag"]:
		m[s] = int(b[s]) + int(g[s]) * lv


func xp_for_level(level: int) -> int:
	return 12 * (level - 1) * (level - 1)


## Vergibt Erfahrung, gibt eine Liste von Meldungen zu Stufenaufstiegen zurück.
func give_xp(m: Dictionary, amount: int) -> Array:
	var msgs: Array = []
	m["xp"] = int(m["xp"]) + amount
	while int(m["xp"]) >= xp_for_level(int(m["level"]) + 1) and int(m["level"]) < 99:
		var old_hp: int = m["max_hp"]
		var old_kp: int = m["max_kp"]
		m["level"] = int(m["level"]) + 1
		_apply_stats(m)
		m["hp"] = int(m["hp"]) + int(m["max_hp"]) - old_hp
		m["kp"] = int(m["kp"]) + int(m["max_kp"]) - old_kp
		msgs.append("%s erreicht Stufe %d!" % [m["name"], m["level"]])
		for sk in heroes[m["id"]].get("skills", []):
			if int(sk["level"]) == int(m["level"]):
				msgs.append("%s lernt %s." % [m["name"], skills[sk["id"]]["name"]])
	return msgs


func member_skills(m: Dictionary) -> Array:
	var out: Array = []
	for sk in heroes[m["id"]].get("skills", []):
		if int(sk["level"]) <= int(m["level"]):
			out.append(sk["id"])
	return out


func hero_name() -> String:
	return party[0]["name"] if party.size() > 0 else "Held"


func text(id: String) -> Array:
	var lines: Array = []
	for l in dialogs.get(id, ["(Text fehlt: %s)" % id]):
		lines.append(String(l).replace("{held}", hero_name()))
	return lines


func average_level() -> float:
	var total := 0
	for m in party:
		total += int(m["level"])
	return float(total) / max(1, party.size())


# ---------- Inventar ----------

func add_item(id: String, count: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + count


func remove_item(id: String, count: int = 1) -> bool:
	var have := int(inventory.get(id, 0))
	if have < count:
		return false
	if have == count:
		inventory.erase(id)
	else:
		inventory[id] = have - count
	return true


## Wendet einen Gegenstand auf ein Mitglied an. Gibt die Meldung zurück.
func use_item(id: String, m: Dictionary) -> String:
	var it: Dictionary = items[id]
	if not remove_item(id):
		return "Nichts mehr da."
	var amount := int(it.get("amount", 0))
	match it.get("effect", ""):
		"heal_hp":
			var before := int(m["hp"])
			m["hp"] = min(int(m["max_hp"]), before + amount)
			return "%s erhält %d LP zurück." % [m["name"], int(m["hp"]) - before]
		"restore_kp":
			var before := int(m["kp"])
			m["kp"] = min(int(m["max_kp"]), before + amount)
			return "%s isst und erhält %d KP zurück." % [m["name"], int(m["kp"]) - before]
	return "Es passiert nichts."


func heal_party_full() -> void:
	for m in party:
		m["hp"] = m["max_hp"]
		m["kp"] = m["max_kp"]


# ---------- Speichern ----------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"chapter": CHAPTER,
		"party": party,
		"inventory": inventory,
		"gold": gold,
		"map": map_id,
		"pos": [pos.x, pos.y],
		"facing": [facing.x, facing.y],
		"flags": flags,
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Speichern fehlgeschlagen")
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	data = _migrate(data)
	party = []
	for m in data["party"]:
		var mm: Dictionary = m
		for k in ["level", "xp", "hp", "kp", "max_hp", "max_kp", "atk", "def", "agi", "mag"]:
			mm[k] = int(mm.get(k, 0))
		_apply_stats(mm)  # Werte aus aktuellen Daten neu berechnen
		party.append(mm)
	inventory = {}
	for k in data["inventory"]:
		inventory[k] = int(data["inventory"][k])
	gold = int(data["gold"])
	map_id = data["map"]
	pos = Vector2i(int(data["pos"][0]), int(data["pos"][1]))
	facing = Vector2i(int(data["facing"][0]), int(data["facing"][1]))
	flags = data.get("flags", {})
	return true


## Hebt alte Spielstände auf die aktuelle Version. Jede neue Version bekommt hier einen Schritt.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	# Beispiel für später:
	# if v < 2:
	#     data["neues_feld"] = standardwert
	#     v = 2
	data["version"] = v
	return data


static func color(hex: String) -> Color:
	return Color.from_string(hex, Color.MAGENTA)
