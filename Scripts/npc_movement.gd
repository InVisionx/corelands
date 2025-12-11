extends Node

@export var model: String
@export var wander_radius: float = 12.0
@export var move_speed: float = 0.5
@export var rotation_speed: float = 6.0
@export var idle_time_range := Vector2(1.0, 3.0)
@export var face_offset_degrees: float = 180.0

var idle_timer := 0.0
var state := "idle"
var spawn_position: Vector3
var npc: CharacterBody3D
var agent: NavigationAgent3D
var anim: AnimationPlayer
var _model: Node3D
var disabled := false
var is_wandering := true
var last_wander_target: Vector3 = Vector3.ZERO


func _ready():
	npc = get_parent()
	agent = npc.get_node("NavigationAgent3D")
	anim = npc.get_node(model + "/AnimationPlayer")
	spawn_position = npc.global_position
	_model = npc.get_node(model)

func start():
	disabled = false
	is_wandering = true
	_set_state("idle")
	_start_idle()


func stop():
	disabled = true
	agent.target_position = npc.global_position
	npc.velocity = Vector3.ZERO
	_set_state("idle")


func _physics_process(delta):
	if disabled:
		return

	match state:
		"idle":
			_process_idle(delta)
		"walk":
			_process_walk(delta)


func move_to(pos: Vector3):
	if disabled:
		return

	state = "walk"
	is_wandering = false
	anim.play("Walk")
	agent.target_position = pos


func _process_idle(delta):
	idle_timer -= delta
	if idle_timer <= 0:
		_pick_new_nav_target()
		_set_state("walk")


func _process_walk(delta):
	# Path finished
	if agent.is_navigation_finished():
		if is_wandering:
			_start_idle()
		else:
			npc.velocity = Vector3.ZERO
		return

	var next_pos = agent.get_next_path_position()
	var direction = next_pos - npc.global_position
	direction.y = 0

	if direction.length() < 0.05:
		if is_wandering:
			_start_idle()
		else:
			npc.velocity = Vector3.ZERO
		return

	_rotate_model(direction, delta)

	npc.velocity = direction.normalized() * move_speed
	npc.move_and_slide()


func _rotate_model(direction: Vector3, delta: float):
	var target_basis = Basis.looking_at(direction, Vector3.UP)
	target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(face_offset_degrees))

	var current_quat = _model.basis.get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()

	var next_quat = current_quat.slerp(target_quat, rotation_speed * delta)
	_model.basis = Basis(next_quat).scaled(_model.scale)


func _pick_new_nav_target():
	is_wandering = true

	var angle = randf() * TAU
	var dist = randf() * wander_radius
	var desired = spawn_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)

	var nav_map = agent.get_navigation_map()
	last_wander_target = NavigationServer3D.map_get_closest_point(nav_map, desired)
	agent.target_position = last_wander_target


func return_to_last_wander_point():
	if last_wander_target != Vector3.ZERO:
		is_wandering = true
		state = "walk"
		anim.play("Walk")
		agent.target_position = last_wander_target


func _start_idle():
	is_wandering = true
	_set_state("idle")
	idle_timer = randf_range(idle_time_range.x, idle_time_range.y)
	npc.velocity = Vector3.ZERO


func _set_state(new_state):
	if state == new_state:
		return
	
	state = new_state

	match new_state:
		"idle":
			anim.play("Idle")
		"walk":
			anim.play("Walk")
