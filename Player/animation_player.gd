extends AnimationPlayer

# Paths to your bone attachments
const WEAPON_ATTACH = "../Armature/GeneralSkeleton/WeaponAttach"
const OFFHAND_ATTACH = "../Armature/GeneralSkeleton/OffhandAttach"
# Your multipurpose axe/pickaxe scene
const AXE_SCENE = preload("res://Items/Resources/Gravewood_Axe/gravewood_pickaxe.tscn")
const TELEPORT_SCENE = preload("res://Shaders/VFX/teleport_vfx.tscn")

# Simple Booleans for your Player script to toggle
var has_2h: bool = false
var is_walking: bool = false
var anim_locked: bool = false 

# --- REACTIVE VARIABLE LOGIC ---

# When you set this to true, the axe spawns and the animation plays once.
var is_mining: bool = false:
	set(value):
		if value == is_mining: return 
		is_mining = value
		if is_mining:
			_run_axe_sequence("Mine")

# Same logic for attacking: setting this to true triggers the sequence.
var is_attacking: bool = false:
	set(value):
		if value == is_attacking: return
		is_attacking = value
		if is_attacking:
			_run_attack_sequence("Scim_Attack")
			
var is_teleporting: bool = false:
	set(value):
		if value == is_teleporting: return
		is_teleporting = value
		if is_teleporting:
			anim_locked = true
			
			# 1. Spawn VFX 
			# Using get_parent().get_parent() or owner ensures the VFX is in the world, 
			# not stuck inside the player's model hierarchy.
			var teleportvfx = TELEPORT_SCENE.instantiate()
			var root_node = get_tree().current_scene # Or use owner
			root_node.add_child(teleportvfx)
			teleportvfx.global_position = get_parent().global_position
			# 2. Trigger the burst
			# We check for both GPU and CPU particles just in case
			if teleportvfx is GPUParticles3D or teleportvfx is CPUParticles3D:
				teleportvfx.emitting = true
			else:
				# If your VFX scene is a Node3D with particle children
				for child in teleportvfx.get_children():
					if child is GPUParticles3D or child is CPUParticles3D:
						child.emitting = true
			
			# 2. Play Animation
			#play("Teleport")
			
			#await animation_finished
			
			anim_locked = false
			is_teleporting = false

# --- CORE LOOP ---

func _process(_delta):
	# If an action (mining/attacking) is happening, let it finish.
	if anim_locked: 
		return

	# Handle movement and idle states
	if is_walking:
		_play("Walk")
	else:
		_play("2H_Idle" if has_2h else "Idle")

# --- ACTION SEQUENCES ---

func _run_axe_sequence(anim_name: String):
	anim_locked = true
	set_weapons_visibility(false) # Hide equipped swords
	
	# 1. Spawn the Axe
	var axe_instance = AXE_SCENE.instantiate()
	get_node(WEAPON_ATTACH).add_child(axe_instance)
	
	# 2. Snap to the hand using the reference node in the axe scene
	var anim_ref = axe_instance.get_node_or_null("AnimTransform")
	if anim_ref:
		axe_instance.transform = anim_ref.transform

	# 3. Play Animation (Speed boost to hide DeepMotion jank)
	play(anim_name, -1, 1.8)
	seek(2.0, true) # Skip the first 2 seconds of the DeepMotion file

	await animation_finished

	# 4. Cleanup and Unlock
	if is_instance_valid(axe_instance): 
		axe_instance.queue_free()
	
	set_weapons_visibility(true) # Show swords again
	is_mining = false            # Reset the boolean
	anim_locked = false          # Return control to _process

func _run_attack_sequence(anim_name: String):
	anim_locked = true
	play(anim_name, 0.3) # 0.3s blend time for smooth combat
	
	await animation_finished
	
	is_attacking = false
	anim_locked = false

# --- UTILITY FUNCTIONS ---

func _play(anim_name: String, blend: float = -1.0, speed: float = 1.0):
	if current_animation == anim_name and is_playing():
		return
	play(anim_name, blend, speed)

func set_weapons_visibility(is_visible: bool):
	var paths = [WEAPON_ATTACH, OFFHAND_ATTACH]
	for path in paths:
		var node = get_node_or_null(path)
		if node:
			for child in node.get_children():
				if child is Node3D:
					child.visible = is_visible
					
