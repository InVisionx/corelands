extends Node

# --- RECIPE DATABASE ---
# You can paste your generated recipes right here, 
# or load them from a separate file if the list gets huge.
var recipes = {
	"smelt_bonebar": {
		"name": "Bone Bar",
		"station": "furnace",
		"inputs": {"boneore": 1},
		"output": "bonebar",
		"amount": 1,
		"time": 3.0
	},
	"smelt_tier2bar": {
		"name": "tier2 baaaaaaaaaaaaaaaaaaaaaaaaaaaaaar",
		"station": "furnace",
		"inputs": {"tier2ore": 1},
		"output": "tier2bar",
		"amount": 1,
		"time": 1
	}
	# Paste new generator output here...
}

# --- 1. GET RECIPES ---
# UI calls this: "Hey, I'm a Furnace, what can I make?"
func get_recipes_by_station(station_type: String) -> Array:
	var list = []
	for id in recipes:
		if recipes[id]["station"] == station_type:
			# We return the whole recipe data so the UI can draw names/icons
			list.append(recipes[id]) 
	return list

# --- 2. CHECK REQUIREMENTS ---
# Checks if player has the stuff. 
# Assumes inventory is a Dictionary: {"wood": 5, "iron": 2}
func can_craft(recipe_id: String, inventory: Dictionary) -> bool:
	# specific recipe look up
	if not recipes.has(recipe_id):
		printerr("Recipe not found: " + recipe_id)
		return false
		
	var needs = recipes[recipe_id]["inputs"]
	
	for item in needs:
		var amount_needed = needs[item]
		
		# Check if item exists and if we have enough
		if not inventory.has(item) or inventory[item] < amount_needed:
			return false
			
	return true

# --- 3. CONSUME ITEMS ---
# Removes items from inventory. Returns the MODIFIED inventory.
func craft_item(recipe_id: String, inventory: Dictionary) -> Dictionary:
	if not can_craft(recipe_id, inventory):
		return inventory # Safety check
	
	var needs = recipes[recipe_id]["inputs"]
	
	# Remove ingredients
	for item in needs:
		inventory[item] -= needs[item]
		# Optional: Remove key if 0
		if inventory[item] <= 0:
			inventory.erase(item)
			
	# Add the result (The Output)
	var product = recipes[recipe_id]["output"]
	var amount = recipes[recipe_id]["amount"]
	
	if inventory.has(product):
		inventory[product] += amount
	else:
		inventory[product] = amount
		
	print("Crafted: " + recipes[recipe_id]["name"])
	return inventory
