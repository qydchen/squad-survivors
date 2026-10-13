class_name DraftScreen
extends CanvasLayer
## DraftScreen: pre-run warband management. Pick up to 5 characters from the
## roster, review the run forecast (intel), browse the stash, then deploy.
## Shown on boot; hidden once a run starts.

signal deployed(char_ids: Array)

var selected: Array = []  # char_ids, max Game.MAX_SQUAD
var roster_box: VBoxContainer
var intel_label: Label
var stash_box: VBoxContainer
var deploy_button: Button
var info_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	refresh()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 560)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "WARBAND — Draft Your Squad"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vb.add_child(title)
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	vb.add_child(info_label)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	# Roster.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Roster (click to draft, max 5)"
	lh.add_theme_font_size_override("font_size", 15)
	left.add_child(lh)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(rscroll)
	roster_box = VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 4)
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(roster_box)
	# Intel + stash.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var ih := Label.new()
	ih.text = "Intel — expected hostiles"
	ih.add_theme_font_size_override("font_size", 15)
	right.add_child(ih)
	intel_label = Label.new()
	intel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel_label.add_theme_font_size_override("font_size", 13)
	intel_label.modulate = Color(1, 1, 1, 0.75)
	right.add_child(intel_label)
	var sh := Label.new()
	sh.text = "Stash"
	sh.add_theme_font_size_override("font_size", 15)
	right.add_child(sh)
	var sscroll := ScrollContainer.new()
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sscroll)
	stash_box = VBoxContainer.new()
	stash_box.add_theme_constant_override("separation", 3)
	stash_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sscroll.add_child(stash_box)
	# Deploy.
	deploy_button = Button.new()
	deploy_button.text = "DEPLOY"
	deploy_button.custom_minimum_size = Vector2(0, 48)
	deploy_button.add_theme_font_size_override("font_size", 18)
	deploy_button.pressed.connect(_on_deploy)
	vb.add_child(deploy_button)


func refresh() -> void:
	for c in roster_box.get_children():
		c.queue_free()
	for c in stash_box.get_children():
		c.queue_free()
	# Roster.
	for char in Roster.characters:
		var cid := String(char.get("id", ""))
		var wounded := int(char.get("wounded_runs_left", 0)) > 0
		var b := Button.new()
		var label := "%s — %s  Lv%d" % [String(char.get("name", "?")), String(char.get("class_id", "")).capitalize(), int(char.get("roster_level", 1))]
		if wounded:
			label += "  [WOUNDED]"
			b.disabled = true
		elif cid in selected:
			label = "▶ " + label
		b.text = label
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(310, 36)
		if not wounded:
			b.pressed.connect(_on_roster_clicked.bind(cid))
		roster_box.add_child(b)
	# Intel.
	intel_label.text = "Swarmers from the start. Shieldbearers push in around 2:00, Stingers at 4:00. Elites prowl from 3:00 — watch for the gold rings. Volatile elites explode: spread out (C)."
	# Stash.
	if Stash.items.is_empty():
		var empty := Label.new()
		empty.text = "Empty. Gear you keep goes here."
		empty.modulate = Color(1, 1, 1, 0.4)
		stash_box.add_child(empty)
	for item in Stash.items:
		var l := Label.new()
		l.text = "%s · %s" % [String(item.get("name", "?")), String(item.get("rarity", "")).capitalize()]
		l.modulate = Game.rarity_color(String(item.get("rarity", "common")))
		l.add_theme_font_size_override("font_size", 13)
		stash_box.add_child(l)
	_update_info()


func _update_info() -> void:
	info_label.text = "Drafted %d / %d" % [selected.size(), Game.MAX_SQUAD]
	deploy_button.disabled = selected.is_empty()


func _on_roster_clicked(char_id: String) -> void:
	if char_id in selected:
		selected.erase(char_id)
	elif selected.size() < Game.MAX_SQUAD:
		selected.append(char_id)
	refresh()


func _on_deploy() -> void:
	if selected.is_empty():
		return
	deployed.emit(selected.duplicate())
