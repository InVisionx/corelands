extends Control

@onready var portal_vfx_scene: PackedScene = preload("res://Shaders/VFX/teleport_vfx.tscn")
@export var fade_overlay: ColorRect 

# We can assume owner is the player if this UI is inside Player.tscn
@onready var player: Node3D = owner 

func _ready() -> void:
	if fade_overlay:
		fade_overlay.visible = true 
		fade_overlay.modulate.a = 0.0 
	else:
		push_warning("⚠️ Teleport script is missing the Fade Overlay link!")

	# Safety check: Verify 'owner' actually found the player
	if not player:
		push_error("❌ Teleport UI could not find the Player! Is this script attached to a node inside Player.tscn?")
# -------------------------------------------------------------
# 🔹 Teleport with DELAYED FADE
# -------------------------------------------------------------
func teleport_player(target_pos: Vector3, facing_y_deg: float, zone_name: String) -> void:
	if not player:
		push_warning("⚠️ No player found for teleport!")
		return
		
	var anim = player.get_node_or_null("PlayerModel/AnimationPlayer")
	if anim:
		print("gonna try to play teleporting")
		anim.is_teleporting = true

	# A. Hide weapon/model
	var attach = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton/WeaponAttach")
	if attach: 
		attach.visible = false
	var offhand = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton/OffhandAttach")
	if offhand:
		offhand.visible = false
		
	# 1. Spawn VFX at current location
	# Let the player watch this for the full duration
	var portal_vfx = portal_vfx_scene.instantiate()
	get_tree().current_scene.add_child(portal_vfx)
	portal_vfx.global_position = player.global_position
	
	# 2. WAIT for VFX to finish (2 Seconds)
	await get_tree().create_timer(2.0).timeout
	
	# 3. Start Fading to BLACK (Now that VFX is done)
	var tween_out = create_tween()
	# Fade to black over 1.0 second
	tween_out.tween_property(fade_overlay, "modulate:a", 1.0, 1.0)
	
	# Wait for the fade to actually finish (1.0s)
	await tween_out.finished

	# ---------------------------------------------------------
	# 🔹 THE MOVE (Happens while screen is totally black)
	# ---------------------------------------------------------
	
	# B. Toggle Zone Visibility
	var nav_parent = get_tree().current_scene.find_child("Nav", true, false)
	if nav_parent:
		for zone_folder in nav_parent.get_children():
			var is_target_zone = (zone_folder.name == zone_name)
			for item in zone_folder.get_children():
				if item is Node3D: item.visible = is_target_zone
				elif item is CanvasItem: item.visible = is_target_zone

	# C. Move player & rotate
	player.global_position = target_pos
	player.rotation.y = deg_to_rad(facing_y_deg)
	
	# D. Restore weapon
	if attach: attach.visible = true
	if offhand: offhand.visible = true

	# ---------------------------------------------------------
	# 🔹 FADE BACK IN
	# ---------------------------------------------------------
	
	# Wait a tiny bit (0.5s) so the player feels "settled" in the darkness
	await get_tree().create_timer(0.5).timeout
	
	# Fade back to transparent
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "modulate:a", 0.0, 1.0) 

# -------------------------------------------------------------
# 🔹 Button Signals
# -------------------------------------------------------------

func _on_home_teleport_pressed() -> void:
	teleport_player(Vector3(-0.0, 0.0, 8.19), 0.0, "Hub")

func _on_tree_teleport_pressed() -> void:
	teleport_player(Vector3(-32.871, 0.0, 1.673), 0.0, "Tree")


func _on_mining_teleport_pressed() -> void:
	var marker = get_tree().current_scene.find_child("MineSpawn", true, false)
	if marker:
		var target_pos: Vector3 = marker.global_position
		teleport_player(target_pos, 0.0, "Mine")
	else:
		push_error("CRITICAL: Could not find 'MineSpawn' marker in the scene!")
