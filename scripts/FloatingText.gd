extends Label


@export var rise_distance := 36.0
@export var lifetime := 0.45


func setup(text_value: String, color_value: Color, scale_value := 1.0) -> void:
	text = text_value
	modulate = color_value
	scale = Vector2.ONE * scale_value


func _ready() -> void:
	var tween := create_tween()
	var target_position := position + Vector2(0, -rise_distance)
	tween.tween_property(self, "position", target_position, lifetime)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	tween.parallel().tween_property(self, "scale", scale * 1.08, lifetime * 0.35)
	tween.tween_callback(queue_free)
