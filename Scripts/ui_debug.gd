@tool
extends Control

@export var dummy_fill_enabled: bool = true:
	set(v):
		dummy_fill_enabled = v
		if Engine.is_editor_hint():
			_refresh_dummy_ui()

@onready var inv: Control   = $InventoryUI
@onready var equip: Control = $EquipmentUI

func _ready() -> void:
	if Engine.is_editor_hint():
		_refresh_dummy_ui()

func _refresh_dummy_ui() -> void:
	if not Engine.is_editor_hint():
		return

	if not dummy_fill_enabled:
		_clear_dummy_ui()
		return

	if inv:
		_fill_inventory(inv)
	#if equip:
		#_fill_equipment(equip)

	# force editor preview to fit contents
	if inv:   inv.size   = inv.get_combined_minimum_size()
	#if equip: equip.size = equip.get_combined_minimum_size()
	queue_redraw()
	
func _fill_inventory(inv_root: Control) -> void:
	var grid := inv_root.get_node_or_null("PanelContainer/VBoxContainer/GridContainer")
	if grid == null:
		push_warning("InventoryUI: PanelContainer/GridContainer not found.")
		return
	_clear_children(grid)
	for i in range(20):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(45, 40)
		grid.add_child(btn)
	grid.size = grid.get_combined_minimum_size()
	inv_root.size = inv_root.get_combined_minimum_size()


func _fill_equipment(equip_root: Control) -> void:
	var grid := equip_root.get_node_or_null("PanelContainer/GridContainer")
	if grid == null:
		push_warning("EquipmentUI: PanelContainer/GridContainer not found.")
		return
	_clear_children(grid)
	for i in range(8):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.custom_minimum_size = Vector2(45, 45)
		grid.add_child(btn)
	grid.size = grid.get_combined_minimum_size()
	equip_root.size = equip_root.get_combined_minimum_size()


func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()

func _clear_dummy_ui() -> void:
	if inv:
		var grid := inv.get_node_or_null("PanelContainer/GridContainer")
		if grid: _clear_children(grid)
	if equip:
		var holder := equip.get_node_or_null("PanelContainer")
		if holder == null: holder = equip
		_clear_children(holder)
