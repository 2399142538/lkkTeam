extends Control

const SkillTreeConnectorScript = preload("res://scripts/SkillTreeConnector.gd")
const SkillUltimateConnectorScript = preload("res://scripts/SkillUltimateConnector.gd")

const WEAPON_INFO := {
	"pistol": {
		"title": "标准手枪",
		"description": "平衡稳定，适合起步。射程远，节奏稳。"
	},
	"shotgun": {
		"title": "霰弹枪",
		"description": "近距离爆发最高，贴脸清怪和压 Boss 都很强。"
	},
	"arc": {
		"title": "电弧法杖",
		"description": "自动锁敌连锁，群怪处理中后期非常稳定。"
	},
	"flame": {
		"title": "火焰喷射器",
		"description": "覆盖面大、射速高，适合持续压场。"
	},
	"sword": {
		"title": "符文长剑",
		"description": "近战连斩型武器，适合贴身切入和暴击爆发。"
	},
	"spear": {
		"title": "猎龙长枪",
		"description": "更长的近战攻击范围，正面压制和突刺都很强。"
	}
}

const STAGE_INFO := [
	{
		"id": "ruins",
		"title": "遗迹试炼场",
		"description": "破碎遗迹中的标准试炼。路线开阔，适合稳定 build 和熟悉节奏。",
		"hint": "推荐难度：标准"
	},
	{
		"id": "factory",
		"title": "钢铁工场",
		"description": "密集轨道与狭长通路更容易形成压迫，适合测试刷怪强度和机动性。",
		"hint": "推荐难度：进阶"
	},
	{
		"id": "sanctum",
		"title": "星环圣所",
		"description": "中央高压区域更考验走位和爆发输出，适合后期 build 检查。",
		"hint": "推荐难度：高压"
	}
]

@onready var shard_label = $ShardPanel/ShardLabel
@onready var shard_panel = $ShardPanel
@onready var help_button = $Root/TopBar/HelpButton
@onready var selected_weapon_label = $CenterPanel/Panel/CenterVBox/SelectedWeaponLabel
@onready var selected_stage_label = $CenterPanel/Panel/CenterVBox/SelectedStageLabel
@onready var start_button = $CenterPanel/Panel/CenterVBox/ButtonRow/StartButton
@onready var reset_button = $CenterPanel/Panel/CenterVBox/ButtonRow/ResetButton
@onready var skill_button = $CenterPanel/Panel/CenterVBox/SkillButton

@onready var help_popup = $HelpPopup
@onready var help_close_button = $HelpPopup/Panel/VBox/CloseButton

@onready var stage_popup = $StagePopup
@onready var stage_close_button = $StagePopup/Panel/VBox/HeaderRow/CloseButton
@onready var stage_preview = $StagePopup/Panel/VBox/PreviewPanel/StagePreview
@onready var stage_name_label = $StagePopup/Panel/VBox/StageNameLabel
@onready var stage_desc_label = $StagePopup/Panel/VBox/StageDescLabel
@onready var stage_hint_label = $StagePopup/Panel/VBox/StageHintLabel
@onready var prev_stage_button = $StagePopup/Panel/VBox/StageButtonRow/PrevStageButton
@onready var next_stage_button = $StagePopup/Panel/VBox/StageButtonRow/NextStageButton
@onready var confirm_stage_button = $StagePopup/Panel/VBox/ConfirmStageButton

@onready var skill_popup = $SkillPopup
@onready var skill_close_button = $SkillPopup/Panel/VBox/HeaderRow/CloseButton
@onready var skill_scroll = $SkillPopup/Panel/VBox/ScrollContainer
@onready var branch_blocks = {
	"survival": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/SurvivalBlock,
	"mobility": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/MobilityBlock,
	"offense": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/OffenseBlock
}
@onready var branch_titles = {
	"survival": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/SurvivalBlock/SurvivalBranch/SurvivalTitle,
	"mobility": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/MobilityBlock/MobilityBranch/MobilityTitle,
	"offense": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/OffenseBlock/OffenseBranch/OffenseTitle
}
@onready var tree_branches = {
	"survival": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/SurvivalBlock/SurvivalBranch/SurvivalTree,
	"mobility": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/MobilityBlock/MobilityBranch/MobilityTree,
	"offense": $SkillPopup/Panel/VBox/ScrollContainer/SkillGraph/OffenseBlock/OffenseBranch/OffenseTree
}

@onready var weapon_popup = $WeaponPopup
@onready var weapon_close_button = $WeaponPopup/Panel/VBox/HeaderRow/CloseButton
@onready var weapon_desc_label = $WeaponPopup/Panel/VBox/WeaponDescLabel
@onready var confirm_weapon_button = $WeaponPopup/Panel/VBox/ConfirmButton
@onready var weapon_buttons = {
	"pistol": $WeaponPopup/Panel/VBox/WeaponButtons/PistolButton,
	"shotgun": $WeaponPopup/Panel/VBox/WeaponButtons/ShotgunButton,
	"arc": $WeaponPopup/Panel/VBox/WeaponButtons/ArcButton,
	"flame": $WeaponPopup/Panel/VBox/WeaponButtons/FlameButton,
	"sword": $WeaponPopup/Panel/VBox/WeaponButtons/SwordButton,
	"spear": $WeaponPopup/Panel/VBox/WeaponButtons/SpearButton
}

var is_dragging_skill_tree := false
var last_drag_mouse_position := Vector2.ZERO
var drag_start_mouse_position := Vector2.ZERO
var drag_started_on_skill_tree := false
var shard_click_count := 0
var shard_click_timer := 0.0
var stage_index := 0


func _ready() -> void:
	help_button.pressed.connect(func() -> void: _show_centered_popup(help_popup))
	help_close_button.pressed.connect(func() -> void: help_popup.visible = false)
	stage_close_button.pressed.connect(func() -> void: stage_popup.visible = false)
	prev_stage_button.pressed.connect(_on_prev_stage_pressed)
	next_stage_button.pressed.connect(_on_next_stage_pressed)
	confirm_stage_button.pressed.connect(_on_confirm_stage_pressed)
	skill_button.pressed.connect(func() -> void: _show_centered_popup(skill_popup))
	skill_close_button.pressed.connect(func() -> void: skill_popup.visible = false)
	start_button.pressed.connect(func() -> void: _open_stage_popup())
	weapon_close_button.pressed.connect(func() -> void: weapon_popup.visible = false)
	confirm_weapon_button.pressed.connect(_on_confirm_weapon_pressed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	skill_scroll.gui_input.connect(_on_skill_scroll_gui_input)
	shard_panel.gui_input.connect(_on_shard_panel_gui_input)
	for weapon_id in weapon_buttons.keys():
		weapon_buttons[weapon_id].pressed.connect(_on_weapon_selected.bind(weapon_id))

	help_popup.visible = false
	stage_popup.visible = false
	skill_popup.visible = false
	weapon_popup.visible = false
	_refresh()


func _refresh() -> void:
	MetaProgression.load_data()
	shard_label.text = "灵魂碎片：%d" % MetaProgression.soul_shards
	var selected_info: Dictionary = WEAPON_INFO.get(MetaProgression.selected_weapon, WEAPON_INFO["pistol"])
	selected_weapon_label.text = "当前武器：%s" % String(selected_info["title"])
	weapon_desc_label.text = String(selected_info["description"])
	stage_index = _get_stage_index(MetaProgression.selected_stage)
	if not MetaProgression.is_stage_unlocked(MetaProgression.selected_stage):
		stage_index = 0
		MetaProgression.set_selected_stage(String(STAGE_INFO[0]["id"]))
	_refresh_stage_selection()
	_refresh_weapon_buttons()
	_refresh_branch_visuals()
	_rebuild_skill_tree()


func _process(delta: float) -> void:
	if shard_click_timer > 0.0:
		shard_click_timer = maxf(shard_click_timer - delta, 0.0)
		if shard_click_timer <= 0.0:
			shard_click_count = 0


func _refresh_weapon_buttons() -> void:
	for weapon_id in weapon_buttons.keys():
		var button: Button = weapon_buttons[weapon_id]
		var is_selected: bool = weapon_id == MetaProgression.selected_weapon
		button.disabled = false
		button.text = "%s%s" % ["已选择 · " if is_selected else "", String(WEAPON_INFO[weapon_id]["title"])]
		_apply_weapon_button_style(button, is_selected)


func _apply_weapon_button_style(button: Button, is_selected: bool) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.corner_radius_top_left = 14
	normal_style.corner_radius_top_right = 14
	normal_style.corner_radius_bottom_right = 14
	normal_style.corner_radius_bottom_left = 14
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	button.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate()
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style.duplicate())

	if is_selected:
		normal_style.bg_color = Color(0.93, 0.55, 0.2, 1.0)
		normal_style.border_color = Color(1.0, 0.91, 0.66, 1.0)
		hover_style.bg_color = Color(1.0, 0.62, 0.28, 1.0)
		hover_style.border_color = Color(1.0, 0.95, 0.76, 1.0)
		button.scale = Vector2(1.04, 1.04)
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		button.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.12, 0.08, 0.04, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.04, 1.0))
	else:
		normal_style.bg_color = Color(0.22, 0.26, 0.34, 1.0)
		normal_style.border_color = Color(0.69, 0.76, 0.83, 0.35)
		hover_style.bg_color = Color(0.28, 0.33, 0.42, 1.0)
		hover_style.border_color = Color(0.84, 0.89, 0.95, 0.55)
		button.scale = Vector2.ONE
		button.modulate = Color(0.9, 0.94, 1.0, 1.0)
		button.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))


func _refresh_branch_visuals() -> void:
	var branch_defs: Dictionary = MetaProgression.get_branch_definitions()
	for branch_key in branch_titles.keys():
		var title_label: Label = branch_titles[branch_key]
		var block: Panel = branch_blocks[branch_key]
		var branch_def: Dictionary = branch_defs.get(branch_key, {})
		title_label.text = String(branch_def.get("title", branch_key.capitalize()))
		title_label.add_theme_color_override("font_color", branch_def.get("accent", Color.WHITE))
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = branch_def.get("panel_bg", Color(0.1, 0.1, 0.1, 0.94))
		style_box.corner_radius_top_left = 22
		style_box.corner_radius_top_right = 22
		style_box.corner_radius_bottom_right = 22
		style_box.corner_radius_bottom_left = 22
		style_box.border_width_left = 2
		style_box.border_width_top = 2
		style_box.border_width_right = 2
		style_box.border_width_bottom = 2
		style_box.border_color = branch_def.get("panel_border", Color(0.8, 0.8, 0.8, 1.0))
		block.add_theme_stylebox_override("panel", style_box)


func _rebuild_skill_tree() -> void:
	for branch in tree_branches.values():
		for child in branch.get_children():
			branch.remove_child(child)
			child.queue_free()

	var definitions: Dictionary = MetaProgression.get_upgrade_definitions()
	var branch_defs: Dictionary = MetaProgression.get_branch_definitions()
	var upgrades_by_branch := {}
	var children_by_parent := {}
	var multi_requirement_upgrades_by_branch := {}

	for upgrade_id in definitions.keys():
		var id_text: String = String(upgrade_id)
		var definition: Dictionary = definitions[id_text]
		var branch_key: String = String(definition.get("branch", "survival"))
		if not upgrades_by_branch.has(branch_key):
			upgrades_by_branch[branch_key] = []
		upgrades_by_branch[branch_key].append(id_text)

		var required_ids: Array[String] = MetaProgression.get_required_ids(id_text)
		if required_ids.size() > 1:
			if not multi_requirement_upgrades_by_branch.has(branch_key):
				multi_requirement_upgrades_by_branch[branch_key] = []
			multi_requirement_upgrades_by_branch[branch_key].append(id_text)
			continue
		if required_ids.size() == 1:
			var parent_id: String = required_ids[0]
			if not children_by_parent.has(parent_id):
				children_by_parent[parent_id] = []
			children_by_parent[parent_id].append(id_text)

	var sorted_branch_keys: Array[String] = []
	for branch_key in branch_defs.keys():
		sorted_branch_keys.append(String(branch_key))
	sorted_branch_keys.sort_custom(func(a: String, b: String) -> bool:
		return int(branch_defs[a].get("order", 999)) < int(branch_defs[b].get("order", 999))
	)

	for branch_key in sorted_branch_keys:
		if not tree_branches.has(branch_key):
			continue
		var branch_container: VBoxContainer = tree_branches.get(branch_key, tree_branches["survival"])
		var branch_block: Panel = branch_blocks.get(branch_key, null)
		var roots: Array[String] = []
		for upgrade_id in upgrades_by_branch.get(branch_key, []):
			if MetaProgression.get_required_ids(upgrade_id).is_empty():
				roots.append(upgrade_id)

		roots.sort_custom(func(a: String, b: String) -> bool:
			var def_a: Dictionary = definitions[a]
			var def_b: Dictionary = definitions[b]
			var tier_a: int = int(def_a.get("tier", 1))
			var tier_b: int = int(def_b.get("tier", 1))
			if tier_a != tier_b:
				return tier_a < tier_b
			return a < b
		)

		var combo_upgrades: Array = multi_requirement_upgrades_by_branch.get(branch_key, [])
		if combo_upgrades.size() > 0 and roots.size() >= 2:
			branch_container.add_child(_build_combo_branch_layout(roots, combo_upgrades, definitions, children_by_parent))
		else:
			for root_id in roots:
				branch_container.add_child(_build_chain_row(root_id, definitions, children_by_parent))

			for upgrade_id_variant in combo_upgrades:
				var upgrade_id: String = String(upgrade_id_variant)
				branch_container.add_child(_build_mid_convergence_row(upgrade_id, definitions[upgrade_id]))

		if branch_block != null:
			var content_height := 0.0
			var child_count := 0
			for child in branch_container.get_children():
				if child is Control:
					content_height += maxf((child as Control).custom_minimum_size.y, 96.0)
					child_count += 1
			if child_count == 0:
				child_count = 1
				content_height = 112.0
			var block_height: float = 34.0 + content_height + float(maxi(child_count - 1, 0)) * 18.0
			branch_block.custom_minimum_size = Vector2(branch_block.custom_minimum_size.x, block_height)


func _build_chain_row(root_id: String, definitions: Dictionary, children_by_parent: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 112)

	var current_ids: Array[String] = [root_id]
	var node_index := 0
	while not current_ids.is_empty():
		var next_ids: Array[String] = []
		for upgrade_id in current_ids:
			if node_index > 0:
				var required_ids: Array[String] = MetaProgression.get_required_ids(upgrade_id)
				var primary_parent_id: String = required_ids[0] if not required_ids.is_empty() else ""
				var child_count: int = children_by_parent.get(primary_parent_id, []).size()
				row.add_child(_build_connector(_is_upgrade_path_active(upgrade_id, definitions), child_count > 1))
			row.add_child(_build_upgrade_button(upgrade_id, definitions[upgrade_id]))
			var children: Array = children_by_parent.get(upgrade_id, [])
			for child in children:
				next_ids.append(String(child))
		current_ids = next_ids
		node_index += 1
	return row


func _build_mid_convergence_row(upgrade_id: String, definition: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 96)

	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(1220, 1)
	row.add_child(left_spacer)
	row.add_child(_build_ultimate_connector(_is_upgrade_path_active(upgrade_id, MetaProgression.get_upgrade_definitions())))
	row.add_child(_build_upgrade_button(upgrade_id, definition))
	return row


func _build_combo_branch_layout(roots: Array[String], combo_upgrades: Array, definitions: Dictionary, children_by_parent: Dictionary) -> Control:
	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_column_width: float = 980.0
	var combo_column_width: float = 520.0
	var layout_width: float = left_column_width + combo_column_width + 28.0
	var row_height: float = 112.0
	var row_spacing: float = 28.0
	var layout_height: float = float(roots.size()) * row_height + float(maxi(roots.size() - 1, 0)) * row_spacing + 24.0
	layout.custom_minimum_size = Vector2(layout_width, maxf(layout_height, 250.0))
	layout.add_theme_constant_override("separation", 28)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_column.add_theme_constant_override("separation", 28)
	left_column.custom_minimum_size = Vector2(left_column_width, maxf(layout_height, 250.0))
	layout.add_child(left_column)

	for root_id in roots:
		left_column.add_child(_build_chain_row(root_id, definitions, children_by_parent))

	var combo_wrap := VBoxContainer.new()
	combo_wrap.size_flags_horizontal = Control.SIZE_SHRINK_END
	combo_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combo_wrap.custom_minimum_size = Vector2(combo_column_width, maxf(layout_height, 250.0))
	layout.add_child(combo_wrap)

	var combo_row := HBoxContainer.new()
	combo_row.add_theme_constant_override("separation", 18)
	combo_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var combo_id: String = String(combo_upgrades[0])
	var combo_connector := _build_ultimate_connector(_is_upgrade_path_active(combo_id, definitions))
	combo_row.add_child(combo_connector)

	var combo_button := _build_upgrade_button(combo_id, definitions[combo_id])
	combo_row.add_child(combo_button)

	var combo_height: float = 112.0
	var combo_required_rows: Array[int] = _get_combo_required_row_indices(combo_id, roots, children_by_parent)
	var top_row_index: int = combo_required_rows[0] if not combo_required_rows.is_empty() else 0
	var bottom_row_index: int = combo_required_rows[combo_required_rows.size() - 1] if not combo_required_rows.is_empty() else mini(roots.size() - 1, 1)
	var row_step: float = row_height + row_spacing
	var top_center: float = float(top_row_index) * row_step + row_height * 0.5
	var bottom_center: float = float(bottom_row_index) * row_step + row_height * 0.5
	var target_center: float = (top_center + bottom_center) * 0.5
	var combo_top_spacing: float = maxf(0.0, target_center - combo_height * 0.5)
	var combo_bottom_spacing: float = maxf(0.0, maxf(layout_height, 250.0) - combo_top_spacing - combo_height)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, combo_top_spacing)
	top_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	combo_wrap.add_child(top_spacer)
	combo_wrap.add_child(combo_row)

	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, combo_bottom_spacing)
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combo_wrap.add_child(bottom_spacer)

	return layout


func _get_combo_required_row_indices(combo_id: String, roots: Array[String], children_by_parent: Dictionary) -> Array[int]:
	var row_indices: Array[int] = []
	var required_ids: Array[String] = MetaProgression.get_required_ids(combo_id)
	for required_id in required_ids:
		for row_index in range(roots.size()):
			var root_id: String = roots[row_index]
			if _chain_contains_upgrade(root_id, required_id, children_by_parent):
				if not row_indices.has(row_index):
					row_indices.append(row_index)
				break
	row_indices.sort()
	return row_indices


func _chain_contains_upgrade(root_id: String, target_id: String, children_by_parent: Dictionary) -> bool:
	if root_id == target_id:
		return true
	var pending: Array[String] = [root_id]
	while not pending.is_empty():
		var current_id: String = pending.pop_back()
		for child_variant in children_by_parent.get(current_id, []):
			var child_id: String = String(child_variant)
			if child_id == target_id:
				return true
			pending.append(child_id)
	return false


func _build_ultimate_connector(is_active: bool) -> Control:
	var connector := Control.new()
	connector.set_script(SkillUltimateConnectorScript)
	connector.custom_minimum_size = Vector2(180, 96)
	connector.state = "available" if is_active else "locked"
	return connector


func _build_connector(is_active: bool, show_branch_stub: bool) -> Control:
	var connector := Control.new()
	connector.set_script(SkillTreeConnectorScript)
	connector.custom_minimum_size = Vector2(72, 28)
	connector.state = "available" if is_active else "locked"
	connector.show_branch_stub = show_branch_stub
	return connector


func _build_upgrade_button(upgrade_id: String, definition: Dictionary) -> Button:
	var button := Button.new()
	var current_level: int = MetaProgression.get_upgrade_level(upgrade_id)
	var max_level: int = int(definition["max_level"])
	var cost: int = int(definition["cost"])
	var bought_out := current_level >= max_level
	var can_buy := MetaProgression.can_buy_upgrade(upgrade_id)
	var is_locked := not bought_out and not can_buy
	var requirement_text: String = MetaProgression.get_requirement_text(upgrade_id)
	var state: String = _get_skill_state(bought_out, can_buy)
	button.custom_minimum_size = Vector2(260, 112)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.text = "%s%s\n%s\n消耗：%d | 已拥有：%d/%d" % [
		"[锁] " if is_locked else "",
		String(definition["title"]),
		String(definition["description"]),
		cost,
		current_level,
		max_level
	]
	button.disabled = bought_out or is_locked
	if bought_out:
		button.text += "\n已解锁"
	elif not requirement_text.is_empty() and not _are_requirements_met(upgrade_id):
		button.text += "\n未解锁"
	elif MetaProgression.soul_shards < cost:
		button.text += "\n未解锁"
	else:
		button.text += "\n待解锁"
	button.tooltip_text = _build_skill_tooltip(String(definition["title"]), String(definition["description"]), cost, current_level, max_level, bought_out, can_buy, is_locked, requirement_text)
	_apply_skill_button_style(button, state)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_on_upgrade_pressed.bind(upgrade_id))
	return button


func _apply_skill_button_style(button: Button, state: String) -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.corner_radius_top_left = 18
	normal_style.corner_radius_top_right = 18
	normal_style.corner_radius_bottom_right = 18
	normal_style.corner_radius_bottom_left = 18
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2

	var hover_style := normal_style.duplicate()
	var pressed_style := normal_style.duplicate()

	var font_color := Color(1.0, 1.0, 1.0, 1.0)
	match state:
		"unlocked":
			normal_style.bg_color = Color(0.13, 0.27, 0.22, 0.96)
			normal_style.border_color = Color(0.48, 0.94, 0.72, 0.95)
			hover_style.bg_color = Color(0.16, 0.31, 0.25, 0.98)
			hover_style.border_color = Color(0.56, 0.98, 0.79, 1.0)
			pressed_style.bg_color = hover_style.bg_color
			pressed_style.border_color = hover_style.border_color
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			font_color = Color(0.82, 1.0, 0.9, 1.0)
		"available":
			normal_style.bg_color = Color(0.27, 0.21, 0.1, 0.97)
			normal_style.border_color = Color(1.0, 0.78, 0.36, 0.98)
			hover_style.bg_color = Color(0.31, 0.24, 0.12, 0.99)
			hover_style.border_color = Color(1.0, 0.86, 0.5, 1.0)
			pressed_style.bg_color = hover_style.bg_color
			pressed_style.border_color = hover_style.border_color
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			font_color = Color(1.0, 0.94, 0.8, 1.0)
		_:
			normal_style.bg_color = Color(0.1, 0.11, 0.15, 0.96)
			normal_style.border_color = Color(0.3, 0.34, 0.42, 0.9)
			hover_style.bg_color = Color(0.11, 0.12, 0.16, 0.98)
			hover_style.border_color = Color(0.34, 0.39, 0.48, 0.95)
			pressed_style.bg_color = hover_style.bg_color
			pressed_style.border_color = hover_style.border_color
			button.modulate = Color(0.76, 0.8, 0.88, 0.92)
			font_color = Color(0.7, 0.75, 0.84, 1.0)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", normal_style.duplicate())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)


func _get_skill_state(bought_out: bool, can_buy: bool) -> String:
	if bought_out:
		return "unlocked"
	if can_buy:
		return "available"
	return "locked"


func _is_upgrade_path_active(upgrade_id: String, definitions: Dictionary) -> bool:
	var current_level: int = MetaProgression.get_upgrade_level(upgrade_id)
	if current_level > 0:
		return true
	for require_id in MetaProgression.get_required_ids(upgrade_id):
		if MetaProgression.get_upgrade_level(require_id) > 0:
			return true
	return false


func _build_skill_tooltip(title: String, description: String, cost: int, current_level: int, max_level: int, bought_out: bool, can_buy: bool, is_locked: bool, requirement_text: String) -> String:
	var status_text := "已解锁" if bought_out else "可解锁"
	if is_locked:
		status_text = "未解锁"
	var lines := [
		title,
		description,
		"状态：%s" % status_text,
		"消耗：%d 灵魂碎片" % cost,
		"进度：%d/%d" % [current_level, max_level]
	]
	if not requirement_text.is_empty():
		lines.append("前置：%s" % requirement_text)
	return "\n".join(lines)


func _on_upgrade_pressed(upgrade_id: String) -> void:
	if MetaProgression.buy_upgrade(upgrade_id):
		_refresh()


func _on_weapon_selected(weapon_id: String) -> void:
	MetaProgression.set_selected_weapon(weapon_id)
	_refresh()


func _open_stage_popup() -> void:
	_show_centered_popup(stage_popup)
	_refresh_stage_selection()


func _on_prev_stage_pressed() -> void:
	stage_index = posmod(stage_index - 1, STAGE_INFO.size())
	_refresh_stage_selection()


func _on_next_stage_pressed() -> void:
	stage_index = posmod(stage_index + 1, STAGE_INFO.size())
	_refresh_stage_selection()


func _on_confirm_stage_pressed() -> void:
	var stage_id: String = String(STAGE_INFO[stage_index]["id"])
	if not MetaProgression.is_stage_unlocked(stage_id):
		return
	MetaProgression.set_selected_stage(stage_id)
	stage_popup.visible = false
	_show_centered_popup(weapon_popup)


func _on_reset_button_pressed() -> void:
	MetaProgression.reset_progress()
	_refresh()


func _on_confirm_weapon_pressed() -> void:
	weapon_popup.visible = false
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _refresh_stage_selection() -> void:
	var stage_data: Dictionary = STAGE_INFO[stage_index]
	var stage_id: String = String(stage_data["id"])
	var is_unlocked: bool = MetaProgression.is_stage_unlocked(stage_id)
	selected_stage_label.text = "当前关卡：%s" % String(stage_data["title"])
	stage_name_label.text = "%s%s" % ["" if is_unlocked else "[锁] ", String(stage_data["title"])]
	stage_desc_label.text = String(stage_data["description"]) if is_unlocked else "需要先通关上一关，才能解锁这一关。"
	stage_hint_label.text = String(stage_data["hint"]) if is_unlocked else "解锁条件：通关上一关"
	stage_preview.set_stage(stage_id)
	confirm_stage_button.disabled = not is_unlocked
	confirm_stage_button.text = "选择武器" if is_unlocked else "尚未解锁"


func _show_centered_popup(popup: Control) -> void:
	popup.visible = true
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.offset_left = 0.0
	popup.offset_top = 0.0
	popup.offset_right = 0.0
	popup.offset_bottom = 0.0
	popup.update_minimum_size()
	if popup == skill_popup:
		skill_scroll.scroll_horizontal = 0
		skill_scroll.scroll_vertical = 0
		is_dragging_skill_tree = false
		drag_started_on_skill_tree = false


func _on_skill_scroll_gui_input(event: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _is_mouse_inside_shard_panel(event.position):
			_register_shard_click()
			return
	if not skill_popup.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_mouse_inside_skill_scroll(event.position):
			drag_started_on_skill_tree = true
			is_dragging_skill_tree = false
			drag_start_mouse_position = event.position
			last_drag_mouse_position = event.position
		else:
			drag_started_on_skill_tree = false
			is_dragging_skill_tree = false
	elif event is InputEventMouseMotion and drag_started_on_skill_tree:
		if not is_dragging_skill_tree and event.position.distance_to(drag_start_mouse_position) > 8.0:
			is_dragging_skill_tree = true
		if is_dragging_skill_tree:
			var delta: Vector2 = event.position - last_drag_mouse_position
			skill_scroll.scroll_horizontal = maxi(skill_scroll.scroll_horizontal - int(delta.x), 0)
			skill_scroll.scroll_vertical = maxi(skill_scroll.scroll_vertical - int(delta.y), 0)
			last_drag_mouse_position = event.position


func _is_mouse_inside_skill_scroll(mouse_position: Vector2) -> bool:
	var scroll_rect := Rect2(skill_scroll.global_position, skill_scroll.size)
	return scroll_rect.has_point(mouse_position)


func _are_requirements_met(upgrade_id: String) -> bool:
	for require_id in MetaProgression.get_required_ids(upgrade_id):
		if MetaProgression.get_upgrade_level(require_id) <= 0:
			return false
	return true


func _on_shard_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_register_shard_click()


func _register_shard_click() -> void:
	if shard_click_timer <= 0.0:
		shard_click_count = 0
	shard_click_count += 1
	shard_click_timer = 0.9
	if shard_click_count >= 3:
		MetaProgression.add_soul_shards(1000)
		shard_click_count = 0
		shard_click_timer = 0.0
		_refresh()


func _is_mouse_inside_shard_panel(mouse_position: Vector2) -> bool:
	var shard_rect := Rect2(shard_panel.global_position, shard_panel.size)
	return shard_rect.has_point(mouse_position)


func _get_stage_index(stage_id: String) -> int:
	for index in range(STAGE_INFO.size()):
		if String(STAGE_INFO[index]["id"]) == stage_id:
			return index
	return 0


func get_next_stage_id(stage_id: String) -> String:
	var stage_position := _get_stage_index(stage_id)
	if stage_position >= STAGE_INFO.size() - 1:
		return ""
	return String(STAGE_INFO[stage_position + 1]["id"])
