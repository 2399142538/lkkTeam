extends Area2D


@export var speed := 820.0
@export var damage := 1
@export var lifetime := 1.2
@export var tint := Color(1, 0.84, 0.45, 1)
@export var size_multiplier := 1.0
@export var sprite_base_scale := 0.018
@export var fire_sprite_base_scale := 0.042
@export var ice_sprite_base_scale := 0.028
@export var sprite_spin_speed := 7.5

var direction := Vector2.RIGHT
var sprite_spin_angle := 0.0
var fire_spin_angle := 0.0
var ice_spin_angle := 0.0
var remaining_hits := 1
var weapon_id := "pistol"
var hit_spark_scene: PackedScene = preload("res://scenes/HitSpark.tscn")
var split_bullet_scene: PackedScene = preload("res://scenes/Bullet.tscn")
var explosion_scene: PackedScene = preload("res://scenes/ExplosionBurst.tscn")
var split_enabled := false
var split_count := 0
var split_depth := 0
var flame_trail_cooldown := 0.0
var explosion_enabled := false
var explosion_radius := 0.0
var explosion_damage_multiplier := 0.65
var explosion_triggered := false
var impact_resolved := false
var fire_effect_enabled := false
var fire_effect_duration := 2.0
var fire_effect_damage := 1
var ice_effect_enabled := false
var ice_effect_duration := 2.2
var ice_effect_damage := 1
var ice_slow_multiplier := 0.6

@onready var visual = $Visual
@onready var fire_visual = $FireVisual
@onready var ice_visual = $IceVisual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var has_fire_visual: bool = _has_fire_visual()
	var has_ice_visual: bool = ice_effect_enabled
	visual.modulate = tint
	visual.scale = Vector2.ONE * sprite_base_scale * size_multiplier
	fire_visual.visible = has_fire_visual
	fire_visual.scale = Vector2.ONE * fire_sprite_base_scale * size_multiplier
	fire_visual.modulate = Color(1.0, 0.58, 0.18, 0.70)
	ice_visual.visible = has_ice_visual
	ice_visual.scale = Vector2.ONE * ice_sprite_base_scale * size_multiplier
	ice_visual.modulate = Color(0.74, 0.94, 1.0, 0.69)


func _process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	rotation = direction.angle()
	sprite_spin_angle += sprite_spin_speed * delta
	visual.rotation = sprite_spin_angle
	fire_spin_angle -= sprite_spin_speed * 0.72 * delta
	ice_spin_angle += sprite_spin_speed * 0.46 * delta
	fire_visual.rotation = fire_spin_angle
	ice_visual.rotation = ice_spin_angle
	var has_fire_visual: bool = _has_fire_visual()
	if has_fire_visual:
		flame_trail_cooldown = max(flame_trail_cooldown - delta, 0.0)
		fire_visual.visible = true
		fire_visual.scale = Vector2.ONE * fire_sprite_base_scale * (size_multiplier * randf_range(0.94, 1.1))
		fire_visual.modulate = Color(1.0, randf_range(0.38, 0.64), 0.12, randf_range(0.58, 0.72))
		if flame_trail_cooldown <= 0.0:
			flame_trail_cooldown = 0.035
			_spawn_flame_trail()
			_spawn_fire_sprite_trail()
	if ice_effect_enabled:
		ice_visual.visible = true
		ice_visual.scale = Vector2.ONE * ice_sprite_base_scale * (size_multiplier * randf_range(0.97, 1.06))
		ice_visual.modulate = Color(0.74, 0.94, 1.0, randf_range(0.58, 0.72))
		if not has_fire_visual:
			flame_trail_cooldown = max(flame_trail_cooldown - delta, 0.0)
		if flame_trail_cooldown <= 0.0:
			flame_trail_cooldown = 0.05 if not has_fire_visual else 0.04
			_spawn_ice_trail()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if impact_resolved or not body.has_method("take_damage"):
		return
	impact_resolved = true

	var hit_targets: Array[Node] = []
	hit_targets.append(body)
	for overlapping_body in get_overlapping_bodies():
		if overlapping_body == body:
			continue
		if not overlapping_body.has_method("take_damage"):
			continue
		hit_targets.append(overlapping_body)

	var any_hit := false
	for target in hit_targets:
		if remaining_hits <= 0:
			break
		if not is_instance_valid(target):
			continue
		var defeated := bool(target.take_damage(damage))
		any_hit = true
		if target.has_method("apply_elemental_effect"):
			if fire_effect_enabled:
				target.apply_elemental_effect("fire", fire_effect_duration, fire_effect_damage)
			if ice_effect_enabled:
				target.apply_elemental_effect("ice", ice_effect_duration, ice_effect_damage, ice_slow_multiplier)
		if explosion_enabled and not explosion_triggered:
			_trigger_explosion(target)
		if defeated and split_enabled and split_count > 0 and split_depth == 0:
			_spawn_split_projectiles()
		remaining_hits -= 1

	if any_hit:
		_spawn_hit_spark()
		if has_node("/root/SFXManager"):
			SFXManager.play_hit(weapon_id)
	if remaining_hits <= 0:
		queue_free()
	else:
		impact_resolved = false


func _spawn_hit_spark() -> void:
	if hit_spark_scene == null:
		return

	var spark = hit_spark_scene.instantiate()
	spark.global_position = global_position
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(spark)


func _spawn_split_projectiles() -> void:
	var projectile_root := get_tree().current_scene.get_node_or_null("Projectiles")
	if projectile_root == null:
		projectile_root = get_parent()
	if projectile_root == null:
		return

	for index in range(split_count):
		if split_bullet_scene == null:
			break
		var child_bullet = split_bullet_scene.instantiate()
		if child_bullet == null:
			continue
		var angle := TAU * float(index) / float(max(split_count, 1))
		child_bullet.global_position = global_position
		child_bullet.direction = Vector2.RIGHT.rotated(angle)
		child_bullet.damage = max(int(round(float(damage) * 0.45)), 1)
		child_bullet.speed = speed * 0.92
		child_bullet.lifetime = min(lifetime, 0.55)
		child_bullet.remaining_hits = 1
		child_bullet.size_multiplier = size_multiplier * 0.72
		child_bullet.split_enabled = false
		child_bullet.split_count = 0
		child_bullet.split_depth = split_depth + 1
		projectile_root.add_child(child_bullet)


func _spawn_flame_trail() -> void:
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	if effect_root == null:
		return
	var ember := Polygon2D.new()
	ember.polygon = PackedVector2Array([
		Vector2(-3, -3),
		Vector2(4, -1),
		Vector2(3, 3),
		Vector2(-2, 4),
		Vector2(-4, 0)
	])
	ember.color = Color(1.0, randf_range(0.45, 0.7), 0.14, 0.7)
	ember.global_position = global_position - direction.normalized() * randf_range(6.0, 12.0)
	ember.global_rotation = randf_range(-PI, PI)
	ember.scale = Vector2.ONE * randf_range(0.55, 0.95) * size_multiplier
	effect_root.add_child(ember)
	var tween := ember.create_tween()
	tween.tween_property(ember, "scale", ember.scale * 1.8, 0.14)
	tween.parallel().tween_property(ember, "modulate:a", 0.0, 0.14)
	tween.parallel().tween_property(ember, "global_position", ember.global_position + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), 0.14)
	tween.tween_callback(ember.queue_free)


func _spawn_fire_sprite_trail() -> void:
	if not (fire_visual is Sprite2D):
		return
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	if effect_root == null:
		return
	var trail := Sprite2D.new()
	trail.texture = fire_visual.texture
	trail.centered = fire_visual.centered
	trail.global_position = global_position - direction.normalized() * randf_range(8.0, 16.0)
	trail.global_rotation = rotation + randf_range(-0.12, 0.12)
	trail.scale = fire_visual.scale * randf_range(0.72, 0.95)
	trail.modulate = Color(1.0, randf_range(0.34, 0.58), 0.08, 0.48)
	effect_root.add_child(trail)
	var tween := trail.create_tween()
	tween.tween_property(trail, "scale", trail.scale * 0.42, 0.18)
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(trail, "global_position", trail.global_position - direction.normalized() * randf_range(10.0, 22.0), 0.18)
	tween.tween_callback(trail.queue_free)


func _has_fire_visual() -> bool:
	return weapon_id == "flame" or fire_effect_enabled


func _spawn_ice_trail() -> void:
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	if effect_root == null:
		return
	var shard := Polygon2D.new()
	shard.polygon = PackedVector2Array([
		Vector2(-2, -4),
		Vector2(3, -2),
		Vector2(2, 4),
		Vector2(-3, 2)
	])
	shard.color = Color(0.7, 0.94, 1.0, 0.72)
	shard.global_position = global_position - direction.normalized() * randf_range(5.0, 10.0)
	shard.global_rotation = randf_range(-PI, PI)
	shard.scale = Vector2.ONE * randf_range(0.5, 0.85) * size_multiplier
	effect_root.add_child(shard)
	var tween := shard.create_tween()
	tween.tween_property(shard, "scale", shard.scale * 1.35, 0.18)
	tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(shard, "global_position", shard.global_position + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), 0.18)
	tween.tween_callback(shard.queue_free)


func _trigger_explosion(hit_body: Node) -> void:
	explosion_triggered = true
	if explosion_radius <= 0.0:
		return
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	if effect_root != null and explosion_scene != null:
		var burst = explosion_scene.instantiate()
		burst.global_position = global_position
		burst.radius = explosion_radius
		burst.blast_color = Color(1.0, 0.58, 0.2, 0.95) if weapon_id != "flame" else Color(1.0, 0.42, 0.16, 0.95)
		effect_root.add_child(burst)

	var aoe_damage: int = max(int(round(float(damage) * explosion_damage_multiplier)), 1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == hit_body:
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(global_position) > explosion_radius:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(aoe_damage)
