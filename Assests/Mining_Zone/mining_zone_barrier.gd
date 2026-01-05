extends Clickable

signal spawn_tier(index)

@onready var ui_scene: PackedScene = preload("res://Scenes/mining_zone_ui.tscn")
@onready var base_spawn: Marker3D = $"../../BaseSpawn"
@onready var arena_spawn: Marker3D = $"../../ArenaSpawn"

var body = null

func _ready() -> void:
	add_to_group(interaction_type)

func _process(_delta: float) -> void:
	pass

func on_click(player):
	body = player
	
	if body.in_mine_zone:
		# --- LEAVING ---
		# Skip the UI entirely. Just get us out of here.
		# We pass -1 because the index doesn't matter when leaving.
		perform_teleport(-1)
	else:
		# --- ENTERING ---
		# Show the UI so we can pick a tier.
		var ui = ui_scene.instantiate()
		ui.tier_selected.connect(perform_teleport)
		player.get_node_or_null("UI_Layer").add_child(ui)

func perform_teleport(index):
	var target_pos = Vector3.ZERO
	
	if !body.in_mine_zone:
		# --- ENTERING LOGIC ---
		print("⚔️ Entering Mine. Spawning Tier: ", index)
		
		# ONLY emit this if we are actually starting a round!
		emit_signal("spawn_tier", index) 
		
		target_pos = arena_spawn.global_position
	else:
		# --- LEAVING LOGIC ---
		print("🏃 Exiting Mine.")
		# Do NOT emit spawn_tier here.
		
		target_pos = base_spawn.global_position
	
	# --- MOVEMENT LOGIC ---
	
	# 1. Move Player Instantly
	body.global_position = target_pos
	
	# 2. Update Navigation Agent
	if body.get("agent"): 
		body.agent.target_position = target_pos
	
	# 3. Stop Momentum
	if body.has_method("set_velocity"):
		body.set_velocity(Vector3.ZERO)
	
	# 4. Fix Godot 4 Visuals (Reset Interpolation)
	if body.has_method("reset_physics_interpolation"):
		body.reset_physics_interpolation()

	var camera = body.get_viewport().get_camera_3d()
	if camera and camera.has_method("reset_physics_interpolation"):
		camera.reset_physics_interpolation()

func _on_mouse_entered() -> void:
	MouseTip.get_node("Label").display(interact_text)

func _on_mouse_exited() -> void:
	MouseTip.get_node("Label").stop_display()
