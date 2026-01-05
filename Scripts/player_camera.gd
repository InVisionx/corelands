extends Camera3D

# === CONFIG ===
@export var target: Node3D
@export var distance: float = 4.0
@export var zoom_speed: float = 0.5 # Lower this for smoother mobile zoom
@export var min_distance: float = 2.0
@export var max_distance: float = 10.0

@export var orbit_sensitivity: float = 0.3
@export var touch_sensitivity: float = 0.3 

# === INTERNAL STATE ===
var _yaw := 0.0
var _pitch := 20.0
var _orbiting := false

# === NEW VARIABLES FOR PINCH ZOOM ===
var _touch_points: Dictionary = {}
var _last_pinch_distance: float = 0.0

func _ready() -> void:
	if target:
		var dir: Vector3 = (global_position - target.global_position).normalized()
		_yaw = atan2(dir.x, dir.z)
		_pitch = rad_to_deg(asin(dir.y))

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	# Ignore UI
	var bank_ui = get_parent().get_node_or_null("UI_Layer/BankUI")
	if bank_ui and bank_ui.visible:
		return
	
	# --- MOUSE LOGIC (Keep existing) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = max(min_distance, distance - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = min(max_distance, distance + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_orbiting = event.pressed
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _orbiting else Input.MOUSE_MODE_VISIBLE)

	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= deg_to_rad(event.relative.x * orbit_sensitivity)
		_pitch -= event.relative.y * orbit_sensitivity
		_pitch = clamp(_pitch, -60, 80)

	# --- TOUCH LOGIC (The new part) ---
	
	# 1. Track fingers touching/leaving
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		
		# CRITICAL FIX FOR SNAPPING:
		# When 2 fingers are confirmed, reset the distance calculator immediately.
		if _touch_points.size() == 2:
			var pos1 = _touch_points.values()[0]
			var pos2 = _touch_points.values()[1]
			_last_pinch_distance = pos1.distance_to(pos2)

	# 2. Handle Drag (Orbit) and Pinch (Zoom)
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		
		if _touch_points.size() == 1:
			# Orbit
			_yaw -= deg_to_rad(event.relative.x * touch_sensitivity)
			_pitch -= event.relative.y * touch_sensitivity
			_pitch = clamp(_pitch, -60, 80)
			
		elif _touch_points.size() == 2:
			# Zoom
			var pos1 = _touch_points.values()[0]
			var pos2 = _touch_points.values()[1]
			var current_dist = pos1.distance_to(pos2)
			
			# If we have a previous distance, calculate the difference
			if _last_pinch_distance > 0:
				var zoom_change = _last_pinch_distance - current_dist
				
				# 0.01 is a scaler to convert pixels to world units
				distance += zoom_change * 0.01 * zoom_speed
				distance = clamp(distance, min_distance, max_distance)
			
			# Update for the next frame
			_last_pinch_distance = current_dist

func _process(_delta: float) -> void:
	if not target:
		return

	var dir = Vector3(
		sin(_yaw) * cos(deg_to_rad(_pitch)),
		sin(deg_to_rad(_pitch)),
		cos(_yaw) * cos(deg_to_rad(_pitch))
	)
	global_position = target.global_position + dir * distance
	look_at(target.global_position, Vector3.UP)
