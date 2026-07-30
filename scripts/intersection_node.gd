extends Node3D

@export var east: NodePath
@export var north: NodePath

func _ready():
	add_to_group("intersection")
