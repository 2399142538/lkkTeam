extends Node2D


@export var radius := 90.0
@export var arc_degrees := 100.0
@export var duration := 0.14
@export var slash_color := Color(1.0, 0.9, 0.64, 0.92)

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
	var start_angle: float = -deg_to_rad(arc_degrees) * 0.5
	var end_angle: float = deg_to_rad(arc_degrees) * 0.5
	draw_arc(Vector2.ZERO, radius * (0.75 + progress * 0.22), start_angle, end_angle, 36, Color(slash_color.r, slash_color.g, slash_color.b, alpha), 10.0 - progress * 4.0)
	draw_arc(Vector2.ZERO, radius * (0.48 + progress * 0.18), start_angle, end_angle, 36, Color(slash_color.r, slash_color.g, slash_color.b, alpha * 0.52), 5.0)
