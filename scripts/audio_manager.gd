extends Node

@export var thump_stream: AudioStream = preload("res://audio/thump.mp3")
@export var argh_stream: AudioStream = preload("res://audio/argh.mp3")
@export var pickup_stream: AudioStream = preload("res://audio/pickup.mp3")
@export var delivered_stream: AudioStream = preload("res://audio/delivered.mp3")
@export var next_order_stream: AudioStream = preload("res://audio/next_order.mp3")
@export var accelerate_stream: AudioStream = preload("res://audio/accelarate.mp3")
@export var engine_stream: AudioStream = preload("res://audio/engine.mp3")
@export var bgm_stream: AudioStream = preload("res://audio/BGM.mp3")

var _engine_player: AudioStreamPlayer
var _bgm_player: AudioStreamPlayer
var _bump_player: AudioStreamPlayer
var _event_player: AudioStreamPlayer
var _accelerate_player: AudioStreamPlayer

var _bump_busy := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	_engine_player = _make_player()
	_bgm_player = _make_player()
	_bump_player = _make_player()
	_event_player = _make_player()
	_accelerate_player = _make_player()

	_set_loop(engine_stream)
	_set_loop(bgm_stream)

	# The engine runs from the moment the game loads - menu included - and
	# never stops; playback keeps going through pause on its own since audio
	# isn't gated by SceneTree.paused, so nothing else has to manage this.
	_engine_player.stream = engine_stream
	_engine_player.play()

	GameManager.game_started.connect(_on_game_started)
	call_deferred("_bind_car")

func _make_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	return player

func _set_loop(stream: AudioStream):
	if stream is AudioStreamMP3:
		stream.loop = true

func _bind_car():
	var car := get_tree().get_first_node_in_group("car")
	if car:
		car.collided.connect(_on_car_collided)

func _on_game_started():
	play_bgm()

func _on_car_collided(_impact_speed: float, _impact_position: Vector3):
	if _bump_busy:
		return
	_bump_busy = true
	_play_bump_sequence()

# Thump plays, then argh right after it - and while that sequence is still
# running (e.g. the car is stuck against a wall and colliding every physics
# frame), new bump triggers are ignored instead of piling up on top of it.
func _play_bump_sequence():
	_bump_player.stream = thump_stream
	_bump_player.play()
	await _bump_player.finished
	_bump_player.stream = argh_stream
	_bump_player.play()
	await _bump_player.finished
	_bump_busy = false

func play_pickup():
	_event_player.stream = pickup_stream
	_event_player.play()

func play_delivered():
	_event_player.stream = delivered_stream
	_event_player.play()

func play_delivered_then_next_order():
	_event_player.stream = delivered_stream
	_event_player.play()
	await _event_player.finished
	_event_player.stream = next_order_stream
	_event_player.play()

func play_accelerate():
	_accelerate_player.stream = accelerate_stream
	_accelerate_player.play()

func play_bgm():
	_bgm_player.stream = bgm_stream
	_bgm_player.play()

func stop_bgm():
	_bgm_player.stop()

# Called when the pause menu closes - only actually resumes if the run has
# already started (BGM only ever begins once W is first pressed).
func resume_bgm():
	if GameManager.is_started():
		play_bgm()
