extends CanvasLayer

@export var label_path: NodePath = ^"MessageLabel"

var _label: Label

func _ready():
	_label = get_node_or_null(label_path)
	GameManager.message_changed.connect(_on_message_changed)

func _on_message_changed(text: String):
	if _label:
		_label.text = text
