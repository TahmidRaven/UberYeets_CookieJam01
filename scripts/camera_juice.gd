extends Camera3D

@export var car_path: NodePath

@export_category("Shake")
@export var impact_to_trauma := 0.05
@export var trauma_decay := 1.6
@export var max_shake_offset := 0.35
@export var max_shake_roll := 0.06

@export_category("Speed FOV")
@export var base_fov := 75.0
@export var max_fov_boost := 12.0
@export var fov_speed_smoothing := 3.0

var _car: CharacterBody3D
var _rng := RandomNumberGenerator.new()
var _trauma := 0.0
var _base_transform: Transform3D

func _ready():
	_rng.randomize()
	_base_transform = transform
	fov = base_fov

	_car = get_node_or_null(car_path)
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")
	if _car:
		_car.collided.connect(_on_collided)

func _on_collided(impact_speed: float, _impact_position: Vector3):
	_trauma = clamp(_trauma + impact_speed * impact_to_trauma, 0.0, 1.0)

func _process(delta):
	_update_shake(delta)
	_update_fov(delta)

func _update_shake(delta: float):
	if _trauma <= 0.0:
		transform = _base_transform
		return

	_trauma = max(_trauma - trauma_decay * delta, 0.0)
	var amount := _trauma * _trauma

	var offset := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * max_shake_offset * amount
	var roll := _rng.randf_range(-1.0, 1.0) * max_shake_roll * amount

	transform = _base_transform
	translate(offset)
	rotate_z(roll)

func _update_fov(delta: float):
	if _car == null:
		return
	var speed_ratio: float = clamp(_car.velocity.length() / _car.max_speed, 0.0, 1.0)
	var target_fov := base_fov + max_fov_boost * speed_ratio
	fov = lerp(fov, target_fov, clamp(fov_speed_smoothing * delta, 0.0, 1.0))
