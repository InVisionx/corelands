extends Node

# --------------------------------------------
# 📡 Chat Manager (global)
# Handles local + network chat messages
# --------------------------------------------

signal message_added(sender: String, message: String)

# Keeps last few messages (for scrollback)
const MAX_MESSAGES := 100
var messages: Array = []

# -------------------------------
# 💬 Add a chat message
# -------------------------------
func add_message(sender: String, message: String) -> void:
	message = message.strip_edges()
	if message == "":
		return

	var entry := {
		"sender": sender,
		"text": message,
		"time": Time.get_unix_time_from_system()
	}
	messages.append(entry)

	# limit total messages to avoid bloat
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()

	emit_signal("message_added", sender, message)

	print("[Chat] %s: %s" % [sender, message])

	# 🧠 multiplayer stub
	# when you add ENet later, this is where you'll broadcast:
	# NetworkManager.broadcast_chat(sender, message)


# -------------------------------
# 📜 Load historical messages (optional)
# -------------------------------
func get_recent_messages() -> Array:
	return messages.duplicate(true)


# -------------------------------
# 🗑️ Clear chat (admin/debug)
# -------------------------------
func clear_chat():
	messages.clear()
	print("[Chat] Cleared.")
