extends CanvasLayer

enum State { MAIN, PAUSED, CREDITS, HIDDEN }

var _state: State = State.MAIN
var _return_state: State = State.MAIN

@onready var _background: ColorRect = $Background
@onready var _main_panel: Control = $MainPanel
@onready var _pause_panel: Control = $PausePanel
@onready var _credits_panel: Control = $CreditsPanel

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	_main_panel.get_node("%PlayButton").pressed.connect(_on_play_pressed)
	_main_panel.get_node("%MainCreditsButton").pressed.connect(func(): _show_credits(State.MAIN))
	_main_panel.get_node("%MainExitButton").pressed.connect(_on_exit_pressed)

	_pause_panel.get_node("%ResumeButton").pressed.connect(_on_resume_pressed)
	_pause_panel.get_node("%PauseCreditsButton").pressed.connect(func(): _show_credits(State.PAUSED))
	_pause_panel.get_node("%PauseExitButton").pressed.connect(_on_exit_pressed)

	_credits_panel.get_node("%BackButton").pressed.connect(_on_credits_back_pressed)

	_enter_state(State.MAIN)

func _unhandled_input(event):
	if not event.is_action_pressed("ui_cancel"):
		return

	if _state == State.HIDDEN:
		_enter_state(State.PAUSED)
	elif _state == State.PAUSED:
		_on_resume_pressed()
	elif _state == State.CREDITS:
		_on_credits_back_pressed()
	else:
		return
	get_viewport().set_input_as_handled()

func _on_play_pressed():
	_enter_state(State.HIDDEN)

func _on_resume_pressed():
	_enter_state(State.HIDDEN)

func _on_exit_pressed():
	get_tree().quit()

func _show_credits(return_to: State):
	_return_state = return_to
	_enter_state(State.CREDITS)

func _on_credits_back_pressed():
	_enter_state(_return_state)

func _enter_state(new_state: State):
	_state = new_state
	get_tree().paused = new_state != State.HIDDEN
	_background.visible = new_state != State.HIDDEN
	_main_panel.visible = new_state == State.MAIN
	_pause_panel.visible = new_state == State.PAUSED
	_credits_panel.visible = new_state == State.CREDITS
