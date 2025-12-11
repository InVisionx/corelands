extends Node

@onready var anim: AnimationPlayer = $"."

var has_2h: bool = false
var is_attacking: bool = false
var is_teleporting: bool = false
var is_walking: bool = false

var anim_locked: bool = false  # <-- NEW
var current_anim := ""
var previous_anim := ""


func _process(_delta):
	# If locked, do NOT override animations
	if anim_locked:
		return

	if is_attacking:
		_play("Scim_Attack")
		return

	if is_walking:
		_play("Walk")
		return

	if has_2h:
		_play("2H_Idle")
	else:
		_play("Idle")


func _play(name: String):
	# Respect animation lock
	if anim_locked:
		return

	# Already playing this animation
	if anim.current_animation == name and anim.is_playing():
		return

	previous_anim = current_anim
	current_anim = name
	
	var is_attack := name.contains("Attack") or previous_anim.contains("Attack")
	if is_attack:
		anim.play(name, 0.3)
	else:
		anim.play(name)

func start_attack():
	is_attacking = true
	anim_locked = true
	_play("Scim_Attack")


func on_attack_finished():
	is_attacking = false
	anim_locked = false
	_return_to_idle()


func on_teleport_finished():
	is_teleporting = false
	anim_locked = false
	_return_to_idle()


func _return_to_idle():
	if has_2h:
		_play("2H_Idle")
	else:
		_play("Idle")
