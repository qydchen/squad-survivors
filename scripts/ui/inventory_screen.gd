class_name InventoryScreen
extends CanvasLayer
## InventoryScreen: the in-run loot manager. Tab toggles it; THE GAME KEEPS
## RUNNING (risk/reward — sorting loot mid-swarm is a decision). Legendary
## pickups auto-pause via the loot toast instead.
##
## Left: squad members with their 3 gear slots. Right: the loot bag.
## Click a bag item to select it, then click a member's slot to equip.
## Click an equipped item to unequip it back to the bag.

var panel: PanelContainer
var members_box: VBoxContainer
var bag_box: VBoxContainer
var info_label: Label
var selected_item := ""  # loot_bag id, or ""
var open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 9
	visible = false
	_build()
	Game.loot_dropped.connect(_on_loot_dropped)


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 480)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "SQUAD INVENTORY  (Tab to close — the fight goes on)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(info_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Squad"
	lh.add_theme_font_size_override("font_size", 15)
	left.add_child(lh)
	members_box = VBoxContainer.new()
	members_box.add_theme_constant_override("separation", 8)
	members_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(members_box)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rh := Label.new()
	rh.text = "Loot bag"
	rh.add_theme_font_size_override("font_size", 15)
	right.add_child(rh)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	bag_box = VBoxContainer.new()
	bag_box.add_theme_constant_override("separation", 4)
	bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bag_box)


func toggle() -> void:
	open = not open
	visible = open
	if open:
		refresh()


func _on_loot_dropped(_item: Dictionary) -> void:
	if open:
		refresh()


func refresh() -> void:
	for c in members_box.get_children():
		c.queue_free()
	for c in bag_box.get_children():
		c.queue_free()
	# Members + slots.
	for entry in Game.squad:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		members_box.add_child(box)
		var hl := Label.new()
		hl.text = "%s (%s)  Lv%d" % [String(entry.get("name", "")), String(entry.get("class_id", "")).capitalize(), int(entry.get("level", 1))]
		hl.add_theme_font_size_override("font_size", 13)
		box.add_child(hl)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 4)
		box.add_child(slots)
		var gear: Dictionary = entry.get("gear", {})
		for slot in ["weapon", "armor", "trinket"]:
			var b := Button.new()
			var item: Dictionary = gear.get(slot, {})
			if item.is_empty():
				b.text = "%s: —" % slot.capitalize()
			else:
				b.text = "%s: %s" % [slot.capitalize(), String(item.get("name", "?"))]
				b.modulate = Game.rarity_color(String(item.get("rarity", "common")))
			b.custom_minimum_size = Vector2(120, 30)
			b.pressed.connect(_on_slot_clicked.bind(String(entry.get("char_id", "")), slot))
			slots.add_child(b)
	# Loot bag.
	if Game.loot_bag.is_empty():
		var empty := Label.new()
		empty.text = "No loot yet. Kill things."
		empty.modulate = Color(1, 1, 1, 0.4)
		bag_box.add_child(empty)
	for item in Game.loot_bag:
		var b := Button.new()
		b.text = "%s\n%s · %s" % [String(item.get("name", "?")), String(item.get("slot", "")).capitalize(), _stat_summary(item)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(280, 52)
		b.modulate = Game.rarity_color(String(item.get("rarity", "common")))
		if String(item.get("id", "")) == selected_item:
			b.text = "▶ " + b.text
		b.pressed.connect(_on_bag_item_clicked.bind(String(item.get("id", ""))))
		bag_box.add_child(b)
	info_label.text = "Selected: %s" % _item_name(selected_item) if selected_item != "" else "Click loot, then a matching slot to equip."


func _stat_summary(item: Dictionary) -> String:
	var parts: Array = []
	for k in (item.get("stats", {}) as Dictionary).keys():
		var v := float((item.get("stats", {}) as Dictionary)[k])
		var label := String(k).replace("_pct", "% ").replace("_flat", " ").replace("_", " ").strip_edges()
		if String(k).ends_with("_pct"):
			parts.append("+%d%% %s" % [int(v * 100.0), label.replace("% ", "")])
		else:
			parts.append("+%d %s" % [int(v), label])
	var affix := String(item.get("affix", ""))
	if affix != "":
		parts.append("★ " + affix.capitalize())
	return ", ".join(parts)


func _item_name(item_id: String) -> String:
	for it in Game.loot_bag:
		if String(it.get("id", "")) == item_id:
			return String(it.get("name", "?"))
	return "?"


func _on_bag_item_clicked(item_id: String) -> void:
	selected_item = "" if selected_item == item_id else item_id
	refresh()


func _on_slot_clicked(char_id: String, slot: String) -> void:
	var node := _member_node(char_id)
	if node == null:
		return
	var gear: Dictionary = node.member.get("gear", {})
	var equipped: Dictionary = gear.get(slot, {})
	if selected_item != "":
		# Equip the selected bag item into this slot (must match).
		var idx := -1
		for i in Game.loot_bag.size():
			if String(Game.loot_bag[i].get("id", "")) == selected_item:
				idx = i
				break
		if idx == -1:
			selected_item = ""
			refresh()
			return
		var item: Dictionary = Game.loot_bag[idx]
		if String(item.get("slot", "")) != slot:
			info_label.text = "That goes in the %s slot." % String(item.get("slot", "")).capitalize()
			return
		Game.loot_bag.remove_at(idx)
		if not equipped.is_empty():
			Game.loot_bag.append(equipped)
		gear[slot] = item
		node.recalc_gear()
		selected_item = ""
	elif not equipped.is_empty():
		# Unequip back to the bag.
		Game.loot_bag.append(equipped)
		gear[slot] = {}
		node.recalc_gear()
	refresh()


func _member_node(char_id: String) -> SquadMember:
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m != null and String(m.member.get("char_id", "")) == char_id:
			return m
	return null
