extends CharacterBody3D

signal damaged_by(attacker)

@export var interaction: Clickable
@export var max_hp := 1
var hp = 0

@onready var movement = $NPCMovement
@onready var combat = $NPCCombatAI
@onready var anim: AnimationPlayer = $zombie_model/AnimationPlayer
@onready var health_bar = $HealthBar/SubViewport/TextureProgressBar

func _ready():
	connect("damaged_by", combat._on_damaged_by)
	movement.start()
	hp = max_hp
	health_bar.max_value = max_hp
	health_bar.value = max_hp
	health_bar.visible = false
	print("NPC HP set to:", hp)

func take_damage(amount, attacker=null):
	hp -= amount
	health_bar.value = hp
	print("NPC HP:", hp)

	if attacker != null:
		emit_signal("damaged_by", attacker)

	if hp <= 0:
		die()

func die():
	combat.stop_combat()
	movement.stop()
	movement.disabled = true  # <-- movement permanently disabled

	velocity = Vector3.ZERO
	set_physics_process(false)

	anim.play("Die")

	var finished_anim = await anim.animation_finished

	if finished_anim == "Die":
		queue_free()
