extends Node2D


@export var tile_size := Vector2(1280, 720)
@export var draw_padding := Vector2(480, 320)

var focus_position := Vector2.ZERO
var view_size := Vector2(1280, 720)
var stage_id := "ruins"


func set_focus_state(new_focus_position: Vector2, new_view_size: Vector2) -> void:
	focus_position = new_focus_position
	view_size = new_view_size
	queue_redraw()


func set_stage(new_stage_id: String) -> void:
	stage_id = new_stage_id
	queue_redraw()


func _draw() -> void:
	var visible_rect := Rect2(
		focus_position - view_size * 0.5 - draw_padding,
		view_size + draw_padding * 2.0
	)
	var start_x: float = floor(visible_rect.position.x / tile_size.x) * tile_size.x
	var end_x: float = ceil(visible_rect.end.x / tile_size.x) * tile_size.x
	var start_y: float = floor(visible_rect.position.y / tile_size.y) * tile_size.y
	var end_y: float = ceil(visible_rect.end.y / tile_size.y) * tile_size.y

	var tile_x := start_x
	while tile_x < end_x:
		var tile_y := start_y
		while tile_y < end_y:
			_draw_tile(Rect2(Vector2(tile_x, tile_y), tile_size))
			tile_y += tile_size.y
		tile_x += tile_size.x


func _draw_tile(tile_rect: Rect2) -> void:
	var outer_rect := tile_rect
	var inset_rect := outer_rect.grow(-28.0)
	var core_rect := outer_rect.grow(-72.0)

	match stage_id:
		"factory":
			_draw_factory_tile(outer_rect, inset_rect, core_rect)
		"sanctum":
			_draw_sanctum_tile(outer_rect, inset_rect, core_rect)
		_:
			_draw_ruins_tile(outer_rect, inset_rect, core_rect)


func _draw_ruins_tile(outer_rect: Rect2, inset_rect: Rect2, core_rect: Rect2) -> void:
	draw_rect(outer_rect, Color(0.035, 0.045, 0.06, 1.0), true)
	draw_rect(inset_rect, Color(0.065, 0.085, 0.105, 1.0), true)
	draw_rect(core_rect, Color(0.08, 0.1, 0.12, 1.0), true)

	_draw_floor_panels(core_rect)
	_draw_grid(core_rect, Color(0.2, 0.28, 0.32, 0.2), Color(0.14, 0.2, 0.24, 0.12))
	_draw_energy_rails(outer_rect, inset_rect, Color(0.42, 0.77, 0.92, 0.24), Color(0.18, 0.48, 0.62, 0.18))
	_draw_corner_beacons(inset_rect, Color(0.96, 0.75, 0.34, 0.9), Color(0.92, 0.58, 0.22, 0.24))
	_draw_decorations(core_rect, Color(0.12, 0.16, 0.19, 0.34), Color(0.32, 0.4, 0.46, 0.18), Color(0.42, 0.52, 0.58, 0.12))

	draw_rect(inset_rect, Color(0.24, 0.32, 0.4, 0.9), false, 3.0)
	draw_rect(core_rect, Color(0.15, 0.2, 0.24, 0.65), false, 2.0)


func _draw_factory_tile(outer_rect: Rect2, inset_rect: Rect2, core_rect: Rect2) -> void:
	draw_rect(outer_rect, Color(0.04, 0.05, 0.07, 1.0), true)
	draw_rect(inset_rect, Color(0.07, 0.09, 0.12, 1.0), true)
	draw_rect(core_rect, Color(0.09, 0.11, 0.15, 1.0), true)

	_draw_factory_lanes(core_rect)
	_draw_grid(core_rect, Color(0.28, 0.34, 0.42, 0.18), Color(0.18, 0.22, 0.28, 0.12))
	_draw_energy_rails(outer_rect, inset_rect, Color(0.56, 0.82, 1.0, 0.26), Color(0.22, 0.42, 0.7, 0.18))
	_draw_corner_beacons(inset_rect, Color(1.0, 0.62, 0.28, 0.9), Color(1.0, 0.42, 0.16, 0.22))
	_draw_factory_machines(core_rect)

	draw_rect(inset_rect, Color(0.38, 0.47, 0.58, 0.88), false, 3.0)
	draw_rect(core_rect, Color(0.22, 0.28, 0.34, 0.72), false, 2.0)


func _draw_sanctum_tile(outer_rect: Rect2, inset_rect: Rect2, core_rect: Rect2) -> void:
	draw_rect(outer_rect, Color(0.05, 0.04, 0.08, 1.0), true)
	draw_rect(inset_rect, Color(0.09, 0.07, 0.13, 1.0), true)
	draw_rect(core_rect, Color(0.11, 0.08, 0.16, 1.0), true)

	_draw_sanctum_rings(core_rect)
	_draw_grid(core_rect, Color(0.34, 0.26, 0.46, 0.18), Color(0.22, 0.16, 0.32, 0.1))
	_draw_energy_rails(outer_rect, inset_rect, Color(0.8, 0.62, 1.0, 0.24), Color(0.42, 0.2, 0.62, 0.16))
	_draw_corner_beacons(inset_rect, Color(0.72, 0.9, 1.0, 0.92), Color(0.42, 0.32, 0.9, 0.18))
	_draw_sanctum_sigils(core_rect)

	draw_rect(inset_rect, Color(0.58, 0.44, 0.8, 0.84), false, 3.0)
	draw_rect(core_rect, Color(0.34, 0.24, 0.48, 0.68), false, 2.0)


func _draw_floor_panels(core_rect: Rect2) -> void:
	var lane_height := core_rect.size.y / 3.0
	var panel_colors := [
		Color(0.07, 0.11, 0.12, 0.65),
		Color(0.08, 0.12, 0.14, 0.72),
		Color(0.07, 0.1, 0.13, 0.65)
	]
	for index in range(3):
		var panel_rect := Rect2(
			core_rect.position + Vector2(0.0, lane_height * float(index)),
			Vector2(core_rect.size.x, lane_height - 6.0)
		)
		draw_rect(panel_rect, panel_colors[index], true)


func _draw_grid(core_rect: Rect2, grid_color_major: Color, grid_color_minor: Color) -> void:
	var minor_step := 48.0
	var major_step := 144.0

	var x := core_rect.position.x
	while x <= core_rect.end.x:
		var offset_x := x - core_rect.position.x
		var is_major: bool = abs(fmod(offset_x, major_step)) < 0.01
		draw_line(
			Vector2(x, core_rect.position.y),
			Vector2(x, core_rect.end.y),
			grid_color_major if is_major else grid_color_minor,
			2.0 if is_major else 1.0
		)
		x += minor_step

	var y := core_rect.position.y
	while y <= core_rect.end.y:
		var offset_y := y - core_rect.position.y
		var is_major_row: bool = abs(fmod(offset_y, major_step)) < 0.01
		draw_line(
			Vector2(core_rect.position.x, y),
			Vector2(core_rect.end.x, y),
			grid_color_major if is_major_row else grid_color_minor,
			2.0 if is_major_row else 1.0
		)
		y += minor_step


func _draw_energy_rails(outer_rect: Rect2, inset_rect: Rect2, rail_color: Color, glow_color: Color) -> void:
	draw_rect(Rect2(outer_rect.position + Vector2(10, 10), Vector2(outer_rect.size.x - 20, 10)), glow_color, true)
	draw_rect(Rect2(outer_rect.position + Vector2(10, outer_rect.size.y - 20), Vector2(outer_rect.size.x - 20, 10)), glow_color, true)
	draw_rect(Rect2(outer_rect.position + Vector2(10, 10), Vector2(10, outer_rect.size.y - 20)), glow_color, true)
	draw_rect(Rect2(outer_rect.position + Vector2(outer_rect.size.x - 20, 10), Vector2(10, outer_rect.size.y - 20)), glow_color, true)
	draw_rect(inset_rect.grow(8.0), rail_color, false, 4.0)


func _draw_corner_beacons(inset_rect: Rect2, beacon_color: Color, glow_color: Color) -> void:
	var offsets := [
		inset_rect.position + Vector2(28, 28),
		Vector2(inset_rect.end.x - 28, inset_rect.position.y + 28),
		Vector2(inset_rect.position.x + 28, inset_rect.end.y - 28),
		inset_rect.end - Vector2(28, 28)
	]
	for point in offsets:
		draw_circle(point, 16.0, glow_color)
		draw_circle(point, 8.0, beacon_color)
		draw_arc(point, 22.0, 0.0, TAU, 28, Color(0.78, 0.92, 1.0, 0.22), 2.0)


func _draw_decorations(core_rect: Rect2, fill_color: Color, outline_color: Color, cross_color: Color) -> void:
	for index in range(10):
		var t := float(index) / 9.0
		var center := Vector2(
			lerpf(core_rect.position.x + 90.0, core_rect.end.x - 90.0, t),
			lerpf(core_rect.position.y + 110.0, core_rect.end.y - 110.0, 1.0 - t * 0.8)
		)
		var width := 54.0 + float(index % 3) * 18.0
		var height := 16.0 + float(index % 2) * 6.0
		draw_rect(
			Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height)),
			fill_color,
			true
		)
		draw_rect(
			Rect2(center - Vector2(width * 0.5, height * 0.5), Vector2(width, height)),
			outline_color,
			false,
			1.0
		)

	for index in range(8):
		var x := lerpf(core_rect.position.x + 120.0, core_rect.end.x - 120.0, float(index) / 7.0)
		var y := core_rect.position.y + 40.0 + float((index % 3) * 180)
		draw_line(
			Vector2(x - 18.0, y - 12.0),
			Vector2(x + 18.0, y + 12.0),
			cross_color,
			2.0
		)
		draw_line(
			Vector2(x - 18.0, y + 12.0),
			Vector2(x + 18.0, y - 12.0),
			Color(cross_color.r, cross_color.g, cross_color.b, cross_color.a * 0.66),
			2.0
		)


func _draw_factory_lanes(core_rect: Rect2) -> void:
	for index in range(4):
		var y := core_rect.position.y + 38.0 + float(index) * 128.0
		draw_rect(Rect2(Vector2(core_rect.position.x + 22.0, y), Vector2(core_rect.size.x - 44.0, 24.0)), Color(0.15, 0.19, 0.24, 0.84), true)
		draw_rect(Rect2(Vector2(core_rect.position.x + 22.0, y + 8.0), Vector2(core_rect.size.x - 44.0, 8.0)), Color(0.84, 0.49, 0.2, 0.42), true)


func _draw_factory_machines(core_rect: Rect2) -> void:
	for index in range(6):
		var x := core_rect.position.x + 90.0 + float(index) * 170.0
		var size_rect := Vector2(72.0, 48.0)
		var center := Vector2(x, core_rect.position.y + 100.0 + float(index % 3) * 150.0)
		draw_rect(Rect2(center - size_rect * 0.5, size_rect), Color(0.12, 0.16, 0.2, 0.88), true)
		draw_rect(Rect2(center - size_rect * 0.5, size_rect), Color(0.58, 0.74, 0.92, 0.22), false, 2.0)
		draw_circle(center + Vector2(0.0, 0.0), 9.0, Color(1.0, 0.66, 0.28, 0.84))


func _draw_sanctum_rings(core_rect: Rect2) -> void:
	var center := core_rect.position + core_rect.size * 0.5
	draw_circle(center, 88.0, Color(0.32, 0.18, 0.42, 0.18))
	for index in range(5):
		var radius := 58.0 + float(index) * 30.0
		draw_arc(center, radius, 0.0, TAU, 64, Color(0.72, 0.52 + float(index) * 0.05, 1.0, 0.28), 3.0)


func _draw_sanctum_sigils(core_rect: Rect2) -> void:
	var center := core_rect.position + core_rect.size * 0.5
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var point := center + Vector2.RIGHT.rotated(angle) * 128.0
		draw_circle(point, 12.0, Color(0.56, 0.9, 1.0, 0.72))
		draw_arc(point, 22.0, 0.0, TAU, 28, Color(0.84, 0.74, 1.0, 0.26), 2.0)
	draw_polygon(
		PackedVector2Array([
			center + Vector2(0, -34),
			center + Vector2(30, 16),
			center + Vector2(-30, 16)
		]),
		[Color(1.0, 0.84, 0.42, 0.9)]
	)
