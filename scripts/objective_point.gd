extends Area3D

@export_enum("Pickup", "Dropoff") var kind: String = "Pickup"
@export var require_action := ""
@export var beacon_color: Color = Color.GREEN

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
