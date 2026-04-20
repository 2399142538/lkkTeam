extends Node2D


@export var radius := 56.0
@export var duration := 0.22
@export var blast_color := Color(1.0, 0.62, 0.22, 0.95)

var elapsed := 0.0


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(elapsed / max(duration, 0.001), 0.0, 1.0)
	var outer_radius: float = lerpf(10.0, radius, progress)
	var inner_radius: float = outer_radius * 0.46
	var alpha: float = 1.0 - progress
	draw_circle(Vector2.ZERO, outer_radius * 0.72, Color(blast_color.r, blast_color.g, blast_color.b, 0.14 * alpha))
	draw_circle(Vector2.ZERO, inner_radius, Color(1.0, 0.92, 0.56, 0.2 * alpha))
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 56, Color(blast_color.r, blast_color.g, blast_color.b, 0.92 * alpha), 7.0 - progress * 3.5)
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0 + progress * 0.22
		var direction := Vector2.RIGHT.rotated(angle)
		draw_line(direction * (inner_radius * 0.5), direction * (outer_radius + 12.0 * (1.0 - progress)), Color(1.0, 0.9, 0.62, 0.8 * alpha), 2.4)
