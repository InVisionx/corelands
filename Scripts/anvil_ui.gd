extends Control

# References to your containers
@onready var recipe_list = $PanelContainer/HBoxContainer/RecipeList
@onready var details_panel = $PanelContainer/HBoxContainer/DetailsPanel

# We keep track of the currently selected recipe to refresh the UI after crafting
var current_recipe_id: String = ""
var current_recipe_data: Dictionary = {}

func _ready():
	_populate_list()
	# Optional: Listen for inventory changes to update the UI in real-time
	InventoryManager.inventory_updated.connect(_on_inventory_updated)

func _populate_list():
	# Clear existing children if we ever re-run this
	for child in recipe_list.get_children():
		child.queue_free()

	# 1. Grab recipes directly so we have the ID (Key) and the Data (Value)
	var all_recipes = CraftingManager.recipes
	
	for id in all_recipes:
		var data = all_recipes[id]
		
		# Filter for furnace only
		if data["station"] == "anvil":
			var btn = Button.new()
			btn.text = ItemDataBase.get_display_name(data["output"])
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			# We bind both the ID and the Data
			btn.pressed.connect(_on_recipe_clicked.bind(id, data))
			recipe_list.add_child(btn)

# This runs when you click a specific recipe button
func _on_recipe_clicked(id: String, data: Dictionary):
	current_recipe_id = id
	current_recipe_data = data
	_refresh_details_panel()

func _refresh_details_panel():
	if current_recipe_id == "": return

	# 1. Clear previous details
	for child in details_panel.get_children():
		child.queue_free()

	# --- CONTAINER SETUP ---
	var content_box = VBoxContainer.new()
	content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_box.alignment = BoxContainer.ALIGNMENT_CENTER
	content_box.add_theme_constant_override("separation", 5) 
	details_panel.add_child(content_box)
	
	# 2. Show the Name (Header)
	var title = Label.new()
	title.text = ItemDataBase.get_display_name(current_recipe_data["output"]) + "\n"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	content_box.add_child(title)
	
	# 2.5 icon
	var icon = TextureRect.new()
	icon.texture = ItemDataBase.get_icon(current_recipe_data["output"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0,64)
	content_box.add_child(icon)
	
	# 3. Show "Requires" Header
	var req_header = Label.new()
	req_header.text = "- Requires -"
	req_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	req_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	content_box.add_child(req_header)

	# 4. Loop through inputs
	var inputs = current_recipe_data["inputs"]
	
	for item_id in inputs:
		var amount_needed = inputs[item_id]
		# Ask the Helper function we wrote in CraftingManager how many we actually have
		var amount_have = CraftingManager._get_total_item_count(item_id)
		
		var req_label = Label.new()
		req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Color code: Green if we have enough, Red if we don't
		var color = Color.GREEN if amount_have >= amount_needed else Color.RED
		req_label.add_theme_color_override("font_color", color)
		
		# Display: "Bone Ore: 1 / 5"
		var item_name_display = ItemDataBase.get_item(item_id).display_name if ItemDataBase.get_item(item_id) else item_id
		req_label.text = "%s: %d / %d" % [item_name_display, amount_have, amount_needed]
		
		content_box.add_child(req_label)

	# 5. Add the "SMELT!" Button
	var craft_btn = Button.new()
	craft_btn.text = "SMELT!"
	craft_btn.custom_minimum_size.y = 40 
	
	# CHECK IF WE CAN CRAFT
	var can_craft = CraftingManager.can_craft(current_recipe_id)
	
	if can_craft:
		craft_btn.disabled = false
		craft_btn.pressed.connect(_attempt_craft)
	else:
		craft_btn.disabled = true
		craft_btn.text = "Missing Materials"
		
	details_panel.add_child(craft_btn)

func _attempt_craft():
	if current_recipe_id == "": return
	
	# 1. Run the logic
	CraftingManager.craft_item(current_recipe_id)
	
	# 2. Refresh the UI immediately so numbers update and button disables if we run out
	_refresh_details_panel()

# If the inventory changes while the window is open (e.g. dropping something), update UI
func _on_inventory_updated():
	if current_recipe_id != "":
		_refresh_details_panel()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		queue_free()
