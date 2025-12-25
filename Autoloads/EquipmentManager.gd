extends Node

signal equipment_changed(slot_name: String, item_id: String)
signal equipment_updated()

var player_ref: Node = null
var anim_player: AnimationPlayer = null

# -------------------------------------------------
# PREFAB ATTACH POINTS
# -------------------------------------------------
const ATTACH_PATHS := {
	"weapon":  "PlayerModel/Armature/GeneralSkeleton/WeaponAttach",
	"offhand": "PlayerModel/Armature/GeneralSkeleton/OffhandAttach",
	"amulet":  "PlayerModel/Armature/GeneralSkeleton/AmuletAttach",
	"cape":    "PlayerModel/Armature/GeneralSkeleton/CapeAttach"
}

# -------------------------------------------------
# PLAYER SETUP
# -------------------------------------------------
func set_player(player: Node) -> void:
	player_ref = player
	anim_player = player.get_node_or_null("PlayerModel/AnimationPlayer")

# -------------------------------------------------
# GET EQUIPPED FROM PROFILE
# -------------------------------------------------
func _get_equipped(slot_key: String) -> String:
	var equip_array = ProfileManager.current_profile.get("equipment", [])
	for slot in equip_array:
		if slot["slot"] == slot_key:
			return slot["item"] if slot["item"] != null else ""
	return ""

# -------------------------------------------------
# CLEAR PREFAB ITEMS
# -------------------------------------------------
func _clear_slot_prefab(slot_key: String) -> void:
	if not ATTACH_PATHS.has(slot_key):
		return
	var attach = player_ref.get_node_or_null(ATTACH_PATHS[slot_key])
	if attach:
		for c in attach.get_children():
			c.queue_free()

# -------------------------------------------------
# CLEAR ARMOR FROM SKELETON
# -------------------------------------------------
func _clear_armor_from_skeleton(item_id: String) -> void:
	var skeleton: Skeleton3D = player_ref.get_node("PlayerModel/Armature/GeneralSkeleton")
	for c in skeleton.get_children():
		if c.name == item_id:
			c.queue_free()

# -------------------------------------------------
# EQUIP ARMOR (SKINNED)
# -------------------------------------------------
func _equip_armor(item: ArmorItem, _slot_key: String) -> void:
	var skeleton: Skeleton3D = player_ref.get_node("PlayerModel/Armature/GeneralSkeleton")

	var armor_scene = load(item.armor_scene_path)
	if not armor_scene:
		push_warning("Armor scene missing: %s" % item.armor_scene_path)
		return

	var inst = armor_scene.instantiate()
	var mesh: MeshInstance3D = inst.get_node(item.mesh_node_path)

	if not mesh:
		push_warning("Armor mesh not found: %s" % str(item.mesh_node_path))
		inst.queue_free()
		return

	mesh.get_parent().remove_child(mesh)
	mesh.set_owner(null)
	mesh.name = item.id
	skeleton.add_child(mesh)
	mesh.set_skeleton_path(NodePath(".."))

	inst.queue_free()

# -------------------------------------------------
# EQUIP PREFAB (WEAPONS / CAPES / AMULETS)
# -------------------------------------------------
func _equip_prefab(item: ItemData, slot_key: String) -> void:
	print("in equip prefab")
	if not item.prefab:
		return

	var attach = player_ref.get_node_or_null(ATTACH_PATHS.get(slot_key, ""))
	if not attach:
		return

	_clear_slot_prefab(slot_key)

	var inst = item.prefab.instantiate()
	inst.name = item.id
	attach.add_child(inst)

	var idle = inst.get_node_or_null("IdleTransform")
	if idle:
		inst.transform = idle.transform

# -------------------------------------------------
# EQUIP ITEM (SLOT-AWARE, SAFE, TRUE SWAP)
# -------------------------------------------------
func equip_item(item_id: String, from_inventory_slot: int = -1) -> bool:
	if not player_ref:
		return false

	var item: ItemData = ItemDataBase.get_item(item_id)
	if not item:
		push_warning("Invalid item_id: " + item_id)
		return false

	var slot_key := item.equip_slot

	# -------------------------------------------------
	# TWO-HAND SAFETY (FIXED LOGIC)
	# -------------------------------------------------
	
	# 1. Safely get the is2h bool (works for Resource or Dictionary)
	var is_two_handed: bool = false
	if item.get("is2h"):
		is_two_handed = item.get("is2h")
	
	# --- CASE A: Equipping a 2H Weapon ---
	if slot_key == "weapon" and is_two_handed:
		print("Attempting 2H Equip...")
		
		# CHECK: Is offhand actually occupied?
		var current_offhand = _get_equipped("offhand")
		if current_offhand != "":
			# Only try to unequip if something is there
			if not unequip_slot("offhand"):
				print("Cannot unequip offhand (Inventory full?)")
				return false
		
		if anim_player:
			anim_player.has_2h = true


	# --- CASE B: Equipping an Offhand (Shield) ---
	if slot_key == "offhand":
		# CHECK: Is main hand actually occupied?
		var main = _get_equipped("weapon")
		if main != "":
			var main_item = ItemDataBase.get_item(main)
			# Check if that main hand item is 2H
			if main_item and main_item.get("is2h"):
				if not unequip_slot("weapon"):
					return false
					
		if anim_player:
			anim_player.has_2h = false

	# -------------------------------------------------
	# FETCH FRESH ARRAY (Crucial: Get state AFTER unequip logic)
	# -------------------------------------------------
	var equip_array = ProfileManager.current_profile.get("equipment", [])

	var old_id := ""
	var old_item: ItemData = null
	var found := false

	for slot in equip_array:
		if slot["slot"] == slot_key:
			found = true
			old_id = slot["item"] if slot["item"] != null else ""
			old_item = ItemDataBase.get_item(old_id) if old_id != "" else null

			# Inventory Swap Logic
			if from_inventory_slot >= 0:
				var clicked := InventoryManager.get_slot(from_inventory_slot)
				if clicked.is_empty() or clicked.get("id", "") != item_id:
					return false

				var consumed_slot_empty := false

				# Remove from inventory
				if clicked.get("qty", 1) > 1:
					clicked["qty"] -= 1
					InventoryManager.set_slot(from_inventory_slot, clicked)
				else:
					InventoryManager.clear_slot(from_inventory_slot)
					consumed_slot_empty = true

				# Put old item back
				if old_id != "":
					if consumed_slot_empty:
						InventoryManager.set_slot(from_inventory_slot, {"id": old_id, "qty": 1})
					else:
						# Fallback if slot wasn't empty
						if not InventoryManager.add_item({"id": old_id}, 1):
							# Rollback
							if clicked.get("qty", 1) > 1:
								clicked["qty"] += 1
								InventoryManager.set_slot(from_inventory_slot, clicked)
							else:
								InventoryManager.set_slot(from_inventory_slot, clicked)
							return false
			else:
				# Programmatic equip (no inventory source)
				if old_id != "":
					if not InventoryManager.add_item({"id": old_id}, 1):
						return false

			# Clear Old Visuals
			if old_id != "":
				if old_item is ArmorItem:
					_clear_armor_from_skeleton(old_id)
				elif ATTACH_PATHS.has(slot_key):
					_clear_slot_prefab(slot_key)

			slot["item"] = item_id
			break

	# Slot didn't exist, add it
	if not found:
		equip_array.append({"slot": slot_key, "item": item_id})

	# Save Profile
	ProfileManager.current_profile["equipment"] = equip_array
	ProfileManager.save_profile()

	# Apply New Visuals
	if item is ArmorItem:
		_equip_armor(item, slot_key)
	elif ATTACH_PATHS.has(slot_key):
		_equip_prefab(item, slot_key)

	emit_signal("equipment_changed", slot_key, item_id)
	emit_signal("equipment_updated")
	return true

# -------------------------------------------------
# UNEQUIP (SAFE)
# -------------------------------------------------
func unequip_slot(slot_key: String) -> bool:
	var equip_array = ProfileManager.current_profile.get("equipment", [])
	
	# Loop through slots to find the one we want to unequip
	for slot in equip_array:
		# Ensure we only try to unequip if there is actually an item there
		if slot["slot"] == slot_key and slot["item"] != null and slot["item"] != "":
			var item_id = slot["item"]
			var item = ItemDataBase.get_item(item_id)

			if not InventoryManager.add_item({"id": item_id}, 1):
				push_warning("Inventory full, cannot unequip: " + item_id)
				return false

			if item is ArmorItem:
				_clear_armor_from_skeleton(item_id)
			else:
				_clear_slot_prefab(slot_key)

			slot["item"] = null

			if slot_key == "weapon" and anim_player:
				anim_player.has_2h = false

			ProfileManager.save_profile()
			emit_signal("equipment_changed", slot_key, "")
			emit_signal("equipment_updated")
			return true

	# If we loop through and find NOTHING to unequip, we return TRUE.
	# Returning TRUE means "The slot is clear (it was already empty)."
	return true

# -------------------------------------------------
# APPLY EQUIPPED ITEMS ON LOAD
# -------------------------------------------------
func apply_equipped_items() -> void:
	if not player_ref:
		return

	for key in ATTACH_PATHS.keys():
		_clear_slot_prefab(key)

	var equip_array = ProfileManager.current_profile.get("equipment", [])

	for slot in equip_array:
		var item_id = slot["item"]
		if item_id == null or item_id == "":
			continue

		var item = ItemDataBase.get_item(item_id)
		if not item:
			continue

		if item is ArmorItem:
			_equip_armor(item, slot["slot"])
		elif ATTACH_PATHS.has(slot["slot"]):
			_equip_prefab(item, slot["slot"])

		if slot["slot"] == "weapon" and item is WeaponItem and anim_player:
			anim_player.has_2h = item.is2h

	emit_signal("equipment_updated")
