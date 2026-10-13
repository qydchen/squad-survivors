class_name Totem
extends Node2D
## Totem: the Stormcaller's deployable. Pulses damage (and slow at high rank)
## to nearby enemies for its duration, then crumbles.

var owner_member: SquadMember = null
var duration := 12.0
var left := 12.0
var pulse_cd := 0.0
var slow := false
var body_radius := 12.0


func _physics_process(delta: float) -> void:
	left -= delta
	if left <= 0.0:
		queue_free()
		return
	pulse_cd -= delta
	if pulse_cd <= 0.0:
		pulse_cd = 1.0
		_pulse()
	queue_redraw()


func _pulse() -> void:
	if owner_member == null or not is_instance_valid(owner_member):
		return
	var dmg: float = owner_member.get_stat("attack_power") * 1.4
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and global_position.distance_to(e.global_position) < 150.0:
			var to: Vector2 = (e.global_position - global_position).normalized()
			e.take_damage(dmg, to, true)
			if slow:
				e.apply_slow(0.7, 1.0)


func _draw() -> void:
	var frac: float = maxf(0.0, left / duration)
	# Totem pole: stacked stones with a glow.
	draw_circle(Vector2(0, 6), 8, Color(0.45, 0.4, 0.5))
	draw_circle(Vector2(0, -2), 6, Color(0.5, 0.45, 0.55))
	var glow := Color(1.0, 0.55, 0.2, 0.6 + 0.4 * frac)
	draw_circle(Vector2(0, -10), 5, glow)
	draw_arc(Vector2.ZERO, 150.0, 0, TAU, 40, Color(1.0, 0.55, 0.2, 0.15), 2.0)
