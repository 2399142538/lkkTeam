extends Control


@export var stage_id := "ruins"


func set_stage(new_stage_id: String) -> void:
	stage_id = new_stage_id
	queue_redraw()


func _draw() -> void:
	var frame_rect := Rect2(Vector2.ZERO, size)
	draw_rect(frame_rect, _get_bg_color(), true)
	draw_rect(frame_rect, _get_border_color(), false, 3.0)

	match stage_id:
		"factory":
			_draw_factory_map(frame_rect)
		"sanctum":
			_draw_sanctum_map(frame_rect)
		_:
			_draw_ruins_map(frame_rect)


func _draw_ruins_map(frame_rect: Rect2) -> void:
	draw_rect(frame_rect.grow(-18.0), Color(0.07, 0.12, 0.11, 0.9), true)
	for index in range(6):
		var x := 30.0 + float(index) * 48.0
		draw_line(Vector2(x, 20), Vector2(x, frame_rect.size.y - 20), Color(0.28, 0.42, 0.36, 0.24), 2.0)
	for index in range(4):
		var y := 28.0 + float(index) * 52.0
		draw_line(Vector2(18, y), Vector2(frame_rect.size.x - 18, y), Color(0.24, 0.36, 0.3, 0.18), 2.0)
	draw_circle(frame_rect.size * 0.5, 26.0, Color(0.96, 0.73, 0.35, 0.85))
	draw_arc(frame_rect.size * 0.5, 48.0, 0.0, TAU, 40, Color(0.78, 0.94, 0.84, 0.4), 4.0)


func _draw_factory_map(frame_rect: Rect2) -> void:
	draw_rect(frame_rect.grow(-18.0), Color(0.09, 0.1, 0.14, 0.92), true)
	for index in range(5):
		var y := 26.0 + float(index) * 46.0
		draw_rect(Rect2(Vector2(24.0, y), Vector2(frame_rect.size.x - 48.0, 18.0)), Color(0.16, 0.22, 0.28, 0.8), true)
	for index in range(3):
		var x := 40.0 + float(index) * 78.0
		draw_rect(Rect2(Vector2(x, 32.0), Vector2(22.0, frame_rect.size.y - 64.0)), Color(0.22, 0.31, 0.38, 0.6), true)
	draw_rect(Rect2(frame_rect.size * 0.5 - Vector2(40, 18), Vector2(80, 36)), Color(0.95, 0.53, 0.24, 0.92), true)
	draw_arc(frame_rect.size * 0.5, 58.0, 0.0, TAU, 44, Color(0.62, 0.88, 1.0, 0.34), 4.0)


func _draw_sanctum_map(frame_rect: Rect2) -> void:
	draw_rect(frame_rect.grow(-18.0), Color(0.11, 0.08, 0.14, 0.92), true)
	var center := frame_rect.size * 0.5
	for index in range(5):
		var radius := 24.0 + float(index) * 18.0
		draw_arc(center, radius, 0.0, TAU, 56, Color(0.62, 0.52 + float(index) * 0.06, 0.96, 0.24), 3.0)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var point := center + Vector2.RIGHT.rotated(angle) * 72.0
		draw_circle(point, 10.0, Color(0.46, 0.92, 1.0, 0.72))
	draw_circle(center, 22.0, Color(1.0, 0.82, 0.42, 0.95))


func _get_bg_color() -> Color:
	match stage_id:
		"factory":
			return Color(0.06, 0.08, 0.12, 0.98)
		"sanctum":
			return Color(0.09, 0.06, 0.12, 0.98)
		_:
			return Color(0.06, 0.09, 0.08, 0.98)


func _get_border_color() -> Color:
	match stage_id:
		"factory":
			return Color(0.52, 0.84, 1.0, 0.86)
		"sanctum":
			return Color(0.82, 0.62, 1.0, 0.86)
		_:
			return Color(0.48, 0.94, 0.78, 0.86)
