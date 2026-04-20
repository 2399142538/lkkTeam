extends Control


signal move_vector_changed(vector: Vector2)
signal aim_state_changed(active: bool, screen_position: Vector2)
signal dash_pressed
signal reload_pressed
signal skill_state_changed(pressed: bool)


@export var force_visible := false

@onready var move_zone: Control = $MoveZone
@onready var move_stick: Control = $MoveZone/Stick
@onready var aim_zone: Control = $AimZone
@onready var aim_stick: Control = $AimZone/Stick
@onready var dash_button: Button = $Buttons/DashButton
@onready var reload_button: Button = $Buttons/DashButton/ReloadButton
@onready var skill_button: Button = $Buttons/DashButton/ReloadButton/SkillButton

var move_touch_id := -1
var aim_touch_id := -1
var move_vector := Vector2.ZERO


func _ready() -> void:
	visible = force_visible or OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	dash_button.pressed.connect(func() -> void: dash_pressed.emit())
	reload_button.pressed.connect(func() -> void: reload_pressed.emit())
	skill_button.button_down.connect(_on_skill_button_down)
	skill_button.button_up.connect(_on_skill_button_up)
	_reset_move_stick()
	_reset_aim_stick()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var screen_position := event.position
	if event.pressed:
		if move_touch_id == -1 and _is_in_control(move_zone, screen_position):
			move_touch_id = event.index
			_update_move_input(screen_position)
			return
		if aim_touch_id == -1 and _is_in_control(aim_zone, screen_position):
			aim_touch_id = event.index
			_update_aim_input(screen_position)
			return

	if event.index == move_touch_id and not event.pressed:
		move_touch_id = -1
		move_vector = Vector2.ZERO
		move_vector_changed.emit(move_vector)
		_reset_move_stick()
	elif event.index == aim_touch_id and not event.pressed:
		aim_touch_id = -1
		aim_state_changed.emit(false, screen_position)
		_reset_aim_stick()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == move_touch_id:
		_update_move_input(event.position)
	elif event.index == aim_touch_id:
		_update_aim_input(event.position)


func _update_move_input(screen_position: Vector2) -> void:
	var zone_center := move_zone.global_position + move_zone.size * 0.5
	var delta := screen_position - zone_center
	move_vector = delta / max(min(move_zone.size.x, move_zone.size.y) * 0.33, 1.0)
	move_vector = move_vector.limit_length(1.0)
	move_vector_changed.emit(move_vector)
	move_stick.position = move_zone.size * 0.5 - move_stick.size * 0.5 + move_vector * 34.0


func _update_aim_input(screen_position: Vector2) -> void:
	var zone_center := aim_zone.global_position + aim_zone.size * 0.5
	var delta := screen_position - zone_center
	var aim_offset := delta.limit_length(min(aim_zone.size.x, aim_zone.size.y) * 0.24)
	aim_stick.position = aim_zone.size * 0.5 - aim_stick.size * 0.5 + aim_offset
	aim_state_changed.emit(true, screen_position)


func _reset_move_stick() -> void:
	move_stick.position = move_zone.size * 0.5 - move_stick.size * 0.5


func _reset_aim_stick() -> void:
	aim_stick.position = aim_zone.size * 0.5 - aim_stick.size * 0.5


func _on_skill_button_down() -> void:
	skill_state_changed.emit(true)


func _on_skill_button_up() -> void:
	skill_state_changed.emit(false)


func _is_in_control(control: Control, screen_position: Vector2) -> bool:
	return Rect2(control.global_position, control.size).has_point(screen_position)
