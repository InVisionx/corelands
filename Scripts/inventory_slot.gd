extends Button

@export var slot_index: int = 0

@onready var slot_icon: TextureRect = $Image
@onready var qty_label: Label = $Quantity

func _ready():
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
	InventoryManager.on_slot_clicked(slot_index)
	print(slot_index)

func set_item(id, qty: int) -> void:
	# ✅ Handle null or empty IDs safely
	if id == null or id == "":
		clear()
		return

	# ✅ Use your renamed autoload singleton
	var data = ItemDataBase.get_item(id)
	if data:
		slot_icon.texture = data.icon
		slot_icon.tooltip_text = data.display_name
	else:
		slot_icon.texture = null

	qty_label.text = str(qty) if qty > 1 else ""

func clear() -> void:
	slot_icon.texture = null
	slot_icon.tooltip_text = ""   # 🔑 FIX
	qty_label.text = ""
