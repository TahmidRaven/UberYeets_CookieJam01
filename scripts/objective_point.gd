extends Area3D

const MeshUtils = preload("res://scripts/mesh_utils.gd")

@export_enum("Pickup", "Dropoff") var kind: String = "Pickup"
@export var require_action := ""
@export var beacon_color: Color = Color.GREEN

@export_category("Landmark")
@export var building_scene: PackedScene
@export var building_side_offset := 14.0
@export var building_y_offset := 0.0

signal triggered(point)

var _car_inside := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var beacon = get_node_or_null("Beacon")
	if beacon is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = beacon_color
		mat.emission_enabled = true
		mat.emission = beacon_color
		beacon.material_override = mat

	if building_scene:
		_spawn_building_landmark()

# The landmark rides along as a child, so it reappears beside the road
# wherever the route places this pickup/dropoff each round.
func _spawn_building_landmark():
	var instance: Node3D = building_scene.instantiate()
	add_child(instance)

	var side := 1.0 if randf() < 0.5 else -1.0
	var aabb := MeshUtils.local_aabb(instance)
	var local_pos := Vector3(0.0, -aabb.position.y + building_y_offset, side * (building_side_offset + aabb.size.z * 0.5))
	instance.transform = Transform3D(Basis.IDENTITY, local_pos)

func _process(_delta):
	if _car_inside and require_action != "" and Input.is_action_just_pressed(require_action):
		triggered.emit(self)

func _on_body_entered(body):
	if body.is_in_group("car"):
		_car_inside = true
		if require_action == "":
			triggered.emit(self)

func _on_body_exited(body):
	if body.is_in_group("car"):
		_car_inside = false
