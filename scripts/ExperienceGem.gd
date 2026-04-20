extends Area2D


@export var experience_value := 1
@export var bob_height := 4.0
@export var bob_speed := 4.0
@export var homing_acceleration := 7.0

var base_position := Vector2.ZERO
var elapsed := 0.0
var velocity := Vector2.ZERO
var collected := false
var forced_target: Node2D = null


func _ready() -> void:
	base_position = global_position
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if collected:
		return

	var player := forced_target
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.has_method("gain_experience"):
		var collect_range := float(player.get("collect_range"))
		var pull_speed := float(player.get("pickup_pull_speed"))
		if forced_target != null:
			collect_range = maxf(collect_range, 99999.0)
			pull_speed *= 2.4
		var distance := global_position.distance_to(player.global_position)
		if distance <= collect_range:
			var direction := global_position.direction_to(player.global_position)
			velocity = velocity.lerp(direction * pull_speed, clampf(delta * homing_acceleration, 0.0, 1.0))
			global_position += velocity * delta
			base_position = global_position
			return

	velocity = Vector2.ZERO
	elapsed += delta
	global_position = base_position + Vector2(0.0, sin(elapsed * bob_speed) * bob_height)


func _on_body_entered(body: Node) -> void:
	if body.has_method("gain_experience"):
		collected = true
		body.gain_experience(experience_value)
		queue_free()


func collect_instantly(target: Node) -> void:
	if collected:
		return
	if target == null or not target.has_method("gain_experience"):
		return
	collected = true
	target.gain_experience(experience_value)
	queue_free()


func magnetize_to(target: Node2D) -> void:
	if collected:
		return
	forced_target = target
	homing_acceleration = max(homing_acceleration, 15.0)
