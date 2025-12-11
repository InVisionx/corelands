extends Button

signal bank_slot_pressed(slot_index: int)

@export var slot_index: int = 0
@onready var slot_icon: TextureRect = $Image
@onready var qty_label: Label = $Quantity

func _ready():
	connect("pressed", Callable(self, "_on_pressed"))

func _on_pressed():
	emit_signal("bank_slot_pressed", slot_index)

# -------------------------------
# 📦 Item Display
# -------------------------------
func set_item(id: String, qty: int = 1) -> void:
	if id == null or id == "":
		clear()
		return

	var data = ItemDataBase.get_item(id)
	if data:
		slot_icon.texture = data.icon
		slot_icon.tooltip_text = data.display_name
	else:
		slot_icon.texture = null

	qty_label.text = str(qty) if qty > 1 else ""

func clear() -> void:
	slot_icon.texture = null
	qty_label.text = ""
