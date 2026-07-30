extends CharacterBody3D

@export var acceleration := 35.0
@export var max_speed := 40.0
@export var turn_speed := 2.8
@export var friction := 10.0
@export var reverse_strength := 30.0

@export_category("Runaway Car Gag")
@export var auto_accelerate := true
@export var brakes_enabled := false
@export var brake_strength := 60.0
@export var space_accelerates := false

@export_category("Cornering")
@export_range(0.0, 1.0) var turn_speed_factor := 0.4
@export var turn_brake_strength := 40.0

signal panic_pressed

func _ready():
	add_to_group("car")

func _physics_process(delta):

	if Input.is_action_just_pressed("panic"):
		panic_pressed.emit()

	var accel = acceleration if auto_accelerate else Input.get_action_strength("accelerate") * acceleration

	velocity += transform.basis.x * accel * delta

	if Input.is_action_pressed("reverse"):
		velocity += transform.basis.x * -reverse_strength * delta

	if space_accelerates and Input.is_action_pressed("panic"):
		velocity += transform.basis.x * acceleration * delta
	elif brakes_enabled and Input.is_action_pressed("panic"):
		velocity = velocity.move_toward(Vector3.ZERO, brake_strength * delta)

	var steer = Input.get_axis("turn_right","turn_left")

	var effective_max_speed = lerp(max_speed, max_speed * turn_speed_factor, absf(steer))
	if velocity.length() > effective_max_speed:
		velocity = velocity.move_toward(Vector3.ZERO, turn_brake_strength * delta)
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	rotate_y(steer * turn_speed * delta * velocity.length() / max_speed)

	velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

	move_and_slide()
