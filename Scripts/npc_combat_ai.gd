extends Node

var npc: CharacterBody3D
var movement
var target = null
var attack_timer := 0.0

@export var model: String
@export var attack_speed := 2.0
@export var attack_range := 1.8
@export var base_damage := 5
@export var chase_max_distance := 15.0   # leash range

# --- NEW AGGRESSION VARIABLES ---
@export var aggressive: bool = false
@export var aggro_range: float = 10.0

var anim: AnimationPlayer
var is_attacking = false


func _ready():
	npc = get_parent()
	movement = npc.get_node("NPCMovement")
	anim = npc.get_node(model + "/AnimationPlayer")

	anim.connect("animation_finished", Callable(self, "_on_anim_finished"))


func _physics_process(delta):
	if "is_dead" in npc and npc.is_dead: return
	
	# 1. NEW: If we have no target but are aggressive, look for one
	if target == null:
		if aggressive:
			_scan_for_targets()
		return

	if not target.is_inside_tree():
		stop_combat()
		movement.return_to_last_wander_point()
		return

	attack_timer -= delta

	var dist = npc.global_position.distance_to(target.global_position)

	# LEASH CHECK — player ran too far
	if dist > chase_max_distance:
		stop_combat()
		movement.return_to_last_wander_point()
		return

	# Freeze movement during attack
	if is_attacking:
		_face_target(delta)
		npc.velocity = Vector3.ZERO
		return

	# CHASE
	if dist > attack_range:
		_chase()
		return

	# ATTACK
	_face_target(delta)
	_attack_if_ready()


# --- NEW: SCANNER FUNCTION ---
func _scan_for_targets():
	# Get all players in the level
	var players = get_tree().get_nodes_in_group("player")
	# Also check specifically for local player if not in that group for some reason
	players.append_array(get_tree().get_nodes_in_group("local_player"))
	
	var closest_player = null
	var closest_dist = aggro_range

	for p in players:
		if not is_instance_valid(p): continue
		
		var dist = npc.global_position.distance_to(p.global_position)
		if dist < closest_dist:
			closest_player = p
			closest_dist = dist
	
	# If we found someone close enough, ATTACK!
	if closest_player:
		start_combat(closest_player)


func _on_damaged_by(attacker):
	start_combat(attacker)


func start_combat(attacker):
	if npc.health_bar:
		npc.health_bar.visible = true
	target = attacker
	movement.is_wandering = false


func stop_combat():
	if npc.health_bar:
		npc.health_bar.visible = false
	target = null
	attack_timer = 0.0
	is_attacking = false
	movement.disabled = false
	movement.is_wandering = true


func _chase():
	if is_attacking:
		return
	movement.move_to(target.global_position)


func _face_target(delta):
	var dir = target.global_position - npc.global_position
	dir.y = 0
	if dir.length_squared() < 0.001:
		return

	var model_node = npc.get_node(model)
	var original_scale = model_node.scale

	var target_basis = Basis.looking_at(dir, Vector3.UP)
	target_basis = target_basis.rotated(Vector3.UP, PI)

	var current_quat = model_node.basis.orthonormalized().get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()

	var next_quat = current_quat.slerp(target_quat, delta * 10.0)
	model_node.basis = Basis(next_quat).scaled(original_scale)


func _attack_if_ready():
	if attack_timer > 0 or is_attacking:
		return

	is_attacking = true
	movement.disabled = true
	npc.velocity = Vector3.ZERO

	npc.get_node("NavigationAgent3D").target_position = npc.global_position
	anim.play("Attack")
	attack_timer = attack_speed

##########HELPER TO CHECK TRACKS##################
# Helper to check if an animation calls a specific function
func _animation_has_method_call(animation_name: String, method_to_check: String) -> bool:
	if not anim.has_animation(animation_name):
		return false
		
	var animation_res = anim.get_animation(animation_name)
	
	for track_idx in range(animation_res.get_track_count()):
		if animation_res.track_get_type(track_idx) != Animation.TYPE_METHOD:
			continue
			
		for key_idx in range(animation_res.track_get_key_count(track_idx)):
			var key_data = animation_res.track_get_key_value(track_idx, key_idx)
			
			if key_data.get("method") == method_to_check:
				return true # Found it!
				
	return false # Scanned everything, didn't find it
	
func _on_anim_finished(anim_name):
	if anim_name == "Attack":
		if not _animation_has_method_call(anim_name, "_deal_attack_damage"):
			_deal_attack_damage()
			
		is_attacking = false
		movement.disabled = false

		await get_tree().process_frame
		npc.velocity = Vector3.ZERO
		
func _deal_attack_damage():
	if target and target.has_method("take_damage"):
		var dmg = randi_range(0, base_damage)
		target.take_damage(dmg, npc)


# ---------------------------------------------------------
# NEW — Allow respawn to reset NPC combat logic
# ---------------------------------------------------------
func reset_state():
	target = null
	is_attacking = false
	attack_timer = 0.0
	movement.disabled = false
	movement.is_wandering = true
