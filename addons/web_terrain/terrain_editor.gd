@tool
extends Node3D
class_name TerrainTool3D

# Added SET_HEIGHT to the enum
enum EditorMode { PAINT, SCULPT_RAISE, SCULPT_LOWER, SCULPT_SET_HEIGHT }

@export_group("General Settings")
@export var active: bool = true
@export var mode: EditorMode = EditorMode.PAINT
@export var brush_size: float = 4.0

@export_group("Paint Settings")
@export var paint_color: Color = Color.BLACK
@export_range(0.0, 1.0) var brush_opacity: float = 1.0

@export_group("Sculpt Settings")
@export var sculpt_strength: float = 0.5
@export var target_height: float = 0.0 # The Y-level for the Set Height mode

var mdt = MeshDataTool.new()
var current_mesh_instance: MeshInstance3D = null
var undo_redo: EditorUndoRedoManager
var mesh_state_before: Dictionary = {} 
var is_painting: bool = false

func _ready():
	if Engine.is_editor_hint():
		undo_redo = EditorInterface.get_editor_undo_redo()

func _process(_delta):
	if not Engine.is_editor_hint() or not active:
		return

	if Input.is_key_pressed(KEY_V):
		if not is_painting:
			_start_stroke()
		_handle_input_under_mouse()
	elif is_painting:
		_end_stroke()

func _start_stroke():
	is_painting = true
	var result = _raycast_under_mouse()
	if result:
		var target = _get_mesh_from_hit(result.collider)
		if target:
			_prepare_mesh_for_editing(target)
			mesh_state_before = _capture_mesh_state(target.mesh)

func _end_stroke():
	is_painting = false
	if current_mesh_instance and !mesh_state_before.is_empty():
		var state_after = _capture_mesh_state(current_mesh_instance.mesh)
		undo_redo.create_action("Terrain Edit: " + str(EditorMode.keys()[mode]))
		undo_redo.add_do_method(self, "_restore_mesh_state", current_mesh_instance, state_after)
		undo_redo.add_undo_method(self, "_restore_mesh_state", current_mesh_instance, mesh_state_before)
		undo_redo.commit_action(false) 
		
	current_mesh_instance = null
	mesh_state_before = {}

# --- CORE MESH LOGIC ---

func _apply_effect(mesh_node: MeshInstance3D, global_hit_pos: Vector3):
	if current_mesh_instance != mesh_node:
		current_mesh_instance = mesh_node
		mdt.create_from_surface(current_mesh_instance.mesh, 0)

	var local_pos = current_mesh_instance.to_local(global_hit_pos)
	var modified = false
	var brush_sq = brush_size * brush_size
	
	for i in range(mdt.get_vertex_count()):
		var v_pos = mdt.get_vertex(i)
		var dist_sq = v_pos.distance_squared_to(local_pos)
		
		if dist_sq < brush_sq:
			modified = true
			var falloff = 1.0 - (sqrt(dist_sq) / brush_size)
			
			match mode:
				EditorMode.PAINT:
					var old_col = mdt.get_vertex_color(i)
					mdt.set_vertex_color(i, old_col.lerp(paint_color, brush_opacity * falloff))
				
				EditorMode.SCULPT_RAISE:
					v_pos.y += sculpt_strength * falloff
					mdt.set_vertex(i, v_pos)
				
				EditorMode.SCULPT_LOWER:
					v_pos.y -= sculpt_strength * falloff
					mdt.set_vertex(i, v_pos)
				
				# NEW: SET HEIGHT LOGIC
				EditorMode.SCULPT_SET_HEIGHT:
					# We lerp towards the target height based on strength and falloff
					# This makes the flattening feel smooth rather than instant/jagged
					v_pos.y = lerp(v_pos.y, target_height, sculpt_strength * falloff)
					mdt.set_vertex(i, v_pos)
	
	if modified:
		_commit_mdt_to_mesh()

# --- REFRESH / COMMIT HELPERS ---

func _commit_mdt_to_mesh():
	current_mesh_instance.mesh.clear_surfaces()
	mdt.commit_to_surface(current_mesh_instance.mesh)
	_refresh_mesh_infrastructure(current_mesh_instance)

func _refresh_mesh_infrastructure(mesh_node: MeshInstance3D):
	var st = SurfaceTool.new()
	st.create_from(mesh_node.mesh, 0)
	st.generate_normals()
	mesh_node.mesh = st.commit()
	_update_collision(mesh_node)

# --- UNDO/REDO HELPERS ---

func _capture_mesh_state(mesh: ArrayMesh) -> Dictionary:
	var state_mdt = MeshDataTool.new()
	state_mdt.create_from_surface(mesh, 0)
	var verts = PackedVector3Array()
	var colors = PackedColorArray()
	for i in range(state_mdt.get_vertex_count()):
		verts.append(state_mdt.get_vertex(i))
		colors.append(state_mdt.get_vertex_color(i))
	return {"verts": verts, "colors": colors}

func _restore_mesh_state(mesh_node: MeshInstance3D, state: Dictionary):
	var restore_mdt = MeshDataTool.new()
	restore_mdt.create_from_surface(mesh_node.mesh, 0)
	for i in range(restore_mdt.get_vertex_count()):
		restore_mdt.set_vertex(i, state["verts"][i])
		restore_mdt.set_vertex_color(i, state["colors"][i])
	
	mesh_node.mesh.clear_surfaces()
	restore_mdt.commit_to_surface(mesh_node.mesh)
	_refresh_mesh_infrastructure(mesh_node)

# --- UTILITIES ---

func _handle_input_under_mouse():
	var result = _raycast_under_mouse()
	if result:
		var target = _get_mesh_from_hit(result.collider)
		if target:
			_apply_effect(target, result.position)
			_draw_debug_sphere(result.position)

func _raycast_under_mouse():
	var viewport = EditorInterface.get_editor_viewport_3d(0)
	var camera = viewport.get_camera_3d()
	var mouse_pos = viewport.get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var space = get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))

func _get_mesh_from_hit(collider):
	if collider is MeshInstance3D: return collider
	if collider.get_parent() is MeshInstance3D: return collider.get_parent()
	return null

func _update_collision(mesh_node: MeshInstance3D):
	for child in mesh_node.get_children():
		if child is StaticBody3D:
			var shape_node = child.get_child(0)
			if shape_node is CollisionShape3D:
				shape_node.shape = mesh_node.mesh.create_trimesh_shape()

func _prepare_mesh_for_editing(mesh_node: MeshInstance3D):
	var mesh = mesh_node.mesh
	if not mesh is ArrayMesh or mesh.resource_path.contains(".glb"):
		var st = SurfaceTool.new()
		st.create_from(mesh, 0)
		mesh_node.mesh = st.commit()
	_ensure_material(mesh_node)

func _ensure_material(mesh_node: MeshInstance3D):
	var mat = mesh_node.get_active_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		mesh_node.set_surface_override_material(0, mat)
	if mat is StandardMaterial3D:
		mat.vertex_color_use_as_albedo = true
		if mat.albedo_color == Color.BLACK: mat.albedo_color = Color.WHITE

func _draw_debug_sphere(pos):
	var debug_ball = MeshInstance3D.new()
	debug_ball.mesh = SphereMesh.new()
	debug_ball.mesh.radius = brush_size
	debug_ball.mesh.height = brush_size * 2.0
	var ball_mat = StandardMaterial3D.new()
	
	# Visual color change for Set Height mode
	if mode == EditorMode.SCULPT_SET_HEIGHT:
		ball_mat.albedo_color = Color(0, 1, 1, 0.2) # Cyan
	else:
		ball_mat.albedo_color = Color(1, 1, 0, 0.2) # Yellow
		
	ball_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_ball.material_override = ball_mat
	get_tree().root.add_child(debug_ball)
	debug_ball.global_position = pos
	await get_tree().process_frame
	debug_ball.queue_free()
