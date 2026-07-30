extends Node3D

@export var road_chunk_scene: PackedScene
@export var road_chunk_extent := 169.0
@export var intersection_extent := 35.0

@export_category("Lane Confinement")
@export var confine_to_lane := true
@export var lane_half_width := 8.0
@export var lane_correction_speed := 10.0

@export var car_path: NodePath

signal route_generated

var route_ready := false

var _chunks: Array[Node3D] = []
var _chunk_extents: Array[float] = []
var _chunk_is_intersection: Array[bool] = []
var _intersections: Array[Node3D] = []
var _edges: Array[Dictionary] = []
var _car: CharacterBody3D

func _ready():
	_car = get_node_or_null(car_path)
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")

	for node in get_tree().get_nodes_in_group("intersection"):
		_intersections.append(node)
		_chunks.append(node)
		_chunk_extents.append(intersection_extent)
		_chunk_is_intersection.append(true)

	for node in _intersections:
		if not node.east.is_empty():
			var neighbor := node.get_node_or_null(node.east)
			if neighbor:
				_build_edge(node, neighbor, "East", "West")
		if not node.north.is_empty():
			var neighbor := node.get_node_or_null(node.north)
			if neighbor:
				_build_edge(node, neighbor, "North", "South")

	route_ready = true
	route_generated.emit()

func _physics_process(delta):
	if not confine_to_lane:
		return
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")
		return
	_apply_lane_confinement(delta)

func get_intersections() -> Array[Node3D]:
	return _intersections

func get_edges() -> Array[Dictionary]:
	return _edges

func get_chunk_transforms() -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for chunk in _chunks:
		transforms.append(chunk.global_transform)
	return transforms

func get_chunk_extents() -> Array[float]:
	return _chunk_extents

func get_chunk_is_roundabout() -> Array[bool]:
	return _chunk_is_intersection

func _build_edge(from_node: Node, to_node: Node, from_marker_name: String, to_marker_name: String):
	var from_marker: Node3D = from_node.get_node("Exits/" + from_marker_name)
	var to_marker: Node3D = to_node.get_node("Exits/" + to_marker_name)

	var start: Vector3 = from_marker.global_transform.origin
	var end: Vector3 = to_marker.global_transform.origin
	var distance := (end - start).length()

	if road_chunk_scene == null or distance <= 0.001:
		return

	var segment_basis: Basis = from_marker.global_transform.basis
	var direction: Vector3 = segment_basis.x
	var segment_count := maxi(1, roundi(distance / road_chunk_extent))

	for i in segment_count:
		var chunk := road_chunk_scene.instantiate()
		add_child(chunk)
		var origin := start + direction * (road_chunk_extent * i)
		chunk.global_transform = Transform3D(segment_basis, origin)

		_chunks.append(chunk)
		_chunk_extents.append(road_chunk_extent)
		_chunk_is_intersection.append(false)

	_edges.append({"a": start, "b": end})

func _apply_lane_confinement(delta):
	if _chunks.is_empty():
		return

	var best_dist := INF
	var best_local := Vector3.ZERO
	var best_chunk: Node3D = null
	var best_is_intersection := false

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
			best_is_intersection = _chunk_is_intersection[i]

	if best_chunk == null or best_is_intersection:
		return

	var clamped_z: float = clamp(best_local.z, -lane_half_width, lane_half_width)
	if not is_equal_approx(clamped_z, best_local.z):
		var corrected_local := Vector3(best_local.x, best_local.y, clamped_z)
		var corrected_global: Vector3 = best_chunk.global_transform * corrected_local
		_car.global_position = _car.global_position.lerp(corrected_global, clamp(lane_correction_speed * delta, 0.0, 1.0))
