extends Label

@export var objective_manager_path: NodePath
@export var low_time_threshold := 5.0
@export var normal_color := Color(1, 1, 1, 1)
@export var low_time_color := Color(1, 0.3, 0.3, 1)

var _objective_manager: Node
var _played_low_time := false

func _ready():
	_objective_manager = get_node_or_null(objective_manager_path)

func _process(_delta):
	if _objective_manager == null:
		return

	if not _objective_manager.is_round_active():
		text = ""
		_played_low_time = false
		return

	var remaining: float = _objective_manager.get_time_remaining()
	text = "%d" % int(ceil(remaining))

	var low := remaining <= low_time_threshold
	add_theme_color_override("font_color", low_time_color if low else normal_color)

	if low and remaining > 0.0 and not _played_low_time:
		_played_low_time = true
		AudioManager.play_low_timer()
	elif not low:
		_played_low_time = false
