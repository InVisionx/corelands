extends Area3D

@export var monster_scene: PackedScene
@export var spawn_markers_container: Node3D

var tier = 0
var zone_active = false
var spawned_monsters = [] 
var current_rock = null 

# --- ROCK VISUAL CONFIGURATION ---
var tier_data = {
	# --- TIER 0: GREY (Standard) ---
	0: { 
		"color": Color("7a8a99"), # Blue-Grey Steel
		"met": 1.0, "rgh": 0.6, "emit": 0.0, 
		"loot": "steelore" 
	},

	# --- TIER 1: GREEN (Uncommon) ---
	1: { 
		"color": Color("586358"), # Murky Moss Green
		"met": 0.6, "rgh": 0.8, "emit": 0.0, 
		"loot": "viridiumore" 
	},

	# --- TIER 2: BLUE (Rare) ---
	2: { 
		"color": Color("4b7b8c"), # Icy Blue
		"met": 0.9, "rgh": 0.3, "emit": 0.5, 
		"loot": "glaciteore" 
	},

	# --- TIER 3: RED (Epic) ---
	3: { 
		"color": Color("8c2d2d"), # Deep Blood Red
		"met": 0.8, "rgh": 0.5, "emit": 1.0, 
		"loot": "pyriumore" 
	},

	# --- TIER 4: ORANGE (Legendary) ---
	4: { 
		"color": Color("CC5500"), # Burnt Orange (Updated)
		"met": 1.0, "rgh": 0.2, "emit": 1.5, # Reduced to 1.5
		"loot": "igneousore" 
	},

	# --- TIER 5: PURPLE (Mythic) ---
	5: { 
		"color": Color("5d3a66"), # Deep Void Purple
		"met": 0.7, "rgh": 0.4, "emit": 1.5, # Reduced to 1.5
		"loot": "umbriteore" 
	},

	# --- TIER 6: WHITE (Godly) ---
	6: { 
		"color": Color("dcdcdc"), # Pure White/Silver
		"met": 1.0, "rgh": 0.1, "emit": 8.0, 
		"loot": "astraliteore" 
	}
}

func _ready():
	var barrier = get_parent().find_child("BarrierBody", true, false)

	if barrier:
		print("✅ Found Barrier: ", barrier)
		barrier.spawn_tier.connect(set_tier)
	else:
		print("❌ Could not find BarrierBody")
	
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player") or body.is_in_group("player"):
		if "in_mine_zone" in body:
			body.in_mine_zone = true
			
		if not zone_active:
			spawn_wave(tier)
			zone_active = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player") or body.is_in_group("player"):
		if "in_mine_zone" in body:
			body.in_mine_zone = false
			clear_room()

func spawn_wave(_tier):
	print("spawning wave for tier : ", _tier)
	if not monster_scene or not spawn_markers_container:
		return
		
	spawned_monsters.clear()
	
	for marker in spawn_markers_container.get_children():
		if marker is Marker3D or marker is Node3D:
			var mob = monster_scene.instantiate()
			get_tree().current_scene.add_child(mob)
			mob.global_position = marker.global_position
			mob.spawn_position = marker.global_position
			
			var combat_ai = mob.find_child("NPCCombatAI", true, false)
			if combat_ai:
				combat_ai.aggressive = true
				combat_ai.aggro_range = 100.0 
				combat_ai.chase_max_distance = 100.0
			
			if mob.has_signal("died_event"):
				mob.died_event.connect(_on_monster_died)
				
			spawned_monsters.append(mob)

func _on_monster_died(_mob_who_died):
	var roll = randf()
	var chance = 1.0 # Guaranteed drop for testing
	
	if roll <= chance:
		print("🎉 SUCCESSFUL ROLL! Clearing Room!")
		var max_tier = ProfileManager.current_profile["unlocks"]["mining_zone_tier"]
		if max_tier == tier:
			ProfileManager.current_profile["unlocks"]["mining_zone_tier"] = tier + 1
			print("unlocked tier : ", tier + 1)
			ProfileManager.save_profile()
		
		clear_room_monsters_only() 
		spawn_rock(tier)
	else:
		print("❌ Roll Failed. Continuing fight...")

func clear_room():
	print("🧹 Cleaning up Room (Monsters + Rock)")
	
	for mob in spawned_monsters:
		if is_instance_valid(mob):
			mob.queue_free()
	spawned_monsters.clear()
	
	if is_instance_valid(current_rock):
		current_rock.queue_free()
		current_rock = null
		
	zone_active = false

func clear_room_monsters_only():
	for mob in spawned_monsters:
		if is_instance_valid(mob):
			mob.queue_free()
	spawned_monsters.clear()

func set_tier(index) -> void:
	print("manager got the signal and the tier is : ", index)
	tier = index

# --- VISUALS HELPER ---
func configure_rock_visuals(rock_instance, tier_index):
	var data = tier_data.get(tier_index, tier_data[0])
	
	var mesh_node = rock_instance.get_node_or_null("Mesh_0")
	
	if mesh_node:
		var new_mat = mesh_node.get_active_material(0).duplicate()
		new_mat.set_shader_parameter("ore_color", data["color"])
		new_mat.set_shader_parameter("ore_metallic", data["met"])
		new_mat.set_shader_parameter("ore_roughness", data["rgh"])
		new_mat.set_shader_parameter("ore_emission_strength", data["emit"])
		mesh_node.set_surface_override_material(0, new_mat)
		print("💎 Applied Visuals for Tier: ", tier_index)
	else:
		print("❌ Error: Could not find Mesh_0 in rock scene")

# --- ROCK SPAWNING ---
func spawn_rock(index) -> void:
	var rock_spawn = get_parent().find_child("RockSpawn", true, false)
	var rock_scene = preload("res://Assests/Mining_Zone/ore_rock.tscn")
	var rock = rock_scene.instantiate()
	
	# 1. Add to Scene
	rock_spawn.get_parent().add_child(rock)
	current_rock = rock
	
	# --- FIX IS HERE ---
	# We get the data for this tier
	var data = tier_data.get(index, tier_data[0])
	
	# Try to find the interactive node (OreRock) and set the 'gather_id'
	var interactive_node = rock.get_node_or_null("Mesh_0/OreRock")
	if interactive_node:
		# Correct Syntax: directly assign the variable
		interactive_node.gather_id = data["loot"] 
		print("💰 Loot Set To: ", data["loot"])
	else:
		print("❌ Could not find node 'OreRock' to set loot!")
	
	# 2. Apply Visuals
	configure_rock_visuals(rock, index)
	
	# 3. Calculate Height (AABB Logic)
	var final_y = rock_spawn.global_position.y
	var mesh = rock.get_node_or_null("Mesh_0")
	if mesh:
		var aabb = mesh.get_aabb()
		var offset_from_floor = -aabb.position.y * mesh.scale.y
		final_y += offset_from_floor
	
	# 4. Set Start Position (Underground)
	var start_pos = rock_spawn.global_position
	start_pos.y = final_y - 4.0 
	rock.global_position = start_pos
	
	# 5. Player Safety Push
	var player = get_tree().get_first_node_in_group("local_player")
	if not player:
		player = get_tree().get_first_node_in_group("player")
		
	if player:
		var dist = player.global_position.distance_to(rock_spawn.global_position)
		var safe_radius = 3.0 
		
		if dist < safe_radius:
			print("⚠️ Player too close! Pushing away...")
			var push_dir = (player.global_position - rock_spawn.global_position).normalized()
			push_dir.y = 0
			push_dir = push_dir.normalized()
			if push_dir == Vector3.ZERO:
				push_dir = Vector3.BACK 
			var target_pos = rock_spawn.global_position + (push_dir * safe_radius)
			target_pos.y = player.global_position.y 
			
			var p_tween = create_tween()
			p_tween.set_trans(Tween.TRANS_CUBIC)
			p_tween.set_ease(Tween.EASE_OUT)
			p_tween.tween_property(player, "global_position", target_pos, 0.8)

	# 6. Tween the Rock Up
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(rock, "global_position:y", final_y, 1.5)
