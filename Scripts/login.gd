extends Control

@onready var list = $VBoxContainer/ProfileList
@onready var name_input = $VBoxContainer/NameInput
@onready var login_button = $VBoxContainer/LoginButton

func _ready():
	ProfileManager.list_updated.connect(_on_list_updated)
	ProfileManager.login_completed.connect(_on_login_completed)

	print("☁️ Fetching user list...")
	ProfileManager.refresh_user_list()

# ---------------------------------
# When profile list from cloud arrives
# ---------------------------------
func _on_list_updated():
	list.clear()

	for username in ProfileManager.profiles:
		list.add_item(username)

	print("✅ Profile list updated in UI")

# ---------------------------------
# Login button pressed
# ---------------------------------
func _on_LoginButton_pressed():
	var index = list.selected
	print(index)
	
	if index == -1:
		print("⚠️ No profile selected")
		return

	var username = list.get_item_text(index)

	print("☁️ Attempting to load profile:", username)

	# Visual feedback
	login_button.disabled = true
	login_button.text = "Loading..."

	# Request profile download
	ProfileManager.load_cloud_profile(username)

# ---------------------------------
# Profile download completed
# ---------------------------------
func _on_login_completed(success: bool):
	login_button.disabled = false
	login_button.text = "Login"

	if success:
		print("✅ Profile loaded! Entering world...")
		get_tree().change_scene_to_file("res://Scenes/world.tscn")
	else:
		print("❌ Failed to download profile. Check console for errors.")
