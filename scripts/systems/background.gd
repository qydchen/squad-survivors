extends Node2D
## Background: arena floor grid + bounds. Purely visual.

const ARENA_HALF := 1500.0
const CELL := 120.0


func _draw() -> void:
	# Floor.
	draw_rect(Rect2(-ARENA_HALF, -ARENA_HALF, ARENA_HALF * 2, ARENA_HALF * 2), Color(0.07, 0.08, 0.11))
	# Grid.
	var line_col := Color(0.13, 0.15, 0.2)
	var x := -ARENA_HALF
	while x <= ARENA_HALF:
		draw_line(Vector2(x, -ARENA_HALF), Vector2(x, ARENA_HALF), line_col, 1.0)
		x += CELL
	var y := -ARENA_HALF
	while y <= ARENA_HALF:
		draw_line(Vector2(-ARENA_HALF, y), Vector2(ARENA_HALF, y), line_col, 1.0)
		y += CELL
	# Bounds.
	draw_rect(Rect2(-ARENA_HALF, -ARENA_HALF, ARENA_HALF * 2, ARENA_HALF * 2), Color(0.85, 0.65, 0.35, 0.8), false, 4.0)
