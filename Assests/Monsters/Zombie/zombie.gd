extends CharacterBody3D

signal damaged_by(attacker)

@export var interaction: Clickable
@export var max_hp := 1
@export var respawn_time := 8.0   # <--- adjustable in editor

var hp = 0
var is_dead = false
var spawn_position: Vector3

@onready var movement = $NPCMovement
@onready var combat = $NPCCombatAI
@onready var anim: AnimationPlayer = $zombie_model/AnimationPlayer
@onready var health_bar = $HealthBar/SubViewport/TextureProgressBar

func _ready():
	spawn_position = global_position
	connect("damaged_by", combat._on_damaged_by)

	movement.start()
	hp = max_hp
	health_bar.max_value = max_hp
	health_bar.value = max_hp
	health_bar.visible = false

	print("NPC HP set to:", hp)


func take_damage(amount, attacker=null):
	if is_dead:
		return

	hp -= amount
	health_bar.value = hp
	print("NPC HP:", hp)

	if attacker != null:
		emit_signal("damaged_by", attacker)

	if hp <= 0:
		die()


func die():
	if is_dead:
		return

	is_dead = true
	combat.stop_combat()
	movement.stop()
	movement.disabled = true

	velocity = Vector3.ZERO
	set_physics_process(false)

	anim.play("Die")
	await anim.animation_finished

	# Hide but DO NOT delete
	visible = false
	health_bar.visible = false
	collision_layer = 0
	collision_mask = 0

	# Wait respawn delay
	await get_tree().create_timer(respawn_time).timeout
	
	anim.play("Idle")
	respawn()


func respawn():
	# Reset stats
	hp = max_hp
	health_bar.value = hp
	is_dead = false

	# Move back to spawn
	global_position = spawn_position
	velocity = Vector3.ZERO

	# Restore visibility & collisions
	visible = true
	collision_layer = 1
	collision_mask = 1
	if health_bar.visible: health_bar.visible = false

	# Re-enable AI
	movement.disabled = false
	movement.start()
	combat.reset_state()
	set_physics_process(true)

	print("NPC respawned with HP:", hp)
