extends Control


@export var state := "locked"
@export var show_branch_stub := false
@export var line_width := 5.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center_y: float = size.y * 0.5
	var start_x: float = 0.0
	var end_x: float = max(size.x, start_x + 1.0)
	var colors := _get_state_colors()
	var line_color: Color = colors["line"]
	var glow_color: Color = colors["glow"]
	var stub_x: float = 6.0

	if glow_color.a > 0.0:
		draw_line(Vector2(start_x, center_y), Vector2(end_x, center_y), glow_color, line_width + 6.0, true)
		if show_branch_stub:
			draw_line(Vector2(stub_x, 0.0), Vector2(stub_x, center_y), glow_color, line_width + 6.0, true)

	draw_line(Vector2(start_x, center_y), Vector2(end_x, center_y), line_color, line_width, true)
	if show_branch_stub:
		draw_line(Vector2(stub_x, 0.0), Vector2(stub_x, center_y), line_color, line_width, true)


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
