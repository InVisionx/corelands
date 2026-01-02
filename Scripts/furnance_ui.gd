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
		# This "bind" trick passes the specific recipe data to the function when clicked
		btn.pressed.connect(_on_recipe_clicked.bind(recipe))
		recipe_list.add_child(btn)

# This runs when you click a specific recipe button
func _on_recipe_clicked(recipe_data):
	# 3. Clear the previous details (if any)
	for child in details_panel.get_children():
		child.queue_free()
	
	# 4. Show the Name (Header)
	var title = Label.new()
	title.text = "Crafting: " + recipe_data["name"]
	details_panel.add_child(title)
	
	# 5. Loop through inputs to show requirements
	# recipe_data["inputs"] looks like {"iron_ore": 1, "coal": 1}
	var inputs = recipe_data["inputs"]
	for item_name in inputs:
		var req_label = Label.new()
		var amount = inputs[item_name]
		req_label.text = "- Requires: " + str(amount) + " " + item_name
		
		# Optional: Check if player has enough and color it red/green?
		# req_label.modulate = Color.RED 
		
		details_panel.add_child(req_label)

	# 6. Add the actual "CRAFT" button at the bottom
	var craft_btn = Button.new()
	craft_btn.text = "SMELT!"
	# Connect this button to the actual crafting logic
	craft_btn.pressed.connect(_attempt_craft.bind(recipe_data))
	details_panel.add_child(craft_btn)

func _attempt_craft(recipe_data):
	# Assuming you have a reference to player inventory
	# For now, let's just print to console
	print("Trying to craft: ", recipe_data["name"])
	
	# This is where you'd call:
	# CraftingManager.craft_item(recipe_data, player.inventory)
