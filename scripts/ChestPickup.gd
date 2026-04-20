extends Area2D


signal opened(position: Vector2)


@onready var visual = $Visual

var velocity := Vector2.ZERO
var collected := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(visual, "rotation", deg_to_rad(6.0), 0.7)
	tween.tween_property(visual, "rotation", deg_to_rad(-6.0), 0.7)


func _process(delta: float) -> void:
	if collected:
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var collect_range := float(player.get("collect_range"))
	var pull_speed := float(player.get("pickup_pull_speed")) * 0.8
	var distance := global_position.distance_to(player.global_position)
	if distance <= collect_range:
		var direction := global_position.direction_to(player.global_position)
		velocity = velocity.lerp(direction * pull_speed, clampf(delta * 5.0, 0.0, 1.0))
		global_position += velocity * delta
	else:
		velocity = Vector2.ZERO


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		collected = true
		if has_node("/root/SFXManager"):
			SFXManager.play_chest_open()
		opened.emit(global_position)
		queue_free()
