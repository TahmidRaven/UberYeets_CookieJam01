extends CanvasLayer

@export var car_path: NodePath
@export var flash_color := Color(1.0, 0.15, 0.1)
@export var peak_alpha := 0.35
@export var impact_to_alpha := 0.03
@export var decay_speed := 3.0

@onready var _rect: ColorRect = $Flash

var _car: Node
var _alpha := 0.0

func _ready():
	_car = get_node_or_null(car_path)
	if _car == null:
		_car = get_tree().get_first_node_in_group("car")
	if _car:
		_car.collided.connect(_on_collided)

func _on_collided(impact_speed: float, _impact_position: Vector3):
	_alpha = clamp(_alpha + impact_speed * impact_to_alpha, 0.0, peak_alpha)

func _process(delta):
	if _alpha <= 0.0:
		return
	_alpha = max(_alpha - decay_speed * delta, 0.0)
	_rect.color = Color(flash_color.r, flash_color.g, flash_color.b, _alpha)
