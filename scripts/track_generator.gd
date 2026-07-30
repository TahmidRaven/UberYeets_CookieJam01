extends Node3D

@export var road_chunk_scene: PackedScene
@export var roundabout_chunk_scene: PackedScene
@export_range(0.0, 1.0) var roundabout_chance := 0.2
@export var chunk_count := 12
@export_range(0.0, 1.0) var turn_chance := 0.5
@export var road_chunk_extent := 135.680158
@export var roundabout_chunk_extent := 20.0

@export_category("Lane Confinement")
@export var confine_to_lane := true
@export var lane_half_width := 8.0
@export var lane_correction_speed := 10.0

@export var rng_seed := 0
@export var car_path: NodePath

signal route_generated

var route_ready := false

var _rng := RandomNumberGenerator.new()
var _chunks: Array[Node3D] = []
var _chunk_extents: Array[float] = []
var _chunk_is_roundabout: Array[bool] = []
var _path_points: PackedVector3Array = []
var _car: CharacterBody3D

func _ready():
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_car = get_node_or_null(car_path)
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")

	var start_position: Vector3 = _car.global_position if _car else global_position
	var start_yaw: float = _car.rotation.y if _car else 0.0
	var entry_transform := Transform3D(Basis(Vector3.UP, start_yaw), start_position)

	for i in chunk_count:
		entry_transform = _spawn_chunk(entry_transform)

	route_ready = true
	route_generated.emit()

func _physics_process(delta):
	if not confine_to_lane:
		return
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")
		return
	_apply_lane_confinement(delta)

func get_transform_at_fraction(f: float) -> Transform3D:
	if _chunks.is_empty():
		return Transform3D.IDENTITY
	var idx := clampi(int(f * (_chunks.size() - 1)), 0, _chunks.size() - 1)
	return _chunks[idx].global_transform

func get_path_points() -> PackedVector3Array:
	return _path_points

func get_chunk_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for chunk in _chunks:
		transforms.append(chunk.global_transform)
	return transforms

func get_chunk_extents() -> Array[float]:
	return _chunk_extents

func get_chunk_is_roundabout() -> Array[bool]:
	return _chunk_is_roundabout

func _spawn_chunk(entry_transform: Transform3D) -> Transform3D:
	var use_roundabout = roundabout_chunk_scene != null and _rng.randf() < roundabout_chance
	var scene := roundabout_chunk_scene if use_roundabout else road_chunk_scene
	if scene == null:
		scene = road_chunk_scene if road_chunk_scene != null else roundabout_chunk_scene
	if scene == null:
		return entry_transform

	var chunk := scene.instantiate()
	add_child(chunk)
	chunk.global_transform = entry_transform

	_chunks.append(chunk)
	_chunk_extents.append(roundabout_chunk_extent if use_roundabout else road_chunk_extent)
	_chunk_is_roundabout.append(use_roundabout)
	_path_points.append(entry_transform.origin)

	var exits := chunk.get_node_or_null("Exits")
	if exits == null or exits.get_child_count() == 0:
		return entry_transform

	var choices: Array = exits.get_children()
	var chosen: Node3D

	if choices.size() == 1:
		chosen = choices[0]
	else:
		var straight: Node3D = exits.get_node_or_null("Front")
		if straight == null:
			straight = exits.get_node_or_null("Straight")

		if straight != null and _rng.randf() >= turn_chance:
			chosen = straight
		else:
			var turn_choices: Array = []
			for m in choices:
				if m != straight:
					turn_choices.append(m)
			if turn_choices.is_empty():
				turn_choices = choices
			chosen = turn_choices[_rng.randi_range(0, turn_choices.size() - 1)]

	return chosen.global_transform

func _apply_lane_confinement(delta):
	if _chunks.is_empty():
		return

	var best_dist := INF
	var best_local := Vector3.ZERO
	var best_chunk: Node3D = null

	for i in _chunks.size():
		var chunk := _chunks[i]
		var extent := _chunk_extents[i]
		var inv_transform: Transform3D = chunk.global_transform.affine_inverse()
		var local: Vector3 = inv_transform * _car.global_position
		var clamped_x: float = clamp(local.x, 0.0, extent)
		var closest_local := Vector3(clamped_x, 0.0, 0.0)
		var closest_global: Vector3 = chunk.global_transform * closest_local
		var d := _car.global_position.distance_to(closest_global)
		if d < best_dist:
			best_dist = d
			best_local = local
			best_chunk = chunk

	if best_chunk == null:
		return

	var clamped_z: float = clamp(best_local.z, -lane_half_width, lane_half_width)
	if not is_equal_approx(clamped_z, best_local.z):
		var corrected_local := Vector3(best_local.x, best_local.y, clamped_z)
		var corrected_global: Vector3 = best_chunk.global_transform * corrected_local
		_car.global_position = _car.global_position.lerp(corrected_global, clamp(lane_correction_speed * delta, 0.0, 1.0))
