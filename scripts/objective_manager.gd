extends Node

@export var pickup_point: NodePath
@export var dropoff_point: NodePath
@export var track_generator_path: NodePath

@export_category("Placement")
@export_range(0.0, 1.0) var pickup_fraction := 0.15
@export_range(0.0, 1.0) var dropoff_fraction := 0.7
@export var beacon_height := 1.0

@export_category("Messages")
@export var pickup_prompt_text := "Find your fare!"
@export var dropoff_prompt_text := "Press E to YEET them out!"
@export var delivered_text := "Delivered!"

var _pickup: Area3D
var _dropoff: Area3D
var _track_generator: Node3D
var _armed := false

func _ready():
	_pickup = get_node_or_null(pickup_point)
	_dropoff = get_node_or_null(dropoff_point)
	_track_generator = get_node_or_null(track_generator_path)

	if _pickup:
		_pickup.triggered.connect(_on_pickup_triggered)
	if _dropoff:
		_dropoff.monitoring = false
		_dropoff.visible = false
		_dropoff.triggered.connect(_on_dropoff_triggered)

	if _track_generator:
		if _track_generator.route_ready:
			_on_route_generated()
		else:
			_track_generator.route_generated.connect(_on_route_generated)

	GameManager.state_changed.connect(_on_game_state_changed)

func _on_route_generated():
	if _pickup:
		var t: Transform3D = _track_generator.get_transform_at_fraction(pickup_fraction)
		t.origin.y += beacon_height
		_pickup.global_transform = t
	if _dropoff:
		var t: Transform3D = _track_generator.get_transform_at_fraction(dropoff_fraction)
		t.origin.y += beacon_height
		_dropoff.global_transform = t

func _on_game_state_changed(new_state):
	if new_state == GameManager.State.DRIVING and not _armed:
		_armed = true
		GameManager.message_changed.emit(pickup_prompt_text)

func _on_pickup_triggered(_point):
	if _pickup:
		_pickup.visible = false
		_pickup.monitoring = false
	if _dropoff:
		_dropoff.visible = true
		_dropoff.monitoring = true
	GameManager.message_changed.emit(dropoff_prompt_text)

func _on_dropoff_triggered(_point):
	if _dropoff:
		_dropoff.visible = false
		_dropoff.monitoring = false
	GameManager.message_changed.emit(delivered_text)
