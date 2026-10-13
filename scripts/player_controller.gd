extends Node2D
## PlayerController: moves the WARBAND ANCHOR (the group). The player controls
## one group — never individual characters.
##   WASD/arrows: steer the group        C: stance Tight/Spread
##   RMB: group focus target             Space: tactical pause (in main.gd)

const ARENA_HALF := 1500.0
const GROUP_SPEED := 240.0
const REVIVE_RADIUS := 70.0
const REVIVE_TIME := 3.0

var revive_progress := 0.0
var reviving_member: SquadMember = null


func _ready() -> void:
	add_to_group("warband_anchor")


func _physics_process(delta: float) -> void:
	if not Game.in_run or Game.tactically_paused:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	global_position += dir * GROUP_SPEED * delta
	global_position.x = clampf(global_position.x, -ARENA_HALF, ARENA_HALF)
	global_position.y = clampf(global_position.y, -ARENA_HALF, ARENA_HALF)
	_apply_stance()
	_tick_revive(delta)


func _apply_stance() -> void:
	var spread := 0.65 if Game.stance == "tight" else 1.7
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
			if global_position.distance_to(m.global_position) < REVIVE_RADIUS + 90.0:
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
	if revive_progress >= REVIVE_TIME:
		reviving_member.revive()
		revive_progress = 0.0
		reviving_member = null
