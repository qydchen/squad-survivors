class_name DamageNumbers
extends Node2D
## DamageNumbers: pooled floating combat text for player-dealt damage.
## In group "damage_numbers". World-space, cheap Labels.

const POOL := 48

var labels: Array[Label] = []
var cursor := 0
var active: Array = []  # parallel: {label, vel, left}


func _ready() -> void:
	add_to_group("damage_numbers")
	for i in POOL:
		var l := Label.new()
		l.visible = false
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 4)
		add_child(l)
		labels.append(l)
		active.append({"vel": Vector2.ZERO, "left": 0.0})


func spawn(pos: Vector2, amount: float, crit: bool) -> void:
	var l: Label = labels[cursor]
	var st: Dictionary = active[cursor]
	cursor = (cursor + 1) % POOL
	l.text = str(int(amount))
	l.position = pos + Vector2(randf_range(-8, 8), -10)
	l.modulate = Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1)
	l.add_theme_font_size_override("font_size", 20 if crit else 15)
	l.visible = true
	l.modulate.a = 1.0
	st["vel"] = Vector2(randf_range(-12, 12), -70)
	st["left"] = 0.7


func _process(delta: float) -> void:
	for i in labels.size():
		var st: Dictionary = active[i]
		if float(st["left"]) <= 0.0:
			continue
		st["left"] = float(st["left"]) - delta
		var l: Label = labels[i]
		l.position += (st["vel"] as Vector2) * delta
		l.modulate.a = maxf(0.0, float(st["left"]) / 0.7)
		if float(st["left"]) <= 0.0:
			l.visible = false
