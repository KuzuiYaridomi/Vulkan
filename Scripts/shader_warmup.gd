extends Node3D

@export var scenes: Array[PackedScene] = [
	preload("res://Scenes/zombie_enemy.tscn"),
	preload("res://Scenes/red_creature.tscn"),
	preload("res://Scenes/end_portal.tscn"),
	preload("res://Scenes/shotgun_pickup.tscn"),
]
@export var muzzle_flash_path: NodePath = ^"../Player/Head/Camera3D/Shotgun/Muzzle/FlashFront"
@export var frames: int = 4


func _ready() -> void:
	await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		queue_free()
		return
	var b := cam.global_transform
	var i := 0
	for s in scenes:
		var n := s.instantiate()
		n.set_script(null)
		add_child(n)
		(n as Node3D).global_position = b.origin - b.basis.z * 4.0 + b.basis.x * (i - 1.5) * 1.3 - b.basis.y * 0.6
		i += 1
	var flash := get_node_or_null(muzzle_flash_path)
	if flash:
		var f := flash.duplicate(0) as Node3D
		add_child(f)
		f.visible = true
		f.global_position = b.origin - b.basis.z * 2.0
	var omni := OmniLight3D.new()
	omni.omni_range = 12.0
	add_child(omni)
	omni.global_position = b.origin - b.basis.z * 3.0
	var spot := SpotLight3D.new()
	spot.spot_range = 25.0
	add_child(spot)
	spot.global_transform = b
	for k in frames:
		await get_tree().process_frame
	queue_free()
