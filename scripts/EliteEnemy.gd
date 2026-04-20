extends "res://scripts/Enemy.gd"


func _ready() -> void:
	super._ready()
	add_to_group("elites")


func take_damage(amount: int) -> bool:
	health = max(health - amount, 0)
	_show_health_bar()
	health_updated.emit(health, max_health)
	_flash_hit()
	_show_damage_text(amount)
	if health == 0:
		if health_bar != null:
			health_bar.queue_free()
		chest_dropped.emit(global_position)
		_drop_experience()
		_try_drop_power_pickup()
		defeated.emit()
		queue_free()
		return true
	return false
