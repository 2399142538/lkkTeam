extends Area2D


@export var speed := 360.0
@export var damage := 1
@export var lifetime := 2.4

var direction := Vector2.RIGHT
var trail_timer := 0.0


func _ready() -> void:
	add_to_group("enemy_projectiles")
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	rotation = direction.angle()
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.03
		queue_redraw()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.48, 0.34, 0.95))
	draw_circle(Vector2(-8, 0), 3.0, Color(1.0, 0.72, 0.42, 0.42))
