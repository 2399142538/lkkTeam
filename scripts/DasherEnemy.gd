extends "res://scripts/Enemy.gd"


@export var dash_speed := 320.0
@export var dash_duration := 0.35
@export var dash_cooldown := 1.8
@export var preferred_range := 150.0

var dash_time_left := 0.0
var dash_cooldown_left := 0.4


func _physics_process(delta: float) -> void:
	if formation_charge_mode:
		super._physics_process(delta)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if player == null:
		velocity = Vector2.ZERO
		return
	if _try_process_release_passthrough(delta):
		return

	dash_time_left = max(dash_time_left - delta, 0.0)
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)

	var direction := global_position.direction_to(player.global_position)
	var distance := global_position.distance_to(player.global_position)

	if dash_time_left > 0.0:
		velocity = direction * dash_speed
	elif distance <= preferred_range and dash_cooldown_left <= 0.0:
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown
		velocity = direction * dash_speed
	else:
		velocity = direction * move_speed

	move_and_slide()
	_apply_enemy_separation()
	_check_player_collisions()
