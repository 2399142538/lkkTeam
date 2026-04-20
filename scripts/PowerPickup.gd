extends Area2D


@export var pickup_type := "magnet"
@export var bob_height := 5.0
@export var bob_speed := 3.6

var base_position := Vector2.ZERO
var elapsed := 0.0
var collected := false

@onready var visual = $Visual


func _ready() -> void:
	base_position = global_position
	_apply_style()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if collected:
		return
	elapsed += delta
	global_position = base_position + Vector2(0.0, sin(elapsed * bob_speed) * bob_height)


func _apply_style() -> void:
	if visual == null:
		return
	match pickup_type:
		"bomb":
			visual.color = Color(1.0, 0.45, 0.24, 0.95)
		_:
			visual.color = Color(0.52, 0.96, 1.0, 0.95)


func _on_body_entered(body: Node) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	collected = true
	match pickup_type:
		"bomb":
			if body.has_method("clear_visible_enemies"):
				body.clear_visible_enemies()
		_:
			if body.has_method("collect_all_experience"):
				body.collect_all_experience()
	queue_free()
