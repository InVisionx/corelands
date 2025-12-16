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

var anim: AnimationPlayer
var is_attacking = false


func _ready():
	npc = get_parent()
	movement = npc.get_node("NPCMovement")
	anim = npc.get_node(model + "/AnimationPlayer")

	anim.connect("animation_finished", Callable(self, "_on_anim_finished"))


func _physics_process(delta):
	if target == null:
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


func _on_damaged_by(attacker):
	start_combat(attacker)


func start_combat(attacker):
	npc.health_bar.visible = true
	target = attacker
	movement.is_wandering = false


func stop_combat():
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


func _on_anim_finished(anim_name):
	if anim_name == "Attack":
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
