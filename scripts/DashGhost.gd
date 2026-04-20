extends Polygon2D


var fade_time := 0.18


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.parallel().tween_property(self, "scale", scale * 0.92, fade_time)
	tween.tween_callback(queue_free)
