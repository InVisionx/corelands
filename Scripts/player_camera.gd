extends Camera3D

# === CONFIG ===
@export var target: Node3D            # The player or focus point
@export var distance: float = 4.0
@export var zoom_speed: float = 1.0
@export var min_distance: float = 2.0
@export var max_distance: float = 10.0

@export var orbit_sensitivity: float = 0.3

# === INTERNAL STATE ===
var _yaw := 0.0
var _pitch := 20.0
var _orbiting := false

func _ready() -> void:
	if target:
		var dir: Vector3 = (global_position - target.global_position).normalized()
		_yaw = atan2(dir.x, dir.z)
		_pitch = rad_to_deg(asin(dir.y))

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	var bank_ui = get_parent().get_node_or_null("UI_Layer/BankUI")
	if bank_ui:
		return
		
	# --- Zoom ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		distance = max(min_distance, distance - zoom_speed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		distance = min(max_distance, distance + zoom_speed)

	# --- Start/stop orbiting ---
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_orbiting = event.pressed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _orbiting else Input.MOUSE_MODE_VISIBLE)

	# --- Orbit ---
	elif event is InputEventMouseMotion and _orbiting:
		_yaw -= deg_to_rad(event.relative.x * orbit_sensitivity)
		_pitch -= event.relative.y * orbit_sensitivity
		_pitch = clamp(_pitch, -60, 80)

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
