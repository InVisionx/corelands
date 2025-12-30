extends Node

const DAMAGE_NUM_SCENE = preload("res://Scenes/damage_number_3d.tscn")

var attacker = null
var target = null
var attack_timer := 0.0
var is_repositioning = false

func start_attack(player, npc):
	if attacker == null:
		attack_timer = 0.0
		
	attacker = player
	target = npc
	is_repositioning = false
	player.agent.target_position = npc.global_position

func stop_attack():
	if attacker:
		attacker.anim_player.is_attacking = false
		attacker.anim_player.anim_locked = false
		if attacker.agent:
			attacker.agent.target_position = attacker.global_position
		attacker.velocity = Vector3.ZERO

	attacker = null
	target = null
	is_repositioning = false

func process(delta):
	if attack_timer > -1.0: 
		attack_timer -= delta
		
	if attacker == null or target == null:
		return

	# Handle Dead/Removed Targets
	if target.is_dead or not target.is_inside_tree():
		if attacker.is_attack_anim_playing(): return
		stop_attack()
		return

	# Handle Locked Animation
	if attacker.anim_player.anim_locked:
		_rotate_towards_target(delta)
		attacker.velocity = Vector3.ZERO
		return

	# Distance Logic
	var p2 = Vector2(attacker.global_position.x, attacker.global_position.z)
	var t2 = Vector2(target.global_position.x, target.global_position.z)
	var dist = p2.distance_to(t2)

	var weapon_reach = target.interaction.interact_range
	var target_radius = _get_radius(target)
	var collision_boundary = 0.5 + target_radius + 0.1
	
	var should_move = false
	
	if dist > weapon_reach:
		should_move = true
	elif is_repositioning and dist > collision_boundary:
		should_move = true
	else:
		is_repositioning = false

	# Execution
	if should_move:
		var dir = (attacker.global_position - target.global_position).normalized()
		var target_pos = target.global_position + (dir * collision_boundary)
		attacker.agent.target_position = target_pos
	else:
		# Stopped / In Range
		attacker.agent.target_position = attacker.global_position
		attacker.velocity.x = move_toward(attacker.velocity.x, 0, attacker.move_speed)
		attacker.velocity.z = move_toward(attacker.velocity.z, 0, attacker.move_speed)
		attacker.anim_player.is_walking = false
		_rotate_towards_target(delta)
		
		if attack_timer <= 0:
			_do_attack()

func _do_attack():
	if attack_timer > 0: return
	if attacker == null or target == null: return

	var weapon_id = EquipmentManager._get_equipped("weapon")
	var weapon = ItemDataBase.get_item(weapon_id)

	var base_damage := 5.0
	var strength_bonus := 0.0
	var cooldown := 2.4

	if weapon != null:
		base_damage = weapon.base_damage
		strength_bonus = weapon.strength
		cooldown = weapon.speed

	# --- ANIMATION SPEED LOGIC ---
	var calculated_speed = 1.0
	var anim_name = "Scim_Attack" 
	
	if attacker.anim_player.has_animation(anim_name):
		var anim_len = attacker.anim_player.get_animation(anim_name).length
		
		# If weapon is faster than animation, speed up.
		# If weapon is slower, keep speed at 1.0 (chill/idle after anim).
		if cooldown < anim_len:
			calculated_speed = anim_len / cooldown
		else:
			calculated_speed = 1.0

	attacker.anim_player.attack_speed = calculated_speed
	attacker.start_attack()

	# --- DAMAGE LOGIC ---
	var max_hit = base_damage * (1.0 + strength_bonus / 100.0)
	var dmg = randi_range(0, int(max_hit))

	if target.has_method("take_damage"):
		target.take_damage(dmg, attacker)
		var dmg_label = DAMAGE_NUM_SCENE.instantiate()
		get_tree().current_scene.add_child(dmg_label)
		dmg_label.label.text = str(dmg)
		dmg_label.global_position = target.global_position + Vector3(0, 1.2, 0)

	# --- TIMER LOGIC (Fix drift) ---
	attack_timer += cooldown

func _rotate_towards_target(delta):
	if attacker == null or target == null: return
	var dir = (target.global_position - attacker.global_position).normalized()
	dir.y = 0
	if dir.length_squared() > 0.001:
		var target_look = Basis.looking_at(dir, Vector3.UP)
		target_look = target_look.rotated(Vector3.UP, PI)
		var model = attacker.get_node("PlayerModel")
		model.basis = model.basis.slerp(target_look, delta * 10.0)

func _get_radius(node: Node3D) -> float:
	for child in node.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			var scale_factor = max(node.scale.x, node.scale.z)
			if shape is CapsuleShape3D or shape is CylinderShape3D or shape is SphereShape3D:
				return shape.radius * scale_factor
			if shape is BoxShape3D:
				return (min(shape.size.x, shape.size.z) / 2.0) * scale_factor
	return 0.5

func connect_player(player):
	player.stop_interactions.connect(stop_attack)
