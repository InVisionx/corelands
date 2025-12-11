extends Node3D

@export var username: String = ""

# --- UI ---
@onready var part_select: OptionButton = $CanvasLayer/PartSelect
@onready var color_select: OptionButton = $CanvasLayer/ColorSelect
@onready var confirm_button: Button = $CanvasLayer/ConfirmButton

# --- Player Mesh References ---
@onready var hair = $PlayerCustomize/Skeleton3D/hair
@onready var shirt = $PlayerCustomize/Skeleton3D/shirt
@onready var arm_bands = $PlayerCustomize/Skeleton3D/arm_bands
@onready var pants = $PlayerCustomize/Skeleton3D/pants
@onready var shoes = $PlayerCustomize/Skeleton3D/shoes

# --- State ---
var current_part_name: String = ""
var mesh_to_mat: Dictionary = {}
var appearance: Dictionary = {}  # stores chosen look

# --- Hair tint options ---
var hair_colors = {
	"Black": Color(0, 0, 0),
	"Brown": Color(0.25, 0.15, 0.05),
	"Blonde": Color(0.9, 0.8, 0.5)
}

# --- Shared cloth materials ---
var shared_materials = {
	"Black": preload("res://Materials/Cloths/black_cloth.tres"),
	"Blue": preload("res://Materials/Cloths/blue_cloth.tres"),
	"Grey": preload("res://Materials/Cloths/grey_cloth.tres"),
	"Orange": preload("res://Materials/Cloths/orange_cloth.tres"),
	"Purple": preload("res://Materials/Cloths/purple_cloth.tres"),
	"Red": preload("res://Materials/Cloths/red_cloth.tres"),
	"Tan": preload("res://Materials/Cloths/tan_cloth.tres"),
	"White": preload("res://Materials/Cloths/white_cloth.tres")
}

# ----------------------------
# Ready
# ----------------------------
func _ready() -> void:
	# Build mesh/material index map AFTER nodes are ready
	mesh_to_mat = {
		"Hair": {"mesh": hair, "mat": 0},
		"Shirt": {"mesh": shirt, "mat": 0},
		"Arm Bands": {"mesh": arm_bands, "mat": 0},
		"Pants": {"mesh": pants, "mat": 0},
		"Kilt": {"mesh": pants, "mat": 2},
		"Shoes": {"mesh": shoes, "mat": 0}
	}

	# Connect popup signals so re-selecting same item still fires
	part_select.get_popup().connect("id_pressed", Callable(self, "_on_part_id_pressed"))
	color_select.get_popup().connect("id_pressed", Callable(self, "_on_color_id_pressed"))
	confirm_button.connect("pressed", Callable(self, "_on_confirm_pressed"))

	# Populate part dropdown
	for part_name in mesh_to_mat.keys():
		part_select.add_item(part_name)

	# Auto-select first part (Hair) and populate colors
	part_select.select(0)
	_on_part_selected(0)
	if color_select.item_count > 0:
		color_select.select(0)
		_on_color_selected(0)

	# Start disabled until all parts are set
	confirm_button.disabled = true

	if has_node("Label3D"):
		$Label3D.text = username


# ----------------------------
# Handle same-item clicks
# ----------------------------
func _on_part_id_pressed(id: int) -> void:
	part_select.select(id)
	_on_part_selected(id)

func _on_color_id_pressed(id: int) -> void:
	color_select.select(id)
	_on_color_selected(id)


# ----------------------------
# When a body part is selected
# ----------------------------
func _on_part_selected(index: int) -> void:
	current_part_name = part_select.get_item_text(index)
	color_select.clear()

	if current_part_name == "Hair":
		for _name in hair_colors.keys():
			color_select.add_item(_name)
	else:
		for _name in shared_materials.keys():
			color_select.add_item(_name)

	if color_select.item_count > 0:
		color_select.select(0)
		_on_color_selected(0)


# ----------------------------
# When a color/material is chosen
# ----------------------------
func _on_color_selected(index: int) -> void:
	if current_part_name == "":
		return

	var mesh_info = mesh_to_mat[current_part_name]
	var mesh = mesh_info["mesh"]
	var mat_index = mesh_info["mat"]
	var selected = color_select.get_item_text(index)

	if mesh == null:
		push_error("❌ Mesh not found for part: " + current_part_name)
		return

	if current_part_name == "Hair":
		var color = hair_colors[selected]
		var mat = mesh.get_active_material(mat_index)
		if mat == null:
			var base_mat = mesh.mesh.surface_get_material(mat_index)
			mat = base_mat.duplicate()
			mesh.set_surface_override_material(mat_index, mat)
		mat.albedo_color = color
		appearance[current_part_name] = {"color": selected}

	else:
		var mat_res = shared_materials[selected]
		mesh.set_surface_override_material(mat_index, mat_res)
		appearance[current_part_name] = {"material": selected}

	print("✅ Applied", selected, "to", current_part_name, "slot", str(mat_index))
	print("🧾 Appearance data:", appearance)

	# ✅ Check if all parts are set before enabling confirm
	_update_confirm_state()


# ----------------------------
# Check if all parts have been set
# ----------------------------
func _update_confirm_state() -> void:
	var all_set := true
	for part_name in mesh_to_mat.keys():
		if not appearance.has(part_name):
			all_set = false
			break
	confirm_button.disabled = not all_set


# ----------------------------
# Confirm button pressed
# ----------------------------
func _on_confirm_pressed() -> void:
	var appearance_data = get_appearance_data()

	# Get or create current profile
	var profile = ProfileManager.current_profile
	if profile.is_empty():
		profile = ProfileManager.load_profile(username)
	if profile.is_empty():
		profile = {"username": username}

	# Update and save
	profile["appearance"] = appearance_data
	ProfileManager.save_profile(username, profile)
	ProfileManager.current_profile = profile

	print("💾 Saved appearance for:", username)
	print(JSON.stringify(appearance_data, "\t"))

	# Load into world scene
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
	
	queue_free()


# ----------------------------
# Get appearance data for saving
# ----------------------------
func get_appearance_data() -> Array:
	var result: Array = []

	for part_name in mesh_to_mat.keys():
		if not appearance.has(part_name):
			continue

		var mesh_info = mesh_to_mat[part_name]
		var mat_index = mesh_info["mat"]
		var mesh_name = mesh_info["mesh"].name
		var entry = appearance[part_name]

		if entry.has("color"):
			var color_val: Color = hair_colors[entry["color"]]
			result.append({
				"mesh_name": mesh_name,
				"mat_index": mat_index,
				"type": "color",
				"value": [color_val.r, color_val.g, color_val.b]
			})
		elif entry.has("material"):
			var mat_path = shared_materials[entry["material"]].resource_path
			result.append({
				"mesh_name": mesh_name,
				"mat_index": mat_index,
				"type": "material",
				"value": mat_path
			})

	return result
