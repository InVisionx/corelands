extends Control

# References to your containers
@onready var recipe_list = $PanelContainer/HBoxContainer/RecipeList
@onready var details_panel = $PanelContainer/HBoxContainer/DetailsPanel

func _ready():
	# 1. Grab furnace recipes from the Manager
	var recipes = CraftingManager.get_recipes_by_station("furnace")
	
	# 2. Loop through and make buttons
	for recipe in recipes:
		var btn = Button.new()
		btn.text = recipe["name"]
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.flat = true
		# This "bind" trick passes the specific recipe data to the function when clicked
		btn.pressed.connect(_on_recipe_clicked.bind(recipe))
		recipe_list.add_child(btn)

# This runs when you click a specific recipe button
func _on_recipe_clicked(recipe_data):
	# 3. Clear previous details
	for child in details_panel.get_children():
		child.queue_free()

	# --- CONTAINER SETUP ---
	var content_box = VBoxContainer.new()
	# Expands to fill vertical space above button
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Centers children vertically and horizontally
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	# Adds a tiny gap between the title, header, and items for readability
	content_box.add_theme_constant_override("separation", 5) 
	details_panel.add_child(content_box)
	
	# 4. Show the Name (Header)
	var title = Label.new()
	title.text = "Crafting: " + recipe_data["name"] + "\n"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_box.add_child(title)
	
	# 5. Show "Requires" Header (RichTextLabel)
	var _req_label = RichTextLabel.new()
	
	# REQUIRED for [u] and [center] tags to work
	_req_label.bbcode_enabled = true 
	# REQUIRED so the label doesn't collapse to 0 height
	_req_label.fit_content = true 
	
	_req_label.add_theme_font_size_override("normal_font_size", 14)
	_req_label.text = "[center][u]Requires[/u][/center]"
	
	content_box.add_child(_req_label)

	# 6. Loop through inputs
	var inputs = recipe_data["inputs"]
	for item_name in inputs:
		var req_label = Label.new()
		req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		req_label.add_theme_font_size_override("font_size", 12)
		req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var amount = inputs[item_name]
		req_label.text = str(amount) + " " + item_name
		content_box.add_child(req_label)

	# 7. Add the "SMELT!" Button (Outside the centered box, at the bottom)
	var craft_btn = Button.new()
	craft_btn.text = "SMELT!"
	craft_btn.flat = true
	# Adding a minimum height makes the button easier to click
	craft_btn.custom_minimum_size.y = 40 
	craft_btn.pressed.connect(_attempt_craft.bind(recipe_data))
	details_panel.add_child(craft_btn)

func _attempt_craft(recipe_data):
	# Assuming you have a reference to player inventory
	# For now, let's just print to console
	print("Trying to craft: ", recipe_data["name"])
	
	# This is where you'd call:
	# CraftingManager.craft_item(recipe_data, player.inventory)

# --- NEW: INPUT HANDLING ---
func _input(event):
	# "ui_cancel" maps to Escape by default in Godot
	if event.is_action_pressed("ui_cancel"):
		queue_free()
