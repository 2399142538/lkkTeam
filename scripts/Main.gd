extends Node2D

@export var arena_size := Vector2(1280, 720)
@export var target_run_time := 120.0

const STAGE_ORDER := ["ruins", "factory", "sanctum"]

@onready var player = $Player
@onready var spawner = $Spawner
@onready var hud = $HUD
@onready var mobile_controls = $HUD/MobileControls
@onready var player_camera = $Player/Camera2D
@onready var map_backdrop = $MapBackdrop

var is_game_over := false
var awarded_shards := false
var run_time := 0.0
var active_boss: Node = null
var kill_count := 0
var elite_kill_count := 0
var level_up_count := 0
var chest_open_count := 0
var boss_phase_time := 0.0
var shards_earned := 0
var default_camera_zoom := Vector2.ONE
var pending_upgrade_level := 0


func _ready() -> void:
	randomize()
	default_camera_zoom = player_camera.zoom
	map_backdrop.tile_size = arena_size
	if has_node("/root/MetaProgression"):
		map_backdrop.set_stage(String(MetaProgression.selected_stage))
	map_backdrop.set_focus_state(player_camera.get_screen_center_position(), get_viewport_rect().size * player_camera.zoom)
	player.health_changed.connect(_on_player_health_changed)
	player.experience_changed.connect(_on_player_experience_changed)
	player.level_up_requested.connect(_on_player_level_up_requested)
	player.weapon_updated.connect(_on_weapon_updated)
	player.weapon.ammo_changed.connect(_on_weapon_ammo_changed)
	player.charge_state_changed.connect(_on_charge_state_changed)
	player.extra_lives_changed.connect(_on_player_extra_lives_changed)
	player.died.connect(_on_player_died)
	spawner.wave_started.connect(_on_wave_started)
	spawner.wave_cleared.connect(_on_wave_cleared)
	spawner.boss_defeated.connect(_on_boss_defeated)
	spawner.boss_spawned.connect(_on_boss_spawned)
	spawner.enemy_defeated.connect(_on_enemy_defeated)
	spawner.enemy_count_changed.connect(_on_enemy_count_changed)
	spawner.chest_spawn_requested.connect(_on_chest_spawn_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.menu_requested.connect(_on_menu_requested)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.upgrade_refresh_requested.connect(_on_upgrade_refresh_requested)
	hud.supply_selected.connect(_on_supply_selected)
	hud.chest_reward_selected.connect(_on_chest_reward_selected)
	hud.force_spawn_requested.connect(_on_force_spawn_requested)
	mobile_controls.move_vector_changed.connect(player.set_touch_move_vector)
	mobile_controls.aim_state_changed.connect(player.set_touch_aim_state)
	mobile_controls.dash_pressed.connect(player.request_touch_dash)
	mobile_controls.reload_pressed.connect(player.request_touch_reload)
	mobile_controls.skill_state_changed.connect(player.set_touch_skill_pressed)

	hud.set_health(player.health, player.max_health)
	hud.set_experience(player.experience, player.experience_to_next_level, player.level)
	hud.set_wave(0)
	hud.set_enemy_count(0)
	hud.set_weapon(player.weapon.get_weapon_name())
	hud.set_ammo(player.weapon.current_ammo, player.weapon.magazine_size, player.weapon.is_reloading(), player.weapon.get_reload_progress())
	hud.set_charge_skill(player.charge_skill_cooldown_left, player.charge_skill_cooldown, player.is_charging_skill, 0.0)
	hud.set_extra_lives(player.extra_lives)
	hud.set_timer(run_time)
	hud.set_wave_progress(0.0, 1, spawner.final_wave)
	spawner.start_waves()


func _process(delta: float) -> void:
	map_backdrop.set_focus_state(player_camera.get_screen_center_position(), get_viewport_rect().size * player_camera.zoom)
	if not is_game_over:
		run_time += delta
		if active_boss != null and is_instance_valid(active_boss):
			boss_phase_time += delta
			hud.update_boss_health(int(active_boss.health), int(active_boss.max_health))
		hud.set_timer(run_time)
		hud.set_wave_progress(spawner.get_wave_progress_ratio(), maxi(spawner.current_wave, 1), spawner.final_wave)
		hud.set_charge_skill(player.charge_skill_cooldown_left, player.charge_skill_cooldown, player.is_charging_skill, player.charge_hold_time / max(player.charge_skill_hold_time, 0.001))


func _on_player_health_changed(current_health: int, maximum_health: int) -> void:
	hud.set_health(current_health, maximum_health)


func _on_wave_started(wave: int) -> void:
	hud.set_wave(wave)
	hud.set_wave_progress(spawner.get_wave_progress_ratio(), wave, spawner.final_wave)
	if wave >= spawner.final_wave:
		hud.show_announcement("首领出现：深渊裂喉者", Color(1, 0.82, 0.44, 1))


func _on_enemy_count_changed(count: int) -> void:
	hud.set_enemy_count(count)


func _on_player_extra_lives_changed(current_extra_lives: int) -> void:
	hud.set_extra_lives(current_extra_lives)


func _on_weapon_updated(weapon_name: String) -> void:
	hud.set_weapon(weapon_name)
	hud.set_ammo(player.weapon.current_ammo, player.weapon.magazine_size, player.weapon.is_reloading(), player.weapon.get_reload_progress())


func _on_weapon_ammo_changed(current_ammo: int, max_ammo: int, is_reloading: bool, reload_progress: float) -> void:
	hud.set_ammo(current_ammo, max_ammo, is_reloading, reload_progress)


func _on_charge_state_changed(cooldown_left: float, max_cooldown: float, is_charging: bool, charge_progress: float) -> void:
	hud.set_charge_skill(cooldown_left, max_cooldown, is_charging, charge_progress)


func _on_player_experience_changed(current_experience: int, experience_to_next_level: int, level: int) -> void:
	hud.set_experience(current_experience, experience_to_next_level, level)


func _on_player_level_up_requested(level: int, choices: Array) -> void:
	level_up_count += 1
	pending_upgrade_level = level
	get_tree().paused = true
	hud.show_upgrade_choices(level, choices)


func _on_wave_cleared(wave: int) -> void:
	if is_game_over:
		return
	if wave >= spawner.final_wave:
		return
	hud.show_announcement("第 %d 波已清空" % wave, Color(0.72, 0.96, 1.0, 1.0))


func _on_player_died() -> void:
	is_game_over = true
	spawner.enabled = false
	get_tree().paused = true
	_award_meta_currency()
	hud.show_game_over(spawner.current_wave, false, _build_end_summary())
	_freeze_battlefield()


func _on_boss_defeated() -> void:
	if is_game_over:
		return
	hud.hide_boss_bar()
	hud.show_announcement("首领已击破", Color(0.78, 1, 0.82, 1))
	_on_victory()


func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_upgrade_selected(upgrade_id: String) -> void:
	player.apply_upgrade(upgrade_id)
	pending_upgrade_level = 0
	hud.hide_upgrade_choices()
	get_tree().paused = false


func _on_upgrade_refresh_requested() -> void:
	if pending_upgrade_level <= 0:
		return
	hud.show_upgrade_choices(pending_upgrade_level, player.build_reroll_upgrade_choices())


func _on_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_force_spawn_requested() -> void:
	if is_game_over or get_tree().paused:
		return
	var spawned_total: int = spawner.spawn_all_remaining_enemies()
	if spawned_total > 0:
		hud.show_announcement("已补刷剩余怪物 %d" % spawned_total, Color(1, 0.78, 0.42, 1))


func _on_chest_spawn_requested(position: Vector2) -> void:
	var chest_scene = preload("res://scenes/ChestPickup.tscn")
	var chest = chest_scene.instantiate()
	chest.global_position = position
	chest.opened.connect(_on_chest_opened)
	var pickup_root := get_node_or_null("Pickups")
	if pickup_root == null:
		pickup_root = self
	pickup_root.add_child(chest)


func _build_supply_choices() -> Array:
	var pool := [
		{
			"id": "field_medicine",
			"title": "战地医疗",
			"description": "回复 3 点生命"
		},
		{
			"id": "hard_shell",
			"title": "硬化甲壳",
			"description": "最大生命 +1，并回复 1 点生命"
		},
		{
			"id": "powder_charge",
			"title": "火药填装",
			"description": "子弹伤害 +1"
		},
		{
			"id": "fresh_mag",
			"title": "新弹匣",
			"description": "射速提升"
		},
		{
			"id": "side_thrusters",
			"title": "侧向推进",
			"description": "移动速度 +20"
		},
		{
			"id": "spread_burst",
			"title": "散射爆发",
			"description": "额外发射 1 颗子弹"
		},
		{
			"id": "sharp_eye",
			"title": "鹰眼校准",
			"description": "暴击概率提升"
		},
		{
			"id": "revival_kit",
			"title": "应急复苏",
			"description": "获得 1 次复活机会"
		},
		{
			"id": "armor_plate",
			"title": "防护钢板",
			"description": "减伤提升"
		},
		{
			"id": "targeting_chip",
			"title": "制导芯片",
			"description": "自动瞄准范围更远"
		},
		{
			"id": "killer_instinct",
			"title": "杀意校准",
			"description": "暴击伤害提升"
		},
		{
			"id": "magnet_field",
			"title": "磁场线圈",
			"description": "收集范围提升"
		}
	]

	pool.shuffle()
	return pool.slice(0, 3)


func _on_supply_selected(supply_id: String) -> void:
	match supply_id:
		"field_medicine":
			player.heal(3)
		"hard_shell":
			player.max_health += 1
			player.heal(1)
			player.health_changed.emit(player.health, player.max_health)
		"powder_charge":
			player.weapon.projectile_damage += 1
		"fresh_mag":
			player.weapon.fire_rate = max(player.weapon.fire_rate - 0.02, 0.08)
		"side_thrusters":
			player.move_speed += 20.0
		"spread_burst":
			player.weapon.projectile_count += 1
			player.weapon.spread_degrees = min(player.weapon.spread_degrees + 6.0, 42.0)
		"sharp_eye":
			player.weapon.crit_chance = min(player.weapon.crit_chance + 0.08, 0.8)
		"revival_kit":
			player.add_extra_lives(1)
		"armor_plate":
			player.damage_reduction = min(player.damage_reduction + 0.08, 0.6)
		"targeting_chip":
			player.weapon.auto_aim_range += 120.0
		"killer_instinct":
			player.weapon.crit_multiplier += 0.25
		"magnet_field":
			player.collect_range += 35.0
			player.pickup_pull_speed += 80.0
		_:
			pass

	hud.hide_supply_choices()
	get_tree().paused = false
	spawner.continue_to_next_wave()


func _on_chest_opened(_position: Vector2) -> void:
	if is_game_over:
		return
	chest_open_count += 1
	get_tree().paused = true
	hud.show_chest_rewards(_build_chest_rewards())


func _build_chest_rewards() -> Array:
	var pool := [
		{"id": "elite_power", "title": "首领奖赏", "description": "子弹伤害 +2"},
		{"id": "elite_vitality", "title": "生命赐福", "description": "最大生命 +3，并回复 3 点生命"},
		{"id": "elite_reload", "title": "极速改造", "description": "射速显著提升"},
		{"id": "elite_crit", "title": "致命铭刻", "description": "暴击概率与暴击伤害提升"},
		{"id": "elite_weapon", "title": "武器秘藏", "description": "获得当前武器专属强化"},
		{"id": "elite_guard", "title": "守护屏障", "description": "获得减伤和 1 次复活"}
	]
	pool.shuffle()
	return pool.slice(0, 3)


func _on_chest_reward_selected(reward_id: String) -> void:
	match reward_id:
		"elite_power":
			player.weapon.projectile_damage += 2
		"elite_vitality":
			player.max_health += 3
			player.heal(3)
			player.health_changed.emit(player.health, player.max_health)
		"elite_reload":
			player.weapon.fire_rate = max(player.weapon.fire_rate - 0.05, 0.06)
		"elite_crit":
			player.weapon.crit_chance = min(player.weapon.crit_chance + 0.18, 0.85)
			player.weapon.crit_multiplier += 0.4
		"elite_weapon":
			_apply_elite_weapon_reward()
		"elite_guard":
			player.damage_reduction = min(player.damage_reduction + 0.12, 0.6)
			player.add_extra_lives(1)
		_:
			pass

	hud.hide_chest_rewards()
	get_tree().paused = false


func _on_victory() -> void:
	is_game_over = true
	spawner.enabled = false
	get_tree().paused = false
	_unlock_next_stage()
	_award_meta_currency(true)
	hud.show_game_over(spawner.current_wave, true, _build_end_summary())
	_freeze_battlefield()


func _award_meta_currency(victory := false) -> void:
	if awarded_shards:
		return
	if not has_node("/root/MetaProgression"):
		return

	var reward: int = max(spawner.current_wave - 1, 0)
	if victory:
		reward += 6
	if reward > 0:
		shards_earned = reward
		MetaProgression.add_soul_shards(reward)
	awarded_shards = true


func _build_end_summary() -> String:
	return "存活时间 %s\n等级 %d\n波次 %d\n击杀 %d\n精英击杀 %d\n升级选择 %d\n宝箱开启 %d\nBoss 对战 %s\n碎片收益 %d\n当前武器 %s" % [
		hud.format_time(run_time),
		player.level,
		spawner.current_wave,
		kill_count,
		elite_kill_count,
		level_up_count,
		chest_open_count,
		hud.format_time(boss_phase_time),
		shards_earned,
		player.weapon.get_weapon_name()
	]


func _freeze_battlefield() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

	var enemy_projectiles := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if enemy_projectiles != null:
		for projectile in enemy_projectiles.get_children():
			projectile.queue_free()


func _apply_elite_weapon_reward() -> void:
	match player.weapon.weapon_id:
		"shotgun":
			player.weapon.apply_upgrade("buckshot")
		"flame":
			player.weapon.apply_upgrade("napalm")
		"arc":
			player.weapon.apply_upgrade("chain_mastery")
		_:
			player.apply_upgrade("precision_barrel")


func _on_boss_spawned(boss: Node) -> void:
	active_boss = boss
	boss_phase_time = 0.0
	if active_boss.has_signal("health_updated"):
		active_boss.health_updated.connect(_on_boss_health_updated)
	hud.show_boss_bar("深渊裂喉者", int(boss.health), int(boss.max_health))
	_play_boss_intro(boss)


func _on_boss_health_updated(current_health: int, maximum_health: int) -> void:
	hud.update_boss_health(current_health, maximum_health)


func _on_enemy_defeated(enemy_kind: String) -> void:
	if enemy_kind == "boss":
		return
	kill_count += 1
	player.register_enemy_kill()
	if enemy_kind == "elite":
		elite_kill_count += 1


func _play_boss_intro(boss: Node) -> void:
	if player_camera == null or not is_instance_valid(boss):
		return

	hud.show_announcement("深渊裂喉者降临", Color(1, 0.8, 0.44, 1))
	var boss_node: Node2D = boss as Node2D
	if boss_node == null:
		return
	var offset_direction: Vector2 = player.global_position.direction_to(boss_node.global_position)
	var intro_offset: Vector2 = offset_direction * 120.0
	var tween := create_tween()
	tween.tween_property(player_camera, "zoom", default_camera_zoom * 1.12, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(player_camera, "offset", intro_offset, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.4)
	tween.tween_property(player_camera, "zoom", default_camera_zoom, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(player_camera, "offset", Vector2.ZERO, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unlock_next_stage() -> void:
	if not has_node("/root/MetaProgression"):
		return
	var current_stage_id: String = String(MetaProgression.selected_stage)
	var current_index: int = STAGE_ORDER.find(current_stage_id)
	if current_index == -1 or current_index >= STAGE_ORDER.size() - 1:
		return
	var next_stage_id: String = STAGE_ORDER[current_index + 1]
	if MetaProgression.unlock_stage(next_stage_id):
		var next_stage_name := _get_stage_title(next_stage_id)
		hud.show_announcement("已解锁新关卡：%s" % next_stage_name, Color(0.76, 1, 0.84, 1))


func _get_stage_title(stage_id: String) -> String:
	match stage_id:
		"factory":
			return "钢铁工场"
		"sanctum":
			return "星环圣所"
		_:
			return "遗迹试炼场"
