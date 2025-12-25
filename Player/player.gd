extends CharacterBody3D

signal stop_interactions

@export var username: String = ""
@export var move_speed: float = 4.0
@export var rotation_speed: float = 10.0      # Controls turning smoothness
@export var face_offset_degrees: float = 0.0  # Adjust if player faces wrong way

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $PlayerModel/AnimationPlayer
@onready var interaction_manager = $InteractionManager

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	if multiplayer.get_unique_id() == get_multiplayer_authority():
		add_to_group("local_player")
		set_process_input(true)
	else:
		add_to_group("player")
		set_process_input(false)

	print("Spawned player:", username)

	InventoryManager.set_player(self)
	EquipmentManager.set_player(self)
	EquipmentManager.apply_equipped_items()
	CombatManager.connect_player(self)

	# NavigationAgent tuning – slightly looser so it doesn't jitter at high speed
	agent.path_desired_distance = 0.35
	agent.target_desired_distance = 0.2
	agent.avoidance_enabled = false   # avoid weird pushing

	anim_player.animation_finished.connect(_on_animation_finished)


func find_clickable(node):
	if node is Clickable:
		return node

	for child in node.get_children():
		var found = find_clickable(child)
		if found:
			return found

	var current = node.get_parent()
	for i in range(6):
		if current == null:
			return null
		if current is Clickable:
			return current
		for sibling in current.get_children():
			if sibling is Clickable:
				return sibling
		current = current.get_parent()

	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Click effect
		var click_2d_effect = preload("res://Scenes/click_effect.tscn")
		var fx2d = click_2d_effect.instantiate()
		$UI_Layer.add_child(fx2d)
		fx2d.position = event.position - fx2d.size * 0.5

		var camera := get_viewport().get_camera_3d()
		if not camera:
			return

		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000.0

		# Exclude the player collider so the ray doesn't hit the player capsule
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self.get_rid()]

		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return
		print("Ray hit: ", result.collider.name, " at ", result.position) # <--- ADD THIS

		var collider = result["collider"]
		var clickable = find_clickable(collider)
		if clickable:
			interaction_manager.handle_click_target(clickable)
			return

		if result.has("position"):
			interaction_manager.target = null
			
			emit_signal("stop_interactions")
			
			var click_pos: Vector3 = result.position

			# Snap click to nearest navmesh point so the agent can always find a path
			var nav_map = agent.get_navigation_map()
			var target_on_nav = NavigationServer3D.map_get_closest_point(nav_map, click_pos)

			agent.target_position = target_on_nav
			anim_player.is_walking = true


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -1.0  # tiny downward push keeps glued to uneven Terrain3D

	if not agent.is_navigation_finished():
		if not anim_player.is_walking:
			anim_player.is_walking = true

		var next_pos: Vector3 = agent.get_next_path_position()
		var to_target: Vector3 = next_pos - global_position
		to_target.y = 0

		var dist := to_target.length()

		if dist > 0.01:
			var dir: Vector3 = to_target / dist

			# 🔒 Clamp movement so we never overshoot the current path point
			var max_step := move_speed * delta
			var step = min(max_step, dist)
			var frame_speed = step / delta  # actual speed this frame

			velocity.x = dir.x * frame_speed
			velocity.z = dir.z * frame_speed

			# ---- Smooth rotation toward movement direction ----
			var target_basis := Basis.looking_at(dir, Vector3.UP)
			target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(face_offset_degrees))
			$PlayerModel.basis = $PlayerModel.basis.slerp(target_basis, rotation_speed * delta)
		else:
			# Very close to this point; let agent advance to next
			velocity.x = move_toward(velocity.x, 0.0, move_speed)
			velocity.z = move_toward(velocity.z, 0.0, move_speed)
	else:
		# No path: idle and smoothly slow down
		anim_player.is_walking = false
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)

	move_and_slide()

	CombatManager.process(delta)

# ----------------------------------
# Combat / Teleport
# ----------------------------------
func start_attack():
	anim_player.is_attacking = true

func start_teleport():
	anim_player.is_teleporting = true
	$PlayerModel/Skeleton3D/WeaponAttach.visible = false

	var teleport_vfx = preload("res://Shaders/VFX/teleport_vfx.tscn").instantiate()
	add_child(teleport_vfx)


func _on_animation_finished(anim_name: String):
	if anim_name == "Teleport":
		# Keep the visual toggle here since the Player script handles Teleport VFX
		$PlayerModel/Skeleton3D/WeaponAttach.visible = true
		# We set the bool directly instead of calling a deleted function
		anim_player.anim_locked = false 

func is_attack_anim_playing() -> bool:
	return anim_player.current_animation.contains("Attack") \
		and anim_player.is_playing()

func take_damage(dmg, npc):
	pass
	#print("%s hit you for: %d" % [npc.name, dmg])


func _on_button_3_pressed() -> void:
	anim_player.is_mining = true
	


func _on_button_2_pressed() -> void:
	anim_player.is_teleporting = true
