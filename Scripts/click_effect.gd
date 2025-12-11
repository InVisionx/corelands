extends Control

@export var duration := 0.3
@export var start_scale := 1.5
@export var end_scale := 0.0

func _ready():
	scale = Vector2(start_scale, start_scale)
	modulate.a = 0.7

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(end_scale, end_scale), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, duration)
	tween.finished.connect(queue_free)
