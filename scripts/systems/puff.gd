class_name Puff
extends Node2D
## Puff: a tiny self-managing death-poof particle. Spawn a few on enemy death.

var vel := Vector2.ZERO
var left := 0.4
var duration := 0.4
var color := Color(1, 1, 1, 0.7)
var size := 5.0


static func burst(parent: Node, pos: Vector2, col: Color, count: int = 6) -> void:
	for i in count:
		var p := Puff.new()
		parent.add_child(p)
		p.global_position = pos
		p.vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 160)
		p.color = col
		p.size = randf_range(3.0, 7.0)


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		queue_free()
		return
	global_position += vel * delta
	vel = vel.move_toward(Vector2.ZERO, 400.0 * delta)
	queue_redraw()


func _draw() -> void:
	var frac := maxf(0.0, left / duration)
	draw_circle(Vector2.ZERO, size * frac, Color(color.r, color.g, color.b, 0.7 * frac))
