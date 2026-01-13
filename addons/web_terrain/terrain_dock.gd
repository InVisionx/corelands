@tool
extends Control

# The reference to the actual tool node in the scene
var current_tool_node: Node = null

# --- 1. UI REFERENCES ---

@onready var mode_label = $MainScroll/VBoxContainer/ModeLabel
@onready var refresh_btn  = $MainScroll/VBoxContainer/HBoxContainer/RefreshButton

# Nested Container Controls
@onready var size_label     = $MainScroll/VBoxContainer/HBoxContainer/HBoxContainer/BrushSizeLabel
@onready var size_slider    = $MainScroll/VBoxContainer/HBoxContainer/HBoxContainer/BrushSizeSlider

# NEW: Opacity Controls
@onready var opacity_label  = $MainScroll/VBoxContainer/HBoxContainer/HBoxContainer/OpacityLabel
@onready var opacity_slider = $MainScroll/VBoxContainer/HBoxContainer/HBoxContainer/OpacitySlider

@onready var height_input   = $MainScroll/VBoxContainer/HBoxContainer/HBoxContainer/HeightSpinBox
@onready var color_picker   = $MainScroll/VBoxContainer/HBoxContainer/ColorPicker
func _ready():
	# --- BUTTON SETUP ---
	var paint_btn = $MainScroll/VBoxContainer/HBoxContainer/PaintButton
	var raise_btn = $MainScroll/VBoxContainer/HBoxContainer/RaiseButton
	var lower_btn = $MainScroll/VBoxContainer/HBoxContainer/LowerButton
	var flat_btn  = $MainScroll/VBoxContainer/HBoxContainer/FlattenButton
	
	if not paint_btn:
		printerr("Terrain Tool Error: Could not find mode buttons.")
		return

	paint_btn.pressed.connect(_on_mode_changed.bind(0))
	raise_btn.pressed.connect(_on_mode_changed.bind(1))
	lower_btn.pressed.connect(_on_mode_changed.bind(2))
	flat_btn.pressed.connect(_on_mode_changed.bind(3))
	
	if refresh_btn:
		refresh_btn.pressed.connect(_on_refresh_pressed)
	
	# --- CONNECT SLIDERS ---
	size_slider.value_changed.connect(_on_size_changed)
	height_input.value_changed.connect(_on_height_changed)
	color_picker.color_changed.connect(_on_color_changed)
	
	# NEW: Connect Opacity
	if opacity_slider:
		opacity_slider.value_changed.connect(_on_opacity_changed)
	
	# Try to find the tool immediately
	_on_refresh_pressed()

# --- CONNECTION LOGIC ---

func set_terrain_node(node):
	current_tool_node = node
	
	if current_tool_node:
		# Sync UI with Tool Settings
		size_slider.value = current_tool_node.brush_size
		height_input.value = current_tool_node.target_height
		color_picker.color = current_tool_node.paint_color
		
		# NEW: Sync Opacity
		if opacity_slider:
			opacity_slider.value = current_tool_node.brush_opacity
			_update_opacity_label(current_tool_node.brush_opacity)
		
		# Update Text Labels
		_update_size_label(current_tool_node.brush_size)
		_update_mode_text(current_tool_node.mode)
		print("Terrain Dock connected to: ", current_tool_node.name)
	else:
		if mode_label:
			mode_label.text = "MODE: DISCONNECTED"

func _on_refresh_pressed():
	var root = EditorInterface.get_edited_scene_root()
	if not root: return
	var found_node = _find_terrain_node_recursive(root)
	set_terrain_node(found_node)

func _find_terrain_node_recursive(node):
	if node is TerrainTool3D: return node
	for child in node.get_children():
		var result = _find_terrain_node_recursive(child)
		if result: return result
	return null

# --- SIGNAL HANDLERS ---

func _on_mode_changed(mode_index):
	if current_tool_node:
		current_tool_node.mode = mode_index
		_update_mode_text(mode_index)

func _on_size_changed(value):
	#_update_size_label(value)
	if current_tool_node:
		current_tool_node.brush_size = value

# NEW: Opacity Handler
func _on_opacity_changed(value):
	_update_opacity_label(value)
	if current_tool_node:
		current_tool_node.brush_opacity = value

func _on_color_changed(color):
	if current_tool_node:
		current_tool_node.paint_color = color

func _on_height_changed(value):
	if current_tool_node:
		current_tool_node.target_height = value

# --- UI UPDATERS ---

func _update_size_label(value):
	if size_label:
		size_label.text = "Size: %.1f" % value

# NEW: Opacity Label Updater
func _update_opacity_label(value):
	if opacity_label:
		# Display as percentage (e.g., "Opacity: 100%")
		opacity_label.text = "Opacity: %d%%" % (value * 100)

func _update_mode_text(index):
	if not mode_label: return
	var mode_name = "UNKNOWN"
	match index:
		0: mode_name = "PAINT"
		1: mode_name = "RAISE"
		2: mode_name = "LOWER"
		3: mode_name = "FLATTEN"
	mode_label.text = "MODE: " + mode_name
