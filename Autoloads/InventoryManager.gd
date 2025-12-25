extends Node

signal inventory_updated()

var player_ref: Node = null

# ==================================================
# 🔍 GET INVENTORY
# ==================================================
func _get_inventory() -> Array:
	if not ProfileManager.current_profile.has("inventory"):
		ProfileManager.current_profile["inventory"] = []
	return ProfileManager.current_profile["inventory"]


# ==================================================
# 🔁 MOVE / SWAP
# ==================================================
# Called by InventorySlot._drop_data()
func move_item(from_index: int, to_index: int) -> void:
	var inventory = _get_inventory()

	if from_index == to_index:
		return
	if from_index < 0 or to_index < 0:
		return
	if from_index >= inventory.size() or to_index >= inventory.size():
		return

	# Swap the data in the array
	var temp = inventory[from_index]
	inventory[from_index] = inventory[to_index]
	inventory[to_index] = temp

	emit_signal("inventory_updated")
	_save()


# ==================================================
# 🖱️ CLICK HANDLER (EQUIP ONLY)
# ==================================================
func on_slot_clicked(slot_index: int) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return

	var slot_data = inventory[slot_index]
	if slot_data == null:
		return

	var id = slot_data.get("id", "")
	if id == "":
		return

	# If it's equipment, equip it
	var item_data = ItemDataBase.get_item(id)
	if item_data and item_data.equip_slot != "":
		EquipmentManager.equip_item(id, slot_index)


# ==================================================
# ✅ ADD ITEM (STACK-AWARE)
# ==================================================
func add_item(item: Dictionary, quantity: int = 1) -> bool:
	var inventory = _get_inventory()
	var item_id = item.get("id", "")
	if item_id == "":
		return false

	var item_data = ItemDataBase.get_item(item_id)
	var stackable = item_data != null and item_data.stackable

	if stackable:
		for slot in inventory:
			if slot != null and slot.get("id", "") == item_id:
				slot["qty"] += quantity
				emit_signal("inventory_updated")
				_save()
				return true

	for i in range(inventory.size()):
		if inventory[i] == null:
			inventory[i] = {"id": item_id, "qty": quantity}
			emit_signal("inventory_updated")
			_save()
			return true

	push_warning("⚠ Inventory full, cannot add item: " + item_id)
	return false


# ==================================================
# ❌ REMOVE ITEM
# ==================================================
func remove_item(slot_index: int, quantity: int = 1) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return

	var slot = inventory[slot_index]
	if slot == null:
		return

	slot["qty"] -= quantity
	if slot["qty"] <= 0:
		inventory[slot_index] = null

	emit_signal("inventory_updated")
	_save()

func drop_item(slot_index: int) -> void:
	var slot = get_slot(slot_index)
	if slot.is_empty():
		return

	var item_id = slot.get("id", "")
	var qty_to_drop = slot.get("qty", 1)
	var item_def: ItemData = ItemDataBase.get_item(item_id)
	if not item_def:
		return

	print("Dropped:", item_def.display_name)

	# =====================================================
	# 1. SPAWN DROP SCENE (FROZEN)
	# =====================================================
	var drop_scene := preload("res://Scenes/dropped_item.tscn")
	var drop := drop_scene.instantiate() as RigidBody3D

	drop.freeze = true
	player_ref.get_parent().add_child(drop)

	var random_offset := Vector3(
		randf_range(-0.25, 0.25),
		0.0,
		randf_range(-0.25, 0.25)
	)
	drop.global_position = player_ref.global_position + Vector3.UP + random_offset

	# =====================================================
	# 2. ASSIGN VISUAL MESH + SCALE (NO PHYSICS YET)
	# =====================================================
	var visual: MeshInstance3D = drop.get_node("Visual")
	var collision: CollisionShape3D = drop.get_node("DroppedCollider")

	var prefab_inst: Node = null
	var source_mesh: MeshInstance3D = null
	var final_scale: Vector3 = Vector3.ONE

	match item_def.item_type:
		ItemData.ItemType.ARMOR:
			var armor := item_def as ArmorItem
			if not armor:
				return

			var armor_scene := load(armor.armor_scene_path) as PackedScene
			if not armor_scene:
				return

			prefab_inst = armor_scene.instantiate()
			source_mesh = prefab_inst.get_node_or_null(armor.mesh_node_path)

		ItemData.ItemType.WEAPON, ItemData.ItemType.GENERIC:
			prefab_inst = item_def.prefab.instantiate()

			if prefab_inst is MeshInstance3D:
				source_mesh = prefab_inst
			else:
				source_mesh = _find_mesh_instance(prefab_inst)

			var idle := prefab_inst.get_node_or_null("IdleTransform") as Node3D
			if idle:
				final_scale = idle.scale

		_:
			return

	if not source_mesh or not source_mesh.mesh:
		if prefab_inst:
			prefab_inst.queue_free()
		push_warning("Drop source mesh missing")
		return

	# ---- Mesh ----
	visual.mesh = source_mesh.mesh

	# ---- Materials ----
	visual.material_override = source_mesh.material_override
	for i in range(source_mesh.get_surface_override_material_count()):
		var mat = source_mesh.get_surface_override_material(i)
		if mat:
			visual.set_surface_override_material(i, mat)

	# ---- Base orientation (authored) ----
	var base_basis := source_mesh.transform.basis.orthonormalized()
	visual.basis = base_basis
	visual.position = Vector3.ZERO

	# ---- Scale ----
	if final_scale != Vector3.ONE:
		visual.scale = final_scale
	else:
		visual.scale = source_mesh.scale

	if prefab_inst:
		prefab_inst.queue_free()

	# =====================================================
	# 2.5 CAPE ROTATION FIX (LAY FLAT + SCALE DOWN)
	# =====================================================
	var is_cape := item_def.display_name.to_lower().find("cape") != -1
	if is_cape:
		# Rotate 90 degrees on X so it lies flat
		var cape_rot := Basis(Vector3.RIGHT, deg_to_rad(90.0))
		visual.basis = cape_rot * visual.basis

		# Scale down to half size
		visual.scale *= Vector3(0.5, 0.5, 0.5)

	# =====================================================
	# 3. COLLISION (MATCH VISUAL)
	# =====================================================
	var shape := visual.mesh.create_convex_shape(true, true)
	collision.shape = shape

	# Match rotation & scale
	collision.basis = visual.basis
	collision.scale = visual.scale
	collision.position = Vector3.ZERO

	# =====================================================
	# 4. WAKE PHYSICS + APPLY IMPULSE
	# =====================================================
	drop.gravity_scale = 0.4
	drop.freeze = false
	drop.sleeping = false
	drop.linear_velocity = Vector3.ZERO
	drop.angular_velocity = Vector3.ZERO

	var radial_impulse := Vector3(
		randf_range(-0.3, 0.3),
		-0.4,
		randf_range(-0.3, 0.3)
	)
	drop.apply_impulse(radial_impulse)

	# =====================================================
	# 5. REMOVE FROM INVENTORY
	# =====================================================
	remove_item(slot_index, qty_to_drop)

	# =====================================================
	# 6. FILL PICKUP DATA
	# =====================================================
	drop.set_item_data(item_id, qty_to_drop)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_mesh_instance(child)
		if found:
			return found
	return null

#func drop_item(slot_index: int) -> void:
	#var slot = get_slot(slot_index)
	#if slot.is_empty(): return
#
	#var item_id = slot.get("id", "")
	#var qty_to_drop = slot.get("qty", 1)
	#var item_def = ItemDataBase.get_item(item_id)
#
	## 1. SPAWN & PHYSICS
	#if item_def and item_def.prefab:
		#var drop = item_def.prefab.instantiate()
		#
		## [FIX 1] Add to scene FIRST so we can use global_position
		#player_ref.get_parent().add_child(drop)
		#
		## [FIX 2] Move it to Player Position + Up a bit (Waist height) + Random offset
		#var random_offset = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
		#
		## Spawning at .global_position is usually the feet. Add Vector3.UP to spawn at waist.
		#drop.global_position = player_ref.global_position + Vector3.UP + random_offset
		#
		## [OPTIONAL] Give it a little toss forward
		#if drop is RigidBody3D:
			## Get the direction the player is facing
			#var forward_dir = -player_ref.global_transform.basis.z
			## Apply a small impulse forward and up
			#drop.apply_impulse(forward_dir * 2.0 + Vector3.UP * 2.0)
#
	## 2. REMOVE FROM INVENTORY
	#remove_item(slot_index, qty_to_drop)
	
# ==================================================
# 🧰 HELPERS
# ==================================================
func get_slot(slot_index: int) -> Dictionary:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return {}
	return inventory[slot_index] if inventory[slot_index] != null else {}


func set_slot(slot_index: int, data: Dictionary) -> void:
	var inventory = _get_inventory()
	if slot_index < 0 or slot_index >= inventory.size():
		return

	inventory[slot_index] = data if data.size() > 0 else null
	emit_signal("inventory_updated")
	_save()


func clear_slot(slot_index: int) -> void:
	set_slot(slot_index, {})


func set_player(player: Node) -> void:
	player_ref = player


func _save() -> void:
	ProfileManager.save_profile()
