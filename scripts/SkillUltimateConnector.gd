extends Control


@export var state := "locked"
@export var line_width := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var colors := _get_state_colors()
	var line_color: Color = colors["line"]
	var glow_color: Color = colors["glow"]
	var left_x: float = 0.0
	var center_x: float = size.x * 0.56
	var right_x: float = size.x
	var top_y: float = 6.0
	var bottom_y: float = size.y - 6.0
	var center_y: float = size.y * 0.5

	if glow_color.a > 0.0:
		draw_line(Vector2(left_x, top_y), Vector2(center_x, center_y), glow_color, line_width + 6.0, true)
		draw_line(Vector2(left_x, bottom_y), Vector2(center_x, center_y), glow_color, line_width + 6.0, true)
		draw_line(Vector2(center_x, center_y), Vector2(right_x, center_y), glow_color, line_width + 6.0, true)

	draw_line(Vector2(left_x, top_y), Vector2(center_x, center_y), line_color, line_width, true)
	draw_line(Vector2(left_x, bottom_y), Vector2(center_x, center_y), line_color, line_width, true)
	draw_line(Vector2(center_x, center_y), Vector2(right_x, center_y), line_color, line_width, true)


func _get_state_colors() -> Dictionary:
	match state:
		"unlocked":
			return {
				"line": Color(0.43, 0.95, 0.73, 0.98),
				"glow": Color(0.43, 0.95, 0.73, 0.24)
			}
		"available":
			return {
				"line": Color(0.99, 0.78, 0.36, 0.98),
				"glow": Color(0.99, 0.78, 0.36, 0.24)
			}
		_:
			return {
				"line": Color(0.34, 0.42, 0.54, 0.9),
				"glow": Color(0.0, 0.0, 0.0, 0.0)
			}
