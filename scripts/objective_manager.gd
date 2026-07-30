extends Node

@export var pickup_point: NodePath
@export var dropoff_point: NodePath
@export var track_generator_path: NodePath

@export_category("Rounds")
@export var round_count := 5
@export var rng_seed := 0
@export var brake_working_duration := 3.0

@export_category("Placement")
@export_range(0.0, 0.5) var road_edge_margin := 0.25

@export_category("Messages")
@export var first_pickup_text := "Looks like the brakes aren't working... but you've got a pickup! Press E to grab it (1/%d)."
@export var dropoff_prompt_text := "Press E to YEET them out!"
@export var round_complete_text := "Delivered! (%d/%d) Brakes hold for %ds"
@export var all_done_text := "All %d deliveries complete!"

var _pickup: Area3D
var _dropoff: Area3D
var _track_generator: Node3D
var _round := 0
var _road_transforms: Array[Transform3D] = []
var _road_min_x: Array[float] = []
var _road_extents: Array[float] = []
var _landmark_points: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _route_ready := false

func _ready():
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_pickup = get_node_or_null(pickup_point)
	_dropoff = get_node_or_null(dropoff_point)
	_track_generator = get_node_or_null(track_generator_path)

	if _pickup:
		_pickup.set_active(false)
		_pickup.triggered.connect(_on_pickup_triggered)
	if _dropoff:
		_dropoff.set_active(false)
		_dropoff.triggered.connect(_on_dropoff_triggered)

	GameManager.game_started.connect(_on_game_started)

	if _track_generator:
		if _track_generator.route_ready:
			_on_route_generated()
		else:
			_track_generator.route_generated.connect(_on_route_generated)

func _on_route_generated():
	_cache_road_segments()
	_pick_fixed_positions()
	_round = 0
	_route_ready = true
	if GameManager.is_started():
		_begin_first_round()

func _on_game_started():
	if _route_ready:
		_begin_first_round()

func _begin_first_round():
	_start_round()
	GameManager.message_changed.emit(first_pickup_text % round_count)

func _cache_road_segments():
	var transforms: Array[Transform3D] = _track_generator.get_chunk_transforms()
	var extents: Array[float] = _track_generator.get_chunk_extents()
	var min_x: Array[float] = _track_generator.get_chunk_min_x()
	var is_intersection: Array[bool] = _track_generator.get_chunk_is_roundabout()

	_road_transforms.clear()
	_road_min_x.clear()
	_road_extents.clear()

	for i in transforms.size():
		if not is_intersection[i]:
			_road_transforms.append(transforms[i])
			_road_min_x.append(min_x[i])
			_road_extents.append(extents[i])

# Pickup/dropoff (and whatever landmark building rides along with each one)
# are placed exactly once here and never moved again - rounds just shuttle
# the player back and forth between these two fixed spots.
func _pick_fixed_positions():
	_landmark_points.clear()
	if _road_transforms.size() < 2:
		return

	var pickup_index := _rng.randi_range(0, _road_transforms.size() - 1)
	var dropoff_index := pickup_index
	while dropoff_index == pickup_index:
		dropoff_index = _rng.randi_range(0, _road_transforms.size() - 1)

	if _pickup:
		_pickup.global_transform = _point_on_chunk(pickup_index)
		_landmark_points.append(_pickup.global_position)
	if _dropoff:
		_dropoff.global_transform = _point_on_chunk(dropoff_index)
		_landmark_points.append(_dropoff.global_position)

func get_landmark_points() -> Array[Vector3]:
	return _landmark_points

func _start_round():
	if _road_transforms.size() < 2:
		return

	_round += 1

	if _pickup:
		_pickup.set_active(true)
	if _dropoff:
		_dropoff.set_active(false)

func _point_on_chunk(index: int) -> Transform3D:
	var frac := _rng.randf_range(road_edge_margin, 1.0 - road_edge_margin)
	var local_x: float = _road_min_x[index] + frac * _road_extents[index]
	var chunk_transform: Transform3D = _road_transforms[index]
	var world_pos: Vector3 = chunk_transform * Vector3(local_x, 0.0, 0.0)
	return Transform3D(chunk_transform.basis, world_pos)

func _on_pickup_triggered(_point):
	if _pickup:
		_pickup.set_active(false)
	if _dropoff:
		_dropoff.set_active(true)
	GameManager.message_changed.emit(dropoff_prompt_text)

func _on_dropoff_triggered(_point):
	if _dropoff:
		_dropoff.set_active(false)

	if _round >= round_count:
		GameManager.set_brakes_permanently_working()
		GameManager.message_changed.emit(all_done_text % round_count)
	else:
		GameManager.start_temporary_brakes(brake_working_duration)
		GameManager.message_changed.emit(round_complete_text % [_round, round_count, int(brake_working_duration)])
		_start_round()
