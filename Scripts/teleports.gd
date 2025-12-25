extends Control

@onready var portal_vfx_scene: PackedScene = preload("res://Shaders/VFX/teleport_vfx.tscn")
var player: Node3D = null

func _ready() -> void:
	find_player()

func find_player() -> void:
	await get_tree().process_frame  # wait 1 frame
	while player == null:
		player = get_tree().get_first_node_in_group("local_player")
		if player == null:
			await get_tree().create_timer(0.1).timeout  # check every 0.1s
# -------------------------------------------------------------
# 🔹 Universal teleport handler for all buttons
# -------------------------------------------------------------
func teleport_player(target_pos: Vector3, facing_y_deg: float = 0.0) -> void:
	if not player:
		push_warning("⚠️ No player found for teleport!")
		return
	else:
		"we do have player"

	# Spawn VFX at player position
	var portal_vfx = portal_vfx_scene.instantiate()
	get_tree().current_scene.add_child(portal_vfx)
	portal_vfx.global_position = player.global_position

	# Hide weapon or model temporarily
	var attach = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton/WeaponAttach")
	if attach:
		attach.visible = false

	# Wait before teleport
	await get_tree().create_timer(2.7).timeout

	# Move player & rotate
	player.global_position = target_pos
	player.rotation.y = deg_to_rad(facing_y_deg)

	# Restore weapon
	if attach:
		attach.visible = true

func _on_home_teleport_pressed() -> void:
	teleport_player(Vector3(-131.287, 4.874, -126.675), 180)
