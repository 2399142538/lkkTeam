extends "res://scripts/Enemy.gd"


@export var projectile_scene: PackedScene
@export var volley_interval := 1.2
@export var volley_count := 7
@export var projectile_speed := 300.0
@export var preferred_range := 260.0
@export var damage_resistance := 0.3
@export var charge_interval := 6.5
@export var charge_duration := 1.55
@export var charge_radius := 250.0
@export var charge_damage := 4

var volley_cooldown_left := 1.0
var charge_cooldown_left := 3.5
var charge_time_left := 0.0
var charge_target_position := Vector2.ZERO
var is_preparing_charge := false


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if player == null:
		velocity = Vector2.ZERO
		return
	if _try_process_release_passthrough(delta):
		return

	volley_cooldown_left = max(volley_cooldown_left - delta, 0.0)
	charge_cooldown_left = max(charge_cooldown_left - delta, 0.0)
	if is_preparing_charge:
		charge_time_left = max(charge_time_left - delta, 0.0)

	var direction := global_position.direction_to(player.global_position)
	var distance := global_position.distance_to(player.global_position)

	if is_preparing_charge:
		velocity = Vector2.ZERO
		var flash_strength: float = 0.78 + sin(Time.get_ticks_msec() * 0.018) * 0.18
		visual.scale = base_visual_scale * (1.04 + (1.0 - charge_time_left / max(charge_duration, 0.001)) * 0.12)
		_set_visual_color(Color(1.0, 0.72 + flash_strength * 0.12, 0.34 + flash_strength * 0.18, 1.0))
		if charge_time_left <= 0.0:
			is_preparing_charge = false
			_release_charge_skill()
	elif charge_cooldown_left <= 0.0:
		_begin_charge_skill()
	elif distance > preferred_range:
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
		if volley_cooldown_left <= 0.0:
			_fire_volley(direction)
			volley_cooldown_left = volley_interval

	if not is_preparing_charge:
		visual.scale = visual.scale.lerp(base_visual_scale, 0.18)
		_set_visual_color(_get_visual_color().lerp(base_color, 0.22))

	move_and_slide()
	_apply_enemy_separation()
	_check_player_collisions()
	queue_redraw()


func _fire_volley(base_direction: Vector2) -> void:
	if projectile_scene == null:
		return

	var projectile_root := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if projectile_root == null:
		projectile_root = get_parent()

	var total: int = max(volley_count, 3)
	var spread: float = deg_to_rad(70.0)
	var step: float = spread / float(total - 1)
	var start: float = -spread * 0.5

	for index in range(total):
		var projectile = projectile_scene.instantiate()
		projectile.global_position = global_position
		projectile.direction = base_direction.rotated(start + step * index)
		projectile.speed = projectile_speed
		projectile.damage = 1
		projectile.lifetime = 2.8
		projectile_root.add_child(projectile)


func take_damage(amount: int) -> bool:
	var reduced_amount: int = max(int(ceil(float(amount) * (1.0 - damage_resistance))), 1)
	return super.take_damage(reduced_amount)


func _begin_charge_skill() -> void:
	is_preparing_charge = true
	charge_time_left = charge_duration
	charge_cooldown_left = charge_interval
	if player != null:
		charge_target_position = player.global_position
	else:
		charge_target_position = global_position
	if has_node("/root/SFXManager"):
		SFXManager.play_boss_charge()
	var target_pulse_scene: PackedScene = preload("res://scenes/PulseWave.tscn")
	if target_pulse_scene != null:
		var target_pulse = target_pulse_scene.instantiate()
		target_pulse.global_position = charge_target_position
		target_pulse.radius = charge_radius * 0.62
		target_pulse.duration = charge_duration
		target_pulse.ring_color = Color(1.0, 0.74, 0.26, 0.72)
		var effect_root := get_tree().current_scene.get_node_or_null("Effects")
		if effect_root == null:
			effect_root = get_tree().current_scene
		effect_root.add_child(target_pulse)


func _release_charge_skill() -> void:
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene

	var pulse_scene: PackedScene = preload("res://scenes/PulseWave.tscn")
	if pulse_scene != null:
		var pulse_wave = pulse_scene.instantiate()
		pulse_wave.global_position = charge_target_position
		pulse_wave.radius = charge_radius
		pulse_wave.ring_color = Color(1.0, 0.52, 0.28, 0.95)
		effect_root.add_child(pulse_wave)
		var inner_pulse = pulse_scene.instantiate()
		inner_pulse.global_position = charge_target_position
		inner_pulse.radius = charge_radius * 0.58
		inner_pulse.duration = 0.26
		inner_pulse.ring_color = Color(1.0, 0.9, 0.4, 0.98)
		effect_root.add_child(inner_pulse)

	if player != null and is_instance_valid(player):
		var distance: float = player.global_position.distance_to(charge_target_position)
		if distance <= charge_radius and player.has_method("take_damage"):
			player.take_damage(charge_damage)
		elif distance <= charge_radius * 1.18 and player.has_method("take_damage"):
			player.take_damage(max(charge_damage - 2, 1))

	_fire_charge_burst()
	if has_node("/root/SFXManager"):
		SFXManager.play_charge_pulse()


func _fire_charge_burst() -> void:
	if projectile_scene == null:
		return

	var projectile_root := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if projectile_root == null:
		projectile_root = get_parent()

	for index in range(14):
		var projectile = projectile_scene.instantiate()
		var angle: float = TAU * float(index) / 14.0
		projectile.global_position = charge_target_position
		projectile.direction = Vector2.RIGHT.rotated(angle)
		projectile.speed = projectile_speed * 1.05
		projectile.damage = 1
		projectile.lifetime = 2.6
		projectile.scale = Vector2.ONE * 1.1
		projectile_root.add_child(projectile)

	for index in range(10):
		var projectile = projectile_scene.instantiate()
		var angle: float = TAU * float(index) / 10.0 + deg_to_rad(18.0)
		projectile.global_position = charge_target_position
		projectile.direction = Vector2.RIGHT.rotated(angle)
		projectile.speed = projectile_speed * 0.72
		projectile.damage = 1
		projectile.lifetime = 3.0
		projectile.scale = Vector2.ONE * 1.28
		projectile_root.add_child(projectile)


func _draw() -> void:
	if charge_time_left <= 0.0:
		return

	var progress: float = 1.0 - (charge_time_left / max(charge_duration, 0.001))
	var radius: float = lerpf(30.0, charge_radius, progress)
	var warning_color := Color(1.0, 0.76, 0.28, 0.9) if progress < 0.7 else Color(1.0, 0.22, 0.22, 0.95)
	var fill_alpha: float = 0.08 + progress * 0.16
	var world_offset: Vector2 = to_local(charge_target_position)
	draw_circle(world_offset, radius, Color(warning_color.r, warning_color.g * 0.72, warning_color.b * 0.7, fill_alpha))
	draw_circle(world_offset, radius * 0.38, Color(warning_color.r, warning_color.g, warning_color.b, 0.05 + progress * 0.12))
	draw_arc(world_offset, radius, 0.0, TAU, 72, warning_color, 5.0 + progress * 2.0)
	if progress >= 0.68:
		draw_arc(world_offset, radius * 0.68, 0.0, TAU, 72, Color(1.0, 0.94, 0.5, 0.95), 4.0)
