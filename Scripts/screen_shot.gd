@tool
extends Node3D

# --- CONTROLS ---
@export_group("Baker Controls")
@export var start_baking: bool = false:
	set(value):
		if value:
			start_baking = false
			bake_all()

@export_group("Settings")
# Instead of an array, we just point to the folder
@export var source_folder: String = "res://Items/" 
@export var output_folder: String = "res://icons/"
@export var padding_factor: float = 1.1 

@onready var pivot = $SubViewportContainer/SubViewport/SpawnPivot
@onready var camera = $SubViewportContainer/SubViewport/Camera3D
@onready var viewport = $SubViewportContainer/SubViewport

func bake_all():
	print("\n--- STARTING ORTHO BAKE ---")
	
	if camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		printerr("ERROR: Camera must be set to ORTHOGONAL mode!")
		return

	# Ensure output directory exists
	var dir_access = DirAccess.open("res://")
	if not dir_access.dir_exists(output_folder):
		dir_access.make_dir(output_folder)

	# 1. GET ALL SCENES RECURSIVELY
	print("Scanning " + source_folder + " for .tscn files...")
	var scenes_to_bake = scan_for_scenes(source_folder)
	print("Found " + str(scenes_to_bake.size()) + " scenes to bake.")

	for scene_res in scenes_to_bake:
		if scene_res == null: continue

		# 2. SPAWN
		var instance = scene_res.instantiate()
		pivot.add_child(instance)
		
		# 3. ROTATE (RPG Style logic preserved)
		# We convert to lower ONCE here, so 'item_name' is clean
		var item_name = instance.name.to_lower() 

		if "cape" in item_name.to_lower() or "raw" in item_name.to_lower():
			pass 
		elif "sword" in item_name.to_lower() or "defender" in item_name.to_lower() or "scim" in item_name.to_lower():
			instance.rotation_degrees.z = -25 
		elif "bar" in item_name.to_lower():
			instance.rotation_degrees.y = 90 
			instance.rotation_degrees.z = 75
		else:
			instance.rotation_degrees.x = -20
			instance.rotation_degrees.y = 25

		# 4. FORCE UPDATE
		await get_tree().process_frame 
		
		# 5. FIT CAMERA
		fit_ortho_camera(instance)
		
		# 6. SAVE
		await get_tree().process_frame
		await get_tree().process_frame
		save_image(instance.name)
		
		instance.queue_free()
		await get_tree().process_frame

	print("--- BAKE COMPLETE ---\n")

# --- NEW RECURSIVE FUNCTION ---
func scan_for_scenes(path: String) -> Array[PackedScene]:
	var collected_scenes: Array[PackedScene] = []
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if dir.current_is_dir():
				# Recursively search subdirectories, ignoring hidden ones (like .godot)
				if not file_name.begins_with("."):
					var sub_path = path.path_join(file_name)
					collected_scenes.append_array(scan_for_scenes(sub_path))
			else:
				# Check for .tscn files
				if file_name.ends_with(".tscn"):
					var full_path = path.path_join(file_name)
					var res = load(full_path)
					if res is PackedScene:
						collected_scenes.append(res)
			
			file_name = dir.get_next()
	else:
		printerr("Could not open directory: " + path)
		
	return collected_scenes

func fit_ortho_camera(obj: Node3D):
	var aabb = get_visual_aabb(obj)
	if aabb.size == Vector3.ZERO: return

	var center = aabb.get_center()
	camera.global_position.x = center.x
	camera.global_position.y = center.y
	camera.global_position.z = center.z + 5.0 

	var max_size = max(aabb.size.x, aabb.size.y)
	camera.size = max_size * padding_factor

func get_visual_aabb(root: Node3D) -> AABB:
	var final_aabb: AABB
	var first = true
	
	var meshes = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	
	for mesh in meshes:
		var global_aabb = mesh.global_transform * mesh.get_aabb()
		if first:
			final_aabb = global_aabb
			first = false
		else:
			final_aabb = final_aabb.merge(global_aabb)
	return final_aabb

func save_image(item_name: String):
	var img = viewport.get_texture().get_image()
	# Clean up the name in case the scene file had a different casing or extra characters
	var clean_name = item_name.replace("@", "").replace("Node3D", "") 
	var filename = output_folder + "icon_" + clean_name + ".png"
	img.save_png(filename)
	print("Saved: " + filename)
