extends CanvasLayer


signal restart_requested
signal menu_requested
signal upgrade_selected(upgrade_id: String)
signal upgrade_refresh_requested
signal supply_selected(supply_id: String)
signal chest_reward_selected(reward_id: String)
signal force_spawn_requested


@onready var health_label = $BottomBar/Margin/HBox/HealthLabel
@onready var force_spawn_button = $ForceSpawnButton
@onready var level_label = $BottomBar/Margin/HBox/LevelLabel
@onready var wave_progress_bar = $TopCenterPanel/VBox/WaveProgressBar
@onready var wave_label = $TopCenterPanel/VBox/WaveLabel
@onready var enemy_label = $BottomBar/Margin/HBox/EnemyLabel
@onready var timer_label = $TopCenterPanel/VBox/TimerLabel
@onready var weapon_label = $BottomBar/Margin/HBox/WeaponLabel
@onready var ammo_label = $BottomBar/Margin/HBox/AmmoLabel
@onready var revive_label = $BottomBar/Margin/HBox/ReviveLabel
@onready var skill_label = $BottomBar/Margin/HBox/SkillLabel
@onready var experience_bar = $BottomBar/Margin/HBox/ExperienceWrap/ExperienceBar
@onready var boss_panel = $BossPanel
@onready var boss_name_label = $BossPanel/BossNameLabel
@onready var boss_health_bar = $BossPanel/BossHealthBar
@onready var announcement_label = $AnnouncementLabel
@onready var game_over_panel = $GameOverPanel
@onready var game_over_overlay = $GameOverPanel/Overlay
@onready var game_over_title = $GameOverPanel/CenterWrap/Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var game_over_label = $GameOverPanel/CenterWrap/Panel/MarginContainer/VBoxContainer/GameOverLabel
@onready var retry_button = $GameOverPanel/CenterWrap/Panel/MarginContainer/VBoxContainer/RetryButton
@onready var menu_button = $GameOverPanel/CenterWrap/Panel/MarginContainer/VBoxContainer/MenuButton
@onready var upgrade_panel = $UpgradePanel
@onready var upgrade_refresh_button = $UpgradePanel/Panel/VBoxContainer/RefreshButton
@onready var upgrade_buttons = [
	$UpgradePanel/Panel/VBoxContainer/OptionOne,
	$UpgradePanel/Panel/VBoxContainer/OptionTwo,
	$UpgradePanel/Panel/VBoxContainer/OptionThree
]
@onready var supply_panel = $SupplyPanel
@onready var supply_buttons = [
	$SupplyPanel/Panel/VBoxContainer/OptionOne,
	$SupplyPanel/Panel/VBoxContainer/OptionTwo,
	$SupplyPanel/Panel/VBoxContainer/OptionThree
]
@onready var chest_panel = $ChestPanel
@onready var chest_buttons = [
	$ChestPanel/Panel/VBoxContainer/OptionOne,
	$ChestPanel/Panel/VBoxContainer/OptionTwo,
	$ChestPanel/Panel/VBoxContainer/OptionThree
]


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	force_spawn_button.pressed.connect(_on_force_spawn_button_pressed)
	upgrade_refresh_button.pressed.connect(_on_upgrade_refresh_button_pressed)
	game_over_panel.visible = false
	upgrade_panel.visible = false
	supply_panel.visible = false
	chest_panel.visible = false
	boss_panel.visible = false
	announcement_label.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	for button in upgrade_buttons:
		button.pressed.connect(_on_upgrade_button_pressed.bind(button))
	for button in supply_buttons:
		button.pressed.connect(_on_supply_button_pressed.bind(button))
	for button in chest_buttons:
		button.pressed.connect(_on_chest_button_pressed.bind(button))


func _unhandled_input(event: InputEvent) -> void:
	if game_over_panel.visible and event.is_action_pressed("dash"):
		restart_requested.emit()


func set_health(current_health: int, maximum_health: int) -> void:
	health_label.text = "生命 %d / %d" % [current_health, maximum_health]


func set_wave(wave: int) -> void:
	wave_label.text = "第 %d 波" % wave


func set_wave_progress(progress: float, wave: int, final_wave: int) -> void:
	wave_progress_bar.max_value = 1.0
	wave_progress_bar.value = clampf(progress, 0.0, 1.0)
	wave_label.text = "第 %d 波 / 共 %d 波" % [wave, final_wave]


func set_enemy_count(count: int) -> void:
	enemy_label.text = "敌人 %d" % count


func set_weapon(weapon_name: String) -> void:
	weapon_label.text = weapon_name


func set_ammo(current_ammo: int, max_ammo: int, is_reloading: bool, reload_progress: float) -> void:
	if max_ammo <= 0:
		ammo_label.text = "近战武器"
		return
	if is_reloading:
		ammo_label.text = "换弹中 %d%%" % int(round(reload_progress * 100.0))
	else:
		ammo_label.text = "弹药 %d / %d" % [current_ammo, max_ammo]


func set_extra_lives(current_extra_lives: int) -> void:
	revive_label.text = "复活 %d" % current_extra_lives


func set_charge_skill(cooldown_left: float, max_cooldown: float, is_charging: bool, charge_progress: float) -> void:
	if is_charging:
		skill_label.text = "脉冲蓄力 %d%%" % int(round(charge_progress * 100.0))
	elif cooldown_left > 0.0:
		var ratio: float = 1.0 - (cooldown_left / max(max_cooldown, 0.001))
		skill_label.text = "脉冲冷却 %d%%" % int(round(ratio * 100.0))
	else:
		skill_label.text = "脉冲 就绪"


func set_experience(current_experience: int, experience_to_next_level: int, level: int) -> void:
	level_label.text = "等级 %d" % level
	experience_bar.max_value = experience_to_next_level
	experience_bar.value = current_experience


func set_timer(time_seconds: float) -> void:
	timer_label.text = format_time(time_seconds)


func set_objective(text: String) -> void:
	return


func show_boss_bar(name_text: String, current_health: int, maximum_health: int) -> void:
	boss_panel.visible = true
	boss_name_label.text = name_text
	boss_health_bar.max_value = float(maximum_health)
	boss_health_bar.value = float(current_health)


func update_boss_health(current_health: int, maximum_health: int) -> void:
	if not boss_panel.visible:
		return
	boss_health_bar.max_value = float(maximum_health)
	boss_health_bar.value = float(current_health)


func hide_boss_bar() -> void:
	boss_panel.visible = false


func show_announcement(text: String, color := Color(1, 0.86, 0.52, 1)) -> void:
	announcement_label.visible = true
	announcement_label.modulate = Color(1, 1, 1, 1)
	announcement_label.text = text
	announcement_label.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_interval(1.1)
	tween.tween_property(announcement_label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		announcement_label.visible = false
		announcement_label.modulate.a = 1.0
	)


func show_upgrade_choices(level: int, choices: Array) -> void:
	_show_centered_popup(upgrade_panel)
	$UpgradePanel/Panel/VBoxContainer/TitleLabel.text = "等级 %d 强化" % level

	for index in range(upgrade_buttons.size()):
		var button: Button = upgrade_buttons[index]
		if index < choices.size():
			var choice: Dictionary = choices[index]
			button.visible = true
			button.disabled = false
			button.text = "%s\n%s" % [choice["title"], choice["description"]]
			button.set_meta("upgrade_id", choice["id"])
		else:
			button.visible = false
			button.set_meta("upgrade_id", "")


func hide_upgrade_choices() -> void:
	upgrade_panel.visible = false
	for button in upgrade_buttons:
		button.visible = true


func show_supply_choices(wave: int, choices: Array) -> void:
	_show_centered_popup(supply_panel)
	$SupplyPanel/Panel/VBoxContainer/TitleLabel.text = "第 %d 波补给" % wave

	for index in range(supply_buttons.size()):
		var button: Button = supply_buttons[index]
		var choice: Dictionary = choices[index]
		button.text = "%s\n%s" % [choice["title"], choice["description"]]
		button.set_meta("supply_id", choice["id"])


func hide_supply_choices() -> void:
	supply_panel.visible = false


func show_chest_rewards(choices: Array) -> void:
	_show_centered_popup(chest_panel)
	for index in range(chest_buttons.size()):
		var button: Button = chest_buttons[index]
		var choice: Dictionary = choices[index]
		button.text = "%s\n%s" % [choice["title"], choice["description"]]
		button.set_meta("reward_id", choice["id"])


func hide_chest_rewards() -> void:
	chest_panel.visible = false


func show_game_over(wave: int, is_victory: bool, summary: String) -> void:
	game_over_title.text = "胜利" if is_victory else "战斗结束"
	game_over_label.text = "%s\n%s" % [
		"你击败了最终首领" if is_victory else "你坚持到了第 %d 波" % wave,
		summary
	]
	game_over_overlay.color = Color(0.02, 0.03, 0.05, 0.58) if is_victory else Color(0.02, 0.03, 0.05, 0.76)
	_show_centered_popup(game_over_panel)
	hide_boss_bar()


func _on_retry_button_pressed() -> void:
	restart_requested.emit()


func _on_upgrade_button_pressed(button: Button) -> void:
	upgrade_selected.emit(String(button.get_meta("upgrade_id", "")))


func _on_upgrade_refresh_button_pressed() -> void:
	upgrade_refresh_requested.emit()


func _on_menu_button_pressed() -> void:
	menu_requested.emit()


func _on_force_spawn_button_pressed() -> void:
	force_spawn_requested.emit()


func _on_supply_button_pressed(button: Button) -> void:
	supply_selected.emit(String(button.get_meta("supply_id", "")))


func _on_chest_button_pressed(button: Button) -> void:
	chest_reward_selected.emit(String(button.get_meta("reward_id", "")))


func format_time(time_seconds: float) -> String:
	var total_seconds := int(floor(time_seconds))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _show_centered_popup(popup: Control) -> void:
	popup.visible = true
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.offset_left = 0.0
	popup.offset_top = 0.0
	popup.offset_right = 0.0
	popup.offset_bottom = 0.0
	for child in popup.get_children():
		if child is Control:
			var child_control := child as Control
			child_control.set_anchors_preset(Control.PRESET_FULL_RECT)
			child_control.offset_left = 0.0
			child_control.offset_top = 0.0
			child_control.offset_right = 0.0
			child_control.offset_bottom = 0.0
	popup.update_minimum_size()
