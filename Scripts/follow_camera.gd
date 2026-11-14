extends Node3D

@export var ground_height: float = 0.0


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		global_position = Vector3(p.x, ground_height, p.z)
