extends Node3D

@onready var label: Label3D = $Label3D

@export var lifetime := 1.0
@export var rise_speed := 0.6

# Desired on-screen size (your size 42 equivalent)
@export var target_screen_size := 1000.0

var time := 0.0

func setup(dmg: int):
	label.text = str(dmg)

func _process(delta: float):
	time += delta

	# --- FIXED ON-SCREEN SIZE SCALING ---
	var cam := get_viewport().get_camera_3d()
	if cam:
		var dist = global_position.distance_to(cam.global_position)
		var fov_rad = deg_to_rad(cam.fov)

		# This formula forces the splat to appear same size on screen no matter what
		var size = (dist * tan(fov_rad * 0.5))  # perspective correction
		var scale_mult = target_screen_size * 0.00025  # tuning coefficient

		scale = Vector3.ONE * (scale_mult * size)

	# Float upward
	global_position.y += rise_speed * delta

	# Fade out
	label.modulate.a = max(0.0, 1.0 - (time / lifetime))

	# Delete after lifetime
	if time >= lifetime:
		queue_free()
