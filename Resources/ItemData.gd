extends Resource
class_name ItemData

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var stackable: bool = false
@export var prefab: PackedScene

# New: item category
enum ItemType { GENERIC, WEAPON, ARMOR, CONSUMABLE, MATERIAL }
@export var item_type: ItemType = ItemType.GENERIC

@export var description: String = ""

# Optional: only used by equipment items
@export var equip_slot: String = ""
