class_name XpGem
extends Node2D
## XpGem: drops from enemies, magnetizes to the warband anchor, feeds Game.add_xp.

var value := 1
var vel := Vector2.ZERO


func _ready() -> void:
	vel = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(40, 120)


func _physics_process(delta: float) -> void:
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	if anchor == null:
		return
	var to: Vector2 = anchor.global_position - global_position
	var dist := to.length()
	if dist < 130.0:
		# Magnet.
		vel = to.normalized() * 420.0
	else:
		vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
	global_position += vel * delta
	if dist < 22.0:
		Game.add_xp(value)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var s := 5.0
	var pts := PackedVector2Array([Vector2(0, -s), Vector2(s, 0), Vector2(0, s), Vector2(-s, 0)])
	draw_colored_polygon(pts, Color(0.35, 1.0, 0.9))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.1, 0.5, 0.45), 1.5)
