extends Area3D

@export var monster_scene: PackedScene
@export var spawn_markers_container: Node3D

var zone_active = false
var spawned_monsters = [] # We keep track of them so we can delete them all later

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("local_player") or body.is_in_group("player"):
		if "in_mine_zone" in body:
			body.in_mine_zone = true
			
		if not zone_active:
			spawn_wave()
			zone_active = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("local_player") or body.is_in_group("player"):
		if "in_mine_zone" in body:
			body.in_mine_zone = false

func spawn_wave():
	if not monster_scene or not spawn_markers_container:
		return
		
	spawned_monsters.clear() # Reset list
	
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

func _on_monster_died(mob_who_died):
	# --- THE ROLL ---
	var roll = randf()
	var chance = 0.1
	
	if roll <= chance:
		print("🎉 SUCCESSFUL ROLL! Clearing Room!")
		clear_room()
	else:
		print("❌ Roll Failed. Continuing fight...")

func clear_room():
	print("🧹 Cleaning up ", spawned_monsters.size(), " monsters.")
	
	for mob in spawned_monsters:
		if is_instance_valid(mob):
			mob.queue_free()
	
	spawned_monsters.clear()
	zone_active = false
