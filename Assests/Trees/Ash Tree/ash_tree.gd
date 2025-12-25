extends Clickable

@export var gather_id: String = "gravewoodsword"
@export var gather_interval: float = 1.8
@export var success_chance: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group(interaction_type)
	
func on_gather(_player):
	print("in tick")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
