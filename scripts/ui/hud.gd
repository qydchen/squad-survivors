class_name Hud
extends CanvasLayer
## HUD: timer, XP bar, squad frames, stance, hints, revive progress, end screen.
## Code-built UI. process_mode is ALWAYS so the end screen works while paused.

var timer_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var squad_box: VBoxContainer
var stance_label: Label
var revive_label: Label
var end_panel: CenterContainer
var end_title: Label
var squad_rows := {}  # char_id -> {hp_bar, level_label, name_label}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Game.run_ended.connect(_on_run_ended)
	visible = true


func _build() -> void:
	# Top center: timer + XP.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-190, 10)
	top.custom_minimum_size = Vector2(380, 0)
	top.add_theme_constant_override("separation", 4)
	add_child(top)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	top.add_child(timer_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(380, 14)
	xp_bar.show_percentage = false
	top.add_child(xp_bar)
	xp_label = Label.new()
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.add_theme_font_size_override("font_size", 12)
	top.add_child(xp_label)

	# Top left: squad frames.
	squad_box = VBoxContainer.new()
	squad_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	squad_box.position = Vector2(12, 12)
	squad_box.add_theme_constant_override("separation", 6)
	add_child(squad_box)

	# Top right: stance.
	stance_label = Label.new()
	stance_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stance_label.position = Vector2(-260, 12)
	stance_label.custom_minimum_size = Vector2(248, 0)
	stance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stance_label.add_theme_font_size_override("font_size", 16)
	add_child(stance_label)

	# Bottom center: hints.
	var hints := Label.new()
	hints.text = "WASD move group · Right-click focus target · C stance · Space pause"
	hints.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hints.position = Vector2(-330, -34)
	hints.custom_minimum_size = Vector2(660, 0)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hints.add_theme_font_size_override("font_size", 13)
	hints.modulate = Color(1, 1, 1, 0.55)
	add_child(hints)

	# Revive progress (center, above hints).
	revive_label = Label.new()
	revive_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	revive_label.position = Vector2(-200, -64)
	revive_label.custom_minimum_size = Vector2(400, 0)
	revive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	revive_label.add_theme_font_size_override("font_size", 18)
	revive_label.visible = false
	add_child(revive_label)

	_build_end_screen()


func _build_end_screen() -> void:
	end_panel = CenterContainer.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.visible = false
	add_child(end_panel)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 180)
	end_panel.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	end_title = Label.new()
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_size_override("font_size", 34)
	vb.add_child(end_title)
	var sub := Label.new()
	sub.text = "Press R to run it back"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)


func build_squad_frames() -> void:
	for c in squad_box.get_children():
		c.queue_free()
	squad_rows.clear()
	for entry in Game.squad:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		squad_box.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = Color(0.7, 0.7, 0.7)
		row.add_child(dot)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		row.add_child(vb)
		var name_label := Label.new()
		name_label.add_theme_font_size_override("font_size", 13)
		vb.add_child(name_label)
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(150, 8)
		hp_bar.show_percentage = false
		vb.add_child(hp_bar)
		var level_label := Label.new()
		level_label.add_theme_font_size_override("font_size", 11)
		level_label.modulate = Color(1, 1, 1, 0.6)
		vb.add_child(level_label)
		squad_rows[String(entry.get("char_id"))] = {"hp_bar": hp_bar, "level_label": level_label, "name_label": name_label, "dot": dot}


func _process(_delta: float) -> void:
	if not Game.in_run:
		return
	var t := Game.run_time
	timer_label.text = "%02d:%02d" % [int(t) / 60, int(t) % 60]
	var need := Game._xp_for_level(Game.run_level)
	xp_bar.max_value = need
	xp_bar.value = Game.xp_pool
	xp_label.text = "Level %d   ·   %d / %d XP" % [Game.run_level, Game.xp_pool, need]
	stance_label.text = "Stance: %s  (C)" % Game.stance.capitalize()
	_update_squad_frames()
	_update_revive()


func _update_squad_frames() -> void:
	var colors := {"bulwark": Color(0.55, 0.65, 0.85), "arcanist": Color(0.45, 0.85, 1.0), "cleric": Color(1.0, 0.85, 0.45)}
	for entry in Game.squad:
		var cid := String(entry.get("char_id"))
		if not squad_rows.has(cid):
			continue
		var row: Dictionary = squad_rows[cid]
		var max_hp: float = maxf(1.0, float(entry.get("max_hp", 1.0)))
		(row["hp_bar"] as ProgressBar).max_value = max_hp
		(row["hp_bar"] as ProgressBar).value = float(entry.get("hp", 0.0))
		(row["level_label"] as Label).text = "Lv %d" % int(entry.get("level", 1))
		var nm := "%s (%s)" % [String(entry.get("name", "")), String(entry.get("class_id", "")).capitalize()]
		if bool(entry.get("downed", false)):
			nm += " — DOWN"
		(row["name_label"] as Label).text = nm
		(row["dot"] as ColorRect).color = colors.get(String(entry.get("class_id", "")), Color(0.7, 0.7, 0.7))


func _update_revive() -> void:
	var pc := get_tree().get_first_node_in_group("warband_anchor")
	if pc != null and float(pc.get("revive_progress")) > 0.0:
		revive_label.visible = true
		revive_label.text = "Reviving… %d%%" % int(100.0 * float(pc.get("revive_progress")) / 3.0)
	else:
		revive_label.visible = false


func _on_run_ended(victory: bool) -> void:
	Game.set_tactical_pause(true)
	end_title.text = "EXTRACTED" if victory else "WIPED"
	end_title.modulate = Color(0.4, 1.0, 0.5) if victory else Color(1.0, 0.4, 0.4)
	end_panel.visible = true
