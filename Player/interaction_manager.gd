extends Node3D

# Reference to the Player (parent)
var player: CharacterBody3D

# The interactable we are currently walking toward
var target: Clickable = null

# Gathering/action loop state
var is_gathering: bool = false
var gather_timer: float = 0.0
var gather_interval: float = 1.8
var gather_object = null

func _ready():
	player = get_parent()


# ---------------------------------------------------------
# 🎯 When the player clicks something
# ---------------------------------------------------------
func handle_click_target(target_clickable: Clickable):
	# Stop any current loop when clicking something new
	_stop_gathering()

	target = target_clickable
	
	# If this is an Enemy, hand over control to CombatManager IMMEDIATELY.
	# CombatManager handles its own chasing logic.
	if target.interaction_type == "enemy":
		_trigger_interaction()
		return
	# --- FIX END ---

	# For Resources/NPCs, keep the old logic (Walk then Interact)
	var dist = player.global_position.distance_to(target.global_position)

	if dist > target.interact_range:
		# Walk to target
		var dir = (target.global_position - player.global_position).normalized()
		var stop_pos = target.global_position - dir * (target.interact_range - 0.1)

		player.agent.target_position = stop_pos
	else:
		_trigger_interaction()

# ---------------------------------------------------------
# 🚶 Called every physics tick
# ---------------------------------------------------------
func _physics_process(delta: float):
	# If we are walking toward a target
	if target != null:
		_check_reach_target()

	# If we are currently gathering
	if is_gathering:
		_process_gathering(delta)


# ---------------------------------------------------------
# ❗ Check if we reached the interactable
# ---------------------------------------------------------
func _check_reach_target():
	var p2 = Vector2(player.global_position.x, player.global_position.z)
	var t2 = Vector2(target.global_position.x, target.global_position.z)

	if p2.distance_to(t2) <= target.interact_range:
		_trigger_interaction()


# ---------------------------------------------------------
# 🤝 Trigger the actual action
# ---------------------------------------------------------
func _trigger_interaction():
	if target == null:
		return

	# UI-style / interaction object
	if target.interaction_type == "interact":
		if target.has_method("on_click"):
			target.on_click(player)
		elif target.has_method("interact"):
			target.interact(player)
		target = null
		return

	# ENVIRONMENT: Mining / Woodcutting / Fishing etc.
	if target.interaction_type == "gather":
		_start_gathering(target)
		target = null
		return

	# Combat
	if target.interaction_type == "enemy":
		var npc = target.get_owner_npc()
		CombatManager.start_attack(player, npc)
		target = null
		return

	# Unknown fallback
	if target.has_method("on_click"):
		target.on_click(player)

	target = null


# =========================================================
# ===================== GATHERING LOOP ====================
# =========================================================

func _start_gathering(obj):
	if is_gathering:
		_stop_gathering()

	is_gathering = true
	gather_object = obj

	# Allow objects to override gather interval
	gather_interval = obj.gather_interval if obj.get("gather_interval") else 1.8

	gather_timer = 0.0

	# Trigger animation
	player.anim_player.is_walking = false
	player.anim_player.is_attacking = false
	#player.anim_player._play("Gather")  # you can rename this

	print("⛏ Started gathering:", obj.name)


func _process_gathering(delta: float):
	if gather_object == null:
		_stop_gathering()
		return

	# If player moved too far → stop
	var p2 = Vector2(player.global_position.x, player.global_position.z)
	var t2 = Vector2(gather_object.global_position.x, gather_object.global_position.z)
	if p2.distance_to(t2) > gather_object.interact_range + 0.5:
		print("❌ Stopped gathering - moved away")
		_stop_gathering()
		return

	# Timer countdown
	gather_timer += delta
	if gather_timer >= gather_interval:
		gather_timer = 0.0
		_perform_gather_tick()


func _perform_gather_tick():
	if gather_object == null:
		return

	# Item to give
	var item_id = gather_object.gather_id if gather_object.get("gather_id") else ""
	if item_id == "":
		push_warning("Gather object missing gather_id")
		return

	# RNG
	var success := true
	if gather_object.get("success_chance"):
		success = randf() <= gather_object.success_chance

	if success:
		InventoryManager.add_item({"id": item_id}, 1)
		print("⛏ Collected:", item_id)
	else:
		print("⛏ Swing… no resource")

	# Optional: object depletion
	if gather_object.has_method("on_gather"):
		gather_object.on_gather(player)


func _stop_gathering():
	is_gathering = false
	gather_object = null
	gather_timer = 0.0
