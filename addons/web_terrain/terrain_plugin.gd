@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/web_terrain/terrain_dock.tscn")

var dock_instance

func _enter_tree():
	# 1. Create the Dock
	dock_instance = DOCK_SCENE.instantiate()
	
	# 2. Add it to bottom panel PERMANENTLY (not just when selected)
	add_control_to_bottom_panel(dock_instance, "Terrain Tool")
	
	# 3. Try to find the tool node immediately
	_find_and_connect_tool()
	
	# 4. Listen for scene changes (so if you load a new level, it reconnects)
	scene_changed.connect(_on_scene_changed)

func _exit_tree():
	if dock_instance:
		remove_control_from_bottom_panel(dock_instance)
		dock_instance.queue_free()

func _on_scene_changed(scene_root):
	_find_and_connect_tool()

# --- THE AUTO-FINDER ---
func _find_and_connect_tool():
	# Get the root of the currently open scene
	var root = EditorInterface.get_edited_scene_root()
	if not root:
		return
		
	# Helper to recursively search for the node
	var tool_node = _find_node_by_type(root, "TerrainTool3D")
	
	if tool_node:
		print("Terrain Plugin: Found tool node: ", tool_node.name)
		dock_instance.set_terrain_node(tool_node)
	else:
		print("Terrain Plugin: No TerrainTool3D node found in this scene.")
		dock_instance.set_terrain_node(null)

# Recursive search function
func _find_node_by_type(node, type_name):
	if node.get_class() == type_name or (node.get_script() and node is TerrainTool3D):
		return node
	
	for child in node.get_children():
		var found = _find_node_by_type(child, type_name)
		if found:
			return found
	return null
