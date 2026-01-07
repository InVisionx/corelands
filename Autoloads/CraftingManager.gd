extends Node

# --- RECIPE DATABASE ---
var recipes = {
	"smelt_steelbar": {
		"name": "Steel Bar",
		"station": "furnace",
		"inputs": {"steelore" : 1},
		"output": "steelbar",
		"amount": 1,
		"time": 1.0
	},
	"smith_steel_scimitar": {
		"name": "steel_scimitar",
		"station": "anvil",
		"inputs": {"steelbar" : 1},
		"output": "steelscimitar",
		"amount": 1,
		"time": 1.0
	}
}

# --- 1. GET RECIPES ---
# Returns recipes for a specific station (unchanged)
func get_recipes_by_station(station_type: String) -> Array:
	var list = []
	for id in recipes:
		if recipes[id]["station"] == station_type:
			list.append(recipes[id])
	return list

# --- 2. CHECK REQUIREMENTS ---
# Checks if InventoryManager has enough total items across all slots
func can_craft(recipe_id: String) -> bool:
	if not recipes.has(recipe_id):
		printerr("Recipe not found: " + recipe_id)
		return false
		
	var needs = recipes[recipe_id]["inputs"]
	
	for item_id in needs:
		var amount_needed = needs[item_id]
		var amount_have = _get_total_item_count(item_id)
		
		if amount_have < amount_needed:
			return false
			
	return true

# --- 3. CONSUME ITEMS & ADD RESULT ---
# Removes items via InventoryManager and adds the result
func craft_item(recipe_id: String) -> void:
	if not can_craft(recipe_id):
		print("Cannot craft: Missing ingredients.")
		return 
	
	var needs = recipes[recipe_id]["inputs"]
	
	# A. Remove Ingredients
	for item_id in needs:
		var amount_to_remove = needs[item_id]
		_consume_material(item_id, amount_to_remove)
			
	# B. Add the Result
	var product_id = recipes[recipe_id]["output"]
	var product_amount = recipes[recipe_id]["amount"]
	
	# Create the item dictionary expected by InventoryManager
	var item_data = {"id": product_id}
	
	var added = InventoryManager.add_item(item_data, product_amount)
	
	if added:
		print("Crafted: " + recipes[recipe_id]["name"])
	else:
		# Edge Case: Inventory Full AFTER consuming items. 
		# In a polished game, you might want to drop the item on the ground here.
		print("Crafted but inventory full! (Logic to drop item needed)")

# ==================================================
# 🛠️ HELPER FUNCTIONS (The Glue Logic)
# ==================================================

# Helper: loops through InventoryManager to count total specific items
func _get_total_item_count(item_id: String) -> int:
	var total = 0
	# Access the array directly from the Autoload
	var inv_array = InventoryManager._get_inventory()
	
	for slot in inv_array:
		# Check if slot is not null and matches ID
		if slot != null and slot.get("id") == item_id:
			total += slot.get("qty", 0)
			
	return total

# Helper: Removes specific amount of item ID across multiple slots
func _consume_material(item_id: String, amount_needed: int) -> void:
	var inv_array = InventoryManager._get_inventory()
	var remaining_to_remove = amount_needed
	
	# Iterate through inventory to find the items
	# We use a while loop or careful for loop because we might modify slots
	for i in range(inv_array.size()):
		if remaining_to_remove <= 0:
			break
			
		var slot = inv_array[i]
		if slot != null and slot.get("id") == item_id:
			var slot_qty = slot.get("qty", 0)
			
			if slot_qty > remaining_to_remove:
				# Slot has more than we need, just reduce it
				InventoryManager.remove_item(i, remaining_to_remove)
				remaining_to_remove = 0
			else:
				# We need this whole slot and maybe more
				remaining_to_remove -= slot_qty
				InventoryManager.remove_item(i, slot_qty) # This clears the slot
