extends Button

@export var slot_index: int = 0

@onready var slot_icon: TextureRect = $Image
@onready var qty_label: Label = $Quantity

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP

# ==================================================
# 🖱️ CUSTOM INPUT (SHIFT + CLICK)
# ==================================================
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# CHECK FOR SHIFT KEY
		if Input.is_key_pressed(KEY_SHIFT):
			# Stop this event from propagating (so we don't click/drag simultaneously)
			accept_event()
			
			# Check if there is actually an item to drop
			var item = InventoryManager.get_slot(slot_index)
			if item != null and not item.is_empty():
				InventoryManager.drop_item(slot_index)

# ==================================================
# 🖱️ GODOT BUILT-IN DRAG & DROP
# ==================================================
func _get_drag_data(_at_position: Vector2):
	# SAFETY: If Shift is held, DO NOT start a drag.
	# This prevents the weird edge case where you try to drop but dragging starts anyway.
	if Input.is_key_pressed(KEY_SHIFT):
		return null
		
	var item = InventoryManager.get_slot(slot_index)
	if item == null or item.is_empty():
		return null 

	# 1. Create the preview (Ghost)
	var preview_texture = TextureRect.new()
	preview_texture.texture = slot_icon.texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.size = size
	preview_texture.modulate.a = 0.8
	
	var preview_control = Control.new()
	preview_control.add_child(preview_texture)
	preview_texture.position = -0.5 * size 
	
	set_drag_preview(preview_control)
	
	# 2. HIDE the original icon so it looks like we picked it up
	slot_icon.visible = false
	
	return { "origin_index": slot_index, "item_id": item.get("id") }


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("origin_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var from_index = data["origin_index"]
	var to_index = slot_index
	InventoryManager.move_item(from_index, to_index)


# ==================================================
# 👻 DRAG END HANDLER (Restore Visibility)
# ==================================================
func _notification(what):
	# This notification fires automatically when a drag operation ends
	# (whether it was dropped successfully or cancelled).
	if what == NOTIFICATION_DRAG_END:
		if not is_drag_successful():
			# If drag was cancelled, we must show the icon again immediately
			slot_icon.visible = true
		else:
			# If drag was successful, the inventory update will normally handle it,
			# but it's safe to force it visible here too just in case.
			slot_icon.visible = true


# ==================================================
# 🖱️ STANDARD CLICK
# ==================================================
func _pressed():
	# If Shift is held, we already handled it in _gui_input, so ignore standard press
	if Input.is_key_pressed(KEY_SHIFT):
		return
		
	InventoryManager.on_slot_clicked(slot_index)


# ==================================================
# 📦 UI UPDATES
# ==================================================
func set_item(id, qty: int) -> void:
	# Ensure it's visible (in case an update happens while it was hidden)
	slot_icon.visible = true 
	
	if id == null or id == "":
		clear()
		return

	var data = ItemDataBase.get_item(id)
	if data:
		slot_icon.texture = data.icon
		slot_icon.tooltip_text = data.display_name
	else:
		slot_icon.texture = null
		slot_icon.tooltip_text = ""

	qty_label.text = str(qty) if qty > 1 else ""


func clear() -> void:
	slot_icon.texture = null
	slot_icon.tooltip_text = ""
	qty_label.text = ""
	slot_icon.visible = true
