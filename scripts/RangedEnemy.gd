extends "res://scripts/Enemy.gd"


@export var projectile_scene: PackedScene
@export var preferred_min_range := 220.0
@export var preferred_max_range := 340.0
@export var fire_interval := 1.4

var fire_cooldown_left := 0.8


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

	fire_cooldown_left = max(fire_cooldown_left - delta, 0.0)

	var distance := global_position.distance_to(player.global_position)
	var direction := global_position.direction_to(player.global_position)

	if distance < preferred_min_range:
		velocity = -direction * move_speed
	elif distance > preferred_max_range:
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
		if fire_cooldown_left <= 0.0:
			_fire_projectile(direction)
			fire_cooldown_left = fire_interval

	move_and_slide()
	_apply_enemy_separation()
	_check_player_collisions()


func _fire_projectile(direction: Vector2) -> void:
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position
	projectile.direction = direction

	var projectile_root := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if projectile_root == null:
		projectile_root = get_parent()
	projectile_root.add_child(projectile)
