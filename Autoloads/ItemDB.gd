extends Node
class_name ItemDB

var items: Dictionary = {}

func _ready():
	_load_all_items("res://Items")

# -----------------------------
# 🔍 Recursive item loader
# -----------------------------
func _load_all_items(base_path: String):
	var dir := DirAccess.open(base_path)
	if not dir:
		push_error("❌ ItemDB: Could not open " + base_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_load_all_items(base_path + "/" + file_name)
		else:
			# 🛠️ WEB FIX START -------------------------
			# If exported, the file might look like "sword.tres.remap"
			# We need to strip that suffix to check the real extension.
			var clean_name = file_name
			if clean_name.ends_with(".remap"):
				clean_name = clean_name.trim_suffix(".remap")
			# ------------------------------------------

			if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
				# IMPORTANT: We load using the CLEAN name. 
				# Godot's internal loader handles the redirect from .tres -> .remap automatically.
				var path = base_path + "/" + clean_name
				var res: Resource = load(path)
				
				if res and res is ItemData and res.id != "":
					items[res.id] = res
					# Print strictly for debugging web (remove later)
					print("✅ Loaded: ", res.id) 
					
		file_name = dir.get_next()
	dir.list_dir_end()

# -----------------------------
# 📦 Lookup helpers
# -----------------------------
func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_icon(id: String) -> Texture2D:
	var item: ItemData = get_item(id)
	return item.icon if item and item.icon else null

func get_display_name(id: String) -> String:
	var item: ItemData = get_item(id)
	return item.display_name if item and item.display_name != "" else id
