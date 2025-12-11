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
# GET EQUIPPED FROM JSON
# -------------------------------------------------
func _get_equipped(slot_key: String) -> String:
	var equip_array = ProfileManager.current_profile.get("equipment", [])
	for slot in equip_array:
		if slot["slot"] == slot_key:
			var item_id = slot["item"]
			return item_id if item_id != null else ""
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
# CLEAR ARMOR MESH FROM SKELETON
# -------------------------------------------------
func _clear_armor_from_skeleton(item_id: String) -> void:
	var skeleton: Skeleton3D = player_ref.get_node("PlayerModel/Armature/GeneralSkeleton")
	for c in skeleton.get_children():
		if c.name == item_id:
			c.queue_free()

# -------------------------------------------------
# EQUIP ARMOR (SKINNED MESH)
# -------------------------------------------------
func _equip_armor(item: ItemData, slot_key: String) -> void:
	if not (item is ArmorItem):
		push_warning("Tried to equip armor on non-armor: %s" % item.id)
		return

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
# EQUIP PREFAB (WEAPONS, CAPES, AMULETS)
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
# EQUIP MASTER FUNCTION
# -------------------------------------------------
func equip_item(item_id: String) -> void:
	if not player_ref:
		return

	var item: ItemData = ItemDataBase.get_item(item_id)
	if item == null:
		push_warning("Invalid item_id: " + item_id)
		return

	var slot_key := item.equip_slot
	var equip_array = ProfileManager.current_profile.get("equipment", [])

	# --- TWO-HAND LOGIC ---
	if slot_key == "weapon" and item is WeaponItem:
		var w: WeaponItem = item
		if w.is2h:
			unequip_slot("offhand")
			if anim_player:
				anim_player.has_2h = true

	if slot_key == "offhand":
		var main = _get_equipped("weapon")
		if main != "":
			var m_item: ItemData = ItemDataBase.get_item(main)
			if m_item and m_item is WeaponItem and m_item.is2h:
				unequip_slot("weapon")
		if anim_player:
			anim_player.has_2h = false

	# --------------------------
	# REMOVE OLD ITEM IN SLOT
	# --------------------------
	var found := false

	for slot in equip_array:
		if slot["slot"] == slot_key:
			found = true

			if slot["item"] != null:
				var old_id = slot["item"]
				var old_item = ItemDataBase.get_item(old_id)

				InventoryManager.add_item({"id": old_id}, 1)

				if old_item and old_item.item_type == ItemData.ItemType.ARMOR:
					_clear_armor_from_skeleton(old_id)
				elif ATTACH_PATHS.has(slot_key):
					_clear_slot_prefab(slot_key)

			slot["item"] = item_id
			break

	# If slot not found, add it fresh
	if not found:
		equip_array.append({"slot": slot_key, "item": item_id})

	# Save modified equipment array
	ProfileManager.current_profile["equipment"] = equip_array
	ProfileManager.save_profile()

	# --------------------------
	# APPLY VISUALS
	# --------------------------
	if item.item_type == ItemData.ItemType.ARMOR:
		_equip_armor(item, slot_key)
	elif ATTACH_PATHS.has(slot_key):
		_equip_prefab(item, slot_key)

	emit_signal("equipment_changed", slot_key, item_id)
	emit_signal("equipment_updated")

# -------------------------------------------------
# UNEQUIP
# -------------------------------------------------
func unequip_slot(slot_key: String) -> void:
	var equip_array = ProfileManager.current_profile.get("equipment", [])

	for slot in equip_array:
		if slot["slot"] == slot_key and slot["item"] != null:
			var item_id = slot["item"]
			var item = ItemDataBase.get_item(item_id)

			if item and item.item_type == ItemData.ItemType.ARMOR:
				_clear_armor_from_skeleton(item_id)
			else:
				_clear_slot_prefab(slot_key)

			InventoryManager.add_item({"id": item_id}, 1)
			slot["item"] = null

			if slot_key == "weapon" and anim_player:
				anim_player.has_2h = false

			break

	ProfileManager.save_profile()
	emit_signal("equipment_changed", slot_key, "")
	emit_signal("equipment_updated")

# -------------------------------------------------
# APPLY EQUIPPED ITEMS ON LOAD
# -------------------------------------------------
func apply_equipped_items() -> void:
	if not player_ref:
		return

	var equip_array = ProfileManager.current_profile.get("equipment", [])

	# Clear only prefabs (weapons/offhand/cape/amulet)
	for key in ATTACH_PATHS.keys():
		_clear_slot_prefab(key)

	# Do NOT clear skeleton meshes globally!
	# Old system only cleared armor by ID when equipping/unequipping.

	# Reapply equipment one by one
	for slot in equip_array:
		var slot_key = slot["slot"]
		var item_id = slot["item"]

		if item_id == null or item_id == "":
			continue

		var item = ItemDataBase.get_item(item_id)
		if not item:
			continue

		if item.item_type == ItemData.ItemType.ARMOR:
			_equip_armor(item, slot_key)
		elif ATTACH_PATHS.has(slot_key):
			_equip_prefab(item, slot_key)

		# restore 2H status
		if slot_key == "weapon" and item is WeaponItem and anim_player:
			anim_player.has_2h = item.is2h

	emit_signal("equipment_updated")
