extends Node2D

signal fired(shake_strength: float)
signal ammo_changed(current_ammo: int, max_ammo: int, is_reloading: bool, reload_progress: float)
signal weapon_changed(weapon_name: String)


const UPGRADE_MAX_LEVELS := {
	"steady_hands": 3,
	"precision_barrel": 3,
	"buckshot": 3,
	"slug_rounds": 3,
	"napalm": 3,
	"inferno": 3,
	"chain_mastery": 3,
	"storm_core": 3,
	"blade_dance": 3,
	"blood_edge": 3,
	"soul_drinker": 3,
	"sweeping_lance": 3,
	"dragon_thrust": 3
}

@export var projectile_scene: PackedScene
@export var arc_beam_scene: PackedScene
@export var melee_slash_scene: PackedScene = preload("res://scenes/MeleeSlash.tscn")
@export var fire_rate := 0.22
@export var projectile_damage := 1
@export var projectile_speed := 820.0
@export var projectile_lifetime := 1.2
@export var projectile_count := 1
@export var spread_degrees := 0.0
@export var piercing := 0
@export var crit_chance := 0.0
@export var crit_multiplier := 2.0
@export var auto_aim_range := 520.0
@export var weapon_id := "pistol"
@export var weapon_name := "标准手枪"
@export var arc_chain_count := 3
@export var magazine_size := 8
@export var reload_time := 1.1
@export var min_stable_aim_distance := 46.0

var fire_cooldown_left := 0.0
var reload_time_left := 0.0
var current_ammo := 0
var owner_player: Node2D
var last_fire_direction := Vector2.RIGHT
var upgrade_levels := {}
var evolution_id := ""
var meta_extra_forward_shots := 0
var meta_extra_backward_shots := 0
var meta_burst_shots := 1
var meta_burst_damage_multiplier := 1.0
var meta_split_on_kill := false
var meta_split_count := 0
var explosive_rounds_enabled := false
var explosive_radius := 54.0
var explosive_damage_multiplier := 0.65
var fire_rounds_enabled := false
var fire_rounds_dot := 1
var fire_rounds_duration := 2.2
var frost_rounds_enabled := false
var frost_rounds_dot := 1
var frost_rounds_duration := 2.4
var frost_rounds_slow_multiplier := 0.7
var melee_lifesteal_ratio := 0.0
var melee_lifesteal_bank := 0.0

@onready var muzzle_flash = $MuzzleFlash


func _ready() -> void:
	owner_player = get_parent() as Node2D
	_apply_weapon_preset(MetaProgression.selected_weapon if has_node("/root/MetaProgression") else "pistol")
	muzzle_flash.visible = false
	current_ammo = magazine_size
	weapon_changed.emit(get_weapon_name())
	_emit_ammo_changed()


func _process(delta: float) -> void:
	fire_cooldown_left = max(fire_cooldown_left - delta, 0.0)
	if reload_time_left > 0.0:
		reload_time_left = max(reload_time_left - delta, 0.0)
		if reload_time_left == 0.0:
			current_ammo = magazine_size
		_emit_ammo_changed()


func try_fire(target_position: Vector2) -> bool:
	if fire_cooldown_left > 0.0 or is_reloading():
		return false
	if not _uses_ammo():
		var origin := global_position
		var base_direction := origin.direction_to(target_position)
		if base_direction == Vector2.ZERO:
			base_direction = Vector2.RIGHT
		last_fire_direction = base_direction.normalized()
		_fire_melee(origin, base_direction)
		_show_muzzle_flash()
		if has_node("/root/SFXManager"):
			SFXManager.play_weapon_fire(weapon_id)
		fired.emit(_get_fire_shake_strength())
		fire_cooldown_left = fire_rate
		_emit_ammo_changed()
		return true
	if projectile_scene == null:
		return false
	if current_ammo <= 0:
		start_reload()
		return false

	var origin := global_position
	var base_direction := origin.direction_to(target_position)
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.RIGHT
	last_fire_direction = base_direction.normalized()

	match weapon_id:
		"arc":
			_fire_arc_burst(origin, base_direction)
		_:
			_fire_projectile_burst(origin, base_direction)

	_show_muzzle_flash()
	if has_node("/root/SFXManager"):
		SFXManager.play_weapon_fire(weapon_id)
	fired.emit(_get_fire_shake_strength())
	fire_cooldown_left = _get_shot_cooldown()
	current_ammo = max(current_ammo - 1, 0)
	if current_ammo == 0:
		start_reload()
	else:
		_emit_ammo_changed()
	return true


func _fire_melee(origin: Vector2, base_direction: Vector2) -> void:
	var melee_config: Dictionary = _get_melee_config()
	var slash_count: int = int(melee_config.get("slashes", 1))
	var separation: float = float(melee_config.get("separation", 0.0))
	var swing_offset: float = -separation * 0.5
	for index in range(slash_count):
		var slash_direction := base_direction.rotated(deg_to_rad(swing_offset + separation * index))
		_spawn_melee_slash(origin, slash_direction, melee_config)
		_damage_melee_targets(origin, slash_direction, melee_config)


func _fire_projectiles(origin: Vector2, base_direction: Vector2) -> void:
	_fire_projectile_wave(origin, base_direction, meta_burst_damage_multiplier)


func _fire_projectile_burst(origin: Vector2, base_direction: Vector2) -> void:
	var burst_total: int = max(meta_burst_shots, 1)
	_fire_projectile_wave(origin, base_direction, meta_burst_damage_multiplier)
	if burst_total <= 1:
		return
	for burst_index in range(1, burst_total):
		var timer := get_tree().create_timer(0.08 * float(burst_index))
		timer.timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			_fire_projectile_wave(global_position, last_fire_direction, meta_burst_damage_multiplier)
			_show_muzzle_flash()
			if has_node("/root/SFXManager"):
				SFXManager.play_weapon_fire(weapon_id)
			fired.emit(_get_fire_shake_strength() * 0.7)
		)


func _fire_projectile_wave(origin: Vector2, base_direction: Vector2, damage_multiplier: float) -> void:

	var projectile_root := get_tree().current_scene.get_node_or_null("Projectiles")
	if projectile_root == null:
		projectile_root = get_parent()

	var total_projectiles: int = max(projectile_count, 1)
	var angle_step := 0.0
	if total_projectiles > 1:
		angle_step = deg_to_rad(spread_degrees) / float(total_projectiles - 1)

	var start_angle := -deg_to_rad(spread_degrees) * 0.5
	for index in range(total_projectiles):
		var projectile = projectile_scene.instantiate()
		var angle_offset := start_angle + angle_step * index
		var projectile_damage_value: int = max(int(round(float(projectile_damage) * damage_multiplier)), 1)
		if randf() < crit_chance:
			projectile_damage_value = max(int(round(float(projectile_damage) * damage_multiplier * crit_multiplier)), 1)
		projectile.global_position = origin
		projectile.direction = base_direction.rotated(angle_offset)
		projectile.damage = projectile_damage_value
		projectile.speed = projectile_speed
		projectile.lifetime = projectile_lifetime
		projectile.remaining_hits = piercing + 1
		projectile.tint = _get_projectile_tint()
		projectile.size_multiplier = _get_projectile_size()
		projectile.weapon_id = weapon_id
		projectile.split_enabled = meta_split_on_kill and _supports_ballistic_modifiers()
		projectile.split_count = meta_split_count
		projectile.explosion_enabled = explosive_rounds_enabled and _supports_ballistic_modifiers()
		projectile.explosion_radius = explosive_radius
		projectile.explosion_damage_multiplier = explosive_damage_multiplier
		projectile.fire_effect_enabled = fire_rounds_enabled and _supports_ballistic_modifiers()
		projectile.fire_effect_duration = fire_rounds_duration
		projectile.fire_effect_damage = fire_rounds_dot
		projectile.ice_effect_enabled = frost_rounds_enabled and _supports_ballistic_modifiers()
		projectile.ice_effect_duration = frost_rounds_duration
		projectile.ice_effect_damage = frost_rounds_dot
		projectile.ice_slow_multiplier = frost_rounds_slow_multiplier
		projectile_root.add_child(projectile)

	if _supports_ballistic_modifiers():
		_spawn_extra_ballistic_shots(origin, base_direction, projectile_root, damage_multiplier)


func _spawn_extra_ballistic_shots(origin: Vector2, base_direction: Vector2, projectile_root: Node, damage_multiplier: float) -> void:
	for index in range(meta_extra_forward_shots):
		var distance_offset := 18.0 + float(index) * 12.0
		_spawn_single_projectile(projectile_root, origin + base_direction * distance_offset, base_direction, damage_multiplier)
	for index in range(meta_extra_backward_shots):
		var distance_offset := 18.0 + float(index) * 12.0
		_spawn_single_projectile(projectile_root, origin - base_direction * distance_offset, -base_direction, damage_multiplier)


func _spawn_single_projectile(projectile_root: Node, origin: Vector2, direction: Vector2, damage_multiplier: float) -> void:
	var projectile = projectile_scene.instantiate()
	var projectile_damage_value: int = max(int(round(float(projectile_damage) * damage_multiplier)), 1)
	if randf() < crit_chance:
		projectile_damage_value = max(int(round(float(projectile_damage) * damage_multiplier * crit_multiplier)), 1)
	projectile.global_position = origin
	projectile.direction = direction
	projectile.damage = projectile_damage_value
	projectile.speed = projectile_speed
	projectile.lifetime = projectile_lifetime
	projectile.remaining_hits = piercing + 1
	projectile.tint = _get_projectile_tint()
	projectile.size_multiplier = _get_projectile_size() * 0.92
	projectile.weapon_id = weapon_id
	projectile.split_enabled = meta_split_on_kill and _supports_ballistic_modifiers()
	projectile.split_count = meta_split_count
	projectile.explosion_enabled = explosive_rounds_enabled and _supports_ballistic_modifiers()
	projectile.explosion_radius = explosive_radius
	projectile.explosion_damage_multiplier = explosive_damage_multiplier
	projectile.fire_effect_enabled = fire_rounds_enabled and _supports_ballistic_modifiers()
	projectile.fire_effect_duration = fire_rounds_duration
	projectile.fire_effect_damage = fire_rounds_dot
	projectile.ice_effect_enabled = frost_rounds_enabled and _supports_ballistic_modifiers()
	projectile.ice_effect_duration = frost_rounds_duration
	projectile.ice_effect_damage = frost_rounds_dot
	projectile.ice_slow_multiplier = frost_rounds_slow_multiplier
	projectile_root.add_child(projectile)


func _fire_arc_burst(origin: Vector2, base_direction: Vector2) -> void:
	var burst_total: int = max(meta_burst_shots, 1)
	_fire_arc_wave(origin, base_direction, meta_burst_damage_multiplier)
	if burst_total <= 1:
		return
	for burst_index in range(1, burst_total):
		var timer := get_tree().create_timer(0.08 * float(burst_index))
		timer.timeout.connect(func() -> void:
			if not is_inside_tree():
				return
			_fire_arc_wave(global_position, last_fire_direction, meta_burst_damage_multiplier)
			_show_muzzle_flash()
			if has_node("/root/SFXManager"):
				SFXManager.play_weapon_fire(weapon_id)
			fired.emit(_get_fire_shake_strength() * 0.7)
		)


func _fire_arc_wave(origin: Vector2, base_direction: Vector2, damage_multiplier: float) -> void:
	var cast_count: int = _get_arc_cast_count()
	var excluded_targets: Array = []
	for _cast_index in range(cast_count):
		var targets: Array = _get_arc_targets(origin, base_direction, excluded_targets, arc_chain_count)
		if targets.is_empty():
			break
		for enemy in targets:
			excluded_targets.append(enemy)
		_fire_arc_chain(origin, targets, damage_multiplier)


func _fire_arc_chain(origin: Vector2, targets: Array, damage_multiplier: float) -> void:
	var points := PackedVector2Array([origin])
	var current_damage: int = max(int(round(float(projectile_damage) * damage_multiplier)), 1)
	for enemy in targets:
		points.append(enemy.global_position)
		var damage_value: int = current_damage
		if randf() < crit_chance:
			damage_value = max(int(round(float(current_damage) * crit_multiplier)), 1)
		enemy.take_damage(damage_value)
		if has_node("/root/SFXManager"):
			SFXManager.play_hit("arc")
		current_damage = max(current_damage - 1, 1)

	if arc_beam_scene != null:
		var beam = arc_beam_scene.instantiate()
		beam.points = points
		var effect_root := get_tree().current_scene.get_node_or_null("Effects")
		if effect_root == null:
			effect_root = get_tree().current_scene
		effect_root.add_child(beam)


func _spawn_melee_slash(origin: Vector2, direction: Vector2, melee_config: Dictionary) -> void:
	if melee_slash_scene == null:
		return
	var slash = melee_slash_scene.instantiate()
	slash.global_position = origin
	slash.global_rotation = direction.angle()
	slash.radius = float(melee_config.get("range", 90.0))
	slash.arc_degrees = float(melee_config.get("arc", 110.0))
	slash.duration = float(melee_config.get("duration", 0.14))
	slash.slash_color = Color(melee_config.get("color", Color(1.0, 0.9, 0.64, 0.92)))
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(slash)


func _damage_melee_targets(origin: Vector2, direction: Vector2, melee_config: Dictionary) -> void:
	var range_value: float = float(melee_config.get("range", 90.0))
	var half_arc: float = deg_to_rad(float(melee_config.get("arc", 110.0))) * 0.5
	var base_damage: int = int(melee_config.get("damage", projectile_damage))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var offset: Vector2 = enemy_node.global_position - origin
		if offset.length() > range_value:
			continue
		if abs(wrapf(direction.angle_to(offset.normalized()), -PI, PI)) > half_arc:
			continue
		var damage_value: int = base_damage
		if randf() < crit_chance:
			damage_value = int(round(float(base_damage) * crit_multiplier))
		if enemy.has_method("take_damage"):
			var defeated := bool(enemy.take_damage(damage_value))
			_apply_melee_lifesteal(damage_value, defeated)
			if has_node("/root/SFXManager"):
				SFXManager.play_hit(weapon_id)
	_destroy_enemy_projectiles(origin, direction, range_value, half_arc)


func _apply_melee_lifesteal(damage_amount: int, _defeated: bool) -> void:
	if melee_lifesteal_ratio <= 0.0:
		return
	if owner_player == null or not owner_player.has_method("heal"):
		return
	melee_lifesteal_bank += float(max(damage_amount, 0)) * melee_lifesteal_ratio
	var heal_amount: int = int(floor(melee_lifesteal_bank))
	if heal_amount <= 0:
		return
	melee_lifesteal_bank -= float(heal_amount)
	owner_player.heal(heal_amount)


func _destroy_enemy_projectiles(origin: Vector2, direction: Vector2, range_value: float, half_arc: float) -> void:
	for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
		if not (projectile is Node2D):
			continue
		var projectile_node := projectile as Node2D
		var offset: Vector2 = projectile_node.global_position - origin
		if offset.length() > range_value:
			continue
		if abs(wrapf(direction.angle_to(offset.normalized()), -PI, PI)) > half_arc:
			continue
		if projectile.has_method("queue_free"):
			projectile.queue_free()


func get_target_position(mouse_position: Vector2) -> Vector2:
	var enemy := _find_auto_aim_target()
	if enemy != null:
		if global_position.distance_to(enemy.global_position) <= min_stable_aim_distance:
			return global_position + last_fire_direction * min_stable_aim_distance
		return enemy.global_position
	return mouse_position


func get_aim_direction(mouse_position: Vector2) -> Vector2:
	var target_position := get_target_position(mouse_position)
	if global_position.distance_to(target_position) <= min_stable_aim_distance:
		return last_fire_direction
	var direction := global_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		return last_fire_direction
	return direction.normalized()


func apply_upgrade(upgrade_id: String) -> bool:
	match upgrade_id:
		"power":
			projectile_damage += 1
		"rapid_fire":
			fire_rate = max(fire_rate - 0.03, 0.08)
		"multishot":
			projectile_count += 1
			spread_degrees = min(spread_degrees + 8.0, 40.0)
		"spread_control":
			spread_degrees = max(spread_degrees - 5.0, 4.0)
		"piercing":
			piercing += 1
		"velocity":
			projectile_speed += 120.0
		"sharpshooter":
			crit_chance = min(crit_chance + 0.12, 0.75)
		"heavy_rounds":
			projectile_lifetime += 0.25
		"seeker":
			auto_aim_range += 100.0
		"deadly_focus":
			crit_multiplier += 0.35
		"explosive_rounds":
			explosive_rounds_enabled = true
		"blast_radius":
			explosive_rounds_enabled = true
			explosive_radius += 18.0
		"blast_payload":
			explosive_rounds_enabled = true
			explosive_damage_multiplier += 0.2
		"fire_rounds":
			fire_rounds_enabled = true
		"wildfire":
			fire_rounds_enabled = true
			fire_rounds_dot += 1
			fire_rounds_duration += 0.7
		"frost_rounds":
			frost_rounds_enabled = true
		"deep_freeze":
			frost_rounds_enabled = true
			frost_rounds_dot += 1
			frost_rounds_duration += 0.8
			frost_rounds_slow_multiplier = min(frost_rounds_slow_multiplier, 0.52)
		"buckshot":
			_increase_upgrade_level("buckshot")
			projectile_count += 2
			spread_degrees = min(spread_degrees + 5.0, 55.0)
		"slug_rounds":
			_increase_upgrade_level("slug_rounds")
			projectile_damage += 2
			projectile_count = max(projectile_count - 1, 1)
			spread_degrees = max(spread_degrees - 8.0, 6.0)
		"napalm":
			_increase_upgrade_level("napalm")
			projectile_lifetime += 0.18
			projectile_damage += 1
		"inferno":
			_increase_upgrade_level("inferno")
			projectile_count += 1
			fire_rate = max(fire_rate - 0.01, 0.05)
		"chain_mastery":
			_increase_upgrade_level("chain_mastery")
			arc_chain_count += 1
		"storm_core":
			_increase_upgrade_level("storm_core")
			fire_rate = max(fire_rate - 0.04, 0.12)
			projectile_damage += 1
		"steady_hands":
			_increase_upgrade_level("steady_hands")
			fire_rate = max(fire_rate - 0.02, 0.08)
			crit_chance = min(crit_chance + 0.08, 0.8)
		"precision_barrel":
			_increase_upgrade_level("precision_barrel")
			projectile_speed += 120.0
			projectile_damage += 1
		"blade_dance":
			_increase_upgrade_level("blade_dance")
			fire_rate = max(fire_rate - 0.05, 0.18)
			projectile_damage += 1
		"blood_edge":
			_increase_upgrade_level("blood_edge")
			crit_chance = min(crit_chance + 0.12, 0.85)
			projectile_damage += 1
		"soul_drinker":
			_increase_upgrade_level("soul_drinker")
			melee_lifesteal_ratio += 0.08
		"sweeping_lance":
			_increase_upgrade_level("sweeping_lance")
			projectile_damage += 1
			auto_aim_range += 18.0
		"dragon_thrust":
			_increase_upgrade_level("dragon_thrust")
			fire_rate = max(fire_rate - 0.04, 0.2)
			crit_multiplier += 0.2
		"fusion_starbreaker":
			evolution_id = "starbreaker"
			weapon_name = "星辉破城枪"
			projectile_damage += 3
			piercing += 1
			crit_multiplier += 0.5
		"fusion_reaper":
			evolution_id = "reaper"
			weapon_name = "收割审判"
			projectile_damage += 4
			projectile_count += 1
			piercing += 2
		"fusion_tempest":
			evolution_id = "tempest"
			weapon_name = "雷暴主宰"
			projectile_damage += 3
			arc_chain_count += 3
			fire_rate = max(fire_rate - 0.08, 0.08)
		"fusion_infernal":
			evolution_id = "infernal"
			weapon_name = "炼狱龙息"
			projectile_damage += 2
			projectile_count += 2
			projectile_lifetime += 0.25
		"fusion_crimson":
			evolution_id = "crimson"
			weapon_name = "猩红风暴"
			projectile_damage += 3
			crit_chance = min(crit_chance + 0.18, 0.9)
			melee_lifesteal_ratio += 0.1
		"fusion_dragonfang":
			evolution_id = "dragonfang"
			weapon_name = "龙牙裂阵"
			projectile_damage += 4
			crit_multiplier += 0.35
			auto_aim_range += 40.0
			melee_lifesteal_ratio += 0.12
		"extended_mag":
			magazine_size += 3
			current_ammo += 3
		"quick_reload":
			reload_time = max(reload_time - 0.18, 0.35)
		"bottomless":
			magazine_size += 5
			reload_time = max(reload_time - 0.08, 0.3)
		_:
			return false

	current_ammo = min(current_ammo, magazine_size)
	weapon_changed.emit(get_weapon_name())
	_emit_ammo_changed()
	return true


func get_weapon_name() -> String:
	return weapon_name


func start_reload() -> void:
	if not _uses_ammo():
		return
	if is_reloading() or current_ammo >= magazine_size:
		return
	reload_time_left = reload_time
	_emit_ammo_changed()


func is_reloading() -> bool:
	if not _uses_ammo():
		return false
	return reload_time_left > 0.0


func get_reload_progress() -> float:
	if reload_time <= 0.0:
		return 0.0
	return clampf(1.0 - (reload_time_left / reload_time), 0.0, 1.0)


func _apply_weapon_preset(new_weapon_id: String) -> void:
	weapon_id = new_weapon_id
	evolution_id = ""
	upgrade_levels.clear()
	meta_extra_forward_shots = 0
	meta_extra_backward_shots = 0
	meta_burst_shots = 1
	meta_burst_damage_multiplier = 1.0
	meta_split_on_kill = false
	meta_split_count = 0
	explosive_rounds_enabled = false
	explosive_radius = 54.0
	explosive_damage_multiplier = 0.65
	fire_rounds_enabled = false
	fire_rounds_dot = 1
	fire_rounds_duration = 2.2
	frost_rounds_enabled = false
	frost_rounds_dot = 1
	frost_rounds_duration = 2.4
	frost_rounds_slow_multiplier = 0.7
	melee_lifesteal_ratio = 0.0
	melee_lifesteal_bank = 0.0
	match weapon_id:
		"sword":
			weapon_name = "符文长剑"
			fire_rate = 0.36
			projectile_damage = 3
			projectile_speed = 0.0
			projectile_lifetime = 0.0
			projectile_count = 1
			spread_degrees = 0.0
			piercing = 0
			auto_aim_range = 140.0
			crit_chance = 0.08
			crit_multiplier = 1.9
			arc_chain_count = 0
			magazine_size = 1
			reload_time = 0.0
		"spear":
			weapon_name = "猎龙长枪"
			fire_rate = 0.46
			projectile_damage = 4
			projectile_speed = 0.0
			projectile_lifetime = 0.0
			projectile_count = 1
			spread_degrees = 0.0
			piercing = 0
			auto_aim_range = 165.0
			crit_chance = 0.05
			crit_multiplier = 2.1
			arc_chain_count = 0
			magazine_size = 1
			reload_time = 0.0
		"shotgun":
			weapon_name = "霰弹枪"
			fire_rate = 0.48
			projectile_damage = 1
			projectile_speed = 760.0
			projectile_lifetime = 0.8
			projectile_count = 5
			spread_degrees = 30.0
			piercing = 0
			auto_aim_range = 460.0
			crit_chance = 0.05
			crit_multiplier = 2.0
			arc_chain_count = 0
			magazine_size = 6
			reload_time = 1.45
		"flame":
			weapon_name = "火焰喷射器"
			fire_rate = 0.09
			projectile_damage = 1
			projectile_speed = 430.0
			projectile_lifetime = 0.42
			projectile_count = 3
			spread_degrees = 34.0
			piercing = 1
			auto_aim_range = 360.0
			crit_chance = 0.0
			crit_multiplier = 1.6
			arc_chain_count = 0
			magazine_size = 18
			reload_time = 1.0
		"arc":
			weapon_name = "电弧法杖"
			fire_rate = 0.42
			projectile_damage = 3
			projectile_speed = 0.0
			projectile_lifetime = 0.0
			projectile_count = 1
			spread_degrees = 0.0
			piercing = 0
			auto_aim_range = 520.0
			crit_chance = 0.1
			crit_multiplier = 1.8
			arc_chain_count = 3
			magazine_size = 5
			reload_time = 1.6
		_:
			weapon_id = "pistol"
			weapon_name = "标准手枪"
			fire_rate = 0.22
			projectile_damage = 1
			projectile_speed = 820.0
			projectile_lifetime = 1.2
			projectile_count = 1
			spread_degrees = 0.0
			piercing = 0
			auto_aim_range = 520.0
			crit_chance = 0.0
			crit_multiplier = 2.0
			arc_chain_count = 0
			magazine_size = 8
			reload_time = 1.1

	current_ammo = magazine_size
	reload_time_left = 0.0


func _show_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_flash.modulate = _get_muzzle_flash_color()
	muzzle_flash.scale = Vector2.ONE
	muzzle_flash.rotation = 0.0
	var tween := create_tween()
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.08)
	tween.parallel().tween_property(muzzle_flash, "scale", Vector2(1.5, 0.4), 0.08)
	tween.tween_callback(func() -> void: muzzle_flash.visible = false)


func _get_projectile_tint() -> Color:
	match weapon_id:
		"shotgun":
			return Color(1, 0.88, 0.48, 1)
		"flame":
			return Color(1, 0.48, 0.18, 1)
		"arc":
			return Color(0.56, 0.95, 1, 1)
		_:
			return Color(1, 0.84, 0.45, 1)


func _get_projectile_size() -> float:
	match weapon_id:
		"shotgun":
			return 0.9
		"flame":
			return 1.15
		_:
			return 1.0


func get_upgrade_pool() -> Array:
	var pool: Array = []
	match weapon_id:
		"shotgun":
			_append_leveled_upgrade(pool, "buckshot", "鹿弹装填", "额外发射 2 颗弹丸")
			_append_leveled_upgrade(pool, "slug_rounds", "独头弹", "伤害提升，散射收束")
			pool.append({"id": "point_blank", "title": "贴脸压制", "description": "暴击概率提升"})
			_append_fusion_if_ready(pool, "fusion_reaper", "收割审判", "鹿弹装填 III + 独头弹 III 后进化，伤害 +4、额外弹丸 +1、穿透 +2", ["buckshot", "slug_rounds"])
		"flame":
			_append_leveled_upgrade(pool, "napalm", "凝固燃油", "火焰持续更久且更痛")
			_append_leveled_upgrade(pool, "inferno", "炼狱喷口", "火焰数量与射速提升")
			pool.append({"id": "heat_sink", "title": "散热循环", "description": "自动瞄准范围与射程提升"})
			_append_fusion_if_ready(pool, "fusion_infernal", "炼狱龙息", "凝固燃油 III + 炼狱喷口 III 后进化，伤害 +2、火焰数量 +2、持续时间提升", ["napalm", "inferno"])
		"arc":
			_append_leveled_upgrade(pool, "chain_mastery", "连锁掌控", "电弧连接更多目标")
			_append_leveled_upgrade(pool, "storm_core", "风暴核心", "电弧更快更痛")
			pool.append({"id": "voltage_surge", "title": "高压过载", "description": "暴击伤害提升"})
			_append_fusion_if_ready(pool, "fusion_tempest", "雷暴主宰", "连锁掌控 III + 风暴核心 III 后进化，伤害 +3、连锁数 +3、射速显著提升", ["chain_mastery", "storm_core"])
		"sword":
			_append_leveled_upgrade(pool, "blade_dance", "刃舞", "挥砍更快，伤害提高")
			_append_leveled_upgrade(pool, "blood_edge", "血锋", "暴击与斩击伤害提升")
			_append_leveled_upgrade(pool, "soul_drinker", "猩红汲取", "近战命中吸取生命")
			pool.append({"id": "guardian_spark", "title": "守护火种", "description": "获得 1 次复活机会"})
			_append_fusion_if_ready(pool, "fusion_crimson", "猩红风暴", "刃舞 III + 血锋 III 后进化，双重大范围连斩，伤害 +3、暴击率提升，并获得额外吸血", ["blade_dance", "blood_edge"])
		"spear":
			_append_leveled_upgrade(pool, "sweeping_lance", "横扫枪幕", "攻击更广，长枪更稳")
			_append_leveled_upgrade(pool, "dragon_thrust", "龙牙突刺", "攻速更快，暴伤提高")
			_append_leveled_upgrade(pool, "soul_drinker", "猩红汲取", "近战命中吸取生命")
			pool.append({"id": "guardian_spark", "title": "守护火种", "description": "获得 1 次复活机会"})
			_append_fusion_if_ready(pool, "fusion_dragonfang", "龙牙裂阵", "横扫枪幕 III + 龙牙突刺 III 后进化，超远贯穿斩刺，伤害 +4、暴伤提升，并获得额外吸血", ["sweeping_lance", "dragon_thrust"])
		_:
			_append_leveled_upgrade(pool, "steady_hands", "稳定手感", "射速与暴击概率小幅提升")
			_append_leveled_upgrade(pool, "precision_barrel", "精密枪管", "子弹速度与伤害提升")
			pool.append({"id": "extended_mag", "title": "扩容弹匣", "description": "弹夹容量提升"})
			pool.append({"id": "quick_reload", "title": "快速换弹", "description": "换弹时间缩短"})
			_append_fusion_if_ready(pool, "fusion_starbreaker", "星辉破城枪", "稳定手感 III + 精密枪管 III 后进化，伤害 +3、穿透 +1、暴伤提升", ["steady_hands", "precision_barrel"])
	return pool


func _get_fire_shake_strength() -> float:
	match weapon_id:
		"shotgun":
			return 5.5
		"flame":
			return 2.4
		"arc":
			return 3.6
		_:
			return 3.0


func _get_arc_targets(origin: Vector2, base_direction: Vector2, excluded_targets: Array = [], target_limit: int = -1) -> Array:
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if excluded_targets.has(enemy):
			continue
		var distance := owner_player.global_position.distance_to(enemy.global_position)
		if distance <= auto_aim_range:
			enemies.append({
				"node": enemy,
				"score": distance - max(base_direction.dot(origin.direction_to(enemy.global_position)), 0.0) * 80.0
			})

	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])

	var chain: Array = []
	var limit: int = min(enemies.size(), arc_chain_count if target_limit < 0 else target_limit)
	for index in range(limit):
		chain.append(enemies[index]["node"])
	return chain


func _get_arc_cast_count() -> int:
	return max(projectile_count + meta_extra_forward_shots + meta_extra_backward_shots, 1)


func _find_auto_aim_target() -> Node2D:
	if owner_player == null:
		return null

	var nearest_enemy: Node2D = null
	var nearest_distance: float = auto_aim_range * auto_aim_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance := owner_player.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_enemy = enemy
			nearest_distance = distance

	return nearest_enemy


func _get_muzzle_flash_color() -> Color:
	match weapon_id:
		"shotgun":
			return Color(1, 0.85, 0.52, 0.95)
		"sword":
			return Color(0.95, 0.95, 1.0, 0.95)
		"spear":
			return Color(0.7, 0.92, 1.0, 0.95)
		"flame":
			return Color(1, 0.45, 0.2, 0.95)
		"arc":
			return Color(0.62, 0.95, 1, 0.95)
		_:
			return Color(1, 1, 1, 0.95)


func _emit_ammo_changed() -> void:
	ammo_changed.emit(current_ammo, magazine_size if _uses_ammo() else 0, is_reloading(), get_reload_progress())


func _uses_ammo() -> bool:
	return weapon_id not in ["sword", "spear"]


func _supports_ballistic_modifiers() -> bool:
	return weapon_id not in ["sword", "spear"]


func _get_shot_cooldown() -> float:
	if meta_burst_shots <= 1 or not _supports_ballistic_modifiers():
		return fire_rate
	return fire_rate + 0.08 * float(meta_burst_shots - 1)


func _get_melee_config() -> Dictionary:
	match evolution_id:
		"crimson":
			return {"range": 130.0, "arc": 150.0, "duration": 0.18, "damage": projectile_damage + 2, "color": Color(1.0, 0.42, 0.52, 0.95), "slashes": 2, "separation": 32.0}
		"dragonfang":
			return {"range": 180.0, "arc": 78.0, "duration": 0.16, "damage": projectile_damage + 2, "color": Color(0.7, 0.94, 1.0, 0.95), "slashes": 1, "separation": 0.0}
	match weapon_id:
		"sword":
			return {"range": 108.0, "arc": 132.0, "duration": 0.14, "damage": projectile_damage, "color": Color(0.98, 0.93, 0.8, 0.92), "slashes": 1, "separation": 0.0}
		"spear":
			return {"range": 152.0, "arc": 72.0, "duration": 0.13, "damage": projectile_damage, "color": Color(0.74, 0.94, 1.0, 0.92), "slashes": 1, "separation": 0.0}
		_:
			return {"range": 90.0, "arc": 90.0, "duration": 0.12, "damage": projectile_damage, "color": Color(1, 1, 1, 0.9), "slashes": 1, "separation": 0.0}


func _increase_upgrade_level(upgrade_id: String) -> void:
	upgrade_levels[upgrade_id] = int(upgrade_levels.get(upgrade_id, 0)) + 1


func _get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func _get_upgrade_max_level(upgrade_id: String) -> int:
	return int(UPGRADE_MAX_LEVELS.get(upgrade_id, 1))


func _append_leveled_upgrade(pool: Array, upgrade_id: String, title: String, description: String) -> void:
	var current_level: int = _get_upgrade_level(upgrade_id)
	var max_level: int = _get_upgrade_max_level(upgrade_id)
	if current_level >= max_level:
		return
	pool.append({
		"id": upgrade_id,
		"title": "%s %d/%d" % [title, current_level + 1, max_level],
		"description": description
	})


func _append_fusion_if_ready(pool: Array, fusion_id: String, title: String, description: String, requirements: Array) -> void:
	if evolution_id != "":
		return
	for requirement in requirements:
		var requirement_id: String = String(requirement)
		if _get_upgrade_level(requirement_id) < _get_upgrade_max_level(requirement_id):
			return
	pool.append({
		"id": fusion_id,
		"title": title,
		"description": description
	})
