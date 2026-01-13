extends Node2D

# Drag your Label here in the Inspector
@export var debug_label: Label
@export var chunk_size: float = 64.0

var player_node: Node3D

func _ready():
	# 1. Find the Player automatically
	# This searches the scene for a node explicitly named "Player"
	# (Make sure your Player node is actually named "Player"!)
	player_node = get_tree().root.find_child("Player", true, false)
	
	if player_node:
		print("Debug: Found Player!")
	else:
		print("Debug: COULD NOT FIND PLAYER! Check naming.")

func _process(delta):
	if player_node and debug_label:
		# 2. Get Player Position
		var pos = player_node.global_position
		
		# 3. Do the Chunk Math
		# We use floor() to handle negative coordinates correctly
		var cx = floor(pos.x / chunk_size)
		var cz = floor(pos.z / chunk_size)
		
		# 4. Update the Label
		debug_label.text = "Position: %s\nChunk: [%d, %d]" % [pos, cx, cz]
