extends Node3D
class_name Clickable

@export_enum("interact", "gather", "enemy") var interaction_type: String = "interact"
@export_enum("none", "mine", "chop", "fish") var gather_subtype: String = "none"
@export var interact_range: float = 2.0
@export var interact_text: String = "Interact"

func interact(player):
	if get_parent().has_method("on_click"):
		get_parent().on_click(player)
		
func get_owner_npc():
	var current = self
	for i in range(6):
		if current == null:
			return null
		if current is CharacterBody3D:
			return current
		current = current.get_parent()
	return null


func _on_zombie_mouse_entered() -> void:
	MouseTip.get_node("Label").display(interact_text)


func _on_zombie_mouse_exited() -> void:
	MouseTip.get_node("Label").stop_display()
