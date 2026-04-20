extends Node2D


@export var radius := 220.0
@export var duration := 0.4
@export var ring_color := Color(0.46, 0.92, 1.0, 0.95)

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(elapsed / max(duration, 0.001), 0.0, 1.0)
	var current_radius: float = lerpf(24.0, radius, progress)
	var alpha: float = 1.0 - progress
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 64, Color(ring_color.r, ring_color.g, ring_color.b, alpha), 8.0 - 5.0 * progress)
	draw_arc(Vector2.ZERO, current_radius * 0.62, 0.0, TAU, 64, Color(ring_color.r, ring_color.g, ring_color.b, alpha * 0.6), 4.0)
	draw_circle(Vector2.ZERO, current_radius * 0.35, Color(ring_color.r, ring_color.g, ring_color.b, 0.08 * alpha))
