extends Control

@onready var input := $PanelContainer/VBoxContainer/ChatInput
@onready var messages_vbox := $PanelContainer/VBoxContainer/ScrollContainer/MessagesVBox
@onready var panel := $PanelContainer
@onready var hide_button := $HideButton

# 🧩 Font settings
@export var font_size: int = 16
@export var chat_font: Font = ThemeDB.fallback_font

func _ready():
	input.connect("text_submitted", Callable(self, "_on_text_submitted"))
	_apply_font_to_control(input)

func _on_text_submitted(text: String):
	text = text.strip_edges()
	if text == "":
		return

	# ---------------------------------------------------------
	# 🛠️ COMMAND INTERCEPTOR
	# Checks for "::" prefix. If found, runs command and stops chat.
	# ---------------------------------------------------------
	if text.begins_with("::"):
		_handle_command(text)
		input.clear()
		return 

	# Normal Chat Logic
	var username = ProfileManager.current_profile.get("username", "Unknown")
	_add_local_message(username, text)
	_show_overhead_message(text)
	input.clear()

# ---------------------------------------------------------
# 💻 COMMAND LOGIC
# ---------------------------------------------------------
func _handle_command(text: String):
	# 1. Permission Check (Case-insensitive)
	var username = ProfileManager.current_profile.get("username", "").to_lower()
	
	if username == "icey":
		_add_local_message("System", "❌ You do not have permission to use commands.")
		return

	# 2. Parse text: "::equip sword" -> command: "equip", arg: "sword"
	var raw_cmd = text.substr(2) 
	var parts = raw_cmd.split(" ", true, 1) 
	var command = parts[0].to_lower()
	var arg = ""
	
	if parts.size() > 1:
		arg = parts[1].replace('"', '') # Strip quotes if user typed ::equip "sword"

	# 3. Router
	match command:
		"equip":
			_cmd_equip(arg)
		"give":
			_cmd_give(arg)
		_:
			_add_local_message("System", "Unknown command: " + command)

func _cmd_equip(item_id: String):
	if item_id == "":
		_add_local_message("System", "Usage: ::equip item_id")
		return

	# Validate ID exists in DB
	if not ItemDataBase.get_item(item_id):
		_add_local_message("System", "❌ Item ID not found: " + item_id)
		return

	# ⚡ DIRECT CALL TO AUTOLOAD
	# This acts as a "Spawn & Equip" (Cheat). It does not require the item in inventory.
	EquipmentManager.equip_item(item_id)
	
	_add_local_message("System", "⚡ Force Equipped: " + item_id)

func _cmd_give(item_id: String):
	if item_id == "":
		_add_local_message("System", "Usage: ::give item_id")
		return

	if not ItemDataBase.get_item(item_id):
		_add_local_message("System", "❌ Item ID not found.")
		return
		
	# ⚡ DIRECT CALL TO INVENTORY MANAGER
	# Assumes InventoryManager has add_item(item_dictionary, quantity)
	InventoryManager.add_item({"id": item_id}, 1)
	
	_add_local_message("System", "📦 Spawned: " + item_id)

# ---------------------------------------------------------
# 🎨 UI & VISUALS
# ---------------------------------------------------------
func _add_local_message(sender: String, message: String):
	var lbl := Label.new()
	
	# Style System messages differently
	if sender == "System":
		lbl.modulate = Color(1, 1, 0) # Yellow
	
	lbl.text = "%s: %s" % [sender, message]
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_apply_font_to_control(lbl)
	messages_vbox.add_child(lbl)

	await get_tree().process_frame
	var scroll := $PanelContainer/VBoxContainer/ScrollContainer
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value

func _apply_font_to_control(ctrl: Control) -> void:
	if chat_font:
		ctrl.add_theme_font_override("font", chat_font)
	ctrl.add_theme_font_size_override("font_size", font_size)

# -----------------------------------------
# 🗨️ Overhead message handling
# -----------------------------------------
func _show_overhead_message(message: String) -> void:
	# Find local player via Group
	var player_root = get_tree().get_first_node_in_group("local_player")
	if not player_root:
		return

	var overhead_label: Label3D = player_root.get_node_or_null("OverheadMessage")
	if not overhead_label:
		return

	overhead_label.text = message
	overhead_label.visible = true

	# Reset timer
	if overhead_label.has_meta("chat_timer"):
		var old_timer = overhead_label.get_meta("chat_timer")
		if is_instance_valid(old_timer):
			old_timer.queue_free()

	var timer := get_tree().create_timer(3.0)
	timer.connect("timeout", Callable(self, "_clear_overhead_label").bind(overhead_label))
	overhead_label.set_meta("chat_timer", timer)

func _clear_overhead_label(overhead_label: Label3D) -> void:
	if is_instance_valid(overhead_label):
		overhead_label.text = ""
		overhead_label.visible = false
		overhead_label.set_meta("chat_timer", null)

func _on_hide_button_pressed() -> void:
	panel.visible = !panel.visible
	if panel.visible:
		hide_button.text = "Hide Chat"
		self.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		hide_button.text = "Show Chat"
		self.mouse_filter = Control.MOUSE_FILTER_IGNORE
