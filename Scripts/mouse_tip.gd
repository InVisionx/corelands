extends Label

var blockers: Array = ["MiningZoneUI", "BankUI", "FurnanceUI"]

func _ready():
	# Hide it by default
	hide()
	
	# Make sure it doesn't block mouse clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta):
	pass
	#if visible:
		#var mouse_pos = get_viewport().get_mouse_position()
		#global_position = mouse_pos - size - Vector2(1, 1)

# Call this to show the tooltip
func display(text_to_show: String):
	for ui in blockers:
		if get_tree().root.find_child(ui, true, false): return
	text = text_to_show
	show()

# Call this to hide it
func stop_display():
	hide()
