class_name LootPickup
extends Node2D
## LootPickup: a gear drop in the world. Magnetizes to the warband anchor like
## an XP gem; on collect it goes to Game.loot_bag (the run's loot bag).

var item: Dictionary = {}
var vel := Vector2.ZERO


func _ready() -> void:
	vel = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(30, 90)


func setup(loot_item: Dictionary) -> void:
	item = loot_item


func _physics_process(delta: float) -> void:
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor == null:
		return
	var to: Vector2 = anchor.global_position - global_position
	var dist := to.length()
	if dist < 130.0:
		vel = to.normalized() * 380.0
	else:
		vel = vel.move_toward(Vector2.ZERO, 260.0 * delta)
	global_position += vel * delta
	if dist < 24.0:
		Game.collect_loot(item)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var col: Color = Game.rarity_color(String(item.get("rarity", "common")))
	var s := 8.0
	# Rarity ring for epics and up.
	if String(item.get("rarity", "")) in ["epic", "legendary"]:
		var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() / 180.0)
		draw_arc(Vector2.ZERO, s * 1.7 * pulse, 0, TAU, 24, col, 2.0)
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.5), 1.5)
	# Slot glyph: weapon = triangle notch, armor = square, trinket = circle.
	var slot := String(item.get("slot", ""))
	if slot == "weapon":
		draw_circle(Vector2(0, -s - 6), 2.5, col)
	elif slot == "armor":
		draw_rect(Rect2(-2.5, -s - 8.5, 5, 5), col)
	else:
		draw_arc(Vector2(0, -s - 6), 2.5, 0, TAU, 10, col, 1.5)
