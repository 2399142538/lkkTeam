extends Line2D


func _ready() -> void:
	modulate.a = 0.95
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)
