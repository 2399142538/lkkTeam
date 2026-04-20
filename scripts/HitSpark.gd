extends Node2D


@export var duration := 0.16
@export var spark_color := Color(1, 0.9, 0.56, 1)

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(elapsed / max(duration, 0.001), 0.0, 1.0)
	var alpha: float = 1.0 - progress
	var length: float = lerpf(6.0, 18.0, progress)
	for index in range(6):
		var angle: float = deg_to_rad(float(index) * 60.0)
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(direction * 4.0, direction * length, Color(spark_color.r, spark_color.g, spark_color.b, alpha), 2.0)
