extends Node3D

@export var road_chunk_scene: PackedScene
@export var segments_per_edge := 1

@export_category("Lane Confinement")
@export var confine_to_lane := true
@export var lane_half_width := 8.0
@export var lane_correction_speed := 10.0

@export var car_path: NodePath

signal route_generated

var route_ready := false

var _chunks: Array[Node3D] = []
var _chunk_min_x: Array[float] = []
var _chunk_extents: Array[float] = []
var _chunk_is_intersection: Array[bool] = []
var _intersections: Array[Node3D] = []
var _edges: Array[Dictionary] = []
var _car: CharacterBody3D

const _EAST_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
const _NORTH_BASIS := Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0))
const _DIRECTIONS := {
	"East": Vector3(1, 0, 0),
	"West": Vector3(-1, 0, 0),
	"North": Vector3(0, 0, 1),
	"South": Vector3(0, 0, -1),
}

# Measured from the actual instanced geometry at runtime (not hand-entered),
# so mismatched or off-center origins baked into the source meshes can't
# cause placement gaps/overlaps - we measure whatever is really there.
var _road_extent := 0.0
var _road_near_offset := 0.0
var _intersection_east := 0.0
var _intersection_west := 0.0
var _intersection_north := 0.0
var _intersection_south := 0.0

func _ready():
	_car = get_node_or_null(car_path)
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")

	for node in get_tree().get_nodes_in_group("intersection"):
		_intersections.append(node)

	if _intersections.is_empty():
		route_ready = true
		route_generated.emit()
		return

	_measure_intersection(_intersections[0])
	_measure_road_chunk()

	for node in _intersections:
		_chunks.append(node)
		_chunk_min_x.append(_intersection_west)
		_chunk_extents.append(_intersection_east - _intersection_west)
		_chunk_is_intersection.append(true)

	var neighbor_of: Dictionary = _build_adjacency()

	var start_node := _closest_intersection(_car.global_position if _car else global_position)
	var edge_span := (_intersection_east - _intersection_west) + segments_per_edge * _road_extent
	var resolved: Dictionary = {start_node: start_node.global_position}
	var queue: Array[Node3D] = [start_node]

	while not queue.is_empty():
		var current: Node3D = queue.pop_front()
		var current_pos: Vector3 = resolved[current]
		var links: Dictionary = neighbor_of.get(current, {})
		for dir_name in links:
			var neighbor: Node3D = links[dir_name]
			if resolved.has(neighbor):
				continue
			resolved[neighbor] = current_pos + _DIRECTIONS[dir_name] * edge_span
			queue.append(neighbor)

	for node in _intersections:
		if resolved.has(node):
			node.global_position = resolved[node]

	if road_chunk_scene != null:
		for node in _intersections:
			var links: Dictionary = neighbor_of.get(node, {})
			if links.has("East"):
				_build_edge(node, links["East"], _EAST_BASIS, _intersection_east)
			if links.has("North"):
				_build_edge(node, links["North"], _NORTH_BASIS, _intersection_north)

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

func _build_adjacency() -> Dictionary:
	var neighbor_of: Dictionary = {}
	for node in _intersections:
		if not neighbor_of.has(node):
			neighbor_of[node] = {}
		if not node.east.is_empty():
			var neighbor := node.get_node_or_null(node.east)
			if neighbor:
				neighbor_of[node]["East"] = neighbor
				if not neighbor_of.has(neighbor):
					neighbor_of[neighbor] = {}
				neighbor_of[neighbor]["West"] = node
		if not node.north.is_empty():
			var neighbor := node.get_node_or_null(node.north)
			if neighbor:
				neighbor_of[node]["North"] = neighbor
				if not neighbor_of.has(neighbor):
					neighbor_of[neighbor] = {}
				neighbor_of[neighbor]["South"] = node
	return neighbor_of

func _closest_intersection(from_position: Vector3) -> Node3D:
	var best: Node3D = _intersections[0]
	var best_dist := from_position.distance_to(best.global_position)
	for node in _intersections:
		var d := from_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best

func _measure_intersection(sample: Node3D):
	var aabb := _local_aabb(sample)
	_intersection_west = aabb.position.x
	_intersection_east = aabb.position.x + aabb.size.x
	_intersection_south = aabb.position.z
	_intersection_north = aabb.position.z + aabb.size.z

func _measure_road_chunk():
	if road_chunk_scene == null:
		return
	var probe := road_chunk_scene.instantiate()
	add_child(probe)
	var aabb := _local_aabb(probe)
	_road_near_offset = aabb.position.x
	_road_extent = aabb.size.x
	remove_child(probe)
	probe.queue_free()

func _build_edge(from_node: Node, to_node: Node, chunk_basis: Basis, from_edge_offset: float):
	var start: Vector3 = from_node.global_position + chunk_basis.x * from_edge_offset

	for i in segments_per_edge:
		var chunk := road_chunk_scene.instantiate()
		add_child(chunk)
		var chunk_origin: Vector3 = start + chunk_basis.x * (i * _road_extent - _road_near_offset)
		chunk.global_transform = Transform3D(chunk_basis, chunk_origin)

		_chunks.append(chunk)
		_chunk_min_x.append(_road_near_offset)
		_chunk_extents.append(_road_extent)
		_chunk_is_intersection.append(false)

	_edges.append({"a": start, "b": to_node.global_position})

func _local_aabb(root: Node3D) -> AABB:
	var root_inverse: Transform3D = root.global_transform.affine_inverse()
	var result := AABB()
	var found := false
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var current: Node = stack.pop_back()

		if current is VisualInstance3D:
			var mesh_aabb: AABB = current.get_aabb()
			var local_transform: Transform3D = root_inverse * current.global_transform
			var transformed := _transform_aabb(mesh_aabb, local_transform)
			if found:
				result = result.merge(transformed)
			else:
				result = transformed
				found = true

		for child in current.get_children():
			stack.append(child)

	return result

func _transform_aabb(aabb: AABB, t: Transform3D) -> AABB:
	var result: AABB
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x if (i & 1) else 0.0,
			aabb.size.y if (i & 2) else 0.0,
			aabb.size.z if (i & 4) else 0.0
		)
		var transformed_corner: Vector3 = t * corner
		if i == 0:
			result = AABB(transformed_corner, Vector3.ZERO)
		else:
			result = result.expand(transformed_corner)
	return result

func _apply_lane_confinement(delta):
	if _chunks.is_empty():
		return

	var best_dist := INF
	var best_local := Vector3.ZERO
	var best_chunk: Node3D = null
	var best_is_intersection := false

	for i in _chunks.size():
		var chunk := _chunks[i]
		var min_x := _chunk_min_x[i]
		var max_x := min_x + _chunk_extents[i]
		var inv_transform: Transform3D = chunk.global_transform.affine_inverse()
		var local: Vector3 = inv_transform * _car.global_position
		var clamped_x: float = clamp(local.x, min_x, max_x)
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
