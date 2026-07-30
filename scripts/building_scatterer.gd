extends Node3D

@export var track_generator_path: NodePath

@export_category("Placement")
@export var side_offset := 14.0
@export var building_spacing := 12.0
@export var spacing_jitter := 3.0
@export var scatter_on_roundabouts := false
@export_range(0.0, 1.0) var tree_chance := 0.35

@export_category("Building Size")
@export var min_width := 6.0
@export var max_width := 12.0
@export var min_depth := 6.0
@export var max_depth := 12.0
@export var min_height := 8.0
@export var max_height := 30.0
@export var building_colors: Array[Color] = [
	Color(0.75, 0.75, 0.78),
	Color(0.65, 0.68, 0.74),
	Color(0.80, 0.72, 0.64),
	Color(0.55, 0.58, 0.62),
]

@export_category("Tree Size")
@export var tree_radius_min := 0.8
@export var tree_radius_max := 1.8
@export var tree_height_min := 4.0
@export var tree_height_max := 9.0
@export var tree_color := Color(0.16, 0.42, 0.2)

@export var rng_seed := 0

var _rng := RandomNumberGenerator.new()
var _track_generator: Node3D

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
	var transforms: Array[Transform3D] = _track_generator.get_chunk_transforms()
	var extents: Array[float] = _track_generator.get_chunk_extents()
	var is_roundabout: Array[bool] = _track_generator.get_chunk_is_roundabout()

	for i in transforms.size():
		if is_roundabout[i] and not scatter_on_roundabouts:
			continue
		_scatter_chunk(transforms[i], extents[i])

func _scatter_chunk(chunk_transform: Transform3D, extent: float):
	var x := 0.0
	while x < extent:
		for side in [-1.0, 1.0]:
			if _rng.randf() < tree_chance:
				_spawn_tree(chunk_transform, x, side)
			else:
				_spawn_building(chunk_transform, x, side)
		x += building_spacing + _rng.randf_range(-spacing_jitter, spacing_jitter)

func _spawn_building(chunk_transform: Transform3D, x: float, side: float):
	var width := _rng.randf_range(min_width, max_width)
	var depth := _rng.randf_range(min_depth, max_depth)
	var height := _rng.randf_range(min_height, max_height)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, depth)
	mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	if not building_colors.is_empty():
		mat.albedo_color = building_colors[_rng.randi_range(0, building_colors.size() - 1)]
	mesh_instance.material_override = mat

	add_child(mesh_instance)
	var local_pos := Vector3(x, height * 0.5, side * (side_offset + depth * 0.5))
	mesh_instance.global_transform = chunk_transform * Transform3D(Basis.IDENTITY, local_pos)

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
