extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died
signal experience_changed(current_experience: int, experience_to_next_level: int, level: int)
signal level_up_requested(level: int, choices: Array)
signal weapon_updated(weapon_name: String)
signal charge_state_changed(cooldown_left: float, max_cooldown: float, is_charging: bool, charge_progress: float)
signal extra_lives_changed(current_extra_lives: int)

const ENDGAME_LEVEL_THRESHOLD := 35
const MELEE_WEAPON_IDS := ["sword", "spear"]
const MELEE_BLOCKED_UPGRADE_IDS := [
	"power",
	"rapid_fire",
	"multishot",
	"spread_control",
	"piercing",
	"velocity",
	"heavy_rounds",
	"seeker",
	"explosive_rounds",
	"blast_radius",
	"blast_payload",
	"fire_rounds",
	"wildfire",
	"frost_rounds",
	"deep_freeze",
	"tactical_reload",
	"drum_mag",
	"extended_mag",
	"quick_reload",
	"steady_hands",
	"precision_barrel",
	"fusion_starbreaker"
]


@export var move_speed := 260.0
@export var dash_speed := 620.0
@export var dash_duration := 0.18
@export var dash_cooldown := 0.9
@export var max_health := 8
@export var damage_cooldown := 0.5
@export var collect_range := 90.0
@export var pickup_pull_speed := 540.0
@export var charge_skill_cooldown := 18.0
@export var charge_skill_hold_time := 0.65
@export var charge_skill_radius := 220.0
@export var charge_skill_damage := 10
@export var player_normal_modulate := Color(1, 1, 1, 1)

var health := max_health
var level := 1
var experience := 0
var experience_to_next_level := 2
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var damage_cooldown_left := 0.0
var alive := true
var extra_lives := 0
var damage_reduction := 0.0
var aim_direction := Vector2.RIGHT
var camera_shake_strength := 0.0
var dash_ghost_cooldown_left := 0.0
var floating_text_scene: PackedScene = preload("res://scenes/FloatingText.tscn")
var pulse_wave_scene: PackedScene = preload("res://scenes/PulseWave.tscn")
var charge_skill_cooldown_left := 0.0
var charge_hold_time := 0.0
var is_charging_skill := false
var revive_invulnerability_left := 0.0
var passive_regen_interval := 0.0
var passive_regen_timer := 0.0
var kill_heal_chance := 0.0
var periodic_shield_interval := 0.0
var shield_recharge_timer := 0.0
var shield_charges := 0
var max_shield_charges := 1
var bonus_healing := 0
var touch_move_vector := Vector2.ZERO
var touch_aim_active := false
var touch_aim_screen_position := Vector2.ZERO
var touch_dash_requested := false
var touch_reload_requested := false
var touch_skill_pressed := false
var touch_skill_just_released := false

@onready var weapon = $Weapon
@onready var camera = $Camera2D
@onready var visual = $Visual
@onready var health_bar = $HealthBar
@onready var ammo_text = $AmmoText
@onready var reload_bar = $ReloadBar


func _ready() -> void:
	add_to_group("player")
	_setup_health_bar_style()
	_apply_meta_progression()
	health_changed.connect(_on_health_changed)
	weapon.fired.connect(_on_weapon_fired)
	weapon.ammo_changed.connect(_on_weapon_ammo_display_changed)
	weapon.weapon_changed.connect(_on_weapon_changed)
	health = max_health
	health_changed.emit(health, max_health)
	experience_to_next_level = _get_experience_needed_for_level(level)
	experience_changed.emit(experience, experience_to_next_level, level)
	weapon_updated.emit(weapon.get_weapon_name())
	extra_lives_changed.emit(extra_lives)
	_on_weapon_ammo_display_changed(weapon.current_ammo, weapon.magazine_size, weapon.is_reloading(), weapon.get_reload_progress())
	_emit_charge_state_changed()


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		return

	_update_timers(delta)
	_update_survival_passives(delta)
	_update_revive_invulnerability_visual()
	_handle_charge_skill(delta)
	_handle_dash()
	_update_camera(delta)
	_update_dash_ghost(delta)

	var input_vector := touch_move_vector
	if input_vector == Vector2.ZERO:
		input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var current_speed := dash_speed if dash_time_left > 0.0 else move_speed
	if is_charging_skill:
		current_speed *= 0.4
	velocity = input_vector * current_speed
	move_and_slide()

	var aim_target_position := get_global_mouse_position()
	if touch_aim_active:
		aim_target_position = _screen_to_world(touch_aim_screen_position)
	aim_direction = weapon.get_aim_direction(aim_target_position)
	_update_facing()
	_update_status_display_position()

	if touch_aim_active or Input.is_action_pressed("fire"):
		weapon.try_fire(weapon.get_target_position(aim_target_position))
	if touch_reload_requested or Input.is_action_just_pressed("reload"):
		weapon.start_reload()
	touch_reload_requested = false
	queue_redraw()


func _update_revive_invulnerability_visual() -> void:
	if revive_invulnerability_left > 0.0:
		var blink_phase: float = sin(Time.get_ticks_msec() * 0.05)
		visual.modulate.a = 0.45 if blink_phase > 0.0 else 1.0
	else:
		visual.modulate.a = 1.0


func take_damage(amount: int) -> void:
	if not alive:
		return
	if damage_cooldown_left > 0.0 or dash_time_left > 0.0:
		return
	if shield_charges > 0:
		shield_charges -= 1
		damage_cooldown_left = 0.12
		_show_popup_text("护盾抵消", Color(0.58, 0.96, 1.0, 1.0), 1.0)
		return

	amount = max(int(round(amount * (1.0 - damage_reduction))), 1)
	damage_cooldown_left = damage_cooldown
	health = max(health - amount, 0)
	_flash_player_hit()
	_show_damage_text(amount)
	if has_node("/root/SFXManager"):
		SFXManager.play_player_hurt()
	_update_health_bar()
	health_changed.emit(health, max_health)

	if health == 0:
		if extra_lives > 0:
			extra_lives -= 1
			extra_lives_changed.emit(extra_lives)
			health = max(ceil(max_health * 0.5), 1)
			damage_cooldown_left = 0.5
			revive_invulnerability_left = 0.5
			_show_revival_feedback()
			_update_health_bar()
			health_changed.emit(health, max_health)
			return
		alive = false
		died.emit()


func heal(amount: int) -> void:
	if not alive:
		return

	var final_amount: int = max(amount + bonus_healing, 0)
	if final_amount <= 0:
		return
	health = min(health + final_amount, max_health)
	_update_health_bar()
	health_changed.emit(health, max_health)


func gain_experience(amount: int) -> void:
	if not alive:
		return

	experience += amount
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = _get_experience_needed_for_level(level)
		experience_changed.emit(experience, experience_to_next_level, level)
		level_up_requested.emit(level, _build_upgrade_choices())

	experience_changed.emit(experience, experience_to_next_level, level)


func build_reroll_upgrade_choices() -> Array:
	return _build_upgrade_choices()


func apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"vitality":
			max_health += 2
			health = min(health + 2, max_health)
			_update_health_bar()
			health_changed.emit(health, max_health)
		"agility":
			move_speed += 25.0
		"dash_drive":
			dash_cooldown = max(dash_cooldown - 0.08, 0.3)
		"haste":
			dash_duration += 0.03
		"guardian_spark":
			add_extra_lives(1)
		"battle_trance":
			weapon.crit_chance = min(weapon.crit_chance + 0.15, 0.8)
		"iron_skin":
			damage_reduction = min(damage_reduction + 0.12, 0.6)
		"dash_burst":
			dash_speed += 80.0
		"second_wind":
			heal(2)
		"point_blank":
			weapon.crit_chance = min(weapon.crit_chance + 0.18, 0.85)
		"heat_sink":
			weapon.auto_aim_range += 70.0
			weapon.projectile_lifetime += 0.12
		"voltage_surge":
			weapon.crit_multiplier += 0.5
		"steady_hands":
			weapon.fire_rate = max(weapon.fire_rate - 0.02, 0.08)
			weapon.crit_chance = min(weapon.crit_chance + 0.08, 0.8)
		"precision_barrel":
			weapon.projectile_speed += 120.0
			weapon.projectile_damage += 1
		"tactical_reload":
			weapon.reload_time = max(weapon.reload_time - 0.15, 0.3)
			weapon._emit_ammo_changed()
		"drum_mag":
			weapon.magazine_size += 4
			weapon.current_ammo += 4
			weapon.current_ammo = min(weapon.current_ammo, weapon.magazine_size)
			weapon._emit_ammo_changed()
		"magnet_core":
			collect_range += 45.0
		"vacuum_drive":
			collect_range += 25.0
			pickup_pull_speed += 120.0
		"recovery_surge":
			heal(2)
		"soul_shard":
			if has_node("/root/MetaProgression"):
				MetaProgression.add_soul_shards(1)
			_show_popup_text("灵魂碎片 +1", Color(0.6, 0.95, 1.0, 1.0), 0.95)
		_:
			if weapon.apply_upgrade(upgrade_id):
				return
			return


func _update_timers(delta: float) -> void:
	dash_time_left = max(dash_time_left - delta, 0.0)
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	damage_cooldown_left = max(damage_cooldown_left - delta, 0.0)
	dash_ghost_cooldown_left = max(dash_ghost_cooldown_left - delta, 0.0)
	charge_skill_cooldown_left = max(charge_skill_cooldown_left - delta, 0.0)
	revive_invulnerability_left = max(revive_invulnerability_left - delta, 0.0)


func _update_survival_passives(delta: float) -> void:
	if passive_regen_interval > 0.0:
		passive_regen_timer -= delta
		while passive_regen_timer <= 0.0:
			heal(1)
			passive_regen_timer += passive_regen_interval

	if periodic_shield_interval > 0.0:
		if shield_charges >= max_shield_charges:
			shield_recharge_timer = periodic_shield_interval
		else:
			shield_recharge_timer -= delta
			while shield_recharge_timer <= 0.0:
				_add_shield(1)
				shield_recharge_timer += periodic_shield_interval


func _handle_dash() -> void:
	if is_charging_skill:
		return
	if (touch_dash_requested or Input.is_action_just_pressed("dash")) and dash_cooldown_left <= 0.0:
		dash_time_left = dash_duration
		dash_cooldown_left = dash_cooldown
		camera_shake_strength = max(camera_shake_strength, 5.0)
	touch_dash_requested = false


func _update_facing() -> void:
	rotation = 0.0
	visual.scale.x = abs(visual.scale.x)


func _handle_charge_skill(delta: float) -> void:
	if charge_skill_cooldown_left > 0.0 and is_charging_skill:
		is_charging_skill = false
		charge_hold_time = 0.0

	if (touch_skill_pressed or Input.is_action_pressed("skill_charge")) and charge_skill_cooldown_left <= 0.0:
		is_charging_skill = true
		charge_hold_time = min(charge_hold_time + delta, charge_skill_hold_time)
		_emit_charge_state_changed()

	if touch_skill_just_released or Input.is_action_just_released("skill_charge"):
		if is_charging_skill and charge_hold_time >= charge_skill_hold_time:
			_activate_charge_skill()
		is_charging_skill = false
		charge_hold_time = 0.0
		touch_skill_just_released = false
		_emit_charge_state_changed()


func _activate_charge_skill() -> void:
	charge_skill_cooldown_left = charge_skill_cooldown
	camera_shake_strength = max(camera_shake_strength, 8.0)
	if has_node("/root/SFXManager"):
		SFXManager.play_charge_pulse()

	if pulse_wave_scene != null:
		var pulse_wave = pulse_wave_scene.instantiate()
		pulse_wave.global_position = global_position
		pulse_wave.radius = charge_skill_radius
		var effect_root := get_tree().current_scene.get_node_or_null("Effects")
		if effect_root == null:
			effect_root = get_tree().current_scene
		effect_root.add_child(pulse_wave)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var distance: float = global_position.distance_to(enemy_node.global_position)
		if distance > charge_skill_radius:
			continue
		var ratio: float = 1.0 - (distance / max(charge_skill_radius, 1.0))
		var burst_damage: int = max(int(round(charge_skill_damage * (0.7 + ratio * 0.9))), 1)
		if enemy.has_method("take_damage"):
			enemy.take_damage(burst_damage)

	charge_hold_time = 0.0
	_emit_charge_state_changed()

func _build_upgrade_choices() -> Array:
	if level >= ENDGAME_LEVEL_THRESHOLD:
		return [
			{
				"id": "recovery_surge",
				"title": "恢复充能",
				"description": "立即恢复 2 点生命"
			},
			{
				"id": "soul_shard",
				"title": "灵魂凝晶",
				"description": "获得 1 个灵魂碎片"
			}
		]

	var pool: Array = [
		{
			"id": "power",
			"title": "火力强化",
			"description": "子弹伤害 +1"
		},
		{
			"id": "rapid_fire",
			"title": "快速射击",
			"description": "射击速度提升"
		},
		{
			"id": "multishot",
			"title": "多重射击",
			"description": "额外发射 1 颗子弹"
		},
		{
			"id": "spread_control",
			"title": "弹道收束",
			"description": "子弹散射范围更小"
		},
		{
			"id": "piercing",
			"title": "穿透弹",
			"description": "子弹额外穿透 1 个敌人"
		},
		{
			"id": "velocity",
			"title": "高速弹头",
			"description": "子弹飞行速度提升"
		},
		{
			"id": "sharpshooter",
			"title": "精准猎手",
			"description": "暴击概率提升"
		},
		{
			"id": "heavy_rounds",
			"title": "重装弹头",
			"description": "子弹存在时间更长"
		},
		{
			"id": "seeker",
			"title": "追猎协议",
			"description": "自动瞄准范围提升"
		},
		{
			"id": "deadly_focus",
			"title": "致命专注",
			"description": "暴击伤害提升"
		},
		{
			"id": "explosive_rounds",
			"title": "爆裂弹头",
			"description": "子弹命中后发生小范围爆炸"
		},
		{
			"id": "blast_radius",
			"title": "震爆扩散",
			"description": "爆炸范围提升"
		},
		{
			"id": "blast_payload",
			"title": "高能装药",
			"description": "爆炸伤害提升"
		},
		{
			"id": "fire_rounds",
			"title": "火焰子弹",
			"description": "子弹附带灼烧效果和火焰粒子"
		},
		{
			"id": "wildfire",
			"title": "余烬蔓延",
			"description": "火焰持续伤害更高，持续时间更久"
		},
		{
			"id": "frost_rounds",
			"title": "寒冰子弹",
			"description": "子弹附带寒霜效果、减速和冰霜粒子"
		},
		{
			"id": "deep_freeze",
			"title": "深寒侵蚀",
			"description": "寒冰减速更强，并附带更高持续伤害"
		},
		{
			"id": "vitality",
			"title": "生命强化",
			"description": "最大生命 +2，并回复 2 点生命"
		},
		{
			"id": "agility",
			"title": "敏捷步伐",
			"description": "移动速度 +25"
		},
		{
			"id": "dash_drive",
			"title": "冲刺驱动",
			"description": "冲刺冷却时间缩短"
		},
		{
			"id": "haste",
			"title": "疾行延展",
			"description": "冲刺持续时间更长"
		},
		{
			"id": "guardian_spark",
			"title": "守护火种",
			"description": "获得 1 次复活机会"
		},
		{
			"id": "battle_trance",
			"title": "战斗直觉",
			"description": "额外提升暴击概率"
		},
		{
			"id": "iron_skin",
			"title": "钢铁皮层",
			"description": "受到伤害降低"
		},
		{
			"id": "dash_burst",
			"title": "爆发冲刺",
			"description": "冲刺速度提升"
		},
		{
			"id": "second_wind",
			"title": "第二呼吸",
			"description": "立即回复 2 点生命"
		},
		{
			"id": "tactical_reload",
			"title": "战术换弹",
			"description": "换弹时间缩短"
		},
		{
			"id": "drum_mag",
			"title": "扩容弹鼓",
			"description": "弹夹容量提升"
		},
		{
			"id": "magnet_core",
			"title": "磁力核心",
			"description": "收集范围提升"
		},
		{
			"id": "vacuum_drive",
			"title": "真空驱动",
			"description": "收集范围和吸附速度提升"
		}
	]

	pool.append_array(weapon.get_upgrade_pool())
	if _is_melee_weapon_active():
		pool = _filter_melee_upgrade_pool(pool)

	pool.shuffle()
	return pool.slice(0, 3)


func _is_melee_weapon_active() -> bool:
	if weapon == null:
		return false
	var active_weapon_id: String = String(weapon.weapon_id)
	return MELEE_WEAPON_IDS.has(active_weapon_id)


func _filter_melee_upgrade_pool(upgrade_pool: Array) -> Array:
	var filtered_pool: Array = []
	for entry in upgrade_pool:
		var upgrade: Dictionary = entry
		var upgrade_id: String = String(upgrade.get("id", ""))
		if MELEE_BLOCKED_UPGRADE_IDS.has(upgrade_id):
			continue
		filtered_pool.append(upgrade)
	return filtered_pool


func _apply_meta_progression() -> void:
	if not has_node("/root/MetaProgression"):
		return

	var modifiers: Dictionary = MetaProgression.build_run_modifiers()
	max_health += int(modifiers.get("max_health_bonus", 0))
	move_speed += float(modifiers.get("move_speed_bonus", 0.0))
	dash_cooldown = max(dash_cooldown - float(modifiers.get("dash_cooldown_bonus", 0.0)), 0.2)
	dash_duration += float(modifiers.get("dash_duration_bonus", 0.0))
	damage_reduction = min(damage_reduction + float(modifiers.get("damage_reduction_bonus", 0.0)), 0.6)
	collect_range += float(modifiers.get("collect_range_bonus", 0.0))
	passive_regen_interval = float(modifiers.get("passive_regen_interval", 0.0))
	passive_regen_timer = passive_regen_interval if passive_regen_interval > 0.0 else 0.0
	kill_heal_chance = float(modifiers.get("kill_heal_chance", 0.0))
	periodic_shield_interval = float(modifiers.get("periodic_shield_interval", 0.0))
	shield_recharge_timer = periodic_shield_interval if periodic_shield_interval > 0.0 else 0.0
	bonus_healing = int(modifiers.get("bonus_healing", 0))
	weapon.fire_rate = max(weapon.fire_rate - float(modifiers.get("fire_rate_bonus", 0.0)), 0.08)
	weapon.reload_time = max(weapon.reload_time - float(modifiers.get("reload_bonus", 0.0)), 0.25)
	weapon.projectile_damage += int(modifiers.get("projectile_damage_bonus", 0))
	weapon.crit_multiplier += float(modifiers.get("crit_multiplier_bonus", 0.0))
	weapon.meta_extra_forward_shots += int(modifiers.get("extra_forward_shots", 0))
	weapon.meta_extra_backward_shots += int(modifiers.get("extra_backward_shots", 0))
	weapon.meta_burst_shots = int(modifiers.get("burst_shots", weapon.meta_burst_shots))
	weapon.meta_burst_damage_multiplier = float(modifiers.get("burst_damage_multiplier", weapon.meta_burst_damage_multiplier))
	weapon.meta_split_on_kill = bool(modifiers.get("split_on_kill", weapon.meta_split_on_kill))
	weapon.meta_split_count = int(modifiers.get("split_count", weapon.meta_split_count))
	_add_shield(int(modifiers.get("starting_shield_charges", 0)), false)
	weapon_updated.emit(weapon.get_weapon_name())


func _update_camera(delta: float) -> void:
	camera_shake_strength = max(camera_shake_strength - delta * 14.0, 0.0)
	if camera_shake_strength > 0.0:
		camera.offset = Vector2(
			randf_range(-camera_shake_strength, camera_shake_strength),
			randf_range(-camera_shake_strength, camera_shake_strength)
		)
	else:
		camera.offset = Vector2.ZERO


func _update_dash_ghost(delta: float) -> void:
	if dash_time_left <= 0.0:
		return
	if dash_ghost_cooldown_left > 0.0:
		return

	dash_ghost_cooldown_left = 0.04
	var ghost: CanvasItem
	if visual is AnimatedSprite2D:
		var ghost_animation := AnimatedSprite2D.new()
		ghost_animation.sprite_frames = visual.sprite_frames
		ghost_animation.animation = visual.animation
		ghost_animation.frame = visual.frame
		ghost_animation.frame_progress = visual.frame_progress
		ghost = ghost_animation
	elif visual is Sprite2D:
		var ghost_sprite := Sprite2D.new()
		ghost_sprite.texture = visual.texture
		ghost_sprite.centered = visual.centered
		ghost_sprite.offset = visual.offset
		ghost = ghost_sprite
	elif visual is Polygon2D:
		var ghost_polygon := Polygon2D.new()
		ghost_polygon.polygon = visual.polygon
		ghost = ghost_polygon
	else:
		return
	ghost.modulate = Color(0.42, 0.87, 1, 0.4)
	ghost.global_position = visual.global_position
	ghost.global_rotation = global_rotation
	ghost.scale = visual.scale * 1.02

	var effect_root: Node = get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.92, 0.18)
	tween.tween_callback(ghost.queue_free)


func _on_weapon_fired(shake_strength: float) -> void:
	camera_shake_strength = max(camera_shake_strength, shake_strength)


func _on_weapon_changed(weapon_name: String) -> void:
	weapon_updated.emit(weapon_name)


func _flash_player_hit() -> void:
	visual.modulate = Color(1, 0.72, 0.72, 1)
	var tween := create_tween()
	tween.tween_property(visual, "modulate", player_normal_modulate, 0.14)


func _show_revival_feedback() -> void:
	camera_shake_strength = max(camera_shake_strength, 4.5)
	visual.modulate = Color(1.0, 0.94, 0.62, 1.0)
	var tween := create_tween()
	for _index in range(5):
		tween.tween_property(visual, "modulate:a", 0.28, 0.05)
		tween.tween_property(visual, "modulate:a", 1.0, 0.05)
	tween.tween_property(visual, "modulate", player_normal_modulate, 0.12)
	_show_popup_text("复活成功", Color(1.0, 0.9, 0.42, 1.0), 1.2)


func _show_damage_text(amount: int) -> void:
	_show_popup_text(str(amount), Color(1, 0.46, 0.46, 1), 1.05)


func _show_popup_text(text: String, color: Color, scale_value: float) -> void:
	if floating_text_scene == null:
		return

	var floating_text = floating_text_scene.instantiate()
	floating_text.global_position = global_position + Vector2(0, -28)
	floating_text.setup(text, color, scale_value)

	var effect_root := get_tree().current_scene.get_node_or_null("Effects")
	if effect_root == null:
		effect_root = get_tree().current_scene
	effect_root.add_child(floating_text)


func _draw() -> void:
	if is_charging_skill:
		var progress: float = clampf(charge_hold_time / max(charge_skill_hold_time, 0.001), 0.0, 1.0)
		var aura_radius: float = lerpf(18.0, charge_skill_radius, progress)
		draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 56, Color(0.48, 0.9, 1.0, 0.55), 4.0)
		draw_circle(Vector2.ZERO, 20.0 + 18.0 * progress, Color(0.34, 0.88, 1.0, 0.12 + progress * 0.18))
		if progress >= 0.98:
			draw_arc(Vector2.ZERO, charge_skill_radius, 0.0, TAU, 64, Color(1.0, 0.85, 0.42, 0.85), 6.0)


func _on_weapon_ammo_display_changed(current_ammo: int, max_ammo: int, is_reloading: bool, reload_progress: float) -> void:
	ammo_text.text = "%d / %d" % [current_ammo, max_ammo]
	reload_bar.value = reload_progress if is_reloading else float(current_ammo) / max(float(max_ammo), 1.0)
	reload_bar.modulate = Color(1.0, 0.67, 0.3, 1) if is_reloading else Color(0.8, 0.95, 0.76, 1)


func _update_health_bar() -> void:
	health_bar.max_value = float(max_health)
	health_bar.value = float(health)


func _on_health_changed(_current_health: int, _maximum_health: int) -> void:
	_update_health_bar()


func _update_status_display_position() -> void:
	health_bar.global_position = global_position + Vector2(-38, -88)
	ammo_text.global_position = global_position + Vector2(-26, -64)
	reload_bar.global_position = global_position + Vector2(-34, -44)


func _setup_health_bar_style() -> void:
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", _build_bar_style(Color(0.12, 0.16, 0.22, 0.9), Color(0.3, 0.45, 0.56, 0.9)))
	health_bar.add_theme_stylebox_override("fill", _build_bar_style(Color(0.3, 0.88, 0.56, 1), Color(0.9, 1, 0.93, 0.9)))


func _build_bar_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	return style


func _emit_charge_state_changed() -> void:
	var charge_progress: float = clampf(charge_hold_time / max(charge_skill_hold_time, 0.001), 0.0, 1.0)
	charge_state_changed.emit(charge_skill_cooldown_left, charge_skill_cooldown, is_charging_skill, charge_progress)


func add_extra_lives(amount: int) -> void:
	extra_lives = max(extra_lives + amount, 0)
	extra_lives_changed.emit(extra_lives)


func register_enemy_kill() -> void:
	if kill_heal_chance <= 0.0:
		return
	if randf() <= kill_heal_chance:
		heal(1)
		_show_popup_text("汲取", Color(0.58, 1.0, 0.72, 1.0), 0.95)


func _add_shield(amount: int, show_popup := true) -> void:
	if amount <= 0:
		return
	var previous_shields: int = shield_charges
	shield_charges = min(shield_charges + amount, max_shield_charges)
	if show_popup and shield_charges > previous_shields:
		_show_popup_text("护盾就绪", Color(0.58, 0.96, 1.0, 1.0), 0.95)


func _get_experience_needed_for_level(current_level: int) -> int:
	if current_level < ENDGAME_LEVEL_THRESHOLD:
		if current_level <= 5:
			return 4 + current_level * 2
		if current_level <= 15:
			return 12 + int(round(pow(float(current_level - 4), 1.18) * 1.7))
		return 28 + int(round(pow(float(current_level - 14), 1.24) * 2.6))
	return max(12 + int(round(pow(float(current_level - ENDGAME_LEVEL_THRESHOLD + 1), 1.35) * 2.4)), 12)


func _clear_non_boss_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_in_group("bosses"):
			continue
		if enemy.has_method("queue_free"):
			enemy.queue_free()

	var enemy_projectiles := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if enemy_projectiles != null:
		for projectile in enemy_projectiles.get_children():
			projectile.queue_free()


func collect_all_experience() -> void:
	var pickup_root := get_tree().current_scene.get_node_or_null("Pickups")
	if pickup_root == null:
		return
	for pickup in pickup_root.get_children():
		if pickup.has_method("magnetize_to"):
			pickup.magnetize_to(self)
	_show_popup_text("经验吸附", Color(0.58, 0.96, 1.0, 1.0), 0.95)


func clear_visible_enemies() -> void:
	var active_camera: Camera2D = camera
	if active_camera == null:
		active_camera = get_viewport().get_camera_2d()
	var center: Vector2 = global_position
	var half_size := get_viewport_rect().size * 0.5
	if active_camera != null:
		center = active_camera.get_screen_center_position()
		half_size = get_viewport_rect().size * active_camera.zoom * 0.5

	var cleared_count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_in_group("bosses"):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var offset: Vector2 = enemy_node.global_position - center
		if abs(offset.x) <= half_size.x and abs(offset.y) <= half_size.y:
			if enemy.has_method("take_damage"):
				var enemy_health: int = int(enemy.get("health"))
				enemy.call("take_damage", max(enemy_health, 9999))
				cleared_count += 1
			elif enemy.has_signal("defeated"):
				enemy.emit_signal("defeated")
				enemy.queue_free()
				cleared_count += 1
			elif enemy.has_method("queue_free"):
				enemy.queue_free()
				cleared_count += 1

	var enemy_projectiles := get_tree().current_scene.get_node_or_null("EnemyProjectiles")
	if enemy_projectiles != null:
		for projectile in enemy_projectiles.get_children():
			if not (projectile is Node2D):
				continue
			var projectile_node := projectile as Node2D
			var offset: Vector2 = projectile_node.global_position - center
			if abs(offset.x) <= half_size.x and abs(offset.y) <= half_size.y:
				projectile.queue_free()

	_show_popup_text("炸弹清场 %d" % cleared_count, Color(1.0, 0.72, 0.42, 1.0), 1.0)


func set_touch_move_vector(vector: Vector2) -> void:
	touch_move_vector = vector.limit_length(1.0)


func set_touch_aim_state(active: bool, screen_position: Vector2) -> void:
	touch_aim_active = active
	touch_aim_screen_position = screen_position


func request_touch_dash() -> void:
	touch_dash_requested = true


func request_touch_reload() -> void:
	touch_reload_requested = true


func set_touch_skill_pressed(pressed: bool) -> void:
	if touch_skill_pressed and not pressed:
		touch_skill_just_released = true
	touch_skill_pressed = pressed


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position
