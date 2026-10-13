class_name LevelUpScreen
extends CanvasLayer
## LevelUpScreen: the in-run draft-within-a-run. Step 1: pick WHICH character
## levels. Step 2: pick 1 of 3 upgrades for them. Pauses the sim while open.

var panel_box: VBoxContainer
var title_label: Label
var options_box: VBoxContainer
var pending_char_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	visible = false


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 440)
	center.add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_box.add_theme_constant_override("separation", 10)
	panel.add_child(panel_box)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	panel_box.add_child(title_label)
	options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 8)
	panel_box.add_child(options_box)


func show_for() -> void:
	Game.set_tactical_pause(true)
	pending_char_id = ""
	_show_character_pick()
	visible = true


func _clear_options() -> void:
	for c in options_box.get_children():
		c.queue_free()


func _show_character_pick() -> void:
	title_label.text = "LEVEL UP — choose who levels"
	_clear_options()
	for entry in Game.squad:
		if not bool(entry.get("alive", true)):
			continue
		var cid := String(entry.get("char_id"))
		var frac: float = float(entry.get("hp", 1.0)) / maxf(1.0, float(entry.get("max_hp", 1.0)))
		var b := Button.new()
		b.text = "%s (%s) — Lv %d → %d · HP %d%%" % [String(entry.get("name", "")), String(entry.get("class_id", "")).capitalize(), int(entry.get("level", 1)), int(entry.get("level", 1)) + 1, int(frac * 100.0)]
		b.custom_minimum_size = Vector2(560, 44)
		b.pressed.connect(_on_character_picked.bind(cid))
		options_box.add_child(b)


func _on_character_picked(char_id: String) -> void:
	pending_char_id = char_id
	_show_upgrade_pick()


func _member_node(char_id: String) -> SquadMember:
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m != null and String(m.member.get("char_id", "")) == char_id:
			return m
	return null


func _class_def(class_id: String) -> Dictionary:
	var path := "res://data/classes/%s.json" % class_id
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _show_upgrade_pick() -> void:
	var node := _member_node(pending_char_id)
	if node == null:
		_finish()
		return
	var entry: Dictionary = node.get("member")
	title_label.text = "%s — choose an upgrade" % String(entry.get("name", "")).capitalize()
	_clear_options()
	var upgrades := _gen_upgrades(node)
	for u in upgrades:
		var b := Button.new()
		b.text = "%s\n%s" % [String(u.get("title", "")), String(u.get("desc", ""))]
		b.custom_minimum_size = Vector2(560, 64)
		b.pressed.connect(_on_upgrade_picked.bind(u))
		options_box.add_child(b)


func _gen_upgrades(node: SquadMember) -> Array:
	var entry: Dictionary = node.member
	var class_def := _class_def(String(entry.get("class_id", "")))
	var new_level := int(entry.get("level", 1)) + 1
	var owned := {}
	for a in entry.get("abilities", []):
		owned[String(a.get("id", ""))] = int(a.get("rank", 1))
	var options: Array = []
	# New abilities whose unlock level we've reached.
	for ab in class_def.get("abilities", []):
		var aid := String(ab.get("id", ""))
		if int(ab.get("unlock_level", 99)) <= new_level and not owned.has(aid):
			options.append({
				"kind": "ability", "ability_id": aid, "ability_def": ab,
				"title": "New ability: %s" % String(ab.get("name", aid)),
				"desc": String(ab.get("description", "")),
			})
	# Rank up owned abilities (max rank 3).
	for a in entry.get("abilities", []):
		var aid := String(a.get("id", ""))
		if int(a.get("rank", 1)) < 3:
			var ranks: Array = []
			for ab in class_def.get("abilities", []):
				if String(ab.get("id", "")) == aid:
					ranks = ab.get("ranks", [])
			var desc := ""
			if ranks.size() > int(a.get("rank", 1)):
				desc = String(ranks[int(a.get("rank", 1))])
			options.append({
				"kind": "ability", "ability_id": aid, "ability_def": {},
				"title": "%s — Rank %d" % [String(a.get("name", aid)), int(a.get("rank", 1)) + 1],
				"desc": desc,
			})
	# Stat boosts.
	var stats := [
		{"stat": "max_hp_mult", "value": 0.15, "title": "+15% Max HP", "desc": "Bigger health pool, and heals the gained amount."},
		{"stat": "attack_power", "value": 0.12, "title": "+12% Attack Power", "desc": "All damage up."},
		{"stat": "attack_speed", "value": 0.10, "title": "+10% Attack Speed", "desc": "Basic attacks come out faster."},
		{"stat": "move_speed", "value": 0.10, "title": "+10% Move Speed", "desc": "Reposition faster, dodge better."},
		{"stat": "crit", "value": 0.05, "title": "+5% Crit Chance", "desc": "Crits deal double damage."},
	]
	for s in stats:
		var u: Dictionary = (s as Dictionary).duplicate()
		u["kind"] = "stat"
		options.append(u)
	options.shuffle()
	return options.slice(0, 3)


func _on_upgrade_picked(upgrade: Dictionary) -> void:
	var node := _member_node(pending_char_id)
	if node != null:
		node.apply_upgrade(upgrade)
	Game.apply_level_up(pending_char_id, String(upgrade.get("ability_id", upgrade.get("stat", ""))))
	_finish()


func _finish() -> void:
	visible = false
	Game.set_tactical_pause(false)
