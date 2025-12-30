extends Node3D

@export var player_scene: PackedScene = preload("res://Player/player.tscn")

func _ready():
	# 1. SAFETY CHECK
	if ProfileManager.current_username == "":
		push_error("❌ No user logged in — returning to login.")
		get_tree().change_scene_to_file("res://Scenes/login.tscn")
		return

	print("🌍 Loading world for: ", ProfileManager.current_username)

	# 2. INSTANTIATE PLAYER
	var player = player_scene.instantiate()
	
	# 3. INJECT DATA
	player.username = ProfileManager.current_username
	
	if "stats" in player: 
		player.stats = ProfileManager.current_profile

	# 4. ADD TO SCENE
	add_child(player)
	
	# Optional: Set position
	if has_node("HubSpawn"):
		player.global_position = $HubSpawn.global_position
	else:
		player.global_position = Vector3(0,0,0)

	# -------------------------------------------------------------
	# 5. ZONE VISIBILITY INIT (Auto-hide non-Hub zones)
	# -------------------------------------------------------------
	var nav = find_child("Nav", true, false)
	
	if nav:
		for zone_folder in nav.get_children():
			# Check if this folder is the Hub
			var is_hub = (zone_folder.name == "Hub")
			
			# Since zone_folder is a plain Node, we must loop through 
			# its children (meshes/lights) and hide/show THEM.
			for item in zone_folder.get_children():
				if item is Node3D:
					item.visible = is_hub
				elif item is CanvasItem:
					item.visible = is_hub
	else:
		push_warning("Could not find 'Nav' node to initialize zones!")
