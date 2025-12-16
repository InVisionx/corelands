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
func _equip_armor(item: ArmorItem, slot_key: String) -> void:
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
# EQUIP ITEM (SLOT-AWARE, SAFE, BUG-FIXED)
# -------------------------------------------------
# -------------------------------------------------
# EQUIP ITEM (SLOT-AWARE, SAFE, UI-CORRECT)
# -------------------------------------------------
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
	var equip_array = ProfileManager.current_profile.get("equipment", [])

	# -------------------------------------------------
	# TWO-HAND SAFETY
	# -------------------------------------------------
	if slot_key == "weapon" and item is WeaponItem and item.is2h:
		if not unequip_slot("offhand"):
			return false
		if anim_player:
			anim_player.has_2h = true

	if slot_key == "offhand":
		var main = _get_equipped("weapon")
		if main != "":
			var main_item = ItemDataBase.get_item(main)
			if main_item is WeaponItem and main_item.is2h:
				if not unequip_slot("weapon"):
					return false
		if anim_player:
			anim_player.has_2h = false

	# -------------------------------------------------
	# FIND EQUIP SLOT
	# -------------------------------------------------
	var old_id := ""
	var old_item: ItemData = null
	var found := false

	for slot in equip_array:
		if slot["slot"] == slot_key:
			found = true
			old_id = slot["item"] if slot["item"] != null else ""
			old_item = ItemDataBase.get_item(old_id) if old_id != "" else null

			# -------------------------------------------------
			# INVENTORY → EQUIP (TRUE SLOT SWAP)
			# -------------------------------------------------
			if from_inventory_slot >= 0:
				var clicked := InventoryManager.get_slot(from_inventory_slot)
				if clicked.is_empty() or clicked.get("id", "") != item_id:
					push_warning("Inventory desync, abort equip.")
					return false

				var consumed_slot_empty := false

				# Consume ONE item from inventory slot
				if clicked.get("qty", 1) > 1:
					clicked["qty"] -= 1
					InventoryManager.set_slot(from_inventory_slot, clicked)
				else:
					InventoryManager.clear_slot(from_inventory_slot)
					consumed_slot_empty = true

				# Put old equipped item BACK INTO SAME SLOT if possible
				if old_id != "":
					if consumed_slot_empty:
						# Perfect swap
						InventoryManager.set_slot(from_inventory_slot, {
							"id": old_id,
							"qty": 1
						})
					else:
						# Stack still exists → fallback
						if not InventoryManager.add_item({"id": old_id}, 1):
							# Rollback inventory removal
							if clicked.get("qty", 1) > 1:
								clicked["qty"] += 1
								InventoryManager.set_slot(from_inventory_slot, clicked)
							else:
								InventoryManager.set_slot(from_inventory_slot, clicked)
							return false

			# -------------------------------------------------
			# PROGRAMMATIC EQUIP (NO INVENTORY SLOT)
			# -------------------------------------------------
			else:
				if old_id != "":
					if not InventoryManager.add_item({"id": old_id}, 1):
						return false

			# -------------------------------------------------
			# CLEAR OLD VISUALS
			# -------------------------------------------------
			if old_id != "":
				if old_item is ArmorItem:
					_clear_armor_from_skeleton(old_id)
				elif ATTACH_PATHS.has(slot_key):
					_clear_slot_prefab(slot_key)

			slot["item"] = item_id
			break

	# Slot did not exist yet
	if not found:
		equip_array.append({"slot": slot_key, "item": item_id})

	# -------------------------------------------------
	# SAVE PROFILE
	# -------------------------------------------------
	ProfileManager.current_profile["equipment"] = equip_array
	ProfileManager.save_profile()

	# -------------------------------------------------
	# APPLY VISUALS
	# -------------------------------------------------
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

	for slot in equip_array:
		if slot["slot"] == slot_key and slot["item"] != null:
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

	return false

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
