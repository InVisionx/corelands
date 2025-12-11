extends Node3D

@export var player_scene: PackedScene = preload("res://Player/player.tscn")

func _ready():
	# 1. SAFETY CHECK
	# We check if the string is empty.
	if ProfileManager.current_username == "":
		push_error("❌ No user logged in — returning to login.")
		get_tree().change_scene_to_file("res://Scenes/login.tscn")
		return

	print("🌍 Loading world for: ", ProfileManager.current_username)

	# 2. INSTANTIATE PLAYER
	var player = player_scene.instantiate()
	
	# 3. INJECT DATA
	# Set the Name (String)
	player.username = ProfileManager.current_username
	
	# Set the Stats/Inventory (Dictionary)
	# Note: You need to make sure your player.gd has a variable for this!
	if "stats" in player: 
		player.stats = ProfileManager.current_profile

	# 4. ADD TO SCENE
	add_child(player)

	# Optional: Set position
	if has_node("SpawnPoint"):
		player.global_position = $SpawnPoint.global_position
