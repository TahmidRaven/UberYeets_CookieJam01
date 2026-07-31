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

@export_category("Impacts")
@export var min_impact_speed := 4.0
@export var bounce_factor := 0.5

signal panic_pressed
signal collided(impact_speed: float, impact_position: Vector3)

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

	# This cornering brake only makes sense for taking a turn too fast going
	# forward - it doesn't know forward from reverse, so applied while
	# reversing it just fights/cancels the reverse thrust the instant you
	# steer at all. Skip it while reverse is held.
	if not Input.is_action_pressed("reverse"):
		var effective_max_speed = lerp(max_speed, max_speed * turn_speed_factor, absf(steer))
		if velocity.length() > effective_max_speed:
			velocity = velocity.move_toward(Vector3.ZERO, turn_brake_strength * delta)
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	rotate_y(steer * turn_speed * delta * velocity.length() / max_speed)

	velocity = velocity.move_toward(Vector3.ZERO, friction * delta)

	var pre_collision_velocity := velocity
	move_and_slide()
	_handle_impacts(pre_collision_velocity)

	# This car never leaves the ground plane - no gravity is applied anywhere
	# above, so any stray vertical velocity (e.g. from clipping the top edge
	# of a curb at an angle) would otherwise accumulate forever with nothing
	# to pull it back down.
	velocity.y = 0.0
	global_position.y = 0.0

# move_and_slide() already strips the into-wall component of velocity so the
# car doesn't get stuck, so impact strength has to be measured from the
# velocity we were carrying right before it - a real bounce-back is then
# added on top so a hard hit actually reads as a thud, not just a stop.
func _handle_impacts(pre_collision_velocity: Vector3):
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		var impact_speed := -pre_collision_velocity.dot(normal)
		if impact_speed > min_impact_speed:
			velocity += normal * impact_speed * bounce_factor
			collided.emit(impact_speed, collision.get_position())
