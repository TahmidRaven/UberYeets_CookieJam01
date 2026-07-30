extends Control

@export var car_path: NodePath
@export var track_generator_path: NodePath
@export var pickup_point_path: NodePath
@export var dropoff_point_path: NodePath

@export_category("Style")
@export var map_padding := 12.0
@export var background_color := Color(0, 0, 0, 0.5)
@export var route_color := Color(1, 1, 1, 0.8)
@export var route_width := 2.0
@export var player_color := Color(0.3, 0.6, 1, 1)
@export var player_marker_size := 6.0
@export var pickup_color := Color(0.2, 1, 0.3, 1)
@export var dropoff_color := Color(1, 0.6, 0.1, 1)
@export var marker_radius := 5.0

var _car: Node3D
var _track_generator: Node3D
var _pickup: Node3D
var _dropoff: Node3D

var _edges: Array[Dictionary] = []
var _node_positions: Array[Vector3] = []
var _world_min := Vector2.ZERO
var _world_scale := 1.0

func _ready():
	_car = get_node_or_null(car_path)
	_track_generator = get_node_or_null(track_generator_path)
	_pickup = get_node_or_null(pickup_point_path)
	_dropoff = get_node_or_null(dropoff_point_path)

	if _track_generator:
		if _track_generator.route_ready:
			_on_route_generated()
		else:
			_track_generator.route_generated.connect(_on_route_generated)

func _on_route_generated():
	var intersections: Array[Node3D] = _track_generator.get_intersections()
	if intersections.is_empty():
		return

	_node_positions.clear()
	for node in intersections:
		_node_positions.append(node.global_position)

	var min_x: float = _node_positions[0].x
	var max_x: float = _node_positions[0].x
	var min_z: float = _node_positions[0].z
	var max_z: float = _node_positions[0].z
	for p in _node_positions:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_z = min(min_z, p.z)
		max_z = max(max_z, p.z)

	_world_min = Vector2(min_x, min_z)
	var world_size := Vector2(max(max_x - min_x, 0.01), max(max_z - min_z, 0.01))
	var available := Vector2(size.x - map_padding * 2.0, size.y - map_padding * 2.0)
	_world_scale = min(available.x / world_size.x, available.y / world_size.y)

	_edges = _track_generator.get_edges()

func _world_to_local(world_pos: Vector3) -> Vector2:
	var flat := Vector2(world_pos.x, world_pos.z) - _world_min
	return flat * _world_scale + Vector2(map_padding, map_padding)

func _process(_delta):
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	for edge in _edges:
		var a: Vector3 = edge["a"]
		var b: Vector3 = edge["b"]
		draw_line(_world_to_local(a), _world_to_local(b), route_color, route_width)

	for node_pos in _node_positions:
		draw_circle(_world_to_local(node_pos), route_width * 1.5, route_color)

	if _pickup and is_instance_valid(_pickup) and _pickup.visible:
		draw_circle(_world_to_local(_pickup.global_position), marker_radius, pickup_color)

	if _dropoff and is_instance_valid(_dropoff) and _dropoff.visible:
		draw_circle(_world_to_local(_dropoff.global_position), marker_radius, dropoff_color)

	if _car and is_instance_valid(_car):
		var pos := _world_to_local(_car.global_position)
		var yaw: float = _car.rotation.y
		# matches Basis(Vector3.UP, yaw).x, the car's actual forward direction
		var forward := Vector2(cos(yaw), -sin(yaw)) * player_marker_size
		var side := forward.orthogonal() * 0.5
		var points := PackedVector2Array([pos + forward, pos - forward + side, pos - forward - side])
		draw_colored_polygon(points, player_color)
