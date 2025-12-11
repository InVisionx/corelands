extends ItemData
class_name WeaponItem

func _init():
	item_type = ItemType.WEAPON

@export var base_damage: float = 0.0
@export var accuracy: float = 0.0
@export var strength: float = 0.0
@export var is2h: bool = false
@export var speed: float = 2.4
@export var offhand: bool = false
