extends Node3D

@export var road_tile_scene: PackedScene
@export var roundabout_tile_scene: PackedScene
@export_range(0.0, 1.0) var roundabout_chance := 0.2
@export var road_tile_length := 34.0
@export var roundabout_tile_length := 20.0
@export var route_length := 50

@export_category("Turning")
@export_range(0.0, 1.0) var turn_chance := 0.5
@export var turn_angle_degrees := 70.0

@export_category("Streaming")
@export var min_lookahead_distance := 60.0
@export var lookahead_seconds := 3.0
@export var despawn_tiles_behind := false
@export var despawn_behind_distance := 60.0
@export var initial_tiles := 6

@export_category("Lane Confinement")
@export var confine_to_lane := true
@export var lane_half_width := 8.0
@export var lane_correction_speed := 10.0

@export var rng_seed := 0
@export var car_path: NodePath

signal route_generated

var route_ready := false

var _rng := RandomNumberGenerator.new()
var _spawned: Array[Node3D] = []
var _path_transforms: Array[Transform3D] = []
var _path_is_roundabout: Array[bool] = []
var _next_index := 0
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
	_precompute_route(start_position, start_yaw)
	route_ready = true
	route_generated.emit()

	for i in initial_tiles:
		_spawn_next_tile()

func _physics_process(delta):
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")
		return

	var required_lookahead = max(min_lookahead_distance, _car.velocity.length() * lookahead_seconds)
	while _next_index < _path_transforms.size() and _car.global_position.distance_to(_path_transforms[_next_index].origin) < required_lookahead:
		_spawn_next_tile()

	if despawn_tiles_behind:
		while _spawned.size() > 0 and _car.global_position.distance_to(_spawned[0].global_position) > despawn_behind_distance:
			_spawned.pop_front().queue_free()

	if confine_to_lane:
		_apply_lane_confinement(delta)

func get_transform_at_fraction(f: float) -> Transform3D:
	if _path_transforms.is_empty():
		return Transform3D.IDENTITY
	var idx := clampi(int(f * (_path_transforms.size() - 1)), 0, _path_transforms.size() - 1)
	return _path_transforms[idx]

func get_path_points() -> PackedVector3Array:
	var points := PackedVector3Array()
	for t in _path_transforms:
		points.append(t.origin)
	return points

func _precompute_route(start_position: Vector3, start_yaw: float):
	_path_transforms.clear()
	_path_is_roundabout.clear()

	var cursor := start_position
	var yaw := start_yaw

	for i in route_length:
		var use_roundabout = roundabout_tile_scene != null and _rng.randf() < roundabout_chance
		var tile_basis := Basis(Vector3.UP, yaw)
		_path_transforms.append(Transform3D(tile_basis, cursor))
		_path_is_roundabout.append(use_roundabout)

		var length := roundabout_tile_length if use_roundabout else road_tile_length
		cursor += tile_basis.x * length

		if use_roundabout and _rng.randf() < turn_chance:
			var turn_sign := 1.0 if _rng.randf() < 0.5 else -1.0
			yaw += turn_sign * deg_to_rad(turn_angle_degrees)

func _spawn_next_tile():
	if _next_index >= _path_transforms.size():
		return

	var use_roundabout: bool = _path_is_roundabout[_next_index]
	var scene := roundabout_tile_scene if use_roundabout else road_tile_scene
	if scene == null:
		scene = road_tile_scene if road_tile_scene != null else roundabout_tile_scene
	if scene == null:
		return

	var tile := scene.instantiate()
	add_child(tile)
	tile.global_transform = _path_transforms[_next_index]
	_spawned.append(tile)
	_next_index += 1

func _apply_lane_confinement(delta):
	if _spawned.is_empty():
		return

	var nearest: Node3D = _spawned[0]
	var nearest_dist := _car.global_position.distance_to(nearest.global_position)
	for tile in _spawned:
		var d := _car.global_position.distance_to(tile.global_position)
		if d < nearest_dist:
			nearest = tile
			nearest_dist = d

	var inv_transform: Transform3D = nearest.global_transform.affine_inverse()
	var local: Vector3 = inv_transform * _car.global_position
	var clamped_z: float = clamp(local.z, -lane_half_width, lane_half_width)
	if not is_equal_approx(clamped_z, local.z):
		var corrected_local := Vector3(local.x, local.y, clamped_z)
		var corrected_global: Vector3 = nearest.global_transform * corrected_local
		_car.global_position = _car.global_position.lerp(corrected_global, clamp(lane_correction_speed * delta, 0.0, 1.0))
