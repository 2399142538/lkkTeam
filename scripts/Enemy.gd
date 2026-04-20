extends CharacterBody2D


signal defeated
signal chest_dropped(position: Vector2)
signal health_updated(current_health: int, maximum_health: int)
signal removed_from_field


@export var move_speed := 120.0
@export var max_health := 4
@export var contact_damage := 1
@export var formation_contact_radius := 48.0
@export var enemy_separation_radius := 33.0
@export var enemy_separation_push := 3.0
@export var formation_release_passthrough_time := 0.42
@export var formation_release_clear_distance := 72.0
@export var experience_drop_scene: PackedScene
@export var experience_value := 1
@export var floating_text_scene: PackedScene = preload("res://scenes/FloatingText.tscn")
@export var health_bar_offset := Vector2(-33, -48)
@export var health_bar_size := Vector2(44, 7)
@export var death_pulse_scene: PackedScene = preload("res://scenes/PulseWave.tscn")
@export var hit_spark_scene: PackedScene = preload("res://scenes/HitSpark.tscn")
@export var magnet_pickup_scene: PackedScene = preload("res://scenes/PowerPickup.tscn")
@export var bomb_pickup_scene: PackedScene = preload("res://scenes/PowerPickup.tscn")
@export var random_size_min := 0.7
@export var random_size_max := 1.5

var health := max_health
var player: CharacterBody2D
var health_bar_visible_time_left := 0.0
var health_bar: ProgressBar
var base_move_speed := 0.0
var burn_time_left := 0.0
var burn_tick_interval := 0.35
var burn_tick_timer := 0.0
var burn_damage := 0
var frost_time_left := 0.0
var frost_tick_interval := 0.5
var frost_tick_timer := 0.0
var frost_damage := 0
var frost_slow_multiplier := 1.0
var formation_charge_mode := false
var formation_direction := Vector2.ZERO
var formation_despawn_distance := 980.0
var formation_move_speed := 0.0
var drops_enabled := true
var enemy_separation_shape: CircleShape2D = CircleShape2D.new()
var normal_collision_mask := 0
var release_passthrough_left := 0.0
var release_passthrough_direction := Vector2.ZERO
var release_passthrough_speed := 0.0
var base_visual_scale := Vector2.ONE
var random_size_multiplier := 1.0

@onready var visual = $Visual
@onready var base_color: Color = _get_visual_color()
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	if visual is AnimatedSprite2D:
		_randomize_visual_animation()
	health = max_health
	base_move_speed = move_speed
	base_visual_scale = visual.scale
	_apply_random_size()
	normal_collision_mask = collision_mask
	_setup_health_bar()
	health_updated.emit(health, max_health)
	visual.scale = base_visual_scale * 0.2
	visual.rotation = -0.18
	var spawn_tween := create_tween()
	spawn_tween.tween_property(visual, "scale", base_visual_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	spawn_tween.parallel().tween_property(visual, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if health_bar == null:
		return
	_update_status_effects(delta)

	health_bar.global_position = global_position + health_bar_offset
	health_bar_visible_time_left = max(health_bar_visible_time_left - delta, 0.0)
	health_bar.visible = health_bar_visible_time_left > 0.0 and health > 0
	health_bar.modulate.a = min(health_bar_visible_time_left / 0.2, 1.0) if health_bar.visible else 0.0


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if player == null:
		velocity = Vector2.ZERO
		return

	if _try_process_release_passthrough(delta):
		return
	_restore_player_collision_if_clear()

	if formation_charge_mode:
		var current_speed: float = formation_move_speed if formation_move_speed > 0.0 else base_move_speed
		if frost_time_left > 0.0:
			current_speed *= frost_slow_multiplier
		velocity = formation_direction * current_speed
		global_position += velocity * delta
		_apply_enemy_separation()
		_check_formation_player_contact()
		_process_formation_despawn()
		return

	var current_speed: float = base_move_speed
	if frost_time_left > 0.0:
		current_speed *= frost_slow_multiplier
	velocity = global_position.direction_to(player.global_position) * current_speed
	move_and_slide()
	_apply_enemy_separation()
	_check_player_collisions()


func _check_player_collisions() -> void:
	_check_player_contact_damage()


func _try_process_release_passthrough(delta: float) -> bool:
	if release_passthrough_left <= 0.0:
		return false
	release_passthrough_left = maxf(release_passthrough_left - delta, 0.0)
	velocity = release_passthrough_direction * release_passthrough_speed
	global_position += velocity * delta
	_apply_enemy_separation()
	_restore_player_collision_if_clear()
	return true


func _check_formation_player_contact() -> void:
	_check_player_contact_damage()


func _check_player_contact_damage() -> void:
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= formation_contact_radius and player.has_method("take_damage"):
		player.take_damage(contact_damage)


func _apply_enemy_separation() -> void:
	enemy_separation_shape.radius = enemy_separation_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = enemy_separation_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 4
	query.exclude = [get_rid()]

	var separation := Vector2.ZERO
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, 8)
	for hit in hits:
		var other_variant: Variant = hit.get("collider")
		if not is_instance_valid(other_variant) or not (other_variant is Node2D):
			continue
		var other := other_variant as Node2D
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		if distance <= 0.01:
			var angle: float = float(get_instance_id() % 360) * TAU / 360.0
			offset = Vector2(cos(angle), sin(angle))
			distance = 1.0
		if distance >= enemy_separation_radius:
			continue
		var overlap_ratio: float = 1.0 - distance / enemy_separation_radius
		separation += offset.normalized() * overlap_ratio
	if separation != Vector2.ZERO:
		global_position += separation * enemy_separation_push


func take_damage(amount: int) -> bool:
	return _apply_damage(amount, true, true)


func configure_formation_charge(direction: Vector2, despawn_distance: float, move_speed_override: float = 0.0) -> void:
	formation_charge_mode = true
	formation_direction = direction.normalized()
	if formation_direction == Vector2.ZERO:
		formation_direction = Vector2.LEFT
	formation_despawn_distance = max(despawn_distance, 480.0)
	formation_move_speed = max(move_speed_override, 0.0)


func release_formation_charge() -> void:
	var release_direction := formation_direction
	var release_speed := formation_move_speed if formation_move_speed > 0.0 else base_move_speed
	formation_charge_mode = false
	formation_direction = Vector2.ZERO
	formation_move_speed = 0.0
	_start_release_passthrough(release_direction, release_speed)


func _start_release_passthrough(direction: Vector2, speed: float) -> void:
	if direction == Vector2.ZERO:
		return
	release_passthrough_direction = direction.normalized()
	release_passthrough_speed = max(speed, base_move_speed)
	release_passthrough_left = formation_release_passthrough_time
	collision_mask = normal_collision_mask & ~2


func _restore_player_collision_if_clear() -> void:
	if collision_mask == normal_collision_mask:
		return
	if player == null or not is_instance_valid(player):
		collision_mask = normal_collision_mask
		return
	var should_restore: bool = release_passthrough_left <= 0.0 and global_position.distance_to(player.global_position) >= formation_release_clear_distance
	if should_restore:
		collision_mask = normal_collision_mask


func _process_formation_despawn() -> void:
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) < formation_despawn_distance:
		return
	drops_enabled = false
	removed_from_field.emit()
	queue_free()


func apply_elemental_effect(effect_type: String, duration: float, tick_damage: int, slow_multiplier := 1.0) -> void:
	match effect_type:
		"fire":
			burn_time_left = max(burn_time_left, duration)
			burn_tick_timer = 0.08 if burn_tick_timer <= 0.0 else min(burn_tick_timer, 0.08)
			burn_damage = max(burn_damage, tick_damage)
		"ice":
			frost_time_left = max(frost_time_left, duration)
			frost_tick_timer = 0.1 if frost_tick_timer <= 0.0 else min(frost_tick_timer, 0.1)
			frost_damage = max(frost_damage, tick_damage)
			frost_slow_multiplier = min(frost_slow_multiplier, slow_multiplier)


func _apply_damage(amount: int, show_feedback: bool, show_text: bool) -> bool:
	health = max(health - amount, 0)
	_show_health_bar()
	health_updated.emit(health, max_health)
	if show_feedback:
		_flash_hit()
	if show_text:
		_show_damage_text(amount)
	if health == 0:
		_spawn_death_fx()
		if drops_enabled:
			_drop_experience()
		if health_bar != null:
			health_bar.queue_free()
		defeated.emit()
		queue_free()
		return true
	return false


func _update_status_effects(delta: float) -> void:
	var tint_target: Color = base_color
	if burn_time_left > 0.0:
		burn_time_left = max(burn_time_left - delta, 0.0)
		burn_tick_timer -= delta
		tint_target = tint_target.lerp(Color(1.0, 0.46, 0.24, 1.0), 0.45)
		while burn_tick_timer <= 0.0 and burn_time_left > 0.0:
			burn_tick_timer += burn_tick_interval
			if _apply_damage(max(burn_damage, 1), false, false):
				return
	if frost_time_left > 0.0:
		frost_time_left = max(frost_time_left - delta, 0.0)
		frost_tick_timer -= delta
		tint_target = tint_target.lerp(Color(0.56, 0.86, 1.0, 1.0), 0.5)
		while frost_tick_timer <= 0.0 and frost_time_left > 0.0:
			frost_tick_timer += frost_tick_interval
			if _apply_damage(max(frost_damage, 1), false, false):
				return
	if burn_time_left <= 0.0:
		burn_damage = 0
	if frost_time_left <= 0.0:
		frost_damage = 0
		frost_slow_multiplier = 1.0
	_set_visual_color(_get_visual_color().lerp(tint_target, 0.22))


func _setup_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.top_level = true
	health_bar.show_percentage = false
	health_bar.max_value = float(max_health)
	health_bar.value = float(health)
	health_bar.custom_minimum_size = health_bar_size
	health_bar.visible = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.modulate = Color(1, 1, 1, 0)
	health_bar.add_theme_stylebox_override("background", _build_health_style(Color(0.12, 0.16, 0.2, 0.88), Color(0.4, 0.48, 0.56, 0.8)))
	health_bar.add_theme_stylebox_override("fill", _build_health_style(Color(0.95, 0.34, 0.42, 1), Color(1, 0.78, 0.82, 0.9)))
	add_child(health_bar)


func _show_health_bar() -> void:
	if health_bar == null:
		return

	health_bar.max_value = float(max_health)
	health_bar.value = float(health)
	health_bar_visible_time_left = 1.4
	health_bar.visible = true
	health_bar.modulate.a = 1.0


func _build_health_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	return style


func _drop_experience() -> void:
	if experience_drop_scene == null:
		return

	var experience_drop = experience_drop_scene.instantiate()
	experience_drop.global_position = global_position
	experience_drop.experience_value = experience_value

	var pickup_root := get_tree().current_scene.get_node_or_null("Pickups")
	if pickup_root == null:
		pickup_root = get_parent()
	pickup_root.add_child(experience_drop)


func _try_drop_power_pickup() -> void:
	if not is_in_group("elites"):
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	if not scene_root.has_meta("power_pickup_target_total"):
		scene_root.set_meta("power_pickup_target_total", randi_range(3, 8))
		scene_root.set_meta("power_pickup_spawned_total", 0)
		scene_root.set_meta("power_pickup_next_time_ms", 0)
	var spawned_total: int = int(scene_root.get_meta("power_pickup_spawned_total", 0))
	var target_total: int = int(scene_root.get_meta("power_pickup_target_total", 4))
	if spawned_total >= target_total:
		return
	var now_ms: int = Time.get_ticks_msec()
	var next_drop_time_ms: int = int(scene_root.get_meta("power_pickup_next_time_ms", 0))
	if now_ms < next_drop_time_ms:
		return

	var pickup_scene: PackedScene = null
	var pickup_type := ""
	if randf() < 0.5:
		pickup_scene = bomb_pickup_scene
		pickup_type = "bomb"
	else:
		pickup_scene = magnet_pickup_scene
		pickup_type = "magnet"
	if pickup_scene == null:
		return

	var pickup = pickup_scene.instantiate()
	pickup.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	if pickup.has_method("set"):
		pickup.set("pickup_type", pickup_type)

	var pickup_root := get_tree().current_scene.get_node_or_null("Pickups")
	if pickup_root == null:
		pickup_root = get_parent()
	pickup_root.add_child(pickup)
	scene_root.set_meta("power_pickup_spawned_total", spawned_total + 1)
	scene_root.set_meta("power_pickup_next_time_ms", now_ms + 18000)


func _flash_hit() -> void:
	_set_visual_color(Color(1, 1, 1, 1))
	var tween := create_tween()
	tween.tween_property(visual, "scale", base_visual_scale * 1.08, 0.05)
	tween.parallel().tween_method(_set_visual_color, _get_visual_color(), base_color, 0.12)
	tween.tween_property(visual, "scale", base_visual_scale, 0.08)
	_spawn_hit_spark()


func _show_damage_text(amount: int) -> void:
	if floating_text_scene == null:
		return

	var floating_text = floating_text_scene.instantiate()
	floating_text.global_position = global_position + Vector2(0, -24)
	floating_text.setup(str(amount), Color(1, 0.9, 0.52, 1), 1.0)

	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(floating_text)


func _spawn_hit_spark() -> void:
	if hit_spark_scene == null:
		return

	var hit_spark = hit_spark_scene.instantiate()
	hit_spark.global_position = global_position
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(hit_spark)


func _spawn_death_fx() -> void:
	if death_pulse_scene == null:
		return

	var pulse_wave = death_pulse_scene.instantiate()
	pulse_wave.global_position = global_position
	pulse_wave.radius = 64.0
	pulse_wave.duration = 0.24
	pulse_wave.ring_color = Color(base_color.r + 0.1, base_color.g + 0.1, base_color.b + 0.1, 0.95)
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(pulse_wave)


func _get_visual_color() -> Color:
	if visual is Polygon2D:
		return visual.color
	return visual.modulate


func _set_visual_color(color: Color) -> void:
	if visual is Polygon2D:
		visual.color = color
	else:
		visual.modulate = color


func _randomize_visual_animation() -> void:
	var animated_visual := visual as AnimatedSprite2D
	animated_visual.play("idle")
	if animated_visual.sprite_frames == null or not animated_visual.sprite_frames.has_animation("idle"):
		return
	var frame_count := animated_visual.sprite_frames.get_frame_count("idle")
	if frame_count <= 0:
		return
	animated_visual.frame = randi() % frame_count
	animated_visual.frame_progress = randf()
	animated_visual.speed_scale = randf_range(0.86, 1.14)


func _apply_random_size() -> void:
	random_size_multiplier = randf_range(random_size_min, random_size_max)
	base_visual_scale *= random_size_multiplier
	formation_contact_radius *= random_size_multiplier
	enemy_separation_radius *= random_size_multiplier
	health_bar_offset *= random_size_multiplier
	health_bar_size *= random_size_multiplier
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		var circle_shape := collision_shape.shape as CircleShape2D
		circle_shape.radius *= random_size_multiplier
