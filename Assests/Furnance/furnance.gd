extends Clickable

@onready var ui_scene = preload("res://Scenes/furnance_ui.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(interaction_type)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func on_click(player) -> void:
	var ui = ui_scene.instantiate()
	player.get_node_or_null("UI_Layer").add_child(ui)

func _on_mouse_entered() -> void:
	MouseTip.get_node("Label").display(interact_text)


func _on_mouse_exited() -> void:
	MouseTip.get_node("Label").stop_display()
