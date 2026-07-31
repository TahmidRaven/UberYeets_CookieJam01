extends Node

@export var pickup_points_path: NodePath
@export var dropoff_points_path: NodePath
@export var track_generator_path: NodePath

@export_category("Rounds")
@export var round_count := 5
@export var rng_seed := 0
@export var brake_working_duration := 3.0

@export_category("Placement")
@export_range(0.0, 0.5) var road_edge_margin := 0.25
@export var min_point_spacing := 40.0

@export_category("Messages")
@export var first_pickup_text := "Looks like the brakes aren't working... but you've got a pickup! Press E to grab it (0/%d)."
@export var dropoff_prompt_text := "Press E to YEET them out!"
@export var round_complete_text := "Delivered! (%d/%d) Brakes hold for %ds"
@export var all_done_text := "All %d deliveries complete!"

var _pickups: Array[Area3D] = []
var _dropoffs: Array[Area3D] = []
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

	var pickup_container := get_node_or_null(pickup_points_path)
	if pickup_container:
		for child in pickup_container.get_children():
			_pickups.append(child)
	var dropoff_container := get_node_or_null(dropoff_points_path)
	if dropoff_container:
		for child in dropoff_container.get_children():
			_dropoffs.append(child)

	for pickup in _pickups:
		pickup.set_active(false)
		pickup.triggered.connect(_on_pickup_triggered)
	for dropoff in _dropoffs:
		dropoff.set_active(false)
		dropoff.triggered.connect(_on_dropoff_triggered)

	_track_generator = get_node_or_null(track_generator_path)
	GameManager.game_started.connect(_on_game_started)

	if _track_generator:
		if _track_generator.route_ready:
			_on_route_generated()
		else:
			_track_generator.route_generated.connect(_on_route_generated)

func _on_route_generated():
	_cache_road_segments()
	_place_all_points()
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

# Every pickup/dropoff for the whole run (and whatever landmark building rides
# along as each one's child) is placed exactly once here, before the player
# ever presses W - the run's locations are decided upfront, not regenerated
# round to round, and rounds just visit them in order.
func _place_all_points():
	_landmark_points.clear()
	if _road_transforms.is_empty():
		return

	var count: int = min(_pickups.size(), _dropoffs.size(), round_count)
	var chosen: Array[Vector3] = []

	for i in count:
		var pickup_transform := _pick_spaced_point(chosen)
		chosen.append(pickup_transform.origin)
		_pickups[i].global_transform = pickup_transform
		_landmark_points.append(pickup_transform.origin)

		var dropoff_transform := _pick_spaced_point(chosen)
		chosen.append(dropoff_transform.origin)
		_dropoffs[i].global_transform = dropoff_transform
		_landmark_points.append(dropoff_transform.origin)

# Picks a random road point, preferring one at least min_point_spacing away
# from every point chosen so far so the run's 10 locations don't cluster on
# top of each other; falls back to the best candidate found if none clear
# that bar within a bounded number of tries.
func _pick_spaced_point(existing: Array[Vector3]) -> Transform3D:
	var best_transform := Transform3D()
	var best_distance := -1.0

	for _attempt in 30:
		var index := _rng.randi_range(0, _road_transforms.size() - 1)
		var candidate := _point_on_chunk(index)
		if existing.is_empty():
			return candidate

		var closest := INF
		for point in existing:
			closest = min(closest, candidate.origin.distance_to(point))

		if closest >= min_point_spacing:
			return candidate
		if closest > best_distance:
			best_distance = closest
			best_transform = candidate

	return best_transform

func get_landmark_points() -> Array[Vector3]:
	return _landmark_points

func _start_round():
	if _pickups.is_empty() or _dropoffs.is_empty():
		return

	_pickups[_round].set_active(true)
	_dropoffs[_round].set_active(false)
	AudioManager.play_accelerate()

func _point_on_chunk(index: int) -> Transform3D:
	var frac := _rng.randf_range(road_edge_margin, 1.0 - road_edge_margin)
	var local_x: float = _road_min_x[index] + frac * _road_extents[index]
	var chunk_transform: Transform3D = _road_transforms[index]
	var world_pos: Vector3 = chunk_transform * Vector3(local_x, 0.0, 0.0)
	return Transform3D(chunk_transform.basis, world_pos)

func _on_pickup_triggered(_point):
	_pickups[_round].set_active(false)
	_dropoffs[_round].set_active(true)
	AudioManager.play_pickup()
	GameManager.message_changed.emit(dropoff_prompt_text)

func _on_dropoff_triggered(_point):
	_dropoffs[_round].set_active(false)

	if _round >= round_count - 1:
		GameManager.set_brakes_permanently_working()
		GameManager.message_changed.emit(all_done_text % round_count)
		AudioManager.play_delivered()
	else:
		GameManager.start_temporary_brakes(brake_working_duration)
		GameManager.message_changed.emit(round_complete_text % [_round + 1, round_count, int(brake_working_duration)])
		AudioManager.play_delivered_then_next_order()
		_round += 1
		_start_round()
