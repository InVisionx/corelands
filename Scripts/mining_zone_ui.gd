extends Control

# This is the signal the Barrier is listening for
signal tier_selected(tier)

@onready var button_container: VBoxContainer = $PanelContainer/VBoxContainer

func _ready() -> void:
	# 1. Get Unlock Data
	# (Using the safe check we discussed earlier just in case)
	var player_max_tier = 0
	if ProfileManager.current_profile.has("unlocks") and ProfileManager.current_profile["unlocks"].has("mining_zone_tier"):
		player_max_tier = ProfileManager.current_profile["unlocks"]["mining_zone_tier"]

	var i = 0 
	for child in button_container.get_children():
		if child is Button:
			child.set_meta("tier_id", i)
			
			# UI Visuals
			child.mouse_entered.connect(_on_any_button_entered.bind(child))
			child.mouse_exited.connect(_on_any_button_exited.bind(child))
			
			# THE CLICK: Connects to our function below
			child.pressed.connect(_on_tier_button_pressed.bind(i))

			# Logic: Lock or Unlock
			if i > player_max_tier:
				child.disabled = true
				child.modulate = Color(0.5, 0.5, 0.5, 0.5)
				child.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			else:
				child.disabled = false
				child.modulate = Color(1, 1, 1, 1)
				child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			i += 1

func _on_any_button_entered(button_node: Button) -> void:
	if not button_node.disabled:
		button_node.modulate = Color(1.353, 1.353, 1.353, 1.0)
		button_node.add_theme_font_size_override("font_size", 20)

func _on_any_button_exited(button_node: Button) -> void:
	if not button_node.disabled:
		button_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button_node.add_theme_font_size_override("font_size", 16)

func _on_tier_button_pressed(tier_index: int) -> void:
	#print("⚔️ Button Pressed! Emitting Signal for Tier: ", tier_index)
	emit_signal("tier_selected", tier_index)
	
	queue_free()
