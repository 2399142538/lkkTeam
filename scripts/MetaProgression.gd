extends Node


const SAVE_PATH := "user://meta_progression.save"

const BRANCH_DEFINITIONS := {
	"survival": {
		"title": "生存",
		"order": 0,
		"accent": Color(0.62, 0.95, 0.8, 1),
		"panel_bg": Color(0.08, 0.16, 0.14, 0.94),
		"panel_border": Color(0.48, 0.9, 0.77, 0.92)
	},
	"mobility": {
		"title": "机动",
		"order": 1,
		"accent": Color(0.69, 0.86, 1, 1),
		"panel_bg": Color(0.08, 0.13, 0.19, 0.94),
		"panel_border": Color(0.5, 0.75, 1, 0.92)
	},
	"offense": {
		"title": "火力",
		"order": 2,
		"accent": Color(1, 0.82, 0.54, 1),
		"panel_bg": Color(0.18, 0.12, 0.06, 0.94),
		"panel_border": Color(1, 0.75, 0.34, 0.94)
	}
}

const UPGRADE_DEFINITIONS := {
	"max_health_1": {
		"title": "体魄强化 I",
		"description": "初始最大生命 +2",
		"cost": 3,
		"max_level": 1,
		"branch": "survival",
		"tier": 1
	},
	"max_health_2": {
		"title": "体魄强化 II",
		"description": "初始最大生命再 +3",
		"cost": 6,
		"max_level": 1,
		"branch": "survival",
		"tier": 2,
		"requires": "max_health_1"
	},
	"max_health_3": {
		"title": "不屈体魄 III",
		"description": "初始最大生命再 +4，并获得 1 点减伤",
		"cost": 9,
		"max_level": 1,
		"branch": "survival",
		"tier": 3,
		"requires": "max_health_2"
	},
	"regen_1": {
		"title": "再生脉冲 I",
		"description": "每 20 秒恢复 1 点生命",
		"cost": 4,
		"max_level": 1,
		"branch": "survival",
		"tier": 1
	},
	"regen_2": {
		"title": "收割回春 II",
		"description": "击杀敌人有 2% 概率恢复 1 点生命",
		"cost": 7,
		"max_level": 1,
		"branch": "survival",
		"tier": 2,
		"requires": "regen_1"
	},
	"regen_3": {
		"title": "庇护屏障 III",
		"description": "每 60 秒获得 1 层护盾，护盾可抵消一次伤害",
		"cost": 11,
		"max_level": 1,
		"branch": "survival",
		"tier": 3,
		"requires": "regen_2"
	},
	"survival_ultimate": {
		"title": "永生庇护",
		"description": "需要两条生存路线都点满。开局获得 1 层护盾，治疗额外 +1，定时恢复缩短到 15 秒，击杀回复概率提升。",
		"cost": 17,
		"max_level": 1,
		"branch": "survival",
		"tier": 4,
		"requires_all": ["max_health_3", "regen_3"]
	},
	"move_speed_1": {
		"title": "迅捷步伐 I",
		"description": "初始移动速度 +20",
		"cost": 3,
		"max_level": 1,
		"branch": "mobility",
		"tier": 1
	},
	"move_speed_2": {
		"title": "迅捷步伐 II",
		"description": "初始移动速度再 +28",
		"cost": 6,
		"max_level": 1,
		"branch": "mobility",
		"tier": 2,
		"requires": "move_speed_1"
	},
	"move_speed_3": {
		"title": "残影步幅 III",
		"description": "初始移动速度再 +36，收集范围 +25",
		"cost": 9,
		"max_level": 1,
		"branch": "mobility",
		"tier": 3,
		"requires": "move_speed_2"
	},
	"mobility_ultimate": {
		"title": "时轨超驰",
		"description": "需要两条机动路线都点满。开局获得大幅移速、冲刺冷却缩短与冲刺时长提升。",
		"cost": 16,
		"max_level": 1,
		"branch": "mobility",
		"tier": 4,
		"requires_all": ["move_speed_3", "dash_3"]
	},
	"fire_rate_1": {
		"title": "扳机训练 I",
		"description": "初始射速提升",
		"cost": 4,
		"max_level": 1,
		"branch": "offense",
		"tier": 1
	},
	"fire_rate_2": {
		"title": "扳机训练 II",
		"description": "初始射速进一步提升",
		"cost": 7,
		"max_level": 1,
		"branch": "offense",
		"tier": 2,
		"requires": "fire_rate_1"
	},
	"fire_rate_3": {
		"title": "极限扳机 III",
		"description": "初始射速再提升，并缩短换弹时间",
		"cost": 10,
		"max_level": 1,
		"branch": "offense",
		"tier": 3,
		"requires": "fire_rate_2"
	},
	"damage_1": {
		"title": "火力校准 I",
		"description": "初始子弹伤害 +1",
		"cost": 5,
		"max_level": 1,
		"branch": "offense",
		"tier": 1
	},
	"damage_2": {
		"title": "火力校准 II",
		"description": "初始子弹伤害再 +1",
		"cost": 8,
		"max_level": 1,
		"branch": "offense",
		"tier": 2,
		"requires": "damage_1"
	},
	"damage_3": {
		"title": "终端火力 III",
		"description": "初始子弹伤害再 +2，暴击伤害提升",
		"cost": 11,
		"max_level": 1,
		"branch": "offense",
		"tier": 3,
		"requires": "damage_2"
	},
	"ballistics_1": {
		"title": "镜像弹道 I",
		"description": "开局获得前后追加弹道",
		"cost": 6,
		"max_level": 1,
		"branch": "offense",
		"tier": 1
	},
	"ballistics_2": {
		"title": "双重齐射 II",
		"description": "每次射击会追加第二波齐射，单发伤害 -20%",
		"cost": 9,
		"max_level": 1,
		"branch": "offense",
		"tier": 2,
		"requires": "ballistics_1"
	},
	"ballistics_3": {
		"title": "裂变弹芯 III",
		"description": "子弹击杀敌人后分裂成 5 枚小子弹并平均散开",
		"cost": 12,
		"max_level": 1,
		"branch": "offense",
		"tier": 3,
		"requires": "ballistics_2"
	},
	"offense_ultimate": {
		"title": "湮灭超载",
		"description": "需要两条火力路线都点满。开局获得更高伤害、射速与暴击伤害。",
		"cost": 18,
		"max_level": 1,
		"branch": "offense",
		"tier": 4,
		"requires_all": ["fire_rate_3", "damage_3"]
	},
	"dash_1": {
		"title": "机动模块 I",
		"description": "初始冲刺冷却缩短",
		"cost": 4,
		"max_level": 1,
		"branch": "mobility",
		"tier": 1
	},
	"dash_2": {
		"title": "机动模块 II",
		"description": "初始冲刺冷却进一步缩短",
		"cost": 7,
		"max_level": 1,
		"branch": "mobility",
		"tier": 2,
		"requires": "dash_1"
	},
	"dash_3": {
		"title": "相位驱动 III",
		"description": "初始冲刺冷却再缩短，冲刺时长略增",
		"cost": 10,
		"max_level": 1,
		"branch": "mobility",
		"tier": 3,
		"requires": "dash_2"
	}
}

var soul_shards := 0
var upgrades := {}
var selected_weapon := "pistol"
var selected_stage := "ruins"
var unlocked_stage_ids: Array[String] = ["ruins"]


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_reset_defaults()
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_reset_defaults()
		return

	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		_reset_defaults()
		return

	soul_shards = int(data.get("soul_shards", 0))
	upgrades = data.get("upgrades", {}).duplicate()
	selected_weapon = String(data.get("selected_weapon", "pistol"))
	selected_stage = String(data.get("selected_stage", "ruins"))
	unlocked_stage_ids.clear()
	for stage_id in data.get("unlocked_stage_ids", ["ruins"]):
		unlocked_stage_ids.append(String(stage_id))
	if unlocked_stage_ids.is_empty():
		unlocked_stage_ids.append("ruins")
	_fill_missing_upgrades()


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_var({
		"soul_shards": soul_shards,
		"upgrades": upgrades,
		"selected_weapon": selected_weapon,
		"selected_stage": selected_stage,
		"unlocked_stage_ids": unlocked_stage_ids
	})


func add_soul_shards(amount: int) -> void:
	soul_shards = max(soul_shards + amount, 0)
	save_data()


func can_buy_upgrade(upgrade_id: String) -> bool:
	if not UPGRADE_DEFINITIONS.has(upgrade_id):
		return false

	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	var current_level := int(upgrades.get(upgrade_id, 0))
	if definition.has("requires") and get_upgrade_level(String(definition["requires"])) <= 0:
		return false
	if definition.has("requires_all"):
		for require_id in definition["requires_all"]:
			if get_upgrade_level(String(require_id)) <= 0:
				return false
	return current_level < int(definition["max_level"]) and soul_shards >= int(definition["cost"])


func buy_upgrade(upgrade_id: String) -> bool:
	if not can_buy_upgrade(upgrade_id):
		return false

	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	soul_shards -= int(definition["cost"])
	upgrades[upgrade_id] = int(upgrades.get(upgrade_id, 0)) + 1
	save_data()
	return true


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_upgrade_definitions() -> Dictionary:
	return UPGRADE_DEFINITIONS


func get_branch_definitions() -> Dictionary:
	return BRANCH_DEFINITIONS


func get_required_ids(upgrade_id: String) -> Array[String]:
	if not UPGRADE_DEFINITIONS.has(upgrade_id):
		return []
	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	if definition.has("requires_all"):
		var result_all: Array[String] = []
		for require_id in definition["requires_all"]:
			result_all.append(String(require_id))
		return result_all
	if definition.has("requires"):
		return [String(definition["requires"])]
	return []


func get_requirement_text(upgrade_id: String) -> String:
	var names: Array[String] = []
	for require_id in get_required_ids(upgrade_id):
		if UPGRADE_DEFINITIONS.has(require_id):
			names.append(String(UPGRADE_DEFINITIONS[require_id]["title"]))
	return " + ".join(names)


func reset_progress() -> void:
	_reset_defaults()
	save_data()


func set_selected_weapon(weapon_id: String) -> void:
	selected_weapon = weapon_id
	save_data()


func set_selected_stage(stage_id: String) -> void:
	if not is_stage_unlocked(stage_id):
		return
	selected_stage = stage_id
	save_data()


func is_stage_unlocked(stage_id: String) -> bool:
	return unlocked_stage_ids.has(stage_id)


func unlock_stage(stage_id: String) -> bool:
	if unlocked_stage_ids.has(stage_id):
		return false
	unlocked_stage_ids.append(stage_id)
	save_data()
	return true


func build_run_modifiers() -> Dictionary:
	var modifiers := {
		"max_health_bonus": 0,
		"move_speed_bonus": 0.0,
		"fire_rate_bonus": 0.0,
		"projectile_damage_bonus": 0,
		"dash_cooldown_bonus": 0.0,
		"damage_reduction_bonus": 0.0,
		"reload_bonus": 0.0,
		"collect_range_bonus": 0.0,
		"crit_multiplier_bonus": 0.0,
		"dash_duration_bonus": 0.0,
		"extra_forward_shots": 0,
		"extra_backward_shots": 0,
		"burst_shots": 1,
		"burst_damage_multiplier": 1.0,
		"split_on_kill": false,
		"split_count": 0,
		"passive_regen_interval": 0.0,
		"kill_heal_chance": 0.0,
		"periodic_shield_interval": 0.0,
		"starting_shield_charges": 0,
		"bonus_healing": 0
	}

	if get_upgrade_level("max_health_1") > 0:
		modifiers["max_health_bonus"] += 2
	if get_upgrade_level("max_health_2") > 0:
		modifiers["max_health_bonus"] += 3
	if get_upgrade_level("max_health_3") > 0:
		modifiers["max_health_bonus"] += 4
		modifiers["damage_reduction_bonus"] += 0.05
	if get_upgrade_level("regen_1") > 0:
		modifiers["passive_regen_interval"] = 20.0
	if get_upgrade_level("regen_2") > 0:
		modifiers["kill_heal_chance"] += 0.02
	if get_upgrade_level("regen_3") > 0:
		modifiers["periodic_shield_interval"] = 60.0
	if get_upgrade_level("survival_ultimate") > 0:
		modifiers["starting_shield_charges"] += 1
		modifiers["bonus_healing"] += 1
		modifiers["kill_heal_chance"] += 0.04
		if float(modifiers["passive_regen_interval"]) <= 0.0 or float(modifiers["passive_regen_interval"]) > 15.0:
			modifiers["passive_regen_interval"] = 15.0
	if get_upgrade_level("move_speed_1") > 0:
		modifiers["move_speed_bonus"] += 20.0
	if get_upgrade_level("move_speed_2") > 0:
		modifiers["move_speed_bonus"] += 28.0
	if get_upgrade_level("move_speed_3") > 0:
		modifiers["move_speed_bonus"] += 36.0
		modifiers["collect_range_bonus"] += 25.0
	if get_upgrade_level("mobility_ultimate") > 0:
		modifiers["move_speed_bonus"] += 45.0
		modifiers["dash_cooldown_bonus"] += 0.12
		modifiers["dash_duration_bonus"] += 0.08
	if get_upgrade_level("fire_rate_1") > 0:
		modifiers["fire_rate_bonus"] += 0.03
	if get_upgrade_level("fire_rate_2") > 0:
		modifiers["fire_rate_bonus"] += 0.04
	if get_upgrade_level("fire_rate_3") > 0:
		modifiers["fire_rate_bonus"] += 0.05
		modifiers["reload_bonus"] += 0.1
	if get_upgrade_level("offense_ultimate") > 0:
		modifiers["fire_rate_bonus"] += 0.08
		modifiers["projectile_damage_bonus"] += 2
		modifiers["crit_multiplier_bonus"] += 0.2
	if get_upgrade_level("damage_1") > 0:
		modifiers["projectile_damage_bonus"] += 1
	if get_upgrade_level("damage_2") > 0:
		modifiers["projectile_damage_bonus"] += 1
	if get_upgrade_level("damage_3") > 0:
		modifiers["projectile_damage_bonus"] += 2
		modifiers["crit_multiplier_bonus"] += 0.2
	if get_upgrade_level("ballistics_1") > 0:
		modifiers["extra_forward_shots"] += 1
		modifiers["extra_backward_shots"] += 1
	if get_upgrade_level("ballistics_2") > 0:
		modifiers["burst_shots"] = 2
		modifiers["burst_damage_multiplier"] = 0.8
	if get_upgrade_level("ballistics_3") > 0:
		modifiers["split_on_kill"] = true
		modifiers["split_count"] = 5
	if get_upgrade_level("dash_1") > 0:
		modifiers["dash_cooldown_bonus"] += 0.12
	if get_upgrade_level("dash_2") > 0:
		modifiers["dash_cooldown_bonus"] += 0.14
	if get_upgrade_level("dash_3") > 0:
		modifiers["dash_cooldown_bonus"] += 0.18
		modifiers["dash_duration_bonus"] += 0.03

	return modifiers


func _reset_defaults() -> void:
	soul_shards = 0
	upgrades = {}
	selected_weapon = "pistol"
	selected_stage = "ruins"
	unlocked_stage_ids = ["ruins"]
	_fill_missing_upgrades()


func _fill_missing_upgrades() -> void:
	for upgrade_id in UPGRADE_DEFINITIONS.keys():
		if not upgrades.has(upgrade_id):
			upgrades[upgrade_id] = 0
