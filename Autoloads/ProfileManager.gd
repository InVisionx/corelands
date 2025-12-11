extends Node

signal list_updated
signal login_completed(success: bool)
signal save_completed(success: bool)

# ----------------------------------
# SUPABASE CONFIG
# ----------------------------------
const SUPABASE_URL = "https://dmgdwddnuecngtzslkti.supabase.co"
const SUPABASE_KEY = "sb_publishable_Aaa774sv8wrDQWGWaoKlNw_lS0qiJ22"

# ----------------------------------
# HEADERS
# ----------------------------------

# HEADERS FOR READING (GET)
var headers_READ = [
	"apikey: " + SUPABASE_KEY,
	"Authorization: Bearer " + SUPABASE_KEY,
	"Accept-Encoding: identity" 
]

# HEADERS FOR SAVING (PATCH)
var headers_WRITE = [
	"apikey: " + SUPABASE_KEY,
	"Authorization: Bearer " + SUPABASE_KEY,
	"Content-Type: application/json",
	"Prefer: return=minimal"
]

# ----------------------------------
# STATE
# ----------------------------------
var current_profile: Dictionary = {}
var current_username: String = ""
var profiles: Array = []

# ----------------------------------
# 1. FETCH USER LIST
# ----------------------------------
func refresh_user_list():
	print("☁️ Fetching User List...")

	var url = SUPABASE_URL + "/rest/v1/profiles?select=username"

	var http := HTTPRequest.new()
	# FIX: Explicitly disable GZIP on the node to prevent C++ error
	http.accept_gzip = false 
	add_child(http)
	
	http.request(url, headers_READ, HTTPClient.METHOD_GET)

	var result = await http.request_completed
	http.queue_free()

	var code = result[1]
	var body = result[3]

	if code != 200:
		print("❌ Error fetching users:", code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("❌ JSON parse failed for user list")
		return

	var data = json.get_data()
	profiles.clear()
	
	if typeof(data) == TYPE_ARRAY:
		for row in data:
			if row.has("username"):
				profiles.append(row["username"])

	print("✅ Loaded users:", profiles.size())
	emit_signal("list_updated")

# ----------------------------------
# 2. LOAD PROFILE
# ----------------------------------
func load_cloud_profile(username: String):
	print("☁️ Loading profile:", username)
	current_username = username
	
	var safe_name = username.uri_encode()
	var url = SUPABASE_URL + "/rest/v1/profiles?username=eq.%s&select=*" % safe_name

	var http := HTTPRequest.new()
	# FIX: Explicitly disable GZIP on the node
	http.accept_gzip = false 
	add_child(http)
	
	http.request(url, headers_READ, HTTPClient.METHOD_GET)

	var result = await http.request_completed
	http.queue_free()

	var code = result[1]
	var body = result[3]
	
	if code != 200:
		print("❌ Load failed:", code)
		emit_signal("login_completed", false)
		return

	# Parse Body
	var json := JSON.new()
	var parse_err = json.parse(body.get_string_from_utf8())
	if parse_err != OK:
		print("❌ JSON parse failed")
		emit_signal("login_completed", false)
		return

	var rows = json.get_data()
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		print("❌ User not found")
		emit_signal("login_completed", false)
		return

	# GET THE GAME DATA
	var raw_data = rows[0].get("game_data")

	# Validate Structure
	if typeof(raw_data) != TYPE_DICTIONARY:
		raw_data = {}

	var modified := false
	if not raw_data.has("inventory"):
		raw_data["inventory"] = _create_default_inventory()
		modified = true
	if not raw_data.has("equipment"):
		raw_data["equipment"] = _create_default_equipment()
		modified = true
	if not raw_data.has("bank"):
		raw_data["bank"] = _create_default_bank()
		modified = true

	current_profile = raw_data
	current_profile["username"] = current_username

	if modified:
		print("🧩 Missing fields repaired. Saving...")
		save_profile()

	print("🎉 Profile Loaded")
	emit_signal("login_completed", true)

# ----------------------------------
# 3. SAVE PROFILE
# ----------------------------------
func save_profile():
	if current_username == "":
		return

	print("☁️ Saving profile...")
	var safe_name = current_username.uri_encode()
	var url = SUPABASE_URL + "/rest/v1/profiles?username=eq.%s" % safe_name
	var body_data = { "game_data": current_profile }

	var http := HTTPRequest.new()
	# FIX: Explicitly disable GZIP on the node
	http.accept_gzip = false 
	add_child(http)
	
	http.request(url, headers_WRITE, HTTPClient.METHOD_PATCH, JSON.stringify(body_data))

	var result = await http.request_completed
	http.queue_free()

	var code = result[1]
	if code == 200 or code == 204:
		print("💾 Save Successful!")
		emit_signal("save_completed", true)
	else:
		print("❌ Save failed:", code)
		emit_signal("save_completed", false)

# ----------------------------------
# DEFAULTS
# ----------------------------------
func _create_default_inventory() -> Array:
	var arr := []
	for i in range(20): arr.append(null)
	return arr

func _create_default_bank() -> Array:
	var arr := []
	for i in range(100): arr.append(null)
	return arr

func _create_default_equipment() -> Array:
	return [
		{"slot": "weapon", "item": "obsidianscimitar"},
		{"slot": "offhand", "item": null},
		{"slot": "helm", "item": null},
		{"slot": "chest", "item": null},
		{"slot": "legs", "item": null},
		{"slot": "gloves", "item": null},
		{"slot": "boots", "item": null},
		{"slot": "amulet", "item": null},
		{"slot": "cape", "item": null}
	]
