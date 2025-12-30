extends AnimationPlayer

const WEAPON_ATTACH = "../Armature/GeneralSkeleton/WeaponAttach"
const OFFHAND_ATTACH = "../Armature/GeneralSkeleton/OffhandAttach"

const AXE_SCENE = preload("res://Items/Resources/Gravewood_Axe/gravewood_pickaxe.tscn")
const TELEPORT_SCENE = preload("res://Shaders/VFX/teleport_vfx.tscn")

var active_tool: Node3D = null
var has_2h: bool = false
var is_walking: bool = false
var anim_locked: bool = false 

# New variable to control attack playback speed dynamically
var attack_speed: float = 1.0 

var is_mining: bool = false:
	set(value):
		if value == is_mining: return 
		is_mining = value
		_handle_gathering_state("Mine" if is_mining else "")
			
var is_chopping: bool = false:
	set(value):
		if value == is_chopping: return
		is_chopping = value
		_handle_gathering_state("Chop" if is_chopping else "")

var is_attacking: bool = false:
	set(value):
		if value == is_attacking: return
		is_attacking = value
		if is_attacking:
			_run_attack_sequence("Scim_Attack")
			
var is_teleporting: bool = false:
	set(value):
		if value == is_teleporting: return
		is_teleporting = value
		if is_teleporting:
			_run_teleport_sequence()

func _process(_delta):
	if anim_locked: 
		return

	if is_walking:
		_play("Walk", 0.3)
	else:
		_play("2H_Idle" if has_2h else "Idle", 0.3)

func _handle_gathering_state(anim_name: String):
	if anim_name != "":
		anim_locked = true
		set_weapons_visibility(false)
		
		if not is_instance_valid(active_tool):
			active_tool = AXE_SCENE.instantiate()
			get_node(WEAPON_ATTACH).add_child(active_tool)
		
		var anim_ref = active_tool.get_node_or_null(anim_name + "Transform")
		if anim_ref:
			active_tool.transform = anim_ref.transform

		_loop_gathering_animation(anim_name)
	else:
		if is_instance_valid(active_tool):
			active_tool.queue_free()
		active_tool = null
		
		set_weapons_visibility(true)
		stop() 
		anim_locked = false 
		_play("Idle", 0.8)

func _loop_gathering_animation(anim_name: String):
	if anim_name == "Mine" and not is_mining: return
	if anim_name == "Chop" and not is_chopping: return
	
	play(anim_name, 0.3, 1.8)
	
	if anim_name == "Mine": seek(2.0, true)
	if anim_name == "Chop": seek(1.2, true)
	
	await animation_finished
	
	if (anim_name == "Chop" and not is_chopping) or (anim_name == "Mine" and not is_mining):
		seek(0.0, true) 
		stop()
		return

	if anim_locked:
		_loop_gathering_animation(anim_name)

func _play(anim_name: String, blend: float = -1.0, speed: float = 1.0):
	if current_animation == anim_name and is_playing():
		return
	play(anim_name, blend, speed)

func set_weapons_visibility(is_visible: bool):
	var paths = [WEAPON_ATTACH, OFFHAND_ATTACH]
	for path in paths:
		var node = get_node_or_null(path)
		if node:
			for child in node.get_children():
				if child is Node3D:
					child.visible = is_visible

func _run_attack_sequence(anim_name: String):
	anim_locked = true
	# Use the custom attack_speed calculated in CombatManager
	play(anim_name, 0.3, attack_speed) 
	await animation_finished
	is_attacking = false
	anim_locked = false
	attack_speed = 1.0

func _run_teleport_sequence():
	anim_locked = true
	_play("Teleport")
	await animation_finished
	#var teleportvfx = TELEPORT_SCENE.instantiate()
	#owner.add_child(teleportvfx) 
	#teleportvfx.global_position = get_parent().global_position
	anim_locked = false
	is_teleporting = false
