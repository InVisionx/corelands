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
	
	# Connect to player signal to cancel interactions when clicking floor
	if player.has_signal("stop_interactions"):
		player.stop_interactions.connect(_on_player_stop_interactions)

# ---------------------------------------------------------
# 🛑 Reset when clicking the ground
# ---------------------------------------------------------
func _on_player_stop_interactions():
	target = null
	_stop_gathering()

# ---------------------------------------------------------
# 🎯 When the player clicks something
# ---------------------------------------------------------
func handle_click_target(target_clickable: Clickable):
	# 1. Always stop current gathering before starting something new
	_stop_gathering()

	target = target_clickable
	
	# 2. Handle Combat immediately (CombatManager handles its own range)
	if target.interaction_type == "enemy":
		_trigger_interaction()
		return

	# 3. Check distance for Resources/Items/NPCs
	var dist = player.global_position.distance_to(target.global_position)

	if dist > target.interact_range:
		# Walk to target: aim for slightly inside the interact range (90%)
		# to prevent "stopping just short" and needing a second click.
		var dir = (target.global_position - player.global_position).normalized()
		var stop_pos = target.global_position - dir * (target.interact_range * 0.9)

		player.agent.target_position = stop_pos
		player.anim_player.is_walking = true
	else:
		# Already in range
		_trigger_interaction()

# ---------------------------------------------------------
# 🚶 Called every physics tick
# ---------------------------------------------------------
func _physics_process(delta: float):
	# Logic for walking toward a target
	if target != null:
		_check_reach_target()

	# Logic for actively gathering (chopping/mining)
	if is_gathering:
		_process_gathering(delta)

# ---------------------------------------------------------
# ❗ Check if we reached the interactable
# ---------------------------------------------------------
func _check_reach_target():
	if target == null: 
		return

	# Flatten Y to prevent issues with hills/slopes
	var player_flat = Vector2(player.global_position.x, player.global_position.z)
	var target_flat = Vector2(target.global_position.x, target.global_position.z)

	# Adding a 0.3 buffer to ensure the click registers upon arrival
	var safe_range = target.interact_range + 0.3

	if player_flat.distance_to(target_flat) <= safe_range:
		# Stop movement
		player.agent.target_position = player.global_position
		player.velocity = Vector3.ZERO
		
		_trigger_interaction()

# ---------------------------------------------------------
# 🤝 Trigger the actual action
# ---------------------------------------------------------
func _trigger_interaction():
	if target == null:
		return

	# Case A: Simple interactions (Items/Pickups/Levers)
	if target.interaction_type == "interact":
		if target.has_method("on_click"):
			target.on_click(player)
		elif target.has_method("interact"):
			target.interact(player)
		target = null
		return

	# Case B: Gathering (Mining/Woodcutting)
	if target.interaction_type == "gather":
		_start_gathering(target)
		target = null
		return

	# Case C: Combat
	if target.interaction_type == "enemy":
		var npc = target.get_owner_npc()
		CombatManager.start_attack(player, npc)
		target = null
		return

	# Catch-all
	target = null

# =========================================================
# ===================== GATHERING LOOP ====================
# =========================================================

func _start_gathering(obj):
	if is_gathering:
		_stop_gathering()

	is_gathering = true
	gather_object = obj

	# Set timing
	gather_interval = obj.gather_interval if obj.get("gather_interval") else 1.8
	gather_timer = 0.0

	# State update
	player.anim_player.is_walking = false
	player.anim_player.is_attacking = false
	print("⛏ Started gathering:", obj.name)

func _process_gathering(delta: float):
	if gather_object == null:
		_stop_gathering()
		return

	# Distance safety check while gathering
	var p2 = Vector2(player.global_position.x, player.global_position.z)
	var t2 = Vector2(gather_object.global_position.x, gather_object.global_position.z)
	
	if p2.distance_to(t2) > gather_object.interact_range + 0.5:
		print("❌ Stopped gathering - moved away")
		_stop_gathering()
		return

	gather_timer += delta
	if gather_timer >= gather_interval:
		gather_timer = 0.0
		_perform_gather_tick()

func _perform_gather_tick():
	if gather_object == null:
		return

	var item_id = gather_object.gather_id if gather_object.get("gather_id") else ""
	if item_id == "":
		return

	# Chance of success
	var success := true
	if gather_object.get("success_chance"):
		success = randf() <= gather_object.success_chance

	if success:
		InventoryManager.add_item({"id": item_id}, 1)
		print("⛏ Collected:", item_id)

	# Trigger object-specific logic (like depleting a node)
	if gather_object.has_method("on_gather"):
		gather_object.on_gather(player)

func _stop_gathering():
	is_gathering = false
	gather_object = null
	gather_timer = 0.0
