extends Node3D

const MeshUtils = preload("res://scripts/mesh_utils.gd")

@export var track_generator_path: NodePath
@export var objective_manager_path: NodePath

@export_category("Placement")
@export var side_offset := 20.0
@export var building_spacing := 12.0
@export var spacing_jitter := 3.0
@export var scatter_on_roundabouts := false
@export var intersection_clearance := 25.0
@export var landmark_clearance := 30.0
@export_range(0.0, 1.0) var tree_chance := 0.35

@export_category("Building Models")
@export var building_scenes: Array[PackedScene] = []

@export_category("Tree Size")
@export var tree_radius_min := 0.8
@export var tree_radius_max := 1.8
@export var tree_height_min := 4.0
@export var tree_height_max := 9.0
@export var tree_color := Color(0.16, 0.42, 0.2)

@export var rng_seed := 0

var _rng := RandomNumberGenerator.new()
var _track_generator: Node3D
var _exclusion_points: Array[Vector3] = []

func _ready():
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	_track_generator = get_node_or_null(track_generator_path)
	if _track_generator == null:
		return

	if _track_generator.route_ready:
		_scatter()
	else:
		_track_generator.route_generated.connect(_scatter)

func _scatter():
	_exclusion_points = _get_landmark_points()

	var transforms: Array[Transform3D] = _track_generator.get_chunk_transforms()
	var extents: Array[float] = _track_generator.get_chunk_extents()
	var is_roundabout: Array[bool] = _track_generator.get_chunk_is_roundabout()

	for i in transforms.size():
		if is_roundabout[i] and not scatter_on_roundabouts:
			continue
		_scatter_chunk(transforms[i], extents[i])

func _get_landmark_points() -> Array[Vector3]:
	var manager = get_node_or_null(objective_manager_path)
	if manager and manager.has_method("get_landmark_points"):
		return manager.get_landmark_points()
	return []

func _scatter_chunk(chunk_transform: Transform3D, extent: float):
	var x := intersection_clearance
	var limit := extent - intersection_clearance
	while x < limit:
		if not _near_landmark(chunk_transform, x):
			for side in [-1.0, 1.0]:
				if _rng.randf() < tree_chance:
					_spawn_tree(chunk_transform, x, side)
				else:
					_spawn_building(chunk_transform, x, side)
		x += building_spacing + _rng.randf_range(-spacing_jitter, spacing_jitter)

# A pickup/dropoff landmark can land on either side of the road (decided
# independently, after scattering may already have run), so both sides near
# it are kept clear rather than trying to predict which side it'll use.
func _near_landmark(chunk_transform: Transform3D, x: float) -> bool:
	var world_pos: Vector3 = chunk_transform * Vector3(x, 0.0, 0.0)
	for point in _exclusion_points:
		if world_pos.distance_to(point) < landmark_clearance:
			return true
	return false

func _spawn_building(chunk_transform: Transform3D, x: float, side: float):
	if building_scenes.is_empty():
		return

	var scene: PackedScene = building_scenes[_rng.randi_range(0, building_scenes.size() - 1)]
	var instance: Node3D = scene.instantiate()
	add_child(instance)

	var aabb := MeshUtils.local_aabb(instance)
	var local_pos := Vector3(x, -aabb.position.y, side * (side_offset + aabb.size.z * 0.5))
	instance.global_transform = chunk_transform * Transform3D(Basis.IDENTITY, local_pos)

func _spawn_tree(chunk_transform: Transform3D, x: float, side: float):
	var radius := _rng.randf_range(tree_radius_min, tree_radius_max)
	var height := _rng.randf_range(tree_height_min, tree_height_max)

	var mesh_instance := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh_instance.mesh = cylinder

	var mat := StandardMaterial3D.new()
	mat.albedo_color = tree_color
	mesh_instance.material_override = mat

	add_child(mesh_instance)
	var local_pos := Vector3(x, height * 0.5, side * (side_offset + radius))
	mesh_instance.global_transform = chunk_transform * Transform3D(Basis.IDENTITY, local_pos)
