extends CanvasLayer

@export var label_path: NodePath = ^"MessageLabel"
@export var crt_toggle_path: NodePath = ^"CRTToggle"
@export var crt_overlay_path: NodePath

var _label: Label

func _ready():
	_label = get_node_or_null(label_path)
	GameManager.message_changed.connect(_on_message_changed)

	var crt_toggle: CheckBox = get_node_or_null(crt_toggle_path)
	var crt_overlay: CanvasLayer = get_node_or_null(crt_overlay_path)
	if crt_toggle and crt_overlay:
		crt_toggle.button_pressed = crt_overlay.visible
		crt_toggle.toggled.connect(func(enabled: bool): crt_overlay.visible = enabled)

func _on_message_changed(text: String):
	if _label:
		_label.text = text
