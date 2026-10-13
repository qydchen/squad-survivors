class_name SquadMember
extends CharacterBody2D
## SquadMember: one deployed character. The GROUP is the unit of control —
## this script handles per-member automation: formation follow, auto-attacks,
## auto-cast abilities, buffs, damage, downed state. No player micro here.

const CLASS_COLORS := {
	"bulwark": Color(0.55, 0.65, 0.85),
	"arcanist": Color(0.45, 0.85, 1.0),
	"cleric": Color(1.0, 0.85, 0.45),
	"ranger": Color(0.55, 0.9, 0.45),
	"shadowblade": Color(0.75, 0.45, 0.9),
	"stormcaller": Color(0.5, 0.7, 1.0),
}

var member: Dictionary = {}
var class_def: Dictionary = {}
var formation_offset := Vector2.ZERO
var stance_spread := 1.0
var attack_cd := 0.0
var body_radius := 14.0
var pet: Pet = null  # Ranger's animal companion (ability-granted).
var flash_left := 0.0  # red hit flash (feel)


func setup(squad_entry: Dictionary) -> void:
	member = squad_entry
	# No physical collision: all combat is distance-based, so units never
	# push each other out of formation.
	collision_layer = 2
	collision_mask = 0
	class_def = _load_class_def(String(squad_entry.get("class_id", "")))
	formation_offset = _formation_offset_for(String(class_def.get("role", "")))
	var base_hp: float = float(class_def.get("base_stats", {}).get("max_hp", 100.0))
	var rbonus: float = 1.0 + 0.02 * (int(member.get("roster_level", 1)) - 1)
	member["max_hp"] = base_hp * rbonus * float(member.get("stat_mults", {}).get("max_hp_mult", 1.0))
	member["hp"] = member["max_hp"]


func _load_class_def(class_id: String) -> Dictionary:
	var path := "res://data/classes/%s.json" % class_id
	if not FileAccess.file_exists(path):
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _formation_offset_for(role: String) -> Vector2:
	match role:
		"tank", "melee_dps":
			return Vector2(70, randf_range(-50, 50))
		"healer", "support":
			return Vector2(-10, randf_range(-40, 40))
		_:
			return Vector2(-80, randf_range(-70, 70))


func gear_stat_total(key: String) -> float:
	var total := 0.0
	for slot in ["weapon", "armor", "trinket"]:
		var item: Dictionary = (member.get("gear", {}) as Dictionary).get(slot, {})
		total += float((item.get("stats", {}) as Dictionary).get(key, 0.0))
	return total


func get_stat(stat: String) -> float:
	var base: float = float(class_def.get("base_stats", {}).get(stat, 0.0))
	var mult: float = float(member.get("stat_mults", {}).get(stat, 1.0))
	return base * mult * (1.0 + gear_stat_total(stat + "_pct")) + gear_stat_total(stat + "_flat")


func has_affix(affix_id: String) -> bool:
	for slot in ["weapon", "armor", "trinket"]:
		var item: Dictionary = (member.get("gear", {}) as Dictionary).get(slot, {})
		if String(item.get("affix", "")) == affix_id:
			return true
	return false


func recalc_gear() -> void:
	# Recompute max HP from gear; keep the current HP fraction.
	var frac: float = float(member.get("hp", 1.0)) / maxf(1.0, float(member.get("max_hp", 1.0)))
	var base_hp: float = float(class_def.get("base_stats", {}).get("max_hp", 100.0))
	var rbonus: float = 1.0 + 0.02 * (int(member.get("roster_level", 1)) - 1)
	var hp_mult: float = float(member.get("stat_mults", {}).get("max_hp_mult", 1.0))
	var gear_pct := 0.0
	var gear_flat := 0.0
	for slot in ["weapon", "armor", "trinket"]:
		var item: Dictionary = (member.get("gear", {}) as Dictionary).get(slot, {})
		var stats: Dictionary = item.get("stats", {})
		gear_pct += float(stats.get("max_hp_pct", 0.0))
		gear_flat += float(stats.get("max_hp_flat", 0.0))
	member["max_hp"] = base_hp * rbonus * hp_mult * (1.0 + gear_pct) + gear_flat
	member["hp"] = float(member.get("max_hp", 1.0)) * frac
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not bool(member.get("alive", true)):
		return
	_move(delta)
	_tick_timers(delta)
	_try_attack(delta)
	_try_abilities(delta)
	_tick_volcanic(delta)
	queue_redraw()


func _tick_volcanic(delta: float) -> void:
	# "volcanic" affix: periodic fire nova around the member.
	if not has_affix("volcanic"):
		return
	var cd: float = float(member.get("volcanic_cd", 0.0)) - delta
	if cd <= 0.0:
		cd = 6.0
		var dmg := get_stat("attack_power") * 2.0
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Enemy
			if e != null and global_position.distance_to(e.global_position) < 170.0:
				var to: Vector2 = (e.global_position - global_position).normalized()
				e.take_damage(dmg, to, true)
	member["volcanic_cd"] = cd


func _move(_delta: float) -> void:
	var anchor := get_tree().get_first_node_in_group("warband_anchor")
	var target := global_position
	if anchor:
		target = anchor.global_position + formation_offset * stance_spread
	var to := target - global_position
	if to.length() > 6.0:
		velocity = to.normalized() * get_stat("move_speed")
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _tick_timers(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	flash_left = maxf(0.0, flash_left - delta)
	for a in member.get("abilities", []):
		a["cd_left"] = maxf(0.0, float(a.get("cd_left", 0.0)) - delta)
	for k in member.get("buffs", {}).keys():
		member["buffs"][k] = float(member["buffs"][k]) - delta
		if float(member["buffs"][k]) <= 0.0:
			member["buffs"].erase(k)


func _pick_target(max_range: float) -> Node2D:
	# Group focus target first (if valid), else nearest in range.
	var focus: Node2D = Game.focus_target
	if is_instance_valid(focus) and focus.is_in_group("enemies"):
		if global_position.distance_to(focus.global_position) <= max_range * 1.6:
			return focus
	var best: Enemy = null
	var best_d := max_range * max_range
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null:
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _try_attack(_delta: float) -> void:
	if attack_cd > 0.0:
		return
	var atk: Dictionary = class_def.get("basic_attack", {})
	var kind := String(atk.get("kind", "melee_arc"))
	var rng: float = float(atk.get("range", 200.0))
	var target := _pick_target(rng)
	if target == null:
		return
	var ap := get_stat("attack_power")
	var dmg: float = ap * float(atk.get("damage_mult", 1.0))
	var crit_chance: float = float(class_def.get("base_stats", {}).get("crit_chance", 0.05)) + float(member.get("stat_mults", {}).get("crit", 0.0)) + gear_stat_total("crit_flat")
	if "shadowstep" in member.get("buffs", {}):
		crit_chance += 0.5
	var crit_roll := randf() < crit_chance
	if crit_roll:
		dmg *= 2.0
	attack_cd = float(atk.get("cooldown", 1.0)) / maxf(0.2, get_stat("attack_speed") * _bloodlust_mult())
	if kind == "melee_arc":
		_melee_arc(target, atk, dmg, crit_roll)
	else:
		_fire_projectile(target.global_position, atk, dmg, true, crit_roll)


func _melee_arc(target: Node2D, atk: Dictionary, dmg: float, crit: bool) -> void:
	var arc: float = deg_to_rad(float(atk.get("arc_degrees", 120.0)))
	var rng: float = float(atk.get("range", 100.0))
	var facing := (target.global_position - global_position).normalized()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e == null:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > rng + e.radius:
			continue
		if facing.angle_to(to.normalized()) > arc * 0.5 and to.length() > 20.0:
			continue
		e.take_damage(dmg, to.normalized(), true, crit)


func _fire_projectile(target_pos: Vector2, atk: Dictionary, dmg: float, from_player: bool, crit: bool = false) -> void:
	var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
	if pool == null:
		return
	var dir := (target_pos - global_position).normalized()
	var color: Color = CLASS_COLORS.get(String(member.get("class_id", "")), Color.WHITE)
	pool.fire(global_position, dir, float(atk.get("projectile_speed", 420.0)), dmg, from_player, color, 6.0, String(atk.get("on_hit", "")), crit)


func _try_abilities(_delta: float) -> void:
	for a in member.get("abilities", []):
		if float(a.get("cd_left", 0.0)) > 0.0:
			continue
		if _cast_ability(String(a.get("id", "")), a):
			a["cd_left"] = float(a.get("cooldown", 10.0))


func _cast_ability(ability_id: String, ability: Dictionary) -> bool:
	var rank := int(ability.get("rank", 1))
	match ability_id:
		"taunt_shout":
			var taunted := 0
			for n in get_tree().get_nodes_in_group("enemies"):
				var e := n as Enemy
				if e != null and global_position.distance_to(e.global_position) < 280.0:
					e.taunted_by = self
					e.taunt_left = 3.0
					taunted += 1
			return taunted > 0
		"shield_wall":
			var dur := 4.0 + 2.0 * (rank - 1)
			member["buffs"]["shield_wall"] = dur
			return true
		"shockwave":
			var dmg := get_stat("attack_power") * (1.5 + 0.5 * rank)
			for n in get_tree().get_nodes_in_group("enemies"):
				var e := n as Enemy
				if e != null and global_position.distance_to(e.global_position) < 150.0:
					var to: Vector2 = (e.global_position - global_position).normalized()
					e.take_damage(dmg, to, true)
					e.stun_left = 1.5 + (0.5 if rank >= 2 else 0.0)
			var pc2 := get_tree().get_first_node_in_group("warband_anchor") as PlayerController
			if pc2 != null:
				pc2.add_shake(float(Game.tun("feel.shake_on_shockwave", 0.2)))
			return true
		"blizzard":
			var zone := get_tree().get_first_node_in_group("zone_layer") as ZoneLayer
			var center := _densest_cluster(600.0)
			if center == Vector2.INF or zone == null:
				return false
			zone.spawn_blizzard(center, 5.0, get_stat("attack_power") * 1.2)
			return true
		"blink":
			# Group blink: the whole warband jumps forward. The group is the unit.
			var anchor := get_tree().get_first_node_in_group("warband_anchor") as Node2D
			if anchor == null:
				return false
			var mv := Vector2.RIGHT
			var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if input_dir.length() > 0.1:
				mv = input_dir.normalized()
			anchor.global_position += mv * 220.0
			return true
		"arcane_barrage":
			var target := _pick_target(520.0)
			if target == null:
				return false
			var n := 5 + 3 * (rank - 1)
			var base_dir := (target.global_position - global_position).normalized()
			for i in n:
				var d := base_dir.rotated(deg_to_rad(-20.0 + 40.0 * i / maxf(1.0, n - 1.0)))
				var pool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
				if pool:
					pool.fire(global_position, d, 460.0, get_stat("attack_power") * 0.8, true, Color(0.7, 0.5, 1.0), 6.0, "")
			return true
		"heal":
			var ally := _most_injured_ally()
			if ally == null:
				return false
			var amount: float = ally.member["max_hp"] * (0.4 + 0.1 * rank)
			ally.heal(amount)
			return true
		"power_shield":
			var ally := _most_injured_ally()
			if ally == null:
				return false
			ally.member["shield"] = float(ally.member.get("max_hp", 100.0)) * 0.35
			ally.member["buffs"]["aegis"] = 6.0
			return true
		"hallowed_ground":
			var zone := get_tree().get_first_node_in_group("zone_layer") as ZoneLayer
			if zone == null:
				return false
			var anchor := get_tree().get_first_node_in_group("warband_anchor") as Node2D
			zone.spawn_hallowed(anchor.global_position if anchor else global_position, 6.0, get_stat("attack_power"))
			return true
		# ---- Ranger ----
		"animal_companion":
			if pet != null and is_instance_valid(pet):
				return false  # already have one; passive
			pet = Pet.new()
			get_parent().add_child(pet)
			pet.global_position = global_position + Vector2(-24, 18)
			pet.owner_member = self
			var prank := int(ability.get("rank", 1))
			pet.damage_mult = 0.7 + 0.35 * (prank - 1)
			pet.slow_on_hit = prank >= 3
			return true
		"aimed_shot":
			var atarget := _pick_target(560.0)
			if atarget == null:
				return false
			var arank := int(ability.get("rank", 1))
			var admg := get_stat("attack_power") * (3.0 + arank)
			var e := atarget as Enemy
			if e != null and e.hp / maxf(1.0, e.max_hp) < 0.3:
				admg *= 3.0  # execute
			var adir: Vector2 = (atarget.global_position - global_position).normalized()
			atarget.take_damage(admg, adir, true)
			return true
		"frost_trap":
			var fzone := get_tree().get_first_node_in_group("zone_layer") as ZoneLayer
			var fcenter := _densest_cluster(600.0)
			if fcenter == Vector2.INF or fzone == null:
				return false
			fzone.spawn_frost_trap(fcenter, 6.0, get_stat("attack_power"))
			return true
		# ---- Shadowblade ----
		"shadowstep":
			var starget := _pick_target(520.0)
			if starget == null:
				return false
			var srank := int(ability.get("rank", 1))
			# Appear behind the target, blades already moving.
			var away: Vector2 = (global_position - starget.global_position).normalized()
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			global_position = starget.global_position + away * -44.0
			member["buffs"]["shadowstep"] = 6.0 + 2.0 * (srank - 1)
			if srank >= 3:
				for n in get_tree().get_nodes_in_group("enemies"):
					var se := n as Enemy
					if se != null and global_position.distance_to(se.global_position) < 150.0:
						se.stun_left = 1.0
			return true
		"fan_of_knives":
			var frank := int(ability.get("rank", 1))
			var knives := 10 + 4 * (frank - 1)
			var fpool := get_tree().get_first_node_in_group("projectile_pool") as ProjectilePool
			if fpool == null:
				return false
			for i in knives:
				var kd := Vector2.RIGHT.rotated(TAU * i / knives)
				fpool.fire(global_position, kd, 420.0, get_stat("attack_power") * 0.7, true, Color(0.8, 0.8, 0.9), 5.0, "")
			return true
		"evasion":
			var vrank := int(ability.get("rank", 1))
			member["buffs"]["evasion"] = 5.0
			member["evasion_rank"] = vrank
			return true
		# ---- Stormcaller ----
		"searing_totem":
			var totem := Totem.new()
			get_parent().add_child(totem)
			totem.global_position = global_position
			totem.owner_member = self
			var trank := int(ability.get("rank", 1))
			totem.duration = 12.0 + 4.0 * (trank - 1)
			totem.left = totem.duration
			totem.slow = trank >= 3
			return true
		"chain_lightning":
			var ctarget := _pick_target(520.0)
			if ctarget == null:
				return false
			var crank := int(ability.get("rank", 1))
			var forks := 2 + crank  # 3 / 4 / 5
			if has_affix("voltaic"):
				forks += 2
			var hit: Array = []
			var current: Enemy = ctarget as Enemy
			var cdmg := get_stat("attack_power") * 1.6
			while current != null and forks > 0:
				hit.append(current)
				var cdir: Vector2 = (current.global_position - global_position).normalized()
				current.take_damage(cdmg, cdir, true)
				cdmg *= 0.8
				forks -= 1
				# Next: nearest unhit enemy within 220px of the current one.
				var next: Enemy = null
				var nd := 220.0 * 220.0
				for n in get_tree().get_nodes_in_group("enemies"):
					var ce := n as Enemy
					if ce == null or ce in hit:
						continue
					var d := current.global_position.distance_squared_to(ce.global_position)
					if d < nd:
						nd = d
						next = ce
				current = next
			return true
		"bloodlust":
			var brank := int(ability.get("rank", 1))
			var dur := 8.0 + 2.0 * (brank - 1)
			for n in get_tree().get_nodes_in_group("squad_members"):
				var sm := n as SquadMember
				if sm != null and bool(sm.member.get("alive", true)):
					sm.member["buffs"]["bloodlust"] = dur
			return true
	return false


func _densest_cluster(max_range: float) -> Vector2:
	var best := Vector2.INF
	var best_n := 0
	for n1 in get_tree().get_nodes_in_group("enemies"):
		var e := n1 as Enemy
		if e == null or global_position.distance_to(e.global_position) > max_range:
			continue
		var n := 0
		for n2 in get_tree().get_nodes_in_group("enemies"):
			var o := n2 as Enemy
			if o != null and e.global_position.distance_to(o.global_position) < 150.0:
				n += 1
		if n > best_n:
			best_n = n
			best = e.global_position
	return best


func _most_injured_ally() -> SquadMember:
	var best: SquadMember = null
	var best_frac := 0.85
	for n in get_tree().get_nodes_in_group("squad_members"):
		var m := n as SquadMember
		if m == null or not bool(m.member.get("alive", true)):
			continue
		var frac: float = float(m.member.get("hp", 1.0)) / maxf(1.0, float(m.member.get("max_hp", 1.0)))
		if frac < best_frac:
			best_frac = frac
			best = m
	return best


func heal(amount: float) -> void:
	if not bool(member.get("alive", true)):
		return
	member["hp"] = minf(float(member.get("max_hp", 1.0)), float(member.get("hp", 0.0)) + amount)


func _bloodlust_mult() -> float:
	return 1.3 if "bloodlust" in member.get("buffs", {}) else 1.0


func take_damage(amount: float, from_dir: Vector2 = Vector2.ZERO) -> void:
	if not bool(member.get("alive", true)):
		return
	# Evasion: flat chance to ignore the hit entirely.
	if "evasion" in member.get("buffs", {}):
		var dodge := 0.3 + 0.15 * int(member.get("evasion_rank", 1))
		if randf() < dodge:
			return
	var dmg := amount
	# Tight stance: group mitigation aura (tuning: combat.tight_mitigation).
	if Game.stance == "tight":
		dmg *= float(Game.tun("combat.tight_mitigation", 0.85))
	# Shield Wall buff.
	if member.get("buffs", {}).has("shield_wall"):
		dmg *= 0.4
	# Aegis absorb.
	var shield: float = float(member.get("shield", 0.0))
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg)
		member["shield"] = shield - absorbed
		dmg -= absorbed
	# Armor (base + gear).
	var armor := get_stat("armor")
	dmg = dmg * 100.0 / (100.0 + armor * 5.0)
	member["hp"] = float(member.get("hp", 0.0)) - dmg
	flash_left = 0.12
	if float(member["hp"]) <= 0.0:
		member["hp"] = 0.0
		member["alive"] = false
		member["downed"] = true
		set_physics_process(false)
		var pc := get_tree().get_first_node_in_group("warband_anchor") as PlayerController
		if pc != null:
			pc.add_shake(float(Game.tun("feel.shake_on_downed", 0.5)))
		queue_redraw()


func revive() -> void:
	member["hp"] = float(member.get("max_hp", 1.0)) * 0.5
	member["alive"] = true
	member["downed"] = false
	set_physics_process(true)


func apply_upgrade(upgrade: Dictionary) -> void:
	var kind := String(upgrade.get("kind", ""))
	if kind == "stat":
		var stat := String(upgrade.get("stat", ""))
		var mults: Dictionary = member.get("stat_mults", {})
		if stat == "crit":
			mults["crit"] = float(mults.get("crit", 0.0)) + float(upgrade.get("value", 0.05))
		elif stat == "max_hp_mult":
			mults["max_hp_mult"] = float(mults.get("max_hp_mult", 1.0)) * (1.0 + float(upgrade.get("value", 0.15)))
			member["max_hp"] = float(member.get("max_hp", 100.0)) * (1.0 + float(upgrade.get("value", 0.15)))
			heal(float(member.get("max_hp", 100.0)) * float(upgrade.get("value", 0.15)))
		else:
			mults[stat] = float(mults.get(stat, 1.0)) * (1.0 + float(upgrade.get("value", 0.1)))
	elif kind == "ability":
		var found := false
		for a in member.get("abilities", []):
			if String(a.get("id", "")) == String(upgrade.get("ability_id", "")):
				a["rank"] = int(a.get("rank", 1)) + 1
				found = true
		if not found:
			var def: Dictionary = upgrade.get("ability_def", {})
			member["abilities"].append({
				"id": def.get("id"),
				"name": def.get("name"),
				"cooldown": float(def.get("cooldown", 10.0)),
				"cd_left": 1.0,
				"rank": 1,
			})


func _draw() -> void:
	var color: Color = CLASS_COLORS.get(String(member.get("class_id", "")), Color.WHITE)
	if bool(member.get("downed", false)):
		# Downed marker: hollow circle + X.
		draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, Color(1, 0.3, 0.3), 3.0)
		draw_line(Vector2(-8, -8), Vector2(8, 8), Color(1, 0.3, 0.3), 3.0)
		draw_line(Vector2(-8, 8), Vector2(8, -8), Color(1, 0.3, 0.3), 3.0)
		return
	draw_circle(Vector2.ZERO, body_radius, color)
	draw_arc(Vector2.ZERO, body_radius, 0, TAU, 24, Color(0, 0, 0, 0.4), 2.0)
	if flash_left > 0.0:
		draw_circle(Vector2.ZERO, body_radius, Color(1, 0.25, 0.25, 0.6))
	# Role pips: tank gets a ring, healer a cross.
	var role := String(class_def.get("role", ""))
	if role == "tank":
		draw_arc(Vector2.ZERO, body_radius + 4, 0, TAU, 24, Color.WHITE, 2.0)
	elif role == "healer":
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color.WHITE, 2.5)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color.WHITE, 2.5)
	if float(member.get("shield", 0.0)) > 0.0:
		draw_arc(Vector2.ZERO, body_radius + 8, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.8), 2.0)
	# Tiny HP bar.
	var frac: float = float(member.get("hp", 1.0)) / maxf(1.0, float(member.get("max_hp", 1.0)))
	draw_rect(Rect2(-14, -body_radius - 10, 28, 4), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-14, -body_radius - 10, 28 * frac, 4), Color(0.3, 1.0, 0.4))
