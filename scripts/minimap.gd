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

var _route_points: Array[Vector2] = []
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
	var points: PackedVector3Array = _track_generator.get_path_points()
	if points.is_empty():
		return

	var min_x: float = points[0].x
	var max_x: float = points[0].x
	var min_z: float = points[0].z
	var max_z: float = points[0].z
	for p in points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_z = min(min_z, p.z)
		max_z = max(max_z, p.z)

	_world_min = Vector2(min_x, min_z)
	var world_size := Vector2(max(max_x - min_x, 0.01), max(max_z - min_z, 0.01))
	var available := Vector2(size.x - map_padding * 2.0, size.y - map_padding * 2.0)
	_world_scale = min(available.x / world_size.x, available.y / world_size.y)

	_route_points.clear()
	for p in points:
		_route_points.append(_world_to_local(Vector3(p.x, 0.0, p.z)))

func _world_to_local(world_pos: Vector3) -> Vector2:
	var flat := Vector2(world_pos.x, world_pos.z) - _world_min
	return flat * _world_scale + Vector2(map_padding, map_padding)

func _process(_delta):
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if _route_points.size() >= 2:
		draw_polyline(_route_points, route_color, route_width)

	if _pickup and is_instance_valid(_pickup):
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
