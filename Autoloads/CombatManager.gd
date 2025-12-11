extends Node

var attacker = null
var target = null
var attack_timer := 0.0
var is_repositioning = false

func start_attack(player, npc):
	attacker = player
	target = npc
	attack_timer = 0.0
	player.agent.target_position = npc.global_position

func stop_attack():
	if attacker:
		attacker.anim_player.is_attacking = false
		attacker.anim_player.anim_locked = false
		attacker.agent.target_position = attacker.global_position

	attacker = null
	target = null
	attack_timer = 0.0

func process(delta):
	if attacker == null or target == null:
		return

	if not target.is_inside_tree():
		stop_attack()
		return

	if attacker.anim_player.anim_locked:
		_rotate_towards_target(delta)
		attacker.velocity = Vector3.ZERO
		return

	var p2 = Vector2(attacker.global_position.x, attacker.global_position.z)
	var t2 = Vector2(target.global_position.x, target.global_position.z)
	var dist = p2.distance_to(t2)

	var weapon_reach = target.interaction.interact_range
	var target_radius = _get_radius(target)
	var collision_boundary = 0.5 + target_radius + 0.1
	var ideal_dist = collision_boundary

	var reposition_buffer = 0.5
	var should_move = false

	if is_repositioning:
		if dist > ideal_dist:
			should_move = true
		else:
			is_repositioning = false
	else:
		if dist > (ideal_dist + reposition_buffer):
			is_repositioning = true
			should_move = true

	if dist > weapon_reach:
		should_move = true
		is_repositioning = true

	if should_move:
		var dir_from_enemy = (attacker.global_position - target.global_position).normalized()
		var target_pos = target.global_position + (dir_from_enemy * collision_boundary)
		attacker.agent.target_position = target_pos
	else:
		attacker.agent.target_position = attacker.global_position
		attacker.velocity.x = move_toward(attacker.velocity.x, 0, attacker.move_speed)
		attacker.velocity.z = move_toward(attacker.velocity.z, 0, attacker.move_speed)
		attacker.anim_player.is_walking = false
		_rotate_towards_target(delta)

	if attack_timer > 0:
		attack_timer -= delta
		return

	if dist <= weapon_reach:
		_do_attack()

func _rotate_towards_target(delta):
	var dir_to_target = (target.global_position - attacker.global_position).normalized()
	dir_to_target.y = 0
	if dir_to_target.length_squared() > 0.001:
		var target_look = Basis.looking_at(dir_to_target, Vector3.UP)
		target_look = target_look.rotated(Vector3.UP, PI)
		var model = attacker.get_node("PlayerModel")
		model.basis = model.basis.slerp(target_look, delta * 10.0)

func _do_attack():
	if attacker == null or target == null:
		stop_attack()
		return

	attacker.start_attack()

	var weapon_id = EquipmentManager._get_equipped("weapon")
	var weapon = ItemDataBase.get_item(weapon_id)

	var base_damage := 5.0
	var strength_bonus := 0.0

	if weapon != null:
		base_damage = weapon.base_damage
		strength_bonus = weapon.strength

	var max_hit = base_damage * (1.0 + strength_bonus / 100.0)
	var dmg = randi_range(0, int(max_hit))

	if target.has_method("take_damage"):
		target.take_damage(dmg, attacker)
		var dmg_scene = preload("res://Scenes/damage_number_3d.tscn")
		var dmg_label = dmg_scene.instantiate()
		get_tree().current_scene.add_child(dmg_label)
		await get_tree().process_frame
		dmg_label.label.text = str(dmg)
		var spawn_pos = target.global_position + Vector3(0, 1.2, 0)
		dmg_label.global_position = spawn_pos

	if weapon != null:
		attack_timer = weapon.speed
	else:
		attack_timer = 2.4

func _get_radius(node: Node3D) -> float:
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			var scale_factor = max(node.scale.x, node.scale.z)
			if shape is CapsuleShape3D: return shape.radius * scale_factor
			if shape is CylinderShape3D: return shape.radius * scale_factor
			if shape is SphereShape3D: return shape.radius * scale_factor
			if shape is BoxShape3D: return (min(shape.size.x, shape.size.z) / 2.0) * scale_factor
	return 0.5

func connect_player(player):
	player.stop_interactions.connect(stop_attack)
