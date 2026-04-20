extends Node


signal wave_started(wave: int)
signal enemy_count_changed(count: int)
signal wave_cleared(wave: int)
signal chest_spawn_requested(position: Vector2)
signal boss_defeated
signal boss_spawned(boss: Node)
signal enemy_defeated(enemy_kind: String)

const STAGE_DIFFICULTY := {
	"ruins": {
		"count_multiplier": 1.0,
		"spawn_rate_multiplier": 1.0,
		"health_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"experience_multiplier": 1.0,
		"elite_multiplier": 1.0,
		"boss_health_multiplier": 1.0,
		"boss_attack_multiplier": 1.0
	},
	"factory": {
		"count_multiplier": 2.1,
		"spawn_rate_multiplier": 1.5,
		"health_multiplier": 1.65,
		"speed_multiplier": 1.18,
		"damage_multiplier": 1.28,
		"experience_multiplier": 0.5,
		"elite_multiplier": 2.0,
		"boss_health_multiplier": 2.4,
		"boss_attack_multiplier": 1.4
	},
	"sanctum": {
		"count_multiplier": 8.0,
		"spawn_rate_multiplier": 3.8,
		"health_multiplier": 9.5,
		"speed_multiplier": 1.85,
		"damage_multiplier": 2.8,
		"experience_multiplier": 0.13,
		"elite_multiplier": 5.0,
		"boss_health_multiplier": 18.0,
		"boss_attack_multiplier": 3.4
	}
}


@export var basic_enemy_scene: PackedScene
@export var basic_enemy_variant_scene: PackedScene
@export var dasher_enemy_scene: PackedScene
@export var tank_enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene
@export var boss_enemy_scene: PackedScene
@export var elite_enemy_scene: PackedScene
@export var wave_enemy_counts := PackedInt32Array([16, 26, 38, 52])
@export var wave_spawn_intervals := PackedFloat32Array([0.5, 0.34, 0.24, 0.17])
@export var spawn_distance_min := 260.0
@export var spawn_distance_max := 430.0
@export var spawn_safe_radius := 180.0
@export var spawn_offscreen_margin := 72.0
@export var formation_spawn_chance := 0.2
@export var formation_spawn_interval := 3.8
@export var formation_move_speed := 170.0
@export var formation_break_distance := 114.0
@export var formation_front_hold_angle_degrees := 30.0
@export var formation_spawn_batch_size := 12
@export var final_wave := 5

var current_wave := 0
var enemies_to_spawn := 0
var active_enemies := 0
var spawn_timer := 0.0
var current_spawn_interval := 0.45
var enabled := true
var waiting_for_next_wave := false
var boss_phase_total_enemies := 0
var boss_spawned_once := false
var current_stage_id := "ruins"
var chest_target_total := 4
var chests_spawned_total := 0
var elite_chest_progress := 0
var formation_events_remaining := 0
var formation_cooldown_left := 0.0
var formation_groups: Dictionary = {}
var pending_formation_spawns: Array[Dictionary] = []
var next_formation_group_id := 1
var next_wave_started_early := false


func _process(delta: float) -> void:
	if not enabled or basic_enemy_scene == null:
		return

	formation_cooldown_left = maxf(formation_cooldown_left - delta, 0.0)
	var pending_spawned_count: int = _process_pending_formation_spawns()
	if pending_spawned_count > 0:
		_emit_enemy_count()
	if not pending_formation_spawns.is_empty():
		return
	_update_formation_groups()

	if enemies_to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_wave_batch(true)
			enemies_to_spawn = max(enemies_to_spawn - 1, 0)
			spawn_timer = current_spawn_interval
			_try_spawn_extra_formation()
			_emit_enemy_count()
	elif _can_spawn_extra_formation():
		_spawn_formation_event()
		_emit_enemy_count()
	elif active_enemies == 0 and not waiting_for_next_wave:
		waiting_for_next_wave = true
		wave_cleared.emit(current_wave)

	if _should_start_next_wave_early():
		_start_next_wave_early()


func start_waves() -> void:
	if has_node("/root/MetaProgression"):
		current_stage_id = String(MetaProgression.selected_stage)
	current_wave = 0
	active_enemies = 0
	enemies_to_spawn = 0
	enabled = true
	waiting_for_next_wave = false
	boss_phase_total_enemies = 0
	boss_spawned_once = false
	chest_target_total = randi_range(3, 5)
	chests_spawned_total = 0
	elite_chest_progress = 0
	formation_events_remaining = 0
	formation_cooldown_left = 0.0
	formation_groups.clear()
	pending_formation_spawns.clear()
	next_formation_group_id = 1
	next_wave_started_early = false
	_start_next_wave()


func continue_to_next_wave() -> void:
	if current_wave >= final_wave:
		return
	waiting_for_next_wave = false
	_start_next_wave()


func spawn_all_remaining_enemies() -> int:
	if not enabled:
		return 0

	var spawned_total := 0
	waiting_for_next_wave = false
	spawn_timer = 0.0
	current_spawn_interval = 0.0
	formation_cooldown_left = 0.0

	while enemies_to_spawn > 0:
		spawned_total += _spawn_wave_batch(true)
		enemies_to_spawn = max(enemies_to_spawn - 1, 0)

	if current_wave < final_wave:
		for wave in range(current_wave + 1, final_wave):
			current_wave = wave
			formation_events_remaining = _get_formation_event_count(wave)
			for _index in range(_get_elite_count(wave)):
				if elite_enemy_scene != null:
					_spawn_elite()
					spawned_total += 1
			var wave_enemy_total: int = _get_wave_enemy_count(wave)
			for _index in range(wave_enemy_total):
				spawned_total += _spawn_wave_batch(true)
			while formation_events_remaining > 0:
				spawned_total += _spawn_formation_event()

		current_wave = final_wave
		wave_started.emit(current_wave)

	if current_wave >= final_wave and boss_enemy_scene != null and not boss_spawned_once:
		var before_boss_enemies: int = active_enemies
		_spawn_boss()
		spawned_total += active_enemies - before_boss_enemies
	elif current_wave >= final_wave:
		while enemies_to_spawn > 0:
			spawned_total += _spawn_wave_batch(true)
			enemies_to_spawn = max(enemies_to_spawn - 1, 0)

	enemies_to_spawn = 0
	boss_phase_total_enemies = max(active_enemies, 1)
	_emit_enemy_count()
	return spawned_total


func get_wave_progress_ratio() -> float:
	if current_wave <= 0:
		return 0.0
	if current_wave >= final_wave:
		var total_boss_phase: int = max(boss_phase_total_enemies, 1)
		var boss_remaining: int = active_enemies + enemies_to_spawn
		return clampf(1.0 - float(boss_remaining) / float(total_boss_phase), 0.0, 1.0)

	var total_wave_enemies: int = _get_wave_enemy_count(current_wave) + _get_elite_count(current_wave)
	if total_wave_enemies <= 0:
		return 1.0
	var remaining_enemies: int = active_enemies + enemies_to_spawn
	return clampf(1.0 - float(remaining_enemies) / float(total_wave_enemies), 0.0, 1.0)


func _start_next_wave() -> void:
	current_wave += 1
	if current_wave >= final_wave and boss_enemy_scene != null:
		enemies_to_spawn = 0
		current_spawn_interval = 0.0
		formation_events_remaining = 0
	else:
		enemies_to_spawn = _get_wave_enemy_count(current_wave)
		current_spawn_interval = _get_wave_spawn_interval(current_wave)
		formation_events_remaining = _get_formation_event_count(current_wave)
	spawn_timer = 0.0
	formation_cooldown_left = maxf(formation_spawn_interval * 0.5, 1.2)
	next_wave_started_early = false
	wave_started.emit(current_wave)
	if current_wave >= final_wave and boss_enemy_scene != null:
		_spawn_boss()
	elif current_wave >= 3 and elite_enemy_scene != null:
		for _index in range(_get_elite_count(current_wave)):
			_spawn_elite()
	_emit_enemy_count()


func _spawn_wave_batch(force_single: bool = false) -> int:
	_spawn_enemy()
	return 1


func _should_start_next_wave_early() -> bool:
	if waiting_for_next_wave:
		return false
	if next_wave_started_early:
		return false
	if current_wave <= 0 or current_wave >= final_wave:
		return false
	if enemies_to_spawn > 0:
		return false
	if formation_events_remaining > 0:
		return false
	if not pending_formation_spawns.is_empty():
		return false
	return true


func _start_next_wave_early() -> void:
	next_wave_started_early = true
	_start_next_wave()


func _spawn_enemy() -> void:
	var enemy_scene := _pick_enemy_scene()
	if enemy_scene == null:
		return

	_spawn_enemy_instance(enemy_scene, _get_spawn_position())


func _spawn_elite() -> void:
	_spawn_enemy_instance(elite_enemy_scene, _get_spawn_position())


func _spawn_enemy_instance(enemy_scene: PackedScene, position: Vector2, formation_forward: Vector2 = Vector2.ZERO, formation_despawn_distance: float = 0.0, formation_speed: float = 0.0) -> Node:
	if enemy_scene == null:
		return null

	var enemy = enemy_scene.instantiate()
	var enemy_kind: String = _classify_enemy(enemy)
	_apply_wave_scaling(enemy)
	enemy.global_position = position
	enemy.defeated.connect(_on_enemy_defeated.bind(enemy_kind))
	if enemy.has_signal("removed_from_field"):
		enemy.removed_from_field.connect(_on_enemy_removed_from_field)
	if enemy.has_signal("chest_dropped"):
		enemy.chest_dropped.connect(_on_chest_dropped)
	if formation_forward != Vector2.ZERO and enemy.has_method("configure_formation_charge"):
		enemy.configure_formation_charge(formation_forward, formation_despawn_distance, formation_speed)

	var enemies_root := get_tree().current_scene.get_node_or_null("Enemies")
	if enemies_root == null:
		enemies_root = get_parent()
	enemies_root.add_child(enemy)
	active_enemies += 1
	return enemy


func _can_spawn_extra_formation() -> bool:
	if not pending_formation_spawns.is_empty():
		return false
	if formation_events_remaining <= 0:
		return false
	if current_wave < 2:
		return false
	if current_wave >= final_wave:
		return false
	return formation_cooldown_left <= 0.0


func _try_spawn_extra_formation() -> void:
	if not _can_spawn_extra_formation():
		return
	if randf() > formation_spawn_chance:
		return
	_spawn_formation_event()


func _spawn_formation_event() -> int:
	if formation_events_remaining <= 0:
		return 0
	formation_events_remaining -= 1
	formation_cooldown_left = formation_spawn_interval
	return _spawn_formation()


func _spawn_formation() -> int:
	var formation_size: int = _get_target_formation_size()
	var pattern_points: Array[Vector2] = _build_random_formation_pattern(formation_size)
	if pattern_points.is_empty():
		_spawn_enemy()
		return 1

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var pattern_extent: float = _get_pattern_extent(pattern_points)
	var anchor: Vector2 = _get_spawn_position(pattern_extent)
	var forward := Vector2.LEFT
	if player != null:
		forward = anchor.direction_to(player.global_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.LEFT
	var right := Vector2(-forward.y, forward.x)
	var formation_despawn_distance: float = max(get_viewport().get_visible_rect().size.length() * 0.9, 960.0)
	var shared_formation_speed: float = formation_move_speed * 3.0 * _get_stage_speed_multiplier()
	var group_id: int = next_formation_group_id
	next_formation_group_id += 1
	var max_center_distance: float = _get_pattern_extent(pattern_points)
	var spawn_requests: Array[Dictionary] = []
	for index in range(pattern_points.size()):
		var local_offset: Vector2 = pattern_points[index]
		var world_offset: Vector2 = forward * local_offset.y + right * local_offset.x
		var spawn_pos: Vector2 = anchor + world_offset
		var formation_scene: PackedScene = _pick_formation_enemy_scene(local_offset, max_center_distance)
		if formation_scene == null:
			continue
		spawn_requests.append({
			"scene": formation_scene,
			"position": spawn_pos,
			"forward": forward,
			"despawn_distance": formation_despawn_distance,
			"speed": shared_formation_speed
		})
	if spawn_requests.is_empty():
		return 0
	pending_formation_spawns.append({
		"group_id": group_id,
		"requests": spawn_requests,
		"next_index": 0,
		"members": []
	})
	return spawn_requests.size()


func _process_pending_formation_spawns() -> int:
	if pending_formation_spawns.is_empty():
		return 0

	var spawned_count := 0
	var budget: int = max(formation_spawn_batch_size, 1)
	while budget > 0 and not pending_formation_spawns.is_empty():
		var formation_data: Dictionary = pending_formation_spawns[0]
		var requests: Array = formation_data.get("requests", [])
		var next_index: int = int(formation_data.get("next_index", 0))
		var members: Array = formation_data.get("members", [])

		while budget > 0 and next_index < requests.size():
			var request: Dictionary = requests[next_index]
			var enemy: Node = _spawn_enemy_instance(
				request.get("scene", null),
				request.get("position", Vector2.ZERO),
				request.get("forward", Vector2.ZERO),
				float(request.get("despawn_distance", 0.0)),
				float(request.get("speed", 0.0))
			)
			if enemy != null:
				members.append(enemy)
				spawned_count += 1
			next_index += 1
			budget -= 1

		if next_index >= requests.size():
			if not members.is_empty():
				formation_groups[int(formation_data.get("group_id", 0))] = {
					"initial_count": members.size(),
					"members": members
				}
			pending_formation_spawns.pop_front()
		else:
			formation_data["next_index"] = next_index
			formation_data["members"] = members
			pending_formation_spawns[0] = formation_data
	return spawned_count


func _get_target_formation_size() -> int:
	var desired_size: int = int(10 + current_wave * 10 + round(_get_stage_count_multiplier() * 6.0))
	return clampi(desired_size, 6, 100)


func _build_random_formation_pattern(point_count: int) -> Array[Vector2]:
	var clamped_count: int = clampi(point_count, 4, 100)
	var generators: Array[Callable] = [
		_generate_rectangle_grid_pattern,
		_generate_hollow_rectangle_pattern,
		_generate_circle_pattern,
		_generate_ring_pattern,
		_generate_heart_pattern,
		_generate_diamond_pattern,
		_generate_arrow_pattern,
		_generate_double_column_pattern,
		_generate_wave_pattern,
		_generate_spiral_pattern
	]
	var generator: Callable = generators[randi() % generators.size()]
	return generator.call(clamped_count)


func _generate_rectangle_grid_pattern(point_count: int) -> Array[Vector2]:
	var spacing := 38.0
	var columns := clampi(ceili(sqrt(float(point_count))), 4, 10)
	var rows := ceili(float(point_count) / float(columns))
	var points: Array[Vector2] = []
	for row in range(rows):
		for column in range(columns):
			if points.size() >= point_count:
				break
			var offset_x: float = (float(column) - float(columns - 1) * 0.5) * spacing
			var offset_y: float = (float(row) - float(rows - 1) * 0.5) * spacing
			points.append(Vector2(offset_x, offset_y))
	return points


func _generate_hollow_rectangle_pattern(point_count: int) -> Array[Vector2]:
	var spacing := 42.0
	var columns := clampi(ceili(sqrt(float(point_count))) + 1, 4, 10)
	var rows := clampi(ceili(float(point_count) / float(columns)) + 1, 4, 10)
	var points: Array[Vector2] = []
	for row in range(rows):
		for column in range(columns):
			if points.size() >= point_count:
				return points
			var offset_x: float = (float(column) - float(columns - 1) * 0.5) * spacing
			var offset_y: float = (float(row) - float(rows - 1) * 0.5) * spacing
			points.append(Vector2(offset_x, offset_y))
	return points


func _generate_circle_pattern(point_count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var radius: float = max(110.0, sqrt(float(point_count)) * 22.0)
	for index in range(point_count):
		var angle: float = float(index) * 2.399963
		var radial: float = radius * sqrt((float(index) + 0.5) / float(max(point_count, 1)))
		points.append(Vector2(cos(angle), sin(angle)) * radial)
	return points


func _generate_ring_pattern(point_count: int) -> Array[Vector2]:
	return _generate_circle_pattern(point_count)


func _generate_heart_outline_point(t: float, scale: float) -> Vector2:
	var x: float = 16.0 * pow(sin(t), 3.0)
	var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
	return Vector2(x * scale, y * scale * 0.85)


func _trim_pattern(points: Array[Vector2], point_count: int) -> Array[Vector2]:
	var trimmed: Array[Vector2] = []
	for index in range(mini(points.size(), point_count)):
		trimmed.append(points[index])
	return trimmed


func _fill_pattern_gap(points: Array[Vector2], point_count: int, spacing: float) -> Array[Vector2]:
	var columns: int = clampi(ceili(sqrt(float(point_count))), 4, 12)
	var row := 0
	while points.size() < point_count:
		for column in range(columns):
			if points.size() >= point_count:
				return points
			var offset_x: float = (float(column) - float(columns - 1) * 0.5) * spacing
			var offset_y: float = float(row) * spacing
			points.append(Vector2(offset_x, offset_y))
		row += 1
	return points


func _generate_heart_pattern(point_count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var scale: float = max(10.0, sqrt(float(point_count)) * 3.3)
	var rings: int = clampi(ceili(sqrt(float(point_count)) * 0.65), 3, 9)
	for ring in range(rings):
		var ratio: float = 1.0 - float(ring) / float(rings)
		var samples: int = max(8, ceili(float(point_count) * ratio / float(rings)) + 4)
		for index in range(samples):
			if points.size() >= point_count:
				return points
			var t: float = TAU * float(index) / float(samples)
			points.append(_generate_heart_outline_point(t, scale) * ratio)
	if points.size() < point_count:
		points.append(Vector2.ZERO)
	return _fill_pattern_gap(points, point_count, 34.0)


func _generate_diamond_pattern(point_count: int) -> Array[Vector2]:
	var spacing := 34.0
	var points: Array[Vector2] = []
	var layer := 0
	while points.size() < point_count:
		for x in range(-layer, layer + 1):
			var y_abs: int = layer - abs(x)
			for sign in [-1, 1]:
				if y_abs == 0 and sign == -1:
					continue
				if points.size() >= point_count:
					return points
				points.append(Vector2(float(x) * spacing, float(y_abs * sign) * spacing))
		layer += 1
	return points


func _generate_arrow_pattern(point_count: int) -> Array[Vector2]:
	var spacing := 42.0
	var points: Array[Vector2] = []
	var rows: int = clampi(ceili(sqrt(float(point_count))) + 1, 4, 10)
	for row in range(rows):
		var row_ratio: float = float(row) / float(max(rows - 1, 1))
		var half_width: int = maxi(0, int(round((1.0 - absf(row_ratio - 0.45) * 1.6) * 3.0)))
		if row > rows * 0.55:
			half_width = maxi(half_width, 1)
		for column in range(-half_width, half_width + 1):
			if points.size() >= point_count:
				return points
			points.append(Vector2(float(column) * spacing, (row_ratio - 0.5) * float(rows) * spacing))
	return _fill_pattern_gap(points, point_count, spacing)


func _generate_double_column_pattern(point_count: int) -> Array[Vector2]:
	var spacing := 36.0
	var points: Array[Vector2] = []
	var columns: int = 4
	var rows: int = ceili(float(point_count) / float(columns))
	for row in range(rows):
		for column in range(columns):
			if points.size() >= point_count:
				return points
			var offset_x: float = (float(column) - float(columns - 1) * 0.5) * spacing
			var offset_y: float = (float(row) - float(rows - 1) * 0.5) * spacing
			points.append(Vector2(offset_x, offset_y))
	return points


func _generate_wave_pattern(point_count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var columns: int = clampi(ceili(sqrt(float(point_count)) * 1.4), 5, 16)
	var lanes: int = maxi(3, ceili(float(point_count) / float(columns)))
	var width: float = max(240.0, float(columns) * 34.0)
	for column in range(columns):
		var t: float = 0.0 if columns <= 1 else float(column) / float(columns - 1)
		var base_x: float = lerpf(-width * 0.5, width * 0.5, t)
		var base_y: float = sin(t * PI * 2.5) * 68.0
		for lane in range(lanes):
			if points.size() >= point_count:
				return points
			var lane_offset: float = (float(lane) - float(lanes - 1) * 0.5) * 34.0
			points.append(Vector2(base_x, base_y + lane_offset))
	return points


func _generate_spiral_pattern(point_count: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var max_radius: float = max(180.0, sqrt(float(point_count)) * 30.0)
	var lanes: int = 3
	var turns: int = maxi(4, ceili(float(point_count) / float(lanes)))
	for step in range(turns):
		var t: float = float(step) / float(max(turns - 1, 1))
		var angle: float = t * PI * 4.0
		var radius: float = lerpf(28.0, max_radius, t)
		var radial_direction: Vector2 = Vector2(cos(angle), sin(angle))
		var tangent_direction: Vector2 = Vector2(-radial_direction.y, radial_direction.x)
		for lane in range(lanes):
			if points.size() >= point_count:
				return points
			var lane_offset: float = (float(lane) - float(lanes - 1) * 0.5) * 36.0
			points.append(radial_direction * radius + tangent_direction * lane_offset)
	return points


func _get_pattern_extent(pattern_points: Array[Vector2]) -> float:
	var extent := 0.0
	for point in pattern_points:
		extent = maxf(extent, maxf(absf(point.x), absf(point.y)))
	return extent


func _pick_formation_enemy_scene(local_offset: Vector2, max_center_distance: float) -> PackedScene:
	var center_ratio: float = 0.0
	if max_center_distance > 0.0:
		center_ratio = clampf(local_offset.length() / max_center_distance, 0.0, 1.0)

	if center_ratio <= 0.22:
		if current_wave >= 3 and tank_enemy_scene != null:
			return tank_enemy_scene
		if dasher_enemy_scene != null:
			return dasher_enemy_scene
		return _pick_basic_enemy_scene()

	if center_ratio <= 0.55:
		var middle_pool: Array[PackedScene] = []
		if current_wave >= 3 and ranged_enemy_scene != null:
			middle_pool.append(ranged_enemy_scene)
		if dasher_enemy_scene != null:
			middle_pool.append(dasher_enemy_scene)
		if tank_enemy_scene != null and randf() < 0.18:
			middle_pool.append(tank_enemy_scene)
		if middle_pool.is_empty():
			return _pick_basic_enemy_scene()
		return middle_pool[randi() % middle_pool.size()]

	if center_ratio <= 0.8 and dasher_enemy_scene != null and randf() < 0.45:
		return dasher_enemy_scene
	return _pick_basic_enemy_scene()


func _update_formation_groups() -> void:
	if formation_groups.is_empty():
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var finished_group_ids: Array[int] = []
	for group_id_variant in formation_groups.keys():
		var group_id: int = int(group_id_variant)
		var formation_data: Dictionary = formation_groups[group_id]
		var members: Array = formation_data.get("members", [])
		var initial_count: int = int(formation_data.get("initial_count", members.size()))
		var active_formation_members: Array[Node] = []

		for member_variant in members:
			if not is_instance_valid(member_variant):
				continue
			var enemy := member_variant as Node
			if enemy == null:
				continue
			if not bool(enemy.get("formation_charge_mode")):
				continue
			if player != null and enemy is Node2D:
				var enemy_node := enemy as Node2D
				if enemy_node.global_position.distance_to(player.global_position) <= formation_break_distance:
					if _is_player_in_enemy_charge_front(enemy_node):
						active_formation_members.append(enemy)
						continue
					_release_formation_enemy(enemy)
					continue
			active_formation_members.append(enemy)

		if active_formation_members.is_empty():
			finished_group_ids.append(group_id)
			continue

		if active_formation_members.size() < ceili(float(initial_count) * 0.5):
			for enemy in active_formation_members:
				_release_formation_enemy(enemy)
			finished_group_ids.append(group_id)
		else:
			formation_data["members"] = active_formation_members
			formation_groups[group_id] = formation_data

	for group_id in finished_group_ids:
		formation_groups.erase(group_id)


func _release_formation_enemy(enemy: Node) -> void:
	if enemy.has_method("release_formation_charge"):
		enemy.release_formation_charge()
	else:
		enemy.set("formation_charge_mode", false)


func _is_player_in_enemy_charge_front(enemy: Node2D) -> bool:
	var player_node := get_tree().get_first_node_in_group("player") as Node2D
	if player_node == null or not is_instance_valid(player_node):
		return false
	var charge_direction: Vector2 = enemy.get("formation_direction")
	if charge_direction == Vector2.ZERO:
		return false
	var to_player: Vector2 = enemy.global_position.direction_to(player_node.global_position)
	if to_player == Vector2.ZERO:
		return true
	var front_threshold: float = cos(deg_to_rad(formation_front_hold_angle_degrees))
	return charge_direction.normalized().dot(to_player) >= front_threshold


func _pick_enemy_scene() -> PackedScene:
	var pool: Array[PackedScene] = []

	for _index in range(5):
		pool.append(_pick_basic_enemy_scene())

	if current_wave >= 2 and tank_enemy_scene != null:
		for _index in range(2):
			pool.append(tank_enemy_scene)
	if current_wave >= 2 and dasher_enemy_scene != null:
		pool.append(dasher_enemy_scene)

	if current_wave >= 3 and dasher_enemy_scene != null:
		for _index in range(3):
			pool.append(dasher_enemy_scene)
	if current_wave >= 3 and ranged_enemy_scene != null:
		pool.append(ranged_enemy_scene)

	if current_wave >= 4 and ranged_enemy_scene != null:
		for _index in range(4):
			pool.append(ranged_enemy_scene)
	if current_wave >= 4 and tank_enemy_scene != null:
		for _index in range(2):
			pool.append(tank_enemy_scene)

	if pool.is_empty():
		return _pick_basic_enemy_scene()

	return pool[randi() % pool.size()]


func _pick_basic_enemy_scene() -> PackedScene:
	if basic_enemy_variant_scene != null and randf() < 0.5:
		return basic_enemy_variant_scene
	return basic_enemy_scene


func _spawn_boss() -> void:
	var boss = boss_enemy_scene.instantiate()
	_apply_wave_scaling(boss)
	boss.global_position = _get_spawn_position()
	boss.defeated.connect(_on_enemy_defeated.bind("boss"))
	boss.defeated.connect(_on_boss_defeated)

	var enemies_root := get_tree().current_scene.get_node_or_null("Enemies")
	if enemies_root == null:
		enemies_root = get_parent()
	enemies_root.add_child(boss)
	active_enemies += 1
	boss_spawned_once = true
	boss_spawned.emit(boss)
	_spawn_boss_arrival_fx(boss.global_position)
	for _index in range(2):
		_spawn_enemy()
	boss_phase_total_enemies = active_enemies + enemies_to_spawn


func _get_wave_enemy_count(wave: int) -> int:
	var index: int = clampi(wave - 1, 0, wave_enemy_counts.size() - 1)
	var base_count: int = 12 + wave * 6
	if wave_enemy_counts.is_empty():
		base_count = 12 + wave * 6
	else:
		base_count = int(wave_enemy_counts[index])
	return max(int(round(float(base_count) * _get_stage_count_multiplier())), 1)


func _get_wave_spawn_interval(wave: int) -> float:
	var index: int = clampi(wave - 1, 0, wave_spawn_intervals.size() - 1)
	var base_interval: float = max(0.18, 0.56 - wave * 0.08)
	if wave_spawn_intervals.is_empty():
		base_interval = max(0.18, 0.56 - wave * 0.08)
	else:
		base_interval = float(wave_spawn_intervals[index])
	return max(base_interval / _get_stage_spawn_rate_multiplier(), 0.03)


func _get_elite_count(wave: int) -> int:
	var base_elites := 0
	if wave < 2:
		base_elites = 0
	elif wave == 2:
		base_elites = 1
	elif wave == 3:
		base_elites = 2
	else:
		base_elites = 3
	return int(round(float(base_elites) * _get_stage_elite_multiplier()))


func _get_formation_event_count(wave: int) -> int:
	if wave < 2:
		return 0
	var base_formations: int = 1
	if wave >= 3:
		base_formations += 1
	if wave >= 4:
		base_formations += 1
	return maxi(int(round(float(base_formations) * (0.9 + (_get_stage_count_multiplier() - 1.0) * 0.25))), 1)


func _apply_wave_scaling(enemy: Node) -> void:
	var enemy_kind: String = _classify_enemy(enemy)
	var is_boss_enemy: bool = enemy_kind == "boss"
	var vitality_scale: float = 1.0 + float(max(current_wave - 1, 0)) * 0.12
	var speed_scale: float = 1.0 + float(max(current_wave - 1, 0)) * 0.03
	var stage_health_multiplier: float = _get_stage_health_multiplier()
	var stage_speed_multiplier: float = _get_stage_speed_multiplier()
	var stage_damage_multiplier: float = _get_stage_damage_multiplier()
	var stage_experience_multiplier: float = _get_stage_experience_multiplier()
	var stage_boss_health_multiplier: float = _get_stage_boss_health_multiplier()
	var stage_boss_attack_multiplier: float = _get_stage_boss_attack_multiplier()
	if enemy.get("max_health") != null:
		var total_health_scale: float = vitality_scale * stage_health_multiplier
		if is_boss_enemy:
			total_health_scale *= stage_boss_health_multiplier
		enemy.max_health = int(round(float(enemy.max_health) * total_health_scale))
		enemy.health = enemy.max_health
	if enemy.get("move_speed") != null:
		enemy.move_speed = float(enemy.move_speed) * speed_scale * stage_speed_multiplier
	if enemy.get("contact_damage") != null and current_wave >= 4:
		enemy.contact_damage = max(int(round((int(enemy.contact_damage) + 1) * stage_damage_multiplier)), 1)
	elif enemy.get("contact_damage") != null:
		enemy.contact_damage = max(int(round(int(enemy.contact_damage) * stage_damage_multiplier)), 1)
	if enemy.get("experience_value") != null:
		enemy.experience_value = max(int(round(float(enemy.experience_value) * stage_experience_multiplier)), 1)
	if enemy.get("fire_interval") != null:
		enemy.fire_interval = max(float(enemy.fire_interval) / _get_stage_spawn_rate_multiplier(), 0.18)
	if enemy.get("volley_interval") != null:
		enemy.volley_interval = max(float(enemy.volley_interval) / _get_stage_boss_attack_multiplier(), 0.3)
	if enemy.get("volley_count") != null:
		enemy.volley_count = max(int(round(float(enemy.volley_count) * (0.85 + stage_boss_attack_multiplier * 0.35))), 3)
	if enemy.get("projectile_speed") != null:
		enemy.projectile_speed = float(enemy.projectile_speed) * (1.0 + (stage_damage_multiplier - 1.0) * 0.4)
	if enemy.get("charge_damage") != null:
		enemy.charge_damage = max(int(round(float(enemy.charge_damage) * stage_boss_attack_multiplier)), 1)
	if enemy.get("charge_interval") != null:
		enemy.charge_interval = max(float(enemy.charge_interval) / max(stage_boss_attack_multiplier, 1.0), 1.8)
	if enemy.get("damage_resistance") != null and is_boss_enemy:
		enemy.damage_resistance = min(float(enemy.damage_resistance) + (stage_boss_health_multiplier - 1.0) * 0.03, 0.78)


func _spawn_boss_arrival_fx(position: Vector2) -> void:
	var pulse_scene: PackedScene = preload("res://scenes/PulseWave.tscn")
	if pulse_scene == null:
		return

	var pulse_wave = pulse_scene.instantiate()
	pulse_wave.global_position = position
	pulse_wave.radius = 320.0
	pulse_wave.ring_color = Color(1.0, 0.82, 0.32, 0.95)
	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(pulse_wave)


func _get_spawn_position(extra_margin: float = 0.0) -> Vector2:
	var player = get_tree().get_first_node_in_group("player") as Node2D
	var center := Vector2.ZERO
	if player != null:
		center = player.global_position

	var camera := _get_spawn_camera()
	var viewport_size := get_viewport().get_visible_rect().size
	var half_view := viewport_size * 0.5
	if camera != null:
		half_view = viewport_size * camera.zoom * 0.5

	var min_x: float = max(half_view.x + spawn_offscreen_margin + extra_margin, spawn_safe_radius, spawn_distance_min)
	var min_y: float = max(half_view.y + spawn_offscreen_margin + extra_margin, spawn_safe_radius, spawn_distance_min)
	var max_x: float = max(min_x + 24.0, max(spawn_distance_max, min_x + 24.0))
	var max_y: float = max(min_y + 24.0, max(spawn_distance_max, min_y + 24.0))

	match randi() % 4:
		0:
			return center + Vector2(randf_range(-max_x, max_x), -randf_range(min_y, max_y))
		1:
			return center + Vector2(randf_range(min_x, max_x), randf_range(-max_y, max_y))
		2:
			return center + Vector2(randf_range(-max_x, max_x), randf_range(min_y, max_y))
		_:
			return center + Vector2(-randf_range(min_x, max_x), randf_range(-max_y, max_y))


func _get_spawn_camera() -> Camera2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D


func _on_enemy_defeated(enemy_kind: String = "enemy") -> void:
	active_enemies = max(active_enemies - 1, 0)
	enemy_defeated.emit(enemy_kind)
	_emit_enemy_count()


func _on_enemy_removed_from_field() -> void:
	active_enemies = max(active_enemies - 1, 0)
	_emit_enemy_count()


func _on_chest_dropped(position: Vector2) -> void:
	if chests_spawned_total >= chest_target_total:
		return
	elite_chest_progress += 1
	if elite_chest_progress < 2:
		return
	elite_chest_progress = 0
	chests_spawned_total += 1
	chest_spawn_requested.emit(position)


func _on_boss_defeated() -> void:
	boss_defeated.emit()


func _emit_enemy_count() -> void:
	enemy_count_changed.emit(active_enemies + enemies_to_spawn)


func _classify_enemy(enemy: Node) -> String:
	if enemy.is_in_group("bosses"):
		return "boss"
	if enemy.is_in_group("elites"):
		return "elite"
	if enemy.get_script() != null:
		var script_path: String = String(enemy.get_script().resource_path)
		if script_path.ends_with("DasherEnemy.gd"):
			return "dasher"
		if script_path.ends_with("TankEnemy.gd"):
			return "tank"
		if script_path.ends_with("RangedEnemy.gd"):
			return "ranged"
	return "enemy"


func _get_stage_config() -> Dictionary:
	return STAGE_DIFFICULTY.get(current_stage_id, STAGE_DIFFICULTY["ruins"])


func _get_stage_count_multiplier() -> float:
	return float(_get_stage_config().get("count_multiplier", 1.0))


func _get_stage_spawn_rate_multiplier() -> float:
	return float(_get_stage_config().get("spawn_rate_multiplier", 1.0))


func _get_stage_health_multiplier() -> float:
	return float(_get_stage_config().get("health_multiplier", 1.0))


func _get_stage_speed_multiplier() -> float:
	return float(_get_stage_config().get("speed_multiplier", 1.0))


func _get_stage_damage_multiplier() -> float:
	return float(_get_stage_config().get("damage_multiplier", 1.0))


func _get_stage_elite_multiplier() -> float:
	return float(_get_stage_config().get("elite_multiplier", 1.0))


func _get_stage_experience_multiplier() -> float:
	return float(_get_stage_config().get("experience_multiplier", 1.0))


func _get_stage_boss_health_multiplier() -> float:
	return float(_get_stage_config().get("boss_health_multiplier", 1.0))


func _get_stage_boss_attack_multiplier() -> float:
	return float(_get_stage_config().get("boss_attack_multiplier", 1.0))
