class_name PlayerController
extends Node2D
## PlayerController: moves the WARBAND ANCHOR (the group). The player controls
## one group — never individual characters.
##   WASD/arrows: steer the group        C: stance Tight/Spread
##   RMB: group focus target             Space: tactical pause (in main.gd)

const ARENA_HALF := 1500.0

var revive_progress := 0.0
var reviving_member: SquadMember = null
var trauma := 0.0  # camera shake 0..1
var cam: Camera2D = null


func group_speed() -> float:
	return float(Game.tun("combat.group_speed", 240.0))


func revive_radius() -> float:
	return float(Game.tun("combat.revive_radius", 70.0))


func revive_time() -> float:
	return float(Game.tun("combat.revive_time", 3.0))


func _ready() -> void:
	add_to_group("warband_anchor")
	cam = get_node_or_null("Camera2D") as Camera2D


func add_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _physics_process(delta: float) -> void:
	_tick_shake(delta)
	if not Game.in_run or Game.tactically_paused:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	global_position += dir * group_speed() * delta
	global_position.x = clampf(global_position.x, -ARENA_HALF, ARENA_HALF)
	global_position.y = clampf(global_position.y, -ARENA_HALF, ARENA_HALF)
	_apply_stance()
	_tick_revive(delta)


func _tick_shake(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.6)
	if cam != null:
		var s := trauma * trauma * 26.0
		cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))


func _apply_stance() -> void:
	var spread := float(Game.tun("combat.tight_spread", 0.65)) if Game.stance == "tight" else float(Game.tun("combat.spread_spread", 1.7))
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m != null:
			m.stance_spread = spread


func _unhandled_input(event: InputEvent) -> void:
	if not Game.in_run or Game.tactically_paused:
		return
	if event.is_action_pressed("stance_toggle"):
		Game.stance = "spread" if Game.stance == "tight" else "tight"
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_set_focus_target()
			get_viewport().set_input_as_handled()


func _set_focus_target() -> void:
	var mouse_world := get_global_mouse_position()
	var best: Enemy = null
	var best_d := 60.0 * 60.0
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null:
			continue
		var d := mouse_world.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	Game.focus_target = best


func _tick_revive(delta: float) -> void:
	# If a downed member is inside the group, channel the revive.
	var candidate: SquadMember = null
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m != null and bool(m.member.get("downed", false)):
			if global_position.distance_to(m.global_position) < revive_radius() + 90.0:
				candidate = m
				break
	if candidate == null:
		revive_progress = 0.0
		reviving_member = null
		return
	if candidate != reviving_member:
		reviving_member = candidate
		revive_progress = 0.0
	revive_progress += delta
	if revive_progress >= revive_time():
		reviving_member.revive()
		revive_progress = 0.0
		reviving_member = null
