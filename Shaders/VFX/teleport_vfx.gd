extends Node3D

@onready var ring: GPUParticles3D = $Ring
@onready var beam: GPUParticles3D = $Beam

func _ready() -> void:
	await get_tree().process_frame
	
	# Start ring immediately
	if ring:
		ring.restart()
		ring.emitting = true

	# Wait 1 second, then start beam
	await get_tree().create_timer(0.5).timeout

	if beam:
		beam.restart()
		beam.emitting = true

	# Optional: clean up effect after 3 seconds total
	await get_tree().create_timer(3.8).timeout
	queue_free()
	
func set_color(new_color: Color):
	for node in [ring, beam]:
		if node and node.draw_pass_1:
			var mesh: Mesh = node.draw_pass_1
			if mesh.get_surface_count() > 0:
				var mat := mesh.surface_get_material(0)
				if mat:
					var new_mat = mat.duplicate()
					new_mat.set_shader_parameter("tint_color", new_color)
					mesh.surface_set_material(0, new_mat)
					node.restart()
