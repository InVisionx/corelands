extends ItemData
class_name ArmorItem

func _init():
	item_type = ItemType.ARMOR
	
@export_file var armor_scene_path: String   # path to .tscn
@export var mesh_node_path: NodePath       # where the mesh is inside the scene

@export var defense: float = 0.0
@export var hide_body_parts := []  # array of strings like ["torso"]
