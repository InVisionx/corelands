@tool
extends Node3D

@export var run_auto_name: bool = false : set = _on_run_auto_name_set

const CHUNK_SIZE = 128.0

# Add any node names here that you do NOT want renamed
var ignore_list = ["PaintManager", "WorldEnvironment", "DirectionalLight3D", "Player", "DebugManager"]

func _on_run_auto_name_set(value):
	if value == true:
		rename_chunks()
		run_auto_name = false

func rename_chunks():
	print("--- Starting Rename ---")
	var count = 0
	
	for child in get_children():
		# 1. Skip non-3D nodes
		if not child is Node3D:
			continue

		# 2. Skip specific utility nodes (The Fix)
		if child.name in ignore_list:
			print("Skipping utility node: ", child.name)
			continue
			
		# 3. Rename Logic
		var gx = round(child.global_position.x / CHUNK_SIZE)
		var gz = round(child.global_position.z / CHUNK_SIZE)
		
		var new_name = "Chunk_%d_%d" % [gx, gz]
		
		if child.name != new_name:
			child.name = new_name
			count += 1
				
	print("Renamed ", count, " chunks.")
	print("--- Done ---")
