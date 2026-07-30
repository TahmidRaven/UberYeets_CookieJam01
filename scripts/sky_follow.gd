extends Node3D

@export var camera_path: NodePath

@export_category("Sun (optional)")
@export var light_path: NodePath
@export var sun_distance := 150.0

var _camera: Node3D
var _local_offset := Vector3.ZERO

func _ready():
	_camera = get_node_or_null(camera_path)
	if _camera == null:
		_camera = get_viewport().get_camera_3d()

	var light: Node3D = get_node_or_null(light_path)
	if light:
		# The sun sits opposite the direction the light travels, i.e. along
		# the light node's own +Z, so it visually matches wherever the
		# DirectionalLight is actually aimed instead of a hand-picked spot.
		_local_offset = light.global_transform.basis.z.normalized() * sun_distance

	_disable_shadows(self)

func _disable_shadows(node: Node):
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)

func _process(_delta):
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
		return
	global_position = _camera.global_position + _local_offset
