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
var _marker: Node3D
var _person: Node3D
var _person_anim: AnimationPlayer

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_setup_marker()
	_setup_person()

	if building_scene:
		_spawn_building_landmark()

	set_active(false)

func _setup_marker():
	_marker = get_node_or_null("Marker")
	var marker_mesh: MeshInstance3D = get_node_or_null("Marker/Circle2")
	if marker_mesh == null:
		return
	# The ring's baked-in shader colors its alpha from a gradient texture
	# sampled by SCREEN_UV (screen-space position, not the mesh's own UV), so
	# its fade pattern isn't tied to the ring at all and it reads as a flat
	# wash instead of the intended color - swap in a plain, reliable material
	# instead of fighting an unfinished jam shader.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = beacon_color
	mat.emission_enabled = true
	mat.emission = beacon_color
	marker_mesh.set_surface_override_material(0, mat)

# The person's AnimationPlayer autoplays "gamejam_jump" the moment it's
# instanced, which is only right for the dropoff's yeet moment - everywhere
# else that gets overridden immediately below.
func _setup_person():
	_person = get_node_or_null("Person")
	if _person == null:
		return
	_person_anim = _person.get_node_or_null("AnimationPlayer")
	if _person_anim == null:
		return
	_person_anim.stop()

	if kind == "Pickup":
		var idle := _person_anim.get_animation("idle_pepsima")
		if idle:
			idle.loop_mode = Animation.LOOP_LINEAR
		_person_anim.play("idle_pepsima")

# The marker ring toggles like the old beacon did. The person is more
# particular: a waiting pickup fare should be standing there the whole time
# it's active, but the dropoff should stay empty (they're riding in the car)
# until the actual yeet - see _fire_triggered().
func set_active(active: bool):
	monitoring = active
	if _marker:
		_marker.visible = active
	if _person == null:
		return
	if kind == "Pickup":
		_person.visible = active
	elif active:
		_person.visible = false

func _fire_triggered():
	if kind == "Dropoff" and _person and _person_anim:
		_person.visible = true
		_person_anim.play("gamejam_jump")
	triggered.emit(self)

# The landmark rides along as a child so it sits beside the road wherever
# this pickup/dropoff ends up once placed.
func _spawn_building_landmark():
	var instance: Node3D = building_scene.instantiate()
	add_child(instance)

	var side := 1.0 if randf() < 0.5 else -1.0
	var aabb := MeshUtils.local_aabb(instance)
	var local_pos := Vector3(0.0, -aabb.position.y + building_y_offset, side * (building_side_offset + aabb.size.z * 0.5))
	instance.transform = Transform3D(Basis.IDENTITY, local_pos)

func _process(_delta):
	if _car_inside and require_action != "" and Input.is_action_just_pressed(require_action):
		_fire_triggered()

func _on_body_entered(body):
	if body.is_in_group("car"):
		_car_inside = true
		if require_action == "":
			_fire_triggered()

func _on_body_exited(body):
	if body.is_in_group("car"):
		_car_inside = false
