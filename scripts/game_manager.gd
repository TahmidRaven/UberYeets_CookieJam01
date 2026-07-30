extends Node

@export_category("Messages")
@export var brakes_failing_again_text := "Brakes are failing again! Space guns it now!"
@export var brakes_fixed_for_good_text := "All deliveries done - brakes are fixed for good!"

@export_category("Timing")
@export var working_duration := 3.0

signal message_changed(text: String)

var car: Node = null
var _timer: Timer

func _ready():
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_working_timeout)

	call_deferred("_bind_car")

func _bind_car():
	car = get_tree().get_first_node_in_group("car")
	if car:
		car.brakes_enabled = false
		car.space_accelerates = false

func start_temporary_brakes(duration: float = working_duration):
	if car:
		car.brakes_enabled = true
		car.space_accelerates = false
	_timer.start(duration)

func set_brakes_permanently_working():
	if car:
		car.brakes_enabled = true
		car.space_accelerates = false
	_timer.stop()
	message_changed.emit(brakes_fixed_for_good_text)

func _on_working_timeout():
	if car:
		car.brakes_enabled = false
		car.space_accelerates = true
	message_changed.emit(brakes_failing_again_text)
