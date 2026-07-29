extends Node

enum State { INTRO, PANIC, DRIVING }

@export_category("Messages")
@export var panic_prompt_text := "PRESS SPACE TO BRAKE!"
@export var panic_reveal_text := "THE BRAKES AREN'T WORKING!!"
@export var brakes_back_text := "...brakes are back. Find your fare!"

@export_category("Timing")
@export var panic_duration := 6.0

signal state_changed(new_state: State)
signal message_changed(text: String)

var state: State = State.INTRO
var car: Node = null

func _ready():
	var timer := Timer.new()
	timer.name = "PanicTimer"
	timer.one_shot = true
	timer.wait_time = panic_duration
	add_child(timer)
	timer.timeout.connect(_on_panic_timer_timeout)

	call_deferred("_bind_car")
	_set_message(panic_prompt_text)

func _bind_car():
	car = get_tree().get_first_node_in_group("car")
	if car:
		car.panic_pressed.connect(_on_car_panic_pressed)

func _on_car_panic_pressed():
	if state != State.INTRO:
		return
	_set_state(State.PANIC)
	_set_message(panic_reveal_text)
	$PanicTimer.start(panic_duration)

func _on_panic_timer_timeout():
	if car:
		car.brakes_enabled = true
	_set_state(State.DRIVING)
	_set_message(brakes_back_text)

func _set_state(new_state: State):
	state = new_state
	state_changed.emit(state)

func _set_message(text: String):
	message_changed.emit(text)
